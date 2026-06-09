# Removable media access

Plug in a USB drive → it auto-mounts → it's browsable, on the niri desktop on metis (#105). Scope is *removable* block storage (USB sticks, SD cards, external disks). Virtual backends (phone MTP/PTP, SMB/NFS network shares, `trash://`) are out of scope — they need gvfs and a GTK file manager, neither of which this stack carries.

## Premise correction — mostly independent of #103

The issue framed this as depending on the graphical-authentication agent (#103). It mostly doesn't: udisks2's default polkit policy makes *removable*-media mounting **passwordless** for the active local session (`org.freedesktop.udisks2.filesystem-mount` and `eject-media` default to `allow_active = yes`). So plugging in a USB stick does **not** invoke the mate-polkit agent at all. The agent only engages for *internal/system* disks (`filesystem-mount-system` = `auth_admin`), fstab devices, LUKS-on-system, or mounts requested from an inactive/SSH session. This work therefore needs neither #103 to land nor a `storage`-group polkit rule (which would weaken the whitelist posture for no benefit on removable media).

## Selection

- **System: `services.udisks2.enable`** — the daemon that exposes block devices and performs the mount (to `/run/media/$USER/<label>`), plus the userspace filesystem helpers it shells out to: **`exfatprogs`** (exFAT), **`ntfs3g`** (NTFS), **`dosfstools`** (FAT). In `modules/nixos/removable-media.nix`, via the system desktop-env bundle.
- **Home: `services.udiskie`** (`automount`, `notify`, **`tray = "never"`**) — the user daemon that auto-mounts on insert and pops fnott notifications. Plus the **`mount.yazi`** plugin for in-yazi unmount/eject. In `home/nixos/removable-media.nix`, via the home desktop-env bundle.
- **Browse surface: yazi** — already installed; auto-mounts land at `/run/media/$USER/<label>` and yazi browses them like any path. No GUI file manager and no gvfs.

## Rationale

**udisks2 is the foundation, but doesn't auto-mount by itself.** It exposes and mounts devices over D-Bus, but bare udisks2 means running `udisksctl mount` by hand. **udiskie** is the de-facto automount daemon across the minimal-Wayland (sway/Hyprland/wlroots) ecosystem — it watches for device-add and issues the mount, giving the "just plug it in" behaviour the issue asks for. No niri-authored doc blesses it by name, but the ecosystem convergence is strong and there is no compositor-specific alternative (the only other option, `udisksctl`, is manual, not a daemon).

**Tray-less is the principled minimal pick.** udiskie can show a tray icon (eject affordance + click-to-open), but the home-manager default `tray = "auto"` hard-`Requires` a `tray.target` that home-manager's waybar does **not** register — the single most common udiskie-on-NixOS failure ("Unit tray.target not found"). `tray = "never"` drops that dependency entirely while **keeping notifications** (they go over the `org.freedesktop.Notifications` D-Bus interface that fnott provides, independent of the tray). The eject affordance the tray would have given is provided instead by the mount.yazi plugin — so nothing is lost and the ordering fragility is sidestepped.

**yazi is a complete browse surface — no GUI file manager, no gvfs.** Once udiskie auto-mounts, `/run/media/$USER/<label>` is an ordinary local path; the already-installed yazi browses it. gvfs is only needed for GTK file managers and *virtual* backends (MTP/SMB/network) — not for plain block-device USB mounts. Adding the **`mount.yazi`** plugin (wraps `udisksctl` + `lsblk`) gives in-TUI mount/unmount/**eject**, which is the safe-removal path given we run tray-less. It's Linux-only, so it lives in the nixos yazi module rather than the cross-platform `cli-utils.nix`.

**The filesystem helpers are named explicitly (whitelist > blanket).** exFAT, NTFS, and FAT are all common on USB sticks; udisks2 shells out to userspace helpers for them, which must be on the system PATH. `exfatprogs` is the current exFAT package (the old `exfat`/`exfat-utils` FUSE packages are deprecated); `ntfs3g` gives reliable NTFS read-write (udisks2 prefers it over the in-kernel `ntfs3` driver when present, which has documented mount quirks); `dosfstools` covers FAT.

## Alternatives considered

**A GUI file manager (Nautilus/Thunar) + gvfs.** The "fuller desktop" path — built-in mount integration and virtual backends. Passed over: it pulls a GTK file manager + gvfs closure for a capability yazi already covers, against the minimal/TUI posture. gvfs earns its place only if phone/MTP or network shares become a need; revisit then.

**udiskie with the tray wired into waybar.** Gives the tray icon + click-to-open. Passed over for `tray = "never"`: it requires making waybar provide `tray.target` with correct ordering — the documented fragility above — for an affordance the mount.yazi plugin already covers. Easy to revisit if a tray icon is wanted later.

**Bare udisks2 + manual `udisksctl` (no automount).** Rejected against the issue's explicit "have it mount" ask — no daemon means manual mounting every time. (Manual mount/unmount is still available via the mount.yazi plugin for deliberate control.)

**ntfs3 (kernel) vs ntfs-3g (FUSE).** Both work; udisks2 prefers ntfs-3g when present, and the kernel `ntfs3` driver has documented udisks mount-quirk reports, so `ntfs3g` is the pragmatic hedge.

## Configuration

**System — `modules/nixos/removable-media.nix`** (system desktop-env bundle):

- `services.udisks2.enable = true`.
- `environment.systemPackages`: `exfatprogs`, `ntfs3g`, `dosfstools`.

**Home — `home/nixos/removable-media.nix`** (home desktop-env bundle):

- `services.udiskie` — `automount = true`, `notify = true`, `tray = "never"`.
- `programs.yazi.plugins.mount = pkgs.yaziPlugins.mount` + a `keymap.mgr.prepend_keymap` row binding `M` → `plugin mount` (yazi 26.5 uses the `mgr` keymap section). This is yazi-internal config, not a niri/system bind, so it does not go through the keybinds.md namespace taxonomy.

## Sharp edges

**No click-to-open without the tray.** `tray = "never"` means there's no tray icon to click "browse"/"eject" from. Browsing is `cd /run/media/$USER/<label>` (or navigate there in yazi); eject is the mount.yazi plugin (`M`) or `udisksctl power-off`. This is the accepted trade for dropping the tray.target fragility.

**Data loss on yank.** Auto-mount does not auto-sync-on-remove; pulling a stick without unmounting risks loss on write-back filesystems. Eject is passwordless, so use the mount.yazi `M` affordance (or `udisksctl unmount`/`power-off`) before unplugging.

**exFAT/NTFS won't mount if a helper is missing.** Covered by the three helpers above; if a future filesystem (e.g. btrfs/f2fs on a stick) won't mount, its helper needs adding to the system list.

**Smoke-test on metis at activation.** Build-time eval can't drive a real USB. After `nh os switch`, insert a stick and confirm: it auto-mounts (fnott notification appears), it's browsable under `/run/media/$USER/<label>` in yazi, and `M` → `plugin mount` lists/unmounts/ejects it. Check `systemctl --user status udiskie` if nothing happens.

**`/run/media/$USER` is 0700, owned by the mounting user** — cross-user access is intentionally denied; correct by default.

## References

- udisks2 polkit action reference — `filesystem-mount` (`allow_active = yes` for removable) vs `filesystem-mount-system` (`auth_admin`); the basis for the #103-independence above.
- udiskie 2.6.2 + home-manager `services.udiskie` — `tray = "never"` drops the `tray.target` `Requires`/`After`; notifications are tray-independent (fnott).
- `mount.yazi` (yazi-rs/plugins) — wraps `udisksctl` + `lsblk`; no `setup()` (keybind-only).
- Filesystem helpers: `exfatprogs` (current exFAT pkg), `ntfs3g`, `dosfstools`.
- [fnott.md](./fnott.md) — the notification daemon udiskie pops to; [polkit.md](./polkit.md) — the agent that does *not* engage for removable media; [gnome-keyring.md](./gnome-keyring.md) — Secret Service, unrelated.
- ADR-028 (Stylix surface), ADR-029 (niri-only desktop).
