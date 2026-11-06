cmake_minimum_required(VERSION 3.24)
project(ODBCStaticExtension LANGUAGES C CXX)
find_package(ODBC REQUIRED)
# Match upstream's src/ tree; tests live outside it. Use the engine's current
# C API headers and static entry macro instead of a process-global API vtable.
file(GLOB_RECURSE ODBC_SOURCES CONFIGURE_DEPENDS "src/*.cpp")
build_static_extension_capi(odbc_scanner 1 5 6 ${ODBC_SOURCES})
target_include_directories(odbc_scanner_extension PRIVATE
  third_party/utf8cpp src/include ${ODBC_INCLUDE_DIRS})
target_link_libraries(odbc_scanner_extension ${ODBC_LIBRARIES})
