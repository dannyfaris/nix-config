# Outbound SSH — defaults only; key generation deferred.
# See docs/decisions/ADR-010-ssh.md for rationale.
#
# No matchBlocks, no identity files, no key generation. Git auth uses
# HTTPS + token via gh/glab (see ADR-009), so SSH keys aren't needed for
# git. No other non-git SSH-out workflow exists yet on this box.
#
# When SSH keys are eventually added (e.g. for a future x86_64 desktop or
# cloud servers), generate fresh ed25519 keys on this box, use a
# passphrase + ssh-agent, and add matchBlocks here. Agent forwarding from
# the Mac stays explicitly OFF (standard security best practice).
_: {
  programs.ssh = {
    enable = true;
    # Opt out of home-manager's deprecated "default match-block contents"
    # behaviour. Upstream is removing the implicit defaults; this silences
    # the trace warning and makes the stance explicit. We don't depend on
    # any of those defaults (no matchBlocks declared; no SSH keys yet).
    enableDefaultConfig = false;
  };
}
