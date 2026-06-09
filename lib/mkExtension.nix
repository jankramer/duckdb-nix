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
  ];

  extendDrvArgs =
    _finalAttrs:
    previousAttrs@{
      name,
      src ? null,
      extensionSrc ? src,

      filePrefixes ? [ ],
      filePostfixes ? [ ],
      ...
    }:
    let
      extensionName = name;
      appendAttr = attr: values: values ++ (previousAttrs.${attr} or [ ]);
      extensionSrcFlag = lib.optionalString (extensionSrc != null) "SOURCE_DIR ${extensionSrc}";
    in
    {
      inherit extensionName filePrefixes filePostfixes;

      name = "duckdb-${duckdb-src.version}-ext-${extensionName}";

      src = duckdb-src;

      nativeBuildInputs = appendAttr "nativeBuildInputs" [
        cmake
        ninja
        python3
      ];

      buildInputs = appendAttr "buildInputs" [ duckdb-core ];

      dontStrip = true;

      preConfigure = ''
        echo "duckdb_extension_load(${extensionName} DONT_LINK ${extensionSrcFlag})" > extension/extension_config.cmake
      '';

      ninjaFlags = [ "duckdb_local_extension_repo" ];

      cmakeFlags = appendAttr "cmakeFlags" [
        (lib.cmakeFeature "OVERRIDE_GIT_DESCRIBE" duckdb-src.gitDescribe)
        (lib.cmakeBool "BUILD_EXTENSIONS_ONLY" true)
        (lib.cmakeBool "EXTENSION_STATIC_BUILD" false)
      ];

      installPhase = ''
        runHook preInstall
        find ./repository -type f -exec install -Dm 0755 "{}" "$out/{}" \;
        runHook postInstall
      '';
    };
}
