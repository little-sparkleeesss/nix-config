# Fedora 宿主：standalone home-manager（无 configuration.nix 兄弟；系统级由 Fedora/dnf 管）。
# 复用 modules/home/* 的 profile，与 NixOS 宿主共用同一套用户环境配置。
{
  lib,
  pkgs,
  pkgs-unstable,
  cc-switch,
  syncclipboard,
  ...
}:
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
  # vscode 与 bitwarden-desktop 取自 nixpkgs-unstable（见 flake.nix 的 nixpkgs-unstable
  # input）：vscode 更新频繁走 unstable；bitwarden 是稳定版所用 electron 较老、已 EOL。
  home.packages = with pkgs; [
    # vscode 是微软官方构建（闭源），unfree 放行在 flake.nix 的 pkgs-unstable 实例上；
    # 介意闭源可选 vscodium
    pkgs-unstable.vscode
    ripgrep
    lazygit
    cc-switch
    syncclipboard
    pkgs-unstable.bitwarden-desktop
  ];

  # SyncClipboard 上游 bug 的 workaround：Program.cs 的 catch 块向
  # ~/.config/SyncClipboard/log/ 直接 File.WriteAllText 写崩溃转储，但 Env.LogFolder
  # （Commons/Env.cs）漏了 GetOrCreateFolder（同文件里 file/assets/data/update 都有），
  # Logger 写日志时才会建目录。启动早期崩溃时该目录不存在 -> dmp 写入失败 -> 二次崩溃
  # （abort）。这里预建目录，保证任何崩溃都能正常落盘 dmp。
  home.activation.createSyncClipboardLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.config/SyncClipboard/log"
  '';

  # Bitwarden SSH agent：socket 由 Bitwarden 运行时创建于 ~/.bitwarden-ssh-agent.sock
  # （非 Flatpak 沙箱路径）。ssh 客户端不会自动发现它，需把 SSH_AUTH_SOCK 指过去。
  # 注意：这会接管 SSH_AUTH_SOCK，覆盖 GNOME keyring / ssh-agent 等既有 agent；
  #       不用 Bitwarden 时删掉本行即可恢复。
  home.sessionVariables.SSH_AUTH_SOCK = "\${HOME}/.bitwarden-ssh-agent.sock";

  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    settings.user.name = "little-sparkleeesss";
    settings.user.email = "little.sparkleeesss@gmail.com";
    settings.user.signingKey = "BD9ED369997D7931";
    settings.commit.gpgsign = true;
    settings.tag.gpgSign = true;
  };
}
