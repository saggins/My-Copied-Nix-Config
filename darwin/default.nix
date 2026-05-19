{
  config,
  hostname,
  inputs,
  lib,
  outputs,
  pkgs,
  platform,
  username,
  ...
}:
{
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.nix-index-database.darwinModules.nix-index
    ./${hostname}
    ./_mixins/desktop
    ./_mixins/features
    ./_mixins/scripts
  ];

  # Only install the docs I use
  documentation.enable = true;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  documentation.man.enable = true;

  environment = {
    shells = [ pkgs.fish ];
    systemPackages = with pkgs; [
      git
      m-cli
      mas
      nix-output-monitor
      nvd
      plistwatch
      sops
    ];

    variables = {
      EDITOR = "vim";
      SYSTEMD_EDITOR = "vim";
      VISUAL = "vim";
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
  };

  nix-homebrew = {
    enable = true;
    enableRosetta = if (platform == "aarch64-darwin") then true else false;
    autoMigrate = true;
    user = "${username}";
    mutableTaps = true;
  };

  nixpkgs = {
    # Configure your nixpkgs instance
    config.allowUnfree = true;
    hostPlatform = lib.mkDefault "${platform}";
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      # Add overlays exported from other flakes:
    ];
  };

  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        # Disable global registry
        flake-regisstry = "";
        # Workaround for https://github.com/NixOS/nix/issues/9574
        nix-path = config.nix.nixPath;
        warn-dirty = false;
      };
      # Determinate uses its own daemon to manage the Nix installation that
      # conflicts with nix-darwin’s native Nix management.
      enable = false;
      # Disable channels
      channel.enable = false;
      # Make flake registry and nix path match flake inputs
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
    };

  networking.hostName = hostname;
  networking.computerName = hostname;

  programs = {
    fish = {
      enable = true;
      shellAliases = {
      };
    };
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    info.enable = false;
    nix-index-database.comma.enable = true;
  };

  # Enable TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  services = {
    tailscale.enable = true;
  };

  system = {
    primaryUser = "sangmin";
    stateVersion = 5;
    # activationScripts run every time you boot the system or execute `darwin-rebuild`
    activationScripts = {
      nixos-needsreboot = {
        supportsDryActivation = true;
        text = "${
          lib.getExe inputs.nixos-needsreboot.packages.${pkgs.system}.default
        } \"$systemConfig\" || true";
      };
      # reload the settings and apply them without the need to logout/login
      activateSettings = {
        text = ''
          sudo -u ${username} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
        '';
      };
      # https://github.com/LnL7/nix-darwin/issues/811
      setFishAsShell.text = ''
        dscl . -create /Users/${username} UserShell /run/current-system/sw/bin/fish
      '';
    };
    defaults = {
      CustomUserPreferences = {
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };
        "com.apple.controlcenter" = {
          BatteryShowPercentage = true;
        };
        "com.apple.SoftwareUpdate" = {
          AutomaticCheckEnabled = true;
          # Check for software updates daily, not just once per week
          ScheduleFrequency = 1;
          # Download newly available updates in background
          AutomaticDownload = 0;
          # Install System data files & security updates
          CriticalUpdateInstall = 1;
        };
        "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
        # Turn on app auto-update
        "com.apple.commerce".AutoUpdate = true;
      };
      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = false;
      };
      finder = {
        _FXShowPosixPathInTitle = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };
      screensaver = {
        askForPassword = true;
        askForPasswordDelay = 300;
      };
    };
  };
}
