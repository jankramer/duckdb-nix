{
  extensionSources,
  mkExtension,
}:

mkExtension {
  name = "vss";

  src = extensionSources.vss;
}
