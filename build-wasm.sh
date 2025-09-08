#!/bin/bash
# Production WASM Build Script for xz.wasm
# High-performance XZ/LZMA2 compression for WebAssembly
#
# Copyright (c) 2025 Superstruct Ltd, New Zealand
# Licensed under the same license as the underlying XZ Utils project (0BSD)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Building xz.wasm${NC}"
echo "======================================================"

# Check for required tools
if ! command -v emcc &> /dev/null; then
    echo -e "${RED}❌ emcc not found. Please install and activate Emscripten SDK.${NC}"
    exit 1
fi

if ! command -v autoconf &> /dev/null; then
    echo -e "${RED}❌ autoconf not found. Please install autotools.${NC}"
    exit 1
fi

# Configuration
BUILD_TYPE=${BUILD_TYPE:-Release}
ENABLE_SIMD=${ENABLE_SIMD:-OFF}
ENABLE_WASM_NATIVE=${ENABLE_WASM_NATIVE:-OFF}
BUILD_DIR="build-wasm-${BUILD_TYPE,,}"
DIST_DIR="dist"

echo -e "${BLUE}Configuration:${NC}"
echo "  Build Type: ${BUILD_TYPE}"
echo "  Enable SIMD: ${ENABLE_SIMD}"
echo "  Enable WASM-Native: ${ENABLE_WASM_NATIVE}"
echo "  Build Directory: ${BUILD_DIR}"

# Clean previous builds
if [ -d "${BUILD_DIR}" ]; then
    echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
    rm -rf "${BUILD_DIR}"
fi

if [ -d "${DIST_DIR}" ]; then
    echo -e "${YELLOW}🧹 Cleaning previous distribution...${NC}"
    rm -rf "${DIST_DIR}"
fi

# Create build directories
mkdir -p "${BUILD_DIR}"
mkdir -p "${DIST_DIR}"

echo -e "${BLUE}📁 Created build directories${NC}"

# Generate configure script if needed
if [ ! -f "configure" ]; then
    echo -e "${BLUE}⚙️  Generating configure script...${NC}"
    ./autogen.sh
fi

# Configure XZ for WASM
echo -e "${BLUE}⚙️  Configuring XZ for WASM...${NC}"

cd "${BUILD_DIR}"

CONFIGURE_ARGS=(
    "--disable-xz"
    "--disable-xzdec"
    "--disable-lzmadec"
    "--disable-lzmainfo"
    "--disable-lzmalinks"
    "--disable-scripts"
    "--disable-doc"
    "--disable-shared"
    "--enable-static"
    "--disable-nls"
    "--host=wasm32-unknown-emscripten"
)

# Configure with emscripten
emconfigure ../configure "${CONFIGURE_ARGS[@]}" || {
    echo -e "${RED}❌ Configuration failed${NC}"
    exit 1
}

echo -e "${GREEN}✅ Configuration completed${NC}"

# Build static library
echo -e "${BLUE}🔨 Building static library...${NC}"

emmake make -j$(nproc) || {
    echo -e "${RED}❌ Static library build failed${NC}"
    exit 1
}

echo -e "${GREEN}✅ Static library built${NC}"

# Prepare EMCC arguments
EMCC_BASE_ARGS=(
    # Source files
    ../wasm/wasm_module.c
    src/liblzma/.libs/liblzma.a
    
    # Include directories
    -I../src/liblzma/api
    
    # Output
    -o xz.js
    
    # Memory Configuration
    -s INITIAL_MEMORY=32MB
    -s MAXIMUM_MEMORY=256MB
    -s ALLOW_MEMORY_GROWTH=1
    -s STACK_SIZE=4MB
    
    # Base WASM Configuration
    -s WASM=1
    -s MODULARIZE=1
    -s EXPORT_ES6=1
    -s USE_ES6_IMPORT_META=0
    -s ENVIRONMENT=web,webview,worker,node
    
    # Performance
    -O3
    -flto
    --closure 1
    -s ASSERTIONS=0
    
    # JavaScript Integration
    -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","HEAPU8","setValue","getValue","stringToUTF8","UTF8ToString"]'
    -s EXPORTED_FUNCTIONS='["_malloc","_free","_xz_get_version","_xz_get_version_number","_xz_compress_buffer","_xz_decompress_buffer","_xz_compress_bound","_xz_check_is_supported","_xz_crc32","_xz_crc64","_xz_stream_encoder_init","_xz_stream_decoder_init","_xz_stream_process","_xz_stream_free","_xz_encoder_memory_usage","_xz_decoder_memory_usage","_xz_error_string"]'
)

