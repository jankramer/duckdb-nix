"""
Patched version of the eponymous script in the original duckdb src with these modifications:
 - Target extension_entries_generated.cpp (see 0001-Move-autoload-config-into-shared-library.patcy)
 - Make all discovered extensions from the provided extension_repository autoloadable
 - Add options to autoload custom extensions by file prefix/postfix/contains
 - Minor fixes to make it work in a Nix build
"""

import os
import re
import argparse
import glob
from typing import Set, Tuple, NamedTuple, List, Dict, Optional
import json

parser = argparse.ArgumentParser(description='Generates/Validates extension_entries_generated.cpp file')

parser.add_argument(
    '--validate',
    action=argparse.BooleanOptionalAction,
    help='If set will validate that extension_entries_generated.cpp is up to date, otherwise it generates the file.',
)
parser.add_argument(
    '--extension_repository',
    action='store',
    help="The repository to look for the '**/<extension>.duckdb_extension' files",
    default='build/release/repository',
)
parser.add_argument(
    '--shell',
    action='store',
    help="Path to the DuckDB shell",
    default='build/release/duckdb',
)
parser.add_argument(
    '--extensions',
    action='store',
    help="Comma separated list of extensions - if not provided this is read from the extension repository",
    default='',
)
parser.add_argument(
    '--extension_file_prefixes',
    action='append',
    help="Comma separated list of extension=prefix entries to add to EXTENSION_FILE_PREFIXES",
    default=[],
)
parser.add_argument(
    '--extension_file_postfixes',
    action='append',
    help="Comma separated list of extension=postfix entries to add to EXTENSION_FILE_POSTFIXES",
    default=[],
)
parser.add_argument(
    '--extension_file_contains',
    action='append',
    help="Comma separated list of extension=substring entries to add to EXTENSION_FILE_CONTAINS",
    default=[],
)

args = parser.parse_args()

DUCKDB_PATH = args.shell
GENERATED_SOURCE_PATH = os.path.join("src", "main", "extension", "extension_entries_generated.cpp")
EXTENSION_PATHS: Optional[Dict[str, str]] = None

EXTENSION_DEPENDENCIES = {
    'iceberg': [
        'avro',
        'parquet',
    ]
}

from enum import Enum


class CatalogType(str, Enum):
    SCALAR = "CatalogType::SCALAR_FUNCTION_ENTRY"
    TABLE = "CatalogType::TABLE_FUNCTION_ENTRY"
    AGGREGATE = "CatalogType::AGGREGATE_FUNCTION_ENTRY"
    PRAGMA = "CatalogType::PRAGMA_FUNCTION_ENTRY"
    MACRO = "CatalogType::MACRO_ENTRY"
    TABLE_MACRO = "CatalogType::TABLE_MACRO_ENTRY"


parameter_type_map = {"TIMESTAMP WITH TIME ZONE": "TIMESTAMPTZ", "TIME WITH TIME ZONE": "TIMETZ"}


def catalog_type_from_type(catalog_type: str) -> CatalogType:
    TYPE_MAP = {
        CatalogType.SCALAR.value: CatalogType.SCALAR,
        CatalogType.TABLE.value: CatalogType.TABLE,
        CatalogType.AGGREGATE.value: CatalogType.AGGREGATE,
        CatalogType.PRAGMA.value: CatalogType.PRAGMA,
        CatalogType.MACRO.value: CatalogType.MACRO,
        CatalogType.TABLE_MACRO.value: CatalogType.TABLE_MACRO,
    }
    if catalog_type not in TYPE_MAP:
        raise Exception(f"Unrecognized function type: '{catalog_type}'")
    return TYPE_MAP[catalog_type]


def catalog_type_from_string(catalog_type: str) -> CatalogType:
    TYPE_MAP = {
        CatalogType.SCALAR.name.lower(): CatalogType.SCALAR,
        CatalogType.TABLE.name.lower(): CatalogType.TABLE,
        CatalogType.AGGREGATE.name.lower(): CatalogType.AGGREGATE,
        CatalogType.PRAGMA.name.lower(): CatalogType.PRAGMA,
        CatalogType.MACRO.name.lower(): CatalogType.MACRO,
        CatalogType.TABLE_MACRO.name.lower(): CatalogType.TABLE_MACRO,
    }
    if catalog_type not in TYPE_MAP:
        raise Exception(f"Unrecognized function type: '{catalog_type}'")
    return TYPE_MAP[catalog_type]


def parse_records(text):
    records = []  # Will hold all parsed records
    current_record = []  # Holds items for the current record
    current_item = []  # Accumulates characters for the current item
    in_quote = False  # True if we're inside a double-quoted string
    inside_braces = False  # True if we're inside a { ... } block

    for char in text:
        if char == '"':
            # Toggle the quote state and always include the quote.
            in_quote = not in_quote
        elif char == '{' and not in_quote:
            # Start of a new record.
            inside_braces = True
            # Reset any previous record state.
            current_record = []
            current_item = []
        elif char == '}' and not in_quote and inside_braces:
            # End of the current record.
            token = ''.join(current_item).strip()
            if token:
                current_record.append(token)
            records.append(current_record)
            # Reset state for subsequent records.
            current_record = []
            current_item = []
            inside_braces = False
        elif char == ',' and not in_quote and inside_braces:
            # A comma outside quotes indicates the end of the current item.
            token = ''.join(current_item).strip()
            if token:
                current_record.append(token)
            current_item = []
        else:
            # Otherwise, just add the character if we're inside braces.
            if inside_braces:
                current_item.append(char)
    return records


