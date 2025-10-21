import json
import os
import requests

def lambda_handler(event, context):
    # Obtener información del evento de S3
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_key = event['Records'][0]['s3']['object']['key']
    
    # Validar que el file_key tenga por lo menos un / ( COMPANY_ID/..)
    if file_key.count('/') == 0:
        return {
            'statusCode': 400,
            'body': json.dumps('Error: El file_key con estructura inesperada.')
        }
    
    # Extraer el collector_document_number del file_key
    collector_document_number = file_key.split('/')[0]  # Toma la primera parte del path
    
    # Obtener el endpoint de la variable de entorno
    endpoint_url = os.environ.get('API_URL')
    
    # Verificar que el endpoint_url no sea None
    if endpoint_url is None:
        return {
            'statusCode': 500,
            'body': json.dumps('Error: API_URL no está configurada.')
        }
    
    # Datos a enviar en la notificación
    payload = {
        "file_path": file_key,
        "collector_document_number": collector_document_number,
        "collector_document_type": "CUIT"
    }
    
    # Realizar la solicitud POST
    try:
        response = requests.post(endpoint_url, json=payload, headers={
            'accept': 'application/json',
            'Content-Type': 'application/json'
        })
        
        # Comprobar la respuesta
        if response.status_code == 200:
            print("Notificación enviada correctamente.")
        else:
            print(f"Error al enviar la notificación: {response.status_code} - {response.text}")
    
    except Exception as e:
        print(f"Ocurrió un error al enviar la notificación: {str(e)}")

    return {
        'statusCode': 200,
        'body': json.dumps('Proceso completado')
    }