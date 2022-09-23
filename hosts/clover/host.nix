{ inputs, lib, config, pkgs, ... }:
{
  boot = {
    kernelModules = [ "kvm-amd" "acpi_call" "i2c-dev" ];
    extraModulePackages = with config.boot.kernelPackages; [
      acpi_call
      ddcci-driver
    ];
    initrd = {
      availableKernelModules = [ "ehci_pci" "xhci_pci" "ahci" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
      kernelModules = [ ];
    };
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
      };
      efi.canTouchEfiVariables = true;
    };
  };

  sops = {
    age.sshKeyPaths = [ "/nix/persist/etc/ssh/ssh_host_ed25519_key" ];
  };

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
    };
    "/nix" = {
      device = "/dev/disk/by-uuid/609d047a-4344-4b4d-84d1-4bd4394e8cac";
      fsType = "btrfs";
      options = [ "compress=zstd" "noatime" "subvol=nix" ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/C488-B73F";
      fsType = "vfat";
    };
    "/swap" = {
      device = "/dev/disk/by-uuid/609d047a-4344-4b4d-84d1-4bd4394e8cac";
      fsType = "btrfs";
      options = [ "noatime" "subvol=swap" ];
    };
  };

  swapDevices = [{ device = "/swap/swapfile"; }];

  console = {
    font = "ter-v32n";
  };

  hardware = {
    enableRedistributableFirmware = lib.mkDefault true;
    enableAllFirmware = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    i2c = {
      enable = true;
      group = "i2c";
    };
    bluetooth = {
      enable = true;
      package = pkgs.bluez5-experimental;
      powerOnBoot = true;
    };
    opengl = {
      enable = true;
      driSupport = true;
    };
  };

  networking = {
    hostName = "clover";
    useDHCP = lib.mkDefault true;
    networkmanager = {
      enable = true;
      dns = "none";
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 7564 ];
      allowedTCPPortRanges = [
        { from = 1714; to = 1764; }
      ];
      allowedUDPPortRanges = [
        { from = 1714; to = 1764; }
      ];
    };
  };

  time.timeZone = "Europe/Paris";

  programs.fuse.userAllowOther = true;

  services = {
    gnome.gnome-keyring.enable = true;
    udev.extraRules = ''
      ACTION=="add", KERNEL=="snd_seq_dummy", SUBSYSTEM=="module", RUN{builtin}+="kmod load ddcci_backlight"
    '';
    dnscrypt-proxy2 = {
      enable = true;
      settings = {
        ipv6_servers = true;
        require_dnssec = true;

        sources.public-resolvers = {
          urls = [
            "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
            "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
          ];
          cache_file = "/var/lib/dnscrypt-proxy2/public-resolvers.md";
          minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
        };
      };
    };
    pipewire = {
      enable = true;
      wireplumber.enable = true;
      pulse.enable = true;
      jack.enable = true;
      audio.enable = true;
      alsa.enable = true;
      socketActivation = true;
    };
    interception-tools = {
      enable = true;
      plugins = with pkgs.interception-tools-plugins; [
        dual-function-keys
      ];
      udevmonConfig = ''
- JOB: "${pkgs.interception-tools}/bin/intercept -g $DEVNODE | ${pkgs.interception-tools-plugins.dual-function-keys}/bin/dual-function-keys -c ${./interception/dual-function-keys.yaml} | ${pkgs.interception-tools}/bin/uinput -d $DEVNODE"
  DEVICE:
    EVENTS:
      EV_KEY: [KEY_CAPSLOCK, KEY_ESC, KEY_RIGHTCTRL, KEY_LEFTCTRL]
'';
    };
    dbus.enable = true;
  };

  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  fonts = {
    fonts = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      material-icons
    ];
    fontconfig.defaultFonts.emoji = [
      "Material Design Icons"
      "Noto Color Emoji"
    ];
  };

  environment = {
    shells = [
      pkgs.bashInteractive
    ];
    systemPackages = with pkgs; [
      terminus_font
      vim
      curl
      git
      gnupg
      age
      ddcutil
      brightnessctl
    ];
    persistence."/nix/persist" = {
      hideMounts = false;
      directories = [
        "/var/log"
        "/var/lib/systemd/coredump"
        "/var/lib/bluetooth"
        "/etc/NetworkManager/system-connections"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
    };
  };

  powerManagement.enable = true;

  systemd = {
    sleep = {
      extraConfig = ''
        AllowSuspendThenHibernate=yes
        AllowHibernation=yes
        SuspendMode=suspend
        HibernateMode=platform
        SuspendState=mem
        HibernateState=disk
        HibernateDelaySec=3600
      '';
    };
    services."ddcci@" = {
      wantedBy = [ "multi-user.target" ];
      scriptArgs = "%i";
      script = ''
        echo Trying to attach ddcci to $1
        i=0
        id=$(echo $1 | cut -d "-" -f 2)
        if ${pkgs.ddcutil}/bin/ddcutil getvcp 10 -b $id; then
          echo ddcci 0x37 > /sys/bus/i2c/devices/$1/new_device
        fi
      '';
      serviceConfig.Type = "oneshot";
    };
    services.dnscrypt-proxy2.serviceConfig = {
      StateDirectory = "dnscrypt-proxy";
    };
  };

  sops.secrets.root_password = {
    sopsFile = ./secrets.yaml;
    neededForUsers = true;
  };
  users = {
    mutableUsers = false;
    users.root.passwordFile = config.sops.secrets.root_password.path;
  };

  system.stateVersion = "22.11";

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      substituters = [
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };
    registry = lib.mapAttrs (_: value: { flake = value; })
      (lib.filterAttrs (_: value: value ? outputs) inputs);
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
  };
  nixpkgs = {
    hostPlatform = "x86_64-linux";
  };

  security = {
    sudo = {
      extraConfig = ''
        Defaults lecture = never 
      '';
    };
    pam.services = {
      swaylock = { };
    };
  };
}
