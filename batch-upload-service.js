/**
 * Batch Upload Service - Frontend Integration
 * Handles both small and large file uploads automatically
 */

class BatchUploadService {
    constructor(apiBaseUrl, authToken) {
        this.apiBaseUrl = apiBaseUrl;
        this.authToken = authToken;
        this.BATCH_THRESHOLD = 10; // Use batch for 10+ files
        this.MAX_CONCURRENT_UPLOADS = 3; // Rate limiting
    }

    /**
     * Main upload method - automatically chooses strategy
     */
    async uploadFiles(files, onProgress = null) {
        console.log(`Starting upload for ${files.length} files`);
        
        if (files.length >= this.BATCH_THRESHOLD) {
            return this.batchUpload(files, onProgress);
        } else {
            return this.individualUpload(files, onProgress);
        }
    }

    /**
     * Individual upload for small quantities (< 10 files)
     */
    async individualUpload(files, onProgress) {
        console.log(`Using individual upload for ${files.length} files`);
        
        const results = [];
        let completed = 0;

        // Process files with concurrency limit
        const semaphore = new Semaphore(this.MAX_CONCURRENT_UPLOADS);
        
        const uploadPromises = files.map(async (file, index) => {
            await semaphore.acquire();
            
            try {
                const result = await this.uploadSingleFile(file, (progress) => {
                    if (onProgress) {
                        onProgress({
                            type: 'individual',
                            fileIndex: index,
                            fileName: file.name,
                            progress: progress,
                            completed: completed,
                            total: files.length,
                            overallProgress: Math.round((completed / files.length) * 100)
                        });
                    }
                });
                
                completed++;
                results.push({ file: file.name, status: 'success', result });
                
                if (onProgress) {
                    onProgress({
                        type: 'individual',
                        fileIndex: index,
                        fileName: file.name,
                        progress: 100,
                        completed: completed,
                        total: files.length,
                        overallProgress: Math.round((completed / files.length) * 100)
                    });
                }
                
                return result;
            } catch (error) {
                completed++;
                results.push({ file: file.name, status: 'error', error: error.message });
                throw error;
            } finally {
                semaphore.release();
            }
        });

        await Promise.allSettled(uploadPromises);
        return results;
    }

    /**
     * Batch upload for large quantities (10+ files)
     */
    async batchUpload(files, onProgress) {
        console.log(`Using batch upload for ${files.length} files`);
        
        try {
            // Step 1: Initiate batch upload
            const batchRequest = {
                files: files.map(file => ({
                    filename: file.name,
                    contentType: file.type || 'application/octet-stream',
                    fileSize: file.size
                }))
            };

            const response = await fetch(`${this.apiBaseUrl}/upload/batch-initiate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.authToken}`
                },
                body: JSON.stringify(batchRequest)
            });

            if (!response.ok) {
                throw new Error(`Batch initiation failed: ${response.statusText}`);
            }

            const batchInfo = await response.json();
            console.log('Batch initiated:', batchInfo);

            if (onProgress) {
                onProgress({
                    type: 'batch',
                    phase: 'initiated',
                    masterBatchId: batchInfo.masterBatchId,
                    totalFiles: batchInfo.totalFiles,
                    totalBatches: batchInfo.totalBatches,
                    progress: 0,
                    message: 'Batch upload initiated, generating URLs...'
                });
            }

            // Step 2: Poll for batch completion and get URLs
            const urls = await this.pollBatchStatus(batchInfo.masterBatchId, onProgress);
            
