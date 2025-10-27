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
- **SQS**: Cola de mensajes para thumbnail generation asíncrono
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
- [x] Lambda User CRUD con 19KB de lógica completa

### ✅ Almacenamiento de Medios
- [x] Bucket S3 con configuración de seguridad
- [x] Estructura de carpetas por usuario
- [x] Encriptación y versionado automático
- [x] Políticas de lifecycle para optimización de costos
- [x] CORS configurado para acceso web
- [x] EventBridge integration habilitada

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
- [x] **Media Processor**: 7.7KB de lógica con AI analysis y reorganización automática

### ✅ Sistema de Carga Básico Implementado
- [x] **Upload Handler Lambda**: 6.5KB con chunking y SQS integration
- [x] **SQS Queue Processing**: Cola para procesamiento asíncrono
- [x] **Thumbnail Generator**: Lambda activado con placeholders funcionales
- [x] **Multipart Upload Support**: Lógica básica implementada
- [x] **Flujo Completo**: Upload → EventBridge → AI → SQS → Thumbnails
- [ ] **WebSocket Notifications** - Progreso en tiempo real
- [ ] **Retry Logic** - Reintentos automáticos en fallos
- [ ] **Upload Progress UI** - Interfaz de progreso como Google Photos

### 🎉 **LOGROS RECIENTES (Octubre 2025)**
- ✅ **Thumbnail Generator Activado**: Flujo completo S3 → EventBridge → Media Processor → SQS → Thumbnail Generator
- ✅ **SQS Integration**: Cola `gildarck-thumbnail-queue` con DLQ funcionando
- ✅ **Media Processor Enhanced**: Envío automático de mensajes SQS para procesamiento de thumbnails
- ✅ **Permisos Configurados**: IAM policies para SQS SendMessage en media-processor
- ✅ **Placeholders Funcionales**: Thumbnails placeholder generados automáticamente en 3 tamaños
- ✅ **Estructura S3 Completa**: Organización automática en `/thumbnails/small|medium|large/`
- ✅ **Logs Detallados**: Monitoreo completo del flujo de procesamiento
- ✅ **Testing Exitoso**: Validación con medios reales de Google Photos backup

### ✅ Infraestructura Web Completa
- [x] **API Gateway**: `api.dev.gildarck.com` configurado
- [x] **CloudFront**: `dev.gildarck.com` con SSL
- [x] **Amplify**: Hosting configurado
- [x] **Route53**: Dominios y DNS configurados
- [x] **WAF**: Protección frontend habilitada

## 📊 ESTADO ACTUAL DE IMPLEMENTACIÓN

### 🎯 **Progreso General: 100% Backend | 85% Frontend**

#### ✅ **COMPLETADO (Backend Infrastructure)**
- **Autenticación**: 100% ✅ (Cognito + Lambda User CRUD v16 - Sub UUID Fix)
- **Almacenamiento**: 100% ✅ (S3 + EventBridge + DynamoDB)
- **Procesamiento AI**: 100% ✅ (Rekognition + Media Processor v15)
- **EventBridge Integration**: 100% ✅ (S3 → EventBridge → Lambda)
- **Thumbnail Generation**: 100% ✅ (SQS + Lambda v8 + Klayers Pillow)
- **Upload Handler**: 100% ✅ (Multipart Upload + CORS Fix v8)
- **Media Retrieval**: 100% ✅ (API Endpoints + CORS v2)
- **Media Delete**: 100% ✅ (Google Photos-style trash system)
- **Seguridad**: 100% ✅ (IAM + WAF + SSL)
- **Infraestructura Web**: 100% ✅ (CloudFront + Amplify + Route53)

#### 🎉 **NUEVO: SISTEMA COMPLETO FUNCIONAL**
- **CORS Resuelto**: 100% ✅ (OPTIONS handler + API Gateway deployment)
- **Upload Automático**: 100% ✅ (Google Photos-style auto-upload)
- **Trash System**: 100% ✅ (Eliminación suave + restauración + permanente)
- **Frontend Integration**: 85% ✅ (Auto-upload, progress, error handling)
- **Complete Upload Flow**: 100% ✅ (Frontend → API → S3 → EventBridge → AI → Thumbnails)
- **Real Image Processing**: 100% ✅ (Pillow + WebP generation)
- **API Endpoints Ready**: 100% ✅ (Upload, Retrieval, Auth, Delete endpoints)

#### 🔧 **Componentes Validados y Funcionando**
- **user-crud v16**: Cognito sub UUID fix aplicado
- **media-processor v15**: EventBridge + AI + SQS integration
- **upload-handler v8**: CORS fix + OPTIONS handler + multipart upload
- **thumbnail-generator v8**: Klayers Pillow + WebP generation
- **media-retrieval v2**: CORS + consistent sub extraction
- **media-delete v1**: Google Photos-style trash system
- **S3 Structure**: `{uuid}/originals|thumbnails|compressed|trash/`