def parse_string_array(text: str) -> Set[str]:
    return set(re.findall(r'"([^"]+)"', text))


def parse_extension_entry_argument(argument_name: str, argument_values) -> Dict[str, str]:
    result: Dict[str, str] = {}
    if isinstance(argument_values, str):
        argument_values = [argument_values]
    if len(argument_values) == 0:
        return result

    for argument_value in argument_values:
        for raw_entry in argument_value.split(','):
            entry = raw_entry.strip()
            if len(entry) == 0:
                continue
            if '=' not in entry:
                print(f"Invalid {argument_name} entry '{entry}', expected extension=pattern")
                exit(1)
            extension, pattern = entry.split('=', 1)
            extension = extension.strip().lower()
            pattern = pattern.strip().lower()
            if len(extension) == 0 or len(pattern) == 0:
                print(f"Invalid {argument_name} entry '{entry}', expected extension=pattern")
                exit(1)
            result[pattern] = extension
    return result


def cpp_string_literal(value: str) -> str:
    return json.dumps(value)


class LogicalType(NamedTuple):
    type: str


class Function(NamedTuple):
    name: str
    type: CatalogType


class FunctionOverload(NamedTuple):
    name: str
    type: CatalogType
    parameters: Tuple
    return_type: LogicalType


class ExtensionFunctionOverload(NamedTuple):
    extension: str
    name: str
    type: CatalogType
    parameters: Tuple
    return_type: LogicalType

    @staticmethod
    def create_map(input: List[Tuple[str, str, str, str]]) -> Dict[Function, List["ExtensionFunctionOverload"]]:
        output: Dict[Function, List["ExtensionFunctionOverload"]] = {}
        for x in input:
            function = Function(x[0], catalog_type_from_type(x[2]))
            # parse the signature
            signature = x[3]
            splits = signature.split('>')
            return_type = LogicalType(splits[1])
            parameters = [LogicalType(param) for param in splits[0][1:-1].split(',')]
            extension_function = ExtensionFunctionOverload(x[1], function.name, function.type, parameters, return_type)
            if function not in output:
                output[function] = []
            output[function].append(extension_function)
        return output


class ExtensionFunction(NamedTuple):
    extension: str
    name: str
    type: CatalogType

    @staticmethod
    def create_map(input: List[Tuple[str, str, str]]) -> Dict[Function, "ExtensionFunction"]:
        output: Dict[Function, "ExtensionFunction"] = {}
        for x in input:
            key = Function(x[0], catalog_type_from_type(x[2]))
            output[key] = ExtensionFunction(x[1], key.name, key.type)
        return output


class ExtensionEntryData(NamedTuple):
    extension: str
    name: str

    @staticmethod
    def create_map(input: List[Tuple[str, str]]) -> Dict[str, "ExtensionEntryData"]:
        output: Dict[str, "ExtensionEntryData"] = {}
        for x in input:
            output[x[0]] = ExtensionEntryData(x[1], x[0])
        return output


def parse_cpp_records(file_blob: str, var_name: str):
    return parse_records(get_slice_of_file(var_name, file_blob))


def parse_cpp_entry_data(file_blob: str, var_name: str) -> Dict[str, ExtensionEntryData]:
    return ExtensionEntryData.create_map([(x[0], x[1]) for x in parse_cpp_records(file_blob, var_name)])


def parse_cpp_entry_map(file_blob: str, var_name: str) -> Dict[str, str]:
    return {x[0]: x[1] for x in parse_cpp_records(file_blob, var_name)}


class ParsedEntries:
    def __init__(self, file_path):
        self.path = file_path
        self.functions = {}
        self.function_overloads = {}
        self.settings = {}
        self.secret_types = {}
        self.file_prefixes = {}
        self.file_postfixes = {}
        self.file_contains = {}
        self.autoloadable_extensions = set()

        with open(file_path, 'r') as file:
            file_blob = file.read()

        self.functions = ExtensionFunction.create_map(
            [(x[0], x[1], x[2]) for x in parse_cpp_records(file_blob, "EXTENSION_FUNCTIONS")]
        )
        self.function_overloads = ExtensionFunctionOverload.create_map(
            [(x[0], x[1], x[2], x[3]) for x in parse_cpp_records(file_blob, "EXTENSION_FUNCTION_OVERLOADS")]
        )
        self.settings = parse_cpp_entry_data(file_blob, "EXTENSION_SETTINGS")
        self.secret_types = parse_cpp_entry_data(file_blob, "EXTENSION_SECRET_TYPES")
        self.file_prefixes = parse_cpp_entry_map(file_blob, "EXTENSION_FILE_PREFIXES")
        self.file_postfixes = parse_cpp_entry_map(file_blob, "EXTENSION_FILE_POSTFIXES")
        self.file_contains = parse_cpp_entry_map(file_blob, "EXTENSION_FILE_CONTAINS")

        ext_autoloadable_extensions_blob = get_slice_of_file("AUTOLOADABLE_EXTENSIONS", file_blob)
        self.autoloadable_extensions = parse_string_array(ext_autoloadable_extensions_blob)

    def strip_unloaded_extensions(self, extensions: List[str], functions):
        return [x for x in functions if x.extension not in extensions]

    def filter_entries(self, extensions: List[str]):
        self.functions = {k: v for k, v in self.functions.items() if v.extension not in extensions}
        self.function_overloads = {
            k: self.strip_unloaded_extensions(extensions, v)
            for k, v in self.function_overloads.items()
            if len(self.strip_unloaded_extensions(extensions, v)) > 0
        }
        self.settings = {k: v for k, v in self.settings.items() if v.extension not in extensions}
        self.secret_types = {k: v for k, v in self.secret_types.items() if v.extension not in extensions}
        self.file_prefixes = {k: v for k, v in self.file_prefixes.items() if v not in extensions}
        self.file_postfixes = {k: v for k, v in self.file_postfixes.items() if v not in extensions}
        self.file_contains = {k: v for k, v in self.file_contains.items() if v not in extensions}
        self.autoloadable_extensions = {x for x in self.autoloadable_extensions if x not in extensions}


