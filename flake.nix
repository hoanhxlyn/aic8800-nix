{
  description = "NixOS driver and module for AIC8800D80 WiFi 6 chipset";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Support common Linux systems
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Helper to generate attributes for all systems
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Helper to get nixpkgs for a system
      nixpkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      # Kernel module packages for each system
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor system;
        in
        {
          # Default package: driver for the default kernel
          default = pkgs.linuxPackages.callPackage ./default.nix { };

          # Also provide driver for latest kernel
          latest = pkgs.linuxPackages_latest.callPackage ./default.nix { };
        }
      );

      # NixOS module for system integration
      nixosModules.default = import ./module.nix;

      # Alias for convenience
      nixosModules.aic8800 = self.nixosModules.default;

      # Development shell for testing and building
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor system;
        in
        {
          default = pkgs.mkShell {
            name = "aic8800-dev";

            nativeBuildInputs = with pkgs; [
              # Kernel build dependencies
              gnumake
              gcc
              pkg-config

              # For testing
              linuxPackages.kernel.dev
              kmod

              # Useful tools
              git
              nix-output-monitor
            ];

            shellHook = ''
              echo "AIC8800D80 WiFi Driver Development Environment"
              echo "=============================================="
              echo ""
              echo "Available commands:"
              echo "  nix build .#default         - Build driver for default kernel"
              echo "  nix build .#latest          - Build driver for latest kernel"
              echo "  nixos-rebuild switch        - Install on NixOS"
              echo ""
              echo "Kernel version: ${pkgs.linuxPackages.kernel.version}"
            '';
          };
        }
      );

      # Formatter for Nix files (use alejandra or nixpkgs-fmt)
      formatter = forAllSystems (system: (nixpkgsFor system).alejandra);
    };
}
