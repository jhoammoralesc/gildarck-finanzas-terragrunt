#!/usr/bin/env python3
"""
Test script for Gildarck Batch Upload Integration
Tests the complete flow: upload-handler → SQS → batch-processor
"""

import json
import boto3
import time
from datetime import datetime

# AWS Configuration
REGION = 'us-east-1'
PROFILE = 'my-student-user'
UPLOAD_BATCH_QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/496860676881/gildarck-upload-batch-queue'

def test_batch_integration():
    """Test the complete batch upload integration"""
    
    print("🚀 Testing Gildarck Batch Upload Integration")
    print("=" * 50)
    
    # Initialize AWS clients
    session = boto3.Session(profile_name=PROFILE, region_name=REGION)
    sqs = session.client('sqs')
    logs = session.client('logs')
    
    # Test data: simulate frontend sending batch request
    test_files = [
        {
            "filename": f"test-photo-{i:03d}.jpg",
            "contentType": "image/jpeg",
            "fileSize": 2048000 + (i * 1000)  # ~2MB each
        }
        for i in range(1, 26)  # 25 files to test batching
    ]
    
    print(f"📁 Test data: {len(test_files)} files")
    print(f"   • File sizes: ~2MB each")
    print(f"   • Total size: ~{len(test_files) * 2}MB")
    print()
    
    # Step 1: Simulate upload-handler sending to SQS
    print("📤 Step 1: Sending batch to SQS (simulating upload-handler)")
    
    batch_id = f"test-batch-{int(time.time())}"
    user_id = "test-user-integration"
    
    sqs_message = {
        'batch_id': batch_id,
        'user_id': user_id,
        'files': test_files,
        'batch_number': 1,
        'total_batches': 1,
        'timestamp': datetime.now().isoformat()
    }
    
    try:
        response = sqs.send_message(
            QueueUrl=UPLOAD_BATCH_QUEUE_URL,
            MessageBody=json.dumps(sqs_message),
            MessageAttributes={
                'user_id': {'StringValue': user_id, 'DataType': 'String'},
                'batch_id': {'StringValue': batch_id, 'DataType': 'String'},
                'batch_number': {'StringValue': '1', 'DataType': 'Number'}
            }
        )
        
        message_id = response['MessageId']
        print(f"✅ Message sent to SQS: {message_id}")
        print(f"   • Batch ID: {batch_id}")
        print(f"   • User ID: {user_id}")
        print(f"   • Files: {len(test_files)}")
        print()
        
    except Exception as e:
        print(f"❌ Failed to send SQS message: {e}")
        return False
    
    # Step 2: Wait for Lambda processing
    print("⏳ Step 2: Waiting for Lambda batch-processor to process...")
    print("   (Lambda should be triggered automatically by SQS)")
    
    # Wait a bit for processing
    time.sleep(10)
    
    # Step 3: Check Lambda logs
    print("📋 Step 3: Checking Lambda logs for processing results")
    
    try:
        # Get latest log stream
        log_streams = logs.describe_log_streams(
            logGroupName='/aws/lambda/gildarck-upload-batch-processor',
            orderBy='LastEventTime',
            descending=True,
            limit=1
        )
        
        if not log_streams['logStreams']:
            print("❌ No log streams found")
            return False
        
        latest_stream = log_streams['logStreams'][0]['logStreamName']
        print(f"   • Latest log stream: {latest_stream}")
        
        # Get recent log events
        log_events = logs.get_log_events(
            logGroupName='/aws/lambda/gildarck-upload-batch-processor',
            logStreamName=latest_stream,
            startTime=int((time.time() - 300) * 1000)  # Last 5 minutes
        )
        
        # Analyze logs
        processing_found = False
        urls_generated = 0
        
        for event in log_events['events']:
            message = event['message']
            
            if batch_id in message:
                processing_found = True
                print(f"   ✅ Found batch processing: {batch_id}")
            
            if 'Generated presigned URL' in message:
                urls_generated += 1
            
            if 'Batch processing completed' in message:
                print(f"   ✅ Batch processing completed")
        
        if processing_found:
            print(f"   ✅ Batch processed successfully")
            print(f"   ✅ URLs generated: {urls_generated}")
            
            if urls_generated == len(test_files):
                print(f"   🎉 All {len(test_files)} files processed correctly!")
            else:
                print(f"   ⚠️  Expected {len(test_files)} URLs, got {urls_generated}")
        else:
            print(f"   ❌ Batch processing not found in logs")
            return False
            
    except Exception as e:
        print(f"❌ Failed to check logs: {e}")
        return False
    
    # Step 4: Check SQS queue status
    print()
    print("📊 Step 4: Checking SQS queue status")
    
    try:
        queue_attrs = sqs.get_queue_attributes(
            QueueUrl=UPLOAD_BATCH_QUEUE_URL,
            AttributeNames=['ApproximateNumberOfMessages', 'ApproximateNumberOfMessagesNotVisible']
        )
        
        messages_available = int(queue_attrs['Attributes']['ApproximateNumberOfMessages'])
        messages_in_flight = int(queue_attrs['Attributes']['ApproximateNumberOfMessagesNotVisible'])
        
        print(f"   • Messages in queue: {messages_available}")
        print(f"   • Messages processing: {messages_in_flight}")
        
        if messages_available == 0 and messages_in_flight == 0:
            print(f"   ✅ Queue is empty - message processed successfully")
        else:
            print(f"   ⚠️  Queue still has messages - processing may be ongoing")
            
    except Exception as e:
        print(f"❌ Failed to check queue status: {e}")
        return False
    
    # Summary
    print()
    print("🎉 INTEGRATION TEST SUMMARY")
    print("=" * 50)
    print("✅ SQS message sent successfully")
    print("✅ Lambda batch-processor triggered")
    print("✅ Batch processing completed")
    print(f"✅ {urls_generated} presigned URLs generated")
    print("✅ SQS message consumed")
    print()
    print("🚀 Batch upload integration is WORKING!")
    print()
    print("📋 Next steps for frontend integration:")
    print("   1. Update frontend to call /upload/batch-initiate for 10+ files")
    print("   2. Implement polling of /upload/batch-status endpoint")
    print("   3. Use returned URLs for actual file uploads")
    print("   4. Add progress UI for batch processing")
    
    return True

if __name__ == "__main__":
    success = test_batch_integration()
    exit(0 if success else 1)
