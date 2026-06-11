# session-type — the shared local-vs-SSH connection detector.
#
# This is a PACKAGE (a callPackage target), not a home-manager module:
# `pkgs.callPackage ./session-type.nix { }`. It builds a single
# `session-type` command consumed by all the host-marker surfaces —
# home/shared/prompt.nix (starship), home/shared/multiplexer.nix
# (zjstatus), and the Claude/Cursor statuslines (home/shared/agent-clis.nix)
# — replacing the four hand-mirrored `is_ssh()` copies that used to drift.
#
# Why a command and not an inline snippet: the detection is no longer a
# one-liner (#270). Inside zellij a pane's environment — including
# $SSH_CONNECTION — is captured at zellij-*server* start and never
# refreshed, so it goes stale the moment you detach and reattach from a
# different connection context (SSH-born session reattached locally keeps
# the SSH glyph, and vice-versa). `za`'s detach-and-reattach workflow
# makes that routine, not an edge case. The pane can't recover the live
# context by walking its own process tree (panes hang off the server
# daemon: pane -> zellij --server -> init), so we instead locate the live
# zellij *client* for this session (a zellij process WITH a controlling tty
# whose argv names the session as a word; the server has none and carries
# --server) and walk ITS process ancestry for an sshd parent. That env-free
# signal works on both platforms (macOS BSD `ps` exposes env only via a
# targeted per-PID query, never the bulk scan a render can afford, and
# procps exposes none on Darwin at all) and as a bonus survives sudo -i /
# su - (the sshd ancestor stays in the tree). A short per-session cache
# keeps the common prompt-render path cheap. See ADR-002 (prompt), ADR-024
# (statusline), ADR-004 (zellij) and issue #270.
{
  writeShellApplication,
  gawk,
}:
writeShellApplication {
  name = "session-type";
  # awk is pinned for deterministic parsing. ps is deliberately NOT pinned —
  # detect() selects the platform-native build itself (/bin/ps on macOS;
  # procps `ps`, which reads /proc, on Linux). `who` (live() fallback only)
  # resolves from the ambient PATH, matching the prior surfaces' usage.
  runtimeInputs = [ gawk ];
  # writeShellApplication injects the shebang + `set -euo pipefail`; the
  # body below is written to be safe under errexit/nounset/pipefail (every
  # command that may legitimately fail is guarded). Validated against
  # shellcheck (run at build) and exercised live before landing.
  text = ''
    # Print "ssh" or "local" for the CURRENT client connection.
    session=''${ZELLIJ_SESSION_NAME:-}

    # Live (non-zellij) detection: $SSH_CONNECTION, with who -m's
    # origin-host-in-parens as the sudo -i / su - fallback (both strip
    # $SSH_CONNECTION). This is the correct, final answer outside zellij,
    # and the graceful fallback inside it when the client can't be found.
    live() {
      if [ -n "''${SSH_CONNECTION:-}" ]; then echo ssh; return 0; fi
      case "$(who -m 2>/dev/null)" in
        *\(*\)*) echo ssh ;;
        *) echo local ;;
      esac
    }

    if [ -z "$session" ]; then live; exit 0; fi

    # Per-session cache (epoch-stamped, short TTL) — absorbs the prompt's
    # two-module double-eval and bounds frequent-render cost. $EUID and the
    # printf clock are bash builtins (no fork) so a cache hit is ~free.
    ttl=2
    uid=''${EUID:-$(id -u 2>/dev/null || echo 0)}
    dir=''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}
    cache="$dir/session-type.$uid.$session"
    printf -v now '%(%s)T' -1 2>/dev/null || now=$(date +%s 2>/dev/null || echo 0)
    if [ -r "$cache" ] && read -r ts val <"$cache" 2>/dev/null; then
      case "''${ts:-}" in *[!0-9]* | "") ts=0 ;; esac
      if [ -n "''${val:-}" ] && [ "$now" -ge "$ts" ] && [ "$((now - ts))" -lt "$ttl" ]; then
        echo "$val"; exit 0
      fi
    fi

    # Locate the live client and read its connection from its ancestry.
    detect() {
      # Platform-native ps: procps on Linux (reads /proc); BSD /bin/ps on
      # macOS (procps reads /proc — absent on Darwin — and can shadow `ps`
      # in a dev shell, so go straight to the system binary there).
      local ps_bin=ps
      [ -d /proc ] || ps_bin=/bin/ps
      # One scan; awk builds pid->ppid and pid->argv maps, finds the client
      # — a process whose argv[0] basename is the zellij binary (so a
      # `grep ... agent` that merely mentions zellij in a path can't
      # masquerade as it), WITH a tty, NOT the --server, whose argv names
      # this session as a whole word after stripping any `-n <layout>` token
      # (so a session named like a zellij keyword, e.g. "agent", isn't
      # confused with another session's layout name, and "work" won't match
      # "work-2") — then climbs the client's ancestry to an sshd (-> ssh) or
      # to init (-> local).
      "$ps_bin" -Ao pid=,ppid=,tty=,args= 2>/dev/null | awk -v s="$session" '
        { pid=$1; pp[pid]=$2; tty=$3
          a=""; for (i=4;i<=NF;i++) a=(a==""?$i:a" "$i); av[pid]=a
          nn=split($4,bp,"/"); base=bp[nn]
          if (client=="" && tty!="?" && tty!="??" && tty!="" \
              && (base=="zellij" || base==".zellij-wrapped") && index(a,"--server")==0) {
            m=a; gsub(/ -n [^ ]+/, "", m)
            if (index(" " m " ", " " s " ")>0) client=pid } }
        END { if (client=="") exit 1
          p=client
          for (n=0; n<40 && p!="" && p!="0" && p!="1"; n++) {
            if (index(av[p],"sshd")>0) { print "ssh"; exit 0 }
            p=pp[p] }
          print "local" }'
    }

    val=$(detect) || val=
    [ -n "''${val:-}" ] || val=$(live)

    printf '%s %s\n' "$now" "$val" >"$cache" 2>/dev/null || true
    echo "$val"
  '';
}
