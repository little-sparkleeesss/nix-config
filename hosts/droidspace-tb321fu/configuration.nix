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
  # NixOS 容器内没有挂载 overlayfs 的能力（不知为何 Debian 是可以的），rootful docker 默认的 overlay2 用不了，
  # 改用基于 FUSE 的 fuse-overlayfs 存储驱动。
  # 不能走 virtualisation.docker.storageDriver：它的 enum 不含 "fuse-overlayfs"，
  # 只能通过 daemon.settings（freeform）直接写 storage-driver。
  # NixOS 的 docker 模块不会按 storage-driver 自动把 fuse-overlayfs 装进 dockerd 的 PATH，
  # 故需手动经 extraPackages 提供给它，docker 的 fuse-overlayfs graphdriver 才能找到该二进制。
  # rootful 下无需 fusermount3：libfuse3 以 root 直接 mount() 即可（EPERM 时 fusermount3 也救不了）。
  virtualisation.docker.extraPackages = [ pkgs.fuse-overlayfs ];
  virtualisation.docker.daemon.settings = {
    # 容器内跑 docker 时关掉 iptables 管理，避免与宿主/容器网络栈冲突。
    iptables = false;
    storage-driver = "fuse-overlayfs";
  };
}
