{ ... }:
{
  # Prebuilt binaries for the pinned Hyprland flake (avoids source builds),
  # and workhorse's CI builds served over Tailscale (see services/nix-serve).
  nix.settings.extra-substituters = [
    "https://hyprland.cachix.org"
    "http://workhorse.comet-court.ts.net"
  ];
  nix.settings.extra-trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    # workhorse.comet-court.ts.net-1:<public key> goes here (see services/nix-serve)
  ];
  # Don't stall builds when workhorse is offline; Nix moves on to the next cache.
  nix.settings.connect-timeout = 5;
}
