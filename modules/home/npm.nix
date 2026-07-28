{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.profiles.npm.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Node.js + npm（用户级 prefix + 国内镜像）";
  };

  config = lib.mkIf config.profiles.npm.enable {
    home.packages = [ pkgs.nodejs ];
    home.sessionPath = [ "$HOME/.npm-global/bin" ];
    # prefix 装到用户目录（免 sudo）；registry 用 npmmirror 国内镜像。
    home.file.".npmrc".text = ''
      prefix=~/.npm-global
      registry=https://registry.npmmirror.com
    '';
  };
}
