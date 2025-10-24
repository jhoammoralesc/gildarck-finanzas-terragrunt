# 📸 GILDARCK - Plataforma de Almacenamiento de Medios Visuales

## ⚠️ ADVERTENCIA CRÍTICA ⚠️

**NUNCA usar perfiles de AWS que comiencen con `ic-` (ic-dev, ic-qa, ic-prod, ic-shared, ic-network, etc.)**

Estos perfiles pertenecen a **IBCOBROS** y están estrictamente prohibidos para el proyecto GILDARCK.

### Perfiles PROHIBIDOS:
- `ic-dev` ❌
- `ic-qa` ❌ 
- `ic-prod` ❌
- `ic-shared` ❌
- `ic-network` ❌
- `ic-uat` ❌
- `ic-root` ❌

**USAR ÚNICAMENTE**: `my-student-user` ✅

---

## 🎯 Objetivo del Proyecto

**Gildarck** es una plataforma de almacenamiento de medios visuales segura, eficiente y confiable, inspirada en la arquitectura de Google Photos. El objetivo principal es proporcionar a los usuarios un espacio personal y privado para almacenar, organizar y gestionar sus imágenes, videos y documentos con tecnología de vanguardia.

## 🌟 Características Principales

### 🔐 Seguridad y Privacidad
- **Aislamiento por Usuario**: Cada usuario tiene acceso únicamente a su carpeta personal
- **Encriptación**: Todos los archivos se almacenan con encriptación AES-256
- **Autenticación Robusta**: Sistema completo con Cognito (registro, login, logout)
- **Permisos Granulares**: IAM policies que restringen acceso por usuario específico

### 🗂️ Organización Inteligente
- **Estructura Jerárquica**: 
  ```
  s3bucket/{cognito-sub}/
  ├── originals/{year}/{month}/     # Archivos originales organizados por fecha
  ├── thumbnails/                   # Miniaturas en múltiples resoluciones
  │   ├── small/                    # 150x150px
  │   ├── medium/                   # 300x300px
  │   └── large/                    # 800x800px
  ├── compressed/                   # Versiones comprimidas
  └── trash/                        # Papelera (eliminación automática en 30 días)
  ```

### 🤖 Inteligencia Artificial
- **Análisis Automático**: Detección de objetos, caras y escenas usando AWS Rekognition
- **Metadatos Completos**: Extracción automática de información EXIF, GPS, y cámara
- **Deduplicación**: Eliminación automática de archivos duplicados usando hash SHA-256
- **Thumbnails**: Generación automática de miniaturas en múltiples resoluciones

### 📊 Metadatos Avanzados (Como Google Photos)
```json
{
  "file_info": "Información básica del archivo",
  "camera_data": "Datos de la cámara y configuración",
  "location": "Coordenadas GPS y dirección",
  "ai_analysis": "Objetos, caras y escenas detectadas",
  "organization": "Álbumes, etiquetas y favoritos",
  "thumbnails": "Miniaturas en múltiples tamaños"
}
```

## 🏗️ Arquitectura Técnica

### ☁️ Infraestructura AWS
- **S3**: Almacenamiento principal con EventBridge notifications habilitadas
- **EventBridge**: Orquestación de eventos para procesamiento escalable
- **DynamoDB**: Base de datos NoSQL para metadatos con índices optimizados
- **Lambda**: Procesamiento automático de archivos via EventBridge
- **Cognito**: Gestión de usuarios y autenticación
- **API Gateway**: Endpoints REST para operaciones CRUD
- **Rekognition**: Análisis de imágenes con IA

### 🔧 Tecnologías Utilizadas
- **Infrastructure as Code**: Terragrunt + Terraform
- **Backend**: Python 3.12 con AWS SDK
- **Frontend**: Next.js + React + TypeScript
- **Autenticación**: AWS Cognito User Pools
- **Base de Datos**: DynamoDB con GSI para consultas optimizadas
- **Procesamiento**: AWS Lambda con layers de Pillow para imágenes

## 📁 Estructura del Proyecto

