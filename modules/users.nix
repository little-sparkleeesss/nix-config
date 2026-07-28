{ pkgs, ... }:
{
  programs.zsh.enable = true;
  users.users.ciallo = {
    isNormalUser = true;
    description = "Ciallo";
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
