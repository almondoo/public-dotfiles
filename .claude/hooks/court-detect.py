#!/usr/bin/env python3
"""Stop hook: detect a malformed tool call left in the assistant's final text.

On Claude Opus 4.8, tool calls sometimes leak into the assistant's text output
as bare <invoke>/<parameter> tags missing the antml: prefix (often preceded by a
lone "court"/"call" token) and the turn ends silently with stop_reason=end_turn
— the call is never executed and work stalls unnoticed. This hook fires on Stop,
inspects the assistant messages, and if the latest turn carries the malformed
signature, blocks the stop and feeds a continuation prompt (via `reason`) telling
Claude to resend the call with correct antml: prefixes.

Because Opus 4.8 tends to emit malformed calls in clusters once context grows, a
single forced retry is not enough: the continuation itself often malforms again,
and the old `stop_hook_active` guard surrendered after exactly one retry. Instead,
this hook counts the trailing run of consecutive malformed assistant turns and
keeps forcing a resend while that run is shorter than MAX_MALFORMED_RETRIES, then
gives up so a malforming model cannot loop forever. The run strictly grows on each
repeated failure, so termination is guaranteed.

Wired via ~/.claude/settings.json:
  "hooks": {"Stop": [{"hooks": [{"type": "command",
    "command": "python3 ~/.claude/hooks/court-detect.py"}]}]}
"""

import json
import re
import sys

# How many consecutive malformed assistant turns to tolerate before giving up.
# We force a resend while the trailing malformed run is shorter than this; once
# it reaches this length we allow the stop so a malforming model cannot loop
# forever. 3 => block on the 1st and 2nd failures, surrender on the 3rd.
MAX_MALFORMED_RETRIES = 3


def strip_code(text: str) -> str:
    """Remove fenced code blocks and inline-backtick spans so that quoted
    <invoke> examples in docs/explanations do not trigger a false positive.
    Genuine malformed tags are emitted bare (no backticks)."""
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    text = re.sub(r"`[^`]*`", "", text)
    return text


# A genuine malformed call leaves the bare tool-call structure in the text: an
# opening `<invoke name="..."` plus a `<parameter name="..."` or closing
# `</invoke>`, all without the antml: prefix. Correct calls never appear as text
# (they are structured tool_use blocks), so this structure outside code fences is
# the signature. Token-agnostic: covers "court"/"call" and any other preamble.
_OPEN = re.compile(r"(?m)^\s*<invoke\s+name=")
_BODY = re.compile(r"(?m)^\s*(</invoke>|<parameter\s+name=)")


def is_malformed(text: str) -> bool:
    clean = strip_code(text)
    return bool(_OPEN.search(clean) and _BODY.search(clean))


def assistant_texts(transcript_path: str) -> list:
    """Return the combined text of each assistant message, in transcript order."""
    out = []
    try:
        with open(transcript_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if rec.get("type") != "assistant":
                    continue
                msg = rec.get("message", {})
                if msg.get("role") != "assistant":
                    continue
                parts = [
                    block.get("text", "")
                    for block in msg.get("content", [])
                    if isinstance(block, dict) and block.get("type") == "text"
                ]
                out.append("\n".join(parts))
    except OSError:
        return []
    return out


def trailing_malformed_count(texts: list) -> int:
    """Count consecutive malformed assistant turns from the end of the list.
    0 means the latest assistant turn is clean (nothing to recover)."""
    n = 0
    for text in reversed(texts):
        if is_malformed(text):
            n += 1
        else:
            break
    return n


# Kept deliberately terse and imperative. A Stop-hook `reason` is fed back to the
# model as feedback; a long, explanatory reason makes the model emit a confirming
# preamble ("court回避のため、正しい接頭辞でツールを呼び出します。") before the
# call — itself a malformed-call risk factor per the output-format rule. A short
# command carries the fix without inviting that narration.
REASON = (
    "[court-detect] Your last tool call was malformed (missing the antml: prefix) "
    "and was NOT executed. Re-emit only the corrected tool call — no preamble."
)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    transcript_path = data.get("transcript_path") or ""
    if not transcript_path:
        sys.exit(0)

    depth = trailing_malformed_count(assistant_texts(transcript_path))
    # depth == 0: the latest turn is clean — let the stop proceed.
    # depth >= MAX_MALFORMED_RETRIES: we have already forced enough resends; give
    # up so a model that keeps malforming cannot loop forever.
    if depth == 0 or depth >= MAX_MALFORMED_RETRIES:
        sys.exit(0)

    # A Stop block delivers `reason` to the model (additionalContext is not
    # surfaced on block), so the instruction lives solely in `reason`.
    print(json.dumps({
        "decision": "block",
        "reason": REASON,
    }, ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    main()
