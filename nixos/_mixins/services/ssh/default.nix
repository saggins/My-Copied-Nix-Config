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
    # 26.05 enables gcr-ssh-agent by default with GNOME components; it conflicts
    # with programs.ssh.startAgent, so disable it in favour of the OpenSSH agent.
    gnome.gcr-ssh-agent.enable = false;
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