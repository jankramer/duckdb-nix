{
  applyPatches,
  fetchFromGitHub,
  mkExtension,
  unixodbc,
}:

mkExtension {
  name = "odbc_scanner";

  src = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "odbc-scanner";
      rev = "7ce06c95c94b46a6984968439ca31ce968a2f473";
      hash = "sha256-V9gLudrOlG4El9gBOU25PynEWD0std1bzvxz9oe2z6U=";
    };

    patches = [ ./no-git-version.patch ];
  };

  buildInputs = [ unixodbc ];
}
