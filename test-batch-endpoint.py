#!/usr/bin/env python3

import requests
import json

# Test endpoint directo sin autenticación para verificar CORS
API_BASE = "https://gslxbu791e.execute-api.us-east-1.amazonaws.com/dev"

def test_batch_initiate():
    """Test del endpoint batch-initiate"""
    
    # Payload de prueba
    payload = {
        "files": [
            {"name": "test1.jpg", "size": 1024000, "type": "image/jpeg"},
            {"name": "test2.png", "size": 2048000, "type": "image/png"}
        ],
        "strategy": {
            "type": "batch",
            "chunk_size": 50
        }
    }
    
    print("🧪 Testing batch-initiate endpoint...")
    print(f"📡 URL: {API_BASE}/upload/batch-initiate")
    
    try:
        # Test OPTIONS (CORS preflight)
        print("\n1️⃣ Testing OPTIONS (CORS preflight)...")
        options_response = requests.options(
            f"{API_BASE}/upload/batch-initiate",
            headers={
                'Origin': 'http://localhost:3000',
                'Access-Control-Request-Method': 'POST',
                'Access-Control-Request-Headers': 'Content-Type,Authorization'
            }
        )
        
        print(f"   Status: {options_response.status_code}")
        print(f"   Headers: {dict(options_response.headers)}")
        
        # Test POST sin autenticación
        print("\n2️⃣ Testing POST without auth...")
        post_response = requests.post(
            f"{API_BASE}/upload/batch-initiate",
            headers={
                'Content-Type': 'application/json',
                'Origin': 'http://localhost:3000'
            },
            json=payload
        )
        
        print(f"   Status: {post_response.status_code}")
        print(f"   Response: {post_response.text}")
        print(f"   Headers: {dict(post_response.headers)}")
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    test_batch_initiate()
