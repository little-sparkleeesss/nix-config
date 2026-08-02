# fedora-laptop（Fedora + 独立 nix）

本机底层是 Fedora，nix 仅作**包管理器**安装（非 NixOS）。因此本目录只有 `home.nix`：系统级
（内核、systemd 服务、用户、网络、时区等）由 Fedora/dnf 管理，不进 flake。这里只跑 standalone
home-manager 管理用户环境，复用 `modules/home/*` 的 profile（zsh、claude-code 等）。

## 一次性准备（flake 之外的步骤）

这些步骤本 flake 管不到，需在 Fedora 上手动完成：

1. **装 nix（multi-user daemon）**。任选其一：
   - 官方脚本：`sh <(curl -L https://nixos.org/nix/install) --daemon`
   - 或 [Determinate 安装器](https://github.com/DeterminateSystems/nix-installer)（默认开 flakes）。

2. **配 `/etc/nix/nix.conf`**，与 NixOS 侧 `modules/common.nix` 对齐（国内加速 + flakes）：
   ```ini
   experimental-features = nix-command flakes
   substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/
   trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
   ```
   改完 `sudo systemctl restart nix-daemon`。

3. **把登录 shell 改成 zsh**：home-manager 无法改 `/etc/passwd`，需手动
   `chsh -s $(which zsh)`（zsh 由 home-manager 装好后再执行）。

## 应用配置

在仓库根目录：

```sh
nix run github:nix-community/home-manager/release-26.05 -- switch --flake .#ciallo@fedora-laptop
```

之后每次更新配置同样跑这条命令。home-manager 的 release 必须与 flake 锁定的 `release-26.05` 一致。
