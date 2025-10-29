#!/usr/bin/env python3
"""
Test script para Upload Handler v2.0
Valida todas las funcionalidades del sistema de carga masiva
"""

import json
import requests
import hashlib
import time
from datetime import datetime

# Configuración
API_BASE = "https://api.dev.gildarck.com"
TEST_USER_ID = "test-user-upload-v2"

def log(message):
    """Log con timestamp"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

def test_health_check():
    """Test básico de conectividad"""
    log("🔍 Testing health check...")
    try:
        response = requests.get(f"{API_BASE}/upload/health", timeout=10)
        if response.status_code == 200:
            log("✅ Health check OK")
            return True
        else:
            log(f"❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        log(f"❌ Health check error: {e}")
        return False

def test_file_analysis():
    """Test análisis de archivos"""
    log("🔍 Testing file analysis...")
    
    test_files = [
        {"filename": "test1.jpg", "size": 1024000, "type": "image/jpeg"},
        {"filename": "test2.mp4", "size": 50000000, "type": "video/mp4"},
        {"filename": "test3.pdf", "size": 2048000, "type": "application/pdf"}
    ]
    
    try:
        response = requests.post(
            f"{API_BASE}/upload/analyze",
            json={
                "files": test_files,
                "user_id": TEST_USER_ID
            },
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            log(f"✅ File analysis OK - Strategy: {result.get('strategy', 'unknown')}")
            log(f"   📊 Files: {len(result.get('files', []))}")
            log(f"   💾 Total size: {result.get('total_size', 0) / 1024 / 1024:.1f} MB")
            return True
        else:
            log(f"❌ File analysis failed: {response.status_code}")
            log(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        log(f"❌ File analysis error: {e}")
        return False

def test_deduplication():
    """Test deduplicación de archivos"""
    log("🔍 Testing deduplication...")
    
    # Generar hash de prueba
    test_hash = hashlib.sha256(b"test_file_content").hexdigest()
    
    try:
        response = requests.post(
            f"{API_BASE}/upload/check-duplicate",
            json={
                "hash": test_hash,
                "filename": "test_duplicate.jpg",
                "user_id": TEST_USER_ID
            },
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            log(f"✅ Deduplication check OK - Duplicate: {result.get('is_duplicate', False)}")
            return True
        else:
            log(f"❌ Deduplication failed: {response.status_code}")
            return False
            
    except Exception as e:
        log(f"❌ Deduplication error: {e}")
        return False

def test_presigned_url():
    """Test generación de URLs presignadas"""
    log("🔍 Testing presigned URL generation...")
    
    try:
        response = requests.post(
            f"{API_BASE}/upload/presigned",
            json={
                "filename": "test_presigned.jpg",
                "size": 1024000,
                "type": "image/jpeg",
                "user_id": TEST_USER_ID
            },
            timeout=15
        )
        
        if response.status_code == 200:
            result = response.json()
            if "presigned_url" in result:
                log("✅ Presigned URL generation OK")
                log(f"   🔗 URL length: {len(result['presigned_url'])}")
                return True
            else:
                log("❌ No presigned URL in response")
                return False
        else:
            log(f"❌ Presigned URL failed: {response.status_code}")
            log(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        log(f"❌ Presigned URL error: {e}")
        return False

def test_batch_initiate():
    """Test iniciación de lotes"""
    log("🔍 Testing batch initiation...")
    
    batch_files = [
        {"filename": f"batch_test_{i}.jpg", "size": 1024000 + i*1000, "type": "image/jpeg"}
        for i in range(25)  # 25 archivos para activar modo batch
    ]
    
    try:
        response = requests.post(
            f"{API_BASE}/upload/batch-initiate",
            json={
                "files": batch_files,
                "user_id": TEST_USER_ID
            },
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            batch_id = result.get("batch_id")
            presigned_urls = result.get("presigned_urls", [])
            
            log(f"✅ Batch initiation OK")
            log(f"   🆔 Batch ID: {batch_id}")
            log(f"   🔗 URLs generated: {len(presigned_urls)}")
            
            return batch_id
        else:
            log(f"❌ Batch initiation failed: {response.status_code}")
            log(f"   Response: {response.text}")
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
    
    try:
        response = requests.get(
            f"{API_BASE}/upload/batch-status",
            params={
                "batch_id": batch_id,
                "user_id": TEST_USER_ID
            },
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            log(f"✅ Batch status OK")
            log(f"   📊 Status: {result.get('status', 'unknown')}")
            log(f"   📁 Files: {result.get('total_files', 0)}")
            log(f"   ✅ Completed: {result.get('completed_files', 0)}")
            return True
        else:
            log(f"❌ Batch status failed: {response.status_code}")
            return False
            
    except Exception as e:
        log(f"❌ Batch status error: {e}")
        return False

def test_compression_threshold():
    """Test umbral de compresión"""
    log("🔍 Testing compression threshold...")
    
    # Archivo grande que debería activar compresión
    large_file = {
        "filename": "large_test.jpg",
        "size": 30 * 1024 * 1024,  # 30MB
        "type": "image/jpeg"
    }
    
    try:
        response = requests.post(
            f"{API_BASE}/upload/analyze",
            json={
                "files": [large_file],
                "user_id": TEST_USER_ID
            },
            timeout=15
        )
        
        if response.status_code == 200:
            result = response.json()
            compression_enabled = result.get("compression_enabled", False)
            log(f"✅ Compression threshold OK - Enabled: {compression_enabled}")
            return True
        else:
            log(f"❌ Compression threshold failed: {response.status_code}")
            return False
            
    except Exception as e:
        log(f"❌ Compression threshold error: {e}")
        return False

def run_performance_test():
    """Test de rendimiento con múltiples archivos"""
    log("🔍 Running performance test...")
    
    # Simular 100 archivos
    files = [
        {"filename": f"perf_test_{i:03d}.jpg", "size": 1024000 + i*1000, "type": "image/jpeg"}
        for i in range(100)
    ]
    
    start_time = time.time()
    
    try:
        response = requests.post(
            f"{API_BASE}/upload/analyze",
            json={
                "files": files,
                "user_id": TEST_USER_ID
            },
            timeout=60
        )
        
        end_time = time.time()
        duration = end_time - start_time
        
        if response.status_code == 200:
            result = response.json()
            log(f"✅ Performance test OK")
            log(f"   ⏱️ Duration: {duration:.2f}s")
            log(f"   📊 Files/sec: {len(files)/duration:.1f}")
            log(f"   🎯 Strategy: {result.get('strategy', 'unknown')}")
            return True
        else:
            log(f"❌ Performance test failed: {response.status_code}")
            return False
            
    except Exception as e:
        log(f"❌ Performance test error: {e}")
        return False

def main():
    """Ejecutar todos los tests"""
    log("🚀 Starting Upload Handler v2.0 Tests")
    log("=" * 50)
    
    tests = [
        ("Health Check", test_health_check),
        ("File Analysis", test_file_analysis),
        ("Deduplication", test_deduplication),
        ("Presigned URLs", test_presigned_url),
        ("Compression Threshold", test_compression_threshold),
        ("Performance Test", run_performance_test),
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
    log("\n" + "=" * 50)
    log("📊 TEST RESULTS SUMMARY")
    log("=" * 50)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        log(f"{status} - {test_name}")
    
    log(f"\n🎯 Overall: {passed}/{total} tests passed ({passed/total*100:.1f}%)")
    
    if passed == total:
        log("🎉 ALL TESTS PASSED! Upload Handler v2.0 is ready for production!")
    else:
        log("⚠️ Some tests failed. Please check the logs above.")
    
    return passed == total

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
