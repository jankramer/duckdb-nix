{
  extensionSources,
  mkExtension,
}:

mkExtension {
  name = "encodings";

  src = extensionSources.encodings;
}
