{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixos-generators, ... }:
    let
      pkgsForSystem = system: import nixpkgs { inherit system; };
      allVMs = [ "x86_64-linux" "aarch64-linux" ];
      forAllVMs = f: nixpkgs.lib.genAttrs allVMs (system: f {
        inherit system;
        pkgs = pkgsForSystem system;
      });
    in
    {
      nixosConfigurations = forAllVMs ({ system, pkgs }: {
        default = nixpkgs.lib.nixosSystem {
          system = system;
          specialArgs = {
            system = system;
            pkgs = pkgs;
          };
          modules = [
            # Pin nixpkgs to the flake input, so that the packages installed
            # come from the flake inputs.nixpkgs.url.
            ({ ... }: { nix.registry.nixpkgs.flake = nixpkgs; })
            # Apply the rest of the config.
            ./configuration.nix
            ({ ... }: { system.stateVersion = "24.05"; })
          ];
        };
      });
    };
}