def check_prerequisites():
    if not os.path.isfile(DUCKDB_PATH):
        print(f"{DUCKDB_PATH} not found")
        print(
            "please run 'GENERATE_EXTENSION_ENTRIES=1 BUILD_ALL_EXT=1 make release', you might have to manually add DONT_LINK to all extension_configs"
        )
        exit(1)
    if not os.path.isdir(args.extension_repository):
        print(f"provided --extension_repository '{args.extension_repository}' is not a valid directory")
        exit(1)


# Gets the extensions to inspect. If --extensions is omitted, scan the configured extension repository.
def get_extension_names() -> List[str]:
    if len(args.extensions) > 0:
        return [extension.strip() for extension in args.extensions.split(',') if extension.strip()]
    extension_names = sorted(get_extension_path_map().keys())
    if not extension_names:
        print(f"No .duckdb_extension files found in --extension_repository '{args.extension_repository}'")
        exit(1)
    return extension_names


def get_query(sql_query, load_query) -> list:
    # Optionally perform a LOAD of an extension
    # Then perform a SQL query, fetch the output
    import csv
    import io

    query = f'{DUCKDB_PATH} -unsigned -csv -c "{load_query}{sql_query}" '
    query_result = os.popen(query).read()
    f = io.StringIO(query_result)
    reader = csv.reader(f)
    header = next(reader)
    result = []
    for line in reader:
        result_obj = {}
        for i in range(len(header)):
            result_obj[header[i]] = line[i]
        result.append(result_obj)
    return result


def transform_parameter(parameter) -> LogicalType:
    if parameter is None:
        return LogicalType("INVALID")
    parameter = parameter.upper()
    if parameter.endswith('[]'):
        return LogicalType(transform_parameter(parameter[0: len(parameter) - 2]).type + '[]')
    if parameter in parameter_type_map:
        return LogicalType(parameter_type_map[parameter])
    return LogicalType(parameter)


def transform_parameters(parameters) -> FunctionOverload:
    parameters = [x for x in parameters.lstrip('[').rstrip(']').split(', ') if len(x) > 0]
    return tuple(transform_parameter(param) for param in parameters)


def get_functions(load="") -> (Set[Function], Dict[Function, List[FunctionOverload]]):
    GET_FUNCTIONS_QUERY = """
                          select distinct function_name,
                                          function_type,
                                          parameter_types,
                                          return_type
                          from duckdb_functions()
                          ORDER BY function_name, function_type; \
                          """
    # ['name_1,type_1', ..., 'name_n,type_n']
    results = get_query(GET_FUNCTIONS_QUERY, load)

    functions = set()
    function_overloads = {}
    for func in results:
        function_name = func["function_name"].lower()
        function_type = func["function_type"]
        parameter_types = func["parameter_types"]
        return_type = func["return_type"]
        function_parameters = transform_parameters(parameter_types)
        function_return = transform_parameter(return_type)
        function = Function(function_name, catalog_type_from_string(function_type))
        function_overload = FunctionOverload(
            function_name, catalog_type_from_string(function_type), function_parameters, function_return
        )
        if function not in functions:
            functions.add(function)
            function_overloads[function] = [function_overload]
        else:
            function_overloads[function].append(function_overload)

    return (functions, function_overloads)


def get_settings(load="") -> Set[str]:
    GET_SETTINGS_QUERY = """
                         select distinct name
                         from duckdb_settings(); \
                         """
    settings = get_query(GET_SETTINGS_QUERY, load)
    res = set()
    for setting in settings:
        name = setting['name']
        res.add(name)
    return res


def get_secret_types(load="") -> Set[str]:
    GET_SECRET_TYPES_QUERY = """
                             select distinct type
                             from duckdb_secret_types(); \
                             """
    secret_types = get_query(GET_SECRET_TYPES_QUERY, load)
    res = set()
    for secret_type in secret_types:
        type = secret_type['type']
        res.add(type)
    return res


HARDCODED_FILE_PREFIXES = {
    "http://": "httpfs",
    "https://": "httpfs",
    "s3://": "httpfs",
    "s3a://": "httpfs",
    "s3n://": "httpfs",
    "gcs://": "httpfs",
    "gs://": "httpfs",
    "r2://": "httpfs",
    "azure://": "azure",
    "az://": "azure",
    "abfss://": "azure",
    "hf://": "httpfs",
}

HARDCODED_FILE_POSTFIXES = {
    ".parquet": "parquet",
    ".json": "json",
    ".jsonl": "json",
    ".ndjson": "json",
    ".shp": "spatial",
    ".gpkg": "spatial",
    ".fgb": "spatial",
    ".xlsx": "excel",
    ".avro": "avro",
}

HARDCODED_FILE_CONTAINS = {
    ".parquet?": "parquet",
    ".json?": "json",
    ".ndjson?": "json",
    ".jsonl?": "json",
}

