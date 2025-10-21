import boto3
import json
import os
import re
import random
import string
import base64
from kubernetes import client
from kubernetes.client.rest import ApiException
from botocore.signers import RequestSigner
import time



STS_TOKEN_EXPIRES_IN = 60
session = boto3.session.Session()
region: str = "us-east-1"
sts = session.client('sts')
sts_client = boto3.client('sts')
eks_client = boto3.client('eks', region_name=region)
secret_client = boto3.client('secretsmanager')
rds_client = boto3.client('rds')
service_id = sts.meta.service_model.service_id
role_to_assume = os.environ['ROLE_TO_ASSUME']
env = os.environ['ENV']
cluster_name = f"eks-{env}-1"
ib_namespace = f"gildarck-{env}"
flexy_namespace = f"flexibility-{env}" 

v1 = None
eks_client = boto3.client('eks')

secret_names = [
    {
        "name": "core-db-secret",
        "db": "core", 
        "password": "7wXLHgZ8jWQfpQKtmWvdzuKH", # borrar
        "new_password": ""
    },
    {
        "name": "fm-db-secret",
        "db": "fm",
        "password": "L746fa2KFVxZ6b", # borrar
        "new_password": ""
    },
    {
        "name": "flexy-db-secret",
        "db": "flexibility",
        "password": "94VfCdnWHomtJ.QfXm!MnKnAci_6MA", # borrar
        "new_password": ""
    }
]


def configure_eks_client():
    """
    Configura el cliente de Kubernetes para EKS
    """
    try:
        # Obtener información del cluster
        cluster_info = eks_client.describe_cluster(name=cluster_name)
        cluster_cert = cluster_info['cluster']['certificateAuthority']['data']
        cluster_endpoint = cluster_info['cluster']['endpoint']
        
        # Obtener token
        token = get_token()
        
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
        print(f"Error configurando el cliente: {e}")
        raise


def get_token():
    "Create authentication token"
    
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

def generate_password(length=24):
    """Genera una contraseña aleatoria."""
    characters = string.ascii_letters + string.digits
    return ''.join(random.choice(characters) for _ in range(length))

def lambda_handler(event, context):
    eks_api = configure_eks_client()
    v1 = eks_api.CoreV1Api()
    apps_v1 = eks_api.AppsV1Api()

    # Listar todos los secretos y actualizar los necesarios
    paginator = secret_client.get_paginator('list_secrets')
    
    for secret_name in secret_names:
        # Obtener el secreto
        secret_response = secret_client.get_secret_value(SecretId=secret_name["name"])
        secret = json.loads(secret_response['SecretString'])

        # Actualiza el secreto en Secrets Manager
        new_password = generate_password()
        # new_password = secret_name["password"] # borrar
        secret['DB_PASSWORD'] = new_password
        secret_name["new_password"] = new_password
        
        secret_client.put_secret_value(SecretId=secret_name["name"], SecretString=json.dumps(secret))

        # Cambia la clave maestra del clúster de RDS
        try:
            rds_client.modify_db_cluster(
                ApplyImmediately=True,
                DBClusterIdentifier=secret['CLUSTER'],  # Asegúrate de que este campo esté presente en el secreto
                MasterUserPassword=new_password
            )
            print(f"Clave maestra del clúster {secret['CLUSTER']} actualizada correctamente.")
        except Exception as e:
            print(f"Error al actualizar la clave maestra del clúster {secret['CLUSTER']}: {e}")


    for page in paginator.paginate():
        for secret in page['SecretList']:
            secret_detail = secret_client.get_secret_value(SecretId=secret['Name'])
            secret_value = json.loads(secret_detail['SecretString'])
            # Validación porque bussines-logic tienen acceso a dos DBs (Core y FM)
            if secret['Name'] == "ic-api-business-logic":
                secret_value["SPRING_DATASOURCE_BUSINESS_PASSWORD"] = [secret["new_password"] for secret in secret_names if secret["db"] == 'core'][0]
                secret_value["SPRING_DATASOURCE_FILEMANAGER_PASSWORD"] = [secret["new_password"] for secret in secret_names if secret["db"] == 'fm'][0]
                secret_client.put_secret_value(SecretId=secret['Name'], SecretString=json.dumps(secret_value))
                delete_k8s_secret(v1, ib_namespace, secret['Name'])
            
            # Validación porque flexibility tiene un key diferente
            elif secret['Name'] == 'flexibility-global-secret':
                secret_value["PROJECT_SQL_PASSWORD"] = [secret["new_password"] for secret in secret_names if secret["db"] == 'flexibility'][0]
                secret_client.put_secret_value(SecretId=secret['Name'], SecretString=json.dumps(secret_value))
                delete_k8s_secret(v1, flexy_namespace, secret['Name'])

            else:
                database_url = secret_value.get('SPRING_DATASOURCE_URL')
                if database_url and any("core" in database_url for sn in secret_names):
                    secret_value['SPRING_DATASOURCE_PASSWORD'] = [secret["new_password"] for secret in secret_names if secret["db"] == 'core'][0]
                if database_url and any("fm" in database_url for sn in secret_names):
                    secret_value['SPRING_DATASOURCE_PASSWORD'] = [secret["new_password"] for secret in secret_names if secret["db"] == 'fm'][0]
                secret_client.put_secret_value(SecretId=secret['Name'], SecretString=json.dumps(secret_value))
                delete_k8s_secret(v1, ib_namespace, secret['Name'])
            print(f"Secreto '{secret['Name']}' actualizado correctamente.")

    # Reinicia los deployments en el namespace específico
    restart_deployments(apps_v1, ib_namespace)
    restart_deployments(apps_v1, flexy_namespace)

