---
name: porting-legacy-challenges
description: >-
  Port pwn.college challenges/modules from the legacy/OLD pwnshop engine to this
  repo's modern templated style, or audit such a port ("does this PR properly port
  X?"). Use when migrating a module out of `challenges/legacy/`, converting OLD
  pwnshop `Challenge` classes + Jinja templates into modern `challenge/` +
  `tests_private/` templates, reproducing a legacy challenge as a build-time-compiled
  SUID template + deterministic solver, or converting legacy-IMAGE re-home wrappers
  into native in-repo builds. Covers hard-won mechanics: keep the challenge IDENTICAL
  (only seed-derived variants differ); the seeded-determinism pattern linking body
  and solver; Jinja/pwnshop gotchas; validating linchpin templates before fan-out;
  git-crypt-encrypting tests_private; module/dojo wiring (module.yml, interleaved
  `resources:`, per-challenge DESCRIPTION.md); making tests_public verify real
  functionality; fake-pass detection (passed != solved); flaky/timing-test
  reliability; local gdb debugging. Complements `authoring-challenges`.
---

# Porting legacy challenges to the modern style

This is the workflow + the non-obvious mechanics for taking a module that exists only as
the OLD pwnshop engine (or as prebuilt binaries under `challenges/legacy/`) and
re-expressing it as modern, build-time-rendered challenges that pass `pwnshop test`.
Every rule below is here because skipping it cost real rework in a previous port. Also
read the **`authoring-challenges`** skill — it owns the per-archetype mechanics
(Dockerfiles, SUID/exec-suid, `win()`, `common/` templates); this skill owns the
*porting* workflow and the *template-determinism* pattern.

## 0. Orient — find all three sources before writing anything

A legacy port has three inputs. Locate each:

1. **The OLD engine** (the source of truth for *behavior*): pwnshop `Challenge` subclasses
   + their Jinja templates, e.g. `OLD/pwncollege-modules/.../<module>/__init__.py` (classes)
   + `<module>/*.c` / `*.py` (templates) + `OLD/pwnshop/.../templates/base/base.c`. Each
   class sets attributes that drive the template; each class's **`verify()` method is the
   real solve** — it is your test.
2. **The OLD descriptions / dojo** (the source of *learner-facing text*): e.g.
   `OLD/intro-to-cybersecurity-dojo/<module>/<id>/DESCRIPTION.md`, `module.yml` (challenge
   order, names, per-challenge pwnshop class + `attributes`), `.init`, helper scripts.
3. **The legacy validation target** (the *challenge set* to match, and reference solvers):
   `challenges/legacy/.../<module>/` — the auto-imported version (prebuilt binaries +
   `tests_private/test_solve.py`). Enumerate its challenge dirs; that is exactly the set
   you must produce. Its `test_solve.py` files are working (if hacky) reverse-engineering
   solvers you can adapt.

Map every challenge dir to its OLD pwnshop class and `attributes` (from `module.yml`), and
note which are presentation variants of one "level" (e.g. `-python`, `-c`, x86-no-source
share one config). **Placement:** a modern standalone module goes at `challenges/<module>/`
(mirroring how `web-security` was migrated out of `legacy/intro-to-cybersecurity/`), not in
`challenges/legacy/`.

## 1. THE CARDINAL RULE — do not change the challenge

