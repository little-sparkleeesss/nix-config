{
  description = "NixOS 配置";
  inputs = {
    # 用 USTC 镜像的 nixos-26.05 频道 tarball（国内加速）；home-manager 复用同一份 nixpkgs。
    nixpkgs.url = "tarball+https://mirrors.ustc.edu.cn/nix-channels/nixos-26.05/nixexprs.tar.xz";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        "droidspace-tb321fu" = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            ./modules/common.nix
            ./modules/users.nix
            ./hosts/droidspace-tb321fu/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.backupFileExtension = "backup";
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.ciallo = import ./hosts/droidspace-tb321fu/home.nix;
            }
          ];
          specialArgs = { inherit inputs; };
        };
      };

      # `nix develop` 提供 .githooks/pre-commit 用到的格式化/lint 工具（nixfmt/statix/deadnix）。
      devShells =
        nixpkgs.lib.genAttrs
          [
            "x86_64-linux"
            "aarch64-linux"
          ]
          (
            system:
            let
              pkgs = nixpkgs.legacyPackages.${system};
            in
            {
              default = pkgs.mkShell {
                packages = with pkgs; [
                  nixfmt
                  statix
                  deadnix
                ];
              };
            }
          );
    };
}