def delete_k8s_secret(v1, namespace: str, secret_name: str) -> bool:
    """
    Elimina un secreto específico de un namespace en Kubernetes.
    
    Returns:
        bool: True si el secreto fue eliminado correctamente, False en caso contrario
    """
    try:
        # Intentar eliminar el secreto
        v1.delete_namespaced_secret(
            name=secret_name,
            namespace=namespace
        )
        
        print(f"Secreto '{secret_name}' eliminado exitosamente del namespace '{namespace}'")
        return True
        
    except ApiException as e:
        if e.status == 404:
            print(f"El secreto '{secret_name}' no existe en el namespace '{namespace}'")
        else:
            print(f"Error al eliminar el secreto '{secret_name}': {e}")
        return False
        
    except Exception as e:
        print(f"Error inesperado al eliminar el secreto '{secret_name}': {e}")
        return False


def restart_deployments(apps_v1, namespace: str):
    """
    Reinicia deployments escalando a 0 y luego al número original de réplicas
    """
    try:
        deployments = apps_v1.list_namespaced_deployment(namespace)
        
        for deployment in deployments.items:
            deployment_name = deployment.metadata.name
            current_replicas = deployment.spec.replicas
            
            print(f"\nReiniciando deployment '{deployment_name}'")
            print(f"Número actual de réplicas: {current_replicas}")
            
            try:
                # Escalar a 0
                print(f"Escalando '{deployment_name}' a 0 réplicas...")
                apps_v1.patch_namespaced_deployment_scale(
                    name=deployment_name,
                    namespace=namespace,
                    body={'spec': {'replicas': 0}}
                )
                
                time.sleep(1)
                
                print(f"Deployment '{deployment_name}' escalado a 0 réplicas exitosamente")
                
                # Escalar al número original de réplicas
                print(f"Escalando '{deployment_name}' de vuelta a {current_replicas} réplicas...")
                apps_v1.patch_namespaced_deployment_scale(
                    name=deployment_name,
                    namespace=namespace,
                    body={'spec': {'replicas': current_replicas}}
                )
                
                time.sleep(1)
                
            except ApiException as e:
                print(f"Error al escalar deployment '{deployment_name}': {e}")
                continue
                
    except ApiException as e:
        print(f"Error de API: {e}")
    except Exception as e:
        print(f"Error inesperado: {e}")