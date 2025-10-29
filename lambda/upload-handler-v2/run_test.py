#!/usr/bin/env python3
"""
Script para ejecutar tests locales con variables de entorno configuradas
"""

import os
import sys

# Configurar variables de entorno necesarias para la Lambda
os.environ['BUCKET_NAME'] = 'gildarck-media-dev'
os.environ['DEDUPLICATION_TABLE'] = 'gildarck-media-metadata-dev'
os.environ['BATCH_TABLE_NAME'] = 'gildarck-batch-uploads-dev'
os.environ['ENABLE_DEDUPLICATION'] = 'true'
os.environ['ENABLE_COMPRESSION'] = 'true'
os.environ['COMPRESSION_THRESHOLD'] = '26214400'  # 25MB
os.environ['MAX_PARALLEL_STREAMS'] = '10'
os.environ['CHUNK_SIZE'] = '8388608'  # 8MB
os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'

# Configurar credenciales AWS (usar perfil por defecto)
os.environ['AWS_PROFILE'] = 'my-student-user'

print("🔧 Environment variables configured:")
for key, value in os.environ.items():
    if key.startswith(('BUCKET_', 'DEDUPLICATION_', 'BATCH_', 'ENABLE_', 'COMPRESSION_', 'MAX_', 'CHUNK_')):
        print(f"   {key} = {value}")

print("\n🚀 Starting Lambda tests with proper environment...")

# Importar y ejecutar el test local
try:
    from test_local import main
    success = main()
    sys.exit(0 if success else 1)
except ImportError as e:
    print(f"❌ Error importing test_local: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error running tests: {e}")
    sys.exit(1)
