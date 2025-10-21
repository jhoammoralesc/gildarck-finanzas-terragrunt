import boto3
import json
import os
import re
import base64
import time
import logging
from datetime import datetime
from kubernetes import client
from kubernetes.client.rest import ApiException
from botocore.signers import RequestSigner

logger = logging.getLogger()
logger.setLevel(logging.INFO)

STS_TOKEN_EXPIRES_IN = 60
session = boto3.session.Session()
region = "us-east-1"
sts = session.client('sts')
sts_client = boto3.client('sts')
eks_client = boto3.client('eks', region_name=region)
eventbridge_client = boto3.client('events', region_name=region)
lambda_client = boto3.client('lambda', region_name=region)
dynamodb = boto3.resource('dynamodb', region_name=region)
service_id = sts.meta.service_model.service_id

def configure_eks_client(cluster_name, role_to_assume):
    try:
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
        
    except Exception as e:
        print(f"Error configurando el cliente: {e}")
        raise

def get_token(cluster_name, role_to_assume):
    assumed_role = sts_client.assume_role(
        RoleArn=role_to_assume,
        RoleSessionName='AssumeRoleSession'
    )
    
    session = boto3.Session(
        aws_access_key_id=assumed_role['Credentials']['AccessKeyId'],
        aws_secret_access_key=assumed_role['Credentials']['SecretAccessKey'],
        aws_session_token=assumed_role['Credentials']['SessionToken']
    )
    
    signer = RequestSigner(
        service_id,
        session.region_name,
        'sts',
        'v4',
        session.get_credentials(),
        session.events
    )

    params = {
        'method': 'GET',
        'url': f'https://sts.{session.region_name}.amazonaws.com/'
               '?Action=GetCallerIdentity&Version=2011-06-15'.format(session.region_name),
        'body': {},
        'headers': {
            'x-k8s-aws-id': cluster_name
        },
        'context': {}
    }

    signed_url = signer.generate_presigned_url(
        params,
        region_name=session.region_name,
        expires_in=STS_TOKEN_EXPIRES_IN,
        operation_name='EksActions'
    )
    base64_url = base64.urlsafe_b64encode(signed_url.encode('utf-8')).decode('utf-8')
    return 'k8s-aws-v1.' + re.sub(r'=*', '', base64_url)

def get_failure_count(cluster_name):
    try:
        table = dynamodb.Table('karpenter-health-status')
        response = table.get_item(Key={'cluster_name': cluster_name})
        count = response.get('Item', {}).get('failure_count', 0)
        return int(count)  # Convert Decimal to int
    except Exception as e:
        print(f"Error getting failure count: {e}")
        return 0

def update_failure_count(cluster_name, count):
    try:
        table = dynamodb.Table('karpenter-health-status')
        table.put_item(Item={
            'cluster_name': cluster_name,
            'failure_count': count,
            'last_updated': datetime.utcnow().isoformat()
        })
    except Exception as e:
        print(f"Error updating failure count: {e}")

def invoke_lambda(function_name, payload=None):
    try:
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='Event',
            Payload=json.dumps(payload) if payload else '{}'
        )
        print(f"{function_name} lambda invoked successfully")
        return response
    except Exception as e:
        print(f"Error invoking {function_name} lambda: {e}")
        return None

