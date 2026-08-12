# SwiftBar — active-Desktop indicator in the macOS menu bar, for the yabai
# trial. yabai ships no bar, and the numbered Desktops the keymap addresses are
# otherwise only visible by entering Mission Control.
#
# Deliberately a menu-bar *item*, not a bar: SwiftBar adds a status item to the
# menu bar macOS already draws, where sketchybar would replace the bar wholesale.
# That is a desktop-environment decision on its own merits (the Noctalia-parity
# question, ADR-036) and is not being pre-empted by a trial indicator.
#
# The agent starts the app through `open -a`, NOT by exec'ing the binary under
# launchd. The refresh path depends on the `swiftbar://` URL scheme, which
# LaunchServices registers when the bundle is *opened*; exec'ing
# Contents/MacOS/SwiftBar starts the process without that registration and the
# push refresh silently stops working. `open` returns as soon as the app is
# launched, so the agent is RunAtLoad-only with no KeepAlive to respawn against.
#
# The push itself is a yabai `space_changed` signal declared in
# modules/darwin/yabai.nix — see the comment there for why it lives on that side.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  yabai = lib.getExe pkgs.yabai;
  jq = lib.getExe pkgs.jq;

  # `.60s.` is a backstop, not the refresh mechanism: the signal drives updates
  # on every space change, and this only bounds staleness if that path breaks
  # (a yabai restart drops signals until yabairc re-runs). SwiftBar takes the
  # plugin name from the filename up to the first dot — `space` — which is what
  # the refresh URL addresses.
  pluginName = "space.60s.sh";

  plugin = pkgs.writeShellScript "swiftbar-space" ''
    # `// "?"` guards the query returning nothing at all, which happens in the
    # window between yabai's launchd job starting and it answering on its socket.
    idx=$(${yabai} -m query --spaces --space 2>/dev/null | ${jq} -r '.index // "?"')
    cnt=$(${yabai} -m query --spaces --display 2>/dev/null | ${jq} 'length')

    echo "⬢ ''${idx:-?}"
    echo "---"
    echo "Desktop ''${idx:-?} of ''${cnt:-?}"
    echo "Refresh | refresh=true"
  '';
in
{
  home.packages = [ pkgs.swiftbar ];

  # Symlinked into a real $HOME directory rather than pointed at a store path:
  # SwiftBar watches its plugin directory for changes and marks plugins
  # executable, neither of which it can do inside the read-only store.
  xdg.dataFile."swiftbar-plugins/${pluginName}".source = plugin;

  targets.darwin.defaults."com.ameba.SwiftBar" = {
    PluginDirectory = "${config.xdg.dataHome}/swiftbar-plugins";

    # Sparkle self-update is off because it cannot work here and is not inert
    # while it fails: it installs by replacing the .app bundle, which lives
    # read-only in the store. The attempt surfaces a modal update dialog, and
    # one of those took the status item down on 2026-08-12 at 15:08 — the app
    # kept running and the plugin kept exiting 0, only the menu-bar item was
    # gone, recoverable solely by relaunching. The version is nixpkgs' to
    # choose, where it is pinned, reviewed, and rolled back with everything
    # else.
    SUEnableAutomaticChecks = false;
    SUAutomaticallyUpdate = false;
  };

  launchd.agents.swiftbar = {
    enable = true;
    config = {
      ProgramArguments = [
        "/usr/bin/open"
        "-a"
        "${pkgs.swiftbar}/Applications/SwiftBar.app"
      ];
      RunAtLoad = true;
    };
  };

}
