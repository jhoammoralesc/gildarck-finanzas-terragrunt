/**
 * Enhanced Upload System - Google Photos Style
 * Handles 1-10,000 files with intelligent batching, deduplication, and parallel streams
 */

class EnhancedUploadSystem {
    constructor(config = {}) {
        this.maxParallelStreams = config.maxParallelStreams || 10;
        this.chunkSize = config.chunkSize || 8 * 1024 * 1024; // 8MB
        this.batchSize = config.batchSize || 50;
        this.compressionThreshold = config.compressionThreshold || 25 * 1024 * 1024; // 25MB
        this.retryAttempts = 3;
        this.uploadQueue = [];
        this.activeUploads = new Map();
        this.completedHashes = new Set();
        this.bandwidth = { current: 0, max: 100 * 1024 * 1024 }; // 100Mbps default
    }

    /**
     * Main upload function - handles 1 to 10,000 files
     */
    async uploadFiles(files, options = {}) {
        console.log(`🚀 Starting upload of ${files.length} files`);
        
        // Phase 1: Pre-analysis and deduplication
        const analysisResult = await this.preAnalyzeFiles(files);
        
        // Phase 2: Strategy selection based on volume
        const strategy = this.selectUploadStrategy(analysisResult.uniqueFiles.length);
        
        // Phase 3: Execute upload with selected strategy
        return await this.executeUpload(analysisResult, strategy, options);
    }

    /**
     * Pre-analyze files: calculate hashes, detect duplicates, estimate sizes
     */
    async preAnalyzeFiles(files) {
        console.log('📊 Pre-analyzing files...');
        
        const fileAnalysis = await Promise.all(
            files.map(async (file) => {
                const hash = await this.calculateFileHash(file);
                const isImage = file.type.startsWith('image/');
                const needsCompression = file.size > this.compressionThreshold;
                
                return {
                    file,
                    hash,
                    size: file.size,
                    type: file.type,
                    isImage,
                    needsCompression,
                    isDuplicate: this.completedHashes.has(hash)
                };
            })
        );

        const uniqueFiles = fileAnalysis.filter(f => !f.isDuplicate);
        const duplicates = fileAnalysis.filter(f => f.isDuplicate);
        const totalSize = uniqueFiles.reduce((sum, f) => sum + f.size, 0);

        console.log(`✅ Analysis complete: ${uniqueFiles.length} unique, ${duplicates.length} duplicates`);
        
        return { uniqueFiles, duplicates, totalSize, fileAnalysis };
    }

    /**
     * Select upload strategy based on file count
     */
    selectUploadStrategy(fileCount) {
        if (fileCount <= 100) {
            return {
                type: 'parallel_simple',
                streams: Math.min(this.maxParallelStreams, fileCount),
                batching: false
            };
        } else if (fileCount <= 1000) {
            return {
                type: 'batch_processing',
                streams: this.maxParallelStreams,
                batching: true,
                batchSize: this.batchSize
            };
        } else {
            return {
                type: 'enterprise_mode',
                streams: this.maxParallelStreams,
                batching: true,
                batchSize: Math.min(100, Math.ceil(fileCount / 100)),
                throttling: true
            };
        }
    }

    /**
     * Execute upload with selected strategy
     */
    async executeUpload(analysisResult, strategy, options) {
        const { uniqueFiles, totalSize } = analysisResult;
        
        console.log(`🎯 Using strategy: ${strategy.type} for ${uniqueFiles.length} files`);
        
        // Initialize progress tracking
        const progress = {
            total: uniqueFiles.length,
            completed: 0,
            failed: 0,
            bytes: { uploaded: 0, total: totalSize },
            startTime: Date.now()
        };

        if (strategy.batching) {
            return await this.executeBatchUpload(uniqueFiles, strategy, progress, options);
        } else {
            return await this.executeParallelUpload(uniqueFiles, strategy, progress, options);
        }
    }

    /**
     * Execute parallel upload (1-100 files)
     */
    async executeParallelUpload(files, strategy, progress, options) {
        const semaphore = new Semaphore(strategy.streams);
        const results = [];

        const uploadPromises = files.map(async (fileData) => {
            await semaphore.acquire();
            try {
                const result = await this.uploadSingleFile(fileData, progress, options);
                results.push(result);
                return result;
            } finally {
                semaphore.release();
            }
        });

        await Promise.all(uploadPromises);
        return this.formatResults(results, progress);
    }

