{
  cmake,
  duckdb-src,
  fetchFromGitHub,
  jdk,
  lib,
  ninja,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "duckdb-java";
  version = "2.0.1.0";
  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-java";
    rev = "9def6924c6da0a41a193f4646878e7ac695e9476";
    hash = "sha256-N0uItArQkcarWGbXQfb9/1mHTjfarA3BMdHCzBaisFs=";
  };
  nativeBuildInputs = [
    cmake
    ninja
    jdk
  ];
  JAVA_HOME = "${jdk}";
  postPatch = "cp ${./CMakeLists.txt} CMakeLists.txt";
  cmakeFlags = [ "-DDUCKDB_SOURCE=${duckdb-src}" ];
  meta = {
    description = "Reusable DuckDB JDBC classes and JNI objects";
    homepage = "https://github.com/duckdb/duckdb-java";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
