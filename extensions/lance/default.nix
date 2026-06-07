{
  cargo,
  fetchFromGitHub,
  mkExtension,
  protobuf,
  rustc,
}:

mkExtension {
  name = "lance";

  src = fetchFromGitHub {
    owner = "lance-format";
    repo = "lance-duckdb";
    rev = "533e0ee6cf419e4be2af3af56182fb04b87978e1";
    hash = "sha256-XmUhtvjGqlgf2oZnqKNjPlMQJIpneJlzSTL3HX1472I=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cargo
    protobuf
    rustc
  ];
}