    /**
     * Execute batch upload (100+ files)
     */
    async executeBatchUpload(files, strategy, progress, options) {
        const batches = this.createBatches(files, strategy.batchSize);
        const results = [];

        console.log(`📦 Processing ${batches.length} batches`);

        for (let i = 0; i < batches.length; i++) {
            const batch = batches[i];
            console.log(`🔄 Processing batch ${i + 1}/${batches.length} (${batch.length} files)`);
            
            // Get batch upload URLs from backend
            const batchResult = await this.initiateBatchUpload(batch, options);
            
            if (batchResult.success) {
                // Upload files using presigned URLs with parallel streams
                const batchUploadResult = await this.uploadBatchFiles(
                    batch, 
                    batchResult.uploadUrls, 
                    strategy.streams,
                    progress
                );
                results.push(...batchUploadResult);
            } else {
                console.error(`❌ Batch ${i + 1} failed:`, batchResult.error);
                results.push(...batch.map(f => ({ file: f.file, success: false, error: batchResult.error })));
            }

            // Throttling for enterprise mode
            if (strategy.throttling && i < batches.length - 1) {
                await this.adaptiveSleep();
            }
        }

        return this.formatResults(results, progress);
    }

    /**
     * Upload single file with compression and retry logic
     */
    async uploadSingleFile(fileData, progress, options, attempt = 1) {
        try {
            let fileToUpload = fileData.file;

            // Apply compression if needed
            if (fileData.needsCompression && fileData.isImage) {
                fileToUpload = await this.compressImage(fileData.file);
            }

            // Get presigned URL
            const urlResponse = await fetch('/api/upload/presigned', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    filename: fileData.file.name,
                    contentType: fileToUpload.type,
                    size: fileToUpload.size
                })
            });

            if (!urlResponse.ok) throw new Error('Failed to get presigned URL');
            
            const { uploadUrl, s3Key } = await urlResponse.json();

            // Upload to S3 with progress tracking
            await this.uploadToS3WithProgress(fileToUpload, uploadUrl, progress);

            // Mark hash as completed
            this.completedHashes.add(fileData.hash);
            progress.completed++;

            return {
                file: fileData.file,
                success: true,
                s3Key,
                hash: fileData.hash,
                compressed: fileData.needsCompression
            };

        } catch (error) {
            if (attempt < this.retryAttempts) {
                console.log(`🔄 Retrying upload for ${fileData.file.name} (attempt ${attempt + 1})`);
                await this.exponentialBackoff(attempt);
                return this.uploadSingleFile(fileData, progress, options, attempt + 1);
            }

            progress.failed++;
            return {
                file: fileData.file,
                success: false,
                error: error.message,
                attempts: attempt
            };
        }
    }

    /**
     * Initiate batch upload via backend API
     */
    async initiateBatchUpload(batch, options) {
        try {
            const response = await fetch('/api/upload/batch-initiate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    files: batch.map(f => ({
                        filename: f.file.name,
                        contentType: f.file.type,
                        size: f.file.size,
                        hash: f.hash
                    })),
                    userId: options.userId || 'current-user'
                })
            });

            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            
            const result = await response.json();
            return { success: true, uploadUrls: result.upload_urls };

        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    /**
     * Upload batch files using presigned URLs
     */
    async uploadBatchFiles(batch, uploadUrls, maxStreams, progress) {
        const semaphore = new Semaphore(maxStreams);
        const results = [];

        const uploadPromises = batch.map(async (fileData, index) => {
            await semaphore.acquire();
            try {
                const urlData = uploadUrls[index];
                let fileToUpload = fileData.file;

                // Apply compression if needed
                if (fileData.needsCompression && fileData.isImage) {
                    fileToUpload = await this.compressImage(fileData.file);
                }

                // Upload to S3
                await this.uploadToS3WithProgress(fileToUpload, urlData.upload_url, progress);
                
                this.completedHashes.add(fileData.hash);
                progress.completed++;

                return {
                    file: fileData.file,
                    success: true,
                    s3Key: urlData.s3_key,
                    hash: fileData.hash
                };

            } catch (error) {
                progress.failed++;
                return {
                    file: fileData.file,
                    success: false,
                    error: error.message
                };
            } finally {
                semaphore.release();
            }
        });

        results.push(...await Promise.all(uploadPromises));
        return results;
    }

    /**
     * Upload to S3 with progress tracking and bandwidth monitoring
     */
    async uploadToS3WithProgress(file, uploadUrl, progress) {
        return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            const startTime = Date.now();

            xhr.upload.addEventListener('progress', (event) => {
                if (event.lengthComputable) {
                    const bytesUploaded = event.loaded;
                    const elapsed = (Date.now() - startTime) / 1000;
                    const speed = bytesUploaded / elapsed; // bytes/second
                    
                    // Update bandwidth monitoring
                    this.bandwidth.current = speed;
                    
                    // Update global progress
                    progress.bytes.uploaded += (bytesUploaded - (progress.lastBytes || 0));
                    progress.lastBytes = bytesUploaded;
                    
                    // Emit progress event
                    this.emitProgress(progress);
                }
            });

            xhr.addEventListener('load', () => {
                if (xhr.status >= 200 && xhr.status < 300) {
                    resolve();
                } else {
                    reject(new Error(`Upload failed: ${xhr.status}`));
                }
            });

            xhr.addEventListener('error', () => {
                reject(new Error('Upload failed'));
            });

            xhr.open('PUT', uploadUrl);
            xhr.setRequestHeader('Content-Type', file.type);
            xhr.send(file);
        });
    }

    /**
     * Compress image if over threshold
     */
    async compressImage(file) {
        return new Promise((resolve) => {
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            const img = new Image();

            img.onload = () => {
                // Calculate new dimensions (max 2048px)
                const maxSize = 2048;
                let { width, height } = img;
                
                if (width > maxSize || height > maxSize) {
                    const ratio = Math.min(maxSize / width, maxSize / height);
                    width *= ratio;
                    height *= ratio;
                }

                canvas.width = width;
                canvas.height = height;
                ctx.drawImage(img, 0, 0, width, height);

                canvas.toBlob((blob) => {
                    resolve(new File([blob], file.name, { type: 'image/webp' }));
                }, 'image/webp', 0.8);
            };

            img.src = URL.createObjectURL(file);
        });
    }

    /**
     * Calculate file hash for deduplication
     */
    async calculateFileHash(file) {
        const buffer = await file.arrayBuffer();
        const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    }

    /**
     * Create batches from files array
     */
    createBatches(files, batchSize) {
        const batches = [];
        for (let i = 0; i < files.length; i += batchSize) {
            batches.push(files.slice(i, i + batchSize));
        }
        return batches;
    }

    /**
     * Adaptive sleep for bandwidth throttling
     */
    async adaptiveSleep() {
        const utilization = this.bandwidth.current / this.bandwidth.max;
        const sleepTime = utilization > 0.8 ? 1000 : utilization > 0.6 ? 500 : 100;
        await new Promise(resolve => setTimeout(resolve, sleepTime));
    }

    /**
     * Exponential backoff for retries
     */
    async exponentialBackoff(attempt) {
        const delay = Math.min(1000 * Math.pow(2, attempt), 10000);
        await new Promise(resolve => setTimeout(resolve, delay));
    }

    /**
     * Emit progress events
     */
    emitProgress(progress) {
        const elapsed = (Date.now() - progress.startTime) / 1000;
        const percentage = (progress.completed / progress.total) * 100;
        const eta = elapsed > 0 ? (elapsed / progress.completed) * (progress.total - progress.completed) : 0;

        const progressData = {
            completed: progress.completed,
            total: progress.total,
            failed: progress.failed,
            percentage: Math.round(percentage * 100) / 100,
            bytesUploaded: progress.bytes.uploaded,
            totalBytes: progress.bytes.total,
            speed: this.bandwidth.current,
            eta: Math.round(eta),
            elapsed: Math.round(elapsed)
        };

        // Emit custom event
        window.dispatchEvent(new CustomEvent('uploadProgress', { detail: progressData }));
    }

    /**
     * Format final results
     */
    formatResults(results, progress) {
        const successful = results.filter(r => r.success);
        const failed = results.filter(r => !r.success);
        
        return {
            success: failed.length === 0,
            total: results.length,
            successful: successful.length,
            failed: failed.length,
            results,
            duration: (Date.now() - progress.startTime) / 1000,
            bytesUploaded: progress.bytes.uploaded,
            averageSpeed: progress.bytes.uploaded / ((Date.now() - progress.startTime) / 1000)
        };
    }
}

