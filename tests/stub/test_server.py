"""tests/stub/server.py (tests T3, V1): the stub model server.

One script, two turns: a tool call that writes a file, then a final text.
Each protocol picks the turn from how many tool results the request
already carries, and renders it the way that API does, plain or streamed.
"""

import json
import threading
import unittest
import urllib.request
from http.server import ThreadingHTTPServer

from tests.stub import server

SCRIPT = {
    "turns": [
        {"tool": {"name": "Write", "arguments": {"file_path": "hello.txt", "content": "hi\n"}}},
        {"text": "Done."},
    ]
}


def sse(body):
    """The `data:` payloads of a server-sent event stream, in order."""
    return [line[len("data: ") :] for line in body.decode().splitlines() if line.startswith("data: ")]


class TurnTest(unittest.TestCase):
    def test_a_fresh_request_gets_the_first_turn(self):
        self.assertEqual(server.turn(SCRIPT, 0), SCRIPT["turns"][0])

    def test_a_request_with_one_tool_result_gets_the_second_turn(self):
        self.assertEqual(server.turn(SCRIPT, 1), SCRIPT["turns"][1])

    def test_past_the_end_the_last_turn_repeats(self):
        self.assertEqual(server.turn(SCRIPT, 7), SCRIPT["turns"][1])


class ToolResultsTest(unittest.TestCase):
    def test_chat_counts_tool_role_messages(self):
        body = {"messages": [{"role": "user", "content": "x"}, {"role": "tool", "content": "ok"}]}
        self.assertEqual(server.tool_results("chat", body), 1)

    def test_responses_counts_function_call_outputs(self):
        body = {"input": [{"role": "user", "content": "x"}, {"type": "function_call_output", "output": "ok"}]}
        self.assertEqual(server.tool_results("responses", body), 1)

    def test_responses_takes_a_plain_string_input(self):
        self.assertEqual(server.tool_results("responses", {"input": "hi"}), 0)

    def test_messages_counts_tool_result_blocks(self):
        body = {
            "messages": [
                {"role": "user", "content": "x"},
                {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "t", "content": "ok"}]},
            ]
        }
        self.assertEqual(server.tool_results("messages", body), 1)


class ChatTest(unittest.TestCase):
    def test_a_tool_call(self):
        reply = json.loads(server.render("chat", SCRIPT["turns"][0], "stub", False))
        message = reply["choices"][0]["message"]
        self.assertEqual(reply["choices"][0]["finish_reason"], "tool_calls")
        call = message["tool_calls"][0]
        self.assertEqual(call["function"]["name"], "Write")
        self.assertEqual(json.loads(call["function"]["arguments"]), SCRIPT["turns"][0]["tool"]["arguments"])

    def test_a_final_text(self):
        reply = json.loads(server.render("chat", SCRIPT["turns"][1], "stub", False))
        self.assertEqual(reply["choices"][0]["message"]["content"], "Done.")
        self.assertEqual(reply["choices"][0]["finish_reason"], "stop")

    def test_streamed_ends_with_done(self):
        events = sse(server.render("chat", SCRIPT["turns"][1], "stub", True))
        self.assertEqual(events[-1], "[DONE]")
        text = "".join(json.loads(e)["choices"][0]["delta"].get("content") or "" for e in events[:-1])
        self.assertEqual(text, "Done.")


class ResponsesTest(unittest.TestCase):
    def test_a_function_call(self):
        reply = json.loads(server.render("responses", SCRIPT["turns"][0], "stub", False))
        item = reply["output"][0]
        self.assertEqual(item["type"], "function_call")
        self.assertEqual(item["name"], "Write")
        self.assertEqual(reply["status"], "completed")

    def test_streamed_text_completes(self):
        events = [json.loads(e) for e in sse(server.render("responses", SCRIPT["turns"][1], "stub", True))]
        self.assertEqual(events[0]["type"], "response.created")
        self.assertEqual(events[-1]["type"], "response.completed")
        deltas = "".join(e["delta"] for e in events if e["type"] == "response.output_text.delta")
        self.assertEqual(deltas, "Done.")


class MessagesTest(unittest.TestCase):
    def test_a_tool_use(self):
        reply = json.loads(server.render("messages", SCRIPT["turns"][0], "stub", False))
        self.assertEqual(reply["stop_reason"], "tool_use")
        block = reply["content"][0]
        self.assertEqual((block["type"], block["name"]), ("tool_use", "Write"))
        self.assertEqual(block["input"], SCRIPT["turns"][0]["tool"]["arguments"])

    def test_streamed_tool_use_carries_its_input(self):
        events = [json.loads(e) for e in sse(server.render("messages", SCRIPT["turns"][0], "stub", True))]
        self.assertEqual(events[0]["type"], "message_start")
        self.assertEqual(events[-1]["type"], "message_stop")
        partial = "".join(e["delta"]["partial_json"] for e in events if e["type"] == "content_block_delta")
        self.assertEqual(json.loads(partial), SCRIPT["turns"][0]["tool"]["arguments"])


class DeterminismTest(unittest.TestCase):
    """V1: the same script gives the same bytes, every protocol, every mode."""

    def test_same_bytes_twice(self):
        for protocol in ("chat", "responses", "messages"):
            for stream in (False, True):
                for turn in SCRIPT["turns"]:
                    self.assertEqual(
                        server.render(protocol, turn, "stub", stream),
                        server.render(protocol, turn, "stub", stream),
                    )


class HttpTest(unittest.TestCase):
    """The server end to end, on an ephemeral port."""

    def setUp(self):
        self.httpd = ThreadingHTTPServer(("127.0.0.1", 0), server.handler(SCRIPT))
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.httpd.server_address[1]}"

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()

    def post(self, path, body):
        request = urllib.request.Request(
            self.base + path, json.dumps(body).encode(), {"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(request) as response:
            return response.read()

    def test_the_two_turns_over_anthropic_messages(self):
        first = json.loads(self.post("/v1/messages", {"model": "m", "messages": [{"role": "user", "content": "go"}]}))
        self.assertEqual(first["stop_reason"], "tool_use")
        result = {"role": "user", "content": [{"type": "tool_result", "tool_use_id": first["content"][0]["id"]}]}
        second = json.loads(
            self.post("/v1/messages", {"model": "m", "messages": [{"role": "user", "content": "go"}, result]})
        )
        self.assertEqual(second["content"][0]["text"], "Done.")

    def test_models_lists_one_model(self):
        with urllib.request.urlopen(self.base + "/v1/models") as response:
            self.assertEqual(json.loads(response.read())["data"][0]["id"], "stub")

    def test_an_unknown_path_is_404(self):
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self.post("/v1/nope", {})
        self.assertEqual(caught.exception.code, 404)


if __name__ == "__main__":
    unittest.main()
