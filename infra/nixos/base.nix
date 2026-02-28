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
    You are Nixpi, an AI life companion running on a NixOS-based AI-first workstation.

    ## Environment
    - OS: NixOS (declarative, flake-based)
    - Config repo: ${repoRoot}
    - Rebuild: cd ${repoRoot} && sudo nixos-rebuild switch --flake .
    - VPN: Tailscale (services restricted to Tailscale + LAN)
    - File sync: Syncthing
    - Object store: flat-file markdown with YAML frontmatter in data/objects/
    - Persona: OpenPersona 4-layer identity in persona/ (SOUL, BODY, FACULTY, SKILL)

    ## Architecture
    - Hexagonal (Ports and Adapters) with TDD-first development
    - Shared domain library: @nixpi/core (packages/nixpi-core/)
    - Shell CRUD: scripts/nixpi-object.sh (requires yq-go + jq)
    - Matrix bridge: services/matrix-bridge/ (matrix-bot-sdk adapter)
    - NixOS modules: infra/nixos/modules/ (objects, heartbeat, matrix)
    - Service factory: infra/nixos/lib/mk-nixpi-service.nix

    ## Guidelines
    - Follow AGENTS.md conventions and persona/ identity layers
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

  # Shared npm environment setup for all Pi-based wrappers.
  # Suppresses noise, isolates cache/prefix to per-user Nixpi dirs.
  npmEnvSetup = ''
    export npm_config_update_notifier=false
    export npm_config_audit=false
    export npm_config_fund=false
    export npm_config_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/nixpi-npm"
    export npm_config_prefix="''${XDG_DATA_HOME:-$HOME/.local/share}/nixpi-npm-global"
    mkdir -p "$npm_config_cache" "$npm_config_prefix"
  '';

  # Lightweight Pi install path: use npm package directly via npx,
  # avoiding the large llm-agents flake dependency.
  # Internal-only — used by nixpiCli and service modules, not exposed in PATH.
  piWrapper = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.nodejs_22 ];
    text = ''
      ${npmEnvSetup}

      # Pin package version to keep behavior stable across rebuilds.
      exec npx --yes @mariozechner/pi-coding-agent@${config.nixpi.piAgentVersion} "$@"
    '';
  };

  nixpiCli = pkgs.writeShellApplication {
    name = "nixpi";
    runtimeInputs = [ pkgs.jq pkgs.nodejs_22 piWrapper ];
    text = ''
      PI_BIN="${piWrapper}/bin/pi"
      PI_DIR="${piDir}"
      REPO_ROOT="${repoRoot}"
      EXTENSIONS_MANIFEST="$REPO_ROOT/infra/pi/extensions/packages.json"
    '' + builtins.readFile ./scripts/nixpi-cli.sh;
  };

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
    default = "0.55.3";
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

  options.nixpi._internal.npmEnvSetup = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    description = "Shared npm environment setup snippet for Pi-based wrappers. Internal use only.";
  };

  options.nixpi._internal.piWrapperBin = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    description = "Store path to the internal pi wrapper binary. Internal use only.";
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
    ./modules/matrix.nix
    ./modules/tailscale.nix
    ./modules/ttyd.nix
    ./modules/syncthing.nix
    ./modules/password-policy.nix
  ];

  config = {
    nixpi._internal.npmEnvSetup = npmEnvSetup;
    nixpi._internal.piWrapperBin = "${piWrapper}/bin/pi";
    nixpi.objects.enable = lib.mkDefault true;
    nixpi.tailscale.enable = lib.mkDefault true;
    nixpi.ttyd.enable = lib.mkDefault true;
    nixpi.syncthing.enable = lib.mkDefault true;
    nixpi.passwordPolicy.enable = lib.mkDefault true;

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

  # Firewall policy: SSH is reachable from Tailscale + LAN (bootstrap).
  # Service-specific rules live in their modules (syncthing, ttyd, etc.).
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
    '';
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

    # Terminal multiplexer
    tmux

    # AI coding tools
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
    if ${lib.getExe' pkgs.glibc.bin "getent"} passwd ${primaryUserShell} >/dev/null; then
      currentGecos="$(${lib.getExe' pkgs.glibc.bin "getent"} passwd ${primaryUserShell} | ${lib.getExe' pkgs.gawk "awk"} -F: '{print $5}')"
      if [ "$currentGecos" != ${userDisplayNameShell} ]; then
        ${lib.getExe' pkgs.shadow "usermod"} -c ${userDisplayNameShell} ${primaryUserShell}
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
