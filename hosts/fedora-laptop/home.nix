# Fedora 宿主：standalone home-manager（无 configuration.nix 兄弟；系统级由 Fedora/dnf 管）。
# 复用 modules/home/* 的 profile，与 NixOS 宿主共用同一套用户环境配置。
{ pkgs, cc-switch, ... }:
{
  imports = [
    ../../modules/home/zsh.nix
    ../../modules/home/claude-code.nix
  ];

  profiles.zsh.enable = true;
  profiles.claudeCode.enable = true;

  home.username = "ciallo";
  home.homeDirectory = "/home/ciallo";
  home.stateVersion = "26.05";

  # 本机专属包（不属于任何 profile）。git 由下方 programs.git 提供，无需重复列出。
  # cc-switch 由 flake 的 packages.x86_64-linux.cc-switch（autoPatchelfHook 打包官方 deb）
  # 经 extraSpecialArgs 传入，见 flake.nix 与 pkgs/cc-switch.nix。
  home.packages = with pkgs; [
    ripgrep
    lazygit
    cc-switch
  ];

  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    settings.user.name = "little-sparkleeesss";
    settings.user.email = "little.sparkleeesss@gmail.com";
  };
}
