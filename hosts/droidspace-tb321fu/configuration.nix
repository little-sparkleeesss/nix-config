{ pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];
  networking.firewall.enable = false;
  networking.hostName = "droidspace-tb321fu";
  # Droidspace 容器不具备 Nix 沙箱所需的能力。
  nix.settings.sandbox = false;
  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings = {
    # 容器内跑 docker 时关掉 iptables 管理，避免与宿主/容器网络栈冲突。
    iptables = false;
  };
}
