# Ensure ~/Screenshots exists so the system-side
# `system.defaults.screencapture.location` set in
# `modules/darwin/system-prefs.nix` actually resolves. macOS's
# `screencapture` (⌘⇧3 / ⌘⇧4 / ⌘⇧5) silently falls back to ~/Desktop
# when the configured save location doesn't exist — without this
# activation hook, the system-side setting would be inert on a fresh
# Mac the first time a screenshot is captured.
#
# Per-user concern, so home-manager is the right layer (the system
# module deals in domain-wide `defaults` keys; the directory itself
# lives under the operator's home). Mirrors the `ensureProjectDirs`
# pattern in `home/shared/git-identity-dual.nix` and the
# `agentStatuslineSettings` shape in `home/shared/agent-clis.nix`:
# `home.activation.<name>` with the `entryAfter ["writeBoundary"]`
# DAG anchor, which is the standard home-manager idiom for "make sure
# something exists on disk after the bulk of the activation has
# written its files."
#
# `mkdir -p` is idempotent — re-running activation is a no-op once the
# directory exists, and existing contents are untouched. Removing this
# module later leaves ~/Screenshots in place (we don't auto-remove
# user data).
{ lib, ... }:
{
  home.activation.ensureScreenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p $VERBOSE_ARG "$HOME/Screenshots"
  '';
}
