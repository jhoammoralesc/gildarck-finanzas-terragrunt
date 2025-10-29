#!/usr/bin/env python3
"""
Test local para Upload Handler v2.0 Lambda
Simula eventos de API Gateway para probar la función directamente
"""

import json
import sys
import os
from datetime import datetime

# Agregar el directorio actual al path para importar la lambda
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from lambda_function import lambda_handler
except ImportError as e:
    print(f"❌ Error importing lambda_function: {e}")
    print("Make sure lambda_function.py exists in the current directory")
    sys.exit(1)

def log(message):
    """Log con timestamp"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

def create_api_gateway_event(method, path, body=None, query_params=None):
    """Crear evento simulado de API Gateway"""
    return {
        "httpMethod": method,
        "path": path,
        "pathParameters": {},
        "queryStringParameters": query_params or {},
        "headers": {
            "Content-Type": "application/json",
            "Authorization": "Bearer test-token"
        },
        "body": json.dumps(body) if body else None,
        "isBase64Encoded": False,
        "requestContext": {
            "requestId": "test-request-id",
            "stage": "dev",
            "resourcePath": path
        }
    }

def create_lambda_context():
    """Crear contexto simulado de Lambda"""
    class MockContext:
        def __init__(self):
            self.function_name = "gildarck-upload-handler-v2-dev"
            self.function_version = "1"
            self.invoked_function_arn = "arn:aws:lambda:us-east-1:496860676881:function:gildarck-upload-handler-v2-dev"
            self.memory_limit_in_mb = "1024"
            self.remaining_time_in_millis = lambda: 30000
            self.aws_request_id = "test-request-id"
    
    return MockContext()

def test_health_endpoint():
    """Test endpoint de health"""
    log("🔍 Testing health endpoint...")
    
    event = create_api_gateway_event("GET", "/upload/health")
    context = create_lambda_context()
    
    try:
        response = lambda_handler(event, context)
        
        if response["statusCode"] == 200:
            body = json.loads(response["body"])
            log(f"✅ Health endpoint OK - Status: {body.get('status')}")
            log(f"   Version: {body.get('version')}")
            log(f"   Features: {body.get('features')}")
            return True
        else:
            log(f"❌ Health endpoint failed: {response['statusCode']}")
            log(f"   Body: {response.get('body')}")
            return False
            
    except Exception as e:
        log(f"❌ Health endpoint error: {e}")
        return False

def test_file_analysis():
    """Test análisis de archivos"""
    log("🔍 Testing file analysis...")
    
    test_files = [
        {"filename": "test1.jpg", "size": 1024000, "type": "image/jpeg"},
        {"filename": "test2.mp4", "size": 50000000, "type": "video/mp4"},
        {"filename": "test3.pdf", "size": 2048000, "type": "application/pdf"}
    ]
    
    event = create_api_gateway_event("POST", "/upload/analyze", {
        "files": test_files,
        "user_id": "test-user"
    })
    context = create_lambda_context()
    
    try:
        response = lambda_handler(event, context)
        
        if response["statusCode"] == 200:
            body = json.loads(response["body"])
            log(f"✅ File analysis OK")
            log(f"   Strategy: {body.get('strategy')}")
            log(f"   Files: {len(body.get('files', []))}")
            log(f"   Total size: {body.get('total_size', 0) / 1024 / 1024:.1f} MB")
            log(f"   Compression: {body.get('compression_enabled')}")
            return True
        else:
            log(f"❌ File analysis failed: {response['statusCode']}")
            log(f"   Body: {response.get('body')}")
            return False
            
    except Exception as e:
        log(f"❌ File analysis error: {e}")
        return False

def test_deduplication_check():
    """Test verificación de duplicados"""
    log("🔍 Testing deduplication check...")
    
    event = create_api_gateway_event("POST", "/upload/check-duplicate", {
        "hash": "test_hash_12345",
        "filename": "test_duplicate.jpg",
        "user_id": "test-user"
    })
    context = create_lambda_context()
    
    try:
        response = lambda_handler(event, context)
        
        if response["statusCode"] == 200:
            body = json.loads(response["body"])
            log(f"✅ Deduplication check OK")
            log(f"   Is duplicate: {body.get('is_duplicate')}")
            return True
        else:
            log(f"❌ Deduplication check failed: {response['statusCode']}")
            return False
            
    except Exception as e:
        log(f"❌ Deduplication check error: {e}")
        return False

def test_presigned_url():
    """Test generación de URL presignada"""
    log("🔍 Testing presigned URL generation...")
    
    event = create_api_gateway_event("POST", "/upload/presigned", {
        "filename": "test_presigned.jpg",
        "size": 1024000,
        "type": "image/jpeg",
        "user_id": "test-user"
    })
    context = create_lambda_context()
    
    try:
        response = lambda_handler(event, context)
        
        if response["statusCode"] == 200:
            body = json.loads(response["body"])
            log(f"✅ Presigned URL generation OK")
            log(f"   Has URL: {'presigned_url' in body}")
            log(f"   Key: {body.get('key', 'N/A')}")
            return True
        else:
            log(f"❌ Presigned URL failed: {response['statusCode']}")
            log(f"   Body: {response.get('body')}")
            return False
            
    except Exception as e:
        log(f"❌ Presigned URL error: {e}")
        return False

def test_batch_initiate():
    """Test iniciación de lote"""
    log("🔍 Testing batch initiation...")
    
    batch_files = [
        {"filename": f"batch_test_{i:03d}.jpg", "size": 1024000 + i*1000, "type": "image/jpeg"}
        for i in range(25)  # 25 archivos para activar modo batch
    ]
    
    event = create_api_gateway_event("POST", "/upload/batch-initiate", {
        "files": batch_files,
        "user_id": "test-user"
    })
    context = create_lambda_context()
    
    try:
        response = lambda_handler(event, context)
        
        if response["statusCode"] == 200:
            body = json.loads(response["body"])
            log(f"✅ Batch initiation OK")
            log(f"   Batch ID: {body.get('batch_id')}")
            log(f"   URLs generated: {len(body.get('presigned_urls', []))}")
            return body.get('batch_id')
        else:
            log(f"❌ Batch initiation failed: {response['statusCode']}")
            log(f"   Body: {response.get('body')}")
            return None
            
    except Exception as e:
        log(f"❌ Batch initiation error: {e}")
        return None

def test_batch_status(batch_id):
    """Test consulta de estado de lote"""
    if not batch_id:
        log("⏭️ Skipping batch status (no batch ID)")
        return False
        
    log("🔍 Testing batch status...")
    
    event = create_api_gateway_event("GET", "/upload/batch-status", 
                                   query_params={"batch_id": batch_id, "user_id": "test-user"})
    context = create_lambda_context()
    
    try:
        response = lambda_handler(event, context)
        
        if response["statusCode"] == 200:
            body = json.loads(response["body"])
            log(f"✅ Batch status OK")
            log(f"   Status: {body.get('status')}")
            log(f"   Total files: {body.get('total_files')}")
            return True
        else:
            log(f"❌ Batch status failed: {response['statusCode']}")
            return False
            
    except Exception as e:
        log(f"❌ Batch status error: {e}")
        return False

def test_invalid_endpoint():
    """Test endpoint inválido"""
    log("🔍 Testing invalid endpoint...")
    
    event = create_api_gateway_event("GET", "/upload/invalid")
    context = create_lambda_context()
    
    try:
        response = lambda_handler(event, context)
        
        if response["statusCode"] == 404:
            log("✅ Invalid endpoint correctly returns 404")
            return True
        else:
            log(f"❌ Invalid endpoint returned: {response['statusCode']}")
            return False
            
    except Exception as e:
        log(f"❌ Invalid endpoint error: {e}")
        return False

def main():
    """Ejecutar todos los tests locales"""
    log("🚀 Starting Upload Handler v2.0 Local Tests")
    log("=" * 60)
    
    # Verificar que tenemos la función lambda
    try:
        from lambda_function import lambda_handler
        log("✅ Lambda function imported successfully")
    except ImportError as e:
        log(f"❌ Cannot import lambda function: {e}")
        return False
    
    tests = [
        ("Health Endpoint", test_health_endpoint),
        ("File Analysis", test_file_analysis),
        ("Deduplication Check", test_deduplication_check),
        ("Presigned URL", test_presigned_url),
        ("Invalid Endpoint", test_invalid_endpoint),
    ]
    
    results = []
    batch_id = None
    
    # Ejecutar tests básicos
    for test_name, test_func in tests:
        log(f"\n📋 Running: {test_name}")
        try:
            result = test_func()
            results.append((test_name, result))
            if result:
                log(f"✅ {test_name} PASSED")
            else:
                log(f"❌ {test_name} FAILED")
        except Exception as e:
            log(f"💥 {test_name} CRASHED: {e}")
            results.append((test_name, False))
    
    # Test de batch (separado porque devuelve batch_id)
    log(f"\n📋 Running: Batch Initiation")
    batch_id = test_batch_initiate()
    if batch_id:
        log("✅ Batch Initiation PASSED")
        results.append(("Batch Initiation", True))
        
        # Test de batch status
        log(f"\n📋 Running: Batch Status")
        batch_status_result = test_batch_status(batch_id)
        results.append(("Batch Status", batch_status_result))
        if batch_status_result:
            log("✅ Batch Status PASSED")
        else:
            log("❌ Batch Status FAILED")
    else:
        log("❌ Batch Initiation FAILED")
        results.append(("Batch Initiation", False))
        results.append(("Batch Status", False))
    
    # Resumen final
    log("\n" + "=" * 60)
    log("📊 LOCAL TEST RESULTS SUMMARY")
    log("=" * 60)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        log(f"{status} - {test_name}")
    
    log(f"\n🎯 Overall: {passed}/{total} tests passed ({passed/total*100:.1f}%)")
    
    if passed == total:
        log("🎉 ALL LOCAL TESTS PASSED! Lambda function is working correctly!")
    elif passed > total * 0.7:
        log("✅ Most tests passed. Lambda function is mostly working.")
    else:
        log("⚠️ Many tests failed. Please check the implementation.")
    
    return passed >= total * 0.7  # 70% success rate

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
