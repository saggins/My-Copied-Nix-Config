{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
  installFor = [ "sangmin" ];
  keysSopsFile = ../../../../secrets/keys.yaml;
  # Helper function to generate SSH key secret definitions
  mkSshKeySecrets = keyNamePrefix: sshBaseName: {
    "${keyNamePrefix}_${sshBaseName}" = {
      sopsFile = keysSopsFile;
      path = "${config.home.homeDirectory}/.ssh/${keyNamePrefix}_${sshBaseName}";
    };
    "${keyNamePrefix}_${sshBaseName}_pub" = {
      sopsFile = keysSopsFile;
      path = "${config.home.homeDirectory}/.ssh/${keyNamePrefix}_${sshBaseName}.pub";
      mode = "0644";
    };
  };
  # List of ed25519_sk base names
  ed25519SkKeyIdentifiers = [

  ];
  # Generate the attribute set for all ed25519_sk key secrets
  allEd25519SkSecrets = lib.foldl lib.recursiveUpdate {} (
    map (baseName: mkSshKeySecrets "id_ed25519_sk" baseName) ed25519SkKeyIdentifiers
  );
  # Make with: pamu2fcfg -n
in
lib.mkIf (lib.elem username installFor) {
  home.packages = with pkgs; [
    yubikey-manager
  ] ++ lib.optionals isLinux [
    pam_u2f
    pamtester
  ] ++ lib.optionals isDarwin [
    openssh # needed for FIDO2 support
  ];
  programs = {
    fish = {
      shellAliases = lib.mkIf isDarwin {
        ssh-agent-start = "eval (${pkgs.openssh}/bin/ssh-agent -c)";
        ssh-agent-stop = "${pkgs.openssh}/bin/ssh-agent -k";
      };
    };
    gpg = lib.mkIf isLinux {
      # Prevent the PCSC-Lite conflicting with gpg-agent
      # https://wiki.nixos.org/wiki/Yubikey#Smartcard_mode
      scdaemonSettings = {
        disable-ccid = true;
      };
    };
    ssh = lib.mkIf isDarwin {
      addKeysToAgent = "yes";
      enable = true;
      includes = [
        "${config.home.homeDirectory}/.ssh/local_config"
      ];
      package = pkgs.openssh;
    };
  };

  sops = {
    secrets = allEd25519SkSecrets;
  };
}