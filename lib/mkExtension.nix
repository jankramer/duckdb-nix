{
  cmake,
  lib,
  ninja,
  python3,
  stdenv,
  duckdb-src,
  duckdb-core,
}:

lib.extendMkDerivation {
  constructDrv = stdenv.mkDerivation;
  excludeDrvArgNames = [
    "extensionSrc"
    "src"
    "linkCmake"
    "registrationSources"
    "extraArchives"
  ];
  extendDrvArgs =
    finalAttrs:
    previousAttrs@{
      name,
      src ? null,
      extensionSrc ? src,
      filePrefixes ? [ ],
      filePostfixes ? [ ],
      linkCmake ? "",
      registrationSources ? [ ],
      extraArchives ? [ ],
      ...
    }:
    let
      appendAttr = attr: values: values ++ (previousAttrs.${attr} or [ ]);
    in
    {
      name = "duckdb-${duckdb-src.version}-ext-${name}";
      extensionName = name;
      inherit filePrefixes filePostfixes;
      src = duckdb-src;
      nativeBuildInputs = appendAttr "nativeBuildInputs" [
        cmake
        ninja
        python3
      ];
      cmakeFlags = appendAttr "cmakeFlags" (
        (import ./buildFlags.nix { inherit duckdb-src; })
        ++ [
          "-DPREBUILT_BINARY=${duckdb-core}/lib/libduckdb_static.a"
          "-DBUILD_SHELL=OFF"
        ]
      );
      preConfigure = ''
        echo 'duckdb_extension_load(${name} ${
          lib.optionalString (extensionSrc != null) "SOURCE_DIR ${extensionSrc}"
        })' > extension/extension_config.cmake
      ''
      + (previousAttrs.preConfigure or "");
      buildPhase = ''
        runHook preBuild
        cmake --build . --parallel "$NIX_BUILD_CORES" --target ${name}_extension
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/lib"
        cp extension/${name}/lib${name}_extension.a "$out/lib/"
        ${lib.concatMapStringsSep "\n" (archive: "cp ${archive} \"$out/lib/\"") extraArchives}
        runHook postInstall
      '';
      passthru = (previousAttrs.passthru or { }) // {
        inherit extensionSrc linkCmake registrationSources;
        linkInputs = (finalAttrs.buildInputs or [ ]) ++ (finalAttrs.propagatedBuildInputs or [ ]);
        core = duckdb-core;
      };
    };
}