# Add SIMD if enabled
if [ "${ENABLE_SIMD}" = "ON" ]; then
    EMCC_BASE_ARGS+=(-msimd128)
    echo -e "${GREEN}✅ SIMD support enabled${NC}"
fi

# Add WASM-native features if enabled
if [ "${ENABLE_WASM_NATIVE}" = "ON" ]; then
    EMCC_BASE_ARGS+=(
        -s ASYNCIFY=1
        -s FORCE_FILESYSTEM=1
        -lidbfs.js
    )
    echo -e "${GREEN}✅ WASM-native features enabled${NC}"
fi

# Build variants
echo -e "${BLUE}🔧 Building WASM variants...${NC}"

# Release variant
echo -e "${BLUE}Building release variant...${NC}"
emcc "${EMCC_BASE_ARGS[@]}" || {
    echo -e "${RED}❌ Release build failed${NC}"
    exit 1
}

# Fallback variant (smaller, more compatible)
if [ "${BUILD_TYPE}" = "Release" ]; then
    echo -e "${BLUE}Building fallback variant...${NC}"
    FALLBACK_ARGS=("${EMCC_BASE_ARGS[@]}")
    # Replace performance flags with smaller size optimization
    for i in "${!FALLBACK_ARGS[@]}"; do
        if [[ "${FALLBACK_ARGS[i]}" == "-O3" ]]; then
            FALLBACK_ARGS[i]="-Os"
        elif [[ "${FALLBACK_ARGS[i]}" == "--closure" ]]; then
            unset 'FALLBACK_ARGS[i]' 'FALLBACK_ARGS[i+1]'
        fi
    done
    
    emcc "${FALLBACK_ARGS[@]}" -o xz-fallback.js || {
        echo -e "${RED}❌ Fallback build failed${NC}"
        exit 1
    }
fi

echo -e "${GREEN}✅ WASM builds completed${NC}"

# Copy artifacts to distribution directory
cd ..
echo -e "${BLUE}📦 Copying artifacts to ${DIST_DIR}...${NC}"

# Copy WASM and JS files
cp "${BUILD_DIR}"/*.wasm "${DIST_DIR}/" 2>/dev/null || true
cp "${BUILD_DIR}"/*.js "${DIST_DIR}/" 2>/dev/null || true

echo -e "${GREEN}✅ Artifacts copied${NC}"

# Generate file sizes report
echo -e "${BLUE}📊 Build Report:${NC}"
echo "======================================================"

if [ -d "${DIST_DIR}" ]; then
    for file in "${DIST_DIR}"/*.wasm "${DIST_DIR}"/*.js; do
        if [ -f "$file" ]; then
            size=$(ls -lh "$file" | awk '{print $5}')
            echo "  $(basename "$file"): $size"
        fi
    done
fi

echo "======================================================"

# Generate modern JavaScript wrapper
echo -e "${BLUE}📝 Generating JavaScript wrapper...${NC}"

cat > "${DIST_DIR}/index.mjs" << 'EOF'
/**
 * xz.wasm - Modern JavaScript Wrapper
 * High-performance XZ/LZMA2 compression for WebAssembly
 */

let Module = null;
let modulePromise = null;

/**
 * Initialize xz WASM module
 * @returns {Promise<Object>} Initialized module
 */
export async function init() {
    if (Module) return Module;
    
    if (!modulePromise) {
        modulePromise = (async () => {
            try {
                const xzModule = await import('./xz.js');
                Module = await xzModule.default();
                return Module;
            } catch (e) {
                console.warn('Release build not available, trying fallback');
                const xzModule = await import('./xz-fallback.js');
                Module = await xzModule.default();
                return Module;
            }
        })();
    }
    
    return modulePromise;
}

