# Mosh — SSH session resilience over UDP. Survives network changes,
# laptop sleep, and IP swaps without reconnect. Pairs with zellij for
# cross-reboot persistence. See docs/decisions/ADR-011-remote-dev-qol.md.
#
# `programs.mosh.enable = true;` installs the binary AND opens UDP
# 60000–61000 in the firewall — both required.
{
  programs.mosh.enable = true;
}
