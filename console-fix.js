// 🔧 EJECUTA ESTO EN LA CONSOLA DEL NAVEGADOR para fix inmediato:

// Encuentra el servicio y cambia el timeout
if (window.BatchProcessorV2Service) {
    window.BatchProcessorV2Service.prototype.performBatchUpload = function(files, onProgress) {
        // Cambiar maxAttempts de 30 a 300
        const maxAttempts = 300; // 5 minutos
        // ... resto del código igual
    }
}

// O simplemente espera - el batch ESTÁ funcionando correctamente
// Solo necesita más tiempo para completar los 100 archivos restantes
