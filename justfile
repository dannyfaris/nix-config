# nix-config — bootstrap & maintenance recipes.
#
# Codifies the operator-side workflow described in
# docs/decisions/ADR-022 (host install via nixos-anywhere + disko) and
# enforces the per-host file structure described in ADR-023.
#
# `just` itself is not yet a home-manager package in this repo. Install
# ad-hoc via `nix shell nixpkgs#just -c just <recipe>`, or run via
# `nix run nixpkgs#just -- <recipe>`. Adding `just` to home-manager is
# a separate question.
#
# Recipes with multi-line prose comments put the one-line docstring
# (the bit `just --list` shows) on the line directly above the recipe,
# separated from the longer context block by a blank line. `just` only
# picks up the contiguous comment block immediately above a recipe.

set shell := ["bash", "-euo", "pipefail", "-c"]

# Default: list available recipes.
default:
    @just --list

# Step 1 of 2 in the bootstrap flow (ADR-022 §Implementation). The
# operator manually updates .sops.yaml + secrets/secrets.yaml between
# this and `just bootstrap` — that step is deliberately out-of-band
# because YAML editing is fiddly enough that automating it would create
# more risk than it removes.

# Generate ed25519 host key + age recipient (bootstrap step 1).
gen-host-key host:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="/dev/shm/nix-bootstrap-{{host}}"
    if [[ -e "$tmp" ]]; then
        echo "ERROR: $tmp already exists." >&2
        echo "  Stale from a previous run? Clean with 'just bootstrap-clean' or" >&2
        echo "  remove manually: rm -rf $tmp" >&2
        exit 1
    fi
    # 700, not the 755 from ADR-022's example: this dir holds the private
    # host key. The key file is 600 either way; tightening the parent
    # avoids leaking the key's existence to other users on the operator
    # machine. Functionally equivalent to the ADR's prescribed workflow.
    install -d -m 700 "$tmp/etc/ssh"
    ssh-keygen -t ed25519 -N "" -C "{{host}}-host" \
        -f "$tmp/etc/ssh/ssh_host_ed25519_key" -q
    chmod 600 "$tmp/etc/ssh/ssh_host_ed25519_key"
    age_recipient=$(nix shell nixpkgs#ssh-to-age -c sh -c \
        "ssh-to-age < $tmp/etc/ssh/ssh_host_ed25519_key.pub")
    echo
    echo "Host key generated at $tmp/etc/ssh/ssh_host_ed25519_key"
    echo "(tmpfs, in-memory; cleaned automatically by 'just bootstrap')"
    echo
    echo "Age recipient for .sops.yaml:"
    echo "  $age_recipient"
    echo
    echo "Next steps:"
    echo "  1. Edit .sops.yaml — add the new host's anchor (preserving all"
    echo "     existing anchors) and include it in the relevant key_groups."
    echo "     Resulting shape:"
    echo "       keys:"
    echo "         - &nixos-vm   age1...                 # existing (keep)"
    echo "         - &{{host}}    $age_recipient   # NEW"
    echo "       creation_rules:"
    echo "         - path_regex: secrets/.*\\.yaml\$"
    echo "           key_groups:"
    echo "             - age:"
    echo "                 - *nixos-vm   # existing (keep)"
    echo "                 - *{{host}}   # NEW"
    echo
    echo "  2. Re-encrypt secrets for the expanded recipient set:"
    echo "       nix shell nixpkgs#sops -c sops updatekeys secrets/secrets.yaml"
    echo
    echo "  3. Commit and push:"
    echo "       git add .sops.yaml secrets/secrets.yaml"
    echo "       git commit -m 'sops: add {{host}} recipient'"
    echo "       git push"
    echo
    echo "  4. Run the install:"
    echo "       just bootstrap {{host}} <user>@<ip>"

# Step 2 of 2 in the bootstrap flow. Uses the host key staged by
# `just gen-host-key {{host}}`. Verifies sops decryption before
# invoking nixos-anywhere so that a forgotten sops update fails fast
# (loudly, locally) rather than producing a host with an empty
# hashedPasswordFile and broken sudo.

