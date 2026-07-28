{ pkgs, ... }:
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
  home.packages = with pkgs; [
    ripgrep
  ];

  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    settings.user.name = "little-sparkleeesss";
    settings.user.email = "little.sparkleeesss@gmail.com";
  };
}
