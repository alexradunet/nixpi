# Base NixOS module — shared config loaded by every host.
#
# `{ config, pkgs, lib, pkgsUnstable ? pkgs, ... }:` is the NixOS module function signature.
# NixOS calls this function and passes in:
#   config      — the fully resolved system config (for reading other modules' values)
#   pkgs        — the stable Nix package set (nixos-25.11)
#   pkgsUnstable— optional newer package set for selected tools
#   lib         — helper functions (merging, filtering, etc.)
#   ...         — catches any extra args so the module stays forward-compatible
{ config, pkgs, lib, pkgsUnstable ? pkgs, ... }:

# `let ... in` binds local variables. Everything between `let` and `in`
# is only visible within this file.
let
  # Shared guidelines for the single Nixpi instance system prompt.
  sharedGuidelines = ''
    - Prefer declarative Nix changes over imperative system mutation
    - Never modify /etc or systemd units directly; edit NixOS config instead
    - Protect secrets: never read ${piDir}/auth.json, ~/.ssh/*, or .env files
  '';

  piSystemPrompt = ''
    You are Nixpi, a personal AI life companion running on a NixOS-based AI-first workstation.

    ## Environment
    - OS: NixOS (declarative, flake-based)
    - Config repo: ${repoRoot}
    - Rebuild: cd ${repoRoot} && sudo nixos-rebuild switch --flake .
    - VPN: Tailscale (services restricted to Tailscale + LAN)
    - File sync: Syncthing
    - Object store: ${repoRoot}/data/objects/

    ## Guidelines
    - Follow AGENTS.md conventions
    ${sharedGuidelines}

    ## Startup behavior
    - At session start, briefly announce discovered local skills from settings.json.
    - If no local skills are found, say so explicitly and suggest `--skill <path-to-SKILL.md>`.
  ''
  + lib.optionalString (personaContent != "") ''

    ## Persona
    ${personaContent}
  '';

  extensionManifest = builtins.fromJSON (builtins.readFile ../pi/extensions/packages.json);
  extensionPackages = extensionManifest.packages or [ ];
  isPinnedNpmSource = source:
    builtins.match "^npm:(@[^/]+/[^@]+|[^@/][^@]*)@[0-9]+\\.[0-9]+\\.[0-9]+([-.+][0-9A-Za-z.-]+)*$" source != null;
  extensionPackagesArePinned = builtins.all isPinnedNpmSource extensionPackages;
  settingsSeedJson = builtins.toJSON {
    skills = [ "${repoRoot}/infra/pi/skills" ];
    packages = extensionPackages;
  };

  # Lightweight Pi install path: use npm package directly via npx,
  # avoiding the large llm-agents flake dependency.
  piWrapper = pkgs.writeShellScriptBin "pi" ''
    set -euo pipefail

    export npm_config_update_notifier=false
    export npm_config_audit=false
    export npm_config_fund=false
    export npm_config_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/nixpi-npm"
    export npm_config_prefix="''${XDG_DATA_HOME:-$HOME/.local/share}/nixpi-npm-global"

    mkdir -p "$npm_config_cache" "$npm_config_prefix"

    # Pin package version to keep behavior stable across rebuilds.
    exec ${pkgs.nodejs_22}/bin/npx --yes @mariozechner/pi-coding-agent@${config.nixpi.piAgentVersion} "$@"
  '';

  nixpiCli = pkgs.writeShellScriptBin "nixpi" ''
    set -euo pipefail

    PI_BIN="${piWrapper}/bin/pi"
    PI_DIR="${piDir}"
    REPO_ROOT="${repoRoot}"
    EXTENSIONS_MANIFEST="$REPO_ROOT/infra/pi/extensions/packages.json"

    is_pinned_npm_source() {
      local source="$1"
      [[ "$source" =~ ^npm:(@[^/]+/[^@]+|[^@/][^@]*)@[0-9]+\.[0-9]+\.[0-9]+([-.+][0-9A-Za-z.-]+)*$ ]]
    }

    normalize_npm_source() {
      local pkg="$1"
      case "$pkg" in
        npm:*) printf '%s\n' "$pkg" ;;
        *) printf 'npm:%s\n' "$pkg" ;;
      esac
    }

    require_pinned_source() {
      local source="$1"
      if ! is_pinned_npm_source "$source"; then
        echo "nixpi npm install requires pinned npm package versions." >&2
        echo "Use pinned npm sources (exact versions), e.g. npm:@scope/extension@1.2.3." >&2
        exit 2
      fi
    }

    ensure_manifest_exists() {
      mkdir -p "$(dirname "$EXTENSIONS_MANIFEST")"
      if [ ! -f "$EXTENSIONS_MANIFEST" ]; then
        cat > "$EXTENSIONS_MANIFEST" <<'JSONEOF'
{
  "packages": []
}
JSONEOF
      fi
    }

    validate_manifest_sources() {
      local source
      while IFS= read -r source; do
        [ -n "$source" ] || continue
        if ! is_pinned_npm_source "$source"; then
          echo "nixpi extension manifest contains unpinned source: $source" >&2
          echo "Use pinned npm sources (exact versions), e.g. npm:@scope/extension@1.2.3." >&2
          exit 2
        fi
      done < <(${pkgs.jq}/bin/jq -r '.packages[]?' "$EXTENSIONS_MANIFEST")
    }

    sync_manifest_to_profile() {
      if [ ! -f "$EXTENSIONS_MANIFEST" ]; then
        echo "nixpi npm sync requires infra/pi/extensions/packages.json." >&2
        exit 2
      fi

      validate_manifest_sources

      manifest_json="$(${pkgs.jq}/bin/jq -c '{ packages: (.packages // []) }' "$EXTENSIONS_MANIFEST")"
      mkdir -p "$PI_DIR"

      tmp_settings="$(mktemp)"
      if [ -f "$PI_DIR/settings.json" ]; then
        ${pkgs.jq}/bin/jq --argjson manifest "$manifest_json" '
          .packages = ($manifest.packages // [])
        ' "$PI_DIR/settings.json" > "$tmp_settings"
      else
        ${pkgs.jq}/bin/jq --argjson manifest "$manifest_json" --arg skillsPath "$REPO_ROOT/infra/pi/skills" -n '
          {
            skills: [$skillsPath],
            packages: ($manifest.packages // [])
          }
        ' > "$tmp_settings"
      fi
      mv "$tmp_settings" "$PI_DIR/settings.json"

      export PI_CODING_AGENT_DIR="$PI_DIR"
      mapfile -t manifest_packages < <(${pkgs.jq}/bin/jq -r '.packages[]?' "$EXTENSIONS_MANIFEST")
      for source in "''${manifest_packages[@]}"; do
        "$PI_BIN" install "$source"
      done

      echo "Synced extension sources from $EXTENSIONS_MANIFEST"
    }

    confirm_action() {
      local token="$1"
      local prompt="$2"
      local reply

      echo "$prompt" >&2
      printf "Type %s to continue: " "$token" >&2
      IFS= read -r reply
      if [ "$reply" != "$token" ]; then
        echo "Cancelled." >&2
        exit 2
      fi
    }

    run_evolve() {
      local assume_yes="$1"
      local verify_script_relative="./scripts/verify-nixpi.sh"
      local verify_script="$REPO_ROOT/scripts/verify-nixpi.sh"

      if [ "$assume_yes" -ne 1 ]; then
        echo "nixpi evolve requires explicit confirmation." >&2
        echo "About to run: sudo nixos-rebuild switch --flake ." >&2
        confirm_action "EVOLVE" "This applies system-level NixOS changes from $REPO_ROOT."
      fi

      (
        cd "$REPO_ROOT"
        sudo nixos-rebuild switch --flake .
      )

      if [ -x "$verify_script" ]; then
        echo "Running $verify_script_relative"
        if ! "$verify_script"; then
          echo "Rebuild validation failed; rolling back..." >&2
          (
            cd "$REPO_ROOT"
            sudo nixos-rebuild switch --rollback
          )
          exit 1
        fi
      else
        echo "Warning: missing executable $verify_script_relative; skipping post-apply validation." >&2
      fi

      echo "nixpi evolve completed successfully."
    }

    run_rollback() {
      local assume_yes="$1"

      if [ "$assume_yes" -ne 1 ]; then
        echo "nixpi rollback requires explicit confirmation." >&2
        echo "About to run: sudo nixos-rebuild switch --rollback" >&2
        confirm_action "ROLLBACK" "This activates the previous NixOS generation."
      fi

      (
        cd "$REPO_ROOT"
        sudo nixos-rebuild switch --rollback
      )

      echo "nixpi rollback completed successfully."
    }

    case "''${1-}" in
      dev|mode|runtime)
        echo "Unknown/deprecated nixpi subcommand: ''${1-}" >&2
        echo "Use: nixpi [pi-args...]" >&2
        exit 2
        ;;
      --help|-h|help)
        cat <<'EOF'
nixpi - primary CLI for the Nixpi assistant (powered by Pi SDK)

Usage:
  nixpi [pi-args...]                         Run Nixpi (single instance)
  nixpi evolve [--yes]                       Apply NixOS config with validation + auto-rollback on failed checks
  nixpi rollback [--yes]                     Roll back to the previous NixOS generation
  nixpi npm install <package@x.y.z...>       Install pinned extension(s) and track them in-repo
  nixpi npm sync                             Rebuild profile extension state from manifest
  nixpi help                                 Show this help

Notes:
  - `pi` remains available as SDK/advanced CLI.
  - `nixpi` uses PI_CODING_AGENT_DIR from nixpi.piDir.
  - `nixpi evolve` runs `sudo nixos-rebuild switch --flake .` from nixpi.repoRoot.
  - `nixpi rollback` runs `sudo nixos-rebuild switch --rollback` from nixpi.repoRoot.
  - `nixpi npm install` stores package sources in infra/pi/extensions/packages.json.
  - Extension sources must be pinned (exact versions), e.g. npm:@scope/extension@1.2.3.
EOF
        ;;
      evolve)
        shift || true
        assume_yes=0
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --yes) assume_yes=1 ;;
            *)
              echo "Unknown nixpi evolve option: $1" >&2
              echo "Usage: nixpi evolve [--yes]" >&2
              exit 2
              ;;
          esac
          shift
        done
        run_evolve "$assume_yes"
        ;;
      rollback)
        shift || true
        assume_yes=0
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --yes) assume_yes=1 ;;
            *)
              echo "Unknown nixpi rollback option: $1" >&2
              echo "Usage: nixpi rollback [--yes]" >&2
              exit 2
              ;;
          esac
          shift
        done
        run_rollback "$assume_yes"
        ;;
      npm)
        shift || true

        case "''${1-}" in
          install)
            shift || true

            if [ "$#" -eq 0 ]; then
              echo "nixpi npm install requires at least one package name." >&2
              echo "Usage: nixpi npm install <package@x.y.z...>" >&2
              exit 2
            fi

            ensure_manifest_exists
            validate_manifest_sources
            export PI_CODING_AGENT_DIR="$PI_DIR"

            for pkg in "$@"; do
              source="$(normalize_npm_source "$pkg")"
              require_pinned_source "$source"

              "$PI_BIN" install "$source"

              tmp_manifest="$(mktemp)"
              ${pkgs.jq}/bin/jq --arg pkg "$source" '
                .packages = ((.packages // []) + [$pkg] | unique)
              ' "$EXTENSIONS_MANIFEST" > "$tmp_manifest"
              mv "$tmp_manifest" "$EXTENSIONS_MANIFEST"
            done

            echo "Saved extension sources to $EXTENSIONS_MANIFEST"
            ;;
          sync)
            sync_manifest_to_profile
            ;;
          *)
            echo "Unknown nixpi npm subcommand: ''${1-}" >&2
            echo "Usage: nixpi npm <install|sync> ..." >&2
            exit 2
            ;;
        esac
        ;;
      *)
        export PI_CODING_AGENT_DIR="$PI_DIR"
        exec "$PI_BIN" "$@"
        ;;
    esac
  '';

  passwordPolicyCheck = pkgs.writeShellScript "nixpi-password-policy-check" ''
    set -euo pipefail

    # pam_exec with expose_authtok provides the candidate password on stdin.
    IFS= read -r password || exit 1

    if [ "''${#password}" -lt 16 ]; then
      echo "Password must be at least 16 characters." >&2
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

  # Read OpenPersona 4-layer files if persona dir exists.
  personaDir = config.nixpi.persona.dir;
  readPersonaLayer = name:
    let path = personaDir + "/${name}";
    in if builtins.pathExists path then builtins.readFile path else "";
  personaContent = builtins.concatStringsSep "\n" (
    builtins.filter (s: s != "") (map readPersonaLayer [ "SOUL.md" "BODY.md" "FACULTY.md" "SKILL.md" ])
  );

  primaryUser = config.nixpi.primaryUser;
  userDisplayName = config.nixpi.primaryUserDisplayName;
  primaryUserShell = lib.escapeShellArg primaryUser;
  userDisplayNameShell = lib.escapeShellArg userDisplayName;
  userHome = "/home/${primaryUser}";
  repoRoot = config.nixpi.repoRoot;
  piDir = config.nixpi.piDir;
in
{
  options.nixpi.primaryUser = lib.mkOption {
    type = lib.types.str;
    default = "nixpi";
    example = "alex";
    description = ''
      Primary Linux username for the local human operator.
    '';
  };

  options.nixpi.primaryUserDisplayName = lib.mkOption {
    type = lib.types.str;
    default = config.nixpi.primaryUser;
    example = "Alex";
    description = ''
      Display name shown by login managers (for example GDM).
      Defaults to nixpi.primaryUser to avoid username/display-name mismatch.
    '';
  };

  options.nixpi.repoRoot = lib.mkOption {
    type = lib.types.str;
    default = "/home/${config.nixpi.primaryUser}/Nixpi";
    example = "/home/alex/Nixpi";
    description = ''
      Repository root for Nixpi on disk.
    '';
  };

  options.nixpi.piAgentVersion = lib.mkOption {
    type = lib.types.str;
    default = "0.55.1";
    example = "0.56.0";
    description = ''
      Version of @mariozechner/pi-coding-agent to use across all services.
    '';
  };

  options.nixpi.piDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.nixpi.repoRoot}/.pi/agent";
    example = "/home/alex/Nixpi/.pi/agent";
    description = ''
      PI_CODING_AGENT_DIR path for the single Nixpi instance.
    '';
  };

  options.nixpi.timeZone = lib.mkOption {
    type = lib.types.str;
    default = "UTC";
    example = "Europe/Bucharest";
    description = ''
      System timezone. Override per host as needed.
    '';
  };

  options.nixpi.persona.dir = lib.mkOption {
    type = lib.types.path;
    default = ../../persona;
    example = "/home/alex/Nixpi/persona";
    description = ''
      Path to the OpenPersona directory containing SOUL.md, BODY.md, FACULTY.md, and SKILL.md.
      These layers define the agent's identity, behavior, cognition, and capabilities.
    '';
  };

  options.nixpi.desktopProfile = lib.mkOption {
    type = lib.types.enum [ "gnome" "preserve" ];
    default = "gnome";
    example = "preserve";
    description = ''
      Desktop profile behavior.
      - "gnome": manage a local default desktop stack (GDM + GNOME).
      - "preserve": keep desktop options defined by the host configuration.
    '';
  };

  imports = [
    ./modules/objects.nix
    ./modules/heartbeat.nix
    ./modules/whatsapp.nix
  ];

  config = {
    nixpi.objects.enable = lib.mkDefault true;

    assertions = [
      {
        assertion = builtins.match "^[a-z_][a-z0-9_-]*$" primaryUser != null;
        message = "nixpi.primaryUser must be a valid Linux username (lowercase letters, digits, _, -, and starting with a lowercase letter or _).";
      }
      {
        assertion = lib.hasPrefix "/" repoRoot;
        message = "nixpi.repoRoot must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" piDir;
        message = "nixpi.piDir must be an absolute path.";
      }
      {
        assertion = extensionPackagesArePinned;
        message = "All infra/pi/extensions/packages.json entries must be pinned npm sources (exact versions), e.g. npm:@scope/extension@1.2.3.";
      }
    ];

  # Enable flakes and nix-command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages. mkDefault on the whole attrset so the VM test
  # framework's read-only nixpkgs.config (types.unique) takes precedence.
  nixpkgs.config = lib.mkDefault { allowUnfree = true; };

  # nix-ld provides a dynamic linker shim so pre-compiled binaries (e.g. VS Code
  # remote server, downloaded tools) can run on NixOS, which normally lacks the
  # standard /lib/ld-linux path that most Linux binaries expect.
  programs.nix-ld.enable = true;

  # Networking
  networking.networkmanager.enable = true;
  # nftables is the modern Linux firewall (successor to iptables).
  # NixOS can generate rules from its firewall options and also accept raw
  # nftables syntax via extraInputRules (see below).
  networking.nftables.enable = true;

  # Local desktop policy for HDMI-first setup (display + Wi-Fi onboarding).
  # Default behavior mirrors standard GNOME installs. Hosts can opt into
  # preserve mode by setting:
  #   nixpi.desktopProfile = "preserve";
  services.xserver.enable = config.nixpi.desktopProfile == "gnome";
  services.displayManager.gdm.enable = config.nixpi.desktopProfile == "gnome";
  services.desktopManager.gnome.enable = config.nixpi.desktopProfile == "gnome";
  services.xserver.xkb = {
    layout = "us";
  };

  # Timezone and locale
  time.timeZone = config.nixpi.timeZone;
  i18n.defaultLocale = "en_US.UTF-8";

  # SSH with security hardening
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };

  # Web terminal interface (ttyd) that reuses localhost OpenSSH login.
  services.ttyd = {
    enable = true;
    port = 7681;
    user = primaryUser;
    writeable = true;
    checkOrigin = true;
    entrypoint = [
      "${pkgs.openssh}/bin/ssh"
      "-o"
      "StrictHostKeyChecking=accept-new"
      "${primaryUser}@127.0.0.1"
    ];
  };

  # Password complexity policy for local account password changes.
  # Requirement: minimum 16 chars, at least one number, and at least one
  # special character.
  security.pam.services.passwd.rules.password.passwordPolicy = {
    order = config.security.pam.services.passwd.rules.password.unix.order - 20;
    control = "requisite";
    modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
    args = [ "expose_authtok" "${passwordPolicyCheck}" ];
  };

  # Apply the same explicit checks to non-interactive password updates
  # (e.g. chpasswd).
  security.pam.services.chpasswd.rules.password.passwordPolicy = {
    order = config.security.pam.services.chpasswd.rules.password.unix.order - 20;
    control = "requisite";
    modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
    args = [ "expose_authtok" "${passwordPolicyCheck}" ];
  };

  # Firewall policy: SSH is reachable from Tailscale + LAN (bootstrap), while
  # ttyd and Syncthing are Tailscale-only.
  # extraInputRules accepts raw nftables syntax that NixOS injects into the
  # input chain.
  networking.firewall = {
    enable = true;

    extraInputRules = ''
      # Allow SSH from Tailscale and local network
      ip saddr 100.0.0.0/8 tcp dport 22 accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport 22 accept
      ip saddr 192.168.0.0/16 tcp dport 22 accept
      ip saddr 10.0.0.0/8 tcp dport 22 accept
      tcp dport 22 drop

      # Allow ttyd web terminal (port 7681) from Tailscale only
      ip saddr 100.0.0.0/8 tcp dport 7681 accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport 7681 accept
      tcp dport 7681 drop

      # Allow Syncthing GUI (port 8384) from Tailscale only
      ip saddr 100.0.0.0/8 tcp dport 8384 accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport 8384 accept
      tcp dport 8384 drop

      # Allow Syncthing sync (port 22000) from Tailscale only
      ip saddr 100.0.0.0/8 tcp dport 22000 accept
      ip saddr 100.0.0.0/8 udp dport 22000 accept
      ip6 saddr fd7a:115c:a1e0::/48 tcp dport 22000 accept
      ip6 saddr fd7a:115c:a1e0::/48 udp dport 22000 accept
      tcp dport 22000 drop
      udp dport 22000 drop
    '';
  };

  # Tailscale VPN
  services.tailscale = {
    enable = true;
    # Keep Tailscale SSH disabled so OpenSSH remains the single SSH control plane.
    extraSetFlags = [ "--ssh=false" ];
  };
  # Note: we intentionally do NOT set trustedInterfaces = [ "tailscale0" ] here.
  # Instead, Tailscale traffic is controlled by the explicit IP-based rules above
  # (100.0.0.0/8 + fd7a:115c:a1e0::/48 for SSH), giving us per-service
  # granularity over what Tailscale peers can access rather than blanket-trusting
  # all traffic on the interface.
  # Tailscale needs UDP 41641 for direct WireGuard connections between nodes.
  networking.firewall.allowedUDPPorts = [ 41641 ];

  # Syncthing for file synchronization
  services.syncthing = {
    enable = true;
    user = primaryUser;
    dataDir = "${userHome}/.local/share/syncthing";
    configDir = "${userHome}/.config/syncthing";
    # Keep overrides disabled so users can still add folders/devices in UI.
    # ~/Shared is declared by default so it can be synced across devices.
    overrideFolders = false;
    overrideDevices = false;
    settings = {
      folders.home = {
        id = "shared";
        label = "Shared";
        path = "${userHome}/Shared";
        devices = builtins.attrNames config.services.syncthing.settings.devices;
      };
      gui = {
        enabled = true;
        address = "0.0.0.0:8384";
      };
      options = {
        relaysEnabled = true;  # Allow relay servers for connectivity
      };
    };
  };

  # Keep existing account passwords mutable so first-install users retain
  # credentials configured in the NixOS installer.
  users.mutableUsers = true;

  # User configuration
  users.users.${primaryUser} = {
    isNormalUser = true;
    home = userHome;
    description = userDisplayName;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Browser (CDP-compatible, for AI agent automation)
  programs.chromium.enable = true;

  # System packages
  # `with pkgs;` brings all pkgs attributes into scope so we can write `git`
  # instead of `pkgs.git` for every package in the list.
  environment.systemPackages = with pkgs; [
    # Development tools
    git
    gh
    nodejs_22
    vim
    neovim
    nano
    vscode

    # Language servers and linters
    nixd                          # Nix LSP
    bash-language-server          # Bash LSP
    shellcheck                    # Shell linter (used by bash-language-server)
    typescript-language-server    # TS/JS LSP

    # Network tools
    curl
    wget
    tailscale

    # Desktop helpers (local HDMI + Wi-Fi setup)
    networkmanagerapplet
    xorg.xrandr

    # Search and utility tools
    jq
    yq-go        # YAML processor for object frontmatter
    ripgrep
    fd
    tree
    htop

    # Terminal multiplexer (recommended for pi background tasks)
    tmux

    # AI coding tools
    piWrapper                  # Pi SDK CLI (npm-backed wrapper)
    (pkgsUnstable."claude-code-bin") # Claude Code CLI (native binary, patched for NixOS)
    nixpiCli                  # Primary Nixpi wrapper command
  ];

  # Ensure ~/.local/bin is in PATH
  environment.localBinInPath = true;

  # Activation scripts run as root during `nixos-rebuild switch`, after the
  # system is built but before services start. They're used for one-time setup.
  # `lib.stringAfter [ "users" ]` ensures this runs after user accounts exist.
  #
  # IMPORTANT:
  # - SYSTEM.md is declaratively refreshed on each activation so policy/prompt
  #   updates apply automatically.
  # - settings.json is seeded write-once to avoid clobbering runtime/user state.
  system.activationScripts.piConfig = lib.stringAfter [ "users" ] ''
    PI_DIR="${piDir}"

    install -d -o ${primaryUser} -g users "$PI_DIR"/{sessions,extensions,skills,prompts,themes}
    install -d -o ${primaryUser} -g users "${userHome}/Shared"

    # Keep SYSTEM.md in sync with declarative policy/prompt content.
    cat > "$PI_DIR/SYSTEM.md" <<'SYSEOF'
${piSystemPrompt}
SYSEOF
    chown ${primaryUser}:users "$PI_DIR/SYSTEM.md"

    # Seed settings if absent.
    # Single instance preloads Nixpi skills plus declarative extension sources.
    if [ ! -f "$PI_DIR/settings.json" ]; then
      cat > "$PI_DIR/settings.json" <<'JSONEOF'
${settingsSeedJson}
JSONEOF
    fi
    if [ -f "$PI_DIR/settings.json" ]; then
      chown ${primaryUser}:users "$PI_DIR/settings.json"
    fi
  '';

  # Keep login-manager display name aligned with configured primary user
  # display name, even when users.mutableUsers is enabled.
  system.activationScripts.syncPrimaryUserDisplayName = lib.stringAfter [ "users" ] ''
    if ${pkgs.glibc.bin}/bin/getent passwd ${primaryUserShell} >/dev/null; then
      currentGecos="$(${pkgs.glibc.bin}/bin/getent passwd ${primaryUserShell} | ${pkgs.gawk}/bin/awk -F: '{print $5}')"
      if [ "$currentGecos" != ${userDisplayNameShell} ]; then
        ${pkgs.shadow}/bin/usermod -c ${userDisplayNameShell} ${primaryUserShell}
      fi
    fi
  '';

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # stateVersion tells NixOS which version's defaults to use for stateful data
  # (databases, state directories). It does NOT control package versions.
  # Never change this after install — it would break existing state assumptions.
  system.stateVersion = "25.11";
  };
}
