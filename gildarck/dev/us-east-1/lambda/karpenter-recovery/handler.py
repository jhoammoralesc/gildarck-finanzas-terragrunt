import boto3
import json
import os
import re
import base64
import time
from datetime import datetime
from kubernetes import client
from kubernetes.client.rest import ApiException
from botocore.signers import RequestSigner

STS_TOKEN_EXPIRES_IN = 60
session = boto3.session.Session()
region = "us-east-1"
sts = session.client('sts')
sts_client = boto3.client('sts')
eks_client = boto3.client('eks', region_name=region)
service_id = sts.meta.service_model.service_id

def configure_eks_client(cluster_name, role_to_assume):
    """Configure Kubernetes client for EKS - same method as credentials-rotation"""
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
        print(f"Error configuring client: {e}")
        raise

def get_token(cluster_name, role_to_assume):
    """Create authentication token - exact same method as credentials-rotation"""
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

def lambda_handler(event, context):
    try:
        cluster_name = os.environ.get('CLUSTER_NAME', 'eks-dev-1')
        node_group_name = os.environ.get('NODE_GROUP_NAME', 'non-fargate-20250804141603154100000001')
        role_to_assume = os.environ.get('ROLE_TO_ASSUME')
        
        # 1. Scale node group to 2 nodes
        print(f"Scaling node group {node_group_name} to 2 nodes")
        
        response = eks_client.update_nodegroup_config(
            clusterName=cluster_name,
            nodegroupName=node_group_name,
            scalingConfig={
                'minSize': 2,
                'maxSize': 10,
                'desiredSize': 2
            }
        )
        
        # 2. Configure EKS client and rollout Karpenter
        eks_api = configure_eks_client(cluster_name, role_to_assume)
        apps_v1 = eks_api.AppsV1Api()
        
        print("Rolling out Karpenter deployment")
        
        # Restart Karpenter deployment
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
        
        result = {
            "status": "success",
            "message": f"Node group {node_group_name} scaled to 2 nodes and Karpenter restarted",
            "update_id": response['update']['id'],
            "timestamp": datetime.utcnow().isoformat()
        }
        
        print(json.dumps(result))
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
        
    except Exception as e:
        error_result = {
            "status": "error",
            "message": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }
        
        print(json.dumps(error_result))
        return {
            'statusCode': 500,
            'body': json.dumps(error_result)
        }
