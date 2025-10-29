#!/usr/bin/env python3
import requests
import json
import time
import uuid

# Test configuration
API_BASE = "https://api.dev.gildarck.com"
TEST_USER_TOKEN = "test-token-123"  # Replace with real token

def test_batch_initiate():
    """Test batch initiate with mixed file sizes"""
    
    # Test files: mix of small and large
    test_files = [
        {"filename": "small1.jpg", "content_type": "image/jpeg", "file_size": 50 * 1024 * 1024},  # 50MB - simple
        {"filename": "large1.mp4", "content_type": "video/mp4", "file_size": 150 * 1024 * 1024},  # 150MB - multipart
        {"filename": "small2.png", "content_type": "image/png", "file_size": 10 * 1024 * 1024},   # 10MB - simple
    ]
    
    payload = {"files": test_files}
    
    headers = {
        "Authorization": f"Bearer {TEST_USER_TOKEN}",
        "Content-Type": "application/json"
    }
    
    print("🚀 Testing batch-initiate...")
    response = requests.post(
        f"{API_BASE}/upload/batch-initiate",
        json=payload,
        headers=headers
    )
    
    print(f"Status: {response.status_code}")
    print(f"Response: {response.text}")
    
    if response.status_code == 200:
        data = response.json()
        master_batch_id = data.get('masterBatchId')
        print(f"✅ Batch initiated: {master_batch_id}")
        return master_batch_id
    else:
        print(f"❌ Batch initiate failed: {response.status_code}")
        return None

def test_batch_status(master_batch_id):
    """Test batch status endpoint"""
    
    headers = {
        "Authorization": f"Bearer {TEST_USER_TOKEN}",
        "Content-Type": "application/json"
    }
    
    print(f"\n🔍 Testing batch-status for: {master_batch_id}")
    
    # Poll status multiple times
    for i in range(5):
        response = requests.get(
            f"{API_BASE}/upload/batch-status?masterBatchId={master_batch_id}",
            headers=headers
        )
        
        print(f"Attempt {i+1} - Status: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            data = response.json()
            status = data.get('status')
            
            if status == 'completed':
                upload_urls = data.get('upload_urls', [])
                print(f"✅ Batch completed with {len(upload_urls)} URLs")
                
                # Show URL types
                for url_info in upload_urls[:2]:  # Show first 2
                    upload_type = url_info.get('upload_type', 'unknown')
                    filename = url_info.get('filename')
                    print(f"  - {filename}: {upload_type}")
                
                return True
            else:
                print(f"⏳ Status: {status}")
        else:
            print(f"❌ Status check failed: {response.status_code}")
        
        time.sleep(2)
    
    return False

def main():
    print("🧪 Testing Simplified Batch Upload System")
    print("=" * 50)
    
    # Test 1: Batch initiate
    master_batch_id = test_batch_initiate()
    
    if not master_batch_id:
        print("❌ Cannot proceed without batch ID")
        return
    
    # Test 2: Batch status
    success = test_batch_status(master_batch_id)
    
    if success:
        print("\n✅ All tests passed! Simplified batch system working.")
    else:
        print("\n❌ Tests failed. Check logs for details.")

if __name__ == "__main__":
    main()
