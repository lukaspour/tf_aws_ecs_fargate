import json
import boto3
import logging
import re
import os
from jinja2 import Environment, FileSystemLoader

session = boto3.session.Session()
logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    cluster_name = os.environ.get('ECS_CLUSTER')
    ecs_region_name = os.environ.get('ECS_REGION_NAME') if \
        os.environ.get('ECS_REGION_NAME') else 'eu-west-1'

    ecs = session.client(
        service_name='ecs',
        region_name=ecs_region_name
    )
    clw = session.client(
        service_name='cloudwatch',
        region_name=ecs_region_name
    )
    elb = boto3.client(
        service_name='elbv2',
        region_name=ecs_region_name
    )

    templates_dir = './templates'
    env = Environment(loader=FileSystemLoader(templates_dir))
    template = env.get_template('dashboard.json.j2')

    # basic listing, list services returns only 10 records at once
    services = ecs.list_services(
        cluster=cluster_name
    )
    services_list = services['serviceArns']
    while len(services['serviceArns']) and 'nextToken' in services:
        services = ecs.list_services(
            cluster=cluster_name,
            nextToken=services['nextToken']
        )
        services_list += services['serviceArns']

    services_names = [
        service.split("/")[1][0:32] for service in services_list if re.fullmatch(
            r"[0-9a-zA-Z\-]+", service.split("/")[1][0:32]
        )
    ]

    target_groups = []
    for services_name in services_names:
        try:
            target_groups.append(
                elb.describe_target_groups(
                    Names=[services_name]
                )['TargetGroups'][0]
            )
        except elb.exceptions.TargetGroupNotFoundException:
            continue

    template_data_list = []

    y_counter = 0

    for service in services_names:
        try:
            target_group = [
                tg['TargetGroupArn'].split('/')[-1] for tg in target_groups if tg['TargetGroupName'] == service
            ][0]
            load_balancer = [
                tg['LoadBalancerArns'] for tg in target_groups if tg['TargetGroupName'] == service
            ][0]
        except IndexError:
            # Service does not have target group or load balancer
            continue

        if len(load_balancer) > 0:
            load_balancer = load_balancer[0]
            load_balancer = load_balancer[
                load_balancer.find('loadbalancer') + len('loadbalancer') + 1:
            ]
        else:
            load_balancer = ""
        template_data_list += [
            {
                "target_group_id": target_group,
                "ecs_cluster_name": cluster_name,
                "ecs_service": service,
                "region": ecs_region_name,
                "y": y_counter,
                "load_balancer": load_balancer
            }
        ]
        y_counter += 1

    dashboard_body = template.render(
        template_data_list=template_data_list
    )

    # print(json.loads(dashboard_body))

    clw.put_dashboard(
        DashboardName=cluster_name + "-ecs-services-list-dashboard",
        DashboardBody=dashboard_body
    )

    return {
        "statusCode": 200,
        "body": json.dumps('Ended correctly')
    }


if __name__ == "__main__":
    lambda_handler("", "")
