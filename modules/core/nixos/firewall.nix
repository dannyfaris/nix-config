# Host firewall — perimeter for every headless instance regardless of
# the network stack it runs (NetworkManager on the VM, cloud-init +
# systemd-networkd on AWS via amazon-image).
#
# Lives in its own core module so the role can import it once and the
# guarantee holds for every host. Specifically: the amazon-image module
# does NOT enable the NixOS firewall by default — it leaves the
# perimeter to the AWS Security Group. Defense-in-depth (both layers
# agreeing) is the explicit posture; the runbook for AWS hosts mirrors
# the same rules in the SG.
#
# Per-service "openFirewall" knobs (services.openssh.openFirewall,
# programs.mosh's UDP range) only do anything when the firewall is
# enabled — keeping the enable at the role level means those knobs
# work for every host.
{
  networking.firewall.enable = true;
}
