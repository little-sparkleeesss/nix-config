{ pkgs, ... }:
{
  programs.zsh.enable = true;
  # UPG（用户私有组）：与 Debian/Fedora 的 adduser 习惯一致，主组为同名私有组 ciallo，
  # 而非 isNormalUser 默认的共享 users 组。
  users.groups.ciallo = { };
  users.users.ciallo = {
    isNormalUser = true;
    description = "Ciallo";
    group = "ciallo";
    extraGroups = [
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEoQb9HkXH1o6M2wEC4c6Wos2ho/SX/xya/YYfpbZncn"
    ];
  };
}
