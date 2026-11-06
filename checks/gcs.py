#!/usr/bin/env python3
"""Run the real GCS SDK against a small authenticated loopback JSON/OAuth fixture."""
import csv
import fnmatch
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import threading
from urllib.parse import parse_qs, unquote, urlsplit

first, last, engine, output = map(Path, sys.argv[1:])
output.mkdir(parents=True)
output = output.resolve()
fixtures = output / "fixtures"
fixtures.mkdir()
home = output / "empty-home"
home.mkdir(mode=0o500)
env = dict(os.environ, HOME=str(home), CLOUDSDK_CONFIG=str(home), TZ="UTC", NO_PROXY="127.0.0.1", no_proxy="127.0.0.1")
for key in list(env):
    if key.upper().endswith("_PROXY") and key.lower() != "no_proxy":
        env.pop(key)
    elif key.startswith(("GOOGLE_", "GCE_", "CLOUD_STORAGE_", "AWS_")):
        env.pop(key)
requests = []
active_label = "setup"


def run(label, args, success=True, overrides=None, trace=False):
    global active_label
    active_label = label
    child = dict(env, **(overrides or {}))
    if trace:
        child["DYLD_PRINT_LIBRARIES" if sys.platform == "darwin" else "LD_DEBUG"] = "1" if sys.platform == "darwin" else "libs"
    r = subprocess.run(list(map(str, args)), env=child, text=True, capture_output=True, timeout=90)
    (output / (label + ".stdout")).write_text(r.stdout)
    (output / (label + ".stderr")).write_text(r.stderr)
    assert (r.returncode == 0) == success, (label, r.stdout[-2000:], r.stderr[-4000:])
    return r


def cli(package, sql):
    return [package / "bin/duckdb", "-init", "/dev/null", "-csv", "-noheader", "-bail", ":memory:", "-c", sql]


def shared_engine(label, text, package):
    suffix = ".dylib" if sys.platform == "darwin" else ".so"
    loaded = set(re.findall(r"/nix/store/[^\s]+/lib/libduckdb" + re.escape(suffix), text))
    assert loaded == {str(package / "lib" / ("libduckdb" + suffix))}, (label, loaded)


(fixtures / "values.csv").write_text("i\n19\n23\n")
run("create-parquet", cli(last, f"COPY (SELECT i FROM range(10000) t(i)) TO '{fixtures}/data.parquet' (FORMAT PARQUET)"))


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def record(self):
        requests.append({"case": active_label, "method": self.command, "path": self.path,
                         "auth": self.headers.get("Authorization"), "range": self.headers.get("Range")})

    def send_json(self, value, status=200):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        self.record()
        form = parse_qs(self.rfile.read(int(self.headers.get("Content-Length", "0"))).decode())
        if self.path == "/token" and form.get("refresh_token") == ["test-refresh"]:
            self.send_json({"access_token": "adc-token", "expires_in": 3600, "token_type": "Bearer"})
        else:
            self.send_json({"error": "invalid_grant"}, 400)

    def respond(self, body=True):
        self.record()
        parsed = urlsplit(self.path)
        if parsed.path == "/values.csv":
            name, media = "values.csv", True
        else:
            if self.headers.get("Authorization") not in ["Bearer adc-token", "Bearer explicit-token"]:
                self.send_json({"error": {"code": 403, "message": "permission denied by fixture endpoint"}}, 403)
                return
            match = re.fullmatch(r"/storage/v1/b/fixture/o(?:/(.*))?", parsed.path)
            if not match:
                self.send_json({"error": {"code": 404, "message": "unexpected route"}}, 404)
                return
            name = unquote(match[1]) if match[1] else ""
            media = parse_qs(parsed.query).get("alt") == ["media"]
            def metadata(n):
                return {"kind": "storage#object", "bucket": "fixture", "name": n, "size": str((fixtures / n).stat().st_size),
                        "generation": "1", "metageneration": "1", "updated": "2026-11-05T00:00:00.000Z"}
            if not name:
                prefix = parse_qs(parsed.query).get("prefix", [""])[0]
                pattern = parse_qs(parsed.query).get("matchGlob", ["*"])[0]
                self.send_json({"items": [metadata(n) for n in ["values.csv", "data.parquet"]
                                         if n.startswith(prefix) and fnmatch.fnmatchcase(n, pattern)]})
                return
            if name not in ["values.csv", "data.parquet"]:
                self.send_json({"error": {"code": 404, "message": "no such object"}}, 404)
                return
            if not media:
                self.send_json(metadata(name))
                return
        data = (fixtures / name).read_bytes()
        start, end = 0, len(data) - 1
        span = self.headers.get("Range")
        if span:
            match = re.fullmatch(r"bytes=(\d+)-(\d*)", span)
            assert match, span
            start = int(match[1])
            end = min(int(match[2]) if match[2] else end, end)
        self.send_response(206 if span else 200)
        self.send_header("Content-Length", str(end - start + 1))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("x-goog-generation", "1")
        if span:
            self.send_header("Content-Range", f"bytes {start}-{end}/{len(data)}")
        self.end_headers()
        if body:
            self.wfile.write(data[start:end + 1])

    def do_GET(self):
        self.respond()

    def do_HEAD(self):
        self.respond(False)


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
url = f"http://127.0.0.1:{server.server_port}"
adc = fixtures / "adc.json"
adc.write_text(json.dumps({"type": "authorized_user", "client_id": "test-id", "client_secret": "test-secret",
                          "refresh_token": "test-refresh", "token_uri": url + "/token"}))
