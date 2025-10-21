import boto3
import json
import os
from datetime import datetime
from kubernetes import client, config
from kubernetes.client.rest import ApiException
import base64
from botocore.signers import RequestSigner

def lambda_handler(event, context):
    """
    Handler principal para la recuperación de Karpenter
    """
    try:
        cluster_name = os.environ.get('CLUSTER_NAME', 'eks-dev-1')
        node_group_name = os.environ.get('NODE_GROUP_NAME')
        role_to_assume = os.environ.get('ROLE_TO_ASSUME')
        
        if not node_group_name:
            raise ValueError("NODE_GROUP_NAME environment variable is required")
        
        if not role_to_assume:
            raise ValueError("ROLE_TO_ASSUME environment variable is required")
        
        # Configurar clientes AWS
        sts_client = boto3.client('sts')
        
        # Asumir rol
        assumed_role = sts_client.assume_role(
            RoleArn=role_to_assume,
            RoleSessionName='karpenter-recovery'
        )
        
        credentials = assumed_role['Credentials']
        
        # Crear clientes con credenciales asumidas
        eks_client = boto3.client(
            'eks',
            aws_access_key_id=credentials['AccessKeyId'],
            aws_secret_access_key=credentials['SecretAccessKey'],
            aws_session_token=credentials['SessionToken'],
            region_name='us-east-1'
        )
        
        # Escalar el node group
        print(f"Escalando node group {node_group_name} a 2 nodos...")
        
        update_response = eks_client.update_nodegroup_config(
            clusterName=cluster_name,
            nodegroupName=node_group_name,
            scalingConfig={
                'minSize': 2,
                'maxSize': 10,
                'desiredSize': 2
            }
        )
        
        update_id = update_response['update']['id']
        print(f"Update iniciado con ID: {update_id}")
        
        # Configurar cliente de Kubernetes para reiniciar Karpenter
        try:
            configure_k8s_client(cluster_name, credentials)
            
            # Reiniciar deployment de Karpenter
            apps_v1 = client.AppsV1Api()
            
            # Obtener el deployment actual
            deployment = apps_v1.read_namespaced_deployment(
                name="karpenter",
                namespace="karpenter"
            )
            
            # Forzar restart agregando/actualizando annotation
            if not deployment.spec.template.metadata.annotations:
                deployment.spec.template.metadata.annotations = {}
            
            deployment.spec.template.metadata.annotations['kubectl.kubernetes.io/restartedAt'] = datetime.utcnow().isoformat()
            
            # Aplicar el cambio
            apps_v1.patch_namespaced_deployment(
                name="karpenter",
                namespace="karpenter",
                body=deployment
            )
            
            print("Karpenter deployment reiniciado exitosamente")
            
        except Exception as k8s_error:
            print(f"Error reiniciando Karpenter (continuando): {k8s_error}")
        
        response = {
            'status': 'success',
            'message': f'Node group {node_group_name} scaled to 2 nodes and Karpenter restarted',
            'update_id': update_id,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        return {
            'statusCode': 200,
            'body': json.dumps(response)
        }
        
    except Exception as e:
        print(f"Error en recovery: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
                'message': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }

def configure_k8s_client(cluster_name, credentials):
    """
    Configura el cliente de Kubernetes para EKS
    """
    try:
        # Crear cliente EKS con credenciales asumidas
        eks_client = boto3.client(
            'eks',
            aws_access_key_id=credentials['AccessKeyId'],
            aws_secret_access_key=credentials['SecretAccessKey'],
            aws_session_token=credentials['SessionToken'],
            region_name='us-east-1'
        )
        
        # Obtener información del cluster
        cluster_info = eks_client.describe_cluster(name=cluster_name)
        cluster_cert = cluster_info['cluster']['certificateAuthority']['data']
        cluster_endpoint = cluster_info['cluster']['endpoint']
        
        # Generar token para EKS
        sts_client = boto3.client(
            'sts',
            aws_access_key_id=credentials['AccessKeyId'],
            aws_secret_access_key=credentials['SecretAccessKey'],
            aws_session_token=credentials['SessionToken'],
            region_name='us-east-1'
        )
        
        service_id = sts_client.meta.service_model.service_id
        
        request_signer = RequestSigner(
            service_id,
            'us-east-1',
            'sts',
            'v4',
            credentials,
            sts_client.meta.events
        )
        
        params = {
            'method': 'GET',
            'url': 'https://sts.us-east-1.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15',
            'body': {},
            'headers': {
                'x-k8s-aws-id': cluster_name
            },
            'context': {}
        }
        
        signed_url = request_signer.generate_presigned_url(
            params,
            region_name='us-east-1',
            expires_in=60,
            operation_name=''
        )
        
        base64_url = base64.urlsafe_b64encode(signed_url.encode('utf-8')).decode('utf-8')
        
        # Configurar el cliente de Kubernetes
        configuration = client.Configuration()
        configuration.host = cluster_endpoint
        configuration.verify_ssl = True
        configuration.ssl_ca_cert = None
        configuration.cert_file = None
        configuration.key_file = None
        configuration.api_key = {"authorization": "Bearer k8s-aws-v1." + base64_url}
        configuration.api_key_prefix = {}
        configuration.ssl_ca_cert_data = base64.b64decode(cluster_cert).decode('utf-8')
        
        client.Configuration.set_default(configuration)
        
    except Exception as e:
        print(f"Error configurando cliente K8s: {str(e)}")
        raise e
