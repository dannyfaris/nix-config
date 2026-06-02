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
{
  inputs,
  pkgs,
  config,
  ...
}:
let
  # zjstatus WASM plugin path. Pulled from the upstream flake (see
  # rationale on the `zjstatus` input in flake.nix); the package output
  # is a directory containing `bin/{zjstatus,zjframes}.wasm`. Resolved
  # per-host via stdenv.hostPlatform.system so each host's xdg.configFile
  # references the store path for its own arch.
  zjstatusWasm = "${
    inputs.zjstatus.packages.${pkgs.stdenv.hostPlatform.system}.default
  }/bin/zjstatus.wasm";

  # Stylix base16 palette accessor — same shape used in
  # home/shared/agent-clis.nix:21. Slots are hex strings without the
  # leading `#`, so format strings interpolate as `#${c.base0D}`.
  c = config.lib.stylix.colors;
in
{
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
  #
  # `default_tab_template` restores chrome that a custom top-level-tab
  # layout otherwise skips entirely (the stock tab-bar + status-bar live
  # in the default template, not the global UI). The `tab` contents land
  # where `children` sits in the template.
  #
  # Status-bar tail: stock `zellij:status-bar` is one WASM rendering
  # both rows; the rotating "Tip:" line on row 2 can't be replaced
  # without forking. zjstatus is the configurable replacement — two
  # `size=1` panes reconstruct (a) a mode-indicator strip and (b) a
  # static training-wheels row for this repo's custom binds
  # (Alt+arrows / Alt+g / Alt+d / Alt+e — see `extraConfig` above).
  #
  # Mode badge colours follow the repo's base16 semantic convention (see
  # home/shared/agent-clis.nix:36-37): 08=red, 09=orange, 0A=yellow,
  # 0B=green, 0C=cyan, 0D=blue, 0E=magenta. RESIZE+MOVE share 09 and
  # TAB+SEARCH share 0C — modes are mutually exclusive so the visual
  # collision is acceptable; both pairs are grouped semantically
  # (layout-altering / navigation-by-selection). The training-wheels row
  # uses base04 (mid-grey) so it reads as ambient guidance, not primary
  # content.
  xdg.configFile."zellij/layouts/agent.kdl".text = ''
    layout {
        default_tab_template {
            pane size=1 borderless=true {
                plugin location="zellij:tab-bar"
            }
            children
            pane size=1 borderless=true {
                plugin location="file:${zjstatusWasm}" {
                    format_left  "{mode}"
                    mode_normal  "#[bg=#${c.base0B},fg=#${c.base00},bold] NORMAL "
                    mode_locked  "#[bg=#${c.base08},fg=#${c.base00},bold] LOCKED "
                    mode_pane    "#[bg=#${c.base0D},fg=#${c.base00},bold] PANE "
                    mode_tab     "#[bg=#${c.base0C},fg=#${c.base00},bold] TAB "
                    mode_resize  "#[bg=#${c.base09},fg=#${c.base00},bold] RESIZE "
                    mode_scroll  "#[bg=#${c.base0A},fg=#${c.base00},bold] SCROLL "
                    mode_search  "#[bg=#${c.base0C},fg=#${c.base00},bold] SEARCH "
                    mode_session "#[bg=#${c.base0E},fg=#${c.base00},bold] SESSION "
                    mode_move    "#[bg=#${c.base09},fg=#${c.base00},bold] MOVE "
                }
            }
            pane size=1 borderless=true {
                plugin location="file:${zjstatusWasm}" {
                    format_left "#[fg=#${c.base04}] Alt+←↑↓→ navigate panes   Alt+g lazygit   Alt+d lazydocker   Alt+e capture scrollback "
                }
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
