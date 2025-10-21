# Karpenter Health Monitor - Lambda Unificada

## Resumen de la Unificación

Se ha unificado exitosamente las funcionalidades de tres Lambdas independientes en una sola función `karpenter-health-monitor`:

### Funciones Originales Unificadas:
1. **karpenter-health-monitor** - Monitoreo de salud (funcionalidad base)
2. **karpenter-recovery** - Recuperación de Karpenter
3. **karpenter-cleanup** - Limpieza de nodos y NodeClaims

## Funcionalidades Integradas

### 1. Health Monitoring (Comportamiento por defecto)
- Monitoreo continuo del estado de Karpenter y nodos EKS
- Seguimiento de fallos en DynamoDB
- Publicación de eventos en EventBridge
- Lógica de escalación automática

### 2. Recovery (action: 'recover')
- Escalamiento del node group a 2 nodos (máximo 3)
- Rollout del deployment de Karpenter
- **Períodos de espera integrados:**
  - 30 segundos después del escalamiento
  - 30 segundos después del rollout

### 3. Cleanup (action: 'cleanup')
- Invocación de `stop-start-services-function` con acción 'stop'
- Limpieza de nodos en estado NotReady/Unknown
- Limpieza de finalizers de NodeClaims huérfanos
- **Períodos de espera integrados:**
  - 60 segundos después de parar servicios
  - 30 segundos después de la limpieza

## Lógica de Escalación Mejorada

### Primer Fallo (failure_count = 1):
- Ejecuta **recovery** con períodos de espera
- Publica evento de fallo en EventBridge

### Segundo Fallo o más (failure_count >= 2):
- Ejecuta secuencia completa: **cleanup** → espera → **recovery**
- Incluye todos los períodos de espera para estabilidad del cluster

## Configuración Actualizada

### Permisos IAM:
- EKS: DescribeCluster, ListClusters, UpdateNodegroupConfig
- Lambda: InvokeFunction (stop-start-services-function)
- EventBridge: PutEvents
- STS: AssumeRole
- DynamoDB: GetItem, PutItem

### Configuración Lambda:
- **Timeout**: 900 segundos (15 minutos)
- **Arquitectura**: ARM64
- **Layer**: karpenter-dependencies:2
- **Variables de entorno**:
  - CLUSTER_NAME: eks-dev-1
  - NODE_GROUP_NAME: non-fargate-20250804141603154100000001
  - ROLE_TO_ASSUME: arn:aws:iam::559756754086:role/eks-karpenter-health-check-role

## Uso de la Lambda Unificada

### Health Monitoring (por defecto):
```bash
aws lambda invoke --function-name eks-karpenter-health-check response.json
```

### Recovery manual:
```bash
aws lambda invoke --function-name eks-karpenter-health-check \
  --payload '{"action": "recover"}' response.json
```

### Cleanup manual:
```bash
aws lambda invoke --function-name eks-karpenter-health-check \
  --payload '{"action": "cleanup"}' response.json
```

## Beneficios de la Unificación

1. **Simplicidad operacional**: Una sola función para gestionar
2. **Consistencia**: Configuración y permisos centralizados
3. **Eficiencia**: Menos recursos y complejidad de infraestructura
4. **Mantenimiento**: Un solo punto de actualización de código
5. **Observabilidad**: Logs centralizados en un solo CloudWatch Log Group

## Backup Realizado

Las funciones originales están respaldadas en:
- `~/Documents/gildarck/lambdas/karpenter-health-monitor`
- `~/Documents/gildarck/lambdas/karpenter-recovery`
- `~/Documents/gildarck/lambdas/karpenter-cleanup`

## Estado Actual

✅ **Completado**: Unificación exitosa con todas las funcionalidades integradas
✅ **Desplegado**: Lambda actualizada en DEV (versión 65)
✅ **Probado**: Configuración validada y aplicada
✅ **Documentado**: Funcionalidades y uso documentados
