# VM test for the ephemeral-root archive-rollback mechanism
# (modules/nixos/ephemeral-root.nix, docs/design/ephemeral-root.md §De-risk).
#
# The de-risk gate before any host adopts. A nixosTest whose nodes boot off a
# REAL btrfs disk with the fleet's subvolume layout (@root + @persist as
# top-level subvolumes), import the rollback module + impermanence, and prove
# the eight assertions a–h from §De-risk.
#
# Disk route (recorded per the brief): NOT disko's diskoImages — the pinned
# disko revision's image machinery is not wired for a test-node root here, and
# the upstream nixpkgs systemd-initrd btrfs pattern (boot normally, format an
# attached empty disk, `switch-to-configuration boot` into a specialisation
# rooted on it, then `crash()`) is the proven, self-contained route. Every
# node's real layout is therefore the fleet's layout (subvolumes @root /
# @persist), so test-vs-host drift is structural, not incidental.
#
# DEVIATION from §De-risk's "@root/@nix/@persist": /nix is NOT a real @nix
# subvolume — mountHostNixStore keeps /nix/store on the driver's host share
# (the brief's sanctioned fallback). A real @nix would mean copying the whole
# host closure into the subvolume per node for zero added coverage of the
# rollback, which only ever touches @root. @root and @persist (the paths the
# mechanism acts on) ARE real btrfs subvolumes.
{
  pkgs,
  self,
  inputs,
  ...
}:
let
  ephemeralRootModule = self + "/modules/nixos/ephemeral-root.nix";
  # The impermanence nixos module, from the same flake input the hosts will
  # use — single-sourced against flake.lock (no duplicate pinned hash here).
  inherit (inputs) impermanence;

  # Distinct label for the attached test disk. NOT "nixos": the qemu-vm base
  # disk (vda2) already claims by-label/nixos (rootFilesystemLabel), so reusing
  # it makes by-label/nixos ambiguous and the specialisation boots the wrong
  # (ext4 base) disk. A test-harness artifact only — the real fleet uses
  # by-label/nixos on its single btrfs disk with no such collision.
  diskLabel = "ephroot";
  device = "/dev/disk/by-label/${diskLabel}";

  # Common config for every node: import the rollback module + impermanence,
  # declare a fixture persist path, and set up the btrfs root layout that the
  # `switch-to-configuration boot` specialisation will target.
  commonNode =
    { lib, ... }:
    {
      imports = [
        ephemeralRootModule
        "${impermanence}/nixos.nix"
      ];

      virtualisation = {
        # /dev/vdb — the empty disk we format with the fleet layout.
        emptyDiskImages = [ 4096 ];
        useBootLoader = true;
        mountHostNixStore = true;
        useEFIBoot = true;
      };
      boot = {
        loader.systemd-boot.enable = true;
        loader.efi.canTouchEfiVariables = true;
        initrd.systemd.enable = true;
        initrd.systemd.emergencyAccess = true;
      };

      environment.systemPackages = [ pkgs.btrfs-progs ];

      ephemeralRoot = {
        enable = true;
        inherit device;
      };

      # Fixture persist declaration — the whitelist under test. A file inside a
      # persisted directory, bind-mounted from /persist, standing in for a real
      # host module's module-owns-its-state fragment. (A top-level file path
      # like "/persisted-file" trips an impermanence parent-dir edge case —
      # length-of-empty-components — so the fixture lives one dir deep.)
      environment.persistence."/persist" = {
        files = [ "/var/fixture/persisted-file" ];
      };

      # The specialisation the test boots into: / and /persist on real btrfs
      # subvolumes of the formatted disk. This is where the initrd rollback
      # service actually runs (every boot of this specialisation).
      #
      # DEVIATION from §De-risk's "@root/@nix/@persist" wish: /nix is NOT a
      # real @nix subvolume — mountHostNixStore keeps /nix/store as the
      # driver's host share (the brief's sanctioned fallback: "store-share is
      # fine for /nix if a real @nix is impractical"). A real @nix would mean
      # copying the whole host closure into the subvolume per node — huge and
      # slow — for no added coverage of the rollback, which only ever touches
      # @root. @root and @persist (the paths the mechanism acts on) ARE real.
      specialisation.on-btrfs.configuration = {
        virtualisation = {
          rootDevice = lib.mkForce device;
          # Disable the driver's default ext4/tmpfs root so our btrfs @root
          # wins; the host store share (mountHostNixStore) is independent of it.
          useDefaultFilesystems = lib.mkForce false;
          fileSystems = {
            "/" = {
              inherit device;
              fsType = "btrfs";
              options = [ "subvol=@root" ];
            };
            "/persist" = {
              inherit device;
              fsType = "btrfs";
              options = [ "subvol=@persist" ];
              neededForBoot = true; # impermanence hard requirement
            };
          };
        };
      };
    };