```
gildarck/
├── infrastructure-iac-terragrunt/     # Infraestructura AWS
│   ├── gildarck/dev/us-east-1/
│   │   ├── cognito/user-pool/         # Autenticación
│   │   ├── lambda/user-crud/          # API de usuarios
│   │   ├── lambda/media-processor/    # Procesamiento de medios
│   │   ├── s3/media-storage/          # Almacenamiento principal
│   │   ├── dynamodb/media-metadata/   # Base de datos de metadatos
│   │   ├── apigateway/                # API REST
│   │   └── iam/s3-user-access/        # Permisos por usuario
│   └── README.md
└── frontend-main-front/               # Aplicación web
    ├── src/
    │   ├── components/auth/           # Componentes de autenticación
    │   ├── services/                  # Servicios API
    │   └── app/                       # Páginas principales
    └── README.md
```

## 🚀 Funcionalidades Implementadas

### ✅ Sistema de Autenticación Completo
- [x] Registro de usuarios con validación de email
- [x] Login con manejo de contraseñas temporales
- [x] Cambio de contraseña obligatorio en primer acceso
- [x] Logout seguro con invalidación de tokens
- [x] Gestión de sesiones y tokens JWT

### ✅ Almacenamiento de Medios
- [x] Bucket S3 con configuración de seguridad
- [x] Estructura de carpetas por usuario
- [x] Encriptación y versionado automático
- [x] Políticas de lifecycle para optimización de costos
- [x] CORS configurado para acceso web

### ✅ Base de Datos de Metadatos
- [x] Tabla DynamoDB con esquema optimizado
- [x] Índices secundarios para búsquedas por:
  - Hash de archivo (deduplicación)
  - Fecha de creación
  - Ubicación GPS
- [x] Esquema de metadatos completo como Google Photos

### ✅ Sistema de Procesamiento EventBridge Completado
- [x] **Arquitectura EventBridge**: S3 → EventBridge → Lambda → DynamoDB
- [x] **Procesamiento Automático**: Trigger en Object Created events
- [x] **Integración AI**: AWS Rekognition para análisis de imágenes
- [x] **Identificación Única**: Cognito sub como UID inmutable
- [x] **Metadatos Google Photos**: Estructura completa con organización temporal
- [x] **Estructura de Archivos**: `{cognito-sub}/originals/{year}/{month}/{filename}`
- [x] **Escalabilidad**: EventBridge permite procesamiento de alto volumen
- [x] **Manejo de Errores**: Logging detallado y recuperación automática

### 🔄 Sistema de Carga en Background (En Desarrollo)
- [ ] **Multipart Upload API** - Carga de archivos grandes en chunks
- [ ] **SQS Queue Processing** - Cola para procesamiento asíncrono
- [ ] **WebSocket Notifications** - Progreso en tiempo real
- [ ] **Retry Logic** - Reintentos automáticos en fallos
- [ ] **Upload Progress UI** - Interfaz de progreso como Google Photos

### 📋 Próximas Funcionalidades
- [ ] Generación automática de thumbnails
- [ ] Frontend para subida y visualización de archivos
- [ ] Sistema de álbumes y etiquetas
- [ ] Búsqueda avanzada por metadatos
- [ ] Compartir archivos entre usuarios

## 🛡️ Seguridad y Permisos

### Modelo de Seguridad
```
Usuario Autenticado → Cognito Identity Pool → IAM Role → S3 Access
                                                      ↓
                              Acceso SOLO a: s3://bucket/{user-id}/*
```

### Políticas de Acceso
- **Principio de Menor Privilegio**: Usuarios solo acceden a sus archivos
- **Segregación por Path**: Cada usuario tiene su prefijo único en S3
- **Tokens Temporales**: Acceso mediante signed URLs con expiración
- **Auditoría**: Logs de CloudTrail para todas las operaciones

## 🎨 Experiencia de Usuario

### Interfaz Inspirada en Google Photos
- **Dashboard Principal**: Vista de medios organizados por fecha
- **Navegación Intuitiva**: Sidebar con categorías y estadísticas
- **Subida Drag & Drop**: Interfaz moderna para cargar archivos
- **Vista Previa**: Thumbnails optimizados para carga rápida
- **Búsqueda Inteligente**: Por fecha, ubicación, objetos detectados

### Responsive Design
- **Mobile First**: Optimizado para dispositivos móviles
- **Progressive Web App**: Funcionalidad offline parcial
- **Carga Lazy**: Optimización de rendimiento para grandes colecciones