# Run nixos-anywhere with the staged host key (bootstrap step 2).
bootstrap host target:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="/dev/shm/nix-bootstrap-{{host}}"
    if [[ ! -f "$tmp/etc/ssh/ssh_host_ed25519_key" ]]; then
        echo "ERROR: no host key at $tmp." >&2
        echo "  Run 'just gen-host-key {{host}}' first." >&2
        exit 1
    fi
    # Two pre-flights with sharply different purposes:
    #   (1) is {{host}}'s recipient encoded in secrets/secrets.yaml? This
    #       catches the "operator forgot step 4" case directly. The age
    #       recipient string appears verbatim in sops's metadata block in
    #       the encrypted file, so a plain grep is sufficient.
    #   (2) does operator-side sops decryption work at all? Independent
    #       of (1) — catches a broken local age identity. Useful but
    #       narrow; without it (1) could silently rely on a stale-but-
    #       correct file the operator can't actually update.
    echo "=== Pre-flight 1: {{host}}'s recipient in secrets/secrets.yaml ==="
    new_recipient=$(nix shell nixpkgs#ssh-to-age -c sh -c \
        "ssh-to-age < $tmp/etc/ssh/ssh_host_ed25519_key.pub")
    if ! grep -qF "$new_recipient" secrets/secrets.yaml; then
        echo "ERROR: {{host}}'s age recipient not found in secrets/secrets.yaml." >&2
        echo "  Either step 4 (.sops.yaml + sops updatekeys) was skipped," >&2
        echo "  or secrets/secrets.yaml hasn't been re-encrypted for {{host}}." >&2
        echo "  Expected recipient: $new_recipient" >&2
        exit 1
    fi
    echo "  OK — recipient present"
    echo
    echo "=== Pre-flight 2: operator-side sops decryption ==="
    if ! nix shell nixpkgs#sops -c sops -d secrets/secrets.yaml > /dev/null 2>&1; then
        echo "ERROR: operator-side sops decryption failed." >&2
        echo "  Run 'just setup-sops-identity' first (one-time per fresh clone)." >&2
        exit 1
    fi
    echo "  OK — operator decrypts cleanly"
    echo
    echo "=== Running nixos-anywhere against {{target}} for host '{{host}}' ==="
    # Pinned to 1.13.0 (the release ADR-022 was validated against).
    # Bump deliberately when reviewing release notes — this is the
    # bootstrap path; a regression here can brick an install.
    #
    # --kexec-extra-flags --kexec-syscall forces the legacy kexec_load
    # syscall instead of kexec_file_load. Necessary on Ubuntu's -aws
    # kernels, which ship with CONFIG_KEXEC_BZIMAGE_VERIFY_SIG=y and
    # reject NixOS's unsigned bzImage with EADDRNOTAVAIL even when
    # Secure Boot is disabled and lockdown is none. Harmless on every
    # other kernel (kexec-tools' option parser is last-wins, so this
    # overrides nixos-anywhere's default --kexec-syscall-auto).
    nix run github:nix-community/nixos-anywhere/1.13.0 -- \
        --flake ".#{{host}}" \
        --target-host {{target}} \
        --extra-files "$tmp" \
        --kexec-extra-flags --kexec-syscall \
        --generate-hardware-config nixos-generate-config \
                                   "hosts/{{host}}/hardware-configuration.nix"
    echo
    echo "=== Bootstrap complete ==="
    # Cleanup only on success. Deliberate divergence from ADR-022's
    # `trap … EXIT` prescription: on failure we keep $tmp so the operator
    # can re-run `just bootstrap` without regenerating the key (which
    # would invalidate the recipient already committed to .sops.yaml).
    # If the bootstrap is being abandoned entirely, `just bootstrap-clean`
    # removes all staged keys.
    echo "Cleaning up $tmp"
    rm -rf "$tmp"
    echo
    echo "Review and commit the regenerated hardware-configuration.nix:"
    echo "  git diff hosts/{{host}}/hardware-configuration.nix"
    echo "  git add hosts/{{host}}/hardware-configuration.nix"

# Remove stale tmpfs scratch directories from gen-host-key.
bootstrap-clean:
    @rm -rf /dev/shm/nix-bootstrap-*
    @echo "Cleaned /dev/shm/nix-bootstrap-*"

# One-time-per-clone operator setup. Derives ~/.config/sops/age/keys.txt
# from /etc/ssh/ssh_host_ed25519_key (the VM's SSH host key, which IS
# this repo's sops decryption identity — same key sops-nix uses at
# activation time as root). sops doesn't read SSH host keys directly
# (perms + format quirks: SOPS_AGE_SSH_PRIVATE_KEY_FILE produced wrong
# age identities in sops 3.12.1 testing), so we pre-convert via
# ssh-to-age. Reqs sudo to read the SSH key.
#
# Without this, `sops -d` / `sops updatekeys` as dbf fail with
# "no identity matched any of the recipients."

# Set up ~/.config/sops/age/keys.txt from the VM's SSH host key (one-time).
setup-sops-identity:
    #!/usr/bin/env bash
    set -euo pipefail
    target=~/.config/sops/age/keys.txt
    if [[ -f "$target" ]]; then
        echo "Identity already at $target."
        echo "Remove it first if you want to regenerate."
        exit 0
    fi
    tmp=$(mktemp -d -p /dev/shm)
    trap 'rm -rf "$tmp"' EXIT
    echo "=== Reading /etc/ssh/ssh_host_ed25519_key (sudo required) ==="
    sudo cat /etc/ssh/ssh_host_ed25519_key > "$tmp/host-key"
    chmod 600 "$tmp/host-key"
    echo "=== Converting SSH key to age private key ==="
    nix shell nixpkgs#ssh-to-age -c \
        ssh-to-age -private-key -i "$tmp/host-key" -o "$tmp/age-key"
    install -d -m 700 ~/.config/sops/age
    install -m 600 "$tmp/age-key" "$target"
    echo
    echo "Installed: $target"
    echo "  sops -d / sops updatekeys will now work as dbf without env vars."

# Configure git to use this repo's .githooks/ directory (one-time per clone).
install-hooks:
    git config core.hooksPath .githooks
    @echo "Hooks installed (core.hooksPath=.githooks)."
    @echo "To uninstall: just uninstall-hooks"

# Revert to git's default .git/hooks/ directory.
uninstall-hooks:
    git config --unset core.hooksPath
    @echo "Hooks uninstalled (core.hooksPath unset)."
