{
  cmake,
  duckdb-src,
  duckdb-core,
  duckdb-java,
  lib,
  jdk_headless,
  makeWrapper,
  patchelf,
  stdenv,
  symlinkJoin,
  python3,
}:

{ extensions, withJdbc }:

let
  repository = symlinkJoin {
    name = "duckdb-${duckdb-src.version}-extension-repository";
    paths = extensions;
  };

  autoloadFlagsForExt =
    ext:
    (map (p: "--extension_file_prefixes ${ext.extensionName}=${p}") ext.filePrefixes)
    ++ (map (p: "--extension_file_postfixes ${ext.extensionName}=${p}") ext.filePostfixes);

  autoloaderFlags = builtins.concatStringsSep " " (
    builtins.concatMap autoloadFlagsForExt extensions
  );

  sharedLib = name: "${name}${stdenv.hostPlatform.extensions.sharedLibrary}";
  installLib = from: name: "install -Dm644 ${from}/${sharedLib name} $out/lib/${sharedLib name}";
in
stdenv.mkDerivation {
  pname = "duckdb";
  version = "v1.5.3";

  src = duckdb-src;

  nativeBuildInputs = [
    cmake
    jdk_headless
    makeWrapper
    patchelf
  ];

  cmakeFlags = [
    (lib.cmakeFeature "SKIP_EXTENSIONS" "core_functions;parquet")
    (lib.cmakeFeature "EXTENSION_DIRECTORIES" "${repository}/repository")
  ];

  postPatch = ''
    ${python3}/bin/python3 ${../scripts/generate_extensions_function.py} \
      --shell "${duckdb-core}/bin/duckdb" \
      --extension_repository "${repository}/repository" \
      ${autoloaderFlags}
  '';

  buildPhase = ''
    runHook preBuild
    cmake --build . --target duckdb_autoload_config
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 ${duckdb-core}/bin/duckdb $out/bin/duckdb
    ${installLib "${duckdb-core}/lib" "libduckdb"}
    ${installLib "src/main/extension" "libduckdb_autoload_config"}

    ${lib.optionalString withJdbc ''
      ${installLib "${duckdb-java}/lib" "libduckdb_java"}
      install -Dm644 ${duckdb-java}/share/java/duckdb_jdbc.jar $out/share/java/duckdb_jdbc.jar
    ''}

    runHook postInstall
  '';

  postFixup = ''
    old="${duckdb-core}"
    new="$out"

    patch_text_refs() {
      local root="$1"

      # Only text files. Do not blindly substituteInPlace binaries.
      while IFS= read -r -d "" f; do
        substituteInPlace "$f" \
          --replace-fail "$old" "$new"
      done < <(grep -IlrZ -- "$old" "$root" || true)
    }

    patch_macho() {
      local f="$1"
      chmod u+w "$f" || true

      # LC_ID_DYLIB: the dylib's own install name.
      local id
      id="$(otool -D "$f" 2>/dev/null | sed -n '2p' || true)"
      if [[ "$id" == "$old"* ]]; then
        install_name_tool -id "''${id/$old/$new}" "$f"
      fi

      # LC_LOAD_DYLIB / related dependency entries.
      otool -L "$f" 2>/dev/null \
        | awk 'NR > 1 { print $1 }' \
        | while IFS= read -r dep; do
            if [[ "$dep" == "$old"* && "$dep" != "$id" ]]; then
              install_name_tool -change "$dep" "''${dep/$old/$new}" "$f" || true
            fi
          done

      # LC_RPATH entries.
      otool -l "$f" 2>/dev/null \
        | awk '/cmd LC_RPATH/ { getline; getline; print $2 }' \
        | while IFS= read -r rp; do
            if [[ "$rp" == "$old"* ]]; then
              install_name_tool -rpath "$rp" "''${rp/$old/$new}" "$f" || true
            fi
          done
    }

    is_elf() {
      local magic
      magic="$(od -An -N4 -tx1 "$1" 2>/dev/null | tr -d ' \n' || true)"
      [[ "$magic" == "7f454c46" ]]
    }

    patch_elf() {
      local f="$1"

      is_elf "$f" || return 0

      chmod u+w "$f" || true

      local soname
      soname="$(patchelf --print-soname "$f" 2>/dev/null || true)"

      if [[ -n "$soname" && "$soname" == "$old"* ]]; then
        patchelf --set-soname "''${soname/$old/$new}" "$f"
      fi

      while IFS= read -r needed; do
        if [[ "$needed" == "$old"* ]]; then
          patchelf --replace-needed "$needed" "''${needed/$old/$new}" "$f"
        fi
      done < <(patchelf --print-needed "$f" 2>/dev/null || true)

      local rpath
      rpath="$(patchelf --print-rpath "$f" 2>/dev/null || true)"

      if [[ "$rpath" == *"$old"* ]]; then
        patchelf --set-rpath "''${rpath//$old/$new}" "$f"
      fi
    }

    for outputName in $outputs; do
      root="''${!outputName}"
      [ -e "$root" ] || continue

      patch_text_refs "$root"

      while IFS= read -r -d "" f; do
        ${lib.optionalString stdenv.hostPlatform.isDarwin ''
          patch_macho "$f"
        ''}
        ${lib.optionalString stdenv.hostPlatform.isLinux ''
          patch_elf "$f"
        ''}
      done < <(find "$root" -type f -print0)
    done
  '';

  disallowedReferences = [ duckdb-core ];
}