HARDCODED_AUTOLOADABLE_EXTENSIONS = {
    "autocomplete",
    "avro",
    "aws",
    "azure",
    "core_functions",
    "delta",
    "ducklake",
    "encodings",
    "excel",
    "fts",
    "httpfs",
    "iceberg",
    "icu",
    "inet",
    "json",
    "motherduck",
    "mysql_scanner",
    "parquet",
    "postgres_scanner",
    "quack",
    "sqlite_scanner",
    "sqlsmith",
    "tpcds",
    "tpch",
    "ui",
    "unity_catalog",
}


class ExtensionData:
    def __init__(self):
        # Map of extension -> ExtensionFunction
        self.function_map: Dict[Function, ExtensionFunction] = {}
        self.settings_map: Dict[str, ExtensionEntryData] = {}
        self.secret_types_map: Dict[str, ExtensionEntryData] = {}
        self.file_prefixes_map: Dict[str, str] = dict(HARDCODED_FILE_PREFIXES)
        self.file_postfixes_map: Dict[str, str] = dict(HARDCODED_FILE_POSTFIXES)
        self.file_contains_map: Dict[str, str] = dict(HARDCODED_FILE_CONTAINS)
        self.priority_file_prefixes: Dict[str, str] = {}
        self.priority_file_postfixes: Dict[str, str] = {}
        self.priority_file_contains: Dict[str, str] = {}
        self.autoloadable_extensions: Set[str] = set(HARDCODED_AUTOLOADABLE_EXTENSIONS)
        # Map of function -> extension function overloads
        self.function_overloads: Dict[Function, List[ExtensionFunctionOverload]] = {}
        # All function overloads (also ones that will not be written to the file)
        self.all_function_overloads: Dict[Function, List[ExtensionFunctionOverload]] = {}

        self.base_settings: Set[str] = set()
        self.base_secret_types: Set[str] = set()
        self.base_functions: Set[Function] = set()

        self.extension_settings: Dict[str, Set[str]] = {}
        self.extension_secret_types: Dict[str, Set[str]] = {}
        self.extension_functions: Dict[str, Set[Function]] = {}

        self.added_extensions: Set[str] = set()

        # Map of extension -> extension_path
        self.extensions: Dict[str, str] = get_extension_path_map()

        self.stored_functions: Dict[str, List[Function]] = {
            'arrow': [Function("scan_arrow_ipc", CatalogType.TABLE), Function("to_arrow_ipc", CatalogType.TABLE)],
            'spatial': [],
        }
        self.stored_settings: Dict[str, List[str]] = {'arrow': [], 'spatial': []}
        self.stored_secret_types: Dict[str, List[str]] = {'arrow': [], 'spatial': []}

    def set_base(self):
        (functions, function_overloads) = get_functions()
        self.base_functions: Set[Function] = functions
        self.base_settings: Set[str] = get_settings()
        self.base_secret_types: Set[str] = get_secret_types()

    def add_entries(self, entries: ParsedEntries):
        self.function_map.update(entries.functions)
        self.function_overloads.update(entries.function_overloads)
        self.settings_map.update(entries.settings)
        self.secret_types_map.update(entries.secret_types)
        self.file_prefixes_map.update(entries.file_prefixes)
        self.file_postfixes_map.update(entries.file_postfixes)
        self.file_contains_map.update(entries.file_contains)
        self.autoloadable_extensions.update(entries.autoloadable_extensions)

    def add_file_entry_overrides(
        self, prefixes: Dict[str, str], postfixes: Dict[str, str], contains: Dict[str, str]
    ):
        self.file_prefixes_map.update(prefixes)
        self.file_postfixes_map.update(postfixes)
        self.file_contains_map.update(contains)
        self.priority_file_prefixes.update(prefixes)
        self.priority_file_postfixes.update(postfixes)
        self.priority_file_contains.update(contains)
        self.autoloadable_extensions.update(prefixes.values())
        self.autoloadable_extensions.update(postfixes.values())
        self.autoloadable_extensions.update(contains.values())

    def load_dependencies(self, extension_name: str) -> str:
        if extension_name not in EXTENSION_DEPENDENCIES:
            return ''

        res = ''
        dependencies = EXTENSION_DEPENDENCIES[extension_name]
        for item in dependencies:
            if item not in self.extensions:
                print(f"Could not load extension '{extension_name}', dependency '{item}' is missing")
                exit(1)
            extension_path = self.extensions[item]
            print(f"Load {item} at {extension_path}")
            res += f"LOAD '{extension_path}';"
        return res

    def add_extension(self, extension_name: str):
        if extension_name in EXTENSION_DEPENDENCIES:
            for item in EXTENSION_DEPENDENCIES[extension_name]:
                if item not in self.added_extensions:
                    self.add_extension(item)

        if extension_name in self.extensions:
            # Perform a LOAD and add the added settings/functions/secret_types
            extension_path = self.extensions[extension_name]

            print(f"Load {extension_name} at {extension_path}")
            load = self.load_dependencies(extension_name)
            load += f"LOAD '{extension_path}';"

            (functions, function_overloads) = get_functions(load)
            extension_functions = list(functions)
            extension_settings = list(get_settings(load))
            extension_secret_types = list(get_secret_types(load))

            self.add_settings(extension_name, extension_settings)
            self.add_secret_types(extension_name, extension_secret_types)
            self.add_functions(extension_name, extension_functions, function_overloads)
        elif extension_name in self.stored_functions or extension_name in self.stored_settings:
            # Retrieve the list of settings/functions from our hardcoded list
            extension_functions = self.stored_functions[extension_name]
            extension_settings = self.stored_settings[extension_name]
            extension_secret_types = self.stored_secret_types[extension_name]

            print(f"Loading {extension_name} from stored functions: {extension_functions}")
            self.add_settings(extension_name, extension_settings)
            self.add_secret_types(extension_name, extension_secret_types)
            self.add_functions(extension_name, extension_functions)
        else:
            error = f"""Missing extension {extension_name} and not found in stored_functions/stored_settings/stored_secret_types
Please double check if '{args.extension_repository}' is the right location to look for ./**/*.duckdb_extension files"""
            print(error)
            exit(1)
        self.added_extensions.add(extension_name)
        self.autoloadable_extensions.add(extension_name.lower())

    def add_settings(self, extension_name: str, settings_list: List[str]):
        extension_name = extension_name.lower()

        base_settings = set()
        base_settings.update(self.base_settings)
        if extension_name in EXTENSION_DEPENDENCIES:
            dependencies = EXTENSION_DEPENDENCIES[extension_name]
            for item in dependencies:
                assert item in self.extension_settings
                base_settings.update(self.extension_settings[item])

        added_settings: Set[str] = set(settings_list) - base_settings

        self.extension_settings[extension_name] = added_settings

        settings_to_add: Dict[str, ExtensionEntryData] = {}
        for setting in added_settings:
            setting_name = setting.lower()
            settings_to_add[setting_name] = ExtensionEntryData(extension_name, setting_name)

        self.settings_map.update(settings_to_add)

    def add_secret_types(self, extension_name: str, secret_types_list: List[str]):
        extension_name = extension_name.lower()

        base_secret_types = set()
        base_secret_types.update(self.base_secret_types)
        if extension_name in EXTENSION_DEPENDENCIES:
            dependencies = EXTENSION_DEPENDENCIES[extension_name]
            for item in dependencies:
                assert item in self.extension_secret_types
                base_secret_types.update(self.extension_secret_types[item])

        added_secret_types: Set[str] = set(secret_types_list) - base_secret_types

        self.extension_secret_types[extension_name] = added_secret_types

        secret_types_to_add: Dict[str, ExtensionEntryData] = {}
        for secret_type in added_secret_types:
            secret_type_name = secret_type.lower()
            secret_types_to_add[secret_type_name] = ExtensionEntryData(extension_name, secret_type_name)

        self.secret_types_map.update(secret_types_to_add)

    def get_extension_overloads(
            self, extension_name: str, overloads: Dict[Function, List[FunctionOverload]]
    ) -> Dict[Function, List[ExtensionFunctionOverload]]:
        result = {}
        for function, function_overloads in overloads.items():
            extension_overloads = []
            for overload in function_overloads:
                extension_overloads.append(
                    ExtensionFunctionOverload(
                        extension_name, overload.name, overload.type, overload.parameters, overload.return_type
                    )
                )
            result[function] = extension_overloads
        return result

    def add_functions(
            self, extension_name: str, function_list: List[Function], overloads: Dict[Function, List[FunctionOverload]]
    ):
        extension_name = extension_name.lower()

        base_functions = set()
        base_functions.update(self.base_functions)
        if extension_name in EXTENSION_DEPENDENCIES:
            dependencies = EXTENSION_DEPENDENCIES[extension_name]
            for item in dependencies:
                assert item in self.extension_functions
                base_functions.update(self.extension_functions[item])

        overloads = self.get_extension_overloads(extension_name, overloads)
        added_functions: Set[Function] = set(function_list) - base_functions

        self.extension_functions[extension_name] = added_functions

        functions_to_add: Dict[Function, ExtensionFunction] = {}
        for function in added_functions:
            if function in self.function_overloads:
                # function is in overload map - add overloads
                self.function_overloads[function] += overloads[function]
            elif function in self.function_map:
                # function is in function map and we are trying to add it again
                # this means the function is present in multiple extensions
                # remove from function map, and add to overload map
                self.function_overloads[function] = self.all_function_overloads[function] + overloads[function]
                del self.function_map[function]
            else:
                functions_to_add[function] = ExtensionFunction(extension_name, function.name, function.type)

        self.all_function_overloads.update(overloads)
        self.function_map.update(functions_to_add)

    def validate(self):
        parsed_entries = ParsedEntries(GENERATED_SOURCE_PATH)
        validate_map("Function map", self.function_map, parsed_entries.functions)
        validate_map("Settings map", self.settings_map, parsed_entries.settings)
        validate_map("SecretTypes map", self.secret_types_map, parsed_entries.secret_types)
        validate_map("File prefix map", self.file_prefixes_map, parsed_entries.file_prefixes)
        validate_map("File postfix map", self.file_postfixes_map, parsed_entries.file_postfixes)
        validate_map("File contains map", self.file_contains_map, parsed_entries.file_contains)
        if self.autoloadable_extensions != parsed_entries.autoloadable_extensions:
            print("Autoloadable extension list mismatches:")
            print("Diff between lists: " + str(self.autoloadable_extensions - parsed_entries.autoloadable_extensions))
            print("Diff between lists: " + str(parsed_entries.autoloadable_extensions - self.autoloadable_extensions))
            exit(1)

        print("All entries found: ")
        print(" > functions: " + str(len(parsed_entries.functions)))
        print(" > settings:  " + str(len(parsed_entries.settings)))
        print(" > secret_types:  " + str(len(parsed_entries.secret_types)))
        print(" > file_prefixes:  " + str(len(parsed_entries.file_prefixes)))
        print(" > file_postfixes:  " + str(len(parsed_entries.file_postfixes)))
        print(" > file_contains:  " + str(len(parsed_entries.file_contains)))
        print(" > autoloadable_extensions:  " + str(len(parsed_entries.autoloadable_extensions)))

    def verify_export(self):
        if len(self.function_map) == 0 or len(self.settings_map) == 0 or len(self.secret_types_map) == 0:
            print(
                """
The provided configuration produced an empty function map or empty settings map or empty secret types map
This is likely caused by building DuckDB with extensions linked in
"""
            )
            exit(1)

    def export_functions(self) -> str:
        result = """
static constexpr ExtensionFunctionEntry EXTENSION_FUNCTIONS_DATA[] = {\n"""
        sorted_function = sorted(self.function_map)

        for func in sorted_function:
            function: ExtensionFunction = self.function_map[func]
            result += "\t{"
            result += f'"{function.name}", "{function.extension}", {function.type.value}'
            result += "},\n"
        result += "}; // END_OF_EXTENSION_FUNCTIONS\n"
        return result

    def export_function_overloads(self) -> str:
        result = """
static constexpr ExtensionFunctionOverloadEntry EXTENSION_FUNCTION_OVERLOADS_DATA[] = {\n"""
        sorted_function = sorted(self.function_overloads)

        for func in sorted_function:
            overloads: List[ExtensionFunctionOverload] = sorted(self.function_overloads[func])
            for overload in overloads:
                result += "\t{"
                result += f'"{overload.name}", "{overload.extension}", {overload.type.value}, "'
                signature = "["
                signature += ",".join([parameter.type for parameter in overload.parameters])
                signature += "]>" + overload.return_type.type
                result += signature
                result += '"},\n'
        result += "}; // END_OF_EXTENSION_FUNCTION_OVERLOADS\n"
        return result

    def export_extension_entries(self, name: str, entries: Dict[str, ExtensionEntryData]) -> str:
        result = f"""
static constexpr ExtensionEntry {name}_DATA[] = {{\n"""
        for entry_name in sorted(entries):
            entry = entries[entry_name]
            result += "\t{"
            result += f"{cpp_string_literal(entry_name.lower())}, {cpp_string_literal(entry.extension)}"
            result += "},\n"
        result += f"}}; // END_OF_{name}\n"
        return result

    def export_entry_map(
        self,
        name: str,
        entries: Dict[str, str],
        priority_entries: Optional[Dict[str, str]] = None,
        priority_last: bool = False,
    ) -> str:
        result = f"""
static constexpr ExtensionEntry {name}_DATA[] = {{\n"""
        if priority_entries is None:
            priority_entries = {}

        sorted_entries = [(entry_name, entries[entry_name]) for entry_name in sorted(entries)]
        sorted_priority_entries = [
            (entry_name, entries[entry_name]) for entry_name in sorted(priority_entries) if entry_name in entries
        ]
        non_priority_entries = [
            (entry_name, extension) for entry_name, extension in sorted_entries if entry_name not in priority_entries
        ]
        ordered_entries = (
            non_priority_entries + sorted_priority_entries
            if priority_last
            else sorted_priority_entries + non_priority_entries
        )

        for entry_name, extension in ordered_entries:
            result += "\t{"
            result += f"{cpp_string_literal(entry_name)}, {cpp_string_literal(extension)}"
            result += "},\n"
        result += f"}}; // END_OF_{name}\n"
        return result

    def export_autoloadable_extensions(self) -> str:
        result = """
static constexpr const char *AUTOLOADABLE_EXTENSIONS_DATA[] = {\n"""
        for extension_name in sorted(self.autoloadable_extensions):
            result += f"\t{cpp_string_literal(extension_name)},\n"
        result += "}; // END_OF_AUTOLOADABLE_EXTENSIONS\n"
        return result


