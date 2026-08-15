# Stylix HM-side target enables for the **desktop** stack — the
# targets that are only enabled on hosts that import the
# desktop-env home bundle. Companion to `home/shared/stylix-targets.nix`
# (which carries the cross-platform-safe TUI targets).
#
# Lives under `home/nixos/` because the one surviving entry here (gtk) is
# driven by a module that's Linux-only today, as part of the niri session.
# Imported by `home/nixos/bundles/desktop-env.nix` so desktop hosts pick it
# up transitively without needing a separate import line.
#
# G6 (#825): the `firefox` colour-role target is dropped — zero-weight
# ruling, accepted collateral (ADR-048); no replacement wiring. See
# docs/desktop/firefox.md.
#
# Why the split: Stylix's `autoload.nix` declares every target's
# `enable` option universally regardless of platform, so the pre-split
# `home/shared/stylix-targets.nix` would have evaluated cleanly on
# Darwin (config emission is gated inside each target via
# `programs.<X>.enable` + per-config arg availability). Co-locating the
# desktop targets with the bundle that actually enables them is an
# architectural cleanup — it makes "what does celaeno's HM tree
# include?" answerable by the import graph alone, rather than by
# tracing per-target gates inside a cross-platform file. The split is
# closure-identical for every NixOS host (verified pre/post; mercury
# and nixos-vm — both since decommissioned, #634 — never imported the
# desktop bundle, so their targets were inert by construction; metis
# picks up the same set via the desktop-env bundle).
#
# Done as a prerequisite for the mac-mini onboarding work (#11).
{ config, lib, ... }:
let
  # `programs.foot.enable` is true only on the hosts that import the
  # desktop-env home bundle. Used as the desktop-session proxy to gate the
  # toolkit-level `gtk` target, which has no per-app gate upstream. (The
  # `qt` target was dropped in #103 — see below; the `firefox` target was
  # dropped in the G6 Stylix-exit audit, #825 — see the header comment.)
  desktopSession = config.programs.foot.enable or false;
in
{
  stylix.targets = {
    # foot + niri targets were removed in #385 — colour for both now comes
    # from Noctalia's own native theme engine via a pre-declared mount-point
    # (ADR-048, reversing ADR-044/#609 for Linux — foot.nix declares the
    # include; niri.nix appends a runtime include, with border on /
    # focus-ring off re-asserted there since Stylix used to set them). See
    # docs/desktop/noctalia.md §Theming and docs/desktop/niri.md §Window
    # decorations.
    # fuzzel/fnott/waybar targets were removed in #385 alongside their
    # modules — Noctalia now owns the launcher, notifications and bar.
    # swaylock's target was removed in #385 — swaylock + swayidle were
    # decommissioned; Noctalia owns the lock surface and idle handling.
    # firefox — dropped (ADR-048 zero-weight ruling, #825); renders stock
    # defaults.
    # gtk — toolkit-level theming, no per-app gating upstream.
    # Gated locally on `desktopSession` so a future desktop-less host
    # importing this file (unlikely under the desktop-env bundle) won't
    # pull adw-gtk3 / gtk+3 (~42 MiB) for theming it can't render. On the
    # NixOS desktop hosts the gate fires and GTK app chrome (file pickers,
    # settings dialogs, GTK apps generally) follows the base16 palette
    # instead of default Adwaita-light.
    #
    # The `qt` target was dropped (#103). The polkit-kde agent was the
    # only Qt app on metis; swapping it for mate-polkit (GTK) left zero
    # Qt apps, so `qt` theming themed nothing — removing it (and the
    # agent's KDE-Frameworks layer) trims a measured 573 MiB. Re-add
    # `qt.enable = lib.mkIf desktopSession true;` if a Qt app is ever
    # installed. See docs/desktop/polkit.md.
    gtk.enable = lib.mkIf desktopSession true;

    # GTK colours come from Noctalia's own gtk3/gtk4 builtin templates now
    # (ADR-048, reversing ADR-044/#609's conductor-owned @import for Linux —
    # #819 Epic G). No declared extraCss seam: gtk's apply.sh takes a
    # different ownership path than foot/niri's pre-declared-include pattern
    # — it detects this target's HM-owned read-only gtk.css symlink at
    # activation and materializes it into a plain, writable file with its
    # own @import appended, idempotently on every re-run (G3 spike,
    # source-confirmed and on-metal-tested; docs/design/
    # noctalia-theming-delegation.md §De-risk). The Stylix gtk target stays
    # enabled for settings.ini (adw-gtk3 + font) only — its own @define-color
    # write is a transient base until Noctalia's first theme resolve
    # overwrites the file (see docs/desktop/noctalia.md §Sharp edges for the
    # window between `nh os switch` and that first resolve).
  };

  # GTK app-UI (the polkit prompt, file pickers, app dialogs) rides the `Sans`
  # fontconfig generic, so it follows the font conductor — and any runtime
  # ~/.config/fontconfig override — like every other surface; today Sans
  # resolves to Inter (#390; docs/desktop/fonts.md). Sized at the popups slot
  # (the chrome body size, M3 body) so dialogs match the notification body, not
  # the applications slot (12, which sizes web body). mkForce because Stylix's
  # gtk target also writes gtk.font (from stylix.fonts.sansSerif); we force the
  # generic over it. No package — the conductor's faces install at system level.
  gtk.font = lib.mkIf desktopSession (
    lib.mkForce {
      name = "Sans";
      size = config.stylix.fonts.sizes.popups;
    }
  );
}