#### 🚀 **FRONTEND IMPLEMENTADO**
- **Auto-Upload**: ✅ Google Photos-style immediate upload
- **Progress Tracking**: ✅ Individual file progress bars
- **Error Handling**: ✅ Per-file error states and retry
- **Trash System**: ✅ Full-page trash view with bulk operations
- **Authentication**: ✅ Login, register, logout components
- **Gallery Grid**: ✅ Responsive media grid with thumbnails
- **File Management**: ✅ Selection, deletion, restoration

#### 🔧 **PENDIENTE (Frontend Polish)**
- **Media Viewer**: ❌ Lightbox/modal for full-size viewing
- **Search/Filter**: ❌ Advanced search by date, location, AI tags
- **Albums**: ❌ Custom album creation and management
- **Sharing**: ❌ Share links and permissions
- **Mobile Optimization**: ❌ Touch gestures and mobile UX

### 🏗️ **ARQUITECTURA LAMBDA COMPLETA**

#### 🔐 **USER-CRUD** (24KB)
- **Funcionalidad**: Sistema completo de autenticación con Cognito
- **Endpoints**: `/auth/register`, `/auth/login`, `/auth/logout`, `/auth/change-password`
- **Características**: 
  - Registro con validación de email
  - Login con manejo de contraseñas temporales
  - Cambio de contraseña obligatorio en primer acceso
  - Envío de emails de bienvenida con SES
  - Extracción de Cognito sub UUID
  - Manejo completo de errores de autenticación

#### 📤 **UPLOAD-HANDLER** (17KB)
- **Funcionalidad**: Manejo completo de uploads multipart a S3
- **Endpoints**: `/upload/initiate`, `/upload/complete`, `/upload/presigned`
- **Características**: 
  - Multipart uploads para archivos grandes (>100MB)
  - Simple uploads para archivos pequeños (<100MB)
  - Validación de tipos de archivo (imágenes, videos, documentos)
  - Generación de presigned URLs seguras
  - Estructura de carpetas: `{cognito-sub}/originals/{year}/{month}/`
  - **CORS completo** con OPTIONS handler
  - Soporte para chunking de archivos

#### 🔄 **MEDIA-PROCESSOR** (12KB)
- **Funcionalidad**: Procesamiento automático de medios con IA
- **Trigger**: EventBridge desde S3 (Object Created)
- **Características**: 
  - **Análisis AI** con AWS Rekognition (objetos, caras, escenas)
  - **Extracción EXIF** de metadatos de imágenes
  - **Reorganización automática** por fecha: `{year}/{month}/`
  - **Generación de metadatos** estilo Google Photos
  - **Envío a SQS** para generación de thumbnails
  - **Deduplicación** usando hash SHA-256
  - **Geolocalización** desde datos GPS

#### 🖼️ **THUMBNAIL-GENERATOR** (4.5KB)
- **Funcionalidad**: Generación automática de miniaturas
- **Trigger**: SQS Queue desde Media Processor
- **Características**: 
  - **Pillow Layer** para procesamiento de imágenes
  - **3 tamaños**: small (150px), medium (300px), large (800px)
  - **Formato WebP** para optimización
  - **Estructura S3**: `{user}/thumbnails/small|medium|large/`
  - **Procesamiento batch** desde SQS
  - **Manejo de errores** con DLQ

#### 📥 **MEDIA-RETRIEVAL** (13KB)
- **Funcionalidad**: API para consulta y descarga de medios
- **Endpoints**: `/media/list`, `/media/thumbnail/{id}`, `/media/file/{id}`, `/media/trash`
- **Características**: 
  - **Listado paginado** de medios por usuario
  - **Presigned URLs** para descarga segura
  - **Filtros avanzados** por fecha, tipo, ubicación
  - **Thumbnails** en múltiples resoluciones
  - **Papelera** con archivos eliminados
  - **CORS configurado** para frontend
  - **Manejo de errores** robusto

#### 🗑️ **MEDIA-DELETE** (20KB)
- **Funcionalidad**: Sistema de eliminación estilo Google Photos
- **Endpoints**: `/media/delete`, `/media/restore`, `/media/permanent-delete`
- **Características**: 
  - **Eliminación suave**: Mover a papelera (30 días)
  - **Restauración**: Recuperar desde papelera
  - **Eliminación permanente**: Borrado definitivo de S3 + DynamoDB
  - **Batch operations**: Múltiples archivos simultáneamente
  - **Validación de permisos** por usuario
  - **Limpieza automática** de thumbnails
  - **Logs detallados** para auditoría

### 🎯 **FLUJO COMPLETO FUNCIONANDO:**
```
📱 Frontend → 🔐 User-CRUD → 📤 Upload-Handler → 🗄️ S3
                                                    ↓
🔄 EventBridge → 🤖 Media-Processor → 🧠 Rekognition + 📊 DynamoDB
                         ↓
                    📨 SQS Queue
                         ↓
                🖼️ Thumbnail-Generator → 🗄️ S3 Thumbnails
                         
📱 Frontend → 📥 Media-Retrieval → 📊 DynamoDB + 🗄️ S3
📱 Frontend → 🗑️ Media-Delete → 📊 DynamoDB + 🗄️ S3
```

