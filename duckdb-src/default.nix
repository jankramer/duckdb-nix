{
  applyPatches,
  fetchFromGitHub,
}:

let
  version = "1.5.3";
  rev = "14eca11bd9d4a0de2ea0f078be588a9c1c5b279c";
  hash = "sha256-k7mtYXHS8IcBAuOCJ/09lPYLxF3RMODIeDaz3tKmQAA=";
in

applyPatches {
  src = fetchFromGitHub {
    name = "duckdb-src-${version}";
    owner = "duckdb";
    repo = "duckdb";

    inherit rev hash;

    passthru = {
      inherit version;
      gitDescribe = "v${version}-0-g${builtins.substring 0 10 rev}";
    };
  };

  patches = map (p: ./. + ("/patches/" + p)) (builtins.attrNames (builtins.readDir ./patches));
}
