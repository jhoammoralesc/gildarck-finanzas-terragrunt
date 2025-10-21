import json
import logging
import os
import re
import base64
import boto3
from kubernetes import client, config
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
service_id = sts.meta.service_model.service_id

def get_token(cluster_name, role_to_assume):
    """Create authentication token - same method as health-check"""
    
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

    # remove any base64 encoding padding:
    return 'k8s-aws-v1.' + re.sub(r'=*', '', base64_url)

def configure_eks_client(cluster_name, role_to_assume):
    """Configura el cliente de Kubernetes para EKS - same method as health-check"""
    try:
        # Obtener información del cluster
        cluster_info = eks_client.describe_cluster(name=cluster_name)
        cluster_cert = cluster_info['cluster']['certificateAuthority']['data']
        cluster_endpoint = cluster_info['cluster']['endpoint']
        
        # Obtener token
        token = get_token(cluster_name, role_to_assume)
        
        # Configurar cliente
        configuration = client.Configuration()
        configuration.host = cluster_endpoint
        configuration.verify_ssl = True
        
        # Asegurarse de que el certificado se cargue correctamente
        cert_file = "/tmp/cluster-cert.pem"
        with open(cert_file, 'wb') as f:
            f.write(base64.b64decode(cluster_cert))
        
        configuration.ssl_ca_cert = cert_file
        configuration.api_key = {"authorization": f"Bearer {token}"}
        
        # Establecer configuración
        client.Configuration.set_default(configuration)
        
        return client
        
    except Exception as e:
        logger.error(f"Error configurando el cliente: {e}")
        raise

def lambda_handler(event, context):
    """
    Lambda function que elimina nodos NotReady/Unknown y NodeClaims huérfanos
    """
    try:
        logger.info("Iniciando limpieza de nodos...")
        
        cluster_name = os.environ.get('CLUSTER_NAME', 'eks-dev-1')
        role_to_assume = os.environ.get('ROLE_TO_ASSUME')
        
        # Configurar cliente EKS usando el mismo método que health-check
        eks_api = configure_eks_client(cluster_name, role_to_assume)
        v1 = eks_api.CoreV1Api()
        custom_api = eks_api.CustomObjectsApi()
        
        # Eliminar nodos en estado Unknown o NotReady
        cleaned_nodes = cleanup_nodes(v1)
        
        # Limpiar finalizers de NodeClaims huérfanos
        cleaned_nodeclaims = cleanup_nodeclaims(custom_api)
        
        result = {
            'cleaned_nodes': cleaned_nodes,
            'cleaned_nodeclaims': cleaned_nodeclaims,
            'total_cleaned': len(cleaned_nodes) + len(cleaned_nodeclaims)
        }
        
        logger.info(f"Limpieza completada: {result}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Error en lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def cleanup_nodes(v1):
    """Elimina nodos en estado NotReady o Unknown usando API REST directa"""
    cleaned_nodes = []
    try:
        logger.info("Eliminando nodos huérfanos...")
        nodes = v1.list_node()
        
        # Obtener configuración del cliente para hacer llamadas REST directas
        config = v1.api_client.configuration
        
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
            
            # Si el nodo está en estado Unknown o NotReady, eliminarlo
            if node_status in ["Unknown", "NotReady"]:
                logger.info(f"Eliminando nodo: {node_name} (Estado: {node_status})")
                
                try:
                    import requests
                    
                    # Primero remover finalizers usando PATCH
                    patch_url = f"{config.host}/api/v1/nodes/{node_name}"
                    patch_headers = {
                        'Authorization': config.api_key['authorization'],
                        'Content-Type': 'application/merge-patch+json'
                    }
                    patch_data = '{"metadata":{"finalizers":[]}}'
                    
                    patch_response = requests.patch(
                        patch_url, 
                        headers=patch_headers, 
                        data=patch_data,
                        verify=config.ssl_ca_cert,
                        timeout=30
                    )
                    
                    if patch_response.status_code in [200, 202]:
                        logger.info(f"Finalizers removidos del nodo: {node_name}")
                        
                        # Luego eliminar el nodo usando DELETE
                        delete_url = f"{config.host}/api/v1/nodes/{node_name}?gracePeriodSeconds=0"
                        delete_headers = {
                            'Authorization': config.api_key['authorization'],
                            'Content-Type': 'application/json'
                        }
                        
                        delete_response = requests.delete(
                            delete_url,
                            headers=delete_headers,
                            verify=config.ssl_ca_cert,
                            timeout=30
                        )
                        
                        if delete_response.status_code in [200, 202, 404]:
                            logger.info(f"Nodo eliminado exitosamente: {node_name}")
                            cleaned_nodes.append({"name": node_name, "status": node_status})
                        else:
                            logger.warning(f"Error eliminando nodo {node_name}: {delete_response.status_code} - {delete_response.text}")
                    else:
                        logger.warning(f"Error removiendo finalizers del nodo {node_name}: {patch_response.status_code}")
                        
                except Exception as e:
                    logger.warning(f"Error procesando nodo {node_name}: {e}")
                    
    except Exception as e:
        logger.error(f"Error en cleanup_nodes: {str(e)}")
    
    return cleaned_nodes

def cleanup_nodeclaims(custom_api):
    """Limpia finalizers de NodeClaims huérfanos"""
    cleaned_nodeclaims = []
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
                cleaned_nodeclaims.append({"name": nc_name})
            except ApiException as e:
                logger.warning(f"Error patcheando NodeClaim {nc_name}: {e}")
                
    except Exception as e:
        logger.error(f"Error en cleanup_nodeclaims: {str(e)}")
    
    return cleaned_nodeclaims
