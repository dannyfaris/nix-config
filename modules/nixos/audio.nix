# Audio — PipeWire sound server + rtkit realtime scheduling.
#
# System-level plumbing for the niri desktop's sound stack; the home-side
# control surfaces (media keys, waybar readout, GUI mixer) are a separate
# concern. See docs/desktop/audio.md §Configuration for the full stack and
# the rationale behind each toggle.
#
# nixpkgs' services.graphical-desktop enables services.pipewire via
# `lib.mkDefault` for any Wayland desktop, so pipewire is *present* on metis
# already — but no repo module asserts it, and that baseline leaves rtkit off.
# This module makes the sound server an explicit, owned guarantee: a
# normal-priority `enable = true` that merges over the mkDefault and survives
# an upstream default change, plus the rtkit companion pipewire needs.
{
  # PipeWire needs rtkit to request realtime scheduling; without it PipeWire
  # loses scheduling priority and logs warnings every session start. PulseAudio
  # enabled this implicitly, PipeWire does not (docs/desktop/audio.md §Rationale).
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    # ALSA + PulseAudio client compatibility. `pulse.enable` provides the
    # pipewire-pulse server the long tail of Pulse-only apps connect to; without
    # it they break silently. `alsa.support32Bit` is deliberately omitted — no
    # 32-bit audio app is anticipated on this box (whitelist stance, audio.md).
    alsa.enable = true;
    pulse.enable = true;
    # WirePlumber is PipeWire's default session manager and needs no extra enable.
  };
}
