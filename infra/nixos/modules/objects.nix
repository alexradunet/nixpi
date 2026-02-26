# Object store module — manages the flat-file data directory for Nixpi objects.
#
# Objects are YAML-frontmatter Markdown files organized by type (journal, task, note, etc.).
# This module ensures the directory tree exists with correct ownership.
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.objects;
  primaryUser = config.nixpi.primaryUser;
in
{
  options.nixpi.objects = {
    enable = lib.mkEnableOption "Nixpi object store (flat-file data directory)";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.nixpi.repoRoot}/data/objects";
      example = "/home/alex/Nixpi/data/objects";
      description = ''
        Root directory for Nixpi object files.
        Each object type gets a subdirectory (e.g. journal/, task/, note/).
      '';
    };

    types = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "journal" "task" "note" ];
      example = [ "journal" "task" "note" "person" "event" "health" ];
      description = ''
        Object types to create subdirectories for.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "nixpi.objects.dataDir must be an absolute path.";
      }
      {
        assertion = builtins.length cfg.types > 0;
        message = "nixpi.objects.types must contain at least one object type.";
      }
      {
        assertion = builtins.all (t: builtins.match "^[a-z][a-z0-9-]*$" t != null) cfg.types;
        message = "nixpi.objects.types entries must be lowercase alphanumeric with hyphens (e.g. 'journal', 'health-metric').";
      }
    ];

    system.activationScripts.nixpiObjects = lib.stringAfter [ "users" ] ''
      install -d -o ${primaryUser} -g users "${cfg.dataDir}"
      ${lib.concatMapStringsSep "\n" (t: ''
        install -d -o ${primaryUser} -g users "${cfg.dataDir}/${t}"
      '') cfg.types}
    '';
  };
}
