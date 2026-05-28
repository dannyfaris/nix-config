# ADR-005: Editor — helix

**Date**: 2026-05-06
**Status**: Accepted

## Context

The editor is the tool the user spends the most time in; the choice shapes
LSP setup, treesitter integration, plugin management, and downstream
keystroke ergonomics. Modal editing is table stakes for any serious editor;
LSP integration and treesitter are now baseline expectations.

The user has *conceptual* familiarity with neovim but no deep vim muscle
memory. They self-describe as a basic user who values clean, light,
out-of-the-box UX.

## Decision

The editor is **helix**, configured via `programs.helix` in home-manager
with TOML settings declared inline as a nix attrset. Nixd is the LSP for
nix files; nixfmt is the formatter, with format-on-save enabled. OSC52
clipboard wiring (`editor.clipboard-provider = "termcode"`) bridges yank
to the client terminal's clipboard (see ADR-011).

## Rationale

The candidates were neovim (with or without a curated distro like LazyVim,
optionally configured declaratively via nixvim) and helix.

**Neovim** has the largest plugin ecosystem of any editor. It is also,
out of the box, essentially nothing — you build the experience yourself,
or adopt a distro that builds it for you. Either way, the result is layered
configuration; the "minimal" path requires meaningful investment. nixvim
addresses the config-burden problem by letting you declare the entire
configuration in nix attrsets, which fits the declarative aesthetic, but
adds another abstraction (nixvim's own DSL on top of neovim's) to learn.

**Helix** is modern (Rust, ~2021), modal, and *batteries-included*. Out of
the box, with zero config, it provides:

- LSP support
- Treesitter syntax highlighting and structural editing
- Fuzzy file picker, buffer picker, symbol picker, global search
- Multi-cursor editing
- Auto-completion popup
- Inline diagnostics
- Keybind-discovery popup (which-key style, but built in)

There is no plugin system shipped (one is in development). The built-ins
cover ~80% of what most plugins are used for.

### The selection-first model

Helix's biggest philosophical difference from vim is the editing direction:

- **vim/neovim** — verb-then-noun. `dw` = "delete a word"; you describe
  the operation, then it executes. You don't see what was operated on
  until afterwards.
- **helix** — noun-then-verb. Press `w` and the next word becomes
  selected (highlighted); press `d` to delete the selection. You always
  see what you're about to act on, before you act.

Same number of keystrokes, inverted order, with constant visual feedback.
For users with deep vim muscle memory, this is a real switching cost. For
users with conceptual familiarity but no deep vim habit (the case here), the
cost of learning helix's model is roughly the same as the cost of learning
vim's model from the same starting point — and helix's model is more
visually intuitive.

### Why this fits the user's preferences

The same operating principle that selected fish (ADR-001), starship
(ADR-002), and zellij (ADR-004) selects helix here: clean, light,
batteries-included. Helix delivers a polished experience without
configuration; neovim doesn't, even with a distro (you adopt someone
else's curated complexity).

The user's lack of vim muscle memory removes the typical reason to prefer
neovim. The user's "basic user" self-description means the plugin gap is
mostly theoretical: the built-ins cover their actual needs.

For features helix lacks (rich git UI, debugger UI, in-editor AI plugins),
the workflow is: open another zellij pane, run the dedicated tool there
(lazygit for git — see ADR-006). This composes naturally with the rest of
the headless dev stack.

## Consequences

- ✓ Out-of-the-box experience matches the rest of the stack's character.
- ✓ Config is small TOML (typically <30 lines), declarative inside nix.
- ✓ Selection-first model is more visually intuitive for newcomers.
- ✓ LSP, treesitter, fuzzy pickers, multi-cursor — all built in, no plugins
  to maintain.
- ✗ No plugin ecosystem (yet). Specific niceties common in neovim (debugger
  UI integration, AI inline-completion plugins, neorg-style apps) are not
  available.