/**
 * Get XZ library version string
 * @returns {string} Version string (e.g., "5.6.3")
 */
export async function getVersion() {
    const module = await init();
    const versionPtr = module._xz_get_version();
    return module.UTF8ToString(versionPtr);
}

/**
 * Get XZ library version number
 * @returns {number} Version number
 */
export async function getVersionNumber() {
    const module = await init();
    return module._xz_get_version_number();
}

/**
 * Compress data using XZ/LZMA2
 * @param {Uint8Array} input - Data to compress
 * @param {number} preset - Compression preset (0-9, default 6)
 * @returns {Uint8Array} Compressed data
 */
export async function compress(input, preset = 6) {
    const module = await init();
    
    if (!(input instanceof Uint8Array)) {
        throw new Error('Input must be Uint8Array');
    }
    
    if (preset < 0 || preset > 9) {
        throw new Error('Preset must be between 0-9');
    }
    
    // Allocate input buffer
    const inputPtr = module._malloc(input.length);
    module.HEAPU8.set(input, inputPtr);
    
    // Estimate output size (worst case: input size + 1KB overhead)
    const maxOutputSize = input.length + 1024;
    const outputPtr = module._malloc(maxOutputSize);
    const outputSizePtr = module._malloc(8); // size_t pointer
    module.setValue(outputSizePtr, maxOutputSize, 'i64');
    
    try {
        const result = module._xz_compress_buffer(
            inputPtr, input.length,
            outputPtr, outputSizePtr,
            preset
        );
        
        if (result !== 0) {
            throw new Error(`Compression failed with error code: ${result}`);
        }
        
        const actualSize = module.getValue(outputSizePtr, 'i64');
        const compressed = new Uint8Array(actualSize);
        compressed.set(module.HEAPU8.subarray(outputPtr, outputPtr + actualSize));
        
        return compressed;
        
    } finally {
        module._free(inputPtr);
        module._free(outputPtr);
        module._free(outputSizePtr);
    }
}

/**
 * Decompress XZ/LZMA2 compressed data
 * @param {Uint8Array} compressed - Compressed data
 * @param {number} maxSize - Maximum expected output size (safety limit)
 * @returns {Uint8Array} Decompressed data
 */
export async function decompress(compressed, maxSize = 64 * 1024 * 1024) {
    const module = await init();
    
    if (!(compressed instanceof Uint8Array)) {
        throw new Error('Input must be Uint8Array');
    }
    
    // Allocate input buffer
    const inputPtr = module._malloc(compressed.length);
    module.HEAPU8.set(compressed, inputPtr);
    
    // Allocate output buffer
    const outputPtr = module._malloc(maxSize);
    const outputSizePtr = module._malloc(8);
    module.setValue(outputSizePtr, maxSize, 'i64');
    
    try {
        const result = module._xz_decompress_buffer(
            inputPtr, compressed.length,
            outputPtr, outputSizePtr
        );
        
        if (result !== 0) {
            throw new Error(`Decompression failed with error code: ${result}`);
        }
        
        const actualSize = module.getValue(outputSizePtr, 'i64');
        const decompressed = new Uint8Array(actualSize);
        decompressed.set(module.HEAPU8.subarray(outputPtr, outputPtr + actualSize));
        
        return decompressed;
        
    } finally {
        module._free(inputPtr);
        module._free(outputPtr);
        module._free(outputSizePtr);
    }
}

/**
 * Calculate compressed size bound for given input size
 * @param {number} inputSize - Size of input data
 * @returns {number} Maximum possible compressed size
 */
export async function compressBound(inputSize) {
    const module = await init();
    return module._xz_compress_bound(inputSize);
}

/**
 * Check if compression check type is supported
 * @param {number} checkType - Check type (0=NONE, 1=CRC32, 4=CRC64, 10=SHA256)
 * @returns {boolean} True if supported
 */
export async function checkIsSupported(checkType) {
    const module = await init();
    return module._xz_check_is_supported(checkType) === 1;
}

