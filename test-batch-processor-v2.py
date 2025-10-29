#!/usr/bin/env python3

import boto3
import json
import time
import uuid

# Configuración
SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/496860676881/gildarck-batch-queue-dev"
TEST_USER_ID = "test-user-batch-v2"
BATCH_ID = f"test-batch-{int(time.time())}"

def send_test_message():
    """Envía mensaje de prueba al SQS para batch processor v2"""
    sqs = boto3.client('sqs', region_name='us-east-1')
    
    # Mensaje de prueba con 5 archivos
    test_message = {
        "batch_id": BATCH_ID,
        "user_id": TEST_USER_ID,
        "file_names": [
            "test-image-1.jpg",
            "test-image-2.png", 
            "test-video-1.mp4",
            "test-doc-1.pdf",
            "test-image-3.webp"
        ],
        "timestamp": int(time.time())
    }
    
    print(f"🚀 Enviando mensaje SQS para batch: {BATCH_ID}")
    print(f"📁 Archivos: {len(test_message['file_names'])}")
    
    response = sqs.send_message(
        QueueUrl=SQS_QUEUE_URL,
        MessageBody=json.dumps(test_message)
    )
    
    print(f"✅ Mensaje enviado - MessageId: {response['MessageId']}")
    return response['MessageId']

def check_logs():
    """Verifica logs del batch processor"""
    logs = boto3.client('logs', region_name='us-east-1')
    
    print("\n🔍 Verificando logs del batch processor...")
    
    try:
        # Obtener último log stream
        streams = logs.describe_log_streams(
            logGroupName="/aws/lambda/gildarck-batch-processor-v2-dev",
            orderBy='LastEventTime',
            descending=True,
            limit=1
        )
        
        if streams['logStreams']:
            stream_name = streams['logStreams'][0]['logStreamName']
            
            # Obtener eventos recientes
            events = logs.get_log_events(
                logGroupName="/aws/lambda/gildarck-batch-processor-v2-dev",
                logStreamName=stream_name,
                startTime=int((time.time() - 300) * 1000)  # Últimos 5 minutos
            )
            
            print(f"📋 Logs recientes ({len(events['events'])} eventos):")
            for event in events['events'][-10:]:  # Últimos 10 eventos
                timestamp = time.strftime('%H:%M:%S', time.localtime(event['timestamp']/1000))
                print(f"  {timestamp}: {event['message'].strip()}")
        else:
            print("⚠️  No hay log streams disponibles")
            
    except Exception as e:
        print(f"❌ Error verificando logs: {e}")

def check_sqs_status():
    """Verifica estado de la cola SQS"""
    sqs = boto3.client('sqs', region_name='us-east-1')
    
    print("\n📨 Estado de la cola SQS:")
    
    attrs = sqs.get_queue_attributes(
        QueueUrl=SQS_QUEUE_URL,
        AttributeNames=['ApproximateNumberOfMessages', 'ApproximateNumberOfMessagesNotVisible']
    )
    
    visible = attrs['Attributes']['ApproximateNumberOfMessages']
    processing = attrs['Attributes']['ApproximateNumberOfMessagesNotVisible']
    
    print(f"  • Mensajes pendientes: {visible}")
    print(f"  • Mensajes procesando: {processing}")

if __name__ == "__main__":
    print("🧪 TESTING BATCH PROCESSOR V2")
    print("=" * 40)
    
    # 1. Verificar estado inicial
    check_sqs_status()
    
    # 2. Enviar mensaje de prueba
    message_id = send_test_message()
    
    # 3. Esperar procesamiento
    print("\n⏳ Esperando procesamiento (10 segundos)...")
    time.sleep(10)
    
    # 4. Verificar estado final
    check_sqs_status()
    
    # 5. Revisar logs
    check_logs()
    
    print(f"\n🎯 Batch ID para seguimiento: {BATCH_ID}")
    print("✅ Test completado - Revisar logs para validar funcionamiento")
