# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(cupertino_http_library VERSION 0.0.1 LANGUAGES C)

add_library(cupertino_http SHARED
  "CUPHTTPClientDelegate.m"
  "CUPHTTPForwardedDelegate.m"
  "${CMAKE_CURRENT_LIST_DIR}/dart-sdk/include/dart_api_dl.c"
)

set_target_properties(cupertino_http PROPERTIES
  PUBLIC_HEADER cupertino_http.h
  OUTPUT_NAME "cupertino_http"
)

target_compile_definitions(cupertino_http PUBLIC DART_SHARED_LIB)

find_library(FOUNDATION_LIB Foundation)
target_link_libraries(cupertino_http PRIVATE ${FOUNDATION_LIB})
