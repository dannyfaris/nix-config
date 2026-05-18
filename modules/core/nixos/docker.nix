# Rootless Docker — per-user dockerd for dbf. Imported per-host (currently
# Mercury only); NOT in the headless role because the UTM VM doesn't run
# containers and pulling docker into its closure for nothing would be
# wasteful.
#
# Resolves the deferred decision in ADR-006 § "Tool-vs-runtime split"
# ("docker daemon: deferred until the first project needs it"). Mercury
# is that first project. See ADR-021 for the rootless-over-rootful
# rationale and the system-wide CLI deviation from ADR-006's per-project
# devShells stance.
{ pkgs, ... }: {
  virtualisation.docker.rootless = {
    enable = true;
    # Sets DOCKER_HOST=unix:///run/user/$UID/docker.sock so the docker
    # CLI talks to the rootless daemon by default — without this the
    # CLI tries the rootful socket (which doesn't exist) and fails.
    setSocketVariable = true;
  };

  users.users.dbf = {
    # Rootless containers need subordinate uid/gid mappings declared in
    # /etc/subuid + /etc/subgid for newuidmap/newgidmap. The NixOS
    # rootless docker module does NOT auto-configure these — verified
    # against pkgs/nixos/modules/virtualisation/docker-rootless.nix at
    # the pinned nixpkgs revision (no assertion, no autosetting). The
    # 100000-165535 range is the conventional default that distros
    # using `useradd`'s automatic-subuid behaviour would assign.
    subUidRanges = [{ startUid = 100000; count = 65536; }];
    subGidRanges = [{ startGid = 100000; count = 65536; }];

    # systemd lingering: keep dbf's user-mode dockerd running across
    # session disconnects. Without this, the daemon stops when the
    # last SSH/mosh session closes — fine for interactive use, bad
    # for background containers that should outlive a disconnect.
    linger = true;
  };

  # docker-compose v2. The docker CLI itself is added to
  # environment.systemPackages by the rootless module automatically
  # (`environment.systemPackages = [ cfg.package ];` in the upstream
  # module — verified at the pinned nixpkgs revision). Adding
  # docker-compose here makes both `docker-compose` (standalone) and
  # `docker compose` (subcommand, via cli-plugins auto-discovery in
  # /run/current-system/sw/libexec/docker/cli-plugins/) available.
  environment.systemPackages = [ pkgs.docker-compose ];
}
