"""tests/stub/run.py (tests T4): run one agent against the stub server.

A fake agent stands in for the real ones: it asks the stub over chat
completions, runs the `write` tool call it gets back, and sends the
result, as an agent does.
"""

import json
import os
import sys
import tempfile
import unittest

from tests.stub import run

FAKE_AGENT = r"""
import json, os, sys, urllib.request
base = os.environ["FAKE_BASE"]
def ask(messages):
    tools = [{"type": "function", "function": {"name": "write"}}]
    body = json.dumps({"model": "m", "messages": messages, "tools": tools})
    req = urllib.request.Request(base + "/v1/chat/completions", body.encode(), {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req))["choices"][0]["message"]
messages = [{"role": "user", "content": sys.argv[1]}]
reply = ask(messages)
for call in reply.get("tool_calls") or []:
    args = json.loads(call["function"]["arguments"])
    with open(args["path"], "w") as f:
        f.write(args["content"])
    messages += [reply, {"role": "tool", "tool_call_id": call["id"], "content": "ok"}]
print(ask(messages)["content"])
"""


class ExpandTest(unittest.TestCase):
    def test_placeholders_are_filled_everywhere(self):
        value = {"a": ["{base}/v1", "{home}/.x", "{workdir}/y"], "b": "{port}"}
        got = run.expand(value, {"base": "http://h:1", "home": "/h", "workdir": "/w", "port": "1"})
        self.assertEqual(got, {"a": ["http://h:1/v1", "/h/.x", "/w/y"], "b": "1"})


class EnvTest(unittest.TestCase):
    def test_home_is_the_runs_own_and_pythonpath_never_leaks(self):
        env = run.environment({"PATH": "/bin", "PYTHONPATH": "/leak", "HOME": "/real"}, {"K": "v"}, "/h")
        self.assertEqual((env["HOME"], env["K"], env["PATH"]), ("/h", "v", "/bin"))
        self.assertNotIn("PYTHONPATH", env)


class RunTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.agent = os.path.join(self.dir, "fake_agent.py")
        with open(self.agent, "w") as f:
            f.write(FAKE_AGENT)
        self.script = os.path.join(self.dir, "fake.json")
        with open(self.script, "w") as f:
            json.dump(
                {
                    "turns": [
                        {"tool": {"name": "write", "arguments": {"path": "{workdir}/hello.txt", "content": "hi\n"}}},
                        {"text": "Done."},
                    ]
                },
                f,
            )

    def recipe(self, argv_tail):
        return {
            "env": {"FAKE_BASE": "{base}"},
            "files": {"{home}/.fake/config": "base={base}\n"},
            "argv": [sys.executable, self.agent, *argv_tail],
        }

    def test_an_agent_that_writes_the_file_passes(self):
        result = run.run_agent(self.recipe(["write hello.txt"]), self.script, timeout=30)
        self.assertTrue(result.ok, result.output)
        self.assertIn("Done.", result.output)

    def test_its_config_files_are_written_before_it_starts(self):
        result = run.run_agent(self.recipe(["write hello.txt"]), self.script, timeout=30)
        with open(os.path.join(result.home, ".fake", "config")) as f:
            self.assertTrue(f.read().startswith("base=http://127.0.0.1:"))

    def test_an_agent_that_never_writes_fails(self):
        recipe = {"env": {}, "files": {}, "argv": [sys.executable, "-c", "print('nothing')"]}
        result = run.run_agent(recipe, self.script, timeout=10)
        self.assertFalse(result.ok)

    def test_every_recorded_agent_has_a_script_and_a_recipe(self):
        runs = run.load_runs()
        scripts = {name[: -len(".json")] for name in os.listdir(run.SCRIPTS)}
        self.assertEqual(set(runs), scripts)


if __name__ == "__main__":
    unittest.main()
