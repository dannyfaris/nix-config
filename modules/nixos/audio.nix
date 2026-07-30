# Audio — PipeWire sound server + rtkit realtime scheduling. System-level
# plumbing only; the home-side control surfaces are #668's remit. Why an
# explicit module when nixpkgs' graphical-desktop baseline already lights
# PipeWire up: docs/desktop/audio.md §Rationale.
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
