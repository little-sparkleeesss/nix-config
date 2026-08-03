# SyncClipboard：C#/.NET 8 + Avalonia 跨平台剪贴板同步工具。官方 release 发的是 self-contained
# Linux deb（自带 .NET 运行时：libcoreclr/libclrjit/...，系统无需装 dotnet）。这里用 autoPatchelfHook
# 把官方 deb 重新打包成 nix 包，思路与 pkgs/cc-switch.nix 一致，但有几个 .NET 特有的关键差异：
#
#   1. 非 GTK/webkit 应用，不用 wrapGAppsHook3。主二进制 SyncClipboard.Desktop.Default 是 .NET
#      apphost：它靠 /proc/self/exe 定位同目录的 dll。shell wrapper 会把 /proc/self/exe 变成
#      wrapper 脚本路径、找不到 dll；故改用 makeBinaryWrapper——它生成 C 二进制，设好环境变量后
#      execve 原二进制，execve 之后 /proc/self/exe 仍指向原 ELF（apphost 能正确定位 dll），且
#      wrapper 设的环境变量对运行时 dlopen 生效。
#
#   2. .NET 运行时通过 dlopen 动态加载部分系统库（openssl 等），dlopen 不走 RPATH，所以仅靠
#      autoPatchelf 补 RPATH 不够，必须由 makeBinaryWrapper 设 LD_LIBRARY_PATH 让运行时找到。
#
# 依赖清单来自对 deb 内所有 ELF 跑 `readelf -d` 汇总的 NEEDED：
#   硬依赖（DT_NEEDED，autoPatchelf 补 RPATH）：
#     libfontconfig.so.1 -> fontconfig
#     libgcc_s.so.1 -> gcc-unwrapped（与 cc-switch 一致；libstdc++.so.6 在 gcc-unwrapped.lib）
#     libstdc++.so.6 -> stdenv.cc.cc.lib
#     libX11/libXt/libXtst/libXinerama -> libx11/libxt/libxtst/libxinerama（xorg.* 已弃用）
#     libz.so.1 -> zlib
#     liblttng-ust.so.0 -> 仅 libcoreclrtraceptprovider.so（.NET EventPipe/LTTng trace provider）
#       需要。该 provider 是按需 dlopen 的可选组件，不加载也能正常运行，故用
#       autoPatchelfIgnoreMissingDeps 忽略，避免把 lttng-ust/liburcu 拖进 closure。
#   软依赖（.NET 运行时 dlopen，靠 LD_LIBRARY_PATH）：
#     libssl.so.3 -> openssl（HTTPS/S3 加密，核心功能必需）
#     libicuuc -> icu（全球化；找不到则 .NET 自动 fallback 到 invariant mode）
{
  lib,
  stdenv,
  autoPatchelfHook,
  makeBinaryWrapper,
  fetchurl,
  dpkg,
  fontconfig,
  gcc-unwrapped,
  zlib,
  openssl,
  icu,
  libx11,
  libxt,
  libxtst,
  libxinerama,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "syncclipboard";
  version = "3.1.9";
  src = fetchurl {
    url = "https://github.com/Jeric-X/SyncClipboard/releases/download/v${finalAttrs.version}/SyncClipboard_linux_x64.deb";
    # sha256 = 16785688a511258eaac263827a080975f02c04019c89fbc1ceb11a37d94a89ec
    hash = "sha256-FnhWiKURJY6qwmOCeggJdfAsBAGcifvBzrEaN9lKiew=";
  };

  # autoPatchelfHook：给所有 ELF 补 RPATH 找到硬依赖库。
  # makeBinaryWrapper：包一层设 LD_LIBRARY_PATH（.NET dlopen 软依赖），且不破坏 apphost 路径解析。
  # dpkg：解包 deb。
  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
    dpkg
  ];

  # 仅列硬依赖（DT_NEEDED）。openssl/icu 是 dlopen 软依赖，不进 buildInputs（autoPatchelf 用不到），
  # 改由下方 makeBinaryWrapper 的 LD_LIBRARY_PATH 提供。
  buildInputs = [
    fontconfig
    gcc-unwrapped
    stdenv.cc.cc.lib
    zlib
    libx11
    libxt
    libxtst
    libxinerama
  ];

  # liblttng-ust.so.0 仅 .NET 的 trace provider（libcoreclrtraceptprovider.so）按需 dlopen，
  # 非必需；忽略以免拖入 lttng-ust/liburcu 依赖链。
  autoPatchelfIgnoreMissingDeps = [ "liblttng-ust.so.0" ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib $out/share/applications $out/share/icons $out/share/metainfo

    dpkg -x $src deb
    APPDIR=deb/opt/xyz.jericx.desktop.syncclipboard

    # .NET 发布产物整体放进 $out/lib/syncclipboard（主二进制 + dll + native .so）。
    cp -r $APPDIR $out/lib/syncclipboard

    # .desktop 原始 Exec/TryExec 是 /opt 绝对路径，进 nix store 后失效，改写成 $out/bin/syncclipboard。
    # 只替换路径串本身一次即可同时覆盖 Exec= 与 TryExec= 两行：Exec= 是 TryExec= 的子串，若带前缀
    # 分两次 --replace-fail，第一次会把 TryExec 行里的子串也改掉，第二次便找不到而报错。
    # 用 --replace-fail：路径若与上游不符会立刻报错，避免静默留下死路径。
    desktop=deb/usr/share/applications/xyz.jericx.desktop.syncclipboard.desktop
    substituteInPlace $desktop \
      --replace-fail \
        "/opt/xyz.jericx.desktop.syncclipboard/SyncClipboard.Desktop.Default" \
        "$out/bin/syncclipboard"
    cp $desktop $out/share/applications/

    cp -r deb/usr/share/icons/hicolor $out/share/icons/
    cp -r deb/usr/share/metainfo/. $out/share/metainfo/

    # makeBinaryWrapper：execve 原二进制（/proc/self/exe 仍指向它，apphost 能定位同目录 dll），
    # 同时 --prefix LD_LIBRARY_PATH 让 .NET 运行时 dlopen 找到 openssl（HTTPS 加密）/icu。
    makeBinaryWrapper $out/lib/syncclipboard/SyncClipboard.Desktop.Default $out/bin/syncclipboard \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          openssl
          icu
        ]
      }"

    runHook postInstall
  '';

  meta = {
    description = "Cross-platform clipboard syncing and history management tool (desktop, self-contained)";
    homepage = "https://github.com/Jeric-X/SyncClipboard";
    license = lib.licenses.mit;
    mainProgram = "syncclipboard";
    platforms = [ "x86_64-linux" ];
  };
})
