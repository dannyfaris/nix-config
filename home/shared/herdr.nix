# herdr — terminal workspace/agent manager, adopted fleet-wide as an
# installed tool per #814. In-app settings changes (theme, onboarding
# dismissal, ...) write to config.toml directly, which is an HM read-only
# store symlink here — those writes fail and surface a toast, so the
# declared config below is the sole source of truth; this is deliberate,
# not a bug.
_: {
  programs.herdr = {
    enable = true;

    settings = {
      # config.toml is read-only (see header), so the first-run dismissal
      # write can never persist — declare onboarding already done.
      onboarding = false;

      theme.name = "terminal"; # ANSI-16 terminal bus (ADR-041), same convention as zellij's theme = "ansi".
    };
  };
}