The single biggest mistake is "improving" the challenge while porting. **The binary's
behavior, the file/protocol format, the win conditions, any byte/size budgets, and the
flag-delivery mechanism MUST match the OLD engine exactly.** What may differ: the
*seed-derived per-build details* — magic bytes, version numbers, dimensions, colors,
positions, randomized opcodes. "The same seed may produce a different variant" — that, and
only that, is your freedom. Concretely, in one port these were all *wrong* and had to be
reverted: changing an internal struct representation (a reverser sees a different binary),
simplifying a generated asset, recomputing fixed byte budgets, and swapping a font-rendered
flag for plain text. When in doubt, transcribe the OLD template faithfully (rename
`challenge.X` → your namespace `c.X`, inline the base template's `main`/`win`) rather than
re-deriving. The *solver* in your test is free to use any valid approach; the *challenge*
is not.

## 2. The modern architecture & the determinism pattern (the "template stuff")

Modern challenges are rendered at build time, not shipped as prebuilt binaries. The
linchpin: a challenge's **body** (the rendered binary/script) and its **solver** (the test)
must agree on every seeded value — the body bakes the magic/dims/etc. into the binary; the
test crafts an input that must match. They stay in lock-step because:

> `tools/pwnshop/src/pwnshop/lib/__init__.py` renders **each `.j2` file with a fresh
> `random.Random(CHALLENGE_SEED)`** (constant seed, env `CHALLENGE_SEED`, default 0). So if
> the body and the test run the **same config draws first, in the same order**, they get
> **identical** values.

The pattern that exploits this (and the recommended structure):

- **Per-challenge config is inlined** in the challenge's own `challenge/cimg.c.j2` (and its
  `tests_private/test_solve.py.j2`, and any `generate_flag_image.j2`): a few
  `{% set c.* %}` lines + calls to shared helpers, then `{% include "common/<body>.j2" %}`.
  The config block is **duplicated body↔test on purpose** — the test must rebuild the same
  values. They can't silently drift: same seed + same draws ⇒ same values, and any mismatch
  fails that challenge's own test immediately.
- **Shared algorithms** (image generation, byte-budget computation, the C/py body itself,
  the solve helpers) live in `common/<module>_lib.j2` and `common/<body>.j2`. These are
  genuinely reusable; they are *not* per-challenge config.
- The shared body/test templates **consume a pre-built `c` from include context** — they do
  NOT build it. The leaf builds `c` and `{% include %}`s them.

