// BATCH-ONLY UPLOAD SERVICE
// Siempre usa batch upload, sin importar la cantidad de archivos

class BatchOnlyUploadService {
    constructor(apiBaseUrl, authToken) {
        this.apiBaseUrl = apiBaseUrl;
        this.authToken = authToken;
    }

    async uploadFiles(files, onProgress = null) {
        console.log(`🚀 BATCH UPLOAD: Processing ${files.length} files`);
        
        try {
            // 1. Preparar archivos para batch
            const fileList = Array.from(files).map(file => ({
                filename: file.name,
                content_type: file.type,
                file_size: file.size
            }));

            console.log('📋 File list prepared:', fileList.length, 'files');

            // 2. Iniciar batch upload
            console.log('🔄 Calling /upload/batch-initiate...');
            const initResponse = await fetch(`${this.apiBaseUrl}/upload/batch-initiate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': this.authToken
                },
                body: JSON.stringify({ files: fileList })
            });

            console.log('📡 Batch initiate response status:', initResponse.status);

            if (!initResponse.ok) {
                const errorText = await initResponse.text();
                throw new Error(`Batch initiate failed: ${initResponse.status} - ${errorText}`);
            }

            const initData = await initResponse.json();
            const masterBatchId = initData.masterBatchId;
            
            console.log(`✅ Batch initiated successfully: ${masterBatchId}`);
            console.log('📊 Batch info:', initData);

            if (onProgress) {
                onProgress({
                    type: 'batch_initiated',
                    masterBatchId: masterBatchId,
                    fileCount: initData.fileCount,
                    totalBatches: initData.totalBatches,
                    message: 'Batch upload initiated, processing...'
                });
            }

            // 3. Polling para obtener URLs presignadas
            console.log('⏳ Starting polling for presigned URLs...');
            let attempts = 0;
            const maxAttempts = 60; // 60 segundos máximo
            
            while (attempts < maxAttempts) {
                await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second
                attempts++;
                
                console.log(`🔍 Polling attempt ${attempts}/${maxAttempts}...`);
                
                const statusResponse = await fetch(
                    `${this.apiBaseUrl}/upload/batch-status?masterBatchId=${masterBatchId}`,
                    {
                        headers: { 'Authorization': this.authToken }
                    }
                );

                console.log('📊 Status response:', statusResponse.status);

                if (statusResponse.ok) {
                    const statusData = await statusResponse.json();
                    console.log('📋 Status data:', statusData);
                    
                    if (onProgress) {
                        onProgress({
                            type: 'batch_processing',
                            progress: statusData.progress || 0,
                            message: statusData.message || `Processing... (attempt ${attempts})`
                        });
                    }

                    // Verificar si hay URLs disponibles
                    if (statusData.upload_urls && statusData.upload_urls.length > 0) {
                        console.log(`🎉 Got ${statusData.upload_urls.length} presigned URLs!`);
                        
                        // 4. Upload archivos usando URLs presignadas
                        return await this.uploadWithPresignedUrls(files, statusData.upload_urls, onProgress);
                    }
                } else {
                    console.warn(`⚠️ Status check failed: ${statusResponse.status}`);
                }
            }

            throw new Error(`Batch processing timeout after ${maxAttempts} seconds`);

        } catch (error) {
            console.error('❌ Batch upload error:', error);
            throw error;
        }
    }

    async uploadWithPresignedUrls(files, uploadUrls, onProgress) {
        console.log(`📤 Starting uploads with ${uploadUrls.length} presigned URLs`);
        
        const results = [];
        const fileMap = new Map();
        
        // Crear mapa de archivos por nombre
        Array.from(files).forEach(file => fileMap.set(file.name, file));
        
        // Upload cada archivo con su URL presignada
        for (let i = 0; i < uploadUrls.length; i++) {
            const urlInfo = uploadUrls[i];
            const file = fileMap.get(urlInfo.filename);
            
            if (!file) {
                console.warn(`⚠️ File not found in file list: ${urlInfo.filename}`);
                results.push({
                    filename: urlInfo.filename,
                    status: 'error',
                    error: 'File not found in original file list'
                });
                continue;
            }

            if (urlInfo.error) {
                console.error(`❌ Presigned URL error for ${urlInfo.filename}:`, urlInfo.error);
                results.push({
                    filename: urlInfo.filename,
                    status: 'error',
                    error: urlInfo.error
                });
                continue;
            }

            try {
                console.log(`📤 Uploading ${urlInfo.filename} (${i + 1}/${uploadUrls.length})...`);
                
                const uploadResponse = await fetch(urlInfo.upload_url, {
                    method: 'PUT',
                    body: file,
                    headers: {
                        'Content-Type': urlInfo.content_type
                    }
                });

                if (uploadResponse.ok) {
                    results.push({
                        filename: urlInfo.filename,
                        status: 'success',
                        s3_key: urlInfo.s3_key
                    });
                    console.log(`✅ Successfully uploaded: ${urlInfo.filename}`);
                } else {
                    const errorText = await uploadResponse.text();
                    results.push({
                        filename: urlInfo.filename,
                        status: 'error',
                        error: `Upload failed: ${uploadResponse.status} - ${errorText}`
                    });
                    console.error(`❌ Upload failed for ${urlInfo.filename}: ${uploadResponse.status}`);
                }

            } catch (error) {
                results.push({
                    filename: urlInfo.filename,
                    status: 'error',
                    error: error.message
                });
                console.error(`❌ Upload error for ${urlInfo.filename}:`, error);
            }

            // Progress update después de cada archivo
            if (onProgress) {
                onProgress({
                    type: 'upload_progress',
                    completed: i + 1,
                    total: uploadUrls.length,
                    progress: Math.round(((i + 1) / uploadUrls.length) * 100),
                    current_file: urlInfo.filename,
                    successful: results.filter(r => r.status === 'success').length,
                    failed: results.filter(r => r.status === 'error').length
                });
            }
        }

        const successful = results.filter(r => r.status === 'success').length;
        const failed = results.filter(r => r.status === 'error').length;

        console.log(`🎯 Batch upload completed: ${successful} successful, ${failed} failed`);

        return {
            type: 'batch',
            results: results,
            successful: successful,
            failed: failed,
            total: results.length
        };
    }
}

// EJEMPLO DE USO SIMPLE
/*
const uploadService = new BatchOnlyUploadService(
    'https://gslxbu791e.execute-api.us-east-1.amazonaws.com/dev',
    'your-jwt-token'
);

const files = document.getElementById('fileInput').files;

uploadService.uploadFiles(files, (progress) => {
    console.log('📊 Progress update:', progress);
    
    switch(progress.type) {
        case 'batch_initiated':
            console.log(`🚀 Batch started: ${progress.fileCount} files in ${progress.totalBatches} batches`);
            break;
        case 'batch_processing':
            console.log(`⏳ Processing: ${progress.progress}% - ${progress.message}`);
            break;
        case 'upload_progress':
            console.log(`📤 Uploading: ${progress.completed}/${progress.total} (${progress.progress}%) - ${progress.current_file}`);
            console.log(`✅ Success: ${progress.successful}, ❌ Failed: ${progress.failed}`);
            break;
    }
}).then(result => {
    console.log('🎉 Upload completed:', result);
    console.log(`📊 Final results: ${result.successful} successful, ${result.failed} failed out of ${result.total} total`);
}).catch(error => {
    console.error('💥 Upload failed:', error);
});
*/

export default BatchOnlyUploadService;
