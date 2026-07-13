# AI coding agents — base set: Claude Code + Cursor.
# See docs/decisions/ADR-008-agent-clis.md for rationale.
#
# Imported by every host via the standard home-manager imports list.
# Hosts that also want Codex + Antigravity CLI add agent-clis-extras.nix via
# hostContext.extraHomeModules — split per ADR-020's host-divergences-via-
# import-splits convention. Work-only hosts (Mercury) keep only the base.
#
# Both tools authenticate via OAuth login flows on first run:
# `claude login` and cursor-agent's login flow. No sops-managed API keys
# needed — pre-flight verified each tool's primary auth path. If
# non-interactive automation later requires env-var API keys, the
# env-var-via-sops pattern sketched in ADR-008 (sops.secrets file at
# /run/secrets/<name>, sourced by fish shellInit) is the documented
# fallback.
#
# Unfree: cursor-cli is whitelisted in modules/shared/nix-daemon.nix's
# allowUnfreePredicate (alongside claude-code).
{
  pkgs,
  lib,
  ...
}:
let
  ansi = import ../../lib/ansi.nix;
  # Classic SGR foreground escape for an ANSI-16 name: `\033[Nm` where N is
  # 30–37 for normal slots or 90–97 for bright. Bash $'...' quoting decodes
  # `\033` to ESC at runtime; the sequence stays textually readable in the
  # generated file for easy debugging.
  fgEscape = name: "\\033[${toString (ansi.fgCode name)}m";

  operator = import ../../lib/operator.nix;

  # The account email → short-label map the Claude statusline sources,
  # generated from lib/operator.nix's identities so the mapping is
  # single-sourced with the git author identities (#339, retiring the two
  # hardcoded emails in the statusline's account case). Emits a
  # `statusline_account_label` shell function; an unknown email passes
  # through as itself (visibly unmapped, never silently wrong), matching
  # the prior hand-written case. Patterns are escapeShellArg-quoted so an
  # email is matched literally. Claude-only — cursor has no account segment.
  statuslineIdentities = pkgs.writeText "statusline-identities.sh" (
    lib.concatStringsSep "\n" (
      [
        "# Generated from lib/operator.nix identities — see home/shared/agent-clis.nix."
        "# Maps a Claude account email to its short label (#339); unknown → raw email."
        "statusline_account_label() {"
        "  case \"$1\" in"
      ]
      ++ lib.mapAttrsToList (
        _: id: "  ${lib.escapeShellArg id.email}) printf '%s' ${lib.escapeShellArg id.label} ;;"
      ) operator.identities
      ++ [
        "  *) printf '%s' \"$1\" ;;"
        "  esac"
        "}"
        ""
      ]
    )
  );

  # Eight statusline colour bindings — ANSI-16 slot-relative so they follow
  # the terminal palette on a conductor flip (ADR-041). Role assignment:
  # blue/green/yellow/red/magenta/cyan on their canonical slots; orange
  # (no ANSI slot) → bright-yellow (attention role, nearest on-bus);
  # muted → bright-black. Dual roles unchanged: ORANGE is untracked +
  # Opus label; TEAL is branch + Sonnet label. See ADR-024 §Implementation.
  statuslineColours = pkgs.writeText "statusline-colours.sh" ''
    # Classic ANSI-16 SGR foreground codes — slot-relative, follow the
    # terminal palette on a conductor flip (ADR-041). See ADR-024 §Implementation.
    BLUE=$'${fgEscape "blue"}'
    GREEN=$'${fgEscape "green"}'
    YELLOW=$'${fgEscape "yellow"}'
    RED=$'${fgEscape "red"}'
    MAUVE=$'${fgEscape "magenta"}'
    ORANGE=$'${fgEscape "bright-yellow"}'
    TEAL=$'${fgEscape "cyan"}'
    MUTED=$'${fgEscape "bright-black"}'
  '';
in
{
  home = {
    packages = with pkgs; [
      claude-code
      cursor-cli
      # `session-type` on PATH for the Claude/Cursor statuslines, which are
      # static files that call it by name. See home/shared/session-type.nix.
      (callPackage ./session-type.nix { })
    ];

    # Custom statusline — see ADR-024 (Claude side) and
    # docs/agents/cursor-statusline.md (Cursor side). Colours use
    # ANSI-16 slot references (ADR-041) via the shared statusline-colours.sh
    # derivation sourced at startup. DIM and RST (style codes, not colours)
    # remain hardcoded in the scripts.
    file = {
      ".claude/statusline.sh" = {
        source = ./claude-statusline.sh;
        executable = true;
      };
      ".claude/statusline-colours.sh".source = statuslineColours;
      # Shared rendering core (static) + the generated identity map, sourced
      # by the Claude statusline (#339).
      ".claude/statusline-lib.sh".source = ./statusline-lib.sh;
      ".claude/statusline-identities.sh".source = statuslineIdentities;
      ".cursor/statusline.sh" = {
        source = ./cursor-statusline.sh;
        executable = true;
      };
      ".cursor/statusline-colours.sh".source = statuslineColours;
      # Same shared rendering core; cursor sources no identity map (no
      # account segment).
      ".cursor/statusline-lib.sh".source = ./statusline-lib.sh;
    };

    # Non-destructively merge the .statusLine block into each tool's
    # config file. Both ~/.claude/settings.json and
    # ~/.cursor/cli-config.json are written-back at runtime by their
    # respective tools (auth tokens, model selection, accepted
    # permission decisions, theme prefs) so home-manager cannot fully
    # own them via home.file.text. jq sets only the .statusLine key
    # and preserves every other field; repeated runs produce identical
    # output. The `~` in the command is left literal — both tools
    # resolve it at invocation time, so the same string works on
    # Linux ($HOME=/home/dbf) and Darwin ($HOME=/Users/dbf).
    #
    # Race window: if the tool is actively running and writes a fresh
    # snapshot between our jq read and the atomic rename, that write is
    # lost. nh switch is operator-driven and rare; accepting the window
    # over more complex coordination. See GH #172 and ADR-024.
    #
    # Corrupt-JSON guard (#342): these files are runtime-owned, so a tool
    # crash mid-write can leave invalid JSON. jq then can't parse it — we
    # warn-and-skip (leave the file for the tool to regenerate) rather
    # than leave a stray .tmp behind or silently no-op.
    activation.agentStatuslineSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for pair in \
        "$HOME/.claude/settings.json:~/.claude/statusline.sh" \
        "$HOME/.cursor/cli-config.json:~/.cursor/statusline.sh"
      do
        file="''${pair%%:*}"
        script="''${pair#*:}"
        run mkdir -p "$(dirname "$file")"
        if [[ -v DRY_RUN ]]; then
          echo "would set .statusLine in $file"
        else
          [ -f "$file" ] || echo '{}' > "$file"
          if ${pkgs.jq}/bin/jq --arg cmd "$script" \
            '.statusLine = {type: "command", command: $cmd}' \
            "$file" > "$file.tmp"; then
            mv "$file.tmp" "$file"
          else
            rm -f "$file.tmp"
            warnEcho "agent-clis: $file is not valid JSON; skipping .statusLine merge (the owning tool will regenerate it)."
          fi
        fi
      done
    '';
  };
}
