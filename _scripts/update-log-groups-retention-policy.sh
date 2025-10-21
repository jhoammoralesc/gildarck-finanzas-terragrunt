#!/bin/bash

# Configuración
# Verificar que se proporcione el profile como parámetro
if [ $# -eq 0 ]; then
    PROFILE="default"
RETENTION_DAYS=7
    echo "No se proporcionó profile, usando 'default'"
    echo "No se proporcionó retention days, usando '7' días"
elif [ $# -eq 1 ]; then
    PROFILE="$1"
    RETENTION_DAYS=7
    echo "No se proporcionó retention days, usando '7' días"
else
PROFILE="$1"
    RETENTION_DAYS="$2"
fi
REGION="us-east-1"

# Obtener todos los grupos de logs
echo "Obteniendo lista de grupos de logs..."
LOG_GROUPS=$(aws logs describe-log-groups --profile $PROFILE --region $REGION --query 'logGroups[*].logGroupName' --output text)

# Contador para seguimiento
TOTAL=$(echo "$LOG_GROUPS" | wc -w)
COUNTER=0
SUCCESS=0
FAILED=0

echo "Se encontraron $TOTAL grupos de logs. Iniciando actualización..."

# Iterar sobre cada grupo de logs
for LOG_GROUP in $LOG_GROUPS; do
  COUNTER=$((COUNTER+1))
  echo "[$COUNTER/$TOTAL] Actualizando $LOG_GROUP..."

  # Actualizar la retención
  if aws logs put-retention-policy --profile $PROFILE --region $REGION --log-group-name "$LOG_GROUP" --retention-in-days $RETENTION_DAYS; then
    echo "  ✅ Éxito: Retención actualizada a $RETENTION_DAYS días"
    SUCCESS=$((SUCCESS+1))
  else
    echo "  ❌ Error: No se pudo actualizar la retención"
    FAILED=$((FAILED+1))
  fi
done

# Mostrar resumen final
echo "Proceso completado:"
echo "  ✅ Exitosos: $SUCCESS"
echo "  ❌ Fallidos: $FAILED"
