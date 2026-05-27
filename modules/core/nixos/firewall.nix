# Host firewall — perimeter for every host regardless of the network
# stack it runs (NetworkManager on bare-metal, cloud-init +
# systemd-networkd on AWS via amazon-image).
#
# Imported via foundation.nix so the guarantee holds for every host
# unconditionally. Specifically: the amazon-image module does NOT
# enable the NixOS firewall by default — it leaves the perimeter to
# the AWS Security Group. Defense-in-depth (both layers agreeing) is
# the explicit posture; the runbook for AWS hosts mirrors the same
# rules in the SG.
#
# Per-service "openFirewall" knobs (services.openssh.openFirewall,
# programs.mosh's UDP range) only do anything when the firewall is
# enabled — placing the enable in foundation means those knobs work
# for every host.
{
  networking.firewall.enable = true;
}
