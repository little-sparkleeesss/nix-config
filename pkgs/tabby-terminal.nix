# Tabby（Eugeny/tabby，https://tabby.sh/）：Electron 终端模拟器，本地 shell/SSH/串口客户端。
# nixpkgs 里的 `tabby` 是 sharkdp 的 cat 克隆（同名不同物），本包命名为 tabby-terminal
# （与官方 packagecloud 的包名一致，也避免与 nixpkgs.tabby 混淆）。
# 官方只发预编译产物（deb/rpm/AppImage/tar.gz），这里用 autoPatchelfHook 重打包 linux-x64
# tar.gz，思路与 pkgs/cc-switch.nix 一致；tar.gz 内含完整 Electron 运行时（自带
# libffmpeg/libEGL/libGLESv2/libvulkan）与原生 node 模块（app.asar.unpacked）。
#
# 依赖清单来自对 tarball 内所有 ELF 跑 `readelf -d` 汇总的 NEEDED：
#   主二进制（Electron/Chromium 标准集）：glib/gobject/gio -> glib，
#     nspr/nss(nss3/nssutil3/smime3) -> nspr/nss，dbus，atk，atk-bridge -> at-spi2-atk，
#     libatspi -> at-spi2-core，cups，cairo，gtk3，pango，expat，
#     libX11/libXcomposite/libXdamage/libXext/libXfixes/libXrandr/libxcb -> libx11 等，
#     libgbm -> mesa，libxkbcommon，libudev -> systemdLibs，libasound -> alsa-lib，libgcc_s。
#   原生模块（决定额外依赖）：
#     keytar.node 需要 libsecret（SSH 密码/凭据存 Secret Service），
#     fontmanager-redux.node 需要 libfontconfig，
#     node-pty/serialport/russh 需要 libstdc++/libutil（glibc 自带）。
#   tarball 里的 app.asar.unpacked 同时带上其他平台（musl/android/arm32/arm64）的预编译
#   .node，这些在本机 x86_64 glibc 上永远用不到，但其 NEEDED 里的 libc.musl-x86_64.so.1 /
#   ld-linux-aarch64.so.1 / ld-linux-armhf.so.3 / android 的 liblog/libc++_shared 等不存在
#   于 store，必须进 autoPatchelfIgnoreMissingDeps 忽略，否则 autoPatchelf 报错。
#
# Electron 特有的处理：
#   1. 主二进制 NEEDED libffmpeg.so 等自带库与其同目录，autoPatchelf 只补 buildInputs 的
#     RPATH、不含应用自身目录，故 wrapper 的 LD_LIBRARY_PATH 必须加 $out/lib/tabby-terminal。
#   2. EGL vendor 链问题与 cc-switch 相同（glvnd 按 50_mesa.json 的相对名 dlopen
#     libEGL_mesa.so.0，nix 加载器不搜宿主 /usr/lib64）：Chromium 找不到 EGL vendor 会
#     回退 SwiftShader 软渲染，故同样用 __EGL_VENDOR_LIBRARY_DIRS 指向 mesa 的
#     egl_vendor.d + LD_LIBRARY_PATH 提供 mesa/libglvnd，拿到硬件加速。
#   3. Chromium 运行时 dlopen libwayland/pipewire（Wayland 渲染与屏幕共享），非 NEEDED，
#     只能由 LD_LIBRARY_PATH 提供；另加 --ozone-platform-hint=auto 让 Wayland 会话下
#     走原生 Wayland 而非 XWayland。
#   4. GPU 进程沙箱：Chromium 的 userns/seccomp 沙箱在 Fedora 上会挡住 /dev/dri 访问
#     （日志 "Failed to find drm render node path"），并导致 GPU 进程约 5 秒后崩溃
#     （"GPU process launch failed: error_code=1002" -> "FATAL: GPU process isn't
#     usable"），整个应用回退软渲染。加 --disable-gpu-sandbox 后 GPU 进程稳定、
#     DRM 节点恢复（实测对照：有沙箱崩溃 9 次，无沙箱 0 次）。
#   5. 启动时的 "MESA-LOADER: failed to open dri: /run/opengl-driver/lib/gbm/dri_gbm.so"
#     警告：Chromium dlopen 的 libgbm 来自 nixpkgs 的 mesa-libgbm（26.0.3，与主 mesa
#     26.1.5 不同版本），其编译期 gbm-backends-path 是 NixOS 的 /run/opengl-driver/lib/gbm
#     （NixOS 由模块建 symlink，Fedora 没有）。该路径硬编译进库，loader 的环境变量
#     （MESA_LOADER_DRIVER_PATH）在此调用链上不生效（实测：进程 env 里有变量、uid 正常，
#     警告仍显示编译期内置路径），只能在 flake 层重编译 mesa-libgbm 把路径指向 store 内的
#     驱动软链目录（见 flake.nix 的 libgbm 覆盖）。
#   GTK 的 "Failed to load module colorreload/window-decorations-gtk-module" 警告是 KDE
#   Plasma 写在 ~/.config/gtk-3.0/settings.ini 的 gtk-modules（KDE 主题模块），nix 的 gtk3
#   里没有这些模块，加载失败但无害，无法也不值得屏蔽。
#   chrome-sandbox 无需特殊处理：Fedora 默认开启非特权 userns，Electron 不用 setuid 也能用。
{
  lib,
  stdenv,
  autoPatchelfHook,
  wrapGAppsHook3,
  fetchurl,
  makeDesktopItem,
  glib,
  nspr,
  nss,
  dbus,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cups,
  cairo,
  gtk3,
  pango,
  expat,
  libxkbcommon,
  systemdLibs,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
  mesa,
  libglvnd,
  alsa-lib,
  gcc-unwrapped,
  libsecret,
  fontconfig,
  pipewire,
  wayland,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "tabby-terminal";
  version = "1.0.235";

  src = fetchurl {
    url = "https://github.com/Eugeny/tabby/releases/download/v${finalAttrs.version}/tabby-${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-rxlNHA6tfBkBJ6qRGlYFK6CIvghbH22FJql/MNsUlis=";
  };

  # 图标：tarball 不含应用图标（只有截图），从 release tag 的 build/icons 取官方 512x512。
  icon = fetchurl {
    url = "https://raw.githubusercontent.com/Eugeny/tabby/v${finalAttrs.version}/build/icons/512x512.png";
    hash = "sha256-KAVVYrZJyt8MYm+/hzh6n2K3EzEaQxd1BGnpkyqrbMw=";
  };

  desktopItem = makeDesktopItem {
    name = "tabby-terminal";
    exec = "tabby %F";
    icon = "tabby";
    desktopName = "Tabby";
    genericName = "Terminal emulator";
    comment = "Terminal emulator, SSH and serial client";
    categories = [
      "System"
      "TerminalEmulator"
    ];
    mimeTypes = [ "x-scheme-handler/ssh" ];
    startupWMClass = "tabby";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
  ];

  # DT_NEEDED 硬依赖：autoPatchelf 补 RPATH（nss 只进 RPATH、不进 wrapper 的
  # LD_LIBRARY_PATH，避免泄漏给子进程的 xdg-open，与 nixpkgs discord 处理一致）。
  buildInputs = [
    glib
    nspr
    nss
    dbus
    atk
    at-spi2-atk
    at-spi2-core
    cups
    cairo
    gtk3
    pango
    expat
    libxkbcommon
    systemdLibs
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    mesa
    alsa-lib
    gcc-unwrapped
    stdenv.cc.cc.lib
    libsecret
    fontconfig
  ];

  # 随包附带的其他平台预编译 .node（musl/android/arm32/arm64）的依赖在本机 x86_64
  # glibc 环境不存在，且这些文件永远不会被加载，忽略之（见文件头注释）。
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "ld-linux-aarch64.so.1"
    "ld-linux-armhf.so.3"
    "liblog.so"
    "libc++_shared.so"
    "libc.so"
    "libm.so"
    "libdl.so"
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  # wrapGAppsHook3 默认只自动包装 $out/bin 下的可执行文件，而 electron 主二进制必须与
  # resources/locales 同目录（相对自身路径加载），装在 $out/lib/tabby-terminal/。
  # 故关掉自动包装（dontWrapGApps），在 installPhase 手动 wrapProgram 并展开
  # gappsWrapperArgs（GTK schemas/pixbuf loader/XDG_DATA_DIRS），与 nixpkgs discord 同款做法。
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/tabby-terminal $out/bin $out/share/icons/hicolor/512x512/apps
    tar xzf $src -C $out/lib/tabby-terminal --strip-components=1
    chmod +x $out/lib/tabby-terminal/tabby

    cp $icon $out/share/icons/hicolor/512x512/apps/tabby.png
    cp -r $desktopItem/share/. $out/share/

    # LD_LIBRARY_PATH：应用自身目录（libffmpeg.so 等自带库，见文件头注释 1）
    # + mesa/libglvnd（EGL vendor 链，注释 2）+ pipewire/wayland（dlopen，注释 3）。
    # __EGL_VENDOR_LIBRARY_DIRS 指向 mesa 的 egl_vendor.d（与 cc-switch 相同）。
    # --disable-gpu-sandbox：GPU 进程沙箱在 Fedora 上崩溃，见文件头注释 4。
    wrapProgram $out/lib/tabby-terminal/tabby \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          mesa
          libglvnd
          pipewire
          wayland
        ]
      }:$out/lib/tabby-terminal" \
      --set __EGL_VENDOR_LIBRARY_DIRS ${mesa}/share/glvnd/egl_vendor.d \
      --add-flags "--ozone-platform-hint=auto --disable-gpu-sandbox"

    ln -s $out/lib/tabby-terminal/tabby $out/bin/tabby
    runHook postInstall
  '';

  meta = {
    description = "Terminal emulator, SSH and serial client (self-contained Electron)";
    homepage = "https://github.com/Eugeny/tabby";
    license = lib.licenses.mit;
    mainProgram = "tabby";
    platforms = [ "x86_64-linux" ];
  };
})
