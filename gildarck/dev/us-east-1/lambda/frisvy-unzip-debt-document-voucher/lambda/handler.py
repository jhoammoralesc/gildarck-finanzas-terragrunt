import json
import boto3
import zipfile
import io
import os

# Nombre del bucket donde se guardarán los archivos procesados
env = os.environ.get('ENV', 'dev')
destination_bucket_name = f'ic-{env}-file-document-publication'

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    # Obtener información del evento
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_key = event['Records'][0]['s3']['object']['key']
    file_name = os.path.basename(file_key)
    
    try:
        # Obtener la ruta del directorio original
        original_directory = os.path.dirname(file_key)
        
        if file_name.endswith('.zip'):
            # Descargar el archivo .zip desde S3
            zip_file_obj = s3_client.get_object(Bucket=bucket_name, Key=file_key)
            zip_file_content = zip_file_obj['Body'].read()
            
            # Descomprimir el archivo .zip
            with zipfile.ZipFile(io.BytesIO(zip_file_content)) as z:
                for file_info in z.infolist():
                    # Leer el contenido del archivo
                    print(f'Archivo: {file_info.filename}')
                    with z.open(file_info) as extracted_file:
                        file_content = extracted_file.read()
                        
                        # Guardar el archivo descomprimido en el bucket de destino
                        # Mantener la estructura de carpetas dentro de /process
                        unzipped_file_key = os.path.join(original_directory, file_info.filename)
                        s3_client.put_object(
                            Bucket=destination_bucket_name,
                            Key=unzipped_file_key,
                            Body=file_content,
                            Tagging=f'extractedFromFile={file_key}'  # Agregar el tag
                        )
            return {
                'statusCode': 200,
                'body': json.dumps('Archivos descomprimidos y guardados exitosamente.')
            }
        # 
        return {
            'statusCode': 400,
            'body': json.dumps('Archivo no zip.')
        }
    
    except Exception as e:
        print(f'Error: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps('Error al procesar el archivo.')
        }