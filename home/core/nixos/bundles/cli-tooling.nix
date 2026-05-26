# cli-tooling — the comprehensive CLI development environment.
#
# Shell + prompt + per-project env activation + multiplexer + editor
# + modern Unix replacements + nix-specific tooling. Every host that
# the operator interactively logs into wants the whole stack; the
# units don't usefully decompose further at this scale (splitting
# into terminal-stack vs dev-tools would create bundles no host
# imports separately).
{
  imports = [
    ../shell.nix
    ../prompt.nix
    ../direnv.nix
    ../multiplexer.nix
    ../editor.nix
    ../cli-utils.nix
    ../nix-tooling.nix
  ];
}
