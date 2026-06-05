cmake_minimum_required(VERSION 3.16)

project(DuckDBJavaExternal C CXX Java)

set(CMAKE_CXX_STANDARD 11 CACHE STRING "C++ standard to enforce")
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(Java 1.8 REQUIRED)
set(JAVA_AWT_LIBRARY NotNeeded)
set(JAVA_JVM_LIBRARY NotNeeded)
find_package(JNI REQUIRED)
find_package(DuckDB CONFIG REQUIRED)

if(NOT TARGET duckdb)
  message(FATAL_ERROR "DuckDBConfig.cmake did not define the duckdb target")
endif()
if(NOT DuckDB_INCLUDE_DIRS)
  message(FATAL_ERROR "DuckDBConfig.cmake did not define DuckDB_INCLUDE_DIRS")
endif()

include(UseJava)

if(NOT(Java_VERSION_MAJOR STREQUAL "1" AND Java_VERSION_MINOR STREQUAL "8"))
  message(WARNING "JDK ${Java_VERSION} is used to compile the Java part of the driver; resulting classes may not be JDK 8 compatible.")
endif()

set(OS_NAME "unknown")
set(OS_ARCH "amd64")

string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" SYSTEM_PROCESSOR_LOWER)
string(REGEX MATCH "(arm64|aarch64)" IS_ARM "${SYSTEM_PROCESSOR_LOWER}")
if(IS_ARM)
  set(OS_ARCH "arm64")
elseif(FORCE_32_BIT)
  set(OS_ARCH "i386")
endif()

if(APPLE)
  set(OS_NAME "osx")
  # DuckDBNative.java looks for osx_universal regardless of the actual binary architecture.
  set(OS_ARCH "universal")
elseif(WIN32)
  set(OS_NAME "windows")
elseif(UNIX)
  set(OS_NAME "linux")
endif()

if(OVERRIDE_JDBC_OS_NAME)
  set(OS_NAME ${OVERRIDE_JDBC_OS_NAME})
endif()
if(OVERRIDE_JDBC_OS_ARCH)
  set(OS_ARCH ${OVERRIDE_JDBC_OS_ARCH})
endif()

file(GLOB_RECURSE JAVA_SRC_FILES
  RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/main/java/org/duckdb/*.java")
file(GLOB_RECURSE JAVA_TEST_FILES
  RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/test/java/org/duckdb/*.java")
file(GLOB_RECURSE JNI_SRC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/jni/*.cpp")

set(CMAKE_JAVA_COMPILE_FLAGS -encoding utf-8 -g -Xlint:all)

add_jar(duckdb_jdbc_nolib
  ${JAVA_SRC_FILES}
  META-INF/services/java.sql.Driver
  MANIFEST META-INF/MANIFEST.MF
  GENERATE_NATIVE_HEADERS duckdb-native)

if(JAVA_TEST_FILES)
  add_jar(duckdb_jdbc_tests ${JAVA_TEST_FILES} INCLUDE_JARS duckdb_jdbc_nolib)
endif()

add_library(duckdb_java SHARED ${JNI_SRC_FILES})

target_link_libraries(duckdb_java PRIVATE
  duckdb-native
  duckdb
  ${CMAKE_DL_LIBS})

target_include_directories(duckdb_java PRIVATE
  ${JAVA_INCLUDE_PATH}
  ${JAVA_INCLUDE_PATH2}
  ${DuckDB_INCLUDE_DIRS})

if(MSVC)
  target_compile_options(duckdb_java PRIVATE /bigobj)
  target_link_libraries(duckdb_java PRIVATE ws2_32 rstrtmgr bcrypt)
else()
  target_compile_options(duckdb_java PRIVATE -fexceptions)
endif()

target_compile_definitions(duckdb_java PRIVATE
  -DDUCKDB_EXTENSION_AUTOLOAD_DEFAULT
  -DDUCKDB_EXTENSION_AUTOINSTALL_DEFAULT)

string(JOIN "_" LIB_SUFFIX ".so" ${OS_NAME} ${OS_ARCH})
set_target_properties(duckdb_java PROPERTIES
  PREFIX "lib"
  SUFFIX "${LIB_SUFFIX}")

string(TOUPPER "${CMAKE_BUILD_TYPE}" DUCKDB_CONFIG)
get_target_property(DUCKDB_LIBRARY duckdb IMPORTED_LOCATION_${DUCKDB_CONFIG})
if(NOT DUCKDB_LIBRARY)
  get_target_property(DUCKDB_LIBRARY duckdb IMPORTED_LOCATION_RELEASE)
endif()
if(NOT DUCKDB_LIBRARY)
  get_target_property(DUCKDB_LIBRARY duckdb IMPORTED_LOCATION)
endif()
if(DUCKDB_LIBRARY)
  get_filename_component(DUCKDB_LIBRARY_DIR "${DUCKDB_LIBRARY}" DIRECTORY)
  set_target_properties(duckdb_java PROPERTIES
    BUILD_RPATH "${DUCKDB_LIBRARY_DIR}"
    INSTALL_RPATH "${DUCKDB_LIBRARY_DIR}")
  message(STATUS "Using DuckDB library: ${DUCKDB_LIBRARY}")
endif()
message(STATUS "Using DuckDB include dirs: ${DuckDB_INCLUDE_DIRS}")

add_custom_command(
  OUTPUT duckdb_jdbc.jar
  DEPENDS duckdb_java duckdb_jdbc_nolib
  COMMAND ${CMAKE_COMMAND} -E copy duckdb_jdbc_nolib.jar duckdb_jdbc.jar
  COMMAND ${Java_JAR_EXECUTABLE} uf duckdb_jdbc.jar -C
          $<TARGET_FILE_DIR:duckdb_java> $<TARGET_FILE_NAME:duckdb_java>)

add_custom_target(jdbc ALL DEPENDS duckdb_jdbc.jar)
