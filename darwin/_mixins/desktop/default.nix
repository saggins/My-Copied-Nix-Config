{ pkgs, ... }:
{
  imports = [
    ./features
  ];

  environment.systemPackages = with pkgs; [ ];
}
