# ADR-008: AI coding agents — Claude Code, Codex, Gemini, Cursor

**Date**: 2026-05-06
**Status**: Accepted

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
- **Gemini CLI** — "Sign in with Google" via `gemini` first-run, OAuth.
- **Cursor CLI** — login flow via the `cursor-agent` binary (note: the
  nixpkgs `cursor-cli` package installs the binary as `cursor-agent`,
  not `cursor`).

Cursor CLI is the only unfree package; it's added to the
`allowUnfreePredicate` whitelist in `modules/core/nixos/nix-daemon.nix`. Codex and
Gemini CLI are both Apache-licensed; no whitelist entries needed.

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
   `modules/core/nixos/sops.nix`.
3. In `home/core/nixos/agent-clis.nix`, add a fish `shellInit` block
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
  the always-on base in `agent-clis.nix`; Codex + Gemini CLI are
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
- ⚠ Migration trigger: a host wanting Codex *xor* Gemini (one but not the
  other). The current grouped split assumes they toggle together;
  unbundling into per-tool files (`codex.nix`, `gemini-cli.nix`) is the
  easy refactor.

## Implementation

Split across two files. The base lives in `home/core/nixos/agent-clis.nix`
and ships on every host:

```nix
{ pkgs, ... }: {
  home.packages = with pkgs; [
    claude-code
    cursor-cli
  ];
}
```

The opt-in extras live in `home/core/nixos/agent-clis-extras.nix` and ship
only on hosts that include the file in `hostContext.extraHomeModules`:

```nix
{ pkgs, ... }: {
  home.packages = with pkgs; [
    codex
    gemini-cli
  ];
}
```

(Specifically `gemini-cli`, not `gemini-cli-bin`; the source-built variant
is preferred.)

Cursor CLI is the only unfree package among the new additions. The
unfree whitelist in `modules/core/nixos/nix-daemon.nix` extends to include it
alongside the existing `claude-code` entry:

```nix
nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getName pkg) [
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
