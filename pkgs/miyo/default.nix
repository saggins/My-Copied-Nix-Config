# miyo: headless Miyo engine + CLI (semantic search over local notes, MCP server).
# - https://www.miyo.md/docs/headless
# Packaged from the npm tarball (@brevilabs/miyo), which ships no lockfile, so
# package-lock.json is vendored here. The per-platform package (@brevilabs/miyo-linux-*)
# carries prebuilt qdrant, llama-server and the OCR runtime; autoPatchelfHook fixes them up.
#
# To update: bump `version` and `hash` (the tarball's `dist.integrity` from
# `curl -s https://registry.npmjs.org/@brevilabs/miyo/latest`), then in an unpacked copy
# of the new tarball run `npm install --package-lock-only --ignore-scripts`, copy the
# lockfile here and refresh npmDepsHash with `prefetch-npm-deps package-lock.json`.
{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_24,
  autoPatchelfHook,
  python3,
  stdenv,
  openssl,
}:
buildNpmPackage rec {
  pname = "miyo";
  version = "0.4.3";

  src = fetchurl {
    url = "https://registry.npmjs.org/@brevilabs/miyo/-/miyo-${version}.tgz";
    hash = "sha512-0jrJXOdN4/L0/hWuyJ7nj9LbXLtLKEuAQIzltapuUFD11Hu5LCncr6T8Na+siaVzZnPhURvUtm/KAQmOkvo7xQ==";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-c74eRpRCVYuHa3XuSkQdIFKSu2/rFiLupWWozULW00g=";
  nodejs = nodejs_24;

  # dist/ is prebuilt; better-sqlite3 is compiled from source by `npm rebuild` (node-gyp)
  # since prebuild-install can't download in the sandbox.
  dontNpmBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
    python3 # node-gyp
  ];

  # libstdc++, libgcc_s, libgomp (llama-server's CPU backends need OpenMP) and
  # OpenSSL (llama-server, for -hf model downloads).
  buildInputs = [
    stdenv.cc.cc.lib
    openssl
  ];

  # npm installs every linux-x64 pdf-inspector variant; drop the musl one so
  # autoPatchelf doesn't look for musl's libc.
  postInstall = ''
    rm -rf $out/lib/node_modules/@brevilabs/miyo/node_modules/@firecrawl/pdf-inspector-*-musl
  '';

  meta = {
    description = "Miyo's search engine and CLI for always-on Linux machines";
    homepage = "https://miyo.md";
    license = with lib.licenses; [
      mit
      asl20
      bsd3
    ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    mainProgram = "miyo";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
