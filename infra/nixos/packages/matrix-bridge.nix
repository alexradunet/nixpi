# Pre-built Matrix bridge derivation.
#
# Builds the entire npm workspace (nixpi-core + matrix-bridge) via
# buildNpmPackage, so the service runs without any runtime npm install.
{ pkgs }:

pkgs.buildNpmPackage {
  pname = "nixpi-matrix-bridge";
  version = "0.1.0";

  src = ../../../.;

  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  makeCacheWritable = true;

  # The workspace root has no build script; build both packages explicitly.
  buildPhase = ''
    runHook preBuild
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
