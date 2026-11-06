{
  extensionSources,
  mkExtension,
}:

mkExtension {
  name = "inet";

  src = extensionSources.inet;
}
