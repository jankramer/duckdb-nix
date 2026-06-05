{
  fetchFromGitHub,
  mkExtension,
  lib,

  curlMinimal,
  openssl,
}:

mkExtension {
  name = "quack";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-quack";
    rev = "87cd65b912a85f38a8522cabcb7514b1854c08bf";
    hash = "sha256-yWTlHXPkSfVclHMXYjDluP/HS/jDwdXl8kK3uGiuiEI=";
  };

  buildInputs = [
    curlMinimal
    openssl
  ];
}