/**
 * Calculate CRC32 checksum
 * @param {Uint8Array} data - Data to checksum
 * @returns {number} CRC32 value
 */
export async function crc32(data) {
    const module = await init();
    
    const dataPtr = module._malloc(data.length);
    module.HEAPU8.set(data, dataPtr);
    
    try {
        return module._xz_crc32(dataPtr, data.length, 0);
    } finally {
        module._free(dataPtr);
    }
}

/**
 * Calculate CRC64 checksum
 * @param {Uint8Array} data - Data to checksum
 * @returns {number} CRC64 value
 */
export async function crc64(data) {
    const module = await init();
    
    const dataPtr = module._malloc(data.length);
    module.HEAPU8.set(data, dataPtr);
    
    try {
        return module._xz_crc64(dataPtr, data.length, 0);
    } finally {
        module._free(dataPtr);
    }
}

// Default export for CommonJS compatibility
export default {
    init,
    getVersion,
    getVersionNumber,
    compress,
    decompress,
    compressBound,
    checkIsSupported,
    crc32,
    crc64
};
EOF

echo -e "${GREEN}✅ JavaScript wrapper generated${NC}"

# Generate TypeScript definitions
cat > "${DIST_DIR}/index.d.ts" << 'EOF'
/**
 * TypeScript definitions for xz.wasm
 * High-performance XZ/LZMA2 compression for WebAssembly
 */

/**
 * Initialize xz WASM module
 */
export function init(): Promise<any>;

/**
 * Get XZ library version string
 * @returns Version string (e.g., "5.6.3")
 */
export function getVersion(): Promise<string>;

/**
 * Get XZ library version number
 * @returns Version number
 */
export function getVersionNumber(): Promise<number>;

/**
 * Compress data using XZ/LZMA2
 * @param input Data to compress
 * @param preset Compression preset (0-9, default 6)
 * @returns Compressed data
 */
export function compress(input: Uint8Array, preset?: number): Promise<Uint8Array>;

/**
 * Decompress XZ/LZMA2 compressed data
 * @param compressed Compressed data
 * @param maxSize Maximum expected output size (safety limit)
 * @returns Decompressed data
 */
export function decompress(compressed: Uint8Array, maxSize?: number): Promise<Uint8Array>;

/**
 * Calculate compressed size bound for given input size
 * @param inputSize Size of input data
 * @returns Maximum possible compressed size
 */
export function compressBound(inputSize: number): Promise<number>;

/**
 * Check if compression check type is supported
 * @param checkType Check type (0=NONE, 1=CRC32, 4=CRC64, 10=SHA256)
 * @returns True if supported
 */
export function checkIsSupported(checkType: number): Promise<boolean>;

/**
 * Calculate CRC32 checksum
 * @param data Data to checksum
 * @returns CRC32 value
 */
export function crc32(data: Uint8Array): Promise<number>;

/**
 * Calculate CRC64 checksum
 * @param data Data to checksum
 * @returns CRC64 value
 */
export function crc64(data: Uint8Array): Promise<number>;

declare const _default: {
    init: typeof init;
    getVersion: typeof getVersion;
    getVersionNumber: typeof getVersionNumber;
    compress: typeof compress;
    decompress: typeof decompress;
    compressBound: typeof compressBound;
    checkIsSupported: typeof checkIsSupported;
    crc32: typeof crc32;
    crc64: typeof crc64;
};

export default _default;
EOF

echo -e "${GREEN}✅ TypeScript definitions generated${NC}"

# Success message
echo ""
echo -e "${GREEN}🎉 xz.wasm build completed successfully!${NC}"
echo ""
echo -e "${BLUE}📁 Distribution files:${NC}"
ls -la "${DIST_DIR}/"
echo ""
echo -e "${YELLOW}💡 Usage:${NC}"
echo "  import { compress, decompress } from './dist/index.mjs';"
echo ""
echo -e "${BLUE}🧪 Next steps:${NC}"
echo "  1. Run tests: npm test"
echo "  2. Run benchmarks: npm run benchmark"
echo "  3. Validate with CI: npm run ci"
echo ""