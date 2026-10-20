"""The stub model server (tests T3, D44): agents talk to it instead of a paid
model, and it replays a script.

A script is JSON, `{"turns": [...]}`; each turn is either a tool call,
`{"tool": {"name": ..., "arguments": {...}}}`, or a final answer,
`{"text": ...}`. A request gets the turn whose index is the number of tool
results it already carries, so an agent that runs the tool and sends its
result back gets the next turn; past the end the last turn repeats.

Three protocols, each plain or streamed (server-sent events) as the
request's `stream` asks:

- OpenAI chat completions, POST /v1/chat/completions
- OpenAI responses, POST /v1/responses
- Anthropic messages, POST /v1/messages

GET /v1/models lists one model. Ids and timestamps are fixed, so the same
script always gives the same bytes (tests V1). Stdlib only (root §C).

Usage: python3 -m tests.stub.server --script FILE [--port N]
"""

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PROTOCOLS = {
    "/v1/chat/completions": "chat",
    "/v1/responses": "responses",
    "/v1/messages": "messages",
}

USAGE = {"input_tokens": 1, "output_tokens": 1}


def turn(script, results):
    """The turn for a request that carries `results` tool results."""
    turns = script["turns"]
    return turns[min(results, len(turns) - 1)]


def tool_results(protocol, body):
    """How many tool results a request already carries."""
    if protocol == "chat":
        return sum(1 for m in body.get("messages", []) if m.get("role") == "tool")
    if protocol == "responses":
        items = body.get("input", [])
        if isinstance(items, str):
            return 0
        return sum(1 for i in items if i.get("type") == "function_call_output")
    count = 0
    for message in body.get("messages", []):
        content = message.get("content")
        if isinstance(content, list):
            count += sum(1 for block in content if block.get("type") == "tool_result")
    return count


def dump(value):
    """Compact, key-ordered JSON: the same value is always the same text."""
    return json.dumps(value, separators=(",", ":"), sort_keys=True)


def events(pairs):
    """Server-sent events from (event name or None, payload) pairs."""
    out = []
    for name, payload in pairs:
        if name:
            out.append(f"event: {name}\n")
        out.append(f"data: {payload if isinstance(payload, str) else dump(payload)}\n\n")
    return "".join(out).encode()


def chat(step, model, stream):
    """OpenAI chat completions."""
    base = {"id": "chatcmpl-stub", "created": 0, "model": model}
    if "tool" in step:
        call = {
            "id": "call_stub",
            "type": "function",
            "function": {"name": step["tool"]["name"], "arguments": dump(step["tool"]["arguments"])},
        }
        message, finish = {"role": "assistant", "content": None, "tool_calls": [call]}, "tool_calls"
    else:
        message, finish = {"role": "assistant", "content": step["text"]}, "stop"
    if not stream:
        return dump(
            {
                **base,
                "object": "chat.completion",
                "choices": [{"index": 0, "message": message, "finish_reason": finish}],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
            }
        ).encode()
    chunk = {**base, "object": "chat.completion.chunk"}
    delta = {"role": "assistant"}
    if "tool" in step:
        delta["tool_calls"] = [{"index": 0, **message["tool_calls"][0]}]
    else:
        delta["content"] = step["text"]
    return events(
        [
            (None, {**chunk, "choices": [{"index": 0, "delta": delta, "finish_reason": None}]}),
            (None, {**chunk, "choices": [{"index": 0, "delta": {}, "finish_reason": finish}]}),
            (None, "[DONE]"),
        ]
    )