This mirrors how web-security keeps `flask.py.j2` and `test_exploit.py.j2` in sync via
`generate_names(challenge, random)` called first in both. **Alternative** (only if you
can't re-derive — e.g. an opaque prebuilt asset): the test reverse-engineers the actual
binary (objdump/strings/parse-source), like the legacy universal solvers. It's robust to
any seed but fragile and verbose — prefer seed re-derivation.

See `references/template-recipes.md` for copy-paste minimal leaf/body/test files and the
exact helper-macro shapes (`defaults`, `draw_magic`, namespace mutation, etc.).

## 3. Jinja + pwnshop gotchas (each one bit a real port)

- **No `trim_blocks`/`lstrip_blocks`.** pwnshop passes them as render *variables*, not
  `Environment` options, so they do nothing — `{% if %}` lines leave blank lines. Don't
  fight it for `.c`/`.py`: **clang-format/black reformat the rendered output** (`.c` via
  clang-format, `.py` when `.py` is in the suffixes *or* the first line contains
  `python`). For `.j2` library/config files (imported, not formatted), control whitespace
  with `{%- … -%}`.
- **Shebang must be physical line 1.** Put all `{%- import/set -%}` directives *before* the
  shebang line (each trimmed to emit nothing). If a `{%-` immediately follows the shebang,
  it eats the shebang's trailing newline and merges it into the next content — a Python
  script then has a broken/garbage shebang and `python3` runs *piped stdin as code* (a
  baffling REPL-ish failure). Mirror it: directives first, then `#!`.
- **`{% include %}` passes context; `{% import %}` does NOT.** Compose with
  `{% set var = … %}{% include "…" %}` so the included template sees your vars and the
  `random` global. For `{% import … as lib %}`, pass everything the macro needs as
  arguments (it won't see your context); a macro using the seeded RNG must take `random` as
  a parameter.
- **Relative paths resolve against the importing file**, not the repo root
  (`RelativeEnvironment.join_path` = `normpath(parent.parent / template)`). From
  `<chal>/challenge/x.j2` use `../../common/y.j2`; from `<chal>/tests_private/x.j2` also
  `../../common/y.j2`. An absolute-from-`challenges/` path will be mis-joined.
- **Dynamic import in a macro works and stays deterministic:**
  `{% import "levels/" ~ level ~ ".j2" as lvl %}{{ lvl.configure(c, random) }}` — but a
  template that is *both* rendered (emits output) and *imported* will double-execute its
  top-level draws on import (desync). Keep importable config in macros only.
- **Namespace mutation propagates through macros** (the `generate_names(ns, random)`
  idiom): a macro that does `{% set ns.attr = … %}` mutates the caller's `namespace()`.
  This is how one `setup`/`configure` call configures both body and test.
- **List element assignment** has no syntax — use `{% set _ = lst.__setitem__(i, v) %}`.
  Call a side-effecting macro for its mutation via `{% set _ = lib.helper(c, random) %}`.
- **No `ord`/`bytes.fromhex` filters.** Precompute an ord-map dict in the macro, or do the
  arithmetic (`48 + n // 100` for an ASCII digit). Emit bytes as a C array
  `{ {{ ints|join(', ') }} }` (bulletproof, identical compiled output) rather than a C
  string literal (escaping `\`, `"`, `\x1b`+digit is a minefield).

## 4. Build the linchpin first, then fan out

The shared `common/` templates are a tight coupling: if they're wrong, all N challenges
fail. Author them, then **validate ONE challenge end-to-end with real Docker before
generating the rest** — this proves the include-composition, the seed determinism, the
compile+SUID pipeline, and the test harness at once. Extend the C/py body family-by-family,
re-validating as you add each feature (framebuffer, directives, sprites, …) — debugging a
500-line Jinja-C template only at the simplest level is a trap. Generate the many small leaf
dirs with a shell/python loop, not by hand. Subagents can author files but usually cannot
run `pwnshop test` (no dev-shell Docker), so **validation is serial and yours.**

## 5. Tests = ported `verify()` (standalone executables)

- A test file is a **standalone executable** matched by glob `test*/test_*`, run via
  `docker exec --user=1000:1000`. Needs a shebang **and** `chmod +x` (mode is preserved
  from the `.j2`). **Pass = exit 0.** A raised `assert`/exception (Python) or `set -e` +
  failing `grep` (shell) signals failure.
- **The `FLAG` env var is NOT reliably set.** Don't `os.environ["FLAG"]`. The flag is a
  random `pwn.college{…}` written to `/flag` (root 0400). Match it in output:
  `re.search(r"pwn\.college\{[^}\n]+\}", out)` or `grep -oE 'pwn\.college\{[^}]+\}'`.
  Printing the matched flag also marks the challenge "solved" (the harness checks the flag
  string appears in output).
- Port each OLD `verify()` faithfully: it built its input from `self.<attrs>` (the same
  seeded values) and asserted the flag appeared — your test rebuilds them via the shared
  config and does the same. `tests_public/` = a benign functionality smoke test (no flag);
  `tests_private/` = the real solve.
- Watch the multi-presentation refactor trap: if a solver hardcodes its level, its *test
  leaf* may carry no `cimg_level` — a script that keys off `cimg_level` will skip it and
  leave it without a configured `c`. Verify every body **and** test renders with `c`
  defined.

## 6. Extract assets the OLD source doesn't ship

Legacy challenges often depend on things provisioned by the base image, not the module
source (fonts, tools, data files). If `find OLD -iname …` comes up empty, pull it from the
legacy image:
`nix develop -c bash -c 'docker run --rm pwncollege/challenge-legacy:latest <cmd>'` — e.g.
the `figlet -fascii9` font turned out to be `/usr/share/figlet/ascii9.tlf`, shipped by the
apt package **`toilet-fonts`** (md5-verify against the image; prefer depending on the
package over vendoring the file).

## 7. Encrypt `tests_private` (per-module git-crypt key)

Solves ship encrypted, like every other module. After the module passes:
```
git-crypt init -k <module>
printf '**/tests_private/** filter=git-crypt-<module> diff=git-crypt-<module>\n' > challenges/<module>/.gitattributes
git add challenges/<module>/.gitattributes && git add --renormalize challenges/<module>/   # encrypts the blobs
```
Grant the maintainers in `maintainers.yml` (root/connor/yan): import each pubkey from that
file, then `git-crypt add-gpg-user -k <module> --no-commit --trusted <fingerprint> …`, and
`git add .git-crypt/keys/<module>/`. Verify: `git cat-file -p :<a test_solve>` starts with
`\x00GITCRYPT`, the working tree stays plaintext (key unlocked, so `pwnshop test` still
works), `tests_public`/source stay plaintext, and your key's GPG-user set matches an
existing module's exactly.

## 8. Validate — and prove refactors are safe

- `pwnshop test` runs **only inside `nix develop`**:
  `nix develop -c bash -c 'pwnshop test challenges/<module>/<chal> …'`. The wrapper script's
  exit code is not pwnshop's — grep the log for `All tests passed` / `Some tests failed`.
- Confirm **seed-robustness**: re-run the tricky levels with `CHALLENGE_SEED=42` — a
  per-build-random target with a fixed budget can be seed-sensitive.
- When refactoring the shared templates (e.g. relocating config), **prove it's
  behavior-preserving by byte-diffing renders**: `pwnshop render` the new version, `git
  stash` to the old, render again, `diff`. Byte-identical ⇒ same variant ⇒ same binary ⇒
  the (already-green) Docker result is unchanged, no re-run needed for the unchanged paths.
- Commit only when asked; on an unpushed WIP branch, `--amend` obvious fixes into the single
  module commit rather than stacking commits.

## 9. Re-homing → native: porting a legacy-IMAGE module

Some modules under `challenges/<dojo>/<module>/` are NOT OLD-engine ports — each leaf is a
thin **re-home** wrapper: `{% set challenge_image = "pwncollege/challenge-legacy:latest" %}
{% set challenge_path = "<dojo>/<module>/<id>" %}{% include "../../common/Dockerfile.j2" %}`
that pulls a prebuilt image and fetches the upstream dojo source at build time. Converting
these to native (source built in-repo) follows the cardinal rule (ship the OLD `run`/`.init`
**byte-for-byte**) plus:

- **Distrust the re-home's stated blocker.** "Privileged netns can't run under the test
  harness" is FALSE — pwnshop runs `privileged: true` challenges under the **kata runtime**
  with `--cap-add=SYS_ADMIN --cap-add=NET_ADMIN` (`lib/__init__.py` ~94–108), so dojjail/netns
  challenges run. A re-home test can also be a **fake pass**: pwnshop tracks `passed =
  returncode==0` SEPARATELY from `solved = flag in last_output` (`commands/test.py`), so an
  in-process replica hardcoding `pwn.college{dummyflag}` exits 0 yet never produces the real
  random `/flag` (watch the "Warning: unsolved challenges" line; use `--require-solved`).
  Replace replica solvers with real ones that drive `/challenge/run` and capture the real flag.
- **The OLD module Dockerfile IS the native recipe.** `OLD/<dojo>/<module>/Dockerfile` gives the
  exact base+apt+pip (e.g. `FROM python:3.13-slim`; `pip install … <dojjail github-zip> <scapy
  github-zip>`; `ADD …/exec-suid`). Mirror it in a module `common/Dockerfile.j2`, **add the
  uid-1000 `hacker` account** the harness execs as, and ship the OLD `run` (shebang
  `#!/usr/bin/exec-suid …`) + a `.init` (chmod 6755 the run; `touch /run/xtables.lock`). pwnshop
  runs `/challenge/.init` at container start unconditionally — works from any base image.
- **Re-create what the legacy image provided ambiently** (this bit four separate times in one
  module). Enumerate deps by grepping BOTH the run scripts' imports AND the tests'
  subprocess/shell-outs:
  - `ENV SHELL=/bin/bash` — dojjail `interactive()` does `environ.get("SHELL","/bin/sh")`; the
    default dash silently drops pre-fed solver input (its "can't access tty" warning is a red
    herring — not the real failure).
  - **iptables-legacy backend** — Debian's nft-backend iptables errors `Could not fetch rule set
    generation id: Invalid argument` inside the kata netns; `update-alternatives --set iptables
    /usr/sbin/iptables-legacy` (+ ip6tables).
  - **tcpdump can't drop privileges** — in the namespace the shell is a mapped root whose
    unprivileged `tcpdump` uid is unmapped, so tcpdump's default drop fails EINVAL; wrap the
    binary to force `-Z root`.
  - **`challenge.localhost` must resolve** — Flask `app.run("challenge.localhost", 80)` *binds*
    the hostname; add `127.0.0.1 challenge.localhost` to `/etc/hosts` (a `.init` line).
  - install the workspace tools the solvers shell out to (`nmap`, `script`/util-linux, `nc`,
    `tcpdump`, `sysctl`/procps).
- **Source-less leaves: rewrite from scratch.** If a leaf is image-only with NO upstream source
  or solver (e.g. `challenge-secure-chat-N`), you cannot transcribe — design a fresh, minimal,
  *escalating* series on the module's theme reusing the module `common/` build infra; one
  concept per level, each with a real seed-robust solver.
- **`pwnshop.ChallengeGroup`s ship multiple binaries** in one challenge dir (dispatch +
  vulnerable-overflow; victim + server). One Dockerfile builds all artifacts; the solver drives
  them together (e.g. use the ECB-oracle `dispatch` binary to forge blocks for the overflow).

## 10. Debug native binaries locally — skip the 10-minute Docker loop

When a native-built C challenge's exploit won't land, do NOT iterate via `pwnshop test`
(build + privileged run ≈ 10 min each). Render + compile on the host and debug with gdb:
```
nix develop -c bash -c 'pwnshop render <leaf>/challenge/x.c.j2 --output /tmp/x.c'
gcc <the leaf's exact flags: -no-pie -fno-stack-protector [-z execstack] -O0 -w …> -o /tmp/x.bin /tmp/x.c
gdb -batch -nx -iex 'set debuginfod enabled off' -ex 'run < /tmp/in' -ex 'bt' /tmp/x.bin
```
`gdb`/`objdump`/`readelf` are on the host; **pwntools is NOT** — craft inputs in plain python /
precompute shellcode bytes. For no-ASLR (personality re-exec) stack fidelity, give the local
binary a path the **same length** as the container's (`/challenge/<name>`, e.g. a 15-char
`/tmp/…`) so stack/env addresses match; a throwaway helper that `getenv()`s + prints `%p`
(with the same disable_aslr re-exec) pins the exact env-var-shellcode address. This turned six
blind 10-min Docker brutes into one gdb session that found the real bug.

**Or debug the REAL container binary directly — inject arbitrary nix tools.** `pwnshop run`'s
`--volume HOST:HOST:ro` bind-mounts a host path at the *same* location inside the challenge
container (`lib/__init__.py` ~125), so mounting the host nix store drops ANY nix app (with its
full dependency closure) into the live container:
```
gdb=$(nix develop -c command -v gdb)   # /nix/store/…-gdb/bin/gdb  (or: nix build --no-link --print-out-paths nixpkgs#gdb)
nix develop -c pwnshop run --user 0 --volume /nix/store <module>/<chal> "$gdb" /challenge/<bin>
```
Mount all of `/nix/store` (read-only, so it's a cheap bind, not a copy) so the tool's closure is
present, then run gdb/strace/ltrace/a pwntools-python/etc. on the **exact** container binary —
right gcc build, SUID, env, and runtime (incl. kata for `privileged`). Prefer this over the host
rebuild whenever the rebuild's layout or behaviour might diverge from the container's; the host
rebuild is for fast pure-exploit-logic iteration with no container at all.

## 11. Native-port solver & exploit mechanics

- **Derive, never hardcode.** A re-home solver hardcoded `WIN_ADDR=0x4013b6` — dead on a native
  rebuild. Read `win`/symbols via `readelf -sW`, the buffer offset from `lea -0xN(%rbp)` and the
  frame from `sub $N,%rsp` via `objdump`. Prefer **spray** (`p64(win)*K`) and **NOP-sled + stack
  brute** over coredump-based exact addresses — coredumps are blocked for SUID binaries run as
  uid 1000.
- **Per-run timeout or the brute hangs forever.** A solver that drives a no-timeout challenge in
  a loop MUST set `subprocess.run(..., timeout=N)` + catch `TimeoutExpired`; one input that makes
  the challenge loop blocks the whole brute (and the entire test times out).
- **Crypto oracle = ONE session.** A fresh process per query gets a NEW per-run/per-container key,
  so byte-at-a-time silently fails; keep one persistent process (pwntools `process`) for all
  queries.
- **Env-var shellcode must be null-free** (a null truncates the env string; pwntools
  `process(env=…)` rejects nulls outright). Hand-roll a null-free stage (`push/pop` for syscall
  numbers, `mov dh,N` for counts) when shellcraft's output contains nulls.
- **ASCII-only overflow → 2-byte partial overwrite.** If the overflow source is ASCII-checked you
  can only write printable bytes: overwrite just the saved return address's low 2 bytes (the high
  6 stay equal to the original ret, which shares the code page with `win` in a small non-PIE
  binary), and shift `win()` to a printable-low-2-byte address via tunable `bin_padding` (sweep
  the pad size, verify with `readelf`). Derive `win` + the ret offset in the solver.
- **gcc layout drifts from the legacy image** (`-O0`, ubuntu 24.04 vs the legacy gcc): a fixed
  stack buffer can land mid-frame with the record/loop-counters ABOVE it (in the overflow path),
  so the copy/overflow loop overwrites its own bounds/counters and runs wild — the OLD exploit
  relied on the buffer being at the top of the frame. Faithful fix (NOT a challenge change): move
  the copy/overflow loop into a **`noinline` helper taking the bounds BY VALUE** so a
  caller-frame overflow can't perturb the loop's own locals, and do any post-overflow stores
  BEFORE the overflow using the still-clean record.

## 12. Port the whole module, not just the challenges (dojo wiring + learner text)

A "port" that compiles every binary but drops the curriculum scaffolding is incomplete. Each
of these recurred as a **blocking audit finding** — a green `pwnshop test` does not catch them:

- **A module needs its own `module.yml` or it renders EMPTY.** `dojo.yml` only *lists* module
  ids; `tools/dojo/parse-dojo-yml … --json` reads each module's `module.yml` for its contents,
  and a missing one parses as **zero levels** — every challenge silently vanishes from the dojo
  even though the dirs exist and test green. After wiring, run the parser and confirm the level
  count for each module.
- **`module.yml` carries the lectures/headers/markdown too, not just the challenge list.**
  Transcribe the OLD module's `resources:` (lecture video/slides ids, `type: header` section
  titles, prose) — dropping them loses the teaching material the port is supposed to preserve.
- **Interleave everything in ONE ordered `resources:` list.** The parser concatenates *all*
  `resources:` entries, *then* all `challenges:` entries (`parse-dojo-yml` ~268–312), so
  splitting headers into `resources:` and levels into a separate `challenges:` key bunches every
  header at the top, detached from the challenges it was meant to precede. Put lectures, headers,
  **and** challenges (as `type: challenge` entries with an `id`) all in the single `resources:`
  list, in display order. `cryptography/module.yml` and `web-security/module.yml` show the shape.
- **Descriptions fall back to `DESCRIPTION.md`.** If a `type: challenge` resource has no inline
  `description`, the parser fills it from that challenge's `DESCRIPTION.md`; the module's own
  `description` falls back to the module-level `DESCRIPTION.md` (`parse-dojo-yml` ~284, ~306,
  ~317). So a module with a module-level DESCRIPTION.md can omit `description:`, and per-challenge
  entries can omit it as long as each leaf ships its own `DESCRIPTION.md`.
- **Port every per-challenge `DESCRIPTION.md` byte-for-byte.** These are trivially forgotten —
  one pass shipped 21 binary-exploitation levels + `cryptography/xor` with none. Diff the ported
  text against OLD; they must match (only seed-derived variants may differ, and descriptions are
  not seeded).
- **Moving a module changes its path everywhere.** Relocating a top-level module under a dojo dir
  (e.g. `web-security/` → `intro-to-cybersecurity/web-security/`) breaks both `../../common`
  relative paths inside its templates *and* stale example paths in `README.md` / `docs/` /
  `AGENTS.md` / `CLAUDE.md`. Grep for the old path and fix both.

## 13. Public tests must verify functionality, not just `ls`

`tests_public/` is the no-flag smoke test, but a stub that only `ls /challenge` proves nothing
and is itself a blocking audit finding. Drive the actual program and assert on real output. Two
output-capture gotchas that bit real ports:

- **Binary stdout breaks pwnshop's capture.** pwnshop captures test output as UTF-8; a program
  that emits raw bytes (e.g. a 32-byte ECB ciphertext from a `dispatch` oracle) corrupts the
  stream and fails the test for the wrong reason. Redirect the binary output to a **file** and
  read it back — don't let raw bytes hit captured stdout.
- **A fragile server dies on a connect-then-close poll.** A C server that double-writes its error
  path and never `signal(SIGPIPE, SIG_IGN)`s is *killed* by a bare `connect()`-then-close
  readiness probe (the close triggers SIGPIPE mid-write). Wait for readiness by retrying a **real
  request** (a full GET that you read a response to), and expect a post-response RST.

## 14. Auditing a port — review the whole thing, not just that tests pass

When asked "does this PR properly port X?", check **completeness**, because green tests miss most
of the gaps above. The dimensions real audits flagged, as a checklist:

1. **Coverage:** challenge-dir count matches the OLD set; every dir has `challenge/Dockerfile.j2`.
2. **Wiring:** every module in `dojo.yml` has a `module.yml`; `tools/dojo/parse-dojo-yml … --json`
   shows the expected level count; `resources:` preserves the OLD lectures/headers (§12).
3. **Learner text:** each challenge has its OLD `DESCRIPTION.md` (byte-diff vs `OLD/`).
4. **Private tests really solve, not just exit 0:** `nix develop -c pwnshop test --require-solved
   <chal>`. pwnshop tracks `passed` (exit 0) separately from `solved` (the real random `/flag`
   appeared in output), so a fake/replica test that prints a dummy flag *passes* yet
   `--require-solved` reports it **unsolved** (§5, §9). This is how you catch fake-pass tests.
5. **Public tests really verify** functionality, not a placeholder `ls` (§13).
6. **Encryption:** `tests_private` blobs are git-crypt-encrypted in the index (`git cat-file -p
   :<test>` starts with `\x00GITCRYPT`).
7. **Seed-robustness:** re-run a sample with `CHALLENGE_SEED=42`.

Lead the review with the verdict (no / not-fully / yes) and the **blocking** findings first; list
positives after. Review the **committed PR state**, and note if you also checked the dirty tree.

## 15. Flaky / timing-dependent tests

- **One green run is not a fix.** Prove a flake is gone by *looping* the test (`for i in 1 2 3; do
  nix develop -c pwnshop test … ; done`) or `pwnshop test --attempts N` — a single pass is noise.
- **`--attempts N` is the robust mitigation when the variance is per-container-instance.** A
  DoS / resource-exhaustion solve's success can hinge on that kata VM instance's core count and
  sysctls (e.g. `nproc=1` + `tcp_syncookies=1`), so *in-container* retries can't escape a bad
  instance — but a fresh container (the next attempt) can. Each attempt gets a new container.
  Never fake the flag to dodge the flake; the test must still only pass on the real `/flag`.
- **Don't tune timing solves on the host.** A many-core host (even `taskset -c 0`) mispredicts the
  kata 1-core VM by ~2×; validate timing-sensitive solves **only in-container**, and accept that
  local experiments only narrow the search.
- **dojjail netns bring-up races (~15%)** and crashes fast — wrap a real `/challenge/run`-driving
  solve in a bounded retry loop so a startup race re-attempts instead of failing the test.
- **`%`-format collision in generated helper scripts.** When an outer template/string interpolates
  a generated Python helper (`helper % constants`, or an f-string/`%`-built blob), the *helper's
  own* `%d`/`%s` operators get consumed by the outer `%` and explode at render time. Escape them
  as `%%`, or build the outer layer with `str.format()` + named `{placeholders}` so the inner `%`
  formatting survives intact.
