{
  cmake,
  duckdb-src,
  duckdb-core,
  duckdb-java,
  jdk,
  lib,
  ninja,
  python3,
  stdenv,
  writeText,
}:

{
  extensions,
  withJdbc ? true,
}:

let
  names = map (ext: ext.extensionName) extensions;
  linkConfig = writeText "duckdb-extension-links.cmake" (
    lib.concatMapStringsSep "\n" (ext: ''
      set(EXTENSION_PREFIX "${ext}")
      ${ext.linkCmake or ""}
      ${lib.concatMapStringsSep "\n" (source: ''target_sources(duckdb PRIVATE "${source}")'') (
        ext.registrationSources or [ ]
      )}
    '') extensions
  );
  os = if stdenv.hostPlatform.isDarwin then "macos" else "linux";
  arch = if stdenv.hostPlatform.isAarch64 then "arm64" else "amd64";
  suffix = stdenv.hostPlatform.extensions.sharedLibrary;
in
assert lib.assertMsg (
  builtins.length names == builtins.length (lib.unique names)
) "Duplicate DuckDB extensions selected";
assert lib.assertMsg (builtins.all (
  ext: ext.core == duckdb-core
) extensions) "DuckDB extensions must use the same engine build";
stdenv.mkDerivation {
  pname = "duckdb";
  version = duckdb-src.version;
  src = ./compose;
  nativeBuildInputs = [
    cmake
    ninja
    python3
  ]
  ++ lib.optional withJdbc jdk;
  buildInputs = lib.unique (lib.concatMap (ext: ext.linkInputs or [ ]) extensions);
  cmakeFlags = [
    "-DDUCKDB_SOURCE=${duckdb-src}"
    "-DARCHIVES=${duckdb-core}"
    (lib.cmakeBool "WITH_JDBC" withJdbc)
    "-DEXTENSIONS=${lib.concatStringsSep ";" names}"
    "-DEXTENSION_ARCHIVE_DIRS=${lib.concatMapStringsSep ";" (ext: "${ext}/lib") extensions}"
    "-DEXTENSION_LINK_CONFIG=${linkConfig}"
  ]
  ++ lib.optional withJdbc "-DJDBC_OBJECTS=${duckdb-java}";
  postInstall = lib.optionalString withJdbc ''
    mkdir -p "$out/share/java"
    cp ${duckdb-java}/share/java/duckdb_jdbc_nolib.jar "$out/share/java/"
  '';
  # Pack after fixup so extraction preserves the final shared-engine path.
  postFixup = lib.optionalString withJdbc ''
    mkdir jar-native
    cp "$out/lib/libduckdb_java${suffix}" "jar-native/libduckdb_java.so_${os}_${arch}"
    cp "$out/share/java/duckdb_jdbc_nolib.jar" "$out/share/java/duckdb_jdbc.jar"
    jar uf "$out/share/java/duckdb_jdbc.jar" -C jar-native "libduckdb_java.so_${os}_${arch}"
  '';
  disallowedReferences = [ duckdb-core ] ++ extensions ++ lib.optional withJdbc duckdb-java;
  passthru = {
    selectedExtensions = extensions;
    inherit withJdbc;
    core = duckdb-core;
    jdbc = duckdb-java;
  };
  meta = {
    description = "DuckDB with a statically composed extension set and shared CLI/JDBC engine";
    homepage = "https://duckdb.org";
    license = lib.licenses.mit;
    mainProgram = "duckdb";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
