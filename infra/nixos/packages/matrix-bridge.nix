# Pre-built Matrix bridge derivation.
#
# Builds the entire npm workspace (nixpi-core + matrix-bridge) via
# buildNpmPackage, so the service runs without any runtime npm install.
{ pkgs }:

let
  # The @matrix-org/matrix-sdk-crypto-nodejs package downloads its native
  # binary via a postinstall script, which doesn't run in the nix sandbox.
  # Fetch it separately and inject it during the build.
  cryptoNativeLib = pkgs.fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v0.4.0/matrix-sdk-crypto.linux-x64-gnu.node";
    hash = "sha256-cHjU3ZhxKPea/RksT2IfZK3s435D8qh1bx0KnwNN5xg=";
  };
in
pkgs.buildNpmPackage {
  pname = "nixpi-matrix-bridge";
  version = "0.1.0";

  src = ../../../.;

  npmDepsHash = "sha256-JFzz64SrRnV1xloGH+ymnaN7mJ6fPg3v2lJtXENsrhI=";

  makeCacheWritable = true;

  # The workspace root has no build script; build both packages explicitly.
  buildPhase = ''
    runHook preBuild

    # Inject the native crypto binary that the postinstall script would download
    cp ${cryptoNativeLib} node_modules/@matrix-org/matrix-sdk-crypto-nodejs/matrix-sdk-crypto.linux-x64-gnu.node

    npm run --workspace=packages/nixpi-core build
    npm run --workspace=services/matrix-bridge build
    runHook postBuild
  '';

  # Install the bridge service output into $out.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/nixpi-matrix-bridge

    # Copy built output
    cp -r services/matrix-bridge/dist $out/lib/nixpi-matrix-bridge/dist
    cp services/matrix-bridge/package.json $out/lib/nixpi-matrix-bridge/

    # Copy node_modules, then fix workspace symlinks:
    # - Remove self-referencing symlink (bridge doesn't import itself)
    # - Replace @nixpi/core symlink with actual built package
    cp -r node_modules $out/lib/nixpi-matrix-bridge/node_modules
    rm -f $out/lib/nixpi-matrix-bridge/node_modules/nixpi-matrix-bridge
    rm -rf $out/lib/nixpi-matrix-bridge/node_modules/@nixpi/core
    mkdir -p $out/lib/nixpi-matrix-bridge/node_modules/@nixpi/core
    cp -r packages/nixpi-core/dist $out/lib/nixpi-matrix-bridge/node_modules/@nixpi/core/dist
    cp packages/nixpi-core/package.json $out/lib/nixpi-matrix-bridge/node_modules/@nixpi/core/

    runHook postInstall
  '';

  # Don't try to run the default npm test/check.
  doCheck = false;

  meta = {
    description = "Nixpi Matrix bridge — matrix-bot-sdk → Pi print mode";
  };
}
