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

  # SwiftBar builds its plugin list at launch and drops a plugin when the file
  # disappears, without re-adding it when a replacement appears. Home-manager
  # never edits in place — every activation that changes home-manager-files
  # deletes and recreates this symlink against a new store path — so without
  # this the indicator dies on essentially every `nh darwin switch` and stays
  # dead. Verified on-box: neither `swiftbar://refreshallplugins` nor
  # `refreshplugin` recovers it; only a relaunch rebuilds the list.
  #
  # Ordered after `linkGeneration` (home-manager modules/files.nix:187), not
  # merely after `writeBoundary` — linkGeneration is itself an entryAfter
  # writeBoundary, so anchoring there leaves the two unordered and the restart
  # could race the symlink it exists to react to.
  #
  # `pgrep` guards the quit because `quit app` will *launch* a non-running app
  # just to quit it; the wait loop stops `open` racing an app still tearing
  # down, and is bounded so a wedged quit cannot hang activation.
  home.activation.restartSwiftBar = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if /usr/bin/pgrep -xq SwiftBar 2>/dev/null; then
      run /usr/bin/osascript -e 'quit app "SwiftBar"' || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        /usr/bin/pgrep -xq SwiftBar 2>/dev/null || break
        sleep 0.2
      done
    fi
    run /usr/bin/open -a ${pkgs.swiftbar}/Applications/SwiftBar.app
  '';
}
