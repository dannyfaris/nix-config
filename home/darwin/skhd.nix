# skhd — hotkey daemon for the yabai trial. yabai has no hotkey engine, so this
# module owns every chord AeroSpace used to own.
#
# Chords come from lib/capabilities.nix (ADR-039): `caps.skhdChords` renders one
# per darwin-realized capability, and `bodies` below supplies each command keyed
# by capability id, with a both-directions assert so a registry change moves the
# bind with it. Bodies live here rather than in the registry because every one
# resolves the yabai binary by package-derived absolute path, which the
# repo-decoupled registry (only `{ lib }`) cannot form — the same constraint that
# put the `aerospace-exec` bodies in home/darwin/aerospace.nix. Trade-off, stated:
# the registry owns the chords, not the actions, which is weaker than the
# AeroSpace arrangement where simple verbs lived in the registry too.
#
# Three skhd properties this module works around:
#
#   1. skhd execs `$SHELL -c <command>` (src/hotkey.c:103), falling back to bash
#      only when SHELL is *unset*. The operator's login shell is fish, so an
#      inherited SHELL would run this POSIX-sh keymap through fish and every
#      `while … done` body would be a silent parse error. SHELL is therefore
#      declared on the agent rather than inherited.
#   2. skhd watches its config's *realpath* (src/hotload.c:222), which under
#      home-manager is an immutable store path, so hot-reload never fires; and
#      home-manager only restarts an agent when the *plist* differs. Passing `-c`
#      puts the config's store path in the plist, so a keymap edit restarts the
#      daemon. (nix-darwin's own skhd module passes `-c` for the same reason.)
#   3. Commands inherit launchd's minimal PATH, so every binary is an absolute
#      store path.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  caps = import ../../lib/capabilities.nix { inherit lib; };

  yabai = lib.getExe pkgs.yabai;
  jq = lib.getExe pkgs.jq;
  skhd = lib.getExe config.services.skhd.package;

  # Command bodies keyed by capability id. Each must render onto ONE physical
  # line unless backslash-continued: skhd's eat_command (src/tokenize.c:44-53)
  # stops at the first un-escaped newline and parses the remainder as fresh
  # declarations.
  y = args: "${yabai} -m ${args}";
  openApp = app: "/usr/bin/open -a ${app}";

  # Edge-scroll fallthrough. `window --focus <dir>` exits non-zero at the layout
  # edge (src/message.c:918-925), so failure means "step to the adjacent space".
  # Both the step and the wrap synthesize macOS's own shortcuts rather than
  # `space --focus`, for the animation reason on focus-workspace-* below — the
  # step is the natively-enabled Move-left/right-a-space, the wrap a numbered
  # Switch-to-Desktop (Move-a-space does not wrap, so the wrap must be a jump).
  #
  # The edge is decided by comparing the *mission-control index*, never by a
  # second exit status. That mattered when the branch called `space --focus prev`
  # (which also fails on DISPLAY_IS_ANIMATING — the normal state right after any
  # switch — so a status chain intermittently teleported to the far end), and it
  # matters more now: a synthesized keystroke reports success whether or not macOS
  # acted on it, so there is no status left to chain on at all.
  #
  # Lands on the target space's last-focused window rather than its far column:
  # weaker than the AeroSpace version, which walked to the far column.
  spaceIndex = "$(${y "query --spaces --space"} | ${jq} -r .index)";
  spaceCount = "$(${y "query --spaces --display"} | ${jq} 'length')";
  edge =
    dir:
    let
      atEdge =
        if dir == "west" then
          "[ \"${spaceIndex}\" = \"1\" ]"
        else
          "[ \"${spaceIndex}\" = \"${spaceCount}\" ]";
      wrap = if dir == "west" then ''${skhd} -k "ctrl - ${spaceCount}"'' else ''${skhd} -k "ctrl - 1"'';
      step = if dir == "west" then ''${skhd} -k "ctrl - left"'' else ''${skhd} -k "ctrl - right"'';
    in
    "if ${y "window --focus ${dir}"}; then :; elif ${atEdge}; then ${wrap}; else ${step}; fi";

  # Cycle Ghostty windows in creation order, wrapping. `jq -s` slurps to `[]` on
  # empty input so `--argjson` still receives valid JSON when nothing is focused —
  # a bare `.id // 0` guards a null id, not zero inputs, and would pass "" to
  # --argjson and abort.
  cycleTerminals = lib.concatStringsSep " " [
    "${y "query --windows"} |"
    "${jq} -r --argjson cur \"$(${y "query --windows --window"} 2>/dev/null | ${jq} -s '.[0].id // 0')\""
    "'[.[] | select(.app == \"Ghostty\") | .id] | sort as $w | if ($w | length) == 0 then empty else ($w | index($cur)) as $i | if $i == null then $w[0] else $w[(($i + 1) % ($w | length))] end end' |"
    "while read -r id; do ${y "window --focus \"$id\""}; done"
  ];

  # bsp <-> stack. yabai has no accordion, so `stack` stands in for AeroSpace's
  # `layout tiles accordion`. `if/else` rather than `[ … ] && A || B`, which runs
  # B as well when A fails.
  layoutToggle = "if [ \"$(${y "query --spaces --space"} | ${jq} -r .type)\" = \"bsp\" ]; then ${y "space --layout stack"}; else ${y "space --layout bsp"}; fi";

  bodies = {
    focus-window-up = y "window --focus north";
    focus-window-down = y "window --focus south";
    focus-column-left = edge "west";
    focus-column-right = edge "east";

    move-window-up = y "window --swap north";
    move-window-down = y "window --swap south";
    move-column-left = y "window --swap west";
    move-column-right = y "window --swap east";

    overview = y "space --focus recent";
    layout-toggle = layoutToggle;
    # Native and reversible, unlike AeroSpace's one-way maximise-by-isolation.
    maximise-by-isolation = y "window --toggle zoom-fullscreen";

    # `open -na` gives a new window per invocation (and a new app instance),
    # paired with quit-after-last-window-closed in ghostty.nix.
    spawn-terminal = "/usr/bin/open -na Ghostty.app";
    cycle-terminal-windows = cycleTerminals;
    spawn-browser = openApp "\"Google Chrome\"";
    spawn-file-manager = openApp "Finder";
    open-messages = openApp "Messages";
    open-outlook = openApp "\"Microsoft Outlook\"";
    open-slack = openApp "Slack";
    open-1password = openApp "1Password";

    # null marks a mode-entry capability: skhd writes those as `chord ; mode`,
    # not `chord : command`. renderBind keys on the null, not on the id, so a
    # second mode-entry capability needs no new special case.
    service-mode = null;
  }
  // lib.listToAttrs (
    lib.concatMap (n: [
      # Synthesizes macOS's own "Switch to Desktop N" rather than calling
      # `space --focus`: yabai's SIP-free path posts dock swipes at a hardcoded
      # 9999 velocity to *skip* the slide (space_manager.c:956), and the slide is
      # wanted. Depends on nine System Settings shortcuts — docs/runbooks/yabai-trial.md.
      (lib.nameValuePair "focus-workspace-${toString n}" ''${skhd} -k "ctrl - ${toString n}"'')
      (lib.nameValuePair "move-window-to-workspace-${toString n}" (y "window --space ${toString n}"))
    ]) (lib.range 1 9)
  );

  # Registry↔body completeness, both directions (#537's pattern). A darwin-realized
  # capability with no body here would be a reserved-but-inert chord; a body with no
  # capability would be an unlinted bind. Either fails at host eval.
  capIds = lib.attrNames caps.skhdChords;
  missing = lib.subtractLists (lib.attrNames bodies) capIds;
  stray = lib.subtractLists capIds (lib.attrNames bodies);
  # An embedded newline would end the bind at skhd's eat_command and leave the
  # remainder parsed as fresh declarations — a corruption the prose above cannot
  # prevent, so it is asserted.
  multiline = lib.filter (id: bodies.${id} != null && lib.hasInfix "\n" bodies.${id}) (
    lib.attrNames bodies
  );

  renderBind =
    id:
    let
      chord = caps.skhdChords.${id};
    in
    if bodies.${id} == null then "${chord} ; service" else "${chord} : ${bodies.${id}}";

  keymap =
    lib.throwIf (missing != [ ] || stray != [ ] || multiline != [ ])
      "skhd.nix: command bodies out of sync with lib/capabilities.nix — caps missing a body: [${lib.concatStringsSep ", " missing}]; bodies with no cap: [${lib.concatStringsSep ", " stray}]; bodies containing a newline: [${lib.concatStringsSep ", " multiline}]"
      ''
        # GENERATED from lib/capabilities.nix — edit the registry, not this file.
        :: default
        :: service @

        ${lib.concatStringsSep "\n" (map renderBind capIds)}

        # Service mode — low-frequency ops, each returning to default. `balance`
        # stands in for AeroSpace's `flatten-workspace-tree`, which has no yabai
        # primitive (it equalises rather than un-nests). AeroSpace's `reload-config`
        # is dropped: the config is an immutable store path, so there is nothing to
        # reload without an activation.
        service < escape ; default
        service < r : ${y "space --balance"}; ${skhd} -k escape
        service < f : ${y "window --toggle float"}; ${skhd} -k escape
      '';
