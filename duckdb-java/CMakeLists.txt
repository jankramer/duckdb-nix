cmake_minimum_required(VERSION 3.24)
project(DuckDBJDBCObjects LANGUAGES C CXX Java)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
find_package(Java REQUIRED)
set(JAVA_AWT_LIBRARY NotNeeded)
set(JAVA_JVM_LIBRARY NotNeeded)
find_package(JNI REQUIRED)
include(UseJava)
file(GLOB_RECURSE JAVA_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/main/java/org/duckdb/*.java")
file(GLOB JNI_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/jni/*.cpp")
set(CMAKE_JAVA_COMPILE_FLAGS --release 11 -encoding UTF-8)
add_jar(duckdb_jdbc_nolib ${JAVA_SOURCES}
  META-INF/services/java.sql.Driver
  META-INF/native-image/org.duckdb/duckdb_jdbc/reachability-metadata.json
  MANIFEST META-INF/MANIFEST.MF
  GENERATE_NATIVE_HEADERS duckdb-native)
add_library(duckdb_jni_objects STATIC ${JNI_SOURCES})
target_link_libraries(duckdb_jni_objects PRIVATE duckdb-native)
target_include_directories(duckdb_jni_objects PRIVATE ${JNI_INCLUDE_DIRS}
  "${DUCKDB_SOURCE}/src/include" "${DUCKDB_SOURCE}/third_party/utf8proc/include"
  "${DUCKDB_SOURCE}/third_party/fmt/include")
install(TARGETS duckdb_jni_objects ARCHIVE DESTINATION lib)
install_jar(duckdb_jdbc_nolib share/java)
