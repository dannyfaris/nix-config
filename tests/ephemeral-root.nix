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
    main = commonNode;

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

          # Promote by snapshot: move the current @root aside, snapshot the
          # archived root into @root's place (never a raw mv — the copy boots,
          # the archive survives re-promotable). Then boot once with the
          # kill-switch so the promoted state is not immediately re-archived.
          toplevel_mount(promote)
          archived = sorted(promote.succeed("ls /tl/roots-archive").split())[-1]
          promote.succeed(f"test -e /tl/roots-archive/{archived}/promote-marker")
          promote.succeed("mv /tl/@root /tl/@root.aside")
          promote.succeed(
              f"btrfs subvolume snapshot /tl/roots-archive/{archived} /tl/@root"
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
