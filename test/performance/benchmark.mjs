/**
 * Performance Benchmarks for xz.wasm
 * Performance validation and optimization for XZ/LZMA2 compression
 */

import { performance } from 'perf_hooks';
import { compress, decompress, getVersion } from '../../dist/index.mjs';

// Test data generators
function generateText(size) {
    const text = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ';
    const result = new TextEncoder().encode(text.repeat(Math.ceil(size / text.length)));
    return result.slice(0, size);
}

function generateBinary(size) {
    const result = new Uint8Array(size);
    for (let i = 0; i < size; i++) {
        result[i] = Math.floor(Math.random() * 256);
    }
    return result;
}

function generateRepetitive(size) {
    const pattern = new Uint8Array([1, 2, 3, 4, 5]);
    const result = new Uint8Array(size);
    for (let i = 0; i < size; i++) {
        result[i] = pattern[i % pattern.length];
    }
    return result;
}

async function benchmark() {
    console.log('🔧 XZ.WASM Performance Benchmark Suite');
    console.log('=====================================');
    
    const version = await getVersion();
    console.log(`XZ Version: ${version}`);
    console.log(`Node.js Version: ${process.version}`);
    console.log(`Platform: ${process.platform} ${process.arch}`);
    console.log('');

    const testSizes = [1024, 8192, 65536, 262144]; // 1KB, 8KB, 64KB, 256KB
    const compressionLevels = [1, 3, 6, 9];
    const dataTypes = [
        { name: 'Text', generator: generateText },
        { name: 'Binary', generator: generateBinary },
        { name: 'Repetitive', generator: generateRepetitive }
    ];

    const results = {
        benchmark: 'xz.wasm',
        version: version,
        timestamp: new Date().toISOString(),
        platform: `${process.platform} ${process.arch}`,
        node: process.version,
        tests: []
    };

    for (const dataType of dataTypes) {
        console.log(`📊 Testing ${dataType.name} Data`);
        console.log('─'.repeat(50));

        for (const size of testSizes) {
            const data = dataType.generator(size);
            
            for (const level of compressionLevels) {
                console.log(`  Size: ${(size/1024).toFixed(1)}KB, Level: ${level}, Type: ${dataType.name}`);
                
                // Warmup
                await compress(data.slice(0, Math.min(1024, size)), level);
                
                const iterations = size < 65536 ? 10 : 3; // Fewer iterations for large data
                let totalCompTime = 0;
                let totalDecompTime = 0;
                let compressed = null;
                
                // Compression benchmark
                for (let i = 0; i < iterations; i++) {
                    const start = performance.now();
                    compressed = await compress(data, level);
                    totalCompTime += performance.now() - start;
                }
                
                // Decompression benchmark
                for (let i = 0; i < iterations; i++) {
                    const start = performance.now();
                    const decompressed = await decompress(compressed);
                    totalDecompTime += performance.now() - start;
                    
                    // Verify correctness
                    if (decompressed.length !== data.length) {
                        throw new Error('Decompression size mismatch');
                    }
                }
                
                const avgCompTime = totalCompTime / iterations;
                const avgDecompTime = totalDecompTime / iterations;
                const compSpeed = (size / 1024 / 1024) / (avgCompTime / 1000); // MB/s
                const decompSpeed = (size / 1024 / 1024) / (avgDecompTime / 1000); // MB/s
                const compressionRatio = size / compressed.length;
                
                const testResult = {
                    dataType: dataType.name,
                    size: size,
                    level: level,
                    compressionTime: Math.round(avgCompTime * 100) / 100,
                    decompressionTime: Math.round(avgDecompTime * 100) / 100,
                    compressionSpeed: Math.round(compSpeed * 100) / 100,
                    decompressionSpeed: Math.round(decompSpeed * 100) / 100,
                    originalSize: size,
                    compressedSize: compressed.length,
                    compressionRatio: Math.round(compressionRatio * 100) / 100,
                    spaceSaved: Math.round((1 - compressed.length/size) * 100 * 100) / 100
                };
                
                results.tests.push(testResult);
                
                console.log(`    ⚡ Comp: ${compSpeed.toFixed(1)} MB/s (${avgCompTime.toFixed(2)}ms)`);
                console.log(`    🚀 Decomp: ${decompSpeed.toFixed(1)} MB/s (${avgDecompTime.toFixed(2)}ms)`);
                console.log(`    📦 Ratio: ${compressionRatio.toFixed(2)}x (${testResult.spaceSaved.toFixed(1)}% saved)`);
                console.log('');
            }
        }
        console.log('');
    }

    // Calculate overall statistics
    const allTests = results.tests;
    const avgCompSpeed = allTests.reduce((sum, test) => sum + test.compressionSpeed, 0) / allTests.length;
    const avgDecompSpeed = allTests.reduce((sum, test) => sum + test.decompressionSpeed, 0) / allTests.length;
    const avgRatio = allTests.reduce((sum, test) => sum + test.compressionRatio, 0) / allTests.length;
    
    // Best results
    const bestCompSpeed = Math.max(...allTests.map(t => t.compressionSpeed));
    const bestDecompSpeed = Math.max(...allTests.map(t => t.decompressionSpeed));
    const bestRatio = Math.max(...allTests.map(t => t.compressionRatio));
    
    console.log('🏆 Overall Performance Summary');
    console.log('=====================================');
    console.log(`Average Compression Speed: ${avgCompSpeed.toFixed(1)} MB/s`);
    console.log(`Average Decompression Speed: ${avgDecompSpeed.toFixed(1)} MB/s`);
    console.log(`Average Compression Ratio: ${avgRatio.toFixed(2)}x`);
    console.log(`Best Compression Speed: ${bestCompSpeed.toFixed(1)} MB/s`);
    console.log(`Best Decompression Speed: ${bestDecompSpeed.toFixed(1)} MB/s`);
    console.log(`Best Compression Ratio: ${bestRatio.toFixed(2)}x`);
    console.log('');

    // Performance validation
    console.log('📋 Performance Validation');
    console.log('=====================================');
    
    const compTarget = 15; // MB/s minimum
    const decompTarget = 80; // MB/s minimum
    const ratioTarget = 2.0; // 2x minimum
    
    const compPass = avgCompSpeed >= compTarget;
    const decompPass = avgDecompSpeed >= decompTarget;
    const ratioPass = avgRatio >= ratioTarget;
    
    console.log(`${compPass ? '✅' : '❌'} Compression Speed: ${avgCompSpeed.toFixed(1)} MB/s (target: ≥${compTarget} MB/s)`);
    console.log(`${decompPass ? '✅' : '❌'} Decompression Speed: ${avgDecompSpeed.toFixed(1)} MB/s (target: ≥${decompTarget} MB/s)`);
    console.log(`${ratioPass ? '✅' : '❌'} Compression Ratio: ${avgRatio.toFixed(2)}x (target: ≥${ratioTarget}x)`);
    
    const overallPass = compPass && decompPass && ratioPass;
    console.log(`${overallPass ? '🎉' : '⚠️'} Overall: ${overallPass ? 'PASSED' : 'NEEDS IMPROVEMENT'}`);
    
    results.summary = {
        avgCompressionSpeed: Math.round(avgCompSpeed * 100) / 100,
        avgDecompressionSpeed: Math.round(avgDecompSpeed * 100) / 100,
        avgCompressionRatio: Math.round(avgRatio * 100) / 100,
        bestCompressionSpeed: Math.round(bestCompSpeed * 100) / 100,
        bestDecompressionSpeed: Math.round(bestDecompSpeed * 100) / 100,
        bestCompressionRatio: Math.round(bestRatio * 100) / 100,
        validation: {
            compressionSpeed: { value: avgCompSpeed, target: compTarget, pass: compPass },
            decompressionSpeed: { value: avgDecompSpeed, target: decompTarget, pass: decompPass },
            compressionRatio: { value: avgRatio, target: ratioTarget, pass: ratioPass },
            overall: overallPass
        }
    };
    
    // Output JSON for CI
    console.log('');
    console.log('📄 JSON Results (for CI):');
    console.log(JSON.stringify(results, null, 2));
    
    return results;
}

// Run benchmark if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
    benchmark().catch(console.error);
}

export { benchmark };