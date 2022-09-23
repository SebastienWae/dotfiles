{
  description = "nix systems config";

  inputs = {
    # channels
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    master.url = "github:nixos/nixpkgs";
    stable.url = "github:nixos/nixpkgs/nixos-22.05";

    # utils
    nixlib.url = "github:nix-community/nixpkgs.lib";
    utils.url = "github:numtide/flake-utils";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixlib";
    };
    impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "unstable";
    };

    # flakes

    # others
    ranger-devicons2 = {
      url = "github:cdump/ranger-devicons2";
      flake = false;
    };
  };

  outputs = inputs@{ self, utils, nixlib, ... }:
    let
      channels = {
        sharedConfig = {
          allowUnfree = true;
        };
        sharedOverlays = [
          (final: prev: {
            ctrl2f19 = import ./pkgs/ctrl2f19.nix { pkgs = final; };
          })
        ];
        set = {
          "unstable" = {
            input = inputs.unstable;
            config = { };
            overlays = [ ];
            patches = [ ];
          };
          "master" = {
            input = inputs.master;
            config = { };
            overlays = [ ];
            patches = [ ];
          };
          "stable" = {
            input = inputs.stable;
            config = { };
            overlays = [ ];
            patches = [ ];
          };
        };
      };

      hosts = {
        sharedExtraArgs = { };
        sharedModules = [ ];
        set = {
          "clover" = {
            system = "x86_64-linux";
            channel = "unstable";
            extraArgs = { };
            specialArgs = { };
            modules = [
              inputs.impermanence.nixosModules.impermanence
              inputs.sops-nix.nixosModules.sops
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.sharedModules = [ ];
              }
              ./hosts/clover/host.nix
              ./hosts/clover/home.nix
            ];
          };
        };
      };

      mkChannels = channels: system:
        let
          patchChannel = system: channel: patches:
            if patches == [ ] then channel else
            (import channel { inherit system; }).pkgs.applyPatches {
              name =
                if channel ? shortRev then
                  "nixpkgs-patched-${channel.shortRev}" else "nixpkgs-patched";
              src = channel;
              patches = patches;
            };

          mkChannel = name: value:
            (import (patchChannel system value.input (value.patches or [ ])) {
              inherit system;
              overlays = channels.sharedOverlays ++ (value.overlays or [ ]);
              config = channels.sharedConfig // (value.config or { });
            });
        in
        nixlib.lib.mapAttrs mkChannel channels.set;

      pkgs = nixlib.lib.lists.foldl
        (a: b: a // { ${b} = mkChannels channels b; })
        { } [ "x86_64-linux" ];

      mkHosts = hosts:
        let
          mkHost = hostname: host:
            let
              selectedNixpkgs = pkgs.${host.system}.${host.channel};
              patchedChannel = selectedNixpkgs.path;
              channels = pkgs.${host.system};

              specialArgs = host.specialArgs // { channels = pkgs.${host.system}; };

              lib = selectedNixpkgs.lib;
              baseModules = import (patchedChannel + "/nixos/modules/module-list.nix");
              nixosSpecialArgs =
                let
                  f = channelName:
                    { "${channelName}ModulesPath" = toString (channels.${channelName}.input + "/nixos/modules"); };
                in
                (nixlib.lib.foldl' (lhs: rhs: lhs // rhs) { } (map f (nixlib.lib.attrNames channels)))
                // { modulesPath = toString (patchedChannel + "/nixos/modules"); };
            in
            inputs.unstable.lib.nixosSystem ({
              inherit (host) system;
              inherit specialArgs;
              modules = [
                ({ pkgs, lib, options, config, ... }: {
                  _type = "merge";
                  contents = [
                    { networking.hostName = hostname; }
                    {
                      nixpkgs.config = selectedNixpkgs.config;
                      nixpkgs.pkgs = selectedNixpkgs;
                    }
                    { system.configurationRevision = lib.mkIf (self ? rev) self.rev; }
                    { nix.package = lib.mkDefault pkgs.nixUnstable; }
                    { nix.extraOptions = "extra-experimental-features = nix-command flakes"; }
                    { _module.args = { inherit inputs; } // host.extraArgs; }
                  ];
                })
              ] ++ host.modules;
            } // {
              inherit lib baseModules;
              specialArgs = nixosSpecialArgs // specialArgs;
            });
        in
        nixlib.lib.mapAttrs mkHost hosts.set;
    in
    {
      legacyPackages = pkgs;
      nixosConfigurations = mkHosts hosts;
    };
}