## 📈 Escalabilidad y Rendimiento

### Optimizaciones Implementadas
- **Pay-per-Request**: DynamoDB sin capacidad reservada
- **Lifecycle Policies**: Transición automática a storage classes más económicos
- **Deduplicación**: Ahorro de espacio mediante hash de archivos
- **Thumbnails**: Múltiples resoluciones para diferentes dispositivos
- **CDN Ready**: Preparado para integración con CloudFront

### Métricas de Rendimiento
- **Subida**: Directa a S3 con signed URLs
- **Metadatos**: Consultas sub-100ms en DynamoDB
- **Procesamiento**: Lambda asíncrono para no bloquear UX
- **Búsqueda**: Índices optimizados para consultas complejas

## 🚀 Sistema de Carga en Background

### 🎯 Arquitectura de Upload (Como Google Photos)
```
Frontend (React) → API Gateway → Lambda Upload → S3 Multipart
                                      ↓
                                  EventBridge
                                      ↓
                              Lambda Processor
                                      ↓
                              DynamoDB + Rekognition
                                      ↓
                              WebSocket/SSE
                                      ↓
                              Frontend Updates
```

### 📊 Flujo de Carga
1. **Selección de Archivos**: Drag & drop o selector múltiple
2. **Chunking**: División en partes de 5MB para upload paralelo
3. **Multipart Upload**: Carga resiliente con retry automático
4. **EventBridge Trigger**: S3 envía evento a EventBridge automáticamente
5. **Lambda Processing**: Procesamiento asíncrono via EventBridge
6. **AI Analysis**: Rekognition + metadatos EXIF automáticos
7. **DynamoDB Storage**: Almacenamiento de metadatos completos
8. **Real-time Updates**: Notificaciones WebSocket al frontend
9. **Completion**: Archivos disponibles con thumbnails

### 🔧 Componentes del Sistema
- **API Gateway**: Endpoints para upload (initiate/chunk/complete)
- **Lambda Upload**: Manejo de multipart uploads a S3
- **EventBridge**: Orquestación de eventos de procesamiento
- **Lambda Processor**: Análisis AI y generación de metadatos
- **WebSocket API**: Notificaciones en tiempo real
- **S3 Bucket**: Almacenamiento con estructura por usuario

### 📱 Estados de Carga
- ⏳ **Uploading**: Progreso de chunks con barra visual
- 🔄 **Processing**: Análisis AI y extracción de metadatos
- 📸 **Generating**: Creación de thumbnails automáticos
- ✅ **Complete**: Archivo disponible en la galería

## 🔮 Roadmap Futuro


### Fase 2: Funcionalidades Avanzadas
- [ ] Reconocimiento facial y agrupación de personas
- [ ] Álbumes inteligentes automáticos
- [ ] Compartir archivos con otros usuarios
- [ ] Integración con redes sociales
- [ ] Backup automático desde dispositivos móviles

### Fase 3: Inteligencia Artificial
- [ ] Búsqueda por contenido visual
- [ ] Etiquetado automático inteligente
- [ ] Detección de duplicados similares (no idénticos)
- [ ] Sugerencias de organización automática
- [ ] Análisis de calidad de imagen

### Fase 4: Colaboración
- [ ] Espacios compartidos familiares
- [ ] Comentarios y reacciones
- [ ] Versionado colaborativo
- [ ] Permisos granulares de compartir

## 🚀 Despliegue

### ⚠️ IMPORTANTE: Configuración AWS
**USAR ÚNICAMENTE el perfil**: `my-student-user`

```bash
# Verificar perfil AWS
aws configure list --profile my-student-user

# Configurar perfil si es necesario
aws configure --profile my-student-user
```

### Comandos de Despliegue
```bash
# Infraestructura
cd infrastructure-iac-terragrunt/gildarck/dev/us-east-1
export AWS_PROFILE=my-student-user
terragrunt run-all apply --terragrunt-non-interactive

# Frontend
cd frontend-main-front
npm install
npm run build
npm run deploy
```

## 📞 Contacto y Contribución

**Desarrollado por**: Equipo Gildarck  
**Tecnología**: AWS + React + Terraform  
**Licencia**: Propietaria  

---

*Gildarck - Almacenamiento inteligente y seguro para tus recuerdos digitales* 📸✨
