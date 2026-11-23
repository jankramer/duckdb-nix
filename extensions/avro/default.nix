{
  applyPatches,
  callPackage,
  extensionSources,
  lib,
  mkExtension,

  jansson,
  snappy,
  xz,
  zlib,
}:

let
  avro-c = callPackage ./avro-c { };

in
mkExtension {
  linkCmake = ''
    find_library(AVRO_LIBRARY NAMES avro REQUIRED)
    find_library(JANSSON_LIBRARY NAMES jansson REQUIRED)
    find_package(Snappy REQUIRED)
    find_package(LibLZMA REQUIRED)
    find_package(ZLIB REQUIRED)
    target_link_libraries(duckdb PRIVATE ''${AVRO_LIBRARY} ''${JANSSON_LIBRARY} Snappy::snappy LibLZMA::LibLZMA ZLIB::ZLIB)
    target_link_libraries(duckdb PRIVATE "''${EXTENSION_PREFIX}/lib/libduckdb_cpp_api.a")
  '';

  name = "avro";

  # Use the separately packaged avro-c. The release's patches only affect
  # Windows compilation of the bundled submodule and Wasm library paths.
  src = applyPatches {
    src = extensionSources.avro;
    postPatch = ''
      substituteInPlace CMakeLists.txt \
        --replace-fail 'add_subdirectory(third_party/avro-c/lang/c EXCLUDE_FROM_ALL)' 'find_library(AVRO_LIBRARY NAMES avro REQUIRED)' \
        --replace-fail 'set(AVRO_INCLUDE_DIR "''${CMAKE_CURRENT_SOURCE_DIR}/third_party/avro-c/lang/c/src")' 'set(AVRO_INCLUDE_DIR "${avro-c}/include")' \
        --replace-fail ' avro-static)' ' ''${AVRO_LIBRARY})' \
        --replace-fail 'TARGETS ''${EXTENSION_NAME} avro-static' 'TARGETS ''${EXTENSION_NAME}'
    '';
  };

  extraArchives = [ "tools/cpp/libduckdb_cpp_api.a" ];

  buildInputs = [
    avro-c
    (jansson.overrideAttrs (
      finalAttrs: previousAttrs: {
        cmakeFlags = builtins.filter (flag: !lib.hasInfix "SHARED_LIBS" flag) previousAttrs.cmakeFlags;
      }
    ))
    (snappy.override { static = true; })
    (xz.override { enableStatic = true; })
    zlib.static
  ];
}
