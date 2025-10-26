# GILDARCK Media Delete API - Google Photos Style

## Endpoints Disponibles

### 1. Mover a Papelera (Soft Delete)
**POST** `/media/delete`

```json
{
  "action": "trash",
  "file_ids": ["file-uuid-1", "file-uuid-2", "file-uuid-3"]
}
```

**Respuesta:**
```json
{
  "success": true,
  "action": "trash",
  "results": [
    {
      "file_id": "file-uuid-1",
      "success": true,
      "action": "moved_to_trash"
    },
    {
      "file_id": "file-uuid-2", 
      "success": false,
      "error": "File not found"
    }
  ]
}
```

### 2. Eliminar Permanentemente
**POST** `/media/delete`

```json
{
  "action": "delete",
  "file_ids": ["file-uuid-1", "file-uuid-2"]
}
```

**Respuesta:**
```json
{
  "success": true,
  "action": "delete",
  "results": [
    {
      "file_id": "file-uuid-1",
      "success": true,
      "action": "permanently_deleted"
    }
  ]
}
```

### 3. Restaurar desde Papelera
**POST** `/media/delete`

```json
{
  "action": "restore",
  "file_ids": ["file-uuid-1", "file-uuid-2"]
}
```

**Respuesta:**
```json
{
  "success": true,
  "action": "restore", 
  "results": [
    {
      "file_id": "file-uuid-1",
      "success": true,
      "action": "restored"
    }
  ]
}
```

### 4. Listar Elementos en Papelera
**GET** `/media/trash`

**Respuesta:**
```json
{
  "success": true,
  "action": "list_trash",
  "results": {
    "items": [
      {
        "file_id": "file-uuid-1",
        "original_filename": "IMG_20241025_143022.jpg",
        "trash_date": "2024-10-25T14:30:22Z",
        "days_in_trash": 5,
        "auto_delete_in_days": 25,
        "file_size": 2048576,
        "content_type": "image/jpeg",
        "thumbnail_url": "https://s3.amazonaws.com/...",
        "media_type": "image"
      }
    ],
    "count": 1,
    "total_size_bytes": 2048576
  }
}
```

## Flujo de Trabajo Google Photos Style

### 1. **Eliminación Suave (Trash)**
- Los archivos se mueven de `/originals/` a `/trash/`
- Los thumbnails se mueven de `/thumbnails/` a `/trash/thumbnails/`
- El estado en DynamoDB cambia a `"trashed"`
- Se agrega `trash_date` con timestamp
- Los archivos permanecen 30 días en papelera

### 2. **Eliminación Permanente**
- Se eliminan todos los archivos de S3 (original + thumbnails + compressed)
- Se elimina completamente el registro de DynamoDB
- **No hay vuelta atrás**

### 3. **Restauración**
- Los archivos se mueven de `/trash/` de vuelta a `/originals/`
- Los thumbnails se restauran a `/thumbnails/`
- El estado cambia a `"completed"`
- Se elimina `trash_date`

### 4. **Auto-eliminación (30 días)**
- Google Photos elimina automáticamente después de 30 días
- Se puede implementar con EventBridge + Lambda programada

## Estructura S3 Actualizada

```
{cognito-sub}/
├── originals/{year}/{month}/
│   └── {file-id}.{ext}
├── thumbnails/
│   ├── small/{file-id}_s.webp
│   ├── medium/{file-id}_m.webp
│   └── large/{file-id}_l.webp
├── compressed/
│   └── {file-id}_compressed.{ext}
└── trash/
    ├── {year}/{month}/{file-id}.{ext}
    └── thumbnails/
        ├── small/{file-id}_s.webp
        ├── medium/{file-id}_m.webp
        └── large/{file-id}_l.webp
```

## Estados en DynamoDB

```json
{
  "processing_status": "completed|trashed",
  "trash_date": "2024-10-25T14:30:22Z",  // Solo si está en trash
  "s3_paths": {
    "original": "{user_id}/trash/{year}/{month}/{file_id}.jpg"  // Actualizado según ubicación
  },
  "thumbnails": {
    "small": "{user_id}/trash/thumbnails/small/{file_id}_s.webp",
    "medium": "{user_id}/trash/thumbnails/medium/{file_id}_m.webp", 
    "large": "{user_id}/trash/thumbnails/large/{file_id}_l.webp"
  }
}
```

## Autenticación

Todos los endpoints requieren:
- **Header**: `Authorization: Bearer {cognito-jwt-token}`
- **Cognito User Pool**: Autenticación automática via API Gateway
- **User Isolation**: Solo acceso a archivos del usuario autenticado

## Códigos de Error

- **400**: Parámetros inválidos o faltantes
- **401**: No autenticado
- **403**: No autorizado para este archivo
- **404**: Archivo no encontrado
- **500**: Error interno del servidor

## Compatibilidad con Frontend

Esta API está diseñada para ser compatible con interfaces estilo Google Photos:

1. **Selección múltiple**: Soporta arrays de `file_ids`
2. **Operaciones batch**: Procesa múltiples archivos en una sola llamada
3. **Feedback granular**: Respuesta individual por cada archivo
4. **Estados visuales**: Información de días en papelera y auto-eliminación
5. **Thumbnails**: URLs pre-firmadas listas para mostrar

## Ejemplo de Uso en Frontend

```javascript
// Mover archivos a papelera
const trashFiles = async (fileIds) => {
  const response = await fetch('/api/media/delete', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      action: 'trash',
      file_ids: fileIds
    })
  });
  return response.json();
};

// Listar papelera
const getTrashItems = async () => {
  const response = await fetch('/api/media/trash', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  return response.json();
};
```
