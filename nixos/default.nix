{
  config,
  hostname,
  isInstall,
  isWorkstation,
  inputs,
  lib,
  modulesPath,
  outputs,
  pkgs,
  platform,
  stateVersion,
  username,
  ...
}:
{
  imports = [
    # Use module this flake exports; from modules/nixos
    #outputs.nixosModules.my-module
    # Use modules from other flakes
    inputs.catppuccin.nixosModules.catppuccin
    inputs.determinate.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.nix-flatpak.nixosModules.nix-flatpak
    inputs.nix-index-database.nixosModules.nix-index
    inputs.sops-nix.nixosModules.sops
    (modulesPath + "/installer/scan/not-detected.nix")
    ./${hostname}
    ./_mixins/configs
    ./_mixins/features
    ./_mixins/scripts
    ./_mixins/services
    ./_mixins/users
  ] ++ lib.optional isWorkstation ./_mixins/desktop;

  boot = {
    consoleLogLevel = lib.mkDefault 0;
    initrd.verbose = false;
    kernelModules = [ "vhost_vsock" ];
    kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
    # Only enable the systemd-boot on installs, not live media (.ISO images)
    loader = lib.mkIf isInstall {
      efi.canTouchEfiVariables = true;
      systemd-boot.configurationLimit = 10;
      systemd-boot.consoleMode = "max";
      systemd-boot.enable = true;
      systemd-boot.memtest86.enable = true;
      timeout = 10;
    };
  };

  # Only install the docs I use
  documentation.enable = true;
  documentation.nixos.enable = false;
  documentation.man.enable = true;
  documentation.info.enable = false;
  documentation.doc.enable = false;

  environment = {
    # Eject nano and perl from the system
    defaultPackages =
      with pkgs;
      lib.mkForce [
        (lib.hiPrio pkgs.uutils-coreutils-noprefix)
        (lib.hiPrio pkgs.uutils-findutils)
        (lib.hiPrio pkgs.uutils-diffutils)
        (lib.hiPrio pkgs.sudo-rs)
        micro
      ];

    systemPackages =
      with pkgs;
      [
        git
        nix-output-monitor
      ]
      ++ lib.optionals isInstall [
        inputs.determinate.packages.${platform}.default
        inputs.fh.packages.${platform}.default
        inputs.nixos-needsreboot.packages.${platform}.default
        nvd
        nvme-cli
        rsync
        smartmontools
        sops
      ];

    variables = {
      EDITOR = "micro";
      SYSTEMD_EDITOR = "micro";
      VISUAL = "micro";
    };
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      # Add overlays exported from other flakes:
    ];
    # Configure your nixpkgs instance
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    settings = {
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;
      warn-dirty = false;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "${platform}";

  programs = {
    command-not-found.enable = false;
    fish = {
      enable = true;
      shellAliases = {
        nano = "micro";
      };
    };
    nano.enable = lib.mkDefault false;
    nh = {
      clean = {
        enable = true;
        extraArgs = "--keep-since 15d --keep 10";
      };
      enable = true;
      flake = "/home/${username}/Zero/nix-config";
    };
    nix-index-database.comma.enable = isInstall;
    nix-ld = lib.mkIf isInstall {
      enable = true;
      libraries = with pkgs; [
        # Add any missing dynamic libraries for unpackaged
        # programs here, NOT in environment.systemPackages
      ];
    };
  };

  security = {
    sudo.enable = false;
    sudo-rs = {
      enable = lib.mkDefault true;
    };
  };

  services = {
    fwupd.enable = isInstall;
    hardware.bolt.enable = true;
    irqbalance = lib.mkIf (! config.services.qemuGuest.enable) {
      enable = true;
    };
    smartd.enable = isInstall;
  };

  # https://dl.thalheim.io/
  sops = lib.mkIf (isInstall) {
    age = {
      keyFile = "/var/lib/private/sops/age/keys.txt";
      generateKey = false;
    };
    defaultSopsFile = ../secrets/secrets.yaml;
    secrets = {
    };
  };

  # Create symlink to /bin/bash
  # - https://github.com/lima-vm/lima/issues/2110
  systemd = {
    extraConfig = "DefaultTimeoutStopSec=10s";
    tmpfiles.rules = [
      "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
      "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root"
      "d /var/lib/private/sops/age 0755 root root"
    ];
  };

  system = {
    activationScripts = {
      nixos-needsreboot = lib.mkIf (isInstall) {
        supportsDryActivation = true;
        text = "${lib.getExe inputs.nixos-needsreboot.packages.${pkgs.system}.default} \"$systemConfig\" || true";
      };
    };
    nixos.label = lib.mkIf isInstall "-";
    inherit stateVersion;
  };
}
