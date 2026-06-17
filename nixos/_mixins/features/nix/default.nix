{ hostname, ... }:
{
  nix.settings.cores =
    if hostname == "phasma" then
      18
    else if hostname == "vader" then
      24
    else
      0;

  # Prebuilt binaries for the pinned Hyprland flake (avoids source builds).
  nix.settings.extra-substituters = [ "https://hyprland.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  ];
}
