{ config, pkgs, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # 二进制缓存：USTC 镜像优先，回退到官方 cache.nixos.org。
  # USTC 的 store 镜像只是 cache.nixos.org 的镜像，用的是同一把公钥，
  # 所以 trusted-public-keys 只需官方那一条即可。
  nix.settings.substituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.nixos.org/"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];
  time.timeZone = "Asia/Shanghai";
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.05";
}