            // Step 3: Upload files using generated URLs
            return this.uploadFilesWithUrls(files, urls, onProgress);

        } catch (error) {
            console.error('Batch upload failed:', error);
            throw error;
        }
    }

    /**
     * Poll batch status until URLs are ready
     */
    async pollBatchStatus(masterBatchId, onProgress) {
        const maxAttempts = 60; // 5 minutes max
        let attempts = 0;

        while (attempts < maxAttempts) {
            try {
                const response = await fetch(
                    `${this.apiBaseUrl}/upload/batch-status?masterBatchId=${masterBatchId}`,
                    {
                        headers: {
                            'Authorization': `Bearer ${this.authToken}`
                        }
                    }
                );

                if (!response.ok) {
                    throw new Error(`Status check failed: ${response.statusText}`);
                }

                const status = await response.json();
                console.log('Batch status:', status);

                if (onProgress) {
                    onProgress({
                        type: 'batch',
                        phase: 'processing',
                        masterBatchId: masterBatchId,
                        progress: status.progress || 0,
                        processed: status.processed_files || 0,
                        total: status.total_files || 0,
                        message: status.message || 'Processing batch...'
                    });
                }

                if (status.status === 'completed') {
                    return status.upload_urls || [];
                }

                if (status.status === 'failed') {
                    throw new Error(status.message || 'Batch processing failed');
                }

                // Wait 5 seconds before next poll
                await new Promise(resolve => setTimeout(resolve, 5000));
                attempts++;

            } catch (error) {
                console.error('Error polling batch status:', error);
                attempts++;
                await new Promise(resolve => setTimeout(resolve, 5000));
            }
        }

        throw new Error('Batch processing timeout - please try again');
    }

    /**
     * Upload files using pre-generated URLs
     */
    async uploadFilesWithUrls(files, urls, onProgress) {
        const results = [];
        let completed = 0;
        
        const semaphore = new Semaphore(this.MAX_CONCURRENT_UPLOADS);
        
        const uploadPromises = files.map(async (file, index) => {
            const urlInfo = urls.find(u => u.filename === file.name);
            if (!urlInfo) {
                throw new Error(`No upload URL found for ${file.name}`);
            }

            await semaphore.acquire();
            
            try {
                const result = await this.uploadFileWithUrl(file, urlInfo.upload_url, (progress) => {
                    if (onProgress) {
                        onProgress({
                            type: 'batch',
                            phase: 'uploading',
                            fileIndex: index,
                            fileName: file.name,
                            progress: progress,
                            completed: completed,
                            total: files.length,
                            overallProgress: Math.round((completed / files.length) * 100)
                        });
                    }
                });
                
                completed++;
                results.push({ file: file.name, status: 'success', result });
                return result;
                
            } catch (error) {
                completed++;
                results.push({ file: file.name, status: 'error', error: error.message });
                throw error;
            } finally {
                semaphore.release();
            }
        });

        await Promise.allSettled(uploadPromises);
        return results;
    }

    /**
     * Upload single file (for individual uploads)
     */
    async uploadSingleFile(file, onProgress) {
        // Step 1: Initiate upload
        const response = await fetch(`${this.apiBaseUrl}/upload/initiate`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.authToken}`
            },
            body: JSON.stringify({
                filename: file.name,
                contentType: file.type || 'application/octet-stream',
                fileSize: file.size
            })
        });

        if (!response.ok) {
            throw new Error(`Upload initiation failed: ${response.statusText}`);
        }

        const uploadInfo = await response.json();

        // Step 2: Upload file
        if (uploadInfo.uploadType === 'simple') {
            return this.uploadFileWithUrl(file, uploadInfo.uploadUrl, onProgress);
        } else {
            return this.uploadMultipart(file, uploadInfo, onProgress);
        }
    }

    /**
     * Upload file using presigned URL
     */
    async uploadFileWithUrl(file, uploadUrl, onProgress) {
        return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            
            xhr.upload.addEventListener('progress', (event) => {
                if (event.lengthComputable && onProgress) {
                    const progress = Math.round((event.loaded / event.total) * 100);
                    onProgress(progress);
                }
            });

            xhr.addEventListener('load', () => {
                if (xhr.status >= 200 && xhr.status < 300) {
                    resolve({
                        status: 'uploaded',
                        url: uploadUrl,
                        size: file.size
                    });
                } else {
                    reject(new Error(`Upload failed: ${xhr.statusText}`));
                }
            });

            xhr.addEventListener('error', () => {
                reject(new Error('Upload failed: Network error'));
            });

            xhr.open('PUT', uploadUrl);
            xhr.setRequestHeader('Content-Type', file.type || 'application/octet-stream');
            xhr.send(file);
        });
    }

    /**
     * Handle multipart upload for large files
     */
    async uploadMultipart(file, uploadInfo, onProgress) {
        // Implementation for multipart upload
        // This would handle chunking and parallel part uploads
        console.log('Multipart upload not implemented in this demo');
        throw new Error('Multipart upload not implemented');
    }
}

/**
 * Semaphore for controlling concurrency
 */
class Semaphore {
    constructor(maxConcurrency) {
        this.maxConcurrency = maxConcurrency;
        this.currentConcurrency = 0;
        this.queue = [];
    }

    async acquire() {
        return new Promise((resolve) => {
            if (this.currentConcurrency < this.maxConcurrency) {
                this.currentConcurrency++;
                resolve();
            } else {
                this.queue.push(resolve);
            }
        });
    }

    release() {
        this.currentConcurrency--;
        if (this.queue.length > 0) {
            const next = this.queue.shift();
            this.currentConcurrency++;
            next();
        }
    }
}

/**
 * Usage Example
 */
function exampleUsage() {
    const uploadService = new BatchUploadService(
        'https://api.dev.gildarck.com',
        'your-jwt-token-here'
    );

    // Handle file input change
    document.getElementById('fileInput').addEventListener('change', async (event) => {
        const files = Array.from(event.target.files);
        
        if (files.length === 0) return;

        console.log(`Selected ${files.length} files`);

        try {
            const results = await uploadService.uploadFiles(files, (progress) => {
                updateProgressUI(progress);
            });
            
            console.log('Upload completed:', results);
            showSuccessMessage(`Successfully uploaded ${results.length} files`);
            
        } catch (error) {
            console.error('Upload failed:', error);
            showErrorMessage(`Upload failed: ${error.message}`);
        }
    });
}

/**
 * Update progress UI based on upload type
 */
function updateProgressUI(progress) {
    const progressContainer = document.getElementById('progressContainer');
    
    if (progress.type === 'individual') {
        // Show individual file progress
        document.getElementById('overallProgress').textContent = 
            `Uploading ${progress.completed}/${progress.total} files (${progress.overallProgress}%)`;
        
        document.getElementById('currentFile').textContent = 
            `Current: ${progress.fileName} (${progress.progress}%)`;
            
    } else if (progress.type === 'batch') {
        // Show batch progress
        if (progress.phase === 'initiated') {
            document.getElementById('overallProgress').textContent = 
                `Batch initiated: ${progress.totalFiles} files in ${progress.totalBatches} batches`;
                
        } else if (progress.phase === 'processing') {
            document.getElementById('overallProgress').textContent = 
                `Processing: ${progress.processed}/${progress.total} files (${progress.progress}%)`;
                
        } else if (progress.phase === 'uploading') {
            document.getElementById('overallProgress').textContent = 
                `Uploading: ${progress.completed}/${progress.total} files (${progress.overallProgress}%)`;
                
            document.getElementById('currentFile').textContent = 
                `Current: ${progress.fileName} (${progress.progress}%)`;
        }
    }
}

function showSuccessMessage(message) {
    console.log('Success:', message);
    // Update UI with success message
}

function showErrorMessage(message) {
    console.error('Error:', message);
    // Update UI with error message
}

// Export for use in modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { BatchUploadService, Semaphore };
}
