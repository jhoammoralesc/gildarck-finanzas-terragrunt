// 🔧 MINIMAL FIX - Replace timeout in BatchProcessorV2Service.ts

// Change this line:
const TIMEOUT_MS = 30000; // OLD: 30 seconds

// To this:
const TIMEOUT_MS = 300000; // NEW: 5 minutes (300 seconds)

// That's it! The batch of 491 files will now have 5 minutes to process instead of 30 seconds.

// Optional: Also update the error message for better UX:
throw new Error(`Batch processing timeout after ${TIMEOUT_MS/1000}s. Batch may still be processing in background.`);
