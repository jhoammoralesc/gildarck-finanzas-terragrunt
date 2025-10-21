import json
import boto3
import urllib.parse
from typing import Dict, Optional, List
import os
import re
from datetime import datetime

# Configuración de mapeo bucket/path origen -> destination_path
# Formato con placeholders dinámicos: 'bucket-origen/COMPANY/path': 'bucket-destino/path/template'

env = os.environ.get('ENV', 'dev')
BUCKET_MAPPING = {
    f'ic-{env}-rtp-files/COMPANY/rtp/process-results': f'gildarck-{env}-client-sftp-files/COMPANY/rtp-lots/output/process-results/YEAR-MONTH/FILE_NAME',
    f'ic-{env}-rtp-files/COMPANY/rtp/report': f'gildarck-{env}-client-sftp-files/COMPANY/rtp-lots/output/report/FILE_NAME',
    f'ic-{env}-renditions/COMPANY/output': f'gildarck-{env}-client-sftp-files/COMPANY/gildarck-payment-order-rendition/output/FILE_NAME'
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
        
        print(f"Procesando archivo inverso: {object_key} en bucket: {bucket_name}")
        
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
        'body': json.dumps('Procesamiento inverso completado')
    }

def process_file(source_bucket: str, object_key: str) -> Dict:
    """
    Procesa un archivo desde bucket de dominio hacia bucket de salida
    """
    
    try:
        # Parsear la información del archivo en el bucket de dominio
        file_info = parse_domain_bucket_path(source_bucket, object_key)
        
        if not file_info['valid']:
            return {
                'success': False,
                'error': f"No se pudo procesar el archivo del bucket de dominio: {object_key}"
            }
        
        company_id = file_info['company_id']
        file_name = file_info['file_name']
        
        # Buscar configuración que haga match con el path completo
        match_result = find_matching_configuration(source_bucket, object_key, company_id)
        
        if not match_result['found']:
            return {
                'success': False,
                'error': f"No se encontró configuración que haga match para: {source_bucket}/{object_key}"
            }
        
        destination_path = match_result['destination_path']
        matched_pattern = match_result['matched_pattern']
        
        print(f"Match encontrado: {matched_pattern} -> {destination_path}")
        
        # Parsear destination_path para extraer bucket y key
        destination_info = parse_destination_path(destination_path, company_id, file_name)
        
        if not destination_info['valid']:
            return {
                'success': False,
                'error': f"Destination path inválido: {destination_path}"
            }
        
        output_bucket = destination_info['bucket']
        destination_key = destination_info['key']
        
        # Copiar archivo al bucket de salida
        copy_result = copy_file_to_output(
            source_bucket, 
            object_key, 
            output_bucket, 
            destination_key,
            company_id
        )
        
        if copy_result['success']:
            # Opcional: Marcar archivo como procesado
            mark_as_processed(source_bucket, object_key)
            
            return {
                'success': True,
                'message': f"Archivo copiado de {source_bucket}/{object_key} a {output_bucket}/{destination_key}"
            }
        else:
            return {
                'success': False,
                'error': copy_result['error']
            }
            
    except Exception as e:
        return {
            'success': False,
            'error': f"Error procesando archivo inverso {object_key}: {str(e)}"
        }

def parse_domain_bucket_path(bucket_name: str, object_key: str) -> Dict:
    """
    Parsea el path del archivo en el bucket de dominio
    """
    
    try:
        path_parts = object_key.split('/')
        file_name = path_parts[-1]
        
        # Extraer company_id del primer segmento del path
        company_id = path_parts[0] if len(path_parts) >= 1 else None
        
        if not company_id:
            return {'valid': False}
        
        return {
            'valid': True,
            'company_id': company_id,
            'file_name': file_name,
            'full_path': object_key
        }
        
    except Exception as e:
        print(f"Error parseando path de dominio {object_key}: {str(e)}")
        return {'valid': False}

def find_matching_configuration(source_bucket: str, object_key: str, company_id: str) -> Dict:
    """
    Busca una configuración que haga match con el path del archivo
    Soporta placeholders dinámicos como COMPANY
    """
    
    try:
        # Construir el path completo del archivo
        full_source_path = f"{source_bucket}/{object_key}"
        
        print(f"Buscando match para: {full_source_path}")
        
        # Buscar en variables de entorno primero
        env_result = find_env_matching_configuration(source_bucket, object_key, company_id)
        if env_result['found']:
            return env_result
        
        # Buscar en mapeo estático
        static_result = find_static_matching_configuration(full_source_path, company_id)
        if static_result['found']:
            return static_result
        
        # Buscar fallback por bucket solo
        fallback_result = find_fallback_configuration(source_bucket)
        if fallback_result['found']:
            return fallback_result
        
        return {'found': False}
        
    except Exception as e:
        print(f"Error buscando configuración para {source_bucket}/{object_key}: {str(e)}")
        return {'found': False}

def find_static_matching_configuration(full_source_path: str, company_id: str) -> Dict:
    """
    Busca match en el mapeo estático
    """
    
    for pattern, destination_path in BUCKET_MAPPING.items():
        if pattern_matches_path(pattern, full_source_path, company_id):
            print(f"Match encontrado en mapeo estático: {pattern}")
            return {
                'found': True,
                'destination_path': destination_path,
                'matched_pattern': pattern
            }
    
    return {'found': False}

