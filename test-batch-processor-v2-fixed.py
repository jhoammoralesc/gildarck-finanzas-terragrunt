#!/usr/bin/env python3

import boto3
import json
import time

# Configuración
SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/496860676881/gildarck-batch-queue-dev"
TEST_USER_ID = "test-user-batch-v2"
BATCH_ID = f"test-batch-{int(time.time())}"

def send_test_message():
    """Envía mensaje con formato correcto para batch processor v2"""
    sqs = boto3.client('sqs', region_name='us-east-1')
    
    # Mensaje con formato correcto (files en lugar de file_names)
    test_message = {
        "batch_id": BATCH_ID,
        "user_id": TEST_USER_ID,
        "files": [
            {"name": "test-image-1.jpg", "size": 1024000},
            {"name": "test-image-2.png", "size": 2048000}, 
            {"name": "test-video-1.mp4", "size": 10240000},
            {"name": "test-doc-1.pdf", "size": 512000},
            {"name": "test-image-3.webp", "size": 768000}
        ],
        "strategy": {
            "type": "batch",
            "chunk_size": 50
        },
        "timestamp": int(time.time())
    }
    
    print(f"🚀 Enviando mensaje SQS corregido para batch: {BATCH_ID}")
    print(f"📁 Archivos: {len(test_message['files'])}")
    
    response = sqs.send_message(
        QueueUrl=SQS_QUEUE_URL,
        MessageBody=json.dumps(test_message)
    )
    
    print(f"✅ Mensaje enviado - MessageId: {response['MessageId']}")
    return response['MessageId']

if __name__ == "__main__":
    print("🧪 TESTING BATCH PROCESSOR V2 - FORMATO CORREGIDO")
    print("=" * 50)
    
    # Enviar mensaje corregido
    message_id = send_test_message()
    
    print("\n⏳ Esperando procesamiento (15 segundos)...")
    time.sleep(15)
    
    # Verificar logs
    logs = boto3.client('logs', region_name='us-east-1')
    
    try:
        streams = logs.describe_log_streams(
            logGroupName="/aws/lambda/gildarck-batch-processor-v2-dev",
            orderBy='LastEventTime',
            descending=True,
            limit=1
        )
        
        if streams['logStreams']:
            stream_name = streams['logStreams'][0]['logStreamName']
            events = logs.get_log_events(
                logGroupName="/aws/lambda/gildarck-batch-processor-v2-dev",
                logStreamName=stream_name,
                startTime=int((time.time() - 300) * 1000)
            )
            
            print(f"\n📋 Logs recientes:")
            for event in events['events'][-8:]:
                timestamp = time.strftime('%H:%M:%S', time.localtime(event['timestamp']/1000))
                message = event['message'].strip()
                if 'Processing batch' in message or 'completed' in message or 'URLs' in message:
                    print(f"  {timestamp}: {message}")
                    
    except Exception as e:
        print(f"❌ Error verificando logs: {e}")
    
    print(f"\n🎯 Batch ID: {BATCH_ID}")
    print("✅ Test completado")
