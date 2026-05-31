# Terminal multiplexer — zellij.
# See docs/decisions/ADR-004-multiplexer.md for rationale, and GH #5 for
# the agentic-workflow layout + ergonomics plan implemented here.
#
# Default zellij settings already pass OSC52 escape sequences through to
# the terminal emulator (see ADR-011), so no custom clipboard config is
# needed here. Mosh (modules/nixos/mosh.nix) handles network-blip
# resilience; zellij handles cross-reboot persistence — they're
# complementary.
#
# The `agent` layout (agent.kdl below) plus the `za` abbreviation in
# home/shared/shell.nix are the only path into the 3-pane agentic
# workspace; plain `zellij` stays a vanilla single-pane session.
_: {
  programs.zellij = {
    enable = true;

    settings = {
      # Default 10k lines is too small for verbose agent output — keep a
      # deep scrollback so a long agent run stays fully reviewable.
      scroll_buffer_size = 100000;
      # Explicit: frames stay on for every pane, so the named-pane headers
      # read `agent`/`yazi`/`terminal` rather than the underlying command.
      pane_frames = true;
      # Survive zellij crashes / `nh os switch` restarts — both the session
      # and each pane's viewport are restorable after a kill.
      session_serialization = true;
      pane_viewport_serialization = true;
    };

    # Keybinds live in raw KDL rather than `settings.keybinds`: the
    # `Run`-with-floating and repeated `bind` nodes don't round-trip
    # cleanly through home-manager's attrset→KDL generator (duplicate node
    # names, node-arg-plus-block shapes). extraConfig is appended verbatim
    # to config.kdl; these binds are additive to zellij's defaults.
    #   Alt+g / Alt+d — floating lazygit / lazydocker, scoped to the
    #     focused pane's cwd; close_on_exit avoids an `(exited)` corpse.
    #   Alt+e — drop the current pane's scrollback straight into $EDITOR
    #     (helix, per ADR-005) for capture/annotation.
    extraConfig = ''
      keybinds {
          shared_except "locked" {
              bind "Alt g" {
                  Run "lazygit" {
                      floating true
                      close_on_exit true
                  }
              }
              bind "Alt d" {
                  Run "lazydocker" {
                      floating true
                      close_on_exit true
                  }
              }
              bind "Alt e" { EditScrollback; }
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
  # `za` opens the workspace *here*. The two `swap_tiled_layout`s give
  # Alt+[ / Alt+] monocle toggles (full-screen agent or full-screen yazi);
  # per zellij's swap-layouts grammar, each holds a `tab` wrapping the
  # bare pane — a bare `pane` directly under `swap_tiled_layout` fails to
  # parse ("Unknown layout node: 'pane'").
  xdg.configFile."zellij/layouts/agent.kdl".text = ''
    layout {
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

        swap_tiled_layout name="agent-monocle" {
            tab {
                pane focus=true name="agent"
            }
        }

        swap_tiled_layout name="yazi-monocle" {
            tab {
                pane name="yazi" {
                    command "yazi"
                }
            }
        }
    }
  '';
}
