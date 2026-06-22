{
  fetchFromGitHub,
  mkExtension,
}:

mkExtension {
  name = "unity_catalog";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "unity_catalog";
    rev = "d52a7ee8678a23a8e0f950e955b9ffa1df0c3395";
    hash = "sha256-bKvfujUeSUgWF+e8ztiZqcAdGjVpFc5TfUOYI6S+jRM=";
  };
}
