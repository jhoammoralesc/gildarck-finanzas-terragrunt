import boto3
import json
import os
import re
import base64
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
eventbridge_client = boto3.client('events', region_name=region)
lambda_client = boto3.client('lambda', region_name=region)
service_id = sts.meta.service_model.service_id

def configure_eks_client(cluster_name, role_to_assume):
    """
    Configura el cliente de Kubernetes para EKS - same method as credentials-rotation
    """
    try:
        # Obtener información del cluster
        cluster_info = eks_client.describe_cluster(name=cluster_name)
        cluster_cert = cluster_info['cluster']['certificateAuthority']['data']
        cluster_endpoint = cluster_info['cluster']['endpoint']
        
        # Asumir el rol necesario
        assumed_role = sts_client.assume_role(
            RoleArn=role_to_assume,
            RoleSessionName='karpenter-health-check'
        )
        
        credentials = assumed_role['Credentials']
        access_key = credentials['AccessKeyId']
        secret_key = credentials['SecretAccessKey']
        token = credentials['SessionToken']
        
        # Crear un nuevo cliente STS con las credenciales asumidas
        sts_assumed = boto3.client(
            'sts',
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            aws_session_token=token,
            region_name=region
        )
        
        # Generar token para EKS
        request_signer = RequestSigner(
            service_id,
            region,
            'sts',
            'v4',
            credentials.get_frozen_credentials(),
            sts_assumed.meta.events
        )
        
        params = {
            'method': 'GET',
            'url': f'https://sts.{region}.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15',
            'body': {},
            'headers': {
                'x-k8s-aws-id': cluster_name
            },
            'context': {}
        }
        
        signed_url = request_signer.generate_presigned_url(
            params,
            region_name=region,
            expires_in=STS_TOKEN_EXPIRES_IN,
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
        
        return client.CoreV1Api(), client.AppsV1Api()
        
    except Exception as e:
        print(f"Error configurando cliente EKS: {str(e)}")
        raise e

def get_karpenter_status(apps_v1_api):
    """
    Obtiene el estado del deployment de Karpenter
    """
    try:
        deployment = apps_v1_api.read_namespaced_deployment(
            name="karpenter",
            namespace="karpenter"
        )
        
        ready_replicas = deployment.status.ready_replicas or 0
        replicas = deployment.status.replicas or 0
        
        return {
            'ready_replicas': ready_replicas,
            'total_replicas': replicas,
            'status': f"{ready_replicas}/{replicas}",
            'is_ready': ready_replicas == replicas and replicas > 0
        }
    except ApiException as e:
        print(f"Error obteniendo estado de Karpenter: {e}")
        return {
            'ready_replicas': 0,
            'total_replicas': 0,
            'status': '0/0',
            'is_ready': False,
            'error': str(e)
        }

def get_node_status(core_v1_api):
    """
    Obtiene el estado de los nodos del cluster
    """
    try:
        nodes = core_v1_api.list_node()
        
        total_nodes = len(nodes.items)
        ready_nodes = 0
        not_ready_nodes = 0
        
        for node in nodes.items:
            node_ready = False
            if node.status.conditions:
                for condition in node.status.conditions:
                    if condition.type == "Ready":
                        if condition.status == "True":
                            ready_nodes += 1
                            node_ready = True
                        break
            
            if not node_ready:
                not_ready_nodes += 1
        
        return {
            'total_nodes': total_nodes,
            'ready_nodes': ready_nodes,
            'not_ready_nodes': not_ready_nodes,
            'health_percentage': (ready_nodes / total_nodes * 100) if total_nodes > 0 else 0
        }
    except ApiException as e:
        print(f"Error obteniendo estado de nodos: {e}")
        return {
            'total_nodes': 0,
            'ready_nodes': 0,
            'not_ready_nodes': 0,
            'health_percentage': 0,
            'error': str(e)
        }

def get_karpenter_pods_status(core_v1_api):
    """
    Obtiene el estado de los pods de Karpenter
    """
    try:
        pods = core_v1_api.list_namespaced_pod(namespace="karpenter", label_selector="app.kubernetes.io/name=karpenter")
        
        total_pods = len(pods.items)
        running_pods = 0
        
        for pod in pods.items:
            if pod.status.phase == "Running":
                running_pods += 1
        
        return {
            'total_pods': total_pods,
            'running_pods': running_pods,
            'status': f"{running_pods}/{total_pods}",
            'is_healthy': running_pods == total_pods and total_pods > 0
        }
    except ApiException as e:
        print(f"Error obteniendo estado de pods de Karpenter: {e}")
        return {
            'total_pods': 0,
            'running_pods': 0,
            'status': '0/0',
            'is_healthy': False,
            'error': str(e)
        }

def trigger_recovery_actions():
    """
    Dispara las acciones de recuperación
    """
    try:
        # Invocar lambda de recovery
        lambda_client.invoke(
            FunctionName='karpenter-recovery',
            InvocationType='Event'
        )
        
        # Enviar evento a EventBridge
        eventbridge_client.put_events(
            Entries=[
                {
                    'Source': 'karpenter.health-monitor',
                    'DetailType': 'Karpenter Health Issue Detected',
                    'Detail': json.dumps({
                        'timestamp': datetime.utcnow().isoformat(),
                        'action': 'recovery_triggered',
                        'status': 'unhealthy'
                    })
                }
            ]
        )
        
        return True
    except Exception as e:
        print(f"Error disparando acciones de recuperación: {e}")
        return False

def lambda_handler(event, context):
    """
    Handler principal de la función Lambda
    """
    try:
        cluster_name = os.environ.get('CLUSTER_NAME', 'eks-dev-1')
        role_to_assume = os.environ.get('ROLE_TO_ASSUME')
        
        if not role_to_assume:
            raise ValueError("ROLE_TO_ASSUME environment variable is required")
        
        # Obtener información del cluster
        cluster_info = eks_client.describe_cluster(name=cluster_name)
        cluster_status = cluster_info['cluster']['status']
        
        # Configurar cliente de Kubernetes
        core_v1_api, apps_v1_api = configure_eks_client(cluster_name, role_to_assume)
        
        # Obtener estados
        karpenter_deployment = get_karpenter_status(apps_v1_api)
        karpenter_pods = get_karpenter_pods_status(core_v1_api)
        node_status = get_node_status(core_v1_api)
        
        # Determinar estado general
        issues = []
        
        # Verificar si hay nodos listos
        if node_status['ready_nodes'] == 0:
            issues.append('no_ready_nodes')
        
        # Verificar estado de Karpenter
        if not karpenter_deployment['is_ready']:
            issues.append('karpenter_not_ready')
        
        if not karpenter_pods['is_healthy']:
            issues.append('karpenter_pods_not_healthy')
        
        # Determinar si el sistema está saludable
        is_healthy = len(issues) == 0
        
        # Si no está saludable, disparar recuperación
        recovery_triggered = False
        if not is_healthy:
            recovery_triggered = trigger_recovery_actions()
        
        # Preparar respuesta
        response = {
            'cluster': cluster_name,
            'cluster_status': cluster_status,
            'karpenter_pods': karpenter_pods['total_pods'],
            'karpenter_status': karpenter_deployment['status'],
            'total_nodes': node_status['total_nodes'],
            'ready_nodes': node_status['ready_nodes'],
            'not_ready_nodes': node_status['not_ready_nodes'],
            'health_percentage': node_status['health_percentage'],
            'issues': issues,
            'status': 'healthy' if is_healthy else 'unhealthy',
            'timestamp': datetime.utcnow().isoformat()
        }
        
        if recovery_triggered:
            response['recovery_triggered'] = True
        
        return {
            'statusCode': 200,
            'body': json.dumps(response)
        }
        
    except Exception as e:
        print(f"Error en lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'status': 'error',
                'timestamp': datetime.utcnow().isoformat()
            })
        }
