# Shared base module for NixOS VM integration tests.
#
# Usage in test files:
#   imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
{ pkgsUnstableForTests }:

{ config, pkgs, lib, ... }:

{
  # Inject the stubbed unstable package set so base.nix sees it as pkgsUnstable.
  _module.args.pkgsUnstable = pkgsUnstableForTests;

  imports = [ ../../infra/nixos/base.nix ];

  # Lightweight test identity — no real host, no GNOME.
  nixpi.primaryUser = "testuser";
  nixpi.repoRoot = "/home/testuser/Nixpi";
  nixpi.desktopProfile = "preserve";

  networking.hostName = "testvm";

  # Known initial password for SSH and PAM tests.
  # Must satisfy the password policy (>=16 chars, digit, special).
  users.users.testuser.initialPassword = "TestPassword123!@#Strong";

  # Tools needed by test scripts (e.g. functional SSH login tests).
  environment.systemPackages = [ pkgs.sshpass ];
}
