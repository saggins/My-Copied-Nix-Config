{
  lib,
  pkgs,
  python313Packages,
  config,
  gpuBackend ? "cuda", # this will cause issues
}:
let
  myTorch =
    if gpuBackend == "cuda" then
      pkgs.python313Packages.torchWithCuda
    else if gpuBackend == "rocm" then
      pkgs.python313Packages.torchWithRocm
    else
      pkgs.python313Packages.torch;
in
python313Packages.buildPythonPackage rec {
  pname = "spandrel";
  version = "0.4.1";
  pyproject = true;

  build-system = [ pkgs.python313Packages.setuptools ];

  buildInputs = with pkgs.python313Packages; [
    myTorch
    torchvision
    safetensors
    einops
  ];

  src = python313Packages.fetchPypi {
    inherit pname version;
    hash = "sha256-ZG2YFqlC5Z1WqrLckENTlS5X3uSyyz9Z9+pNwPsRofI=";
  };

  pythonImportsCheck = [ "spandrel" ];

  meta = {
    description = "Library for loading and running pre-trained PyTorch models";
    homepage = "https://github.com/chaiNNer-org/spandrel/";
    changelog = "https://github.com/chaiNNer-org/spandrel/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ scd31 ];
  };
}
