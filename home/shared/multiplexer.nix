# Terminal multiplexer — zellij.
# See docs/decisions/ADR-004-multiplexer.md for rationale, and GH #5 for
# the agentic-workflow layout + ergonomics plan implemented here.
#
# Default zellij settings already pass OSC52 escape sequences through to
# the terminal emulator (see ADR-011), so no custom clipboard config is
# needed here. zellij handles session persistence across disconnects
# (reconnect over SSH, then `zellij attach`). (mosh was removed in #47.)
#
# The `agent` layout (agent.kdl below) plus the `za` function in
# home/shared/shell.nix are the only path into the 3-pane agentic
# workspace; plain `zellij` stays a vanilla single-pane session.
{
  pkgs,
  config,
  lib,
  zellijCacheDir,
  ...
}:
let
  c = config.lib.stylix.colors;

  # Palette pulled straight from the active Stylix scheme so the zjstatus
  # top bar (agent.kdl below) stays cohesive even though stylix.targets
  # .zellij doesn't reach a third-party plugin (it themes the stock
  # status-bar + pane frames; zjstatus reads these hex values directly).
  # Roles mirror the starship prompt and Claude statusline so the bar reads
  # as a third surface of the same language: host green/purple by SSH
  # state, session blue (the prompt's `$directory` slot), git "on" muted +
  # branch cyan, status counts !conflict red / +staged green / ~modified
  # yellow / ?untracked orange, clock foreground. (base0B green / base0E
  # purple / base0D blue / base0C cyan /
  # base0A yellow / base09 orange / base08 red / base05 fg / base03 muted —
  # same slots as prompt.nix / claude-statusline.sh.)
  greenHex = "#${c."base0B-hex"}";
  purpleHex = "#${c."base0E-hex"}";
  blueHex = "#${c."base0D-hex"}";
  cyanHex = "#${c."base0C-hex"}";
  yellowHex = "#${c."base0A-hex"}";
  orangeHex = "#${c."base09-hex"}";
  redHex = "#${c."base08-hex"}";
  fgHex = "#${c."base05-hex"}";
  mutedHex = "#${c."base03-hex"}";

  # Glyphs decoded from codepoints (fromJSON `"\uXXXX"`) — same ASCII-safe
  # pattern and same codepoints as prompt.nix / claude-statusline.sh.
  desktopGlyph = builtins.fromJSON ''"\uf108"''; # nf-fa-desktop — local
  sshGlyph = builtins.fromJSON ''"\uf489"''; # nf-mdi-console_network — SSH

  chevGlyph = builtins.fromJSON ''"\u276f"''; # ❯ host->session separator (prompt.nix's chev)
  branchGlyph = builtins.fromJSON ''"\ue0a0"''; # nf-pl-branch, matches claude-statusline.sh

  zjstatus = "${pkgs.zellijPlugins.zjstatus}"; # output IS the .wasm file

  # Shared local-vs-SSH detector — the same command the prompt and
  # statuslines use. Reads the live client's connection so the host marker
  # is correct after a zellij detach/reattach across contexts (#270). See
  # home/shared/session-type.nix.
  sessionType = pkgs.callPackage ./session-type.nix { };

  # Permission grant block for zjstatus, in zellij's permissions.kdl format
  # and keyed by the bare store path exactly as zellij caches it. Pre-seeded
  # by home.activation below (see the rationale there). Leading newline so
  # appending it can never fuse onto a prior block.
  zjstatusGrant = pkgs.writeText "zjstatus-permissions.kdl" (
    "\n"
    + ''
      "${zjstatus}" {
          ChangeApplicationState
          ReadApplicationState
          RunCommands
      }
    ''
  );

  # zjstatus runs widget commands *not* in a shell, so the host marker is
  # a wrapped script (bash + PATH guaranteed) referenced below by absolute
  # store path — hence it needn't land on the user's PATH.
  #
  # Host marker — emits zjstatus `#[fg=…]` markup chosen at runtime, so
  # command_host_rendermode "dynamic" renders green + desktop glyph
  # locally and purple + console-network glyph over SSH. Connection
  # detection delegates to the shared `session-type` command, which reads
  # the live client's context — so the marker is correct after a zellij
  # detach/reattach across connection contexts (#270), not stuck on the
  # pane's frozen $SSH_CONNECTION. One of four surfaces sharing that
  # detector (prompt + Claude/Cursor statuslines are the others; ADR-002 /
  # ADR-024).
  zjstatusHostMarker = pkgs.writeShellApplication {
    name = "zjstatus-host-marker";
    # session-type does the detection; coreutils gives it `who` for the
    # non-zellij fallback (hostname resolves from ambient PATH).
    runtimeInputs = [
      sessionType
      pkgs.coreutils
    ];
    text = ''
      if [ "$(session-type)" = ssh ]; then
        printf '#[fg=%s,bold]%s  %s' '${purpleHex}' '${sshGlyph}' "$(hostname -s)"
      else
        printf '#[fg=%s,bold]%s  %s' '${greenHex}' '${desktopGlyph}' "$(hostname -s)"
      fi
    '';
  };

  # Git marker — branch + per-category status counts for the workspace
  # repo (the session launch dir; interval-polled below, so agent edits
  # and branch-switches surface). Emits its own leading separator and
  # zjstatus `#[fg=…]` markup (rendermode "dynamic"), so when the launch
  # dir isn't a repo it prints nothing and contributes no gap — no
  # reliance on zjstatus's undocumented hide-on-empty flag. The counts use
  # the exact symbols, colours, porcelain categorisation and render order
  # of the Claude statusline (`!conflict +staged ~modified ?untracked`,
  # each shown only when non-zero) so the three surfaces speak one visual
  # language. Branch cyan; detached HEAD shows `@<sha>`. Deliberately no
  # ahead/behind — parity with the prompt/statusline, which omit it.
  zjstatusGit = pkgs.writeShellApplication {
    name = "zjstatus-git";
    runtimeInputs = [ pkgs.git ];
    text = ''
      # Repo guard first: statusline_git_state's rev-parse read would trip
      # this widget's `set -e` in a non-repo dir, so exit before the shared
      # parser runs where its reads can't succeed.
      git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

      # Shared git-state parser (home/shared/statusline-lib.sh) — the single
      # home for the porcelain counter the two statuslines also use (#339,
      # retiring this third hand-mirrored copy). Sets BRANCH / HEAD_REF /
      # CONFLICT / STAGED / MODIFIED / UNTRACKED for $PWD; this widget keeps
      # its own zjstatus-markup renderer below (its dialect + Nix-interpolated
      # hex are a different harness — the parser is the drift-prone part).
      # shellcheck source=/dev/null
      source ${./statusline-lib.sh}
      statusline_git_state "$PWD"

      # On a real branch, prefix a dim "on" (like the statusline). Detached
      # HEAD shows just `@<sha>` with no "on" — "on @sha" reads oddly, and
      # the statusline drops it there too.
      on=""
      if [ -n "''${BRANCH}" ]; then
        branch="''${BRANCH}"
        on="#[fg=${mutedHex}]on "
      elif [ -n "''${HEAD_REF}" ]; then
        branch="@''${HEAD_REF}"
      else
        exit 0
      fi

      # Mirrors claude-statusline.sh's git segment: dim "on" (real branch
      # only), cyan branch glyph + name, then the counts (same symbols/
      # colours/order).
      out=" ''${on}#[fg=${cyanHex}]${branchGlyph} $branch"
      [ "''${CONFLICT}" -gt 0 ] && out="$out #[fg=${redHex}]!''${CONFLICT}"
      [ "''${STAGED}" -gt 0 ] && out="$out #[fg=${greenHex}]+''${STAGED}"
      [ "''${MODIFIED}" -gt 0 ] && out="$out #[fg=${yellowHex}]~''${MODIFIED}"
      [ "''${UNTRACKED}" -gt 0 ] && out="$out #[fg=${orangeHex}]?''${UNTRACKED}"
      printf '%s' "$out"
    '';
  };

  # Path marker — the basename of the session launch dir (zjstatus runs
  # command widgets in that cwd, like the git marker above). Renders in the
  # bar's directory slot in place of `{session}`, which is host-prefixed —
  # see ADR-004 §Session naming.
  zjstatusPath = pkgs.writeShellApplication {
    name = "zjstatus-path";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      basename "$PWD"
    '';
  };

  ghDashEnabled = config.programs.gh-dash.enable;
  zellijAgentHelpLines = [
    ""
    "        Agent layout — keys"
    ""
    "          Alt+← ↑ ↓ →     navigate panes"
    "          Alt+g           lazygit (floating)"
    "          Alt+d           lazydocker (floating)"
  ]
  ++ lib.optional ghDashEnabled "          Alt+r           gh-dash (floating)"
  ++ [
    "          Alt+e           capture scrollback to $EDITOR"
    "          Alt+k           this help"
    ""
    "        Press any key to dismiss."
    ""
  ];
  zellijAgentHelpScript = builtins.concatStringsSep "\n" (
    [ "cat <<'EOF'" ]
    ++ zellijAgentHelpLines
    ++ [
      "EOF"
      "read -r -n1 -s"
      ""
    ]
  );
  ghDashKeybind = lib.optionalString ghDashEnabled (
    builtins.concatStringsSep "\n" [
      "              bind \"Alt r\" {"
      "                  Run \"gh-dash\" {"
      "                      floating true"
      "                      close_on_exit true"
      "                      width \"85%\""
      "                      height \"85%\""
      "                      x \"7%\""
      "                      y \"7%\""
      "                  }"
      "              }"
      ""
    ]
  );

  # Floating cheatsheet for the agent layout's custom tool/help binds.
  # Invoked from Alt+k via the `Run … floating true` pattern (same shape
  # as the floating tool binds below). Mod+k as the help binding mirrors a
  # convention already familiar from other tools, so no on-screen
  # discovery hint is needed in the layout itself.
  zellijAgentHelp = pkgs.writeShellApplication {
    name = "zellij-agent-help";
    text = zellijAgentHelpScript;
  };
