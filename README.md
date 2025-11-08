# Gildarck Finanzas - Personal Finance Management

Sistema de gestión de finanzas personales con integración de bot de Telegram y procesamiento automático de imágenes.

## Arquitectura

### Backend (AWS Amplify)
- **Lambda Functions**: Procesamiento automático de imágenes con Textract
- **DynamoDB**: Almacenamiento de transacciones financieras
- **S3**: Almacenamiento de imágenes y recibos
- **API Gateway**: REST API para operaciones CRUD

### Bot de Telegram (n8n)
- **Procesamiento de texto**: Análisis con Bedrock Claude
- **Procesamiento de audio**: Transcripción con AWS Transcribe
- **Procesamiento de imágenes**: OCR con AWS Textract

## Funcionalidades

### 🤖 Bot de Telegram
- Registro de ingresos y gastos por texto
- Transcripción de mensajes de voz
- Procesamiento automático de facturas y recibos
- Categorización inteligente de transacciones
- Detección de gastos de ocio

### 📊 Procesamiento Automático
- **Trigger S3**: Lambda se activa automáticamente al subir imágenes a `s3://gildarck-bucket-audio-transcribe-dev/photos/`
- **OCR con Textract**: Extracción de texto de facturas y recibos
- **Análisis inteligente**: Categorización automática de gastos
- **Almacenamiento**: Guardado automático en DynamoDB

### 🗄️ Estructura de Datos
```typescript
interface Transaction {
  user_id: string;
  transaction_id: string;
  chat_id?: number;
  username?: string;
  message_id?: number;
  amount: number;
  type: "income" | "expense";
  description: string;
  category: string;
  is_leisure: boolean;
  currency: string;
  confidence: number;
  processing_method: string;
  reasoning: string;
  original_text: string;
  date_only: string;
  month_year: string;
}
```

## Deployment

### Requisitos
- AWS CLI configurado
- Node.js 18+
- Amplify CLI

### Comandos
```bash
# Desarrollo local
npm run amplify:dev

# Deploy a producción
npm run amplify:deploy
```

### Configuración del Trigger S3
La Lambda `image-processor-function` se activa automáticamente cuando se suben archivos a:
- **Bucket**: `gildarck-bucket-audio-transcribe-dev`
- **Prefix**: `photos/`

### Variables de Entorno
- `DYNAMODB_TABLE_NAME`: Tabla de transacciones
- `TEXTRACT_REGION`: Región para AWS Textract
- `AWS_REGION`: Región principal de AWS

## Categorías Soportadas

### Gastos
- **comida**: Supermercados, alimentos
- **transporte**: Gasolina, Uber, transporte público
- **servicios**: Servicios públicos, internet, telefonía
- **entretenimiento**: Restaurantes, cine, bares (is_leisure: true)
- **salud**: Farmacias, consultas médicas
- **compras**: Ropa, productos generales
- **educacion**: Cursos, libros
- **otro_gasto**: Gastos no categorizados

### Ingresos
- **salario**: Sueldo mensual
- **freelance**: Trabajos independientes
- **venta**: Ventas de productos
- **inversion**: Retornos de inversión
- **regalo**: Dinero recibido como regalo
- **otro_ingreso**: Ingresos no categorizados

## Integración con n8n

El bot de Telegram funciona con n8n y se conecta a esta infraestructura de Amplify para:
1. Almacenar transacciones procesadas
2. Consultar historial de transacciones
3. Generar reportes automáticos

## Monitoreo

- **CloudWatch Logs**: Logs de Lambda functions
- **DynamoDB Metrics**: Métricas de uso de base de datos
- **S3 Events**: Eventos de carga de archivos
