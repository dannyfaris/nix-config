# AI coding agents — base set: Claude Code + Cursor.
# See docs/decisions/ADR-008-agent-clis.md for rationale.
#
# Imported by every host via the standard home-manager imports list.
# Hosts that also want Codex + Gemini CLI add agent-clis-extras.nix via
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
  config,
  ...
}:
let
  c = config.lib.stylix.colors;

  # Truecolor SGR foreground escape for a given base16 slot. Returns
  # the literal 4-char string `\033[38;2;R;G;Bm` — bash's $'...' ANSI-C
  # quoting decodes `\033` to the ESC byte at runtime. This differs
  # from the macchina recolour (home/nixos/macchina.nix), which
  # pre-decodes ESC at Nix eval time and interpolates it directly;
  # here we keep the escape sequence textually readable in the
  # generated file because operators may want to cat / grep / debug it.
  fgEscape =
    slot:
    "\\033[38;2;${toString c."${slot}-rgb-r"};${toString c."${slot}-rgb-g"};${toString c."${slot}-rgb-b"}m";

  # Seven statusline colour bindings derived from the host's base16
  # palette. Role → base16 slot mapping mostly follows the standard
  # base16 semantic convention (08=red, 09=orange, 0A=yellow, 0B=green,
  # 0C=cyan, 0D=blue, 0E=magenta) so the colours come out semantically
  # right regardless of which palette the host picks. ORANGE (base09)
  # was added — and untracked moved to it — so the SSH host marker
  # (MAUVE/base0E) is the only purple element on line 2; see
  # `home/shared/prompt.nix` for the matching prompt change.
  #
  # Two slots carry a deliberate dual role across the two lines:
  #   - ORANGE: untracked counter (line 2) + Opus model label (line 1)
  #   - TEAL:   branch (line 2) + Sonnet model label (line 1)
  # Both pair semantically — "attention" or "label" hues, applied to
  # similar-role elements at distinct positions across lines. Haiku
  # and unknown models render in default foreground (no SGR) — that
  # absence is itself a signal: lightweight tier, no flourish.
  # See ADR-024 §Implementation and ADR-028 slice 6 for the why.
  statuslineColours = pkgs.writeText "statusline-colours.sh" ''
    # Generated from config.lib.stylix.colors at activation time.
    # See ADR-024 §Implementation and ADR-028 slice 6 for the why.
    # Edit the role→base16-slot mapping in home/shared/agent-clis.nix.
    BLUE=$'${fgEscape "base0D"}'
    GREEN=$'${fgEscape "base0B"}'
    YELLOW=$'${fgEscape "base0A"}'
    RED=$'${fgEscape "base08"}'
    MAUVE=$'${fgEscape "base0E"}'
    ORANGE=$'${fgEscape "base09"}'
    TEAL=$'${fgEscape "base0C"}'
  '';
in
{
  home = {
    packages = with pkgs; [
      claude-code
      cursor-cli
    ];

    # Custom statusline — see ADR-024 (Claude side) and
    # docs/agents/cursor-statusline.md (Cursor side). Colours are
    # palette-driven via Stylix (ADR-028 slice 6 / issue #7); both
    # scripts source the same statusline-colours.sh derivation at
    # startup — no second palette source. DIM and RST (style codes,
    # not colours) remain hardcoded in the scripts.
    file = {
      ".claude/statusline.sh" = {
        source = ./claude-statusline.sh;
        executable = true;
      };
      ".claude/statusline-colours.sh".source = statuslineColours;
      ".cursor/statusline.sh" = {
        source = ./cursor-statusline.sh;
        executable = true;
      };
      ".cursor/statusline-colours.sh".source = statuslineColours;
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
          ${pkgs.jq}/bin/jq --arg cmd "$script" \
            '.statusLine = {type: "command", command: $cmd}' \
            "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        fi
      done
    '';
  };
}
