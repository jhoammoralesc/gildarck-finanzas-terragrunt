import json
import logging
import os
import boto3
from kubernetes import client, config
from kubernetes.client.rest import ApiException

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function que limpia finalizers de nodos NotReady/Unknown y NodeClaims huérfanos
    """
    try:
        logger.info("Iniciando limpieza de finalizers...")
        
        cluster_name = os.environ.get('CLUSTER_NAME', 'eks-dev-1')
        role_arn = os.environ.get('ROLE_TO_ASSUME')
        
        # Configurar cliente EKS
        eks_client = boto3.client('eks')
        
        # Obtener información del cluster
        cluster_info = eks_client.describe_cluster(name=cluster_name)
        cluster_endpoint = cluster_info['cluster']['endpoint']
        cluster_ca = cluster_info['cluster']['certificateAuthority']['data']
        
        # Asumir rol si está configurado
        if role_arn:
            sts_client = boto3.client('sts')
            assumed_role = sts_client.assume_role(
                RoleArn=role_arn,
                RoleSessionName='karpenter-cleanup-session'
            )
            credentials = assumed_role['Credentials']
            
            # Configurar token de autenticación
            token = get_eks_token(cluster_name, credentials)
        else:
            token = get_eks_token(cluster_name)
        
        # Configurar cliente de Kubernetes
        configuration = client.Configuration()
        configuration.host = cluster_endpoint
        configuration.verify_ssl = True
        configuration.ssl_ca_cert = write_ca_cert(cluster_ca)
        configuration.api_key = {"authorization": "Bearer " + token}
        configuration.api_key_prefix = {"authorization": "Bearer"}
        
        client.Configuration.set_default(configuration)
        
        v1 = client.CoreV1Api()
        custom_api = client.CustomObjectsApi()
        
        # Limpiar finalizers de nodos en estado Unknown o NotReady
        cleanup_nodes(v1)
        
        # Limpiar finalizers de NodeClaims huérfanos
        cleanup_nodeclaims(custom_api)
        
        logger.info("Limpieza de finalizers completada")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Limpieza de finalizers completada exitosamente')
        }
        
    except Exception as e:
        logger.error(f"Error en lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def cleanup_nodes(v1):
    """Limpia finalizers de nodos en estado NotReady o Unknown"""
    try:
        logger.info("Removiendo finalizers de nodos huérfanos...")
        nodes = v1.list_node()
        
        for node in nodes.items:
            node_name = node.metadata.name
            node_status = "Unknown"
            
            # Determinar el estado del nodo
            if node.status.conditions:
                for condition in node.status.conditions:
                    if condition.type == "Ready":
                        if condition.status == "True":
                            node_status = "Ready"
                        elif condition.status == "False":
                            node_status = "NotReady"
                        break
            
            # Si el nodo está en estado Unknown o NotReady, limpiar finalizers
            if node_status in ["Unknown", "NotReady"]:
                logger.info(f"Removiendo finalizers del nodo: {node_name} (Estado: {node_status})")
                
                try:
                    # Patch para remover finalizers
                    body = {"metadata": {"finalizers": []}}
                    v1.patch_node(name=node_name, body=body)
                    logger.info(f"Finalizers removidos exitosamente del nodo: {node_name}")
                except ApiException as e:
                    logger.warning(f"Error patcheando nodo {node_name}: {e}")
                    
    except Exception as e:
        logger.error(f"Error en cleanup_nodes: {str(e)}")

def cleanup_nodeclaims(custom_api):
    """Limpia finalizers de NodeClaims huérfanos"""
    try:
        logger.info("Removiendo finalizers de NodeClaims huérfanos...")
        
        # Listar NodeClaims
        nodeclaims = custom_api.list_cluster_custom_object(
            group="karpenter.sh",
            version="v1beta1",
            plural="nodeclaims"
        )
        
        for nc in nodeclaims.get('items', []):
            nc_name = nc['metadata']['name']
            logger.info(f"Removiendo finalizers del NodeClaim: {nc_name}")
            
            try:
                # Patch para remover finalizers
                body = {"metadata": {"finalizers": []}}
                custom_api.patch_cluster_custom_object(
                    group="karpenter.sh",
                    version="v1beta1",
                    plural="nodeclaims",
                    name=nc_name,
                    body=body
                )
                logger.info(f"Finalizers removidos exitosamente del NodeClaim: {nc_name}")
            except ApiException as e:
                logger.warning(f"Error patcheando NodeClaim {nc_name}: {e}")
                
    except Exception as e:
        logger.error(f"Error en cleanup_nodeclaims: {str(e)}")

def get_eks_token(cluster_name, credentials=None):
    """Genera token de autenticación para EKS"""
    import base64
    import datetime
    import hashlib
    import hmac
    import urllib.parse
    
    if credentials:
        access_key = credentials['AccessKeyId']
        secret_key = credentials['SecretAccessKey']
        session_token = credentials['SessionToken']
    else:
        session = boto3.Session()
        creds = session.get_credentials()
        access_key = creds.access_key
        secret_key = creds.secret_key
        session_token = creds.token
    
    # Crear token usando AWS STS
    sts_client = boto3.client('sts')
    if credentials:
        sts_client = boto3.client(
            'sts',
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            aws_session_token=session_token
        )
    
    # Generar token presignado
    url = sts_client.generate_presigned_url(
        'get_caller_identity',
        Params={'ClusterName': cluster_name},
        ExpiresIn=60,
        HttpMethod='GET'
    )
    
    token = base64.urlsafe_b64encode(url.encode()).decode().rstrip('=')
    return f"k8s-aws-v1.{token}"

def write_ca_cert(ca_data):
    """Escribe el certificado CA a un archivo temporal"""
    import tempfile
    import base64
    
    ca_cert = base64.b64decode(ca_data)
    with tempfile.NamedTemporaryFile(mode='w+b', delete=False, suffix='.crt') as f:
        f.write(ca_cert)
        return f.name