def responses(step, model, stream):
    """OpenAI responses."""
    if "tool" in step:
        item = {
            "type": "function_call",
            "id": "fc_stub",
            "call_id": "call_stub",
            "name": step["tool"]["name"],
            "arguments": dump(step["tool"]["arguments"]),
            "status": "completed",
        }
    else:
        item = {
            "type": "message",
            "id": "msg_stub",
            "role": "assistant",
            "status": "completed",
            "content": [{"type": "output_text", "text": step["text"], "annotations": []}],
        }
    done = {
        "id": "resp_stub",
        "object": "response",
        "created_at": 0,
        "status": "completed",
        "model": model,
        "output": [item],
        "usage": {**USAGE, "total_tokens": 2},
    }
    if not stream:
        return dump(done).encode()
    started = {**done, "status": "in_progress", "output": []}
    pairs = [("response.created", {"type": "response.created", "response": started})]
    pairs.append(
        ("response.output_item.added", {"type": "response.output_item.added", "output_index": 0, "item": item})
    )
    if "tool" in step:
        pairs.append(
            (
                "response.function_call_arguments.done",
                {"type": "response.function_call_arguments.done", "item_id": "fc_stub", "arguments": item["arguments"]},
            )
        )
    else:
        part = {"item_id": "msg_stub", "output_index": 0, "content_index": 0}
        pairs.append(
            ("response.output_text.delta", {"type": "response.output_text.delta", **part, "delta": step["text"]})
        )
        pairs.append(("response.output_text.done", {"type": "response.output_text.done", **part, "text": step["text"]}))
    pairs.append(("response.output_item.done", {"type": "response.output_item.done", "output_index": 0, "item": item}))
    pairs.append(("response.completed", {"type": "response.completed", "response": done}))
    numbered = [(name, {**payload, "sequence_number": n}) for n, (name, payload) in enumerate(pairs)]
    return events(numbered)


def messages(step, model, stream):
    """Anthropic messages."""
    if "tool" in step:
        block = {
            "type": "tool_use",
            "id": "toolu_stub",
            "name": step["tool"]["name"],
            "input": step["tool"]["arguments"],
        }
        stop = "tool_use"
    else:
        block = {"type": "text", "text": step["text"]}
        stop = "end_turn"
    message = {
        "id": "msg_stub",
        "type": "message",
        "role": "assistant",
        "model": model,
        "content": [block],
        "stop_reason": stop,
        "stop_sequence": None,
        "usage": USAGE,
    }
    if not stream:
        return dump(message).encode()
    if "tool" in step:
        start = {**block, "input": {}}
        delta = {"type": "input_json_delta", "partial_json": dump(step["tool"]["arguments"])}
    else:
        start = {"type": "text", "text": ""}
        delta = {"type": "text_delta", "text": step["text"]}
    opening = {**message, "content": [], "stop_reason": None}
    return events(
        [
            ("message_start", {"type": "message_start", "message": opening}),
            ("content_block_start", {"type": "content_block_start", "index": 0, "content_block": start}),
            ("content_block_delta", {"type": "content_block_delta", "index": 0, "delta": delta}),
            ("content_block_stop", {"type": "content_block_stop", "index": 0}),
            (
                "message_delta",
                {"type": "message_delta", "delta": {"stop_reason": stop, "stop_sequence": None}, "usage": USAGE},
            ),
            ("message_stop", {"type": "message_stop"}),
        ]
    )


RENDERERS = {"chat": chat, "responses": responses, "messages": messages}


def render(protocol, step, model, stream):
    """One turn as `protocol` sends it: JSON bytes, or event-stream bytes."""
    return RENDERERS[protocol](step, model, stream)


def handler(script):
    """A request handler class serving `script`."""

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.split("?")[0] != "/v1/models":
                self.send_error(404)
                return
            self.reply(
                200,
                "application/json",
                dump(
                    {"object": "list", "data": [{"id": "stub", "object": "model", "created": 0, "owned_by": "stub"}]}
                ).encode(),
            )

        def do_POST(self):
            protocol = PROTOCOLS.get(self.path.split("?")[0])
            if protocol is None:
                self.send_error(404)
                return
            length = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(length) or b"{}")
            stream = bool(body.get("stream"))
            step = turn(script, tool_results(protocol, body))
            payload = render(protocol, step, body.get("model", "stub"), stream)
            self.reply(200, "text/event-stream" if stream else "application/json", payload)

        def reply(self, status, kind, payload):
            self.send_response(status)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, format, *args):  # noqa: A002 - BaseHTTPRequestHandler's signature
            return

    return Handler


def main():
    parser = argparse.ArgumentParser(description="Replay a scripted model over OpenAI and Anthropic APIs.")
    parser.add_argument("--script", required=True, help='JSON script: {"turns": [...]}')
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()
    with open(args.script, encoding="utf-8") as f:
        script = json.load(f)
    ThreadingHTTPServer(("127.0.0.1", args.port), handler(script)).serve_forever()


if __name__ == "__main__":
    main()
