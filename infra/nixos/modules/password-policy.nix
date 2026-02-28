# Password policy module — PAM-based password complexity enforcement.
#
# When enabled, enforces minimum length, digit, and special character
# requirements for local password changes (passwd and chpasswd).
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.passwordPolicy;

  passwordPolicyCheck = pkgs.writeShellScript "nixpi-password-policy-check" ''
    set -euo pipefail

    # pam_exec with expose_authtok provides the candidate password on stdin
    # WITHOUT a trailing newline, so read returns non-zero at EOF. Accept
    # the data anyway; only bail if the password is truly empty.
    IFS= read -r password || :
    [ -n "$password" ] || exit 1

    if [ "''${#password}" -lt ${toString cfg.minLength} ]; then
      echo "Password must be at least ${toString cfg.minLength} characters." >&2
      exit 1
    fi

    case "$password" in
      (*[0-9]*) ;;
      (*)
        echo "Password must include at least one number." >&2
        exit 1
        ;;
    esac

    case "$password" in
      (*[[:punct:]]*) ;;
      (*)
        echo "Password must include at least one special character." >&2
        exit 1
        ;;
    esac
  '';
in
{
  options.nixpi.passwordPolicy = {
    enable = lib.mkEnableOption "Password complexity policy (PAM)";

    minLength = lib.mkOption {
      type = lib.types.int;
      default = 16;
      description = "Minimum password length.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.minLength >= 8;
        message = "nixpi.passwordPolicy.minLength must be at least 8.";
      }
    ];

    security.pam.services.passwd.rules.password.passwordPolicy = {
      order = config.security.pam.services.passwd.rules.password.unix.order - 20;
      control = "requisite";
      modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
      args = [ "expose_authtok" "${passwordPolicyCheck}" ];
    };

    security.pam.services.chpasswd.rules.password.passwordPolicy = {
      order = config.security.pam.services.chpasswd.rules.password.unix.order - 20;
      control = "requisite";
      modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
      args = [ "expose_authtok" "${passwordPolicyCheck}" ];
    };
  };
}
