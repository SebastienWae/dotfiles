{ inputs, lib, pkgs, config, home-manager, channels, ... }:
let
  nerdfont = {
    jetbrains = (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; });
  };

  clipboard_menu = pkgs.writeShellScriptBin "clipboard_menu" ''
    ${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi-wayland}/bin/rofi -dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
  '';

  power_menu = pkgs.writeShellScriptBin "power_menu" ''
    RESULT=$(echo -e "lock session\nsleep\nhibernate\nlogout\nreboot\nshutdown\nreload sway\nkill sway\nclear clipboard" | rofi -dmenu)

    SESSION_ID=$(loginctl list-sessions -o json | jq ".[] | select(.user == \"$USER\") | .session | tonumber")

    case "$RESULT" in
    "lock session")
      loginctl lock-session "$SESSION_ID"
      ;;
    "sleep")
      systemctl suspend
      ;;
    "hibernate")
      systemctl hibernate
      ;;
    "logout")
      loginctl kill-session "$SESSION_ID"
      ;;
    "reboot")
      reboot
      ;;
    "shutdown")
      shutdown now
      ;;
    "reload sway")
      swaymsg reload
      ;;
    "kill sway")
      swaymsg exit
      ;;
    "clear clipboard")
      rm $XDG_CACHE_HOME/cliphist/db
      ;;
    esac
  '';

  record_menu = pkgs.writeShellScriptBin "record_menu" ''
    RESULT=$(echo -e "full screen\ncurrent window\nselect region" | rofi -dmenu)

    export GRIM_DEFAULT_DIR="$HOME/Pictures/Screenshots"

    case "$RESULT" in
    "full screen")
      grim
      ;;
    "current window")
      grim -g "$(swaymsg -t get_tree | jq -j '.. | select(.type?) | select(.focused).rect | "\(.x),\(.y) \(.width)x\(.height)"')"
      ;;
    "select region")
      grim -g "$(slurp)"
      ;;
    esac
  '';

