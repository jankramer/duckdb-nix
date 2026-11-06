{
  extensionSources,
  mkExtension,
}:

mkExtension {
  name = "sqlsmith";

  src = extensionSources.sqlsmith;
}
