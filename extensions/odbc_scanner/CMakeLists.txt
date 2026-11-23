cmake_minimum_required(VERSION 3.24)
project(ODBCStaticExtension LANGUAGES C CXX)
find_package(ODBC REQUIRED)
# Match upstream's src/ tree; tests live outside it. Link the C++ API directly
# to the shared engine using the upstream static entry point.
file(GLOB_RECURSE ODBC_SOURCES CONFIGURE_DEPENDS "src/*.cpp")
build_static_extension_capi_unstable(odbc_scanner ${ODBC_SOURCES})
target_include_directories(odbc_scanner_extension PRIVATE
  third_party/utf8cpp src/include ${ODBC_INCLUDE_DIRS})
target_link_libraries(odbc_scanner_extension duckdb_cpp_api ${CMAKE_DL_LIBS})