in
{
  sops.secrets.seb_password = {
    sopsFile = ./secrets.yaml;
    neededForUsers = true;
  };
  users = {
    users.seb = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "i2c" ];
      passwordFile = config.sops.secrets.seb_password.path;
    };
  };

  environment.persistence."/nix/persist".users.seb = {
    directories = [
      ".dotfiles"

      "Downloads"
      "Documents"

      ".config/mpv/watch_later"

      ".mozilla"

      ".vscode"
      ".config/Code"

      ".local/share/direnv"

      { directory = ".gnupg"; mode = "0700"; }
      { directory = ".ssh"; mode = "0700"; }
      { directory = ".local/share/keyrings"; mode = "0700"; }
    ];
    files = [
      ".bash_history"
      ".cache/rofi3.druncache"
    ];
  };

  home-manager.users.seb = {

    programs.home-manager.enable = true;

    home = {
      stateVersion = "22.11";
      # username = "seb";
      # homeDirectory = "/home/seb";
      packages = with pkgs; [
        jetbrains-mono
        material-design-icons
        zeal
        xdg-utils
        imv
        calibre
        obsidian
        slack
        keepassxc
        swaylock
        cliphist
        wl-clipboard
        libappindicator-gtk3
        grim
        slurp
        playerctl
        transmission-gtk
        ranger
        kitti3
      ] ++ [
        nerdfont.jetbrains
      ];
      sessionVariables = {
        EDITOR = "vim";
        VISUAL = "code";
      };
    };

    xdg.configFile = {
      "ranger/rc.conf".text = ''
        set show_hidden true
        default_linemode devicons2
        set preview_images true
        set preview_images_method kitty
      '';
      "ranger/plugins/devicons2".source = inputs.ranger-devicons2;
      "transmission/settings.json".source = ./transmission/settings.json;
      "lazygit/config.yml".source = ./lazygit/config.yml;
    };

    programs = {
      aria2 = {
        enable = true;
      };
      bat = {
        enable = true;
      };
      bottom = {
        enable = true;
      };
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      fzf = {
        enable = true;
      };
      git = {
        enable = true;
        userEmail = "sebastien@waegeneire.com";
        userName = "Sebastien Waegeneire";
        extraConfig = {
          init = {
            defaultBranch = "main";
          };
        };
      };
      jq = {
        enable = true;
      };
      lazygit = {
        enable = true;
      };
      lsd = {
        enable = true;
      };
      tealdeer = {
        enable = true;
      };
      yt-dlp = {
        enable = true;
      };
      bash = {
        enable = true;
        profileExtra = ''
          [ "$(tty)" = "/dev/tty1" ] && exec sway | logger -t sway
        '';
      };
      zsh = {
        enable = true;
        loginExtra = ''
          [ "$(tty)" = "/dev/tty1" ] && exec sway | logger -t sway
        '';
      };
      gpg = {
        enable = true;
      };
      firefox = {
        enable = true;
        package = channels.master.firefox;
        extensions = [ ];
        profiles = {
          default = {
            settings = {
              "browser.cache.disk.enable" = false;
              "browser.cache.memory.enable" = true;
              "browser.cache.memory.capacity" = 36196;
              "browser.aboutConfig.showWarning" = false;
              "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
              "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
              "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
              "browser.newtabpage.activity-stream.feeds.topsites" = false;
              "browser.search.region" = "US";
              "browser.startup.page" = 3;
              "dom.forms.autocomplete.formautofill" = false;
              "extensions.formautofill.creditCards.enabled" = false;
              "extensions.formautofill.addresses.enabled" = false;
              "media.eme.enabled" = true;
              "app.shield.optoutstudies.enabled" = false;
              "datareporting.healthreport.uploadEnabled" = false;
              "widget.gtk.overlay-scrollbars.enabled" = false;
              "signon.rememberSignons" = false;
              "findbar.highlightAll" = true;
            };
            extraConfig = '''';
            userChrome = '''';
            userContent = '''';
            id = 0;
            isDefault = true;
          };
        };
      };
      obs-studio = {
        enable = true;
      };
      sioyek = {
        enable = true;
        config = { };
      };
      kitty = {
        enable = true;
        font = {
          package = nerdfont.jetbrains;
          name = "JetBrainsMono Nerd Font Mono";
          size = 14;
        };
      };
      vscode = {
        enable = true;
        package = channels.master.vscode.fhsWithPackages (ps: with ps; [
          rnix-lsp
        ]);
      };
      mpv = {
        enable = true;
        config = {
          save-position-on-quit = true;
          af = "scaletempo2";
          sub-auto = "all";
          sub-file-paths = "sub:subs:subtitles:Sub:Subs:Subtitles";
          profile = "pseudo-gui";
          video-sync = "display-resample";
        };
        scripts = with pkgs.mpvScripts; [
          mpris
        ];
      };
      swaylock.settings = {
        color = "808080";
        font-size = 24;
        indicator-idle-visible = false;
        indicator-radius = 100;
        line-color = "ffffff";
        show-failed-attempts = true;
      };
      waybar = {
        enable = true;
        settings = {
          default = {
            layer = "top";
            position = "top";
            spacing = 10;
            output = [
              "eDP-1"
              "HDMI-A-1"
            ];
            modules-left = [ "clock" ];
            modules-center = [ "sway/workspaces" ];
            modules-right = [ "sway/mode" "pulseaudio" "battery#0" "battery#1" "tray" ];
            "clock" = {
              format = "{:%Y-%m-%d %H:%M}";
              tooltip = false;
            };
            "sway/workspaces" = {
              all-outputs = true;
              disable-scroll = true;
              persistent_workspaces = {
                "1" = [ ];
                "2" = [ ];
                "3" = [ ];
                "4" = [ ];
                "5" = [ ];
                "6" = [ ];
                "7" = [ ];
                "8" = [ ];
                "9" = [ ];
                "10" = [ ];
              };
            };
            "pulseaudio" = {
              format = "{icon}";
              format-bluetooth = "{icon} 󰂰";
              format-muted = "󰝟";
              format-source = "󰍬";
              format-source-muted = "󰍭";
              format-icons = {
                default = [ "󰕿" "󰖀" "󰕾" ];
              };
              scroll-step = 0.0;
              tooltip = false;
            };
            "battery#0" = {
              bat = "BAT0";
              tooltip = false;
              format = "{icon}";
              format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
              states = {
                full = 100;
                warning = 30;
                critical = 10;
              };
            };
            "battery#1" = {
              bat = "BAT1";
              tooltip = false;
              format = "{icon}";
              format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
              states = {
                full = 100;
                warning = 30;
                critical = 10;
              };
            };
            "backlight" = { };
            "tray" = {
              icon-size = 22;
              spacing = 10;
            };
          };
        };
        style = ''
          * {
            transition-property: none;
            transition-duration: 0;
          }

          window#waybar {
            font-family: Material Design Icons, JetBrainsMono Nerd Font Mono;
            color: #222222;
            background-color: #dddddd;
          }

          #clock {
            margin-left: 10px
          }

          #workspaces button {
            color: #222222;
            border-radius: 0;
            border: none;
          }
          #workspaces button:hover {
            background: rgba(0, 0, 0, 0);
            box-shadow: none;
            text-shadow: none;
            border: none;
            font-weight: bold;
          }
          #workspaces button:not(.persistent) {
            background-color: #fafafa;
          }
          #workspaces button.focused {
            font-weight: bold;
            background-color: #c9f1f1;
          }
          #workspace button.urgent {
            background-color: #f1c9c9;
          }

          #pulseaudio {
            font-size: 22px;
          }

          #battery {
            font-size: 20px;
          }
          #battery.full {
            color: #26A269;
          }
          #battery.warning {
            color: #FF7800;
          }
          #battery.critical {
            color: #E01B24;
          }

          #tray {
            margin-right: 10px
          }
        '';
      };
      rofi = {
        enable = true;
        package = pkgs.rofi-wayland;
      };
    };

    services = {
      gnome-keyring = {
        enable = true;
        components = [ "secrets" ];
      };
      kdeconnect = {
        enable = true;
        indicator = true;
      };
      mpris-proxy = {
        enable = true;
      };
      dunst = {
        enable = true;
        settings = {
          global = {
            width = 300;
            height = 300;
            offset = "30x50";
            origin = "top-right";
            transparency = 10;
            frame_color = "#eceff1";
            font = "Droid Sans 9";
          };

          urgency_normal = {
            background = "#37474f";
            foreground = "#eceff1";
            timeout = 10;
          };
        };
      };
      gpg-agent = {
        enable = true;
        enableExtraSocket = true;
        enableScDaemon = true;
        enableSshSupport = true;
        maxCacheTtl = 7200;
        maxCacheTtlSsh = 7200;
      };
      gammastep = {
        enable = true;
        provider = "manual";
        latitude = 47.745;
        longitude = 7.337;
        tray = true;
        temperature = {
          day = 6500;
          night = 2500;
        };
      };
      swayidle = {
        enable = true;
        events = [
          { event = "before-sleep"; command = "${pkgs.swaylock}/bin/swaylock"; }
          { event = "lock"; command = "${pkgs.swaylock}/bin/swaylock"; }
        ];
      };
      kanshi = {
        enable = true;
        profiles = {
          laptop = {
            outputs = [
              { criteria = "eDP-1"; status = "enable"; }
            ];
          };
          docked = {
            outputs = [
              { criteria = "eDP-1"; status = "disable"; }
              { criteria = "HDMI-A-1"; status = "enable"; }
            ];
          };
        };
      };
    };

    gtk = {
      enable = true;
      iconTheme = {
        package = pkgs.gnome.adwaita-icon-theme;
        name = "Adwaita";
      };
      cursorTheme = {
        package = pkgs.gnome.gnome-themes-extra;
        name = "Adwaita";
      };
      theme = {
        package = pkgs.gnome.gnome-themes-extra;
        name = "Adwaita";
      };
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 0;
      };
    };

    qt = {
      enable = true;
      platformTheme = "gnome";
      style = {
        package = pkgs.adwaita-qt;
        name = "adwaita";
      };
    };

    fonts.fontconfig.enable = true;

    wayland = {
      windowManager = {
        sway = {
          enable = true;
          config = {
            assigns = { };
            bars = [
              {
                command = "${pkgs.waybar}/bin/waybar";
              }
            ];
            bindkeysToCode = false;
            colors = {
              background = "#ffffff";
              focused = {
                background = "#285577";
                border = "#4c7899";
                childBorder = "#285577";
                indicator = "#2e9ef4";
                text = "#ffffff";
              };
              focusedInactive = {
                background = "#285577";
                border = "#4c7899";
                childBorder = "#285577";
                indicator = "#2e9ef4";
                text = "#ffffff";
              };
              placeholder = {
                background = "#285577";
                border = "#4c7899";
                childBorder = "#285577";
                indicator = "#2e9ef4";
                text = "#ffffff";
              };
              unfocused = {
                background = "#285577";
                border = "#4c7899";
                childBorder = "#285577";
                indicator = "#2e9ef4";
                text = "#ffffff";
              };
              urgent = {
                background = "#285577";
                border = "#4c7899";
                childBorder = "#285577";
                indicator = "#2e9ef4";
                text = "#ffffff";
              };
            };
            defaultWorkspace = "1";
            floating = {
              border = 2;
              criteria = [
                { title = "Firefox — Sharing Indicator"; }
              ];
              modifier = "Mod4";
              titlebar = false;
            };
            focus = {
              followMouse = false;
              forceWrapping = false;
              mouseWarping = false;
              newWindow = "smart";
            };
            fonts = { };
            gaps = {
              vertical = 0;
              horizontal = 0;
              top = 0;
              bottom = 0;
              left = 0;
              right = 0;
              inner = 0;
              outer = 0;
              smartBorders = "on";
              smartGaps = false;
            };
            input = { };
            keybindings =
              let
                progress_bar = { title, delimiter, value }: ''| ${pkgs.gawk}/bin/awk 'BEGIN {FS = "${delimiter}"};{system("${pkgs.dunst}/bin/dunstify -t 1000 -h string:x-canonical-private-synchronous:${title} ${title} -h int:value:" ${value})}' '';
                audio_cmd = cmd: "exec ${pkgs.wireplumber}/bin/wpctl ${cmd}";
                volume_cmd = cmd: (audio_cmd cmd) + " && ${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ " + progress_bar { title = "volume"; delimiter = " "; value = "($2 * 100)"; };
                brightness_cmd = cmd: "exec ${pkgs.brightnessctl}/bin/brightnessctl -m ${cmd} " + progress_bar { title = "brightness"; delimiter = ","; value = "$3"; };
                media_player_cmd = cmd: "exec ${pkgs.playerctl}/bin/playerctl ${cmd}";
              in
              {
                "F11" = "mode action";
                "XF86AudioMicMute" = audio_cmd "set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
                "XF86AudioMute" = audio_cmd "set-mute @DEFAULT_AUDIO_SINK@ toggle";
                "XF86AudioLowerVolume" = volume_cmd "set-volume @DEFAULT_AUDIO_SINK@ 5%-";
                "XF86AudioRaiseVolume" = volume_cmd "set-volume @DEFAULT_AUDIO_SINK@ 5%+";
                "XF86AudioPlay" = media_player_cmd "play-pause";
                "XF86AudioPause" = media_player_cmd "play-pause";
                "XF86AudioPrev" = media_player_cmd "previous";
                "XF86AudioNext" = media_player_cmd "next";
                "XF86MonBrightnessDown" = brightness_cmd "s 5%-";
                "XF86MonBrightnessUp" = brightness_cmd "s +5%";
              };
            modes =
              let
                left = "h";
                down = "j";
                up = "k";
                right = "l";
              in
              {
                action = {
                  "Escape" = "mode default";

                  "Return" = "mode default; exec ${pkgs.kitty}/bin/kitty";
                  "Shift+Return" = "mode default; exec ${pkgs.kitty}/bin/kitty";

                  "Space" = "mode default; exec ${pkgs.rofi-wayland}/bin/rofi -show drun";

                  "e" = "mode default;";
                  "Shift+e" = "mode default;";

                  "p" = "mode default; exec ${power_menu}/bin/power_menu";
                  "r" = "mode default; exec ${record_menu}/bin/record_menu";
                  "c" = "mode default; exec ${clipboard_menu}/bin/clipboard_menu";

                  "t" = "layout tabbed";
                  "s" = "layout splith";
                  "v" = "layout splitv";

                  "Shift+c" = "kill";
                  "Shift+f" = "floating toggle";
                  "Shift+s" = "sticky toggle";

                  #                  "=" = "resize grow width 2 ppt";
                  #                  "+" = "resize grow height 2 ppt";
                  #                  "-" = "resize shrink width 2 ppt";
                  #                  "_" = "resize shrink height 2 ppt";
                  #
                  "${left}" = "focus left";
                  "${down}" = "focus down";
                  "${up}" = "focus up";
                  "${right}" = "focus right";

                  "Shift+${left}" = "move left 20";
                  "Shift+${down}" = "move down 20";
                  "Shift+${up}" = "move up 20";
                  "Shift+${right}" = "move right 20";

                  "1" = "workspace 1";
                  "2" = "workspace 2";
                  "3" = "workspace 3";
                  "4" = "workspace 4";
                  "5" = "workspace 5";
                  "6" = "workspace 6";
                  "7" = "workspace 7";
                  "8" = "workspace 8";
                  "9" = "workspace 9";
                  "0" = "workspace 10";

                  "Shift+1" = "move container to workspace 1";
                  "Shift+2" = "move container to workspace 2";
                  "Shift+3" = "move container to workspace 3";
                  "Shift+4" = "move container to workspace 4";
                  "Shift+5" = "move container to workspace 5";
                  "Shift+6" = "move container to workspace 6";
                  "Shift+7" = "move container to workspace 7";
                  "Shift+8" = "move container to workspace 8";
                  "Shift+9" = "move container to workspace 9";
                  "Shift+0" = "move container to workspace 10";
                };
              };
            output = { };
            seat = { };
            startup = [
              {
                command = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
                always = true;
              }
            ];
            window = {
              border = 2;
              commands = [ ];
              hideEdgeBorders = "smart";
              titlebar = true;
            };
            workspaceAutoBackAndForth = false;
            workspaceLayout = "default";
            workspaceOutputAssign = [ ];
          };
          extraConfigEarly = ''
            exec_always --no-startup-id kitti3
            bindsym Shift+k nop kitti3
          '';
          extraConfig = '''';
          extraOptions = [ ];
          extraSessionCommands = ''
            export MOZ_ENABLE_WAYLAND=1
            export GDK_BACKEND=wayland
            export NIXOS_OZONE_WL=1
          '';
          wrapperFeatures.gtk = true;
        };
      };
    };

    xdg = {
      enable = true;
      systemDirs = {
        data = [
          "${pkgs.gammastep}/share"
        ];
      };
    };
  };
}
