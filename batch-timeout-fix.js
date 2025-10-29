// 🔧 BATCH TIMEOUT FIX - Increase timeout and add better error handling

// In BatchProcessorV2Service.ts, replace the timeout logic:

async performBatchUpload(files) {
    try {
        // 1. Initiate batch
        const batchResponse = await this.initiateBatch(files);
        const { batch_id, strategy } = batchResponse;
        
        if (strategy === 'simple') {
            // Simple strategy returns URLs immediately
            return batchResponse;
        }
        
        // 2. For chunked strategy, poll for completion with extended timeout
        const TIMEOUT_MS = 300000; // 5 minutes instead of 30 seconds
        const POLL_INTERVAL = 2000; // 2 seconds
        const startTime = Date.now();
        
        while (Date.now() - startTime < TIMEOUT_MS) {
            const status = await this.getBatchStatus(batch_id);
            
            console.log(`📊 Batch ${batch_id} status:`, status);
            
            if (status.status === 'completed') {
                return {
                    batch_id,
                    status: 'completed',
                    total_files: status.total_files,
                    processed_files: status.processed_files,
                    strategy: 'chunked'
                };
            }
            
            if (status.status === 'failed') {
                throw new Error(`Batch processing failed: ${status.error || 'Unknown error'}`);
            }
            
            // Show progress
            if (status.total_files > 0) {
                const progress = (status.processed_files / status.total_files) * 100;
                console.log(`📈 Progress: ${progress.toFixed(1)}% (${status.processed_files}/${status.total_files})`);
            }
            
            await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL));
        }
        
        // If we get here, it's a timeout
        throw new Error(`Batch processing timeout after ${TIMEOUT_MS/1000} seconds. Batch may still be processing in background.`);
        
    } catch (error) {
        console.error('Batch upload error:', error);
        throw error;
    }
}

// Also add this method to check batch status without throwing on timeout:
async checkBatchStatusSafe(batch_id) {
    try {
        const status = await this.getBatchStatus(batch_id);
        return status;
    } catch (error) {
        console.warn('Error checking batch status:', error);
        return { status: 'unknown', error: error.message };
    }
}
