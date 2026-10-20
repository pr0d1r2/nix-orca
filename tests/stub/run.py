"""Run one agent against the stub server (tests T4, D44): the recipe in
tests/stub/runs.json says how that agent reaches a custom endpoint (its
variables, its config files and its command line), and its script in
tests/stub/scripts/ says what the "model" answers. The run passes when the
agent wrote hello.txt holding "hi".

Each run gets a fresh working directory and HOME, the stub on a free
loopback port, stdin closed, PWD set to the working directory (opencode
reads PWD, not its real cwd), and no PYTHONPATH from the caller: a dev
shell's PYTHONPATH loads another Python's packages into Python agents.
Placeholders `{base}` (http://127.0.0.1:<port>), `{port}`, `{home}` and
`{workdir}` are filled in the recipe; `{workdir}` also in the script.

Usage: python3 -m tests.stub.run AGENT... [--timeout SECONDS]
       python3 -m tests.stub.run --all [--timeout SECONDS]
"""

import argparse
import json
import os
import signal
import subprocess
import sys
import tempfile
import threading
import time
from collections import namedtuple
from http.server import ThreadingHTTPServer

from tests.stub import server

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(HERE, "scripts")
RUNS = os.path.join(HERE, "runs.json")
WANT = "hi\n"

Result = namedtuple("Result", "ok output home workdir")


def load_runs():
    """Every agent's recipe, by Orca agent id."""
    with open(RUNS, encoding="utf-8") as f:
        return json.load(f)


def expand(value, names):
    """`value` with every `{name}` from `names` filled, in every string."""
    if isinstance(value, str):
        for name, text in names.items():
            value = value.replace("{" + name + "}", text)
        return value
    if isinstance(value, list):
        return [expand(v, names) for v in value]
    if isinstance(value, dict):
        return {expand(k, names): expand(v, names) for k, v in value.items()}
    return value


def environment(base, extra, home):
    """The agent's environment: the caller's, its own HOME, the recipe's
    variables, and never PYTHONPATH."""
    env = {k: v for k, v in base.items() if k != "PYTHONPATH"}
    env.update(extra)
    env["HOME"] = home
    return env


def written(workdir):
    """What the agent wrote to hello.txt, or None."""
    try:
        with open(os.path.join(workdir, "hello.txt"), encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None


def run_agent(recipe, script_path, timeout=120):
    """Run one recipe against the stub serving `script_path`."""
    workdir = os.path.realpath(tempfile.mkdtemp(prefix="orca-stub-work-"))
    home = os.path.realpath(tempfile.mkdtemp(prefix="orca-stub-home-"))
    with open(script_path, encoding="utf-8") as f:
        script = server.fill(json.load(f), workdir)
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), server.handler(script))
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    port = str(httpd.server_address[1])
    names = {"base": f"http://127.0.0.1:{port}", "port": port, "home": home, "workdir": workdir}
    recipe = expand(recipe, names)
    for path, text in recipe.get("files", {}).items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
    log = tempfile.TemporaryFile()
    agent = subprocess.Popen(
        recipe["argv"],
        cwd=workdir,
        env={**environment(os.environ, recipe.get("env", {}), home), "PWD": workdir},
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline and agent.poll() is None and written(workdir) != WANT:
        time.sleep(0.5)
    # A few seconds more, so the agent can finish its last turn and exit.
    grace = time.monotonic() + 5
    while agent.poll() is None and time.monotonic() < grace:
        time.sleep(0.5)
    if agent.poll() is None:
        os.killpg(agent.pid, signal.SIGKILL)
        agent.wait()
    httpd.shutdown()
    httpd.server_close()
    log.seek(0)
    output = log.read().decode(errors="replace")
    return Result(written(workdir) == WANT, output, home, workdir)


def main():
    parser = argparse.ArgumentParser(description="Run agents against the stub model server.")
    parser.add_argument("agents", nargs="*", help="Orca agent ids from tests/stub/runs.json")
    parser.add_argument("--all", action="store_true", help="every agent in runs.json")
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()
    runs = load_runs()
    agents = sorted(runs) if args.all else args.agents
    if not agents:
        parser.error("name an agent, or pass --all")
    failed = 0
    for agent in agents:
        result = run_agent(runs[agent], os.path.join(SCRIPTS, agent + ".json"), args.timeout)
        print(f"{'PASS' if result.ok else 'FAIL'} {agent}")
        if not result.ok:
            failed += 1
            print("  " + result.output[-600:].replace("\n", "\n  "))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