in
{
  services.skhd = {
    enable = true;
    config = keymap;
    # Flat paths: the module default points at ~/Library/Logs/skhd/, a
    # subdirectory launchd will not create. Both daemons exit(EXIT_SUCCESS) when
    # their Accessibility check fails (src/skhd.c:477-479 via src/log.h:36-44), so
    # launchd reports them healthy and launchd-failure-notifier.nix — keyed on
    # non-zero exits — stays silent. Without a log a dead daemon is
    # indistinguishable from a live one with no binds.
    errorLogFile = "${config.home.homeDirectory}/Library/Logs/skhd.err.log";
    outLogFile = "${config.home.homeDirectory}/Library/Logs/skhd.out.log";
  };

  launchd.agents.skhd.config = {
    # See header note 1 — without this the keymap runs through fish.
    EnvironmentVariables.SHELL = "/bin/sh";
    # See header note 2. mkForce because the upstream module owns this key; if a
    # future home-manager bump reshapes the agent's argv, this override wins
    # silently and would need revisiting.
    ProgramArguments = lib.mkForce [
      skhd
      "-c"
      "${config.xdg.configFile."skhd/skhdrc".source}"
    ];
    # A missing Accessibility grant is a clean exit, which KeepAlive=true would
    # respawn every ~10s — each respawn re-prompting, with no window manager up.
    KeepAlive = lib.mkForce { SuccessfulExit = false; };
  };
}
