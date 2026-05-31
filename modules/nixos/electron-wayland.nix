# electron-wayland — opt every Electron app on this host into native
# Wayland rendering.
#
# nixpkgs' Electron-app wrappers (vscode, code-cursor, discord,
# signal-desktop, slack, etc., all of which extend `buildVscode` or
# the generic Electron wrapper) detect this env var at startup and,
# if `WAYLAND_DISPLAY` is also set, append the canonical Wayland-ozone
# flags to the Electron command line:
#
#   --ozone-platform-hint=auto
#   --enable-features=WaylandWindowDecorations
#   --enable-wayland-ime=true
#   --wayland-text-input-version=3
#
# Source: nixpkgs `pkgs/applications/editors/vscode/generic.nix:375`.
#
# Set host-wide via environment.sessionVariables (not per-tool) because
# every Electron-based app benefits and pinning it per-tool would be
# repetitive. Imported by the desktop-env bundle, so it only fires on
# desktop hosts (where Electron apps are usable). Inert on headless
# hosts like mercury that never import the desktop-env bundle.
#
# Wayland still works for non-Electron Wayland-native apps regardless
# of this var; this only governs how Electron's Chromium runtime picks
# its windowing backend.
#
# Per #77.
_: {
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
