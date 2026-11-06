{
  extensionSources,
  mkExtension,
}:

mkExtension {
  name = "sqlite_scanner";

  src = extensionSources.sqlite_scanner;
}
