{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.profiles.zsh.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "zsh + powerlevel10k + 自动补全 + 语法高亮 + oh-my-zsh";
  };

  config = lib.mkIf config.profiles.zsh.enable {
    home.packages = with pkgs; [
      zsh-powerlevel10k
      # HM 的 zsh 模块会在 .zshrc 里 source 这两个包，但 release-26.05 并未把它们加入
      # home.packages，导致每次启动报 "no such file"。这里显式装上。
      zsh-autosuggestions
      zsh-syntax-highlighting
    ];

    home.shell.enableZshIntegration = true;
    home.file.".p10k.zsh".source = ./p10k.zsh;

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      initContent = lib.mkMerge [
        # Powerlevel10k instant-prompt 前导块：启用 ~/.p10k.zsh 里配置的 instant prompt
        # （POWERLEVEL9K_INSTANT_PROMPT=verbose）。没有这段前导该设置不生效（instant prompt
        # 保持关闭）。必须排在任何可能向终端输出内容的代码之前，故用 mkBefore（order 500）。
        (lib.mkBefore ''
          # 启用 Powerlevel10k instant prompt。应尽量靠近 ~/.zshrc 顶部。
          # 可能需要控制台输入的初始化代码（密码提示、[y/n] 确认等）必须放在本块之上；其余可放之下。
          if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
            source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
          fi
        '')
        # 主配置：加载 p10k 主题，再加载生成的 ~/.p10k.zsh。
        # $HOME/.npm-global/bin 已由 npm / claudeCode profile 通过 home.sessionPath 加入 PATH，
        # 这里无需手动 export。
        ''
          # 终端只声明 xterm（8 色）时升级为 256 色，p10k 的 256 色配色才生效。
          # TERM 是声明而非测量：现代 xterm 类终端实际都支持 256 色，但有些客户端把它
          # 设成 xterm，导致 zsh/p10k 查 terminfo 以为只有 8 色、不发 256 色码。
          # 真 8 色终端（如 TERM=linux）不会命中本条件。
          [[ $TERM == xterm ]] && export TERM=xterm-256color
          source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
          [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
        ''
      ];
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      oh-my-zsh = {
        enable = true;
        package = pkgs.oh-my-zsh;
        plugins = [ "git" ];
      };
    };
  };
}
