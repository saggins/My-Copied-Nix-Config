{
  lib,
  fetchFromGitHub,
  python313Packages,
  callPackage,
  pkgs,
  gpuBackend ? "cuda", # this will cause issues
  ...
}:
let
  spandrel = pkgs.callPackage ../spandrel { };
  myTorch =
    if gpuBackend == "cuda" then
      pkgs.python313Packages.torchWithCuda
    else if gpuBackend == "rocm" then
      pkgs.python313Packages.torchWithRocm
    else
      pkgs.python313Packages.torch;
in
python313Packages.buildPythonApplication rec {
  pname = "comic-upscaler";
  version = "0.0.1";
  pyproject = false; # very sad
  python = pkgs.python313;

  src = fetchFromGitHub {
    name = "comic-upscaler-source";
    owner = "anvstin";
    repo = "comic-upscaler";
    rev = "13a19a6b40bfae232a1a84ac69838480b6edbb94";
    hash = "sha256-XKYSTBF90rr4sigN+dmKCOuQlKI8nEqa8WJZz08wiOE=";
  };

  doCheck = false;

  dependencies = with pkgs.python313Packages; [
    numpy
    imageio
    natsort
    tqdm
    pkgs.libwebp
    rich
    pillow
    unidecode
    requests
    opencv-python
    spandrel # imported from a failed pr in nixpkgs
    myTorch
    torchvision
    torchaudio
  ];
  makeWrapperArgs = [ "main.py" ];
}
