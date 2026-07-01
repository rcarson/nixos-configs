{
  description = "NixOS configuration for roach";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
  };

  outputs = { self, nixpkgs, claude-code-nix, ...}: {
    nixosConfiguration.roach = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        { nixpkgs.overlays = [ claude-code-nix.overlays.default ]; }
      ];
    };
  };
}