# Get the slice of the file containing the var (assumes // END_OF_<varname> comment after var)
def get_slice_of_file(var_name, file_str):
    begin = file_str.find(var_name)
    end = file_str.find("END_OF_" + var_name)
    if end == -1:
        end = file_str.find("}; // " + var_name)
    return file_str[begin:end]


def print_map_diff(d1, d2):
    s1 = sorted(set(d1.items()))
    s2 = sorted(set(d2.items()))

    diff1 = str(set(s1) - set(s2))
    diff2 = str(set(s2) - set(s1))
    print("Diff between maps: " + diff1 + "\n")
    print("Diff between maps: " + diff2 + "\n")


def validate_map(name: str, actual, expected):
    if actual == expected:
        return
    print(f"{name} mismatches:")
    print_map_diff(actual, expected)
    exit(1)


def get_extension_path_map() -> Dict[str, str]:
    global EXTENSION_PATHS
    if EXTENSION_PATHS is not None:
        return EXTENSION_PATHS

    extension_paths: Dict[str, str] = {}
    extension_repository = args.extension_repository
    for location in sorted(glob.iglob(extension_repository + '/**/*.duckdb_extension', recursive=True)):
        name, _ = os.path.splitext(os.path.basename(location))
        print(f"Located extension: {name} in path: '{location}'")
        extension_paths[name] = location
    EXTENSION_PATHS = extension_paths
    return extension_paths


