#
# Auto-Build Script: 小游戏 APK 自动打包
# 每次打包自动递增该游戏的版本号，产出可直接覆盖安装的更新包
# 版本号按游戏（包名）独立计数，互不影响
# 游戏根目录会自动探测，也可用 -GamesRoot 显式指定
#
# 使用方法: 双击 build_apks.bat 按提示选择游戏，或执行：
#   powershell -ExecutionPolicy Bypass -File build_apks.ps1             交互选择
#   powershell -ExecutionPolicy Bypass -File build_apks.ps1 -GameName all            全部游戏
#   powershell -ExecutionPolicy Bypass -File build_apks.ps1 -GameName RailOps2026    指定单个游戏
#

[CmdletBinding()]
param(
    [string]$GamesRoot = "",
    [string]$OutputDir = "",
    [string]$GameName = "",
    [string]$JavaHome = "",
    [string]$AndroidSdk = "",
    [string]$IconSource = ""
)

$ErrorActionPreference = "Continue"
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) { $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

# ============================================================
# 0. 配置游戏列表
# ============================================================
$Games = @(
    @{
        Name    = "Anniversary2025"
        Dir     = "Anniversary2025"
        Html    = "Anniversary2025.html"
        PkgName = "com.ba.anniv2025"
        AppName = "Anniversary 2025"
        Orient  = "landscape"
    },
    @{
        Name    = "RailOps2026"
        Dir     = "RailOps2026"
        Html    = "RailOps2026.html"
        PkgName = "com.ba.railops2026"
        AppName = "Rail Ops 2026"
        Orient  = "landscape"
    },
    @{
        Name    = "RhythmGame2026"
        Dir     = "RhythmGame2026"
        Html    = "RhythmGame2026.html"
        PkgName = "com.ba.rhythm2026"
        AppName = "Rhythm Game 2026"
        Orient  = "landscape"
    },
    @{
        Name    = "MidAutumn2026"
        Dir     = "MidAutumn2026"
        Html    = "MidAutumn2026.html"
        PkgName = "com.ba.midautumn2026"
        AppName = "Mid Autumn 2026"
        Orient  = "landscape"
    }
)

# ============================================================
# 0.1 定位游戏根目录 / 输出目录
#     （根目录被改名或搬家后依然能找到，避免打包被整体跳过）
# ============================================================
function Resolve-GamesRoot {
    param([string]$Hint, [string]$Root)
    $candidates = @()
    if ($Hint) { $candidates += $Hint }
    $candidates += "E:\bluearchive-web-games"
    $candidates += "E:\bluearchive-little-games"
    $candidates += (Split-Path $Root -Parent)
    $candidates += $Root
    foreach ($c in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        if (-not (Test-Path $c)) { continue }
        foreach ($g in $Games) {
            if (Test-Path (Join-Path $c $g.Dir)) { return $c }
        }
    }
    return ""
}

$GamesRoot = Resolve-GamesRoot -Hint $GamesRoot -Root $ScriptRoot
if (-not $GamesRoot) {
    Write-Host "[错误] 未找到游戏根目录（应包含 $($Games[0].Dir) 等子目录）"
    Write-Host "       请用 -GamesRoot 参数指定，例如："
    Write-Host "       powershell -File build_apks.ps1 -GamesRoot `"E:\bluearchive-web-games`""
    exit 1
}
if (-not $OutputDir) { $OutputDir = Join-Path $GamesRoot "apk_output" }

# ============================================================
# 0.2 版本号记录
#     key 为包名，每个游戏的 versionCode 独立计数、互不影响
# ============================================================
$VersionFile = Join-Path $ScriptRoot "apk_versions.json"
$versions = @{}
if (Test-Path $VersionFile) {
    try {
        $saved = Get-Content $VersionFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $saved.PSObject.Properties) { $versions[$p.Name] = [int]$p.Value }
    } catch {
        Write-Host "[警告] 版本记录读取失败，将从 1 重新开始"
    }
}

function Get-CurrentVersion {
    param([string]$PkgName)
    if ($versions.ContainsKey($PkgName)) { return [int]$versions[$PkgName] }
    return 0
}

# versionCode=1 时 versionName 为 1.0，之后 1.1 / 1.2 ...
function Get-VersionName {
    param([int]$VersionCode)
    return "1." + ($VersionCode - 1)
}

# ============================================================
# 0.3 选择要重新打包的游戏（未指定时交互选择）
# ============================================================
$AllGames = $Games

function Select-Game {
    param([string]$Choice)

    if (-not $Choice) {
        Write-Host ""
        Write-Host "  请选择要重新打包的游戏:"
        Write-Host "    0. 全部游戏"
        for ($i = 0; $i -lt $AllGames.Count; $i++) {
            $g = $AllGames[$i]
            $cur = Get-CurrentVersion $g.PkgName
            $curText = if ($cur -gt 0) { "当前 " + (Get-VersionName $cur) } else { "尚未打包" }
            Write-Host ("    {0}. {1}   ({2})" -f ($i + 1), $g.Name, $curText)
        }
        Write-Host ""
        $Choice = Read-Host "  输入序号或名称（直接回车 = 全部）"
    }

    $Choice = "$Choice".Trim()
    if (-not $Choice -or $Choice -eq "0" -or $Choice -eq "all") { return $AllGames }

    $idx = 0
    if ([int]::TryParse($Choice, [ref]$idx)) {
        if ($idx -ge 1 -and $idx -le $AllGames.Count) { return @($AllGames[$idx - 1]) }
        Write-Host "[错误] 序号超出范围: $Choice"
        exit 1
    }

    $matched = @($AllGames | Where-Object { $_.Name -like "*$Choice*" })
    if ($matched.Count -eq 0) {
        Write-Host "[错误] 未找到匹配的游戏: $Choice"
        Write-Host "       可选: $(($AllGames | ForEach-Object { $_.Name }) -join ', ')"
        exit 1
    }
    return $matched
}

$Games = @(Select-Game -Choice $GameName)

# ============================================================
# 1. 检查并设置环境
# ============================================================
Write-Host ""
Write-Host "========================================"
Write-Host "  小游戏 APK 自动打包脚本"
Write-Host "========================================"
Write-Host "  游戏目录: $GamesRoot"
Write-Host "  输出目录: $OutputDir"
Write-Host "  打包游戏: $(($Games | ForEach-Object { $_.Name }) -join ', ')"
Write-Host ""

# --- Java ---
function Find-JavaHome {
    param([string]$Hint)
    if ($Hint -and (Test-Path "$Hint\bin\javac.exe")) { return $Hint }

    # 常见 JDK 安装路径
    $candidates = @()
    $cmd = Get-Command javac -ErrorAction SilentlyContinue
    if ($cmd) { $candidates += (Split-Path (Split-Path $cmd.Source -Parent) -Parent) }
    $candidates += "$env:JAVA_HOME"
    $candidates += "C:\Program Files\Java\latest\jdk-25"
    $candidates += "C:\Program Files\Java\jdk-25"
    $candidates += Get-ChildItem "C:\Program Files\Java" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    $candidates += Get-ChildItem "$env:ProgramFiles\Eclipse Adoptium" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    $candidates += Get-ChildItem "$env:LOCALAPPDATA\Programs\Android Studio\jbr" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    $candidates += Get-ChildItem "C:\Program Files\Android\Android Studio\jbr" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }

    foreach ($c in ($candidates | Select-Object -Unique)) {
        if ($c -and (Test-Path "$c\bin\javac.exe")) { return $c }
    }
    return ""
}
$JavaHome = Find-JavaHome -Hint $JavaHome
if (-not $JavaHome) {
    Write-Host "[错误] 未找到包含 javac 的 JDK 17+，请先安装 JDK 并配置 JAVA_HOME"
    exit 1
}
$env:JAVA_HOME = $JavaHome
$javac = Join-Path $JavaHome "bin\javac.exe"
if (-not (Test-Path $javac)) { $javac = Join-Path $JavaHome "bin\javac" }
Write-Host "[OK] JAVA_HOME = $JavaHome"

# --- Android SDK ---
if (-not $AndroidSdk) {
    $AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk"
}
if (-not (Test-Path $AndroidSdk)) {
    Write-Host "[错误] 未找到 Android SDK"
    Write-Host "       下载: https://developer.android.com/studio"
    exit 1
}
$env:ANDROID_HOME = $AndroidSdk
Write-Host "[OK] ANDROID_HOME = $AndroidSdk"

# --- 查找 build-tools ---
$buildToolsDir = Join-Path $AndroidSdk "build-tools"
if (-not (Test-Path $buildToolsDir)) {
    Write-Host "[错误] 未找到 build-tools"
    exit 1
}
$btVersion = (Get-ChildItem $buildToolsDir -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name
$BT = Join-Path $buildToolsDir $btVersion
Write-Host "[OK] Build-Tools = $BT"

# --- 查找 android.jar ---
$platformsDir = Join-Path $AndroidSdk "platforms"
$androidJar = $null
if (Test-Path $platformsDir) {
    $platformVer = (Get-ChildItem $platformsDir -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name
    $androidJar = Join-Path $platformsDir "$platformVer\android.jar"
}
if (-not $androidJar -or -not (Test-Path $androidJar)) {
    Write-Host "[错误] 未找到 android.jar"
    exit 1
}
Write-Host "[OK] android.jar = $androidJar"

# --- 工具路径 ---
$aapt2      = Join-Path $BT "aapt2.exe"
$d8         = Join-Path $BT "d8.bat"
$zipalign   = Join-Path $BT "zipalign.exe"
$apksigner  = Join-Path $BT "apksigner.bat"

if (-not (Test-Path $aapt2)) { Write-Host "[错误] 未找到 aapt2"; exit 1 }
if (-not (Test-Path $d8)) { Write-Host "[错误] 未找到 d8"; exit 1 }
if (-not (Test-Path $apksigner)) { Write-Host "[错误] 未找到 apksigner"; exit 1 }

# ============================================================
# 2. 密钥库
#    固定存放在脚本目录下，不随输出目录一起被清理。
#    签名必须前后一致，手机端才能直接覆盖安装（更新），
#    否则会报 INSTALL_FAILED_UPDATE_INCOMPATIBLE，只能先卸载。
# ============================================================
$KeyStoreDir = Join-Path $ScriptRoot "keystore"
$KeyStore = Join-Path $KeyStoreDir "debug.keystore"

# 兼容旧版本：原密钥库放在输出目录，首次运行时迁移过来以保持签名不变
$LegacyKeyStore = Join-Path $OutputDir "debug.keystore"
if (-not (Test-Path $KeyStore) -and (Test-Path $LegacyKeyStore)) {
    New-Item -ItemType Directory -Path $KeyStoreDir -Force | Out-Null
    Copy-Item $LegacyKeyStore $KeyStore -Force
    Write-Host "[OK] 已沿用原有密钥库: $LegacyKeyStore"
}

if (-not (Test-Path $KeyStore)) {
    Write-Host ""
    Write-Host "[信息] 创建调试密钥库..."
    New-Item -ItemType Directory -Path $KeyStoreDir -Force | Out-Null
    $keytool = Join-Path $JavaHome "bin\keytool.exe"
    if (-not (Test-Path $keytool)) { $keytool = Join-Path $JavaHome "bin\keytool" }
    & $keytool -genkey -v -keystore $KeyStore -storepass android -keypass android -keyalg RSA -keysize 2048 -validity 10000 -alias androiddebugkey -dname "CN=Debug, OU=Debug, O=Debug, L=Debug, ST=Debug, C=US" 2>&1 | Out-Null
    Write-Host "[OK] 密钥库已创建: $KeyStore"
}

# ============================================================
# 3. 图标生成：将 favicon.ico 转为各密度 PNG 图标
# ============================================================
function Convert-IconToMipmaps {
    param(
        [string]$IcoPath,
        [string]$ResRoot
    )
    if (-not (Test-Path $IcoPath)) { return $false }

    Add-Type -AssemblyName System.Drawing
    $densities = @(
        @{ Folder = "mipmap-mdpi";    Size = 48  },
        @{ Folder = "mipmap-hdpi";    Size = 72  },
        @{ Folder = "mipmap-xhdpi";   Size = 96  },
        @{ Folder = "mipmap-xxhdpi";  Size = 144 },
        @{ Folder = "mipmap-xxxhdpi"; Size = 192 }
    )

    try {
        # 加载 ICO 中最大可用帧（favicon 通常含多尺寸帧）
        $icon = New-Object System.Drawing.Icon($IcoPath, 256, 256)
        $src = $icon.ToBitmap()

        foreach ($d in $densities) {
            $dir = Join-Path $ResRoot $d.Folder
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $png = New-Object System.Drawing.Bitmap($d.Size, $d.Size)
            $g2 = [System.Drawing.Graphics]::FromImage($png)
            $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g2.Clear([System.Drawing.Color]::Transparent)
            $g2.DrawImage($src, 0, 0, $d.Size, $d.Size)
            $g2.Dispose()
            $out = Join-Path $dir "ic_launcher.png"
            $png.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
            $png.Dispose()
        }
        $src.Dispose()
        $icon.Dispose()
        return $true
    } catch {
        Write-Host "       [警告] 图标转换失败: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================
# 4. 为每个游戏构建 APK
# ============================================================
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$builtCount = 0

foreach ($Game in $Games) {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  打包游戏: $($Game.Name)"
    Write-Host "========================================"

    $gameDir = Join-Path $GamesRoot $Game.Dir
    if (-not (Test-Path $gameDir)) {
        Write-Host "[跳过] 游戏目录不存在: $gameDir"
        continue
    }

    # 查找 HTML 文件
    $htmlFile = $null
    $htmlCandidates = @(
        (Join-Path $gameDir "game\$($Game.Html)"),
        (Join-Path $gameDir $Game.Html),
        (Join-Path $gameDir "index.html")
    )
    foreach ($cand in $htmlCandidates) {
        if (Test-Path $cand) { $htmlFile = $cand; break }
    }
    if (-not $htmlFile) {
        Write-Host "[跳过] 未找到 HTML 文件"
        continue
    }
    Write-Host "[OK] 游戏目录: $gameDir"
    Write-Host "[OK] 主页面: $htmlFile"

    # --- 构建目录 ---
    $buildDir = Join-Path $OutputDir "build\$($Game.Name)"
    $assetsDir = Join-Path $buildDir "assets"
    $srcDir    = Join-Path $buildDir "src"
    $resRoot   = Join-Path $buildDir "res"
    $resDir    = Join-Path $resRoot "values"

    Remove-Item $buildDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
    New-Item -ItemType Directory -Path $resDir -Force | Out-Null

    # --- 生成应用图标（优先使用根目录 favicon.ico，否则用游戏目录内的） ---
    $iconSource = $IconSource
    if (-not $iconSource) {
        $iconSource = Join-Path $GamesRoot "favicon.ico"
        if (-not (Test-Path $iconSource)) { $iconSource = Join-Path $gameDir "favicon.ico" }
    }
    if (Test-Path $iconSource) {
        Write-Host "[步骤] 生成应用图标 (来自 $iconSource)..."
        if (Convert-IconToMipmaps -IcoPath $iconSource -ResRoot $resRoot) {
            Write-Host "       图标生成成功 (mdpi 48x48 ~ xxxhdpi 192x192)"
        } else {
            Write-Host "       使用系统默认图标"
        }
    }

    # --- 复制游戏资源 ---
    Write-Host "[步骤] 复制游戏资源..."
    $gameRoot = Split-Path $htmlFile -Parent
    Copy-Item "$gameRoot\*" $assetsDir -Recurse -Force
    $htmlName = Split-Path $htmlFile -Leaf
    if ($htmlName -ne "index.html") {
        Copy-Item (Join-Path $assetsDir $htmlName) (Join-Path $assetsDir "index.html") -Force -ErrorAction SilentlyContinue
    }
    $fileCount = (Get-ChildItem $assetsDir -Recurse).Count
    Write-Host "       已复制 $fileCount 个文件"

    # --- 版本号：每次打包自动 +1，作为可覆盖安装的新版本 ---
    $prevVc = 0
    if ($versions.ContainsKey($Game.PkgName)) { $prevVc = [int]$versions[$Game.PkgName] }
    $vc = $prevVc + 1
    if ($vc -lt 1) { $vc = 1 }
    # versionCode=1 时 versionName 为 1.0（重置基线），之后 1.1 / 1.2 ...
    $vn = Get-VersionName $vc

    # --- AndroidManifest.xml ---
    Write-Host "[步骤] 生成 AndroidManifest.xml..."
    $manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$($Game.PkgName)"
    android:versionCode="$vc"
    android:versionName="$vn">

    <uses-sdk android:minSdkVersion="21" android:targetSdkVersion="35" />

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application
        android:label="$($Game.AppName)"
        android:icon="@mipmap/ic_launcher"
        android:theme="@android:style/Theme.NoTitleBar.Fullscreen"
        android:hardwareAccelerated="true"
        android:usesCleartextTraffic="true"
        android:allowBackup="true">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:screenOrientation="$($Game.Orient)">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
"@
    $manifestPath = Join-Path $buildDir "AndroidManifest.xml"
    # 使用无 BOM 的 ASCII 写入，避免 javac/aapt2 解析失败
    [System.IO.File]::WriteAllText($manifestPath, $manifest, [System.Text.Encoding]::ASCII)

    # --- strings.xml ---
    $stringsXml = @"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$($Game.AppName)</string>
</resources>
"@
    [System.IO.File]::WriteAllText((Join-Path $resDir "strings.xml"), $stringsXml, [System.Text.Encoding]::ASCII)

    # --- MainActivity.java + AssetHttpServer.java ---
    Write-Host "[步骤] 生成 Java 代码..."
    $pkgPath = $Game.PkgName -replace '\.', '\'
    $pkgDir = Join-Path $srcDir $pkgPath
    New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null

    # 内嵌本地 HTTP 服务器：WebView 的 file:// 协议会拦截 ES 模块 / fetch / XHR，
    # 通过 http://127.0.0.1 提供游戏资源可正常加载
    $javaServerCode = @"
package $($Game.PkgName);

import android.content.Context;
import java.io.ByteArrayOutputStream;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URLDecoder;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class AssetHttpServer {
    private final Context context;
    private ServerSocket serverSocket;
    private ExecutorService pool;
    private final int port;

    private static final Map<String, String> MIME = new HashMap<>();
    static {
        MIME.put("html", "text/html; charset=utf-8");
        MIME.put("htm", "text/html; charset=utf-8");
        MIME.put("js", "application/javascript");
        MIME.put("mjs", "application/javascript");
        MIME.put("css", "text/css");
        MIME.put("json", "application/json");
        MIME.put("png", "image/png");
        MIME.put("jpg", "image/jpeg");
        MIME.put("jpeg", "image/jpeg");
        MIME.put("gif", "image/gif");
        MIME.put("webp", "image/webp");
        MIME.put("svg", "image/svg+xml");
        MIME.put("ico", "image/x-icon");
        MIME.put("bmp", "image/bmp");
        MIME.put("mp3", "audio/mpeg");
        MIME.put("wav", "audio/wav");
        MIME.put("ogg", "audio/ogg");
        MIME.put("oga", "audio/ogg");
        MIME.put("mp4", "video/mp4");
        MIME.put("webm", "video/webm");
        MIME.put("woff", "font/woff");
        MIME.put("woff2", "font/woff2");
        MIME.put("ttf", "font/ttf");
        MIME.put("otf", "font/otf");
        MIME.put("txt", "text/plain");
        MIME.put("xml", "text/xml");
        MIME.put("wasm", "application/wasm");
        MIME.put("map", "application/json");
        MIME.put("zip", "application/zip");
        MIME.put("bin", "application/octet-stream");
        MIME.put("dat", "application/octet-stream");
    }

    public AssetHttpServer(Context context) throws IOException {
        this.context = context;
        this.serverSocket = new ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"));
        this.port = serverSocket.getLocalPort();
        this.pool = Executors.newCachedThreadPool();
    }

    public String getBaseUrl() {
        return "http://127.0.0.1:" + port;
    }

    public void start() {
        Thread t = new Thread(new Runnable() {
            @Override public void run() {
                acceptLoop();
            }
        });
        t.setDaemon(true);
        t.setName("AssetHttpServer");
        t.start();
    }

    private void acceptLoop() {
        while (!serverSocket.isClosed()) {
            try {
                final Socket s = serverSocket.accept();
                pool.execute(new Runnable() {
                    @Override public void run() { handle(s); }
                });
            } catch (IOException e) {
                break;
            }
        }
    }

    private void handle(Socket socket) {
        try {
            socket.setSoTimeout(10000);
            BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream(), "ISO-8859-1"));
            String requestLine = in.readLine();
            if (requestLine == null) { socket.close(); return; }
            String[] parts = requestLine.split(" ");
            if (parts.length < 2 || !"GET".equalsIgnoreCase(parts[0])) {
                socket.close();
                return;
            }
            String path = parts[1];
            int q = path.indexOf('?');
            if (q >= 0) path = path.substring(0, q);
            if (path.equals("/") || path.isEmpty()) path = "/index.html";
            path = URLDecoder.decode(path, "UTF-8");
            if (path.contains("..")) { send404(socket); return; }
            String assetPath = path.startsWith("/") ? path.substring(1) : path;

            InputStream is;
            try {
                is = context.getAssets().open(assetPath);
            } catch (IOException e) {
                send404(socket);
                return;
            }

            String ext = "";
            int dot = assetPath.lastIndexOf('.');
            if (dot >= 0) ext = assetPath.substring(dot + 1).toLowerCase();
            String mime = MIME.get(ext);
            if (mime == null) mime = "application/octet-stream";

            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = is.read(buf)) != -1) bos.write(buf, 0, n);
            is.close();
            byte[] data = bos.toByteArray();

            OutputStream out = socket.getOutputStream();
            StringBuilder head = new StringBuilder();
            head.append("HTTP/1.1 200 OK\r\n");
            head.append("Content-Type: ").append(mime).append("\r\n");
            head.append("Content-Length: ").append(data.length).append("\r\n");
            head.append("Access-Control-Allow-Origin: *\r\n");
            head.append("Cache-Control: no-store\r\n");
            head.append("Connection: close\r\n\r\n");
            out.write(head.toString().getBytes("ISO-8859-1"));
            out.write(data);
            out.flush();
            socket.close();
        } catch (Exception e) {
            try { socket.close(); } catch (IOException ignored) {}
        }
    }

    private void send404(Socket socket) {
        try {
            String body = "404 Not Found";
            OutputStream out = socket.getOutputStream();
            StringBuilder head = new StringBuilder();
            head.append("HTTP/1.1 404 Not Found\r\n");
            head.append("Content-Type: text/plain\r\n");
            head.append("Content-Length: ").append(body.getBytes("UTF-8").length).append("\r\n");
            head.append("Connection: close\r\n\r\n");
            out.write(head.toString().getBytes("ISO-8859-1"));
            out.write(body.getBytes("UTF-8"));
            out.flush();
        } catch (IOException ignored) {
        } finally {
            try { socket.close(); } catch (IOException ignored) {}
        }
    }

    public void stop() {
        try { serverSocket.close(); } catch (IOException ignored) {}
        if (pool != null) pool.shutdownNow();
    }
}
"@
    $serverPath = Join-Path $pkgDir "AssetHttpServer.java"
    [System.IO.File]::WriteAllText($serverPath, $javaServerCode, [System.Text.Encoding]::ASCII)

    $javaCode = @"
package $($Game.PkgName);

import android.app.Activity;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class MainActivity extends Activity {
    private WebView webView;
    private AssetHttpServer httpServer;

    /**
     * Exposed to the game pages as window.BaExit.
     * The games call window.BaExit.exit() when the close button is tapped
     * inside the APK, so the app really quits instead of reloading the
     * bundled page (../../index.html resolves to the game itself here).
     */
    public static class ExitBridge {
        private final MainActivity activity;
        ExitBridge(MainActivity activity) { this.activity = activity; }

        @JavascriptInterface
        public void exit() {
            activity.runOnUiThread(new Runnable() {
                @Override public void run() { activity.exitApp(); }
            });
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        );
        webView = new WebView(this);
        setContentView(webView);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setBuiltInZoomControls(false);
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(true);
        settings.setSupportZoom(false);
        settings.setDisplayZoomControls(false);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        webView.setWebChromeClient(new WebChromeClient());
        webView.setWebViewClient(new WebViewClient());
        // window.BaExit.exit() -> quit the app (see ExitBridge)
        webView.addJavascriptInterface(new ExitBridge(this), "BaExit");

        // 用本地 HTTP 服务加载，避免 file:// 下 ES 模块 / fetch 被拦截
        try {
            httpServer = new AssetHttpServer(this);
            httpServer.start();
            webView.loadUrl(httpServer.getBaseUrl() + "/index.html");
        } catch (Exception e) {
            webView.loadUrl("file:///android_asset/index.html");
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK && webView.canGoBack()) {
            webView.goBack();
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    /** Stop the local asset server and quit the app for real. */
    private void exitApp() {
        try {
            if (httpServer != null) { httpServer.stop(); httpServer = null; }
        } catch (Exception ignored) {}
        finish();
        System.exit(0);
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (webView != null) { webView.onResume(); webView.resumeTimers(); }
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (webView != null) { webView.onPause(); webView.pauseTimers(); }
    }

    @Override
    protected void onDestroy() {
        if (httpServer != null) {
            httpServer.stop();
            httpServer = null;
        }
        if (webView != null) {
            webView.stopLoading();
            webView.removeAllViews();
            webView.destroy();
            webView = null;
        }
        super.onDestroy();
    }
}
"@
    $javaPath = Join-Path $pkgDir "MainActivity.java"
    [System.IO.File]::WriteAllText($javaPath, $javaCode, [System.Text.Encoding]::ASCII)

    # --- 编译 Java ---
    Write-Host "[步骤] 编译 Java 代码..."
    $classesDir = Join-Path $buildDir "classes"
    New-Item -ItemType Directory -Path $classesDir -Force | Out-Null

    # JDK 9+ 不支持 -bootclasspath；使用 --release 8 控制目标 class 版本（d8 兼容），
    # android.jar 放在 classpath 上供 android.* API 解析
    $javaFiles = @($javaPath, $serverPath)
    $javacArgs = @(
        "-encoding", "UTF-8",
        "--release", "8",
        "-classpath", $androidJar,
        "-d", $classesDir
    ) + $javaFiles
    $compileOutput = & $javac $javacArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        # 回退: 部分旧 JDK 不支持 --release
        $javacArgs2 = @(
            "-encoding", "UTF-8",
            "-classpath", $androidJar,
            "-d", $classesDir
        ) + $javaFiles
        $compileOutput = & $javac $javacArgs2 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] Java 编译失败:"
        Write-Host ($compileOutput | Select-Object -First 10)
        continue
    }
    Write-Host "       编译成功"

    # --- DEX 转换 ---
    Write-Host "[步骤] 转换为 DEX..."
    $classFiles = Get-ChildItem $classesDir -Recurse -Filter "*.class" | ForEach-Object { $_.FullName }
    & $d8 --output $buildDir $classFiles 2>&1 | Out-Null
    if (-not (Test-Path (Join-Path $buildDir "classes.dex"))) {
        Write-Host "[错误] DEX 转换失败"
        continue
    }
    Write-Host "       DEX 转换成功"

    # --- 打包 APK ---
    Write-Host "[步骤] 打包 APK..."
    $unsignedApk = Join-Path $buildDir "unsigned.apk"

    # 1) 编译资源
    $compiledRes = Join-Path $buildDir "compiled.res.zip"
    & $aapt2 compile --dir $resRoot -o $compiledRes 2>&1 | Out-Null

    # 2) 链接生成基础 APK
    & $aapt2 link -o $unsignedApk --manifest $manifestPath -I $androidJar $compiledRes 2>&1 | Out-Null
    if (-not (Test-Path $unsignedApk)) {
        Write-Host "[错误] APK 链接失败"
        continue
    }

    # 3) 使用 .NET Zip API 添加 classes.dex 和 assets 到 APK
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression
    $apkZip = [System.IO.Compression.ZipFile]::Open($unsignedApk, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        # 删除已存在的 assets 条目
        $existingEntries = $apkZip.Entries | Where-Object { $_.FullName.StartsWith("assets/") -or $_.FullName.StartsWith("assets\") }
        foreach ($entry in $existingEntries) { $entry.Delete() }

        # 添加 classes.dex
        $dexPath = Join-Path $buildDir "classes.dex"
        if (Test-Path $dexPath) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($apkZip, $dexPath, "classes.dex") | Out-Null
        }

        # 添加 assets 下所有文件
        Get-ChildItem $assetsDir -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Substring($assetsDir.Length + 1).Replace('\', '/')
            $zipEntryName = "assets/" + $relativePath
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($apkZip, $_.FullName, $zipEntryName) | Out-Null
        }
    } finally {
        $apkZip.Dispose()
    }

    if (-not (Test-Path $unsignedApk)) {
        Write-Host "[错误] APK 打包失败"
        continue
    }
    Write-Host "       APK 打包成功"

    # --- zipalign ---
    Write-Host "[步骤] 对齐 APK..."
    $alignedApk = Join-Path $buildDir "aligned.apk"
    if (Test-Path $zipalign) {
        & $zipalign -f 4 $unsignedApk $alignedApk 2>&1 | Out-Null
        if (-not (Test-Path $alignedApk)) {
            Copy-Item $unsignedApk $alignedApk
        }
    } else {
        Copy-Item $unsignedApk $alignedApk
    }

    # --- 签名 ---
    Write-Host "[步骤] 签名 APK..."
    $finalApk = Join-Path $OutputDir "$($Game.Name).apk"
    # 先删掉旧包，避免签名失败时把残留的旧文件误判为本次成功
    Remove-Item $finalApk -Force -ErrorAction SilentlyContinue
    Remove-Item "$finalApk.idsig" -Force -ErrorAction SilentlyContinue
    & $apksigner sign --ks $KeyStore --ks-pass pass:android --key-pass pass:android --out $finalApk $alignedApk 2>&1 | Out-Null

    if (-not (Test-Path $finalApk)) {
        Write-Host "[错误] APK 签名失败"
        continue
    }

    $apkSize = [math]::Round((Get-Item $finalApk).Length / 1MB, 2)
    $builtCount++
    $versions[$Game.PkgName] = $vc
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  [成功] $($Game.Name)"
    Write-Host "  APK: $finalApk"
    Write-Host "  大小: $apkSize MB"
    Write-Host "  版本: $vn (versionCode $vc)"
    Write-Host "========================================"
}

# ============================================================
# 5. 保存版本号并汇总
# ============================================================
if ($versions.Count -gt 0) {
    $versions | ConvertTo-Json | Set-Content -Path $VersionFile -Encoding UTF8
}

Write-Host ""
Write-Host "========================================"
Write-Host "  完成: 成功 $builtCount / $($Games.Count)"
Write-Host "  APK 输出目录: $OutputDir"
Write-Host "  签名密钥库: $KeyStore"
Write-Host "========================================"
Write-Host ""
Write-Host "  各游戏版本（独立计数）:"
foreach ($g in $AllGames) {
    $cur = Get-CurrentVersion $g.PkgName
    if ($cur -gt 0) {
        Write-Host ("    {0,-18} {1}   versionCode {2}" -f $g.Name, (Get-VersionName $cur), $cur)
    } else {
        Write-Host ("    {0,-18} 尚未打包" -f $g.Name)
    }
}
Write-Host ""
Write-Host "  更新安装方法:"
Write-Host "  1. 直接把新 APK 装到手机上即可覆盖旧版本（签名一致，App 数据保留）"
Write-Host "  2. 若提示签名冲突，说明旧包由其它密钥签名，需先卸载旧版"
Write-Host "========================================"
Write-Host ""

Get-ChildItem $OutputDir -Filter "*.apk" | ForEach-Object {
    $size = [math]::Round($_.Length / 1MB, 2)
    Write-Host "  $($_.Name) - $size MB"
}

if ($builtCount -lt $Games.Count) {
    Write-Host ""
    Write-Host "[警告] 有 $($Games.Count - $builtCount) 个游戏未成功打包，请查看上方错误信息"
    exit 1
}
exit 0