in
{
  home.packages = [ zellijAgentHelp ];

  programs.zellij = {
    enable = true;

    settings = {
      # Built-in ANSI-16 theme (ships in zellij, indices 0–15 only) —
      # chrome renders from the terminal palette, following polarity flips
      # and SSH context (terminal-authority direction). Replaces the
      # Stylix zellij target, which shadowed the built-in `default` theme
      # by name with baked hex. The zjstatus bar formats above remain
      # hex — their ANSI conversion is #411.
      theme = "ansi";
      # Default 10k lines is too small for verbose agent output — keep a
      # deep scrollback so a long agent run stays fully reviewable.
      scroll_buffer_size = 100000;
      # Explicit: frames stay on for every pane, so the named-pane headers
      # read `agent`/`yazi`/`terminal` rather than the underlying command.
      pane_frames = true;
      # Serialization OFF: resurrecting the agent layout degrades it — the
      # bare-shell `agent`/`terminal` panes die on reboot and collapse the
      # split to a lone suspended `yazi`, which self-perpetuates. See ADR-004.
      session_serialization = false;
      pane_viewport_serialization = false;
      # zellij's enhanced Kitty Keyboard Protocol handling misbehaves on
      # foot — it leaks the agent-layer Alt-key binds straight through to the
      # inner pane instead of acting on them, and drops Shift+Return en route
      # to agent CLIs. Disabling drops zellij to legacy key encoding, which
      # fixes both. Applied fleet-wide, not just on foot: legacy is the
      # universally-supported baseline (this config's binds are all bare
      # Alt+letter, which it handles fine), so it can't regress the other
      # hosts' terminals. Upstream: zellij #3723.
      # NOTE: "Requires restart" — a live session won't re-read this.
      support_kitty_keyboard_protocol = false;
    };

    # Keybinds live in raw KDL rather than `settings.keybinds`: the
    # `Run`-with-floating and repeated `bind` nodes don't round-trip
    # cleanly through home-manager's attrset→KDL generator (duplicate node
    # names, node-arg-plus-block shapes). extraConfig is appended verbatim
    # to config.kdl; these binds are additive to zellij's defaults.
    #   Alt+g / Alt+d — floating lazygit / lazydocker, scoped to the
    #     focused pane's cwd; close_on_exit avoids an `(exited)` corpse.
    #     Sized 85% centred (x/y 7%) — the default float is too cramped.
    #   Alt+r — floating gh-dash (mnemonic: PR/review dashboard), same
    #     geometry, gated to hosts where gh-dash is enabled. Bare Alt-letter
    #     that's free in both zellij and fish (Alt+s is fish's prepend-sudo);
    #     see ADR-006.
    #   Alt+e — drop the current pane's scrollback straight into $EDITOR
    #     (helix, per ADR-005) for capture/annotation.
    #   Alt+k — floating cheatsheet for these custom binds (zellij-agent-help
    #     script defined in the `let` block above).
    extraConfig = ''
            keybinds {
                // Tabs are unused in the agent workflow (one workspace per
                // session) and the zjstatus bar renders no tab list, so make
                // tab creation unreachable. `NewTab` exists only inside Tab mode
                // and tmux mode, whose sole entry keys are Ctrl+t and Ctrl+b —
                // unbinding both seals every path, including the indirect
                // tmux → "," (rename) → Esc → Tab mode → "n" back-door, because
                // rename mode is itself only reachable from those two modes
                // (verified via `zellij setup --dump-config`). Side effect: the
                // tmux-compat keytable goes with it, which this zellij-native
                // setup doesn't use. The custom tool/help binds below live in
                // `shared_except "locked"`, unaffected.
                unbind "Ctrl t" "Ctrl b"

                shared_except "locked" {
                    bind "Alt g" {
                        Run "lazygit" {
                            floating true
                            close_on_exit true
                            width "85%"
                            height "85%"
                            x "7%"
                            y "7%"
                        }
                    }
                    bind "Alt d" {
                        Run "lazydocker" {
                            floating true
                            close_on_exit true
                            width "85%"
                            height "85%"
                            x "7%"
                            y "7%"
                        }
                    }
      ${ghDashKeybind}              bind "Alt e" { EditScrollback; }
                    bind "Alt k" {
                        Run "zellij-agent-help" {
                            floating true
                            close_on_exit true
                        }
                    }
                }
            }
    '';
  };

  # The agent workspace: agent CLI (fish — pick the agent per session per
  # ADR-008) left 50%; yazi top-right; terminal (fish) bottom-right.
  # zellij sizes are relative to the parent container, so the 60/40 split
  # of the 50% right column lands yazi at 30% and terminal at 20% of the
  # screen (the split #5 asked for). No `cwd` anywhere — every pane
  # inherits the directory `zellij --layout agent` was launched from, so
  # `za` opens the workspace *here*. No swap layouts — full-screen monocles
  # weren't useful, and swap layouts can't substitute a pane's command
  # (they only rearrange existing panes), so tool-switching stays on the
  # floating Alt+g/Alt+d binds above.
  #
  # `default_tab_template` restores chrome that a custom top-level-tab
  # layout otherwise skips entirely (the bars live in the default
  # template, not the global UI). The `tab` contents land where
  # `children` sits in the template.
  #
  # Top bar: zjstatus (not the stock `zellij:tab-bar`) so the left side
  # can carry host+SSH marker, the workspace path, and the repo's git
  # state — none of which the stock bar exposes. `format_left` is the host
  # widget + `{command_path}` (launch-dir basename) + the git widget — the
  # path, not `{session}`, because the session name is host-prefixed (see
  # ADR-004 §Session naming). `format_right` is just a 12-hour NZ clock. No
  # `{tabs}` widget — tabs are deliberately out (see the `unbind "Ctrl t"`
  # above).
  #
  # Widget cadence: host interval "2" (poll — SSH-state is NOT fixed for a
  # session's life: it flips on a zellij detach/reattach across contexts
  # (#270); session-type is cheap, and its own 2s cache stacks with this
  # poll so a reattach flip surfaces within ~4s). Git interval "2"
  # (poll so agent edits and
  # branch-switches show). Both render "dynamic" so the `#[fg=…]` markup
  # the scripts emit is rendered as colour. Path interval "10" (the launch
  # dir is fixed for a session's life, so it barely needs re-polling) and
  # rendermode "static" — it emits plain text, coloured by the leading
  # `#[fg=…]` in format_left. The clock is the native
  # `{datetime}` widget, timezone-pinned so it reads NZ time even on
  # mercury (EC2, non-NZ region).
  #
  # Bottom bar unchanged: the stock `zellij:status-bar` is a single WASM
  # rendering two rows (mode-indicator + keybind hints on top, rotating
  # "Tip:" on bottom), so its pane stays `size=2` — less clips the hints.
  # Custom binds from `extraConfig` (tool/help shortcuts) live in the Alt+k
  # cheatsheet, not the layout chrome.
  xdg.configFile."zellij/layouts/agent.kdl".text = ''
    layout {
        default_tab_template {
            pane size=1 borderless=true {
                plugin location="file:${zjstatus}" {
                    format_left  " {command_host} #[fg=${fgHex}]${chevGlyph} #[fg=${blueHex}]{command_path}{command_git}"
                    format_right "{datetime}"
                    format_space ""

                    command_host_command    "${zjstatusHostMarker}/bin/zjstatus-host-marker"
                    command_host_format     "{stdout}"
                    command_host_rendermode "dynamic"
                    command_host_interval   "2"

                    command_path_command    "${zjstatusPath}/bin/zjstatus-path"
                    command_path_format     "{stdout}"
                    command_path_rendermode "static"
                    command_path_interval   "10"

                    command_git_command    "${zjstatusGit}/bin/zjstatus-git"
                    command_git_format     "{stdout}"
                    command_git_rendermode "dynamic"
                    command_git_interval   "2"

                    datetime          "#[fg=${fgHex}]{format}"
                    datetime_format   "%I:%M%P"
                    datetime_timezone "Pacific/Auckland"
                }
            }
            children
            pane size=2 borderless=true {
                plugin location="zellij:status-bar"
            }
        }

        tab name="agent" {
            pane split_direction="vertical" {
                pane size="50%" focus=true name="agent"
                pane size="50%" split_direction="horizontal" {
                    pane size="60%" name="yazi" {
                        command "yazi"
                    }
                    pane size="40%" name="terminal"
                }
            }
        }
    }
  '';

  # zjstatus is a third-party plugin, so zellij withholds rendering until
  # its permissions are granted — and that grant prompt can't be answered
  # in the agent layout's 1-row borderless bar pane, so the bar just renders
  # blank (the stock bars work only because built-in plugins are
  # pre-granted). Pre-seed the grant so the bar works on first launch after
  # a switch, on every host, with no interactive dance. zellij caches grants
  # keyed by the plugin's bare store path in permissions.kdl under its
  # cache dir (macOS Caches bundle dir / XDG cache on Linux). Append-if-
  # missing keeps the file mutable (zellij still writes it when you grant
  # other plugins) and preserves those grants; a zjstatus version bump
  # changes the path and appends a fresh block, leaving the old one as
  # harmless dead cruft. The `>>` lives inside `sh -c` so home-manager's
  # dry-run run-wrapper doesn't perform the write.
  home.activation.zellijZjstatusPermission =
    let
      # zellij's cache dir is platform-specific; the path is injected by
      # the per-platform home-manager wiring (modules/{nixos,darwin}/
      # home-manager.nix's extraSpecialArgs) so this shared module stays
      # platform-pure (shared-purity lint).
      permFile = "${zellijCacheDir}/permissions.kdl";
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      permFile="${permFile}"
      if ! grep -qsF "${zjstatus}" "$permFile"; then
        run mkdir -p "$(dirname "$permFile")"
        run sh -c 'cat "$1" >> "$2"' sh "${zjstatusGrant}" "$permFile"
      fi
    '';
}