def write_header(data: ExtensionData):
    INCLUDE_HEADER = """//===----------------------------------------------------------------------===//
//                         DuckDB
//
// duckdb/main/extension_entries_generated.cpp
//
//
//===----------------------------------------------------------------------===//

#include \"duckdb/main/extension_entries_shared.hpp\"

#define DUCKDB_EXTENSION_ENTRY_COUNT(array) (sizeof(array) / sizeof(array[0]))

// These fallbacks are necessary if the user doesn't use the CMake build.
#ifndef DUCKDB_EXTENSION_DIRECTORIES
#ifdef _WIN32
#define DUCKDB_EXTENSION_DIRECTORIES \"~\\\\.duckdb\\\\extensions\"
#else
#define DUCKDB_EXTENSION_DIRECTORIES \"~/.duckdb/extensions\"
#endif
#endif

// NOTE: this file is generated by scripts/generate_extensions_function.py.
// Example usage to refresh one extension (replace "icu" with the desired extension):
// GENERATE_EXTENSION_ENTRIES=1 make debug
// python3 scripts/generate_extensions_function.py --extensions icu --shell build/debug/duckdb --extension_repository build/debug/repository

// Check out the check-load-install-extensions  job in .github/workflows/LinuxRelease.yml for more details

namespace duckdb {
"""

    INCLUDE_FOOTER = """
// Note: these are currently hardcoded in scripts/generate_extensions_function.py
// TODO: automate by passing though to script via duckdb
static constexpr ExtensionEntry EXTENSION_COPY_FUNCTIONS_DATA[] = {
    {"parquet", "parquet"},
    {"json", "json"},
    {"avro", "avro"},
    {"iceberg", "iceberg"}
}; // END_OF_EXTENSION_COPY_FUNCTIONS

// Note: these are currently hardcoded in scripts/generate_extensions_function.py
// TODO: automate by passing though to script via duckdb
static constexpr ExtensionEntry EXTENSION_TYPES_DATA[] = {
    {"json", "json"},
    {"inet", "inet"},
}; // END_OF_EXTENSION_TYPES

// Note: these are currently hardcoded in scripts/generate_extensions_function.py
// TODO: automate by passing though to script via duckdb
static constexpr ExtensionEntry EXTENSION_COLLATIONS_DATA[] = {
    {"af", "icu"},    {"am", "icu"},    {"ar", "icu"},     {"ar_sa", "icu"}, {"as", "icu"},    {"az", "icu"},
    {"be", "icu"},    {"bg", "icu"},    {"bn", "icu"},     {"bo", "icu"},    {"br", "icu"},    {"bs", "icu"},
    {"ca", "icu"},    {"ceb", "icu"},   {"chr", "icu"},    {"cs", "icu"},    {"cy", "icu"},    {"da", "icu"},
    {"de", "icu"},    {"de_at", "icu"}, {"dsb", "icu"},    {"dz", "icu"},    {"ee", "icu"},    {"el", "icu"},
    {"en", "icu"},    {"en_us", "icu"}, {"eo", "icu"},     {"es", "icu"},    {"et", "icu"},    {"fa", "icu"},
    {"fa_af", "icu"}, {"ff", "icu"},    {"fi", "icu"},     {"fil", "icu"},   {"fo", "icu"},    {"fr", "icu"},
    {"fr_ca", "icu"}, {"fy", "icu"},    {"ga", "icu"},     {"gl", "icu"},    {"gu", "icu"},    {"ha", "icu"},
    {"haw", "icu"},   {"he", "icu"},    {"he_il", "icu"},  {"hi", "icu"},    {"hr", "icu"},    {"hsb", "icu"},
    {"hu", "icu"},    {"hy", "icu"},    {"id", "icu"},     {"id_id", "icu"}, {"ig", "icu"},    {"is", "icu"},
    {"it", "icu"},    {"ja", "icu"},    {"ka", "icu"},     {"kk", "icu"},    {"kl", "icu"},    {"km", "icu"},
    {"kn", "icu"},    {"ko", "icu"},    {"kok", "icu"},    {"ku", "icu"},    {"ky", "icu"},    {"lb", "icu"},
    {"lkt", "icu"},   {"ln", "icu"},    {"lo", "icu"},     {"lt", "icu"},    {"lv", "icu"},    {"mk", "icu"},
    {"ml", "icu"},    {"mn", "icu"},    {"mr", "icu"},     {"ms", "icu"},    {"mt", "icu"},    {"my", "icu"},
    {"nb", "icu"},    {"nb_no", "icu"}, {"ne", "icu"},     {"nl", "icu"},    {"nn", "icu"},    {"om", "icu"},
    {"or", "icu"},    {"pa", "icu"},    {"pa_in", "icu"},  {"pl", "icu"},    {"ps", "icu"},    {"pt", "icu"},
    {"ro", "icu"},    {"ru", "icu"},    {"sa", "icu"},     {"se", "icu"},    {"si", "icu"},    {"sk", "icu"},
    {"sl", "icu"},    {"smn", "icu"},   {"sq", "icu"},     {"sr", "icu"},    {"sr_ba", "icu"}, {"sr_me", "icu"},
    {"sr_rs", "icu"}, {"sv", "icu"},    {"sw", "icu"},     {"ta", "icu"},    {"te", "icu"},    {"th", "icu"},
    {"tk", "icu"},    {"to", "icu"},    {"tr", "icu"},     {"ug", "icu"},    {"uk", "icu"},    {"ur", "icu"},
    {"uz", "icu"},    {"vi", "icu"},    {"wae", "icu"},    {"wo", "icu"},    {"xh", "icu"},    {"yi", "icu"},
    {"yo", "icu"},    {"yue", "icu"},   {"yue_cn", "icu"}, {"zh", "icu"},    {"zh_cn", "icu"}, {"zh_hk", "icu"},
    {"zh_mo", "icu"}, {"zh_sg", "icu"}, {"zh_tw", "icu"},  {"zu", "icu"}}; // END_OF_EXTENSION_COLLATIONS

// Note: these are currently hardcoded in scripts/generate_extensions_function.py
// TODO: automate by passing though to script via duckdb
static constexpr ExtensionEntry EXTENSION_SECRET_PROVIDERS_DATA[] = {{"s3/config", "httpfs"},
                                                                {"gcs/config", "httpfs"},
                                                                {"r2/config", "httpfs"},
                                                                {"s3/credential_chain", "aws"},
                                                                {"gcs/credential_chain", "aws"},
                                                                {"r2/credential_chain", "aws"},
                                                                {"aws/credential_chain", "aws"},
                                                                {"rds/credential_chain", "aws"},
                                                                {"azure/access_token", "azure"},
                                                                {"azure/config", "azure"},
                                                                {"azure/credential_chain", "azure"},
                                                                {"azure/service_principal", "azure"},
                                                                {"huggingface/config", "httfps"},
                                                                {"huggingface/credential_chain", "httpfs"},
                                                                {"bearer/config", "httpfs"},
                                                                {"mysql/config", "mysql_scanner"},
                                                                {"postgres/config", "postgres_scanner"}
}; // EXTENSION_SECRET_PROVIDERS

extern "C" DUCKDB_EXTENSION_ENTRIES_API const DuckDBExtensionEntriesV1 *duckdb_extension_entries_v1() {
    static const DuckDBExtensionEntriesV1 entries = {1,
                                                     EXTENSION_FUNCTIONS_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_FUNCTIONS_DATA),
                                                     EXTENSION_FUNCTION_OVERLOADS_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_FUNCTION_OVERLOADS_DATA),
                                                     EXTENSION_SETTINGS_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_SETTINGS_DATA),
                                                     EXTENSION_SECRET_TYPES_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_SECRET_TYPES_DATA),
                                                     EXTENSION_COPY_FUNCTIONS_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_COPY_FUNCTIONS_DATA),
                                                     EXTENSION_TYPES_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_TYPES_DATA),
                                                     EXTENSION_COLLATIONS_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_COLLATIONS_DATA),
                                                     EXTENSION_FILE_PREFIXES_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_FILE_PREFIXES_DATA),
                                                     EXTENSION_FILE_POSTFIXES_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_FILE_POSTFIXES_DATA),
                                                     EXTENSION_FILE_CONTAINS_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_FILE_CONTAINS_DATA),
                                                     EXTENSION_SECRET_PROVIDERS_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(EXTENSION_SECRET_PROVIDERS_DATA),
                                                     AUTOLOADABLE_EXTENSIONS_DATA,
                                                     DUCKDB_EXTENSION_ENTRY_COUNT(AUTOLOADABLE_EXTENSIONS_DATA),
                                                     DUCKDB_EXTENSION_DIRECTORIES};
    return &entries;
}

} // namespace duckdb"""

    data.verify_export()

    with open(GENERATED_SOURCE_PATH, 'w') as file:
        file.write(INCLUDE_HEADER)

        exported_functions = data.export_functions()
        file.write(exported_functions)

        exported_overloads = data.export_function_overloads()
        file.write(exported_overloads)

        exported_settings = data.export_extension_entries("EXTENSION_SETTINGS", data.settings_map)
        file.write(exported_settings)

        exported_secret_types = data.export_extension_entries("EXTENSION_SECRET_TYPES", data.secret_types_map)
        file.write(exported_secret_types)

        file.write(
            data.export_entry_map(
                "EXTENSION_FILE_PREFIXES", data.file_prefixes_map, data.priority_file_prefixes, priority_last=True
            )
        )
        file.write(
            data.export_entry_map("EXTENSION_FILE_POSTFIXES", data.file_postfixes_map, data.priority_file_postfixes)
        )
        file.write(data.export_entry_map("EXTENSION_FILE_CONTAINS", data.file_contains_map, data.priority_file_contains))
        file.write(data.export_autoloadable_extensions())

        file.write(INCLUDE_FOOTER)


