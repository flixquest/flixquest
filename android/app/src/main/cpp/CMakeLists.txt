cmake_minimum_required(VERSION 3.22.1)
project(fqcore CXX)

# Comes from SCRAPER_NATIVE_SECRET in .env.scraper, through build.gradle.
if(NOT FQ_NATIVE_SECRET MATCHES "^[0-9a-f]+$")
  message(FATAL_ERROR
    "SCRAPER_NATIVE_SECRET is missing. Run: dart run tool/scraper_key.dart init")
endif()
string(LENGTH "${FQ_NATIVE_SECRET}" FQ_NATIVE_SECRET_LENGTH)
if(NOT FQ_NATIVE_SECRET_LENGTH EQUAL 64)
  message(FATAL_ERROR "SCRAPER_NATIVE_SECRET must be 64 hex characters.")
endif()

add_library(fqcore SHARED fq_core.cpp)
set_target_properties(fqcore PROPERTIES
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
  CXX_VISIBILITY_PRESET hidden)
# The x prefix keeps the value a single preprocessor token. fq_core.cpp drops it.
target_compile_definitions(fqcore PRIVATE FQ_NATIVE_SECRET=x${FQ_NATIVE_SECRET})
target_compile_options(fqcore PRIVATE -O2 -fno-exceptions -fno-rtti)
target_link_options(fqcore PRIVATE -s -Wl,-z,max-page-size=16384)
