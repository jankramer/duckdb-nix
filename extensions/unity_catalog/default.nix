{
  fetchFromGitHub,
  mkExtension,
}:

mkExtension {
  name = "unity_catalog";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "unity_catalog";
    rev = "fa223642f3e8a4377e7fb6ce3a7f3f19767951e4";
    hash = "sha256-6L3gSx+HRkBHk3BF9RjMWKjygPRLyPL65itQCydq2Ak=";
  };
}
