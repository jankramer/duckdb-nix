#!/usr/bin/env python3
"""Run installed CLI/JDBC variants and retain command output and loader evidence."""
import csv
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import subprocess
import sys

minimal, with_icu, with_remote, engine, output = map(Path, sys.argv[1:])
output.mkdir(parents=True, exist_ok=True)
output = output.resolve()
home = output / "empty-home"
home.mkdir(exist_ok=True)
env = dict(os.environ, HOME=str(home), TZ="UTC")
trace_key = "DYLD_PRINT_LIBRARIES" if sys.platform == "darwin" else "LD_DEBUG"
trace_value = "1" if sys.platform == "darwin" else "libs"
suffix = ".dylib" if sys.platform == "darwin" else ".so"


def run(label, args, *, success=True, trace=False):
    child_env = dict(env)
    if trace:
        child_env[trace_key] = trace_value
    r = subprocess.run(list(map(str, args)), env=child_env, text=True, capture_output=True, timeout=90)
    (output / (label + ".stdout")).write_text(r.stdout)
    (output / (label + ".stderr")).write_text(r.stderr)
    if (r.returncode == 0) != success:
        raise AssertionError(f"{label}: exit {r.returncode}\n{r.stdout[-2000:]}\n{r.stderr[-4000:]}")
    return r


def one_engine(label, trace, variant):
    engines = set(re.findall(r"/nix/store/[^\s]+/lib/libduckdb" + re.escape(suffix), trace))
    assert engines == {str(variant / "lib" / ("libduckdb" + suffix))}, (label, engines)


source = Path(__file__).with_name("Smoke.java")
run("javac", ["javac", "--release", "11", "-d", output, source])
report = {"platform": sys.platform, "architecture": platform.machine(), "engine_archive": str(engine),
          "engine_sha256": hashlib.sha256(engine.read_bytes()).hexdigest(), "variants": {}}

for name, variant, expected in [
    ("minimal", minimal, "core_functions,json"),
    ("with-icu", with_icu, "core_functions,icu,json"),
    ("with-remote", with_remote, "core_functions,httpfs,icu,json,parquet"),
]:
    cli = [variant / "bin/duckdb", "-init", "/dev/null", "-csv", "-noheader", "-bail", ":memory:", "-c"]
    config = "SET autoload_known_extensions=false; SET autoinstall_known_extensions=false; "
    sets = "SELECT string_agg(extension_name, ',' ORDER BY extension_name) FROM duckdb_extensions() WHERE loaded AND extension_name <> 'shell';"
    positive = config + sets + " SELECT version(); SELECT json_extract_string('{\"v\":\"works-λ\"}', '$.v'); LOAD json; LOAD json;"
    r = run(name + "-cli", cli + [positive], trace=True)
    rows = list(csv.reader(r.stdout.splitlines()))
    assert rows == [[expected], ["v2.0.0"], ["works-λ"]], rows
    one_engine(name + "-cli", r.stderr, variant)
    icu = "SELECT epoch(timezone('Europe/Amsterdam', TIMESTAMP '2026-01-15 12:00:00')) = epoch(TIMESTAMPTZ '2026-01-15 11:00:00+00');"
    r = run(name + "-cli-icu", cli + [config + icu], success="icu" in expected)
    if "icu" in expected:
        assert list(csv.reader(r.stdout.splitlines())) == [["true"]], r.stdout
    else:
        assert "icu" in r.stderr.lower(), r.stderr
        run(name + "-cli-load-icu", cli + [config + "LOAD icu"], success=False)
    omitted = "tpch" if "parquet" in expected else "parquet"
    for operation in ["LOAD", "INSTALL"]:
        r = run(name + "-cli-" + operation.lower() + "-" + omitted, cli + [config + operation + " " + omitted], success=False)
        assert "does not link the loadable_extensions library" in r.stderr, r.stderr
    for mode, jar in [("packed", "duckdb_jdbc.jar"), ("external", "duckdb_jdbc_nolib.jar")]:
        args = ["java", "-Duser.home=" + str(home), "-Djava.io.tmpdir=" + str(output)]
        # Packed mode must work with an empty java.library.path after extracting the JNI resource.
        args += ["-Djava.library.path=" + str(variant / "lib" if mode == "external" else home)]
        args += ["-cp", str(output) + os.pathsep + str(variant / "share/java" / jar), "Smoke", expected]
        r = run(name + "-jdbc-" + mode, args, trace=True)
        one_engine(name + "-jdbc-" + mode, r.stderr, variant)
        print(r.stdout.strip())
    for binary in [variant / "bin/duckdb", variant / "lib" / ("libduckdb_java" + suffix)]:
        r = run(name + "-symbols-" + binary.name,
                ["nm", "-gU" if sys.platform == "darwin" else "--defined-only", binary])
        assert not re.search(r"\b_?duckdb_register_static_extension$", r.stdout, re.MULTILINE), binary
        if sys.platform == "darwin":
            r = run(name + "-deps-" + binary.name, ["otool", "-L", binary])
            assert str(variant / "lib" / "libduckdb.dylib") in r.stdout, r.stdout
    r = run(name + "-symbols-engine", ["nm", "-gU" if sys.platform == "darwin" else "--defined-only", variant / "lib" / ("libduckdb" + suffix)])
    for ext in ["icu", "httpfs", "parquet"]:
        assert bool(re.search(r"\b_?duckdb_extension_" + ext + "_describe$", r.stdout, re.MULTILINE)) == (ext in expected)
    assert re.search(r"\b_?duckdb_register_static_extension$", r.stdout, re.MULTILINE)
    report["variants"][name] = {"path": str(variant), "loaded": expected.split(","),
        "cli": "PASS", "jdbc_packed": "PASS", "jdbc_external": "PASS", "single_shared_engine": "PASS"}
    print("PASS CLI " + expected)
assert not [p for p in home.rglob("*") if p.is_file() or p.is_symlink()], "Unexpected files written to HOME"
report["home_directories"] = sorted(str(p.relative_to(home)) for p in home.rglob("*") if p.is_dir())
(output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print("PASS identical engine archive: " + report["engine_sha256"])
