#!/usr/bin/env python3
"""Loopback-only HTTPFS/Parquet integration probe; no cloud credentials required."""
import csv
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import ssl
import subprocess
import sys
import threading

minimal, remote, httpfs, parquet, output = map(Path, sys.argv[1:])
output = output.resolve()
fixtures = output / "fixtures"
fixtures.mkdir()
home = output / "readonly-home"
home.mkdir(mode=0o500)
env = dict(os.environ, HOME=str(home), TZ="UTC", NO_PROXY="127.0.0.1", no_proxy="127.0.0.1")
for key in ["HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"]:
    env.pop(key, None)


def run(label, args, success=True):
    r = subprocess.run(list(map(str, args)), env=env, text=True, capture_output=True, timeout=60)
    (output / (label + ".stdout")).write_text(r.stdout)
    (output / (label + ".stderr")).write_text(r.stderr)
    assert (r.returncode == 0) == success, (label, r.stdout, r.stderr)
    return r


def cli(package, sql):
    return [package / "bin/duckdb", "-init", "/dev/null", "-csv", "-noheader", "-bail", ":memory:", "-c", sql]


(fixtures / "values.csv").write_text("i\n19\n23\n")
run("create-parquet", cli(remote, "COPY (SELECT i, 'row-' || i AS label FROM range(10000) t(i)) TO '"
    + str(fixtures / "data.parquet") + "' (FORMAT PARQUET, COMPRESSION ZSTD, ROW_GROUP_SIZE 2048)"))
cert, key = fixtures / "cert.pem", fixtures / "key.pem"
run("create-test-certificate", ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-noenc", "-days", "1",
    "-subj", "/CN=127.0.0.1", "-addext", "subjectAltName=IP:127.0.0.1", "-keyout", key, "-out", cert])
requests = []


class Handler(BaseHTTPRequestHandler):
    def handle(self):
        try:
            super().handle()
        except (ConnectionResetError, BrokenPipeError):
            # The negative TLS probe intentionally rejects this server's certificate.
            pass

    def log_message(self, *args):
        pass

    def respond(self, body):
        requests.append({"method": self.command, "path": self.path,
                         "range": self.headers.get("Range"), "tls": isinstance(self.connection, ssl.SSLSocket)})
        if self.path not in ["/values.csv", "/data.parquet"]:
            self.send_error(404)
            return
        data = (fixtures / self.path[1:]).read_bytes()
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
        self.send_header("ETag", '"fixture-fixture"')
        if span:
            self.send_header("Content-Range", f"bytes {start}-{end}/{len(data)}")
        self.end_headers()
        if body:
            self.wfile.write(data[start:end + 1])

    def do_HEAD(self):
        self.respond(False)

    def do_GET(self):
        self.respond(True)


http = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
https = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(cert, key)
https.socket = context.wrap_socket(https.socket, server_side=True)
for server in [http, https]:
    threading.Thread(target=server.serve_forever, daemon=True).start()
urls = [f"http://127.0.0.1:{http.server_port}", f"https://127.0.0.1:{https.server_port}"]
config = ("SET autoload_known_extensions=false; SET autoinstall_known_extensions=false; "
          "SET http_timeout=5; SET http_retries=0; SET enable_server_cert_verification=true; "
          f"SET ca_cert_file='{cert}'; ")
try:
    for scheme, url in zip(["http", "https"], urls):
        sql = config + f"SELECT sum(i) FROM read_csv('{url}/values.csv'); "
        sql += f"SELECT count(*) || ':' || sum(i) FROM read_parquet('{url}/data.parquet') WHERE i % 2 = 0;"
        r = run("remote-cli-" + scheme, cli(remote, sql))
        assert list(csv.reader(r.stdout.splitlines())) == [["42"], ["5000:24995000"]], r.stdout
        r = run("remote-cli-disabled-" + scheme, cli(remote,
            config + f"SET enable_external_access=false; SELECT * FROM read_csv('{url}/values.csv')"), False)
        assert "disabled" in r.stderr.lower(), r.stderr
    # A TLS handshake without the explicitly trusted certificate must fail.
    r = run("remote-cli-untrusted-tls", cli(remote,
        "SET http_retries=0; SET enable_server_cert_verification=true; "
        f"SELECT * FROM read_csv('{urls[1]}/values.csv')"), False)
    assert "certificate" in r.stderr.lower(), r.stderr
    before = len(requests)
    r = run("remote-cli-omitted-httpfs", cli(minimal,
        "SET autoload_known_extensions=false; SET autoinstall_known_extensions=false; "
        f"SELECT * FROM read_csv('{urls[0]}/values.csv')"), False)
    assert "httpfs" in r.stderr.lower(), r.stderr
    assert before == len(requests), "Omitted HTTPFS made a request"

    run("javac-remote", ["javac", "--release", "11", "-cp", output, "-d", output,
        Path(__file__).with_name("RemoteSmoke.java")])
    for mode, jar in [("packed", "duckdb_jdbc.jar"), ("external", "duckdb_jdbc_nolib.jar")]:
        args = ["java", "-Duser.home=" + str(home), "-Djava.io.tmpdir=" + str(output),
                "-Djava.library.path=" + str(remote / "lib" if mode == "external" else home),
                "-cp", str(output) + os.pathsep + str(remote / "share/java" / jar), "RemoteSmoke", *urls, cert]
        print(run("remote-jdbc-" + mode, args).stdout.strip())
finally:
    for server in [http, https]:
        server.shutdown()
        server.server_close()

assert not list(home.iterdir()), "Remote reads wrote to HOME"
home.chmod(0o700)  # Allow Nix to normalize the completed output.
assert any(r["range"] for r in requests), "No HTTP range requests observed"
assert any(r["tls"] for r in requests), "No HTTPS requests observed"
(output / "http-requests.json").write_text(json.dumps(requests, indent=2) + "\n")
for name, archive in [("httpfs", httpfs), ("parquet", parquet)]:
    r = run(name + "-archive-symbols", ["nm", "-gU" if sys.platform == "darwin" else "--defined-only",
        archive / "lib" / ("lib" + name + "_extension.a")])
    assert re.search(r"\b_?duckdb_extension_" + name + "_describe$", r.stdout, re.MULTILINE)
    assert not re.search(r"\b_?duckdb_register_static_extension$", r.stdout, re.MULTILINE)
report = json.loads((output / "report.json").read_text())
report["independent_archives"] = {"httpfs": str(httpfs), "parquet": str(parquet)}
report["remote_io"] = {"http_csv_parquet": "PASS", "https_csv_parquet": "PASS",
    "tls_verification": "PASS", "jdbc_startup_settings": "PASS", "s3_secret_registration": "PASS",
    "external_access_disabled": "PASS", "readonly_home": "PASS", "http_requests": len(requests)}
report["startup_option_policy"] = {
    "autoload_true_autoinstall_false": "PASS",
    "autoload_false": "rejected before static eager loading (verified)",
    "autoinstall_true": "attempted installation before static-name lookup (verified)"}
(output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print("PASS independent HTTPFS/Parquet archives, HTTP/HTTPS reads, TLS verification and read-only HOME")
