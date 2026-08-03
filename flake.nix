{
  description = "NixOS 配置";
  inputs = {
    # nixos-26.05 分支的 GitHub ref（commit-based）：lockfile 锁定具体 commit，不会像 channel
    # tarball 那样被覆盖而 stale；narHash 只在主动 `nix flake update` 且分支前进时才变。
    # store 产物仍走 USTC substituter 加速（见 modules/common.nix）；flake input 的源码 tarball
    # 首次 fetch 走 GitHub（一次性，缓存进 /nix/store）。home-manager 复用同一份 nixpkgs。
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
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
        extraSpecialArgs = {
          inherit inputs;
          cc-switch = self.packages.x86_64-linux.cc-switch;
          syncclipboard = self.packages.x86_64-linux.syncclipboard;
        };
        modules = [
          ./hosts/fedora-laptop/home.nix
        ];
      };

      # 自定义预编译包：cc-switch（Tauri 应用，用 autoPatchelfHook 打包官方 deb）。
      # 用 `nix build .#cc-switch` 构建；进 home.packages 即可由 home-manager 装给用户。
      packages.x86_64-linux.cc-switch =
        nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/cc-switch.nix
          { };
      packages.x86_64-linux.syncclipboard =
        nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/syncclipboard.nix
          { };

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