def find_env_matching_configuration(source_bucket: str, object_key: str, company_id: str) -> Dict:
    """
    Busca match en variables de entorno
    """
    
    # Construir posibles keys de variables de entorno
    # Esto es más complejo con placeholders dinámicos, por simplicidad
    # mantenemos la búsqueda básica por bucket
    bucket_env_key = source_bucket.upper().replace('-', '_')
    env_destination_path = os.environ.get(f"DESTINATION_PATH_{bucket_env_key}")
    
    if env_destination_path:
        print(f"Encontrada configuración en variable de entorno: DESTINATION_PATH_{bucket_env_key}")
        return {
            'found': True,
            'destination_path': env_destination_path,
            'matched_pattern': f"ENV:{bucket_env_key}"
        }
    
    return {'found': False}

def find_fallback_configuration(source_bucket: str) -> Dict:
    """
    Busca configuración fallback por bucket solo
    """
    
    if source_bucket in BUCKET_MAPPING:
        print(f"Usando configuración fallback: {source_bucket}")
        return {
            'found': True,
            'destination_path': BUCKET_MAPPING[source_bucket],
            'matched_pattern': source_bucket
        }
    
    return {'found': False}

def pattern_matches_path(pattern: str, full_path: str, company_id: str) -> bool:
    """
    Verifica si un patrón hace match con un path
    Soporta placeholder COMPANY
    """
    
    try:
        # Reemplazar COMPANY en el patrón con el company_id real
        resolved_pattern = pattern.replace('COMPANY', company_id)
        
        # Verificar match exacto (sin considerar el filename)
        # Extraer path sin filename
        path_parts = full_path.split('/')
        path_without_filename = '/'.join(path_parts[:-1])
        
        # Comparar paths
        if resolved_pattern == path_without_filename:
            return True
        
        # También verificar si el patrón incluye el filename
        if resolved_pattern == full_path:
            return True
        
        # Verificar match con wildcards o regex si es necesario
        # Por ahora mantenemos match exacto
        
        return False
        
    except Exception as e:
        print(f"Error verificando match entre {pattern} y {full_path}: {str(e)}")
        return False

def parse_destination_path(destination_path: str, company_id: str, file_name: str) -> Dict:
    """
    Parsea el destination_path y reemplaza los placeholders
    Formato esperado: bucket/path/template (sin s3://)
    """
    
    try:
        # Dividir bucket/key directamente
        path_parts = destination_path.split('/', 1)
        
        if len(path_parts) < 2:
            # Si solo hay bucket sin path, usar el filename directamente
            bucket = destination_path
            key_template = file_name
        else:
            bucket = path_parts[0]
            key_template = path_parts[1]

        # Get the current date and time
        current_datetime = datetime.now()
        # Extract the year
        current_year = current_datetime.year
        # Extract the month
        current_month = current_datetime.month
        
        # Reemplazar placeholders
        final_key = key_template.replace('COMPANY', company_id)
        final_key = final_key.replace('FILE_NAME', file_name)
        final_key = final_key.replace('YEAR', str(current_year))
        final_key = final_key.replace('MONTH', str(current_month))
        
        return {
            'valid': True,
            'bucket': bucket,
            'key': final_key
        }
        
    except Exception as e:
        print(f"Error parseando destination_path {destination_path}: {str(e)}")
        return {'valid': False}

def copy_file_to_output(source_bucket: str, source_key: str, 
                       output_bucket: str, output_key: str,
                       company_id: str) -> Dict:
    """
    Copia el archivo del bucket de dominio al bucket de salida
    """
    
    try:
        print(f"Copiando archivo a salida: {output_bucket}/{output_key}")
        
        # Verificar que el bucket de salida existe
        s3_client.head_bucket(Bucket=output_bucket)
        
        # Copiar el archivo con metadatos adicionales
        copy_source = {
            'Bucket': source_bucket,
            'Key': source_key
        }
        
        # Agregar metadatos personalizados
        metadata = {
            'company-id': company_id,
            'processed-timestamp': datetime.now().isoformat(),
            'source-bucket': source_bucket,
            'source-key': source_key
        }
        
        s3_client.copy_object(
            CopySource=copy_source,
            Bucket=output_bucket,
            Key=output_key,
            Metadata=metadata,
            MetadataDirective='REPLACE'
        )
        
        return {
            'success': True,
            'message': f"Archivo copiado exitosamente a {output_bucket}/{output_key}"
        }
        
    except s3_client.exceptions.NoSuchBucket:
        return {
            'success': False,
            'error': f"Bucket de salida no existe: {output_bucket}"
        }
    except Exception as e:
        return {
            'success': False,
            'error': f"Error copiando archivo a salida: {str(e)}"
        }

def mark_as_processed(bucket: str, key: str) -> None:
    """
    Marca el archivo como procesado agregando tags
    """
    
    try:
        s3_client.put_object_tagging(
            Bucket=bucket,
            Key=key,
            Tagging={
                'TagSet': [
                    {
                        'Key': 'movedToSftp',
                        'Value': datetime.now().isoformat()
                    }
                ]
            }
        )
        
        print(f"Archivo marcado como procesado: {bucket}/{key}")
        
    except Exception as e:
        print(f"Error marcando archivo como procesado {bucket}/{key}: {str(e)}")
        # No fallar la función si no se puede marcar como procesado