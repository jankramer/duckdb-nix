{
  extensionSources,
  mkExtension,
}:

mkExtension {
  name = "fts";

  src = extensionSources.fts;
}