- ✗ Not vim-compatible by default. Existing vim muscle memory doesn't
  transfer cleanly. (For this user, not applicable.)
- ⚠ Migration trigger: needing in-editor AI completion (avante.nvim,
  copilot.nvim, claude-code-nvim, etc.) that doesn't compose with the
  "open another zellij pane" pattern. Helix has no plugin system to host
  these.
- ⚠ Migration trigger: needing a debug adapter (DAP) UI integrated with
  the editor — a workflow neovim's nvim-dap covers and helix doesn't.
- ⚠ Migration trigger: regular SSH access to machines that have vim or
  neovim available but not helix, where editing in those sessions becomes
  enough of the workflow to justify shared muscle memory.

## Implementation

Configured in `home/core/shared/editor.nix`:

```nix
let
  flakePath = "/home/dbf/nix-config";
  hostName = "nixos-vm";
in {
  programs.helix = {
    enable = true;

    settings = {
      theme = "<chosen at first use>";
      editor = {
        line-number = "relative";
        bufferline = "multiple";
        lsp.display-messages = true;
        clipboard-provider = "termcode";   # OSC52 — see ADR-011
      };
    };

    # Tell nixd how to evaluate this flake's option schema. Without this,
    # nixd does only syntax-level analysis; with it, hovers on option
    # attributes (users.users.dbf.shell, programs.git.settings.user.name,
    # etc.) show their type and description.
    languages.language-server.nixd = {
      command = "nixd";
      config.nixd.options = {
        nixos.expr = ''(builtins.getFlake "${flakePath}").nixosConfigurations.${hostName}.options'';
        home-manager.expr = ''(builtins.getFlake "${flakePath}").nixosConfigurations.${hostName}.options.home-manager.users.type.getSubOptions []'';
      };
    };

    languages.language = [{
      name = "nix";
      auto-format = true;
      formatter.command = "${lib.getExe pkgs.nixfmt}";
      language-servers = [ "nixd" ];
    }];
  };
}
```

Notes:

- `programs.helix.languages.language` is a **list of attribute sets** (not
  a single attrset). The shape above is the correct one.
- `lib.getExe pkgs.nixfmt` resolves to the absolute binary path,
  surviving any future binary-rename in nixpkgs.
- `nixd` LSP and `nixfmt` formatter are installed by `home/core/shared/nix-tooling.nix`
  (ADR-007); helix invokes them through PATH.
- The nixd `options.{nixos,home-manager}.expr` strings are passed through
  to nixd verbatim; nixd evaluates them at hover-time. The flake path
  (`/home/dbf/nix-config`) and host name (`nixos-vm`) are hardcoded
  via the `let` bindings — when this repo moves (Tier 5 x86_64 host with
  a different path or hostname), update both `flakePath` and `hostName`.
- LSPs for non-nix languages live in per-project `flake.nix` devShells, not
  in home-manager — direnv (ADR-003) makes them available when entering a
  project directory.
- Arrow keys work fine in helix; the user is free to use them indefinitely
  or transition to `hjkl` at their own pace. Both are first-class.

**`EDITOR` wiring (two-layer).** Interactive user shells get
`home.sessionVariables.{EDITOR,VISUAL} = "hx";` from
`home/core/shared/editor.nix` itself. System-mediated tools
(`sudoedit`, `visudo`, `systemctl edit`) get
`environment.variables.{SUDO_EDITOR,SYSTEMD_EDITOR} = "${pkgs.helix}/bin/hx";`
from a dedicated `modules/core/shared/editor-defaults.nix` imported via
`foundation.nix`. The system layer uses absolute store paths because
sudo strips `PATH` from the inherited environment. `VISUAL` complements
`EDITOR` for tools (notably git) that check `VISUAL` first.
`programs.helix.defaultEditor = true;` was rejected — it only sets
`EDITOR`, not `VISUAL`. The system-layer module lives in `shared/`
because `environment.variables` is shared-name between NixOS and
nix-darwin; ready for Darwin onboarding without duplication.
