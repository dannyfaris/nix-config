# ADR-008: AI coding agents — Claude Code, Codex, Antigravity, Cursor

**Date**: 2026-05-06
**Status**: Accepted

> **Revision (2026-06-05):** stale module paths in this ADR were swept to the
> current flat layout (`home/core/…` → `home/…`, `modules/core/…` → `modules/…`)
> per [ADR-026](./ADR-026-drop-core-tier-prefix.md), which dropped the `core/`
> tier prefix. Navigability fix only — the decision recorded here is unchanged.

> **Revision (2026-06-24):** Gemini CLI is replaced by the **Antigravity CLI** (`pkgs.antigravity-cli`, binary `agy`) in the opt-in extras. Google announced this on 2026-05-19 ([developers.googleblog.com](https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/)): it is folding Gemini CLI into Antigravity and on 2026-06-18 retired the free / AI Pro / Ultra hosted backend that served Gemini CLI — the consumer tier this config authenticated against via "Sign in with Google". (Issue #433's "June 17" is that retirement, off by one.) Antigravity CLI keeps the same Google-OAuth auth shape, so the OAuth-not-sops decision below stands and this ADR is amended in place rather than superseded; only the roster member swaps. Antigravity CLI is unfree, so it joins the `allowUnfreePredicate` whitelist alongside `cursor-cli` (Gemini CLI was Apache-2.0 and needed no entry). Headless/API-key auth for `agy` is an open upstream request (antigravity-cli#78); not a blocker here, since the only headless host (Mercury) omits these extras and the four extras hosts each reach a browser-or-URL OAuth flow. See #433. Body references below are updated to the current roster; the original 2026-05-06 pre-flight notes about Gemini CLI are retained as history.

## Context

The user actively uses four AI coding agent CLIs across different
workflows: Claude Code (Anthropic), Codex CLI (OpenAI), Gemini CLI
(Google), and Cursor CLI. They're not seeking to converge on one — each
serves a distinct role in their toolkit, and the headless dev tier should
make all four available.

The implementation question is auth handling: the original plan assumed
each agent would use an env-var API key managed via sops-nix. Pre-flight
verification of upstream auth conventions changed that assumption.

## Decision

All four agent CLIs are installed at the home-manager level. Auth is via
**OAuth login flows** for all four, not env-var API keys. Consequently, no
sops-nix integration is needed for these tools.

- **Claude Code** — `claude login` (existing pattern, unchanged).
- **Codex** — "Sign in with ChatGPT" via `codex` first-run, OAuth.
- **Antigravity CLI** — "Sign in with Google" via `agy` first-run, OAuth
  (replaced Gemini CLI; see the 2026-06-24 revision above).
- **Cursor CLI** — login flow via the `cursor-agent` binary (note: the
  nixpkgs `cursor-cli` package installs the binary as `cursor-agent`,
  not `cursor`).

Cursor CLI and Antigravity CLI are the unfree packages; both are in the
`allowUnfreePredicate` whitelist in `modules/shared/nix-daemon.nix`. Codex is
Apache-licensed; no whitelist entry needed. (Antigravity CLI replaced the
Apache-2.0 Gemini CLI — see the 2026-06-24 revision above.)

## Rationale

Pre-flight verification (recorded in
`agent_clis_implementation_notes.md` in memory) confirmed:

- Codex's primary auth path per its README is "Sign in with ChatGPT". The
  `OPENAI_API_KEY` env-var path is documented as a secondary option ("you
  can also use Codex with an API key").
- Gemini CLI's primary auth path is "Sign in with Google". `GEMINI_API_KEY`
  / `GOOGLE_API_KEY` are alternatives.
- Claude Code already uses an OAuth credential file (existing config).
- Cursor CLI follows the same pattern (login flow producing a credential
  file).

When all four tools default to OAuth-credential-file auth, the original
plan's conditional ("API-key tools → sops; OAuth tools → no sops needed")
resolves to "no sops needed for any of them". This is a pre-flight-driven
simplification consistent with the spirit of the plan.

The user's earlier decision had been: "if we do need to manage Auth, we
will do so via sops-nix" — conditional. The pre-flight resolved the
condition to "we don't need to" for these tools.

If the user later wants API-key auth (e.g., for non-interactive
automation, CI-style workflows on the dev box), the env-var-via-sops
pattern can be added as a follow-up. The mechanism would be:

1. Add `openai_api_key` (or whichever) to `secrets/secrets.yaml` via
   `sops`.
2. Declare `sops.secrets.openai_api_key.owner = "dbf"` in
   `modules/nixos/sops.nix`.
3. In `home/shared/agent-clis.nix`, add a fish `shellInit` block
   that reads the file and exports the env var:
   ```fish
   if test -r /run/secrets/openai_api_key
     set -gx OPENAI_API_KEY (cat /run/secrets/openai_api_key)
   end
   ```

The plaintext is read at shell start — never present in the nix store.

This is documented here as the future path; not implemented now.

## Consequences

- ✓ Substantially simpler implementation than the originally-planned sops
  setup. Fewer moving parts.
- ✓ Each tool's own auth flow is the supported one — fewer "weird config
  for headless usage" surprises.
- ✓ Credentials live in each tool's own state dir
  (`~/.config/...` typically), where the user's existing tools already
  store theirs.
- ✓ The set is split along a host-policy axis: Claude Code + Cursor are
  the always-on base in `agent-clis.nix`; Codex + Antigravity CLI are
  opt-in via `agent-clis-extras.nix`, applied on hosts that want the
  broader set. Work-only hosts (e.g. Mercury) get only the base,
  reflecting the work environment's narrower vendor scope. The split
  follows ADR-020's host-divergences-via-import-splits convention.
- ✗ First-time login on this box is interactive (browser device flow or
  callback) — not declarative. Same character compromise as `gh auth
  login` and `glab auth login` (ADR-009).
- ✗ Non-interactive contexts (e.g., a hypothetical cron job invoking
  Codex without a logged-in session) wouldn't work without further setup.
  Not a concern given current use is interactive.
- ⚠ Migration trigger: a workflow that requires non-interactive agent
  invocation. At that point, add the env-var-via-sops pattern (sketched
  above).
- ⚠ Migration trigger: an agent CLI changing its auth model. If that
  happens, this ADR gets superseded by a new one with the actual
  implementation.
- ⚠ Migration trigger: a host wanting Codex *xor* Antigravity CLI (one but
  not the other). The current grouped split assumes they toggle together;
  unbundling into per-tool files (`codex.nix`, `antigravity-cli.nix`) is the
  easy refactor.

## Implementation

Split across two files. The base lives in `home/shared/agent-clis.nix`
and ships on every host:

```nix
{ pkgs, ... }: {
  home.packages = with pkgs; [
    claude-code
    cursor-cli
  ];
}
```

The opt-in extras live in `home/shared/agent-clis-extras.nix` and ship
only on hosts that include the file in `hostContext.extraHomeModules`:

```nix
{ pkgs, ... }: {
  home.packages = with pkgs; [
    codex
    antigravity-cli
  ];
}
```

(`antigravity-cli` ships the `agy` binary as a vendor prebuilt for all four
platforms — no Darwin-side source-build override is needed, unlike `codex`.)

Cursor CLI and Antigravity CLI are the unfree packages. The unfree whitelist
in `modules/shared/nix-daemon.nix` lists both alongside the existing
`claude-code` entry:

```nix
nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getName pkg) [
    "antigravity-cli"
    "claude-code"
    "cursor-cli"
  ];
```

First-time auth on the dev box is interactive, per tool. Each tool's
first invocation prompts a login flow. The user runs each once after the
first rebuild lands these packages.

If the agent in a future Claude Code session needs to advise on usage,
remember the user has all four available — no need to push a particular
one.
