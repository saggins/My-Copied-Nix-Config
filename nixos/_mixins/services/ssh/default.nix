{
  isInstall,
  isLaptop,
  lib,
  pkgs,
  ...
}:
let
  # Don't open the firewall for SSH on laptops; Tailscale will handle it.
  openSSHFirewall = if (isInstall) then false else true;
in
{
  environment = lib.mkIf isInstall { systemPackages = with pkgs; [ ssh-to-age ]; };
  programs = {
    ssh.startAgent = true;
  };
  services = {
    openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
      };
    };
    sshguard = {
      enable = true;
      whitelist = [
        "10.0.0.0/24"
      ];
    };
  };
}