project('xz.wasm', 'c', version: '5.6.2', meson_version: '>=1.3.0', default_options: ['buildtype=release'])

if get_option('simd')
  add_project_arguments('-msimd128', language: 'c')
endif

incs = [ include_directories('src/liblzma') ]

core_sources = []
core_sources += files(
  'src/liblzma/common/stream_flags_common.c',
  'src/liblzma/common/stream_decoder.c',
  'src/liblzma/common/stream_encoder.c',
  'src/liblzma/common/auto_decoder.c',
  'src/liblzma/common/block_util.c',
  'src/liblzma/common/block_decoder.c',
  'src/liblzma/common/block_encoder.c',
  'src/liblzma/common/easy_preset.c',
  'src/liblzma/common/easy_buffer_encoder.c',
  'src/liblzma/common/index.c',
  'src/liblzma/common/index_decoder.c',
  'src/liblzma/common/index_encoder.c',
  'src/liblzma/common/index_hash.c',
  'src/liblzma/common/filter_common.c',
  'src/liblzma/common/filter_decoder.c',
  'src/liblzma/common/filter_encoder.c',
  'src/liblzma/common/memcmplen.c',
  'src/liblzma/common/vli_encoder.c',
  'src/liblzma/common/vli_decoder.c',
  'src/liblzma/common/vli_size.c',
  'src/liblzma/check/check.c',
  'src/liblzma/check/crc32_table.c',
  'src/liblzma/check/crc32_fast.c',
  'src/liblzma/check/crc64_table.c',
  'src/liblzma/check/crc64_fast.c',
  'src/liblzma/lz/lz_decoder.c',
  'src/liblzma/lz/lz_encoder.c',
  'src/liblzma/lz/lz_encoder_mf.c',
  'src/liblzma/lzma/fastpos_table.c',
  'src/liblzma/lzma/lzma_common.c',
  'src/liblzma/lzma/lzma_decoder.c',
  'src/liblzma/lzma/lzma_encoder.c',
  'src/liblzma/lzma/lzma_encoder_optimum_fast.c',
  'src/liblzma/lzma/lzma_encoder_optimum_normal.c',
  'src/liblzma/rangecoder/price_table.c',
  'src/liblzma/simple/simple_coder.c',
  'src/liblzma/simple/simple_decoder.c',
  'src/liblzma/simple/simple_encoder.c',
  'src/liblzma/simple/x86.c')

core = static_library('liblzma_core', core_sources, include_directories: incs)

if get_option('main_module')
  executable('liblzma-main', 'src/liblzma_wasm_module.c',
    link_with: core,
    include_directories: incs,
    install: true,
    link_args: [
      '--no-entry',
      '-sMODULARIZE=1',
      '-sEXPORT_ES6=1',
      '-sALLOW_MEMORY_GROWTH=1',
      '-sENVIRONMENT=web,webview,worker',
      '-sNO_FILESYSTEM=1',
      '-sEXPORTED_RUNTIME_METHODS=["cwrap","ccall","UTF8ToString"]',
      '-sEXPORTED_FUNCTIONS=@' + meson.project_source_root() / get_option('exports'),
    ])
endif

if get_option('side_module')
  shared_module('liblzma-side', 'src/liblzma_wasm_side.c',
    link_whole: core,
    include_directories: incs,
    name_prefix: '',
    install: true,
    link_args: ['-sSIDE_MODULE=2', '-fPIC'])
endif

