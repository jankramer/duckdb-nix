cmake_minimum_required(VERSION 3.24)
project(DuckDBComposition LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
find_package(Threads REQUIRED)
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)

# This project only compiles registration glue and the CLI entry point.
# Engine, extension, shell and JNI objects were built in reusable derivations.
execute_process(COMMAND "${Python3_EXECUTABLE}"
  "${DUCKDB_SOURCE}/scripts/generate_static_extension_loader.py"
  -o "${CMAKE_CURRENT_BINARY_DIR}/static_extension_loader.c" ${EXTENSIONS}
  COMMAND_ERROR_IS_FATAL ANY)
add_library(duckdb SHARED
  "${CMAKE_CURRENT_BINARY_DIR}/static_extension_loader.c"
  "${DUCKDB_SOURCE}/extension/loader/static_extension_autoregister.cpp")
target_include_directories(duckdb PRIVATE "${DUCKDB_SOURCE}/src/include")
# Keep the full exported C++ API: JDBC needs more symbols than a CLI link roots.
target_link_libraries(duckdb PRIVATE
  "$<LINK_LIBRARY:WHOLE_ARCHIVE,${ARCHIVES}/lib/libduckdb_static.a>"
  Threads::Threads ${CMAKE_DL_LIBS})
foreach(extension IN LISTS EXTENSIONS)
  unset(EXTENSION_ARCHIVE)
  find_library(EXTENSION_ARCHIVE NAMES "${extension}_extension"
    PATHS ${EXTENSION_ARCHIVE_DIRS} NO_DEFAULT_PATH REQUIRED NO_CACHE)
  target_link_libraries(duckdb PRIVATE "${EXTENSION_ARCHIVE}")
endforeach()
include("${EXTENSION_LINK_CONFIG}")

add_executable(duckdb_cli "${DUCKDB_SOURCE}/tools/shell/shell_main.cpp")
set_target_properties(duckdb_cli PROPERTIES OUTPUT_NAME duckdb)
target_include_directories(duckdb_cli PRIVATE
  "${DUCKDB_SOURCE}/src/include" "${DUCKDB_SOURCE}/tools/shell/include")
target_link_libraries(duckdb_cli PRIVATE "${ARCHIVES}/lib/libduckdb_shell.a" duckdb Threads::Threads)

if(WITH_JDBC)
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/empty.cpp" "// JNI definitions come from the reusable archive.\n")
  add_library(duckdb_java SHARED "${CMAKE_CURRENT_BINARY_DIR}/empty.cpp")
  target_link_libraries(duckdb_java PRIVATE
    "$<LINK_LIBRARY:WHOLE_ARCHIVE,${JDBC_OBJECTS}/lib/libduckdb_jni_objects.a>"
    duckdb Threads::Threads ${CMAKE_DL_LIBS})
endif()
if(UNIX AND NOT APPLE)
  target_link_options(duckdb PRIVATE LINKER:--no-undefined)
  if(WITH_JDBC)
    target_link_options(duckdb_java PRIVATE LINKER:--no-undefined)
  endif()
endif()
install(TARGETS duckdb duckdb_cli LIBRARY DESTINATION lib RUNTIME DESTINATION bin)
if(WITH_JDBC)
  install(TARGETS duckdb_java LIBRARY DESTINATION lib)
endif()
