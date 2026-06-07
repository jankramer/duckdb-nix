{
  fetchFromGitHub,
  mkExtension,
}:

mkExtension {
  name = "vss";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-vss";
    rev = "b833341c8737fd3f3558c7720cc575ae8fc82598";
    hash = "sha256-txtsTm3OGNDGI5jeMvy9JA7R6pzb22gy5ArxTVc2Usw=";
  };
}
