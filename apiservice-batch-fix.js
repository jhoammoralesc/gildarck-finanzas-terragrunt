// Fix para ApiService - Manejo correcto de respuestas batch upload
// Este código debe reemplazar o complementar el ApiService existente

class ApiService {
    constructor(baseURL) {
        this.baseURL = baseURL;
    }

    async makeRequest(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        
        try {
            console.log(`🔄 Making request to: ${endpoint}`);
            console.log(`📤 Request options:`, options);
            
            const response = await fetch(url, {
                headers: {
                    'Content-Type': 'application/json',
                    ...options.headers
                },
                ...options
            });

            console.log(`📊 Response status: ${response.status}`);
            console.log(`📊 Response headers:`, Object.fromEntries(response.headers.entries()));

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            // Obtener el texto crudo primero
            const responseText = await response.text();
            console.log(`📊 Raw response text:`, responseText);

            // Intentar parsear como JSON
            let responseData;
            try {
                responseData = JSON.parse(responseText);
                console.log(`📊 Parsed JSON:`, responseData);
            } catch (parseError) {
                console.error(`❌ JSON parse error:`, parseError);
                throw new Error(`Invalid JSON response: ${responseText}`);
            }

            // CRÍTICO: Para batch-initiate, verificar masterBatchId
            if (endpoint.includes('batch-initiate')) {
                console.log(`🔍 Batch-initiate response analysis:`);
                console.log(`📊 masterBatchId:`, responseData.masterBatchId);
                console.log(`📊 Type of masterBatchId:`, typeof responseData.masterBatchId);
                
                if (!responseData.masterBatchId) {
                    console.error(`❌ Missing masterBatchId in response:`, responseData);
                    throw new Error('Missing masterBatchId in batch-initiate response');
                }
            }

            return responseData;

        } catch (error) {
            console.error(`❌ Request failed for ${endpoint}:`, error);
            throw error;
        }
    }

    // Método específico para batch upload con logging detallado
    async initiateBatchUpload(files) {
        console.log(`🚀 Initiating batch upload for ${files.length} files`);
        
        const response = await this.makeRequest('/upload/batch-initiate', {
            method: 'POST',
            body: JSON.stringify({ files }),
            headers: {
                'Authorization': this.getAuthToken()
            }
        });

        // Validación adicional específica para batch
        if (!response.masterBatchId) {
            console.error('❌ CRITICAL: No masterBatchId in response:', response);
            throw new Error('Batch initiate failed: No masterBatchId received');
        }

        console.log(`✅ Batch initiated successfully. masterBatchId: ${response.masterBatchId}`);
        return response;
    }

    // Método para verificar estado del batch
    async checkBatchStatus(masterBatchId) {
        if (!masterBatchId || masterBatchId === 'undefined') {
            console.error('❌ Invalid masterBatchId for status check:', masterBatchId);
            throw new Error('Invalid masterBatchId provided');
        }

        console.log(`🔍 Checking batch status for: ${masterBatchId}`);
        
        return await this.makeRequest(`/upload/batch-status?masterBatchId=${masterBatchId}`, {
            method: 'GET',
            headers: {
                'Authorization': this.getAuthToken()
            }
        });
    }

    getAuthToken() {
        // Implementar según el sistema de auth existente
        return localStorage.getItem('authToken') || '';
    }
}

// Ejemplo de uso correcto
async function testBatchUpload() {
    const apiService = new ApiService('https://gslxbu791e.execute-api.us-east-1.amazonaws.com/dev');
    
    const testFiles = [
        { filename: 'test1.jpg', content_type: 'image/jpeg', file_size: 1000 },
        { filename: 'test2.jpg', content_type: 'image/jpeg', file_size: 2000 }
    ];

    try {
        // Iniciar batch upload
        const batchResponse = await apiService.initiateBatchUpload(testFiles);
        console.log('✅ Batch initiated:', batchResponse);

        // Verificar estado
        const statusResponse = await apiService.checkBatchStatus(batchResponse.masterBatchId);
        console.log('✅ Batch status:', statusResponse);

    } catch (error) {
        console.error('❌ Batch upload failed:', error);
    }
}

// Export para uso en el frontend
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ApiService;
}
