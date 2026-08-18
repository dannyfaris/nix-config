# Noctalia Shell v5 — cohesive Wayland desktop shell on the Linux desktop
# (ADR-036; v5 re-integration #644, docs/design/noctalia-v5-migration.md).
# Native C++ binary (`noctalia`) via the flake's home-manager module —
# no Quickshell/Qt runtime, IPC is `noctalia msg <verb>`.
#
# The shell is spawned from niri (`spawn-at-startup` in home/nixos/niri.nix);
# the HM module's systemd unit stays at its default (off). `validateConfig`
# stays at its default (true): the baseline below is validated by the v5
# binary's own schema engine at build time, so schema drift on a bump fails
# the build, not the session.
#
# Theming — DELEGATED (ADR-048, reversing ADR-044 for Linux; #819 Epic G,
# docs/design/noctalia-theming-delegation.md is the mandate). Noctalia's own
# native engine is the sole theming authority: builtin, community, and
# wallpaper-derived themes are picked in its own UI (control centre,
# launcher), never a Nix-declared catalogue. `config.toml` below declares
# NO theme keys — no source, no custom_palette, no mode — so there is
# exactly one writer (Noctalia's `settings.toml` overrides layer) and no
# declared/runtime disagreement is possible by construction. What Nix still
# declares is mechanism, not taste: which builtin templates may render
# (below), the pre-declared mount-points those templates write into
# (home/nixos/foot.nix, home/nixos/niri.nix), and the `colors_changed`
# repaint hook that OSC-paints already-open foot windows (below). The
# ADR-044 conductor (home/nixos/theme-menu.nix, the `theme` CLI, the
# `hooks.started` polarity reconcile) is deleted on Linux, not deprecated
# in place — Darwin (celaeno) keeps its conductor untouched.
{
  inputs,
  config,
  lib,
  pkgs,
  hostContext,
  ...
}:
let
  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Idle-suspend guard — the `[idle.behavior.suspend]` command. Ordered
  # skip-checks, failure direction "stays awake" (correct for a remotely-used
  # box — design note §Design): (1) Noctalia's caffeine logind inhibitor
  # (who=noctalia, why=Caffeine). Runtime verification (probe S4) showed
  # caffeine natively suppresses idle behaviours at beta.4 — this check is
  # defence-in-depth against a future regression, not the primary gate;
  # (2) live inbound SSH; (3) detached agent workloads (linger is on — SSH
  # teardown does not imply idle; pattern starts conservative, tune on
  # evidence). Otherwise delegate to Noctalia's own locked-event-gated
  # suspend. `--dry-run` prints + logs the decision without acting (probe S3).
  idleGuard = pkgs.writeShellApplication {
    name = "noctalia-idle-guard";
    runtimeInputs = [
      pkgs.systemd # systemd-inhibit
      pkgs.iproute2 # ss
      pkgs.procps # pgrep
      pkgs.coreutils
      pkgs.gnugrep
      noctaliaPkg
    ];
    text = ''
      decision="suspend"
      if systemd-inhibit --list --no-pager 2>/dev/null | grep -qE 'noctalia.*Caffeine'; then
        decision="skip: caffeine inhibitor present"
      elif [ -n "$(ss -H -tn state established '( sport = :22 )')" ]; then
        decision="skip: live inbound SSH session"
      elif pgrep -u "$(id -un)" -f 'claude|tmux' >/dev/null 2>&1; then
        decision="skip: detached agent session running"
      fi

      if [ "''${1:-}" = "--dry-run" ]; then
        log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}"
        printf '%s %s\n' "$(date -Is)" "$decision" >> "$log_dir/noctalia-idle-guard.log"
        echo "noctalia-idle-guard (dry-run): $decision"
        exit 0
      fi

      if [ "$decision" != "suspend" ]; then
        echo "noctalia-idle-guard: $decision" >&2
        exit 0
      fi
      exec noctalia msg session lock-and-suspend
    '';
  };

  # Terminal repaint hook — bound to Noctalia's `colors_changed` hook, which
  # fires strictly after all templates (builtin → community → user) finish
  # writing (source-guaranteed by the single template worker; design note
  # §De-risk) and is executed with NO environment variables, so the script
  # reads state itself rather than being handed it. Re-points the #609-proven
  # per-pty OSC loop (OSC 4×16 + 10/11, pgrep→ps discovery — never signals by
  # process name) at Noctalia's own rendered foot theme file instead of the
  # retired conductor's, and nudges niri explicitly since its inotify watch
  # misses the write (niri#2658 — the same reload gap the conductor's `theme`
  # CLI worked around). Idempotency is a PERMANENT requirement, not a
  # transitional one: `colors_changed` fires 3-4x per change at beta.8 plus
  # once on an unrelated reload — the upstream dedup (`460d1d4fc`) does not
  # land 1:1 in practice (design note §De-risk, root cause unpinned) — so
  # re-running against unchanged input is the normal case. Logs honestly to
  # a state-dir file rather than swallowing a missing theme file or a dead
  # pty silently (#303 — no unconditional success).
  repaintHook = pkgs.writeShellApplication {
    name = "noctalia-repaint-hook";
    runtimeInputs = [
      pkgs.procps # pgrep, ps
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
      config.programs.niri.package # niri msg action load-config-file
    ];
    text = ''
      log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia-repaint"
      log_file="$log_dir/repaint.log"
      mkdir -p "$log_dir"
      log() { printf '%s %s\n' "$(date -Is)" "$1" >>"$log_file"; }

      # Noctalia's own foot builtin template output_path (assets/templates/
      # foot/apply.sh) — the same file the pre-declared mount-point in
      # home/nixos/foot.nix includes.
      foot_theme="''${XDG_CONFIG_HOME:-$HOME/.config}/foot/themes/noctalia"

      if [ ! -r "$foot_theme" ]; then
        log "error: noctalia foot theme file not readable at $foot_theme"
        exit 1
      fi

      # Parse the [colors-dark] section into key=value lines, one match per
      # line — adapted from the #609-proven parse_foot_ini() in the retired
      # conductor (origin/main home/nixos/theme-menu.nix). That parser strips
      # intra-line whitespace with a line-oriented `sed 's/[[:space:]]//g'`,
      # which leaves the newlines between matches intact so each key=value
      # pair stays on its own line for the per-slot `grep '^key='` lookups
      # below. A stream-oriented `tr -d '[:space:]'` instead (the bug this
      # replaces) deletes the newlines along with the spaces and collapses
      # the whole section into one unbroken line, so every per-slot grep
      # after the first silently matches nothing.
      #
      # Noctalia's own render (assets/templates/foot/foot, verified against
      # the pinned v5.0.0-beta.8 source, rev 45e721ba0fb47d6efc00ca47e156237
      # 954037c99) emits `key=value` with no padding around '=' — unlike the
      # retired conductor's padded output — so the whitespace strip is a
      # no-op on real input, but keeping it (rather than dropping the step)
      # keeps this parser correct if Noctalia ever pads its emitted values.
      parse_foot_theme() {
        sed -n '/^\[colors-dark\]/,/^\[/p' "$1" \
          | grep -E '^[[:space:]]*(background|foreground|regular[0-9]|bright[0-9])' \
          | sed 's/[[:space:]]//g'
      }

      stripped=$(parse_foot_theme "$foot_theme") || true

      if [ -z "$stripped" ]; then
        log "error: no [colors-dark] palette parsed from $foot_theme"
        exit 1
      fi

      # Emit OSC 4 (16 ANSI slots) + OSC 10/11 (fg/bg) to one foot pty. foot
      # is standalone (one process per window); writing to the pty slave is
      # display-side — foot parses OSC directly, zellij is not in this path.
      emit_osc_to_pty() {
        pty="$1"
        {
          bg=$(printf '%s\n' "$stripped" | grep '^background=' | cut -d= -f2)
          fg=$(printf '%s\n' "$stripped" | grep '^foreground=' | cut -d= -f2)
          printf '\033]11;#%s\007' "$bg"
          printf '\033]10;#%s\007' "$fg"
          for slot_idx in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
            if [ "$slot_idx" -lt 8 ]; then
              key="regular''${slot_idx}"
            else
              key="bright''$((slot_idx - 8))"
            fi
            colour=$(printf '%s\n' "$stripped" | grep "^''${key}=" | cut -d= -f2)
            [ -n "$colour" ] && printf '\033]4;%d;#%s\007' "$slot_idx" "$colour"
          done
        } > "/dev/pts/$pty" 2>/dev/null || true
      }

      # Discover foot ptys: for each foot pid, find its child tty via
      # `ps --ppid`. `pgrep` exits 1 with no output when no foot windows are
      # running — normal, not a failure — so capture to a variable first
      # rather than piping straight into `while read` (would otherwise abort
      # the whole script under errexit+pipefail via writeShellApplication).
      foot_pids=$(pgrep -x foot 2>/dev/null || true)
      repainted=0
      if [ -n "$foot_pids" ]; then
        while read -r foot_pid; do
          [ -z "$foot_pid" ] && continue
          # shellcheck disable=SC2009
          tty_path=$(ps --ppid "$foot_pid" -o tty= 2>/dev/null | grep -v '?' | head -1 || true)
          if [ -n "$tty_path" ]; then
            emit_osc_to_pty "''${tty_path##pts/}"
            repainted=$((repainted + 1))
          fi
        done <<< "$foot_pids"
      fi
      log "repainted $repainted foot pty(s) from $foot_theme"

      # niri's inotify watch misses file/symlink writes at this mount-point
      # (niri#2658); nudge it explicitly, non-fatally (harmless outside a
      # niri session).
      if niri msg action load-config-file >/dev/null 2>&1; then
        log "niri config reloaded"
      else
        log "niri reload skipped (non-fatal outside session)"
      fi
    '';
  };

  # Lock engagement for the user-level sleep.target that
  # modules/nixos/lock-before-sleep.nix bridges (systemd-lock-handler holds
  # the logind delay-inhibitor, so sleep waits for this oneshot). The short
  # settle covers the niri round-trip — v5's IPC has no lock-state query.
  # If the shell is dead nothing locks, but nothing idle-suspends either
  # (accepted residual, design note §Design).
  lockOnSleep = pkgs.writeShellApplication {
    name = "noctalia-lock-on-sleep";
    runtimeInputs = [
      pkgs.coreutils
      noctaliaPkg
    ];
    text = ''
      noctalia msg session lock >/dev/null 2>&1 || true
      sleep 0.3
    '';
  };

  # Authoritative-key manifest — single source for both guards (design note
  # §Design, F6). Parsed here for the reconcile; read verbatim by
  # scripts/noctalia-config-audit.sh.
  authoritativeEntries =
    let
      lines = builtins.filter (l: l != "" && !lib.hasPrefix "#" l) (
        lib.splitString "\n" (builtins.readFile ./noctalia-authoritative-keys.conf)
      );
      # Fail EVAL, not silently drop, on a malformed entry — the audit
      # rejects the same line loudly at runtime, and the two consumers of
      # the single source must agree on validity (stage-6 finding 11).
      bad = builtins.filter (l: !(lib.hasPrefix "table " l || lib.hasPrefix "leaf " l)) lines;
    in
    if bad == [ ] then
      lines
    else
      throw "noctalia-authoritative-keys.conf: unrecognised entry: ${builtins.head bad}";
  authoritativeTables = map (l: builtins.elemAt (lib.splitString " " l) 1) (
    builtins.filter (l: lib.hasPrefix "table " l) authoritativeEntries
  );
  authoritativeLeafs = map (
    l:
    let
      parts = lib.splitString " " l;
    in
    "${builtins.elemAt parts 1}:${builtins.elemAt parts 2}"
  ) (builtins.filter (l: lib.hasPrefix "leaf " l) authoritativeEntries);

  # Pre-spawn reconcile — the authoritative-key guard (design note §Design,
  # ruling 2-bis). Runs BEFORE the noctalia process exists, then execs it:
  # ConfigService's constructor reads the corrected sidecar at startup, so
  # there is no watcher, no hot-reload, and no echo-drain filter anywhere in
  # the path (the hooks.started slot was disqualified on exactly those —
  # design note §De-risk, gate i/iv). Failure direction is ALWAYS "the shell
  # starts": every guard failure logs and falls through to exec. The
  # structural post-check, not TOML parse validity, is the safety gate —
  # parse-valid output can still have silently eaten an unrelated table
  # (gate ii's trailing-comment counterexample); any removed line that is
  # not a target header, a key line, or a blank aborts the swap and leaves
  # the sidecar untouched. Self-logging is mandatory: nothing else reports
  # for a pre-spawn wrapper (#303 — no silent success).
  guardedLaunch = pkgs.writeShellApplication {
    name = "noctalia-guarded-launch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.diffutils
      noctaliaPkg
    ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia"
      sidecar="$state_dir/settings.toml"
      log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia-reconcile"
      mkdir -p "$log_dir" 2>/dev/null || true
      # log must never be the thing that breaks session start (disk-full,
      # read-only state dir): best-effort, swallowing its own failure.
      log() { printf '%s %s\n' "$(date -Is)" "$1" >>"$log_dir/reconcile.log" 2>/dev/null || true; }

      # The same awk pass detects (out=/dev/null) and rewrites. A region
      # terminates at ANY line whose first non-space char is '[' — deliberately
      # looser than an exact-header match, so a header carrying a trailing
      # comment ends the region instead of being swallowed into it (the
      # gate-ii failure mode). CR is stripped before matching so CRLF files
      # cannot silently no-op.
      # shellcheck disable=SC2016 # single quotes are the point: awk -v vars, no shell expansion
      strip_awk='
        BEGIN {
          nt = split(tables, T, " ");
          nl = split(leafs, L, " ");
          for (i = 1; i <= nl; i++) { split(L[i], a, ":"); LP[a[1]] = a[2]; }
        }
        {
          line = $0; sub(/\r$/, "", line);
          t = line; gsub(/^[ \t]+/, "", t); gsub(/[ \t]+$/, "", t);
          if (t ~ /^\[/) {
            region = "";
            for (i = 1; i <= nt; i++) if (t == "[" T[i] "]") region = "DROP";
            for (p in LP) if (t == "[" p "]") region = "LEAF:" p;
          }
          if (region == "DROP") { print line >> removed; next }
          if (region ~ /^LEAF:/) {
            p = substr(region, 6);
            if (t ~ "^" LP[p] "[ \t]*=") { print line >> removed; next }
          }
          print $0 >> out
        }'

      run_strip() { # $1=input $2=out $3=removed
        : >"$2"
        : >"$3"
        awk -v tables=${lib.escapeShellArg (toString authoritativeTables)} \
          -v leafs=${lib.escapeShellArg (toString authoritativeLeafs)} \
          -v out="$2" -v removed="$3" "$strip_awk" "$1"
      }

      # The reconcile body NEVER execs and returns nonzero on any refusal.
      # It is called as `reconcile || true` below so that errexit is
      # suppressed inside it (bash: set -e is inert in a `||` context) and a
      # failure ANYWHERE — guarded or not — still reaches the unconditional
      # `exec noctalia` at the bottom. Failure direction is "the shell
      # starts", always: this wrapper gates session start, and a broken
      # guard must never mean a broken desktop. Because errexit is inert
      # inside, every step that must stop the reconcile carries an explicit
      # `|| return`.
      reconcile() {
        if [ ! -f "$sidecar" ]; then
          log "clean: no sidecar"
          return 0
        fi

        work="$(mktemp -d)" || {
          log "FLAG: mktemp failed — sidecar untouched"
          return 1
        }

        run_strip "$sidecar" "$work/candidate" "$work/removed" || {
          log "FLAG: awk pass errored — sidecar untouched; run scripts/noctalia-config-audit.sh"
          return 1
        }

        if [ ! -s "$work/removed" ]; then
          log "clean: no authoritative keys in sidecar"
          return 0
        fi

        # Structural post-check 1 — every removed line is a target-table
        # header (checked against the manifest-derived list, never
        # hardcoded), a plain key line, or blank. Any other shape (an
        # unrelated table header swallowed into a region) refuses the swap.
        target_tables=${lib.escapeShellArg (toString authoritativeTables)}
        while IFS= read -r raw; do
          t="''${raw#"''${raw%%[![:space:]]*}"}"
          case "$t" in
            "") continue ;;
            "["*)
              ok=0
              for tt in $target_tables; do
                [ "$t" = "[$tt]" ] && ok=1
              done
              if [ "$ok" -ne 1 ]; then
                log "FLAG: post-check refused — removed line looks like a foreign header: $t"
                return 1
              fi
              ;;
            *"="*) continue ;;
            *)
              log "FLAG: post-check refused — unrecognised removed line: $t"
              return 1
              ;;
          esac
        done <"$work/removed"

        # Structural post-check 2 — the rewrite added nothing. diff exits 1
        # whenever the files differ (they always will here) — neutralised so
        # the pipeline reports the count, not a failure.
        additions="$( (diff "$sidecar" "$work/candidate" || true) | { grep -c '^>' || true; })"
        if [ "$additions" -ne 0 ]; then
          log "FLAG: post-check refused — rewrite added $additions line(s); sidecar untouched"
          return 1
        fi

        # Structural post-check 3 — no target survives in the candidate.
        run_strip "$work/candidate" /dev/null "$work/recheck" || true
        if [ -s "$work/recheck" ]; then
          log "FLAG: post-check refused — targets survive the rewrite; sidecar untouched"
          return 1
        fi

        backup="$sidecar.pre-reconcile.$(date +%Y%m%dT%H%M%S)" || return 1
        cp "$sidecar" "$backup" || {
          log "FLAG: backup failed — sidecar untouched"
          return 1
        }
        # Same-filesystem staging file so the final mv is an atomic
        # rename(2), never a cross-device copy-then-unlink: a power cut
        # mid-copy would leave a truncated sidecar, and a parse failure
        # wipes ALL overrides at next load (stage-6 finding 3; upstream
        # itself writes this file atomically). Non-.toml dotfile name —
        # inert to the loader, which reads exactly settings.toml.
        staged="$state_dir/.settings.reconcile-staged.$$"
        cp "$work/candidate" "$staged" || {
          log "FLAG: staging copy failed — sidecar untouched"
          rm -f "$staged"
          return 1
        }
        if mv "$staged" "$sidecar"; then
          log "reconciled: removed $(wc -l <"$work/removed") line(s); backup at $backup"
        else
          log "FLAG: swap failed after backup — sidecar state uncertain, inspect $backup"
          rm -f "$staged"
          return 1
        fi
      }

      # Residual-mention check — flag-only, never removes (stage-6
      # finding 5): a hand-edited shape (e.g. a target header carrying a
      # trailing comment) can evade the strip while remaining live in the
      # merged config. grep -F per target table over the final state; a hit
      # after reconcile means the guard could not enforce and someone
      # should run the audit.
      flag_residuals() {
        [ -f "$sidecar" ] || return 0
        # shellcheck disable=SC2043 # single-word today; the list is manifest-derived and grows with it
        for tt in ${lib.escapeShellArg (toString authoritativeTables)}; do
          if grep -qF "$tt" "$sidecar"; then
            log "FLAG: residual mention of authoritative '$tt' survives in the sidecar (hand-edited shape?) — run scripts/noctalia-config-audit.sh"
          fi
        done
      }

      work=""
      trap '[ -n "$work" ] && rm -rf "$work"' EXIT
      reconcile || true
      flag_residuals || true
      # The EXIT trap does not survive a successful exec (stage-6
      # finding 4) — clean up explicitly; the trap remains as the
      # exec-failure backstop. if-form, not &&: a failing && list at top
      # level would trip errexit and kill the wrapper before exec.
      if [ -n "$work" ]; then rm -rf "$work" || true; fi
      exec noctalia
    '';
  };
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  # Cross-module seam (same idiom as home/darwin/dark-mode-notify.nix):
  # niri's spawn-at-startup launches the shell THROUGH the reconcile wrapper,
  # store-pinned via getExe — never the bare binary, or the authoritative-key
  # guard silently stops running.
  options.noctalia.guardedLaunch = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "Pre-spawn reconcile wrapper around the noctalia binary (design note §Design).";
  };
  config = {
    noctalia.guardedLaunch = guardedLaunch;

    programs.noctalia = {
      enable = true;
      package = noctaliaPkg;

      settings = {
        # Skip the first-run wizard: its guided theme selection would persist
        # theme.* overrides into settings.toml on day one — the exact shadowing
        # channel the palette seam is designed to keep empty (probe C2).
        shell.setup_wizard_enabled = false;

        theme = {
          # NO theme keys — no source, no custom_palette, no mode (ADR-048,
          # reversing ADR-044's Linux authority; #819). Declaring any of these
          # would keep a config.toml-vs-settings.toml two-writer seam alive;
          # declaring nothing makes Noctalia's own runtime overrides the sole
          # writer, by construction. A fresh host renders Noctalia's own
          # defaults — the first runtime pick (builtin/community/wallpaper, in
          # Noctalia's own UI) just works and persists.
          templates = {
            # Builtin template whitelist — EXACTLY these four ids, whitelist-
            # form (never blanket, CLAUDE.md stance). starship and btop are
            # deliberately excluded: the G3 spike's starship incident found
            # both tools' builtin apply.sh run `sed -i` against the discovered
            # config path with no read-only awareness, materializing a plain
            # file over our HM-owned symlink (docs/design/
            # noctalia-theming-delegation.md §De-risk, "the starship
            # incident") — starship's constructive route is a future
            # user-template with an explicit output_path, not this builtin;
            # btop shares the hazard class. helix and the remaining community
            # ids are deferred post-cutover (design note §Unresolved
            # questions). Qt has no target on this desktop (#103) and stays
            # out.
            enable_builtin_templates = true;
            builtin_ids = [
              "foot"
              "gtk3"
              "gtk4"
              "niri"
            ];

            # Community TEMPLATES stay off at cutover — a separate, unreviewed
            # trust surface (arbitrary apply.sh via /bin/sh -lc, no
            # sandboxing) staged for after cutover per-tool acceptance
            # testing. Community PALETTES need no enablement here at all and
            # are part of the UX regardless — they're picked in Noctalia's own
            # UI, orthogonal to this template whitelist (design note §Design).
            enable_community_templates = false;
          };
        };

        # `colors_changed` — fires after every template finishes writing; the
        # sole remaining Nix-declared theming hook (the `started` polarity
        # reconcile and the whole conductor it served are deleted). See
        # repaintHook above.
        hooks.colors_changed = lib.getExe repaintHook;

        idle = {
          # Nobody is at the desk when idle actions fire; the fade overlay
          # countdown is noise.
          pre_action_fade_seconds = 0;

          behavior = {
            lock = {
              enabled = true;
              timeout = 600;
              action = "lock";
            };
            screen-off = {
              enabled = true;
              timeout = 660;
              action = "screen_off";
            };
            # Guarded suspend (stance change, #644). Per-host flag: off by
            # default fleet-wide, the desktop hosts opt in. `action` strings
            # are NOT schema-validated (a typo silently becomes command mode)
            # — keep these exact.
            suspend = {
              enabled = hostContext.idleSuspend;
              timeout = 1800;
              action = "command";
              command = lib.getExe idleGuard;
            };
          };
        };
      };
    };

    # Lock before ANY suspend path (idle-fired, `systemctl suspend`, future
    # power-key) — the user-level half of the systemd-lock-handler bridge
    # (modules/nixos/lock-before-sleep.nix). Restores the guarantee the v4
    # gap relaxed, proven by probe S5's journal ordering.
    systemd.user.services.noctalia-lock-on-sleep = {
      Unit = {
        Description = "Engage the Noctalia lock before suspend";
        Before = [ "sleep.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe lockOnSleep;
      };
      Install.WantedBy = [ "sleep.target" ];
    };

    # notify-send (libnotify) — the CLI for emitting test notifications to
    # Noctalia, which owns org.freedesktop.Notifications (v5 default; it
    # throws if another daemon holds the name — fnott was decommissioned in
    # #385, so the name is free).
    #
    # wl-clipboard (wl-copy/wl-paste) — CLI clipboard access on the session
    # PATH. v5's clipboard is a native wlr-data-control implementation (no
    # cliphist, no wl-clipboard in its tree), so this exists purely for
    # non-OSC-52 CLI consumers that shell out to wl-copy (gh-dash's `y`,
    # scripts). See docs/desktop/clipboard.md (#360).
    home.packages = [
      pkgs.libnotify
      pkgs.wl-clipboard
    ];

    home.activation = {
      # One-time cleanup of the retired ADR-044 conductor's consumer-side
      # symlinks (#819 G5 cutover, home/nixos/theme-menu.nix deleted). Dangling
      # once the conductor is gone — harmless if left, but confusing residue,
      # and the palette-symlink path in particular sat where a GUI palette-save
      # writer could otherwise collide with it (docs/research/
      # noctalia-v5-palette-seam-review.md B2). Only ever removes a symlink,
      # never a plain file — a plain file at one of these paths means something
      # else has claimed it, and this must not touch it.
      themeMenuResidueCleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        for f in \
          "$HOME/.config/noctalia/palettes/theme-menu.json" \
          "$HOME/.config/gtk-3.0/theme-menu.css" \
          "$HOME/.config/gtk-4.0/theme-menu.css"
        do
          if [ -L "$f" ]; then
            $DRY_RUN_CMD rm -f "$f"
          fi
        done
      '';

      # Seed-if-absent: foot's include of the Noctalia-written theme file is
      # fatal while the file doesn't exist (activation → first theme resolve),
      # so new terminals would fail to launch in that window. An empty, writable
      # placeholder closes it; Noctalia overwrites the plain file at first
      # resolve. Seeds only when absent — a live theme file is never touched
      # (operator ruling, #824).
      noctaliaFootThemeSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        footTheme="$HOME/.config/foot/themes/noctalia"
        if [ ! -e "$footTheme" ] && [ ! -L "$footTheme" ]; then
          $DRY_RUN_CMD mkdir -p "$(dirname "$footTheme")"
          $DRY_RUN_CMD touch "$footTheme"
        fi
      '';
    };
  };
}
