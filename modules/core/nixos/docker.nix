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

  # docker-compose v2 standalone binary. The `docker compose`
  # subcommand form already works without this — at the pinned nixpkgs
  # revision pkgs.docker is built with composeSupport = true and the
  # docker binary is wrapped with DOCKER_CLI_PLUGIN_DIRS pointing at
  # the bundled compose's own cli-plugins directory. So `docker compose
  # …` resolves through the wrapper, not via NixOS profile-merging
  # under /run/current-system/sw/libexec/.
  #
  # Adding pkgs.docker-compose here gives the standalone `docker-compose`
  # binary on PATH alongside the subcommand form, for scripts and
  # tooling that invoke the hyphenated name directly. One version
  # caveat: pkgs.docker-compose and the compose plugin bundled into
  # pkgs.docker can drift; `docker compose version` and
  # `docker-compose --version` may report different numbers.
  environment.systemPackages = [ pkgs.docker-compose ];
}