env.update(GOOGLE_APPLICATION_CREDENTIALS=str(adc), CLOUD_STORAGE_EMULATOR_ENDPOINT=url,
           GCE_METADATA_HOST=f"127.0.0.1:{server.server_port}")
config = "SET autoload_known_extensions=false; SET autoinstall_known_extensions=false; SET gcs_enable_metadata_cache=false; "
competing = f"CREATE SECRET competing_httpfs (TYPE GCS, KEY_ID 'test-hmac', SECRET 'test-hmac', ENDPOINT '127.0.0.1:{server.server_port}', URL_STYLE 'path', USE_SSL false); "
try:
    run("javac", ["javac", "--release", "11", "-d", output, "Smoke.java", "GcsSmoke.java"])
    for order, package in [("gcs-first", first), ("httpfs-first", last)]:
        sql = config + competing
        for scheme in ["gs", "gcs", "gcss"]:
            sql += f"SELECT sum(i) FROM read_csv('{scheme}://fixture/values.csv'); "
            sql += f"SELECT count(*) || ':' || sum(i) FROM read_parquet('{scheme}://fixture/data.parquet'); "
        sql += f"SELECT sum(i) FROM read_csv('{url}/values.csv');"
        r = run(order + "-cli", cli(package, sql), trace=True)
        assert list(csv.reader(r.stdout.splitlines())) == [["true"]] + [["42"], ["10000:49995000"]] * 3 + [["42"]], r.stdout
        shared_engine(order, r.stderr, package)
        for mode, jar in [("packed", "duckdb_jdbc.jar"), ("external", "duckdb_jdbc_nolib.jar")]:
            r = run(order + "-jdbc-" + mode, ["java", "-Duser.home=" + str(home), "-Djava.io.tmpdir=" + str(output),
                "-Djava.library.path=" + str(package / "lib" if mode == "external" else home),
                "-cp", str(output) + os.pathsep + str(package / "share/java" / jar), "GcsSmoke", url,
                f"127.0.0.1:{server.server_port}"], trace=True)
            shared_engine(order + "-jdbc-" + mode, r.stderr, package)
            print(r.stdout.strip())
    r = run("explicit-credentials", cli(last, config + competing + "CREATE SECRET native_gcp (TYPE GCP, PROVIDER access_token, ACCESS_TOKEN 'explicit-token'); SELECT sum(i) FROM read_csv('gs://fixture/values.csv')"))
    assert list(csv.reader(r.stdout.splitlines())) == [["true"], ["true"], ["42"]]
    r = run("invalid-explicit-credentials", cli(last, config + competing + "CREATE SECRET native_gcp (TYPE GCP, PROVIDER access_token, ACCESS_TOKEN 'invalid-token'); SELECT * FROM read_csv('gs://fixture/values.csv')"), False)
    assert "denied" in r.stderr.lower(), r.stderr
    bad_adc = fixtures / "bad-adc.json"
    bad_adc.write_text('{"type":"authorized_user"}')
    r = run("invalid-adc", cli(last, config + competing + "SELECT * FROM read_csv('gs://fixture/values.csv')"), False,
            {"GOOGLE_APPLICATION_CREDENTIALS": str(bad_adc)})
    assert "credentials" in r.stderr.lower() or "client_id" in r.stderr.lower(), r.stderr
finally:
    server.shutdown()
    server.server_close()
    (output / "requests.json").write_text(json.dumps(requests, indent=2) + "\n")

assert not list(home.iterdir()), "Unexpected HOME writes"
home.chmod(0o700)
assert any(r["path"] == "/token" for r in requests), "No real ADC refresh was exercised"
assert any(r["auth"] == "Bearer adc-token" for r in requests), "ADC token was not used"
assert any(r["auth"] == "Bearer explicit-token" for r in requests), "Explicit credential was not used"
assert not [r for r in requests if r["case"] == "invalid-adc"], "Unexpected network after credential rejection"
invalid = [r for r in requests if r["case"] == "invalid-explicit-credentials"]
assert invalid and all(r["auth"] == "Bearer invalid-token" for r in invalid), "Invalid explicit credentials fell back to ADC"
(output / "requests.json").write_text(json.dumps(requests, indent=2) + "\n")
report = {"platform": sys.platform, "architecture": platform.machine(), "engine_archive": str(engine),
    "engine_sha256": hashlib.sha256(engine.read_bytes()).hexdigest(),
    "packages": {"gcs_first": str(first), "httpfs_first": str(last)},
    "startup_callback": "PASS", "adc_fallback": "PASS",
    "explicit_credentials": "PASS", "invalid_credentials": "PASS", "three_schemes_both_orders": "PASS",
    "cli_and_both_jdbc_modes": "PASS", "single_shared_engine": "PASS", "readonly_home": "PASS", "requests": len(requests)}
(output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print("PASS GCS ADC fallback, startup callback, and HTTPFS coexistence in both registration orders")
