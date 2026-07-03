{
  description = "NixOS configurations for roach and crafty";

  inputs = {
    # Pinned to the 26.05 release channel for reproducible, stable builds.
    # Shared by both hosts so they build against the same package set.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # roach: up-to-date claude-code package (not yet in nixpkgs) + ThinkPad tuning.
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # crafty: Minecraft server module + Hermes agent module.
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    hermes-agent.url = "github:NousResearch/hermes-agent";

    # Secrets management, shared by both hosts.
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, claude-code-nix, nixos-hardware, nix-minecraft, hermes-agent, sops-nix, ... }: {
    nixosConfigurations = {
      roach = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./modules/common.nix
          ./hosts/roach/hardware-configuration.nix
          ./hosts/roach/configuration.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
          sops-nix.nixosModules.sops
          { nixpkgs.overlays = [ claude-code-nix.overlays.default ]; }
        ];
      };

      crafty = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./modules/common.nix
          ./hosts/crafty/hardware-configuration.nix
          ./hosts/crafty/configuration.nix
          hermes-agent.nixosModules.default
          nix-minecraft.nixosModules.minecraft-servers
          sops-nix.nixosModules.sops
          { nixpkgs.overlays = [ nix-minecraft.overlay ]; }
        ];
      };
    };
  };
}
