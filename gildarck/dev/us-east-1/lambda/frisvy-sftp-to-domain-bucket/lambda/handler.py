import json
import boto3
import urllib.parse
from typing import Dict, Optional
import os
from datetime import datetime

# Configuración de mapeo dominio -> bucket destino
# Se soporta el mapeo de COMPANY y FILENAME dinámicamente
# Ejemplo: 'gildarck-document-files': 'ic-dev-document-publication-by-file/COMPANY/process/FILE_NAME',
env = os.environ.get('ENV', 'dev')
DOMAIN_BUCKET_MAPPING = {
    'gildarck-document-files': f'ic-{env}-document-publication-by-file',
    'rtp-lots': f'ic-{env}-rtp-files/COMPANY/rtp/in/FILE_NAME',
    'gildarck-file-document-publication': f'ic-{env}-file-document-publication/COMPANY/YEAR/MONTH/FILE_NAME'
}

# Cliente S3
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Función Lambda que procesa archivos desde EventBridge
    """
    
    print(f"Evento recibido: {json.dumps(event)}")
    
    try:
        # Extraer información del evento EventBridge
        bucket_name = event['detail']['bucket']['name']
        object_key = event['detail']['object']['key']
        
        print(f"Procesando archivo: {object_key} en bucket: {bucket_name}")
        
        # Validar que el object key contenga /input/
        if '/input/' not in object_key:
            print(f"Archivo ignorado - no contiene /input/: {object_key}")
            return {
                'statusCode': 200,
                'body': json.dumps('Archivo ignorado - no está en carpeta input')
            }
        
        # Procesar el archivo
        result = process_file(bucket_name, object_key)
        
        if result['success']:
            print(f"Archivo procesado exitosamente: {result['message']}")
        else:
            print(f"Error procesando archivo: {result['error']}")
                
    except Exception as e:
        print(f"Error en lambda_handler: {str(e)}")
        raise
    
    return {
        'statusCode': 200,
        'body': json.dumps('Procesamiento completado')
    }

def process_file(source_bucket: str, object_key: str) -> Dict:
    """
    Procesa un archivo individual y lo mueve al bucket correspondiente
    """
    
    try:
        # Parsear la estructura del path
        path_info = parse_s3_path(object_key)
        
        if not path_info['valid']:
            return {
                'success': False,
                'error': f"Estructura de path inválida: {object_key}"
            }
        
        company_id = path_info['company_id']
        business_domain = path_info['business_domain']
        file_path = path_info['file_path']
        file_name = path_info['file_name']
        
        # Obtener bucket destino basado en el dominio
        destination = get_destination_bucket(business_domain)
        if not destination:
            return {
                'success': False,
                'error': f"No se encontró información destino para dominio: {business_domain}"
            }
        
        destination_bucket = destination['bucket']
        if not destination_bucket:
            return {
                'success': False,
                'error': f"No se encontró bucket destino para dominio: {business_domain}"
            }

        # Get the current date and time
        current_datetime = datetime.now()
        # Extract the year
        current_year = current_datetime.year
        # Extract the month
        current_month = current_datetime.month
        # Set default destination key
        destination_key = f"{company_id}/{file_name}"
        # If exist specific path for destination, override
        if destination['path'] and destination['path'] != '':
            destination_key = destination['path'].replace('FILE_NAME', file_name).replace('COMPANY', company_id).replace('YEAR',str(current_year)).replace('MONTH',str(current_month))
        
        # Copiar archivo al bucket destino
        copy_result = copy_file_to_destination(
            source_bucket, 
            object_key, 
            destination_bucket, 
            destination_key
        )
        
        if copy_result['success']:
            # Eliminar archivo del bucket origen
            delete_source_file(source_bucket, object_key)
            
            return {
                'success': True,
                'message': f"Archivo movido de {source_bucket}/{object_key} a {destination_bucket}/{destination_key}"
            }
        else:
            return {
                'success': False,
                'error': copy_result['error']
            }
            
    except Exception as e:
        return {
            'success': False,
            'error': f"Error procesando archivo {object_key}: {str(e)}"
        }

def parse_s3_path(object_key: str) -> Dict:
    """
    Parsea la estructura del path S3 y extrae company_id, business_domain, y file_path
    Estructura esperada: company_id/business_domain/input/filename
    """
    
    try:
        path_parts = object_key.split('/')
        
        # Validar estructura mínima
        if len(path_parts) < 4:
            return {'valid': False}
        
        company_id = path_parts[0]
        business_domain = path_parts[1]
        input_folder = path_parts[2]
        file_name = path_parts[-1]

        if '.' not in file_name:
            return {'valid': False}
        
        # El file_path incluye todo después del business_domain
        file_path = '/'.join(path_parts[2:])
        
        # Validar que company_id no esté vacío
        if not company_id or company_id.strip() == '':
            return {'valid': False}
        
        # Validar que business_domain no esté vacío
        if not business_domain or business_domain.strip() == '':
            return {'valid': False}

        if not input_folder or input_folder.strip() != 'input':
            return {'valid': False}
        
        return {
            'valid': True,
            'company_id': company_id,
            'business_domain': business_domain,
            'file_path': file_path,
            'file_name': file_name
        }
        
    except Exception as e:
        print(f"Error parseando path {object_key}: {str(e)}")
        return {'valid': False}

def get_destination_bucket(business_domain: str) -> Optional[str]:
    """
    Obtiene el bucket destino basado en el dominio de negocio
    """
    
    # Primero buscar en variables de entorno (para configuración dinámica)
    env_bucket = os.environ.get(f"BUCKET_{business_domain.upper().replace('-', '_')}")
    if env_bucket:
        return env_bucket
    
    # Luego buscar en el mapeo estático
    bucket_path = DOMAIN_BUCKET_MAPPING.get(business_domain)

    path_parts = bucket_path.split('/') if bucket_path else []
    if len(path_parts) == 0:
        return None

    return {
        'bucket': path_parts[0],
        'path': '/'.join(path_parts[1:]) if len(path_parts) > 1 else ''
    }

def copy_file_to_destination(source_bucket: str, source_key: str, 
                           destination_bucket: str, destination_key: str) -> Dict:
    """
    Copia el archivo del bucket origen al bucket destino
    """
    
    try:
        print(f"Copiando archivo a {destination_bucket}/{destination_key}")
        # Verificar que el bucket destino existe
        s3_client.head_bucket(Bucket=destination_bucket)
        
        # Copiar el archivo
        copy_source = {
            'Bucket': source_bucket,
            'Key': source_key
        }
        
        s3_client.copy_object(
            CopySource=copy_source,
            Bucket=destination_bucket,
            Key=destination_key,
            # Preservar metadatos del archivo original
            MetadataDirective='COPY'
        )
        
        return {
            'success': True,
            'message': f"Archivo copiado exitosamente a {destination_bucket}/{destination_key}"
        }
        
    except s3_client.exceptions.NoSuchBucket:
        return {
            'success': False,
            'error': f"Bucket destino no existe: {destination_bucket}"
        }
    except Exception as e:
        return {
            'success': False,
            'error': f"Error copiando archivo: {str(e)}"
        }

def delete_source_file(bucket: str, key: str) -> None:
    """
    Elimina el archivo del bucket origen después de copiarlo exitosamente
    """
    
    try:
        s3_client.delete_object(Bucket=bucket, Key=key)
        print(f"Archivo eliminado del origen: {bucket}/{key}")
    except Exception as e:
        print(f"Error eliminando archivo origen {bucket}/{key}: {str(e)}")
        # No fallar la función si no se puede eliminar el origen