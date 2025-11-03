#!/usr/bin/env python3
import boto3
import sys

def cleanup_dynamodb_table(table_name, profile='my-student-user'):
    """Limpia todos los registros de una tabla DynamoDB"""
    session = boto3.Session(profile_name=profile)
    dynamodb = session.resource('dynamodb', region_name='us-east-1')
    
    try:
        table = dynamodb.Table(table_name)
        
        # Scan para obtener todos los items
        response = table.scan()
        items = response['Items']
        
        # Continuar si hay más items
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            items.extend(response['Items'])
        
        print(f"Encontrados {len(items)} registros en {table_name}")
        
        if len(items) == 0:
            print("No hay registros para eliminar")
            return
        
        # Confirmar eliminación
        confirm = input(f"¿Eliminar {len(items)} registros? (y/N): ")
        if confirm.lower() != 'y':
            print("Operación cancelada")
            return
        
        # Eliminar en batches
        deleted = 0
        for item in items:
            table.delete_item(Key={'user_id': item['user_id'], 'file_id': item['file_id']})
            deleted += 1
            if deleted % 10 == 0:
                print(f"Eliminados {deleted}/{len(items)} registros...")
        
        print(f"✅ Eliminados {deleted} registros de {table_name}")
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    table_name = "gildarck-media-metadata-dev"
    
    if len(sys.argv) > 1:
        table_name = sys.argv[1]
    
    print(f"Limpiando tabla: {table_name}")
    cleanup_dynamodb_table(table_name)
