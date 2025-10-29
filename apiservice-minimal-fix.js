// Fix mínimo para ApiService - Problema de extracción masterBatchId
// Reemplazar el método makeRequest existente con este

async makeRequest(endpoint, options = {}) {
    const response = await fetch(`${this.baseURL}${endpoint}`, {
        headers: { 'Content-Type': 'application/json', ...options.headers },
        ...options
    });

    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const text = await response.text();
    const data = JSON.parse(text);
    
    // CRÍTICO: Log para batch-initiate
    if (endpoint.includes('batch-initiate')) {
        console.log('🔍 Batch response:', data);
        console.log('📊 masterBatchId:', data.masterBatchId);
    }
    
    return data;
}
