/**
 * WASM Bindings for XZ Utils (liblzma)
 * High-performance LZMA2 compression and decompression for WebAssembly
 * 
 * Copyright (c) 2025 Superstruct Ltd, New Zealand
 * Licensed under the same license as the underlying XZ Utils project (0BSD)
 */

#include "../src/liblzma/api/lzma.h"
#include <emscripten/emscripten.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// WASM-exported functions for XZ/LZMA compression and decompression

EMSCRIPTEN_KEEPALIVE
const char* xz_get_version(void) {
    return lzma_version_string();
}

EMSCRIPTEN_KEEPALIVE
uint32_t xz_get_version_number(void) {
    return lzma_version_number();
}

EMSCRIPTEN_KEEPALIVE
int xz_compress_buffer(const uint8_t* input, size_t input_size, 
                       uint8_t* output, size_t* output_size,
                       int preset) {
    lzma_ret ret;
    
    // Initialize the encoder with the specified preset
    lzma_stream stream = LZMA_STREAM_INIT;
    ret = lzma_easy_encoder(&stream, preset, LZMA_CHECK_CRC64);
    if (ret != LZMA_OK) {
        return ret;
    }
    
    // Set up input and output buffers
    stream.next_in = input;
    stream.avail_in = input_size;
    stream.next_out = output;
    stream.avail_out = *output_size;
    
    // Compress the data
    ret = lzma_code(&stream, LZMA_FINISH);
    
    if (ret == LZMA_STREAM_END) {
        *output_size = *output_size - stream.avail_out;
        ret = LZMA_OK;
    }
    
    lzma_end(&stream);
    return ret;
}

EMSCRIPTEN_KEEPALIVE
int xz_decompress_buffer(const uint8_t* input, size_t input_size,
                         uint8_t* output, size_t* output_size) {
    lzma_ret ret;
    
    // Initialize the decoder
    lzma_stream stream = LZMA_STREAM_INIT;
    ret = lzma_stream_decoder(&stream, UINT64_MAX, LZMA_CONCATENATED);
    if (ret != LZMA_OK) {
        return ret;
    }
    
    // Set up input and output buffers
    stream.next_in = input;
    stream.avail_in = input_size;
    stream.next_out = output;
    stream.avail_out = *output_size;
    
    // Decompress the data
    ret = lzma_code(&stream, LZMA_FINISH);
    
    if (ret == LZMA_STREAM_END) {
        *output_size = *output_size - stream.avail_out;
        ret = LZMA_OK;
    }
    
    lzma_end(&stream);
    return ret;
}

EMSCRIPTEN_KEEPALIVE
size_t xz_compress_bound(size_t input_size) {
    // Conservative estimate for XZ compression output size
    // XZ can expand data in worst case, so we add significant overhead
    return input_size + (input_size / 4) + 1024;
}

EMSCRIPTEN_KEEPALIVE
int xz_check_is_supported(lzma_check check_type) {
    return lzma_check_is_supported(check_type) ? 1 : 0;
}

EMSCRIPTEN_KEEPALIVE
uint32_t xz_crc32(const uint8_t* buffer, size_t size, uint32_t crc) {
    return lzma_crc32(buffer, size, crc);
}

EMSCRIPTEN_KEEPALIVE
uint64_t xz_crc64(const uint8_t* buffer, size_t size, uint64_t crc) {
    return lzma_crc64(buffer, size, crc);
}

// Stream-based compression functions for large data
EMSCRIPTEN_KEEPALIVE
lzma_stream* xz_stream_encoder_init(int preset) {
    lzma_stream* stream = malloc(sizeof(lzma_stream));
    if (!stream) return NULL;
    
    *stream = (lzma_stream)LZMA_STREAM_INIT;
    lzma_ret ret = lzma_easy_encoder(stream, preset, LZMA_CHECK_CRC64);
    
    if (ret != LZMA_OK) {
        free(stream);
        return NULL;
    }
    
    return stream;
}

EMSCRIPTEN_KEEPALIVE
lzma_stream* xz_stream_decoder_init(void) {
    lzma_stream* stream = malloc(sizeof(lzma_stream));
    if (!stream) return NULL;
    
    *stream = (lzma_stream)LZMA_STREAM_INIT;
    lzma_ret ret = lzma_stream_decoder(stream, UINT64_MAX, LZMA_CONCATENATED);
    
    if (ret != LZMA_OK) {
        free(stream);
        return NULL;
    }
    
    return stream;
}

EMSCRIPTEN_KEEPALIVE
int xz_stream_process(lzma_stream* stream, 
                      const uint8_t* input, size_t input_size,
                      uint8_t* output, size_t output_size,
                      size_t* bytes_written, int finish) {
    if (!stream) return LZMA_PROG_ERROR;
    
    stream->next_in = input;
    stream->avail_in = input_size;
    stream->next_out = output;
    stream->avail_out = output_size;
    
    lzma_action action = finish ? LZMA_FINISH : LZMA_RUN;
    lzma_ret ret = lzma_code(stream, action);
    
    *bytes_written = output_size - stream->avail_out;
    
    return ret;
}

EMSCRIPTEN_KEEPALIVE
void xz_stream_free(lzma_stream* stream) {
    if (stream) {
        lzma_end(stream);
        free(stream);
    }
}

// Memory usage estimation
EMSCRIPTEN_KEEPALIVE
uint64_t xz_encoder_memory_usage(int preset) {
    return lzma_easy_encoder_memusage(preset);
}

EMSCRIPTEN_KEEPALIVE
uint64_t xz_decoder_memory_usage(void) {
    return lzma_stream_decoder_memusage(UINT64_MAX);
}

// Error handling
EMSCRIPTEN_KEEPALIVE
const char* xz_error_string(lzma_ret error_code) {
    switch (error_code) {
        case LZMA_OK: return "Operation completed successfully";
        case LZMA_STREAM_END: return "End of stream reached";
        case LZMA_NO_CHECK: return "Input stream has no integrity check";
        case LZMA_UNSUPPORTED_CHECK: return "Cannot calculate the integrity check";
        case LZMA_GET_CHECK: return "Integrity check type is now available";
        case LZMA_MEM_ERROR: return "Cannot allocate memory";
        case LZMA_MEMLIMIT_ERROR: return "Memory usage limit was reached";
        case LZMA_FORMAT_ERROR: return "File format not recognized";
        case LZMA_OPTIONS_ERROR: return "Invalid or unsupported options";
        case LZMA_DATA_ERROR: return "Data is corrupt";
        case LZMA_BUF_ERROR: return "No progress is possible";
        case LZMA_PROG_ERROR: return "Programming error";
        default: return "Unknown error";
    }
}