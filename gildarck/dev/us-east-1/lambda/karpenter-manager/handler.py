import boto3
import json
import os
import re
import base64
import logging
from datetime import datetime
from kubernetes import client
from botocore.signers import RequestSigner

logger = logging.getLogger()
logger.setLevel(logging.INFO)

STS_TOKEN_EXPIRES_IN = 60
region = "us-east-1"
sts_client = boto3.client('sts')
eks_client = boto3.client('eks', region_name=region)
dynamodb = boto3.resource('dynamodb', region_name=region)
service_id = sts_client.meta.service_model.service_id

def get_token(cluster_name, role_to_assume):
    assumed_role = sts_client.assume_role(
        RoleArn=role_to_assume,
        RoleSessionName='AssumeRoleSession'
    )
    
    session = boto3.Session(
        aws_access_key_id=assumed_role['Credentials']['AccessKeyId'],
        aws_secret_access_key=assumed_role['Credentials']['SecretAccessKey'],
        aws_session_token=assumed_role['Credentials']['SessionToken'],
        region_name=region
    )
    
    signer = RequestSigner(
        service_id,
        region,
        'sts',
        'v4',
        session.get_credentials(),
        session.events
    )

    params = {
        'method': 'GET',
        'url': f'https://sts.{region}.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15',
        'body': {},
        'headers': {'x-k8s-aws-id': cluster_name}
    }

    signed_url = signer.generate_presigned_url(
        params,
        region_name=region,
        expires_in=STS_TOKEN_EXPIRES_IN,
        operation_name=''
    )

    base64_url = base64.urlsafe_b64encode(signed_url.encode('utf-8')).decode('utf-8')
    return 'k8s-aws-v1.' + re.sub(r'=*', '', base64_url)

def configure_eks_client(cluster_name, role_to_assume):
    cluster_info = eks_client.describe_cluster(name=cluster_name)
    cluster_cert = cluster_info['cluster']['certificateAuthority']['data']
    cluster_endpoint = cluster_info['cluster']['endpoint']
    
    token = get_token(cluster_name, role_to_assume)
    
    configuration = client.Configuration()
    configuration.host = cluster_endpoint
    configuration.verify_ssl = True
    
    cert_file = "/tmp/cluster-cert.pem"
    with open(cert_file, 'wb') as f:
        f.write(base64.b64decode(cluster_cert))
    
    configuration.ssl_ca_cert = cert_file
    configuration.api_key = {"authorization": f"Bearer {token}"}
    
    client.Configuration.set_default(configuration)
    return client

def get_failure_count(cluster_name):
    try:
        table = dynamodb.Table('karpenter-health-status')
        response = table.get_item(Key={'cluster_name': cluster_name})
        count = response.get('Item', {}).get('failure_count', 0)
        return int(count)
    except Exception as e:
        logger.error(f"Error getting failure count: {e}")
        return 0

def monitor_cluster_health():
    try:
        cluster_name = os.environ.get('CLUSTER_NAME', 'eks-dev-1')
        role_to_assume = os.environ.get('ROLE_TO_ASSUME')
        
        cluster_response = eks_client.describe_cluster(name=cluster_name)
        cluster = cluster_response['cluster']
        
        eks_api = configure_eks_client(cluster_name, role_to_assume)
        v1 = eks_api.CoreV1Api()
        
        total_nodes = 0
        ready_nodes = 0
        not_ready_nodes = 0
        
        try:
            nodes = v1.list_node()
            total_nodes = len(nodes.items)
            
            for node in nodes.items:
                node_ready = False
                if node.status.conditions:
                    for condition in node.status.conditions:
                        if condition.type == "Ready" and condition.status == "True":
                            node_ready = True
                            break
                
                if node_ready:
                    ready_nodes += 1
                else:
                    not_ready_nodes += 1
                    
        except Exception as e:
            logger.error(f"Error getting nodes: {e}")
        
        karpenter_pods = 0
        karpenter_status = "Not Found"
        karpenter_ready = False
        
        try:
            pods = v1.list_namespaced_pod(namespace="karpenter")
            for pod in pods.items:
                if "karpenter" in pod.metadata.name:
                    karpenter_pods += 1
                    if pod.status.phase == "Running":
                        ready_containers = 0
                        total_containers = len(pod.spec.containers)
                        
                        if pod.status.container_statuses:
                            for container_status in pod.status.container_statuses:
                                if container_status.ready:
                                    ready_containers += 1
                        
                        if ready_containers == total_containers:
                            karpenter_status = f"{ready_containers}/{total_containers} Running"
                            karpenter_ready = True
                        else:
                            karpenter_status = f"{ready_containers}/{total_containers} Not Ready"
                    else:
                        karpenter_status = f"0/1 {pod.status.phase}"
                    break
                    
        except Exception as e:
            logger.error(f"Error getting Karpenter status: {e}")
        
        health_percentage = (ready_nodes / total_nodes * 100) if total_nodes > 0 else 0
        
        issues = []
        if cluster['status'] != 'ACTIVE':
            issues.append("cluster_not_active")
        if total_nodes == 0:
            issues.append("no_nodes_available")
        elif ready_nodes == 0:
            issues.append("no_ready_nodes")
        elif not_ready_nodes > 0:
            issues.append(f"{not_ready_nodes}_nodes_not_ready")
        if karpenter_pods == 0:
            issues.append("karpenter_not_found")
        elif not karpenter_ready:
            issues.append("karpenter_not_ready")
        
        status = "healthy" if len(issues) == 0 else "unhealthy"
        
        result = {
            "cluster": cluster_name,
            "cluster_status": cluster['status'],
            "karpenter_pods": karpenter_pods,
            "karpenter_status": karpenter_status,
            "karpenter_ready": karpenter_ready,
            "failure_count": get_failure_count(cluster_name),
            "total_nodes": total_nodes,
            "ready_nodes": ready_nodes,
            "not_ready_nodes": not_ready_nodes,
            "health_percentage": health_percentage,
            "issues": issues,
            "status": status,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        logger.info(json.dumps(result))
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Error in monitor_cluster_health: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def lambda_handler(event, context):
    try:
        action = event.get('action', 'monitor')
        logger.info(f"Ejecutando acción: {action}")
        
        if action == 'monitor':
            return monitor_cluster_health()
        elif action == 'recover':
            return {'statusCode': 200, 'body': json.dumps('Recover function - not implemented yet')}
        elif action == 'cleanup':
            return {'statusCode': 200, 'body': json.dumps('Cleanup function - not implemented yet')}
        else:
            return {
                'statusCode': 400,
                'body': json.dumps(f'Acción inválida: {action}. Usar: monitor, recover, cleanup')
            }
            
    except Exception as e:
        logger.error(f"Error en lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
