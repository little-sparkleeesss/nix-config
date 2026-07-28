{
  pkgs,
  lib,
  config,
  ...
}:
{
  # Claude Code 是 npm 包，显式依赖 npm profile（由它提供 nodejs、~/.npmrc 镜像、~/.npm-global/bin）。
  imports = [ ./npm.nix ];

  options.profiles.claudeCode.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Anthropic Claude Code CLI（npm 装到 ~/.npm-global）";
  };

  config = lib.mkIf config.profiles.claudeCode.enable {
    # 软依赖：开 Claude Code 默认连带开 npm；host 可用 `profiles.npm.enable = false` 覆盖。
    # 用 mkDefault（priority 1000）而非断言，既显式又不死板。
    profiles.npm.enable = lib.mkDefault true;

    home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.npm-global"
      export PATH="${pkgs.nodejs}/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.gnutar}/bin:${pkgs.git}/bin:$PATH"
      claude_bin="$HOME/.npm-global/bin/claude"
      needs_install=0
      # 同时检测「未安装」和「软链指向非 ELF（.exe）」两种情况：解析软链并校验 ELF 魔数（0x7f E L F）。
      if [ ! -e "$claude_bin" ]; then
        needs_install=1
      else
        real_bin="$(readlink -f "$claude_bin" 2>/dev/null || true)"
        if [ -z "$real_bin" ] || ! head -c4 "$real_bin" 2>/dev/null | grep -q $'\x7fELF'; then
          needs_install=1
        fi
      fi
      if [ "$needs_install" = "1" ]; then
        echo "[HM Activation] 正在安装 @anthropic-ai/claude-code ..."
        # registry 与 prefix 都由 npm profile 的 ~/.npmrc 提供（npmmirror 镜像 + ~/.npm-global），
        # 这里不再自带 --registry/--prefix，正经走 npm 配置。
        $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install -g --no-fund --no-audit @anthropic-ai/claude-code
      else
        echo "[HM Activation] claude-code 已存在且为 ELF，跳过安装"
      fi
    '';
  };
}