# Extensions that can be autoloaded, but are not buildable by DuckDB CI
HARDCODED_EXTENSION_FUNCTIONS = ExtensionFunction.create_map(
    [
        ("delta_scan", "delta", "CatalogType::TABLE_FUNCTION_ENTRY"),
    ]
)


def main():
    check_prerequisites()

    extension_names: List[str] = get_extension_names()

    extension_data = ExtensionData()
    # Collect the list of functions/settings without any extensions loaded
    extension_data.set_base()

    # TODO: add 'purge' option to ignore existing entries ??
    parsed_entries = ParsedEntries(GENERATED_SOURCE_PATH)
    parsed_entries.filter_entries(extension_names)

    # Add the entries we parsed from GENERATED_SOURCE_PATH
    extension_data.add_entries(parsed_entries)

    cli_file_prefixes = parse_extension_entry_argument("--extension_file_prefixes", args.extension_file_prefixes)
    cli_file_postfixes = parse_extension_entry_argument("--extension_file_postfixes", args.extension_file_postfixes)
    cli_file_contains = parse_extension_entry_argument("--extension_file_contains", args.extension_file_contains)
    extension_data.add_file_entry_overrides(cli_file_prefixes, cli_file_postfixes, cli_file_contains)

    for extension_name in extension_names:
        print(extension_name)
        # For every extension, add the functions/settings added by the extension
        extension_data.add_extension(extension_name)

    # Add hardcoded extension entries (
    for key, value in HARDCODED_EXTENSION_FUNCTIONS.items():
        extension_data.function_map[key] = value

    if args.validate:
        extension_data.validate()
        return

    write_header(extension_data)


if __name__ == '__main__':
    main()
