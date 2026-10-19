#!/usr/bin/env python3
"""PreToolUse/Bash gate: force an approval prompt before any git command that
creates, deletes, or pushes a tag.

Tagging is a publish step — it is how a release becomes visible to anything
downstream — so it always needs an explicit human yes, never an inherited
allow rule. Tag *reads* (bare `git tag`, -l/--list, -n, --contains, --merged,
--points-at, -v/--verify, ...) are read-only and stay silent.

The command is shell-tokenized and split on control operators, so each git
invocation is judged on its own: `git tag -l && git tag v1` still prompts,
`git commit -m "bump before git tag"` does not. Subshells (`$(...)`, backticks)
and `sh -c '...'` strings are scanned recursively. If the command can't be
tokenized (e.g. an unbalanced quote in a heredoc), the offending line falls
back to a coarse text match and prompts when in doubt.

Deliberately not filtered with `if: "Bash(git *)"`: that prefix does not match
chained commands such as `cd /repo && git tag v1.0`, which must still prompt.
So this runs on every Bash call and decides here.

Exit 0 with no stdout = no opinion, normal permission flow continues.
"""
import json
import re
import shlex
import sys

SEPARATORS = {";", "&", "&&", "|", "||", "|&", "(", ")", "`", "\n"}

# git global options that take a separate value: `git -C /repo tag v1`.
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
                       "--config-env", "--super-prefix"}

# Any of these puts `git tag` in list mode; positionals become patterns.
TAG_READ_FLAGS = ("-l", "--list", "-n", "--contains", "--no-contains",
                  "--merged", "--no-merged", "--points-at", "-v", "--verify")
# Flags that take a separate value which must not be mistaken for a tag name.
TAG_OPTS_WITH_VALUE = {"--sort", "--format", "--cleanup", "-m", "-F", "-u",
                       "--message", "--file", "--local-user"}

# Refspec side that names a tag: refs/tags/..., or a version like v1.2 / 1.2.3.
TAG_REF = re.compile(r"^(refs/tags/|v?\d+(\.\d+)*([-+.].*)?$)")


def tokenize(text):
    lex = shlex.shlex(text, posix=True, punctuation_chars=";&|()`<>")
    lex.whitespace = " \t\r"  # keep newlines as command separators
    lex.whitespace_split = True
    return list(lex)


def segments(tokens):
    seg = []
    for tok in tokens:
        if tok in SEPARATORS or tok.startswith(("&", "|", ";")):
            if seg:
                yield seg
            seg = []
        else:
            seg.append(tok)
    if seg:
        yield seg


def tag_writes(args):
    if not args:
        return False
    positional = False
    skip = False
    for arg in args:
        if skip:
            skip = False
            continue
        if arg == "--":
            positional = True
            break
        if arg.startswith(TAG_READ_FLAGS):
            return False
        if arg in ("-d", "--delete", "-a", "-s", "-f", "--force",
                   "--annotate", "--sign"):
            return True
        if arg in TAG_OPTS_WITH_VALUE:
            skip = True
            continue
        if arg.startswith("-"):
            continue
        positional = True
    return positional


def push_tags(args):
    for arg in args:
        if arg in ("--tags", "--follow-tags", "--mirror", "tag"):
            return True
        if arg.startswith("-"):
            continue
        for side in arg.lstrip("+").split(":"):
            if side and TAG_REF.match(side):
                return True
    return False


def git_subcommand(seg, i):
    """Return (subcommand, args) for the git invocation at seg[i]."""
    j = i + 1
    while j < len(seg) and seg[j].startswith("-"):
        j += 2 if seg[j] in GIT_OPTS_WITH_VALUE else 1
    if j >= len(seg):
        return None, []
    return seg[j], seg[j + 1:]


def check_segment(seg):
    for i, tok in enumerate(seg):
        if tok == "git" or tok.endswith("/git"):
            sub, args = git_subcommand(seg, i)
            if sub == "tag" and tag_writes(args):
                return "creates or deletes a git tag"
            if sub == "push" and push_tags(args):
                return "pushes a git tag"
    return None


def check(text, depth=0):
    if depth > 5:
        return None
    try:
        tokens = tokenize(text)
    except ValueError:
        if "\n" in text:
            for line in text.split("\n"):
                why = check(line, depth + 1)
                if why:
                    return why
            return None
        if re.search(r"\bgit\b.*\b(tag|push)\b", text):
            return "may create, delete, or push a git tag (could not parse)"
        return None

    for seg in segments(tokens):
        why = check_segment(seg)
        if why:
            return why
        # Recurse into quoted strings that are themselves commands.
        for k, tok in enumerate(seg):
            nested = ("$(" in tok or "`" in tok
                      or (k > 0 and seg[k - 1] == "-c" and " " in tok))
            if nested:
                inner = tok.replace("$(", " ( ").replace("`", " ` ")
                why = check(inner, depth + 1)
                if why:
                    return why
    return None


def main():
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command") or ""
    why = check(cmd)
    if not why:
        return
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": f"Release gate: this {why}. Tagging "
                                    "publishes a release and always needs "
                                    "explicit approval.",
    }}))


if __name__ == "__main__":
    main()
