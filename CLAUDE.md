# CLAUDE.md

Guidance for Claude Code when working in this repo.

## What this is

A single POSIX shell script (`statusline-command.sh`) that Claude Code invokes
on every UI render. It reads a JSON status payload on stdin and writes one
ANSI-styled line to stdout: model · context bar · directory · git · docker.

`install.sh` deploys the script to `~/.claude/statusline-command.sh` and wires
it into `~/.claude/settings.json` under the `statusLine` key.

## Hard constraints

- **POSIX sh, not bash.** Shebang is `#!/bin/sh`. No `[[ ]]`, no `$'...'`, no
  arrays, no `local`. Use `printf` instead of `echo -e`. Parameter expansion
  patterns must work in dash.
- **Performance matters.** The script runs on every render. Each subprocess
  (`jq`, `git`, `docker`, `stat`) costs a fork+exec. Don't add fork-heavy
  steps without caching them.
- **Output is one line, no trailing newline.** Final `printf` must not end
  with `\n` — Claude Code appends its own framing.

## Input JSON shape

Fields the script reads from stdin (all optional, defaults in the jq block):

```
.cwd
.model.display_name
.context_window.context_window_size
.context_window.used_percentage
.context_window.current_usage.input_tokens
.context_window.current_usage.cache_creation_input_tokens
.context_window.current_usage.cache_read_input_tokens
.context_window.current_usage.output_tokens
```

`used_percentage` may be a float — `| floor` in jq keeps shell arithmetic
safe. `cwd` may be empty for non-project sessions; git/docker sections must
degrade silently.

## Cache layout

- Directory: `/tmp/claude-statusline-<uid>/`
- TTL: `CACHE_TTL=3` seconds
- Files:
  - `git-<cksum-of-cwd>` — 4 lines: branch, dirty_count, ahead, behind
  - `docker` — single integer: running container count
- `file_age()` uses `stat -c %Y` (GNU) with `stat -f %m` fallback (BSD/macOS).
- If `mkdir -p` fails, `cache_dir` is blanked and the script still works
  uncached.

The 3s TTL is the deliberate tradeoff: invisible staleness, no fork storm.
Don't lower it without measuring.

## ANSI handling

Colors are pre-expanded once at the top (`ESC=$(printf '\033')`) and used as
plain string variables with `printf '%s'`. Do **not** reintroduce `printf
'%b'` — it interprets backslashes in arbitrary values (branch names,
directory names) and is the bug the rewrite fixed.

## Testing

Pipe a representative payload to the script and eyeball the output:

```sh
echo '{"cwd":"/tmp","model":{"display_name":"Claude Opus 4.7"},"context_window":{"context_window_size":200000,"used_percentage":42,"current_usage":{"input_tokens":10000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":60000,"output_tokens":2000}}}' \
  | ./statusline-command.sh; echo
```

To see live changes inside Claude Code, copy the repo file over the installed
one (settings.json already points there):

```sh
cp statusline-command.sh ~/.claude/statusline-command.sh
```

Benchmark before/after when touching the hot path:

```sh
/usr/bin/time -f "%es" sh -c 'for i in $(seq 1 10); do echo "$INPUT" | ./statusline-command.sh > /dev/null; done'
```

## Editing notes

- Don't add new top-level dependencies. Keep the requirements list as-is:
  `jq` required; `git`, `docker` optional and gated by `command -v`.
- New sections should respect the `SEP` separator pattern and be hidden when
  empty (no dangling separators).
- If a feature needs config, prefer an env var with a safe default (e.g.
  `CSL_SOMETHING=0` to disable) — there's no config file.
