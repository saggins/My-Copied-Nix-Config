{
  config,
  isISO,
  lib,
  pkgs,
  ...
}:
# Bootable ISO images ship bcachefs userspace tools and the kernel module so the
# live media can mount, repair and install onto bcachefs filesystems. bcachefs
# is out-of-tree on the 6.18 kernel, so the module is pulled in explicitly.
# - https://wiki.nixos.org/wiki/Bcachefs
lib.mkIf isISO {
  environment.systemPackages = with pkgs; [
    bcachefs-tools
    keyutils
  ];
  boot.extraModulePackages = [ config.boot.kernelPackages.bcachefs ];
  boot.kernelModules = [ "bcachefs" ];
}
