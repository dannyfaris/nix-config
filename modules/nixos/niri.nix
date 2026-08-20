# niri — Wayland scrollable-tiling compositor.
#
# Imports niri-flake's nixosModule (settings surface + polkit + dconf + OpenGL
# + xdg.portal + the wayland-sessions entry greetd discovers) and enables
# programs.niri at the system layer.
#
# The flake is `epireyn/niri-flake`, the maintained fork — sodiboo's original
# stopped merging and its stale libdisplay-info pin blocked every weekly
# lockfile bump fleet-wide. Why the fork rather than owning the config
# outright: docs/design/niri-sourcing.md §Rationale (#763).
#
# The *package* is nixpkgs', not the flake's, which is what keeps this to a
# module dependency with no binary and no signing key behind it. Two
# consequences worth stating: niri now rides the 26.04 *release* line instead
# of niri-unstable's master snapshots (the reason for tracking master was
# niri-flake's stable slot sitting at 25.08, which nixpkgs having 26.04
# retires); and no cachix trust is needed at all, since cache.nixos.org
# already serves it. 26.04 still carries `include optional=true`, which is
# what lets Noctalia's own niri builtin template reach niri through a
# pre-declared include mount-point — see ADR-048 (reversing ADR-044 for
# Linux) and docs/desktop/noctalia.md.
#
# Per ADR-028.
{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs.niri-flake.nixosModules.niri ];

  programs.niri.enable = true;

  programs.niri.package = pkgs.niri;

  # Load-bearing, and NOT vestigial now that the substituter block is gone:
  # this option defaults to *true* upstream, so removing it would have the
  # fork silently add `niri-epireyn.cachix.org` plus its signing key to every
  # host importing this module — a single-maintainer trust delegation nobody
  # chose, which is exactly what the fork migration set out not to take on
  # (CLAUDE.md, whitelist > blanket).
  niri-flake.cache.enable = false;

  # Register niri's package-shipped systemd user units (niri.service +
  # niri-shutdown.target, at `$out/{lib,share}/systemd/user/` — hardlinked)
  # for systemd-user discovery. niri-flake's nixosModule installs the niri
  # package via `environment.systemPackages` only, so without this NixOS
  # never symlinks the shipped units into `/etc/systemd/user/` and greetd
  # → niri-session's `systemctl --user --wait start niri.service` fails
  # with "Unit not found". See issue #67 for the incident write-up.
  systemd.packages = [ config.programs.niri.package ];

  # Don't let `nh os switch` SIGTERM the live compositor. switch-to-
  # configuration otherwise restarts niri.service when it changes, tearing
  # down the whole graphical-session.target mid-session (and wedging greetd
  # on recovery). `restartIfChanged = false` marks the unit
  # X-RestartIfChanged so switch leaves the running session alone; changes
  # are picked up on the next login.
  #
  # The override must be a *drop-in*: the default full-replace strategy
  # shadows the package unit with a NixOS-generated stub that has no
  # ExecStart= — the exact #67 failure. `overrideStrategy = "asDropin"`
  # keeps the package's `ExecStart=niri --session`. `enableDefaultPath =
  # false` stops NixOS injecting a minimal `PATH=` that would shadow the
  # full session PATH niri-session populates at runtime via `systemctl
  # --user import-environment` (else the binds' bare-name spawns — foot,
  # noctalia, xdg-open — don't resolve).
  systemd.user.services = {
    niri = {
      overrideStrategy = "asDropin";
      restartIfChanged = false;
      enableDefaultPath = false;
    };

    # niri-flake also runs a polkit authentication agent by default — the KDE
    # agent, via the `niri-flake-polkit` user service. Disable it (the
    # niri-flake-documented lever): on this non-Plasma host the KDE/Kirigami
    # agent renders off-theme (nothing writes kdeglobals here, so it falls
    # back to stock Breeze), and it is the host's only Qt app — 573 MiB of
    # Qt/KDE for one dialog. It is replaced by mate-polkit, which is GTK and
    # so picks up the toolkit theme, in home/nixos/polkit-agent.nix. See
    # docs/desktop/polkit.md (#103).
    niri-flake-polkit.enable = false;
  };
}
