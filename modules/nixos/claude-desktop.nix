# Claude Desktop for Linux — Anthropic's official beta, repackaged by
# aaddrick (github:aaddrick/claude-desktop-debian, pinned as the
# `claude-desktop` flake input; selection rationale in #683). Imported
# per-host (alcyone, alnair): it is a Wayland GUI app, so hosts without a
# desktop session would carry the Electron closure for nothing.
#
# Phase 1 ONLY — the Chat + Claude Code tabs. Cowork (the KVM-sandboxed
# agent-in-a-VM mode) is deferred: the Linux build has no hardware-key
# backend, so Cowork cloud tasks can never link to the computer — an
# upstream (Anthropic-side) blocker no Nix wiring can fix. The host-side
# virt plumbing (vhost_vsock module, kvm group, udev rule) is recorded in
# #683 and lands only when the tripwire there fires (aaddrick #780/#807
# closed, or an Anthropic release note shipping Linux device-linking).
#
# Variant: `claude-desktop-fhs`, not the bare `claude-desktop`. The FHS
# build wraps the app in an FHS environment so MCP servers and Claude Code
# tool use (which shell out to interpreters expecting /usr/bin paths) run.
# Known cost: upstream's FHS targetPkgs unconditionally bundle the Cowork
# virt userspace (qemu_kvm ~1.5 GB, OVMF, virtiofsd) plus docker/nodejs/uv
# — inert without the deferred host plumbing, but in the closure; stripping
# would mean overriding upstream's targetPkgs, out of Phase-1 scope.
# `overlays.default` surfaces both variants into pkgs; `claude-desktop` is
# unfree, whitelisted by name in modules/shared/nix-daemon.nix.
#
# Electron/Wayland rendering (NIXOS_OZONE_WL=1) already comes from the
# desktop-env bundle's electron-wayland.nix — not re-set here.
#
# App state lives in ~/.config/Claude (per-user; both hosts persist /home
# under ephemeral root, so no persist-whitelist entry is needed).
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.claude-desktop.overlays.default ];

  # environment.systemPackages, not the home/nixos home.packages pattern
  # (obsidian, typora): the overlay must be declared at system level anyway
  # (useGlobalPkgs), so the install co-locates with it in one module.
  environment.systemPackages = [ pkgs.claude-desktop-fhs ];
}
