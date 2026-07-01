{
  description = "NixOS configuration for roach";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, claude-code-nix, nixos-hardware, ...}: {
    nixosConfigurations.roach = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
        { nixpkgs.overlays = [ claude-code-nix.overlays.default ]; }
      ];
    };
  };
}
