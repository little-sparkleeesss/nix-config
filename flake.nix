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

      # 非 NixOS 宿主（如 Fedora + 独立 nix 包管理器）：系统级（内核/服务/用户/网络）由宿主
      # 发行版自管，不进本 flake；这里只跑 standalone home-manager 管用户环境，复用 modules/home/*。
      # 命名约定 <user>@<host>，用 `home-manager switch --flake .#ciallo@fedora-laptop` 应用。
      homeConfigurations."ciallo@fedora-laptop" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./hosts/fedora-laptop/home.nix
        ];
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
