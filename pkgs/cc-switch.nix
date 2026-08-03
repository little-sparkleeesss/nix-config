# cc-switch 是 Tauri（Rust）桌面应用，官方只发预编译 deb/rpm/AppImage。
# 这里用 autoPatchelfHook 把官方 deb 重新打包成 nix 包：fetchurl 拉 deb -> dpkg -x 解包 ->
# autoPatchelfHook 给 ELF 二进制补 RPATH、到 nix store 找运行时库（webkit2gtk-4.1/gtk3/...）。
# 产物进 home.packages，由 home-manager 装给用户，声明式、纯用户态，无 flatpak/OSTree/daemon。
# 依赖清单来自 `readelf -d` 的 NEEDED：libwebkit2gtk-4.1/libsoup-3.0/javascriptcoregtk-4.1
# （-> webkitgtk_4_1，它同时提供 webkit2gtk-4.1 与 javascriptcoregtk-4.1，并传播 libsoup_3）、
# gtk3、glib、gdk-pixbuf、cairo、openssl、xz，以及 libgcc_s（-> gcc-unwrapped）。
# 另有运行时 dlopen 的 libayatana-appindicator3（Tauri 托盘，非 NEEDED），见下 preFixup 的 gappsWrapperArgs。
#
# WebKitWebProcess 空白窗口问题的修复（EGL vendor）：
#   WebKit 的渲染进程（WebKitWebProcess）启动时要创建默认 EGL display（WebCore::
#   PlatformDisplayDefault::create），失败即 abort（journal 里能看到 "Could not create
#   default EGL display: EGL_BAD_PARAMETER. Aborting..."），主窗口空白。
#   根因是 nix 版 libEGL（libglvnd）的 EGL vendor 加载链在 Fedora 宿主上断掉：
#     - glvnd 的 vendor 搜索路径（libEGL.so.1 内编译期字符串）为
#       __EGL_VENDOR_LIBRARY_DIRS -> /run/opengl-driver/share/glvnd/egl_vendor.d ->
#       /etc/glvnd/egl_vendor.d -> /usr/share/glvnd/egl_vendor.d；
#     - 宿主 /etc/glvnd/egl_vendor.d 为空，/usr/share/glvnd/egl_vendor.d 有 Fedora 的
#       50_mesa.json/10_nvidia.json，但其 library_path 是相对名（libEGL_mesa.so.0），
#       nix 加载器不读宿主 ld.so.cache 也不搜 /usr/lib64 -> dlopen 失败 -> 无可用 vendor
#       -> eglGetDisplay(EGL_DEFAULT_DISPLAY) 返回 EGL_BAD_PARAMETER；
#   修复：把 mesa 拉进 closure，用 __EGL_VENDOR_LIBRARY_DIRS 指向 mesa store 路径的
#   egl_vendor.d（其 50_mesa.json 的 libEGL_mesa.so.0 由 wrapper 的 LD_LIBRARY_PATH 提供），
#   DRI 驱动（iris/swrast）走 mesa 自身编译期路径，无需额外设置。
#   （注意：GLVND_EGL_CONFIGURATION_PATH 不是 glvnd 认的变量，勿用。）
{
  lib,
  stdenv,
  autoPatchelfHook,
  wrapGAppsHook3,
  fetchurl,
  dpkg,
  webkitgtk_4_1,
  gtk3,
  glib,
  gdk-pixbuf,
  cairo,
  pango,
  libsoup_3,
  openssl,
  xz,
  gcc-unwrapped,
  libayatana-appindicator,
  mesa,
  libglvnd,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "cc-switch";
  version = "3.19.1";
  src = fetchurl {
    url = "https://github.com/farion1231/cc-switch/releases/download/v${finalAttrs.version}/CC-Switch-v${finalAttrs.version}-Linux-x86_64.deb";
    hash = "sha256-PVK8AQNAd843oSbH+o46fopT0XjpLY89wE8YA0TzfYc=";
  };
  # autoPatchelfHook 给 ELF 补 RPATH 找到运行时库；wrapGAppsHook3 再包一层 GTK 运行时环境
  # （GSETTINGS_SCHEMA_DIR / GDK_PIXBUF_MODULE_FILE / XDG_DATA_DIRS / fontconfig 等），
  # 否则 GTK/webkit 应用找不到 schemas、图标、字体，起来即崩。
  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    wrapGAppsHook3
  ];
  buildInputs = [
    webkitgtk_4_1
    gtk3
    glib
    gdk-pixbuf
    cairo
    pango
    libsoup_3
    openssl
    xz
    gcc-unwrapped
    mesa
    libglvnd
  ];

  # libappindicator-sys（Tauri 托盘图标）运行时 dlopen libayatana-appindicator3.so.1，
  # 不在 DT_NEEDED 里 -> autoPatchelf 抓不到；且 dlopen 不查 RUNPATH（buildInputs 进的是
  # RUNPATH），故必须由 wrapGAppsHook3 的 wrapper 用 LD_LIBRARY_PATH 提供。
  # mesa 进 LD_LIBRARY_PATH 同理：glvnd 按 50_mesa.json 里的相对名 dlopen libEGL_mesa.so.0。
  # __EGL_VENDOR_LIBRARY_DIRS 指向 mesa 的 vendor json，见文件头注释。
  # 注意：wrapGAppsHook3 的 setup-hook 不读 makeWrapperArgs，只读 gappsWrapperArgs 数组，
  # 故在 preFixup 里追加到 gappsWrapperArgs（preFixup 先于 wrapGApps 的 wrapProgram 执行）。
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libayatana-appindicator
          mesa
        ]
      }
      --set __EGL_VENDOR_LIBRARY_DIRS ${mesa}/share/glvnd/egl_vendor.d
    )
  '';

  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/applications $out/share/icons
    dpkg -x $src deb
    cp deb/usr/bin/cc-switch $out/bin/
    cp "deb/usr/share/applications/CC Switch.desktop" $out/share/applications/
    cp -r deb/usr/share/icons/hicolor $out/share/icons/
    runHook postInstall
  '';
  meta = {
    description = "Cross-platform desktop All-in-One assistant for Claude Code, Codex, OpenCode, etc.";
    homepage = "https://github.com/farion1231/cc-switch";
    license = lib.licenses.mit;
    mainProgram = "cc-switch";
    platforms = [ "x86_64-linux" ];
  };
})