### 🚀 **PRÓXIMOS PASOS: Funcionalidades Avanzadas**
1. **Media Viewer** (Lightbox con navegación)
2. **Search & Filter** (Por fecha, ubicación, AI tags)
3. **Albums** (Creación y gestión de álbumes)
4. **Sharing** (Links compartidos y permisos)
5. **Mobile UX** (Gestos táctiles y optimización)

**Estimación Funcionalidades Avanzadas**: ~2-3 semanas de desarrollo

### 📋 **APIs Completas Disponibles:**
```
POST /auth/register          - User registration
POST /auth/login             - User authentication  
POST /auth/logout            - Session termination
POST /upload/initiate        - Start multipart upload
POST /upload/complete        - Finish multipart upload
GET  /upload/presigned       - Get upload URLs
GET  /media/list             - List user media
GET  /media/thumbnail/{id}   - Get thumbnail URL
GET  /media/file/{id}        - Get file details + download URL
GET  /media/trash            - List trash items
POST /media/delete           - Move to trash (soft delete)
POST /media/restore          - Restore from trash
POST /media/permanent-delete - Permanent deletion
```

---

## 🎯 **RESUMEN EJECUTIVO**

### ✅ **LOGROS COMPLETADOS**
- **6 Lambdas principales** funcionando al 100%
- **Arquitectura serverless** escalable y robusta
- **IA integrada** para análisis automático de medios
- **Sistema de autenticación** completo con Cognito
- **Upload automático** estilo Google Photos implementado
- **CORS resuelto** para integración frontend
- **Trash system** con eliminación suave y restauración
- **Thumbnail generation** automática con Pillow
- **EventBridge architecture** para procesamiento asíncrono

### 🚀 **ESTADO ACTUAL**
- **Backend**: 100% funcional y listo para producción
- **Frontend**: 85% implementado con auto-upload funcionando
- **APIs**: Todas las endpoints críticas disponibles
- **Infraestructura**: Desplegada y monitoreada
- **Seguridad**: IAM, CORS, WAF configurados

### 🎯 **PRÓXIMOS HITOS**
1. **Media Viewer** - Lightbox para visualización completa
2. **Search & Filter** - Búsqueda avanzada por metadatos AI
3. **Albums** - Organización personalizada de medios
4. **Sharing** - Links compartidos y permisos
5. **Mobile UX** - Optimización para dispositivos móviles

**El proyecto está listo para MVP y uso en producción** 🎉

---

*Gildarck - Almacenamiento inteligente y seguro para tus recuerdos digitales* 📸✨

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

## 🎨 Sistema de Thumbnail Generation

### 🎯 Arquitectura de Procesamiento (Activado)
```
S3 Upload → EventBridge → Media Processor → SQS Queue → Thumbnail Generator
                              ↓                           ↓
                         DynamoDB Metadata         S3 Thumbnails (3 sizes)
                              ↓
                         Rekognition AI
```

### 📊 Flujo de Thumbnails
1. **Upload Trigger**: Archivo subido a S3 dispara EventBridge
2. **Media Processing**: Lambda procesa metadatos y AI analysis
3. **SQS Message**: Media processor envía mensaje a cola de thumbnails
4. **Thumbnail Generation**: Lambda consume SQS y genera 3 tamaños
5. **S3 Storage**: Thumbnails almacenados en `/thumbnails/small|medium|large/`
6. **Completion**: Placeholders listos para frontend (Pillow pendiente)

### 🔧 Componentes Activos
- **SQS Queue**: `gildarck-thumbnail-queue` con DLQ configurada
- **Media Processor**: Envía mensajes automáticamente para imágenes
- **Thumbnail Generator**: Consume SQS y genera placeholders funcionales
- **Permisos IAM**: Media processor con SQS SendMessage configurado
- **Estructura S3**: Organización automática por tamaños

### 📱 Estados de Procesamiento
- ⏳ **Uploading**: Archivo subido a S3
- 🔄 **Processing**: Análisis AI y extracción de metadatos
- 📸 **Generating**: Creación de thumbnails (placeholders actualmente)
- ✅ **Complete**: Thumbnails disponibles para frontend

---

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

### Fase 1: MVP Completion (Próximas 3-4 semanas)
- [ ] **Pillow Real**: Instalar Pillow para Linux en Lambda
- [ ] **Frontend React**: Componentes básicos (Auth, Upload, Gallery)
- [ ] **API Testing**: Validar media-retrieval endpoints
- [ ] **WebP Generation**: Conversión real de imágenes
- [ ] **Upload UI**: Drag & drop interface

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