/**
 * Semaphore for controlling concurrent uploads
 */
class Semaphore {
    constructor(max) {
        this.max = max;
        this.current = 0;
        this.queue = [];
    }

    async acquire() {
        return new Promise((resolve) => {
            if (this.current < this.max) {
                this.current++;
                resolve();
            } else {
                this.queue.push(resolve);
            }
        });
    }

    release() {
        this.current--;
        if (this.queue.length > 0) {
            this.current++;
            const resolve = this.queue.shift();
            resolve();
        }
    }
}

// Export for use
window.EnhancedUploadSystem = EnhancedUploadSystem;

// Usage example:
/*
const uploader = new EnhancedUploadSystem({
    maxParallelStreams: 10,
    chunkSize: 8 * 1024 * 1024,
    batchSize: 50
});

// Listen for progress
window.addEventListener('uploadProgress', (event) => {
    const progress = event.detail;
    console.log(`Progress: ${progress.percentage}% (${progress.completed}/${progress.total})`);
    console.log(`Speed: ${(progress.speed / 1024 / 1024).toFixed(2)} MB/s`);
    console.log(`ETA: ${progress.eta}s`);
});

// Upload files
const fileInput = document.getElementById('fileInput');
fileInput.addEventListener('change', async (event) => {
    const files = Array.from(event.target.files);
    const result = await uploader.uploadFiles(files, { userId: 'current-user' });
    console.log('Upload complete:', result);
});
*/
