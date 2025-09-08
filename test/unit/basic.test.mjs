/**
 * Basic Unit Tests for xz.wasm
 * Core functionality validation for XZ/LZMA2 compression
 */

import { describe, it, beforeAll, afterAll } from 'node:test';
import assert from 'node:assert';
import { compress, decompress, getVersion, getVersionNumber, crc32, crc64, compressBound } from '../../dist/index.mjs';

describe('xz.wasm Basic Functionality', () => {
    
    it('should get version information', async () => {
        const version = await getVersion();
        const versionNumber = await getVersionNumber();
        
        assert.ok(typeof version === 'string');
        assert.ok(version.length > 0);
        assert.ok(typeof versionNumber === 'number');
        assert.ok(versionNumber > 0);
        
        console.log(`XZ Version: ${version} (${versionNumber})`);
    });

    it('should compress and decompress simple data', async () => {
        const original = new TextEncoder().encode('Hello, XZ compression world!');
        
        // Test default compression
        const compressed = await compress(original);
        const decompressed = await decompress(compressed);
        
        assert.ok(compressed.length > 0);
        assert.ok(compressed.length < original.length + 1000); // Reasonable bound
        assert.deepStrictEqual(decompressed, original);
        
        const decodedText = new TextDecoder().decode(decompressed);
        assert.strictEqual(decodedText, 'Hello, XZ compression world!');
    });

    it('should handle different compression levels', async () => {
        const original = new TextEncoder().encode('A'.repeat(1000)); // Repetitive data
        const results = [];
        
        // Test compression levels 0, 3, 6, 9
        for (const level of [0, 3, 6, 9]) {
            const compressed = await compress(original, level);
            const decompressed = await decompress(compressed);
            
            assert.deepStrictEqual(decompressed, original);
            results.push({ level, size: compressed.length });
        }
        
        console.log('Compression levels:', results);
        
        // Generally, higher levels should compress better (though not guaranteed)
        assert.ok(results[3].size <= results[0].size); // Level 9 should be <= level 0
    });

    it('should calculate compression bounds', async () => {
        for (const size of [100, 1000, 10000]) {
            const bound = await compressBound(size);
            assert.ok(bound > size); // Should be larger than input
            assert.ok(bound < size * 2); // Should be reasonable
        }
    });

    it('should calculate CRC checksums', async () => {
        const data = new TextEncoder().encode('test data for checksums');
        
        const crc32Value = await crc32(data);
        const crc64Value = await crc64(data);
        
        assert.ok(typeof crc32Value === 'number');
        assert.ok(typeof crc64Value === 'number');
        assert.ok(crc32Value > 0);
        assert.ok(crc64Value > 0);
        
        // CRC should be consistent
        const crc32Value2 = await crc32(data);
        const crc64Value2 = await crc64(data);
        assert.strictEqual(crc32Value, crc32Value2);
        assert.strictEqual(crc64Value, crc64Value2);
    });

    it('should handle empty data', async () => {
        const empty = new Uint8Array(0);
        
        const compressed = await compress(empty);
        const decompressed = await decompress(compressed);
        
        assert.ok(compressed.length > 0); // XZ format has headers even for empty data
        assert.strictEqual(decompressed.length, 0);
    });

    it('should handle binary data', async () => {
        // Create some binary data
        const original = new Uint8Array(256);
        for (let i = 0; i < 256; i++) {
            original[i] = i;
        }
        
        const compressed = await compress(original);
        const decompressed = await decompress(compressed);
        
        assert.deepStrictEqual(decompressed, original);
    });

    it('should handle large data efficiently', async () => {
        // Test with larger data
        const size = 50000;
        const original = new Uint8Array(size);
        
        // Fill with pattern that should compress well
        for (let i = 0; i < size; i++) {
            original[i] = i % 256;
        }
        
        const startTime = Date.now();
        const compressed = await compress(original, 3); // Use reasonable compression
        const compressTime = Date.now() - startTime;
        
        const startDecomp = Date.now();
        const decompressed = await decompress(compressed);
        const decompTime = Date.now() - startDecomp;
        
        assert.deepStrictEqual(decompressed, original);
        
        // Performance should be reasonable
        const compSpeed = (size / 1024 / 1024) / (compressTime / 1000); // MB/s
        const decompSpeed = (size / 1024 / 1024) / (decompTime / 1000); // MB/s
        
        console.log(`Performance: Compression ${compSpeed.toFixed(2)} MB/s, Decompression ${decompSpeed.toFixed(2)} MB/s`);
        console.log(`Sizes: Original ${size}, Compressed ${compressed.length}, Ratio ${(size / compressed.length).toFixed(2)}x`);
        
        // Performance requirements for XZ compression
        assert.ok(compSpeed > 5, `Compression speed ${compSpeed.toFixed(2)} MB/s should be > 5 MB/s`);
        assert.ok(decompSpeed > 30, `Decompression speed ${decompSpeed.toFixed(2)} MB/s should be > 30 MB/s`);
    });

    it('should reject invalid inputs', async () => {
        // Test invalid compression levels
        const data = new TextEncoder().encode('test');
        
        await assert.rejects(async () => {
            await compress(data, -1);
        });
        
        await assert.rejects(async () => {
            await compress(data, 10);
        });
        
        // Test invalid input types
        await assert.rejects(async () => {
            await compress("not a uint8array");
        });
        
        await assert.rejects(async () => {
            await decompress("not a uint8array");
        });
    });

    it('should handle corrupted data gracefully', async () => {
        const original = new TextEncoder().encode('test data');
        const compressed = await compress(original);
        
        // Corrupt the compressed data
        const corrupted = new Uint8Array(compressed);
        corrupted[corrupted.length - 1] = ~corrupted[corrupted.length - 1]; // Flip bits
        
        await assert.rejects(async () => {
            await decompress(corrupted);
        });
    });
});