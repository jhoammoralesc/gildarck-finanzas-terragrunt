#!/bin/bash

# 🤖 AUTO-RESTORE - Recupera contexto automáticamente

CONTEXT_FILE="/Users/jhoam.morales/Documents/gildarck/infrastructure-iac-terragrunt/AUTO_CONTEXT.json"

if [[ -f "$CONTEXT_FILE" ]]; then
    echo "🤖 CONTEXTO AUTOMÁTICO RECUPERADO:"
    echo "================================="
    
    # Extraer información crítica del JSON
    TIMESTAMP=$(jq -r '.timestamp' "$CONTEXT_FILE" 2>/dev/null || echo "unknown")
    LAST_COMMAND=$(jq -r '.last_command' "$CONTEXT_FILE" 2>/dev/null || echo "unknown")
    BATCH_STATUS=$(jq -r '.infrastructure_state.batch_processor_v2' "$CONTEXT_FILE" 2>/dev/null || echo "unknown")
    SQS_MESSAGES=$(jq -r '.infrastructure_state.sqs_messages' "$CONTEXT_FILE" 2>/dev/null || echo "0")
    
    echo "⏰ Última actividad: $TIMESTAMP"
    echo "🔧 Último comando: $LAST_COMMAND"
    echo "🚀 Batch Processor v2: $BATCH_STATUS"
    echo "📨 Mensajes SQS pendientes: $SQS_MESSAGES"
    
    echo ""
    echo "🎯 PRÓXIMAS ACCIONES AUTOMÁTICAS:"
    jq -r '.next_actions[]' "$CONTEXT_FILE" 2>/dev/null | head -3 | sed 's/^/  • /'
    
    echo ""
    echo "🧠 CONTEXTO CRÍTICO:"
    jq -r '.critical_context | to_entries[] | "  • \(.key): \(.value)"' "$CONTEXT_FILE" 2>/dev/null
    
    echo ""
    echo "✅ Contexto cargado automáticamente - Continúa trabajando"
else
    echo "⚠️  No hay contexto previo - Iniciando sesión nueva"
fi
