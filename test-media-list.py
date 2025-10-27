#!/usr/bin/env python3
"""
Test script to list available media files
"""
import boto3
import json
import sys

def test_media_list():
    # Initialize Lambda client
    lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    # Test event - simulating API Gateway request
    test_event = {
        "httpMethod": "GET",
        "requestContext": {
            "authorizer": {
                "claims": {
                    "sub": "34581438-20d1-70f7-6422-33faef85360d"
                }
            }
        },
        "queryStringParameters": {
            "limit": "5"
        }
    }
    
    try:
        # Invoke the media-retrieval Lambda function
        response = lambda_client.invoke(
            FunctionName='gildarck-media-retrieval',
            InvocationType='RequestResponse',
            Payload=json.dumps(test_event)
        )
        
        # Parse response
        payload = json.loads(response['Payload'].read())
        
        print("Media List Response:")
        print(json.dumps(payload, indent=2))
        
        if response['StatusCode'] == 200:
            print("\n✅ Media retrieval successful!")
            
            # Parse the body to get file IDs
            if 'body' in payload:
                body = json.loads(payload['body'])
                if 'files' in body and body['files']:
                    print(f"\nFound {len(body['files'])} files:")
                    for file in body['files'][:3]:  # Show first 3 files
                        print(f"- {file.get('file_id', 'Unknown ID')}: {file.get('filename', 'Unknown filename')}")
                    return [f['file_id'] for f in body['files'][:2]]  # Return first 2 file IDs for testing
        else:
            print(f"\n❌ Media retrieval failed with status: {response['StatusCode']}")
            
    except Exception as e:
        print(f"❌ Error invoking Lambda: {str(e)}")
    
    return []

if __name__ == "__main__":
    print("Testing media-retrieval Lambda function...")
    file_ids = test_media_list()
    if file_ids:
        print(f"\nFile IDs for testing: {file_ids}")
    else:
        print("\nNo files found for testing")