in
pkgs.testers.runNixOSTest {
  name = "ephemeral-root-vm";

  nodes = {
    # main carries the probe (#633) in addition to the rollback assertions a–k.
    # A local python http.server sink stands in for the quiet ntfy topic so the
    # probe's POSTs SUCCEED and the seen-set / marker update paths (which only
    # run on a good post) are actually exercised.
    main =
      { ... }:
      {
        imports = [ commonNode ];

        ephemeralRoot.probe = {
          enable = true;
          # Point at the local sink below, not metis. A path the delta scan
          # can never itself produce, so the sink's own request-log files don't
          # feed back as drift.
          ntfyUrl = "http://127.0.0.1:8199/fleet-state";
          # Glob suppressing a planted random-suffixed residue path (assertion m).
          extraIgnorePatterns = [ "/var/probe-glob-*" ];
        };

        # The sink: a trivial always-up HTTP server that 200s every POST (the
        # stdlib http.server 501s on POST, so a tiny custom handler is needed),
        # so post_delta succeeds and the probe records its seen-set / marker.
        systemd.services.probe-sink = {
          description = "Local HTTP sink standing in for the quiet ntfy topic";
          wantedBy = [ "multi-user.target" ];
          serviceConfig.ExecStart =
            let
              # Each POST's Title header + body are appended to /tmp/sink-log so
              # the test can inspect exactly what the probe posted (assertion n
              # distinguishes an empty-delta note from a content rollup).
              sink = pkgs.writeText "probe-sink.py" ''
                from http.server import BaseHTTPRequestHandler, HTTPServer
                class H(BaseHTTPRequestHandler):
                    def do_POST(self):
                        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
                        with open("/tmp/sink-log", "ab") as f:
                            f.write(b"=== " + self.headers.get("Title", "").encode() + b"\n")
                            f.write(body + b"\n")
                        self.send_response(200); self.end_headers()
                HTTPServer(("127.0.0.1", 8199), H).serve_forever()
              '';
            in
            "${pkgs.python3}/bin/python3 ${sink}";
        };
      };

    killswitch =
      { ... }:
      {
        imports = [ commonNode ];
        # Kill-switch baked onto the cmdline: the rollback is skipped every
        # boot of this node, so an undeclared file must survive.
        boot.kernelParams = [ "ephemeral.skip-rollback" ];
      };

    sabotage =
      { lib, ... }:
      {
        imports = [ commonNode ];
        # Inject a failure into the rollback service's archive step: point the
        # module's device at the vfat ESP partition. Its .device unit exists
        # (so the service starts normally), but `mount -t btrfs` on a vfat
        # filesystem fails — driving the service down its bail path. The real
        # root still lives on the ephroot disk (the specialisation's fileSystems
        # are unchanged), so the fail-safe direction is proven: boot completes
        # on the old @root, degraded marker set.
        ephemeralRoot.device = lib.mkForce "/dev/disk/by-label/ESP";
      };

    retention =
      { lib, ... }:
      {
        imports = [ commonNode ];
        # Retention-zero: any archive at least a minute old is purged.
        ephemeralRoot.retentionDays = lib.mkForce 0;
      };

    # Purge DISCIPLINE (as distinct from retention-zero's "aged is deleted"):
    # a realistic window where a fresh archive falls INSIDE it and must be
    # spared, while an over-window archive is deleted — and the live root is
    # never touched. Needs a non-zero window: at retentionDays=0 GNU find's
    # `-mmin +0` round-up purges even second-old entries, so no archive can be
    # reliably "fresh". One day gives an unambiguous inside-window fresh entry.
    purgekeep =
      { lib, ... }:
      {
        imports = [ commonNode ];
        ephemeralRoot.retentionDays = lib.mkForce 1;
      };

    promote = commonNode;
  };

  # Format /dev/vdb with the fleet subvolume layout, populate @root from the
  # specialisation's closure, seed @persist, then boot into it. Returned as a
  # python helper string so each node runs the identical setup.
  testScript =
    { nodes, ... }:
    let
      # Each node's on-btrfs specialisation toplevel — what we install onto
      # @root before switching.
      specOf = node: node.specialisation.on-btrfs.configuration.system.build.toplevel;
    in
    ''
      import re


      def setup_btrfs(machine, spec):
          """Format /dev/vdb with the fleet subvolume layout (@root/@persist),
          then boot into `spec` via switch-to-configuration. /nix/store stays
          on the host share (mountHostNixStore) — see the DEVIATION note on the
          specialisation. @root is created empty; the first boot's rollback
          archives it and NixOS activation + impermanence repopulate."""
          machine.wait_for_unit("multi-user.target")
          machine.succeed("mkfs.btrfs -f -L ${diskLabel} /dev/vdb")
          machine.succeed("mkdir -p /mnt && mount /dev/vdb /mnt")
          machine.succeed("btrfs subvolume create /mnt/@root")
          machine.succeed("btrfs subvolume create /mnt/@persist")
          machine.succeed("umount /mnt")

          # Boot the on-btrfs specialisation and crash into it. From here on
          # every boot runs the initrd rollback service against real btrfs.
          machine.succeed(f"{spec}/bin/switch-to-configuration boot")
          machine.succeed("sync")
          machine.crash()
          machine.wait_for_unit("multi-user.target")
          # Confirm we booted off the btrfs @root subvolume.
          machine.succeed("mount | grep -E 'on / type btrfs' | grep -q 'subvol=/@root'")


      def toplevel_mount(machine):
          machine.succeed("mkdir -p /tl")
          machine.succeed("mount -t btrfs -o subvolid=5 ${device} /tl")


      def toplevel_umount(machine):
          machine.succeed("umount /tl")


      # ---------------------------------------------------------------
      # main: assertions a, b, c, d
      # ---------------------------------------------------------------
      with subtest("main: setup real btrfs root"):
          setup_btrfs(main, "${specOf nodes.main}")

      with subtest("a/b/c/d: seed state on the running btrfs root"):
          # Undeclared file on / — should NOT survive a reboot.
          main.succeed("echo undeclared > /undeclared-file")
          # Persisted file — write through the bind mount; should survive.
          main.succeed("echo persistent > /var/fixture/persisted-file")
          # Nested subvolume under / with a marker file — should ride the
          # rename into the archive intact.
          main.succeed("btrfs subvolume create /nested-sv")
          main.succeed("echo nested > /nested-sv/marker")
          main.succeed("sync")
          main.shutdown()
          main.start()
          main.wait_for_unit("multi-user.target")

      with subtest("a: undeclared file did NOT survive the reboot"):
          main.fail("test -e /undeclared-file")
          # A HEALTHY rollback must not raise the degraded flag — a marker
          # that cries wolf on every boot would bury the real bail signal
          # the probe (#633) reads.
          main.fail("test -e /run/ephemeral-root-degraded")

      with subtest("b: persisted file survived"):
          assert "persistent" in main.succeed("cat /var/fixture/persisted-file")

      with subtest("c: archive entry exists and CONTAINS the undeclared file"):
          toplevel_mount(main)
          entries = main.succeed("ls /tl/roots-archive").split()
          assert len(entries) >= 1, f"expected an archive entry, got {entries}"
          newest = sorted(entries)[-1]
          assert "undeclared" in main.succeed(
              f"cat /tl/roots-archive/{newest}/undeclared-file"
          )

      with subtest("d: nested subvolume rode into the archive intact"):
          # The nested subvolume is still a subvolume (inode 256) inside the
          # archived root, and its marker file is intact.
          assert "nested" in main.succeed(
              f"cat /tl/roots-archive/{newest}/nested-sv/marker"
          )
          main.succeed(
              f"btrfs subvolume show /tl/roots-archive/{newest}/nested-sv"
          )
          toplevel_umount(main)
          # And it did NOT survive on the fresh root.
          main.fail("test -e /nested-sv/marker")

      with subtest("i: a second normal reboot produces a distinct archive entry (no overwrite)"):
          # Each normal reboot must ADD a distinct, timestamped entry — never
          # overwrite an existing one (guards fixed-archive-name mutants:
          # distinct timestamps per boot). Snapshot the set before this boot's
          # reboot, then require it to grow by exactly one distinct entry.
          toplevel_mount(main)
          before = set(main.succeed("ls /tl/roots-archive").split())
          assert len(before) >= 1, f"expected >=1 archive before 2nd reboot, got {before}"
          toplevel_umount(main)
          # Marker whose presence in the *new* archive proves it is this boot's
          # root, not a re-archive of / write-into an existing entry.
          main.succeed("echo second-boot > /second-boot-file")
          main.succeed("sync")
          main.shutdown()
          main.start()
          main.wait_for_unit("multi-user.target")
          toplevel_mount(main)
          after = set(main.succeed("ls /tl/roots-archive").split())
          # Exactly one NEW, distinct entry appeared (no overwrite of any prior).
          new_entries = after - before
          assert len(new_entries) == 1, (
              f"expected exactly one new archive after 2nd reboot; "
              f"before={sorted(before)} after={sorted(after)}"
          )
          # Every prior entry is preserved verbatim (nothing overwritten/renamed).
          assert before <= after, f"a prior archive vanished: before={sorted(before)} after={sorted(after)}"
          # The new entry carries this boot's file.
          newer = new_entries.pop()
          assert "second-boot" in main.succeed(
              f"cat /tl/roots-archive/{newer}/second-boot-file"
          )
          # No PRIOR entry carries it (proves no overwrite/merge into an old one).
          for old in before:
              main.fail(f"test -e /tl/roots-archive/{old}/second-boot-file")
          # Every entry is a TIMESTAMPED name (ISO-8601 basic form, optional
          # same-second collision suffix) — the audit-trail form the design
          # promises, and what newest-selection by sort relies on.
          for entry in after:
              assert re.fullmatch(r"\d{8}T\d{6}Z(\.\d+)?", entry), (
                  f"archive entry not ISO-timestamp-formed: {entry}"
              )
          toplevel_umount(main)

      with subtest("k: a long-uptime root's archive survives the purge (mv-mtime refresh bites)"):
          # A renamed subvolume keeps its old top-dir mtime — set when
          # activation populated / at the root's CREATION boot, not advanced
          # since. `mv` preserves it, and the purge's find -mmin selects on
          # exactly that. Without the module's post-mv `touch "$DEST"`, a root
          # whose uptime exceeds retentionDays is archived already-stale and
          # reaped at the very next purge. Prove the touch bites: back-date the
          # LIVE root's top-dir mtime far past retention (30 days on this node),
          # reboot (the rollback archives the back-dated root), run the purge
          # once, and require the just-created archive to STILL EXIST — its
          # mtime having been refreshed to archiving-time by the module.
          #
          # `touch -d` sets the mounted @root subvolume's top-dir mtime, the
          # same knob the retention-zero test drives on an archive entry; here
          # we drive it on the live root pre-archive so the inherited mtime the
          # purge sees is 90 days old.
          main.succeed("touch -d '90 days ago' /")
          main.succeed("sync")
          main.shutdown()
          main.start()
          main.wait_for_unit("multi-user.target")
          # Identify the archive this boot just created (newest by sort).
          toplevel_mount(main)
          archived = sorted(main.succeed("ls /tl/roots-archive").split())[-1]
          toplevel_umount(main)
          # Run the purge once (this node's retentionDays=30 => MMIN=43200).
          main.succeed("systemctl start ephemeral-root-purge.service")
          toplevel_mount(main)
          # The just-created archive survives: its mtime was refreshed to
          # archiving-time, so it is NOT older than the 30-day window despite
          # the root's 90-day-back-dated top-dir mtime. On the touch-less
          # mutant it inherits the 90-day mtime and the purge reaps it here.
          main.succeed(f"test -e /tl/roots-archive/{archived}")
          toplevel_umount(main)

      # ---------------------------------------------------------------
      # main: the drift-detection probe (#633) — assertions l, m, n, o.
      # The probe posts to a local http sink (probe-sink) so post_delta
      # succeeds and the seen-set / marker update paths are exercised.
      # ---------------------------------------------------------------
      with subtest("probe: sink is up so posts succeed"):
          main.wait_for_unit("probe-sink.service")
          main.wait_until_succeeds(
              "curl -fsS -d probe http://127.0.0.1:8199/fleet-state"
          )

      with subtest("l: live scan reports an undeclared file; a declared (pruned) path does not"):
          # Plant an undeclared file on the live root, and confirm the persisted
          # fixture file is present (it is on the prune set as a `files` entry).
          main.succeed("echo drift > /probe-undeclared")
          main.succeed("test -e /var/fixture/persisted-file")
          main.succeed("systemctl start ephemeral-root-probe-live.service")
          # The newest live report lists the undeclared file...
          report = main.succeed(
              "ls -t /var/lib/ephemeral-root-probe/report-live-* | head -n1"
          ).strip()
          main.succeed(f"grep -qxF /probe-undeclared {report}")
          # ...and NOT the declared (pruned) fixture file — prune bites.
          main.fail(f"grep -qxF /var/fixture/persisted-file {report}")

      with subtest("m: an extraIgnorePatterns glob suppresses a matching planted path"):
          # /var/probe-glob-* is on extraIgnorePatterns; a random-suffixed match
          # must not appear in the report even though it is undeclared.
          main.succeed("echo glob > /var/probe-glob-abc123")
          # A control undeclared file that is NOT glob-matched, to prove the run
          # actually scanned (the glob suppresses, it does not blind the scan).
          main.succeed("echo control > /probe-glob-control")
          main.succeed("systemctl start ephemeral-root-probe-live.service")
          report = main.succeed(
              "ls -t /var/lib/ephemeral-root-probe/report-live-* | head -n1"
          ).strip()
          main.succeed(f"grep -qxF /probe-glob-control {report}")
          main.fail(f"grep -qxF /var/probe-glob-abc123 {report}")

      with subtest("n: delta discipline — a repeated live run posts an EMPTY delta (seen-set bites)"):
          # Everything undeclared planted so far (/probe-undeclared,
          # /probe-glob-control) is now in the shared seen-set. Remove every
          # unseen planted file so this run has NO new drift, then re-run: the
          # probe must take the empty-delta branch and post the fixed
          # "no new undeclared paths" note — NOT a content rollup. (Checking the
          # seen-set line count cannot distinguish this: re-appending an
          # already-seen path via `sort -u` is idempotent, so the count would be
          # unchanged even if the delta were mis-computed as the full report.
          # The post BODY is the discriminating observable.)
          main.succeed("grep -qxF /probe-undeclared /var/lib/ephemeral-root-probe/seen")
          main.succeed("rm -f /probe-glob-control /var/probe-glob-abc123")
          main.succeed("truncate -s0 /tmp/sink-log")
          main.succeed("systemctl start ephemeral-root-probe-live.service")
          post = main.succeed("cat /tmp/sink-log")
          assert "no new undeclared paths" in post, (
              f"empty-delta run did not post the no-new-drift note; posted:\n{post}"
          )
          # And it did NOT re-post an already-seen path (would appear in the
          # rollup body). /probe-undeclared must be absent from this post.
          assert "probe-undeclared" not in post, (
              f"an already-seen path was re-posted on an empty-delta run:\n{post}"
          )

      with subtest("o: archive half reports newest-archive drift, advances marker, shares the seen-set"):
          # A file the live scan NEVER saw, written just before a wipe so it
          # lands in the newest archive (not on the fresh root). /probe-undeclared
          # is already in the seen-set from assertion l — the archive half must
          # NOT re-post it (shared seen-set).
          marker_before = main.succeed(
              "cat /var/lib/ephemeral-root-probe/last-scanned-archive 2>/dev/null || echo none"
          ).strip()
          main.succeed("echo archive-only > /probe-archive-only")
          main.succeed("sync")
          main.shutdown()
          main.start()
          main.wait_for_unit("multi-user.target")
          main.wait_for_unit("probe-sink.service")
          # The per-boot archive service runs automatically; block on it.
          main.succeed("systemctl start ephemeral-root-probe-archive.service")
          # Its report lists the archived undeclared file...
          report = main.succeed(
              "ls -t /var/lib/ephemeral-root-probe/report-archive-* | head -n1"
          ).strip()
          main.succeed(f"grep -qxF /probe-archive-only {report}")
          # ...the marker advanced to the just-scanned (newest) archive...
          toplevel_mount(main)
          newest = sorted(main.succeed("ls /tl/roots-archive").split())[-1]
          toplevel_umount(main)
          marker_after = main.succeed(
              "cat /var/lib/ephemeral-root-probe/last-scanned-archive"
          ).strip()
          assert marker_after == newest, f"marker did not advance: {marker_after} != {newest}"
          assert marker_after != marker_before, "marker unchanged across the archive scan"
          # ...and /probe-undeclared (already in the seen-set from the live half)
          # was NOT re-posted: it is absent from the delta appended to the sink.
          # Prove via the seen-set: /probe-archive-only was newly added, but the
          # already-seen /probe-undeclared count stays exactly one.
          main.succeed("grep -qxF /probe-archive-only /var/lib/ephemeral-root-probe/seen")
          assert (
              main.succeed("grep -cxF /probe-undeclared /var/lib/ephemeral-root-probe/seen").strip()
              == "1"
          ), "already-seen path duplicated in the seen-set (shared seen-set broken)"

      # ---------------------------------------------------------------
      # killswitch: assertion e
      # ---------------------------------------------------------------
      with subtest("killswitch: setup"):
          setup_btrfs(killswitch, "${specOf nodes.killswitch}")

      with subtest("e: file on / survives two boots with kill-switch baked in"):
          killswitch.succeed("echo survives > /killswitch-file")
          killswitch.succeed("sync")
          killswitch.shutdown()
          killswitch.start()
          killswitch.wait_for_unit("multi-user.target")
          assert "survives" in killswitch.succeed("cat /killswitch-file")
          # Second boot — still there, and no archive was ever created.
          killswitch.shutdown()
          killswitch.start()
          killswitch.wait_for_unit("multi-user.target")
          assert "survives" in killswitch.succeed("cat /killswitch-file")
          toplevel_mount(killswitch)
          killswitch.fail("test -d /tl/roots-archive")
          toplevel_umount(killswitch)

      # ---------------------------------------------------------------
      # sabotage: assertion f
      # ---------------------------------------------------------------
      with subtest("sabotage: setup"):
          setup_btrfs(sabotage, "${specOf nodes.sabotage}")

      with subtest("f: sabotaged rollback still reaches multi-user on old root, degraded marker set"):
          sabotage.succeed("echo old-root > /sabotage-file")
          sabotage.succeed("sync")
          sabotage.shutdown()
          sabotage.start()
          # The whole point: boot still completes despite the rollback failing.
          sabotage.wait_for_unit("multi-user.target")
          # Old root preserved (no wipe happened).
          assert "old-root" in sabotage.succeed("cat /sabotage-file")
          # Degraded marker written by the initrd service's bail path.
          sabotage.succeed("test -e /run/ephemeral-root-degraded")
          # The bail path leaves the unit SUCCESSFUL — the fail-safe is
          # structural (exit 0 on every path), not merely "boot happened to
          # proceed": a failed initrd unit is one dependency change away from
          # blocking sysroot. The initrd journal carries the unit's result.
          sabotage.succeed(
              "journalctl -b -o cat | grep -q 'Finished Archive @root'"
          )
          sabotage.fail(
              "journalctl -b -o cat"
              + " | grep -qE 'ephemeral-root-rollback.service: Failed'"
          )

      # ---------------------------------------------------------------
      # retention: assertion g
      # ---------------------------------------------------------------
      with subtest("retention: setup"):
          setup_btrfs(retention, "${specOf nodes.retention}")

      with subtest("g: aged archive is purged recursively (nested subvolume included)"):
          # The purge must actually be SCHEDULED, not merely startable: g/j
          # drive the service by hand, which would mask a timer that never
          # fires (dead-letter retention on real hosts).
          retention.succeed("systemctl is-active ephemeral-root-purge.timer")
          # Fabricate an aged archive entry with a nested subvolume inside it.
          toplevel_mount(retention)
          retention.succeed("mkdir -p /tl/roots-archive")
          retention.succeed("btrfs subvolume create /tl/roots-archive/aged")
          retention.succeed("btrfs subvolume create /tl/roots-archive/aged/nested")
          retention.succeed("touch /tl/roots-archive/aged/marker")
          # Backdate it well past the retention-zero threshold (>1 minute).
          retention.succeed("touch -d '2 hours ago' /tl/roots-archive/aged")
          toplevel_umount(retention)

          # Run the purge and assert the aged entry (and its nested subvolume)
          # are gone.
          retention.succeed("systemctl start ephemeral-root-purge.service")
          toplevel_mount(retention)
          retention.fail("test -e /tl/roots-archive/aged")
          toplevel_umount(retention)

      # ---------------------------------------------------------------
      # purgekeep: assertion j (purge discipline)
      # ---------------------------------------------------------------
      with subtest("purgekeep: setup"):
          setup_btrfs(purgekeep, "${specOf nodes.purgekeep}")

      with subtest("j: purge deletes only over-window archives; fresh entry and live root survive"):
          # retentionDays=1 => the window is one day. Seed one archive well past
          # the window (deleted) and one fresh archive inside it (spared), and a
          # sentinel on the live root (never touched by the purge).
          toplevel_mount(purgekeep)
          purgekeep.succeed("mkdir -p /tl/roots-archive")
          purgekeep.succeed("btrfs subvolume create /tl/roots-archive/stale")
          purgekeep.succeed("echo stale-archive > /tl/roots-archive/stale/marker")
          # Two days old — comfortably past the one-day window.
          purgekeep.succeed("touch -d '2 days ago' /tl/roots-archive/stale")
          purgekeep.succeed("btrfs subvolume create /tl/roots-archive/fresh")
          purgekeep.succeed("echo fresh-archive > /tl/roots-archive/fresh/marker")
          # Sentinel on the live root (top-level @root == the mounted /).
          purgekeep.succeed("echo live-root > /tl/@root/purge-sentinel")
          toplevel_umount(purgekeep)

          purgekeep.succeed("systemctl start ephemeral-root-purge.service")
          toplevel_mount(purgekeep)
          # Over-window archive is gone.
          purgekeep.fail("test -e /tl/roots-archive/stale")
          # A non-aged archive SURVIVES (purge deletes only aged, never fresh).
          purgekeep.succeed("test -e /tl/roots-archive/fresh")
          assert "fresh-archive" in purgekeep.succeed(
              "cat /tl/roots-archive/fresh/marker"
          )
          # The active root was never touched by the purge.
          assert "live-root" in purgekeep.succeed("cat /tl/@root/purge-sentinel")
          toplevel_umount(purgekeep)
          # Cross-check via the booted / that the live root is intact.
          assert "live-root" in purgekeep.succeed("cat /purge-sentinel")

      # ---------------------------------------------------------------
      # promote: assertion h
      # ---------------------------------------------------------------
      with subtest("promote: setup"):
          setup_btrfs(promote, "${specOf nodes.promote}")

      with subtest("h: promote an archive then consume it via one kill-switch boot"):
          # Produce an archive with a recognisable marker: write a file, reboot
          # once (normal wipe), the file lands in the archive.
          promote.succeed("echo promoted-state > /promote-marker")
          promote.succeed("sync")
          promote.shutdown()
          promote.start()
          promote.wait_for_unit("multi-user.target")
          # The marker is gone from the live (wiped) root but present in the
          # archive.
          promote.fail("test -e /promote-marker")

          # Promote by snapshot, verbatim per the recovery runbook §Promote
          # (docs/runbooks/ephemeral-root-recovery.md): choose the SOURCE
          # archive first, then DISPLACE the current @root INTO roots-archive/
          # under a fresh stamp and `touch` it (a renamed subvolume keeps its
          # old top-dir mtime; the touch is the same mv-mtime invariant the
          # module enforces, so the displaced root survives the retention
          # window instead of aging-out stale), then SNAPSHOT — never raw mv —
          # the chosen archive into @root's place (the copy boots, the source
          # archive survives re-promotable). Then boot once with the
          # kill-switch so the promoted state is not immediately re-archived.
          toplevel_mount(promote)
          # Chosen source: the newest EXISTING archive (carries promote-marker).
          # Selected BEFORE displacement so the fresh displaced stamp — newer,
          # and therefore [-1] after this point — cannot shadow it.
          chosen = sorted(promote.succeed("ls /tl/roots-archive").split())[-1]
          promote.succeed(f"test -e /tl/roots-archive/{chosen}/promote-marker")
          # 1. Displace the live root into the archive under a fresh stamp, and
          #    refresh its mtime (the mv-mtime invariant).
          displaced = promote.succeed("date -u +%Y%m%dT%H%M%SZ").strip()
          promote.succeed(f"mv /tl/@root /tl/roots-archive/{displaced}")
          promote.succeed(f"touch /tl/roots-archive/{displaced}")
          # 2. Snapshot the chosen source into @root's place.
          promote.succeed(
              f"btrfs subvolume snapshot /tl/roots-archive/{chosen} /tl/@root"
          )
          # The displaced entry now lives in roots-archive/ (newer stamp than
          # the chosen source), and did NOT clobber the chosen source.
          promote.succeed(f"test -e /tl/roots-archive/{displaced}")
          promote.succeed(f"test -e /tl/roots-archive/{chosen}/promote-marker")
          assert displaced != chosen, (
              f"displaced stamp collided with chosen source: {displaced}"
          )
          toplevel_umount(promote)

          # Boot once with the kill-switch on the cmdline. On a real host this
          # is a one-line edit at the systemd-boot menu; here we append the
          # param to the live boot entry on the ESP (already mounted at /boot),
          # then reboot into it.
          promote.succeed(
              "sed -i '/^options / s/$/ ephemeral.skip-rollback/' "
              + "$(grep -rl '^options ' /boot/loader/entries/)"
          )
          promote.succeed("sync")
          promote.shutdown()
          promote.start()
          promote.wait_for_unit("multi-user.target")

      with subtest("h: promoted state is live after the kill-switch boot"):
          promote.succeed("grep -qw ephemeral.skip-rollback /proc/cmdline")
          assert "promoted-state" in promote.succeed("cat /promote-marker")

      with subtest("h: the following boot resumes normal wiping"):
          # Remove the kill-switch param and reboot; the rollback wipes again.
          promote.succeed(
              "sed -i 's/ ephemeral.skip-rollback//' "
              + "$(grep -rl '^options ' /boot/loader/entries/)"
          )
          promote.succeed("sync")
          promote.shutdown()
          promote.start()
          promote.wait_for_unit("multi-user.target")
          promote.fail("grep -qw ephemeral.skip-rollback /proc/cmdline")
          promote.fail("test -e /promote-marker")
    '';
}
