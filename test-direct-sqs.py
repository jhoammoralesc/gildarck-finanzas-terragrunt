#!/usr/bin/env python3

import boto3
import json
import time

# Initialize AWS clients
session = boto3.Session(profile_name='my-student-user')
sqs = session.client('sqs', region_name='us-east-1')
logs = session.client('logs', region_name='us-east-1')

# Configuration
QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/496860676881/gildarck-batch-queue-dev"
LOG_GROUP = "/aws/lambda/gildarck-batch-processor-v2-dev"

def send_test_message():
    """Send a simple test message to SQS"""
    
    # Create test message
    message = {
        'batch_id': 'test-debug-batch',
        'user_id': 'test-user-debug',
        'files': [
            {
                'filename': 'test1.jpg',
                'contentType': 'image/jpeg',
                'size': 1024
            },
            {
                'filename': 'test2.jpg', 
                'contentType': 'image/jpeg',
                'size': 2048
            }
        ],
        'strategy': {'type': 'chunked'}
    }
    
    print("🚀 Sending test message to SQS...")
    print(f"📋 Message: {json.dumps(message, indent=2)}")
    
    # Send message
    response = sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(message)
    )
    
    print(f"✅ Message sent! MessageId: {response['MessageId']}")
    return response['MessageId']

def check_logs():
    """Check recent Lambda logs"""
    
    print("\n⏳ Waiting 10 seconds for Lambda processing...")
    time.sleep(10)
    
    print("📋 Checking Lambda logs...")
    
    # Get recent logs (last 5 minutes)
    start_time = int((time.time() - 300) * 1000)
    
    try:
        response = logs.filter_log_events(
            logGroupName=LOG_GROUP,
            startTime=start_time,
            limit=50
        )
        
        events = response.get('events', [])
        
        if events:
            print(f"✅ Found {len(events)} log events:")
            for event in events[-10:]:  # Show last 10 events
                timestamp = time.strftime('%H:%M:%S', time.localtime(event['timestamp']/1000))
                print(f"  [{timestamp}] {event['message'].strip()}")
        else:
            print("❌ No recent log events found")
            
    except Exception as e:
        print(f"❌ Error checking logs: {e}")

if __name__ == "__main__":
    print("🧪 Direct SQS Test for Batch Processor")
    print("=" * 50)
    
    # Send test message
    message_id = send_test_message()
    
    # Check logs
    check_logs()
    
    print("\n🏁 Test completed!")