def publish_karpenter_failure_event(cluster_name, karpenter_status, issues):
    try:
        event_detail = {
            "cluster": cluster_name,
            "status": "NOT_READY",
            "karpenter_status": karpenter_status,
            "issues": issues,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        response = eventbridge_client.put_events(
            Entries=[
                {
                    'Source': 'karpenter.health.monitor',
                    'DetailType': 'Karpenter Health Check Failed',
                    'Detail': json.dumps(event_detail)
                }
            ]
        )
        
        print(f"Published Karpenter failure event: {response}")
        return response
        
    except Exception as e:
        print(f"Error publishing event: {e}")
        return None

def karpenter_recovery(cluster_name, role_to_assume):
    """Recovery functionality - scale node group and restart Karpenter with wait periods"""
    try:
        node_group_name = os.environ.get('NODE_GROUP_NAME', 'non-fargate-20250804141603154100000001')
        
        print(f"Scaling node group {node_group_name} to 2 nodes (max 3)")
        response = eks_client.update_nodegroup_config(
            clusterName=cluster_name,
            nodegroupName=node_group_name,
            scalingConfig={
                'minSize': 2,
                'maxSize': 3,
                'desiredSize': 2
            }
        )
        
        print("Waiting 30 seconds for node group scaling...")
        time.sleep(30)  # Wait for scaling
        
        eks_api = configure_eks_client(cluster_name, role_to_assume)
        apps_v1 = eks_api.AppsV1Api()
        
        print("Rolling out Karpenter deployment")
        body = {
            'spec': {
                'template': {
                    'metadata': {
                        'annotations': {
                            'kubectl.kubernetes.io/restartedAt': datetime.utcnow().isoformat()
                        }
                    }
                }
            }
        }
        
        apps_v1.patch_namespaced_deployment(
            name='karpenter',
            namespace='karpenter',
            body=body
        )
        
        print("Waiting 30 seconds for Karpenter rollout...")
        time.sleep(30)  # Wait for rollout
        
        return {"status": "success", "update_id": response['update']['id']}
        
    except Exception as e:
        print(f"Error in recovery: {e}")
        return {"status": "error", "message": str(e)}

def cleanup_nodes(v1):
    """Remove nodes in NotReady or Unknown state"""
    cleaned_nodes = []
    try:
        nodes = v1.list_node()
        config = v1.api_client.configuration
        
        for node in nodes.items:
            node_name = node.metadata.name
            node_status = "Unknown"
            
            if node.status.conditions:
                for condition in node.status.conditions:
                    if condition.type == "Ready":
                        if condition.status == "True":
                            node_status = "Ready"
                        elif condition.status == "False":
                            node_status = "NotReady"
                        break
            
            if node_status in ["Unknown", "NotReady"]:
                try:
                    import requests
                    
                    patch_url = f"{config.host}/api/v1/nodes/{node_name}"
                    patch_headers = {
                        'Authorization': config.api_key['authorization'],
                        'Content-Type': 'application/merge-patch+json'
                    }
                    patch_data = '{"metadata":{"finalizers":[]}}'
                    
                    patch_response = requests.patch(
                        patch_url, headers=patch_headers, data=patch_data,
                        verify=config.ssl_ca_cert, timeout=30
                    )
                    
                    if patch_response.status_code in [200, 202]:
                        delete_url = f"{config.host}/api/v1/nodes/{node_name}?gracePeriodSeconds=0"
                        delete_headers = {
                            'Authorization': config.api_key['authorization'],
                            'Content-Type': 'application/json'
                        }
                        
                        delete_response = requests.delete(
                            delete_url, headers=delete_headers,
                            verify=config.ssl_ca_cert, timeout=30
                        )
                        
                        if delete_response.status_code in [200, 202, 404]:
                            cleaned_nodes.append({"name": node_name, "status": node_status})
                            
                except Exception as e:
                    logger.warning(f"Error processing node {node_name}: {e}")
                    
    except Exception as e:
        logger.error(f"Error in cleanup_nodes: {e}")
    
    return cleaned_nodes

def cleanup_nodeclaims(custom_api):
    """Clean finalizers from orphaned NodeClaims"""
    cleaned_nodeclaims = []
    try:
        nodeclaims = custom_api.list_cluster_custom_object(
            group="karpenter.sh", version="v1beta1", plural="nodeclaims"
        )
        
        for nc in nodeclaims.get('items', []):
            nc_name = nc['metadata']['name']
            try:
                body = {"metadata": {"finalizers": []}}
                custom_api.patch_cluster_custom_object(
                    group="karpenter.sh", version="v1beta1",
                    plural="nodeclaims", name=nc_name, body=body
                )
                cleaned_nodeclaims.append({"name": nc_name})
            except ApiException as e:
                logger.warning(f"Error patching NodeClaim {nc_name}: {e}")
                
    except Exception as e:
        logger.error(f"Error in cleanup_nodeclaims: {e}")
    
    return cleaned_nodeclaims

def invoke_stop_start_services(action):
    """Invoke stop-start-services-function with specified action"""
    try:
        response = lambda_client.invoke(
            FunctionName='stop-start-services-function',
            InvocationType='RequestResponse',
            Payload=json.dumps({'action': action})
        )
        
        result = json.loads(response['Payload'].read())
        print(f"Stop-start-services {action} result: {result}")
        return result
        
    except Exception as e:
        print(f"Error invoking stop-start-services {action}: {e}")
        return {"status": "error", "message": str(e)}

def karpenter_cleanup(cluster_name, role_to_assume):
    """Cleanup functionality - remove bad nodes and NodeClaims with wait periods"""
    try:
        print("Starting cleanup process...")
        
        # Step 1: Stop services
        print("Stopping services...")
        stop_result = invoke_stop_start_services('stop')
        
        print("Waiting 60 seconds after stopping services...")
        time.sleep(60)  # Wait after stopping services
        
        # Step 2: Clean nodes and NodeClaims
        eks_api = configure_eks_client(cluster_name, role_to_assume)
        v1 = eks_api.CoreV1Api()
        custom_api = eks_api.CustomObjectsApi()
        
        print("Cleaning up nodes and NodeClaims...")
        cleaned_nodes = cleanup_nodes(v1)
        cleaned_nodeclaims = cleanup_nodeclaims(custom_api)
        
        print("Waiting 30 seconds after cleanup...")
        time.sleep(30)  # Wait after cleanup
        
        return {
            "status": "success",
            "stop_services_result": stop_result,
            "cleaned_nodes": cleaned_nodes,
            "cleaned_nodeclaims": cleaned_nodeclaims,
            "total_cleaned": len(cleaned_nodes) + len(cleaned_nodeclaims)
        }
        
    except Exception as e:
        print(f"Error in cleanup: {e}")
        return {"status": "error", "message": str(e)}

def lambda_handler(event, context):
    try:
        # Check if this is an action-based invocation
        action = event.get('action')
        cluster_name = os.environ.get('CLUSTER_NAME', 'eks-dev-1')
        role_to_assume = os.environ.get('ROLE_TO_ASSUME')
        
        # Handle specific actions
        if action == 'recover':
            result = karpenter_recovery(cluster_name, role_to_assume)
            return {'statusCode': 200, 'body': json.dumps(result)}
            
        elif action == 'cleanup':
            result = karpenter_cleanup(cluster_name, role_to_assume)
            return {'statusCode': 200, 'body': json.dumps(result)}
        
        # Default behavior: health monitoring (original functionality)
        eks_api = configure_eks_client(cluster_name, role_to_assume)
        v1 = eks_api.CoreV1Api()
        
        cluster_response = eks_client.describe_cluster(name=cluster_name)
        cluster = cluster_response['cluster']
        
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
            print(f"Error getting nodes: {e}")
        
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
            print(f"Error getting Karpenter status: {e}")
        
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
        
        # ESCALATION LOGIC with integrated recovery/cleanup and wait periods
        if not karpenter_ready:
            current_failures = get_failure_count(cluster_name)
            new_failure_count = current_failures + 1
            update_failure_count(cluster_name, new_failure_count)
            
            print(f"Karpenter not ready. Failure count: {new_failure_count}")
            
            if new_failure_count == 1:
                print("First Karpenter failure - executing recovery with wait periods")
                publish_karpenter_failure_event(cluster_name, karpenter_status, issues)
                recovery_result = karpenter_recovery(cluster_name, role_to_assume)
                print(f"Recovery result: {recovery_result}")
                
            elif new_failure_count >= 2:
                print("Second+ Karpenter failure - executing full recovery sequence with wait periods")
                publish_karpenter_failure_event(cluster_name, karpenter_status, issues)
                
                # Full sequence: stop services -> wait -> cleanup -> wait -> recovery
                print("Starting full cleanup and recovery sequence...")
                cleanup_result = karpenter_cleanup(cluster_name, role_to_assume)
                print(f"Cleanup result: {cleanup_result}")
                
                # Additional wait between cleanup and recovery
                print("Waiting 30 seconds before recovery...")
                time.sleep(30)
                
                recovery_result = karpenter_recovery(cluster_name, role_to_assume)
                print(f"Recovery result: {recovery_result}")
                
        else:
            update_failure_count(cluster_name, 0)
        
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
        
        print(json.dumps({
            "statusCode": 200,
            "body": result
        }, indent=2))
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
        
    except Exception as e:
        error_result = {
            "error": str(e),
            "status": "error",
            "timestamp": datetime.utcnow().isoformat()
        }
        
        print(json.dumps({
            "statusCode": 500,
            "body": error_result
        }, indent=2))
        
        return {
            'statusCode': 500,
            'body': json.dumps(error_result)
        }
