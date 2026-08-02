# cc-switch 是 Tauri（Rust）桌面应用，官方只发预编译 deb/rpm/AppImage。
# 这里用 autoPatchelfHook 把官方 deb 重新打包成 nix 包：fetchurl 拉 deb -> dpkg -x 解包 ->
# autoPatchelfHook 给 ELF 二进制补 RPATH、到 nix store 找运行时库（webkit2gtk-4.1/gtk3/...）。
# 产物进 home.packages，由 home-manager 装给用户，声明式、纯用户态，无 flatpak/OSTree/daemon。
# 依赖清单来自 `readelf -d` 的 NEEDED：libwebkit2gtk-4.1/libsoup-3.0/javascriptcoregtk-4.1
# （-> webkitgtk_4_1，它同时提供 webkit2gtk-4.1 与 javascriptcoregtk-4.1，并传播 libsoup_3）、
# gtk3、glib、gdk-pixbuf、cairo、openssl、xz，以及 libgcc_s（-> gcc-unwrapped）。
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
  ];
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
