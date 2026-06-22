{
  fetchFromGitHub,
  mkExtension,
}:

mkExtension {
  name = "sqlite_scanner";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-sqlite";
    rev = "494e9feed54c20b6bbfb665baf26864bc7e3b517";
    hash = "sha256-KGN/HbL3S0W8885CEarSUcTA6haSCFq5ElWA9Fzxnlg=";
  };
}
