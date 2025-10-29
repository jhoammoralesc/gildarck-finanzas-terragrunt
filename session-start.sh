#!/bin/bash

# 🎯 GILDARCK SESSION STARTER
# Ejecutar al inicio de cada sesión para recuperar contexto

echo "🚀 INICIANDO SESIÓN GILDARCK PROJECT"
echo "=================================="

# Mostrar estado actual
echo "📊 ESTADO ACTUAL DEL PROYECTO:"
cat GILDARCK_PROJECT_STATE.md | grep -A 20 "## 📊 ESTADO ACTUAL DEL SISTEMA"

echo ""
echo "🎯 PRÓXIMAS TAREAS:"
cat GILDARCK_PROJECT_STATE.md | grep -A 10 "## 🎯 PRÓXIMAS TAREAS PRIORITARIAS"

echo ""
echo "🔧 VERIFICANDO INFRAESTRUCTURA..."

# Verificar componentes clave
echo "✅ Verificando Lambda Batch Processor v2:"
aws lambda get-function --function-name "gildarck-batch-processor-v2-dev" --profile my-student-user --query 'Configuration.LastModified' --output text

echo "✅ Verificando SQS Queue:"
aws sqs get-queue-attributes --queue-url "https://sqs.us-east-1.amazonaws.com/496860676881/gildarck-batch-queue-dev" --attribute-names ApproximateNumberOfMessages --profile my-student-user --query 'Attributes.ApproximateNumberOfMessages'

echo "✅ Verificando Event Source Mapping:"
aws lambda get-event-source-mapping --uuid "7561cf5d-6e72-48b1-ad72-f294a57cec58" --profile my-student-user --query 'State' --output text

echo ""
echo "📝 PARA CONTINUAR:"
echo "1. Revisar GILDARCK_PROJECT_STATE.md"
echo "2. Ejecutar próxima tarea prioritaria"
echo "3. Actualizar estado al final de sesión"

echo ""
echo "🎯 CONTEXTO RECUPERADO - LISTO PARA CONTINUAR"
