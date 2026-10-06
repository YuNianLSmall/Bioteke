# 百泰克企业社区 - 把当前公网隧道地址同步到 GitHub 固定地址
# 用法：sync.ps1 -Url "https://xxx.trycloudflare.com"   或不带参数（自动从 公网地址.txt / tunnel.log 读取）
# 依赖文件（写在同目录，都在 .gitignore 里）：
#   remote.txt  第一行 = owner/repo 或完整 https 地址；第二行 = GitHub Pages 访问地址（可选）
#   token.txt   GitHub Personal Access Token（可选，缺了就只改 index.html 不推送）

param([string]$Url)

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$parent = Split-Path -Parent $root
$remoteF = Join-Path $root 'remote.txt'
$tokenF  = Join-Path $root 'token.txt'
$lastF   = Join-Path $root '.last_url'
$index   = Join-Path $root 'index.html'

Set-Location $root
$env:GIT_TERMINAL_PROMPT = '0'
$env:GIT_SSL_NO_VERIFY   = '1'

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

Say '============================================' 'Cyan'
Say '  百泰克企业社区 - 同步到 GitHub 固定地址' 'Cyan'
Say '============================================' 'Cyan'

# ---------- 0. 定位 git ----------
# 系统 PowerShell 默认没有 git（PortableGit 只挂在 Git Bash 的 PATH 里），所以显式找一次再塞回 PATH
$gitCmd = $null
foreach ($d in @(
    'C:\Program Files\Git\bin',
    'C:\Program Files (x86)\Git\bin',
    'C:\Program Files\Git\cmd',
    'C:\Users\Administrator\.workbuddy\binaries\PortableGit\versions\1.2.0\mingw64\bin',
    'C:\Users\Administrator\.workbuddy\binaries\PortableGit\versions\1.2.0\bin',
    'C:\Users\Administrator\.workbuddy\binaries\PortableGit\versions\1.2.0\cmd'
)) { if (-not $gitCmd -and (Test-Path (Join-Path $d 'git.exe'))) { $gitCmd = Join-Path $d 'git.exe' } }

if (-not $gitCmd) {
    $g = Get-ChildItem 'C:\Users\Administrator\.workbuddy\binaries\PortableGit\versions\*\mingw64\bin\git.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $g) { $g = Get-ChildItem 'C:\Users\Administrator\.workbuddy\binaries\PortableGit\versions\*\bin\git.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($g) { $gitCmd = $g.FullName }
}

if (-not $gitCmd) {
    $c = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($c) { $gitCmd = $c.Source }
}

if (-not $gitCmd) {
    Say '[失败] 没找到 git.exe。请安装 Git，或把 git 所在目录加进 PATH。' 'Red'
    exit 2
}

$env:PATH = (Split-Path $gitCmd) + ';' + $env:PATH
$git = 'git'
try {
    $gv = (& $git --version 2>$null | Select-Object -First 1)
    if ($gv) { Say ('  git：' + $gv) 'Gray' }
} catch { }

# ---------- 1. 拿到当前隧道地址 ----------
if (-not $Url -and (Test-Path $lastF)) { $Url = (Get-Content $lastF -Raw).Trim() }
if (-not $Url) {
    $txt = Join-Path $parent '公网地址.txt'
    if (Test-Path $txt) { $Url = (Get-Content $txt -Raw).Trim() }
}
if (-not $Url) {
    $log = Join-Path $parent 'tunnel.log'
    if (Test-Path $log) {
        $m = [regex]::Match((Get-Content $log -Raw), 'https://[\w-]+\.trycloudflare\.com')
        if ($m.Success) { $Url = $m.Value }
    }
}
if (-not $Url) {
    Say '[失败] 没读到隧道地址。请带 -Url 参数调用，或先运行一次「启动公网穿透」生成地址。' 'Red'
    exit 2
}
$Url = $Url.Trim().TrimEnd('/')
Say ('  隧道地址：' + $Url) 'Green'

# ---------- 2. 仓库与凭据 ----------
if (-not (Test-Path $remoteF)) {
    Say '[失败] 缺少 remote.txt（内容示例：yourname/bioteke-tunnel）' 'Red'
    exit 2
}
$lines  = Get-Content $remoteF | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
$slug   = $lines[0]
$pages  = if ($lines.Count -ge 2) { $lines[1] } else { '' }

$token = ''
if (Test-Path $tokenF) { $token = (Get-Content $tokenF -Raw).Trim() }
if (-not $token) {
    $gh = (Get-Command gh -ErrorAction SilentlyContinue)
    if ($gh) {
        try {
            $t = (& gh auth token 2>$null | Select-Object -First 1)
            if ($t -and $t -match '^ghp_|^github_pat_|^gho_|^ghs_') { $token = $t.Trim() }
        } catch { }
    }
}

$pushUrl = $slug
if ($slug -notmatch '^https?://') {
    $pushUrl = if ($slug -match '^[\w.-]+/') { $slug } else { "github.com/$slug" }
}
if ($pushUrl -notmatch '^https?://') { $pushUrl = "https://$pushUrl" }
if ($token -and $pushUrl -match '^https://') {
    $pushUrl = $pushUrl -replace '^https://', "https://x-access-token:$token@"
}

# ---------- 3. 改 index.html ----------
$old = ''
if (Test-Path $index) {
    $m0 = [regex]::Match((Get-Content $index -Raw), 'data-target="([^"]*)"')
    if ($m0.Success) { $old = $m0.Groups[1].Value }
}

try {
    $html = Get-Content $index -Raw -Encoding UTF8
    $html = [regex]::Replace($html, 'data-target="[^"]*"', ('data-target="' + $Url + '"'))
    [System.IO.File]::WriteAllText($index, $html, (New-Object System.Text.UTF8Encoding $false))
} catch {
    Say "[失败] 写 index.html 出错：$($_.Exception.Message)" 'Red'
    exit 2
}

if ($old -eq $Url) {
    Say '  index.html 已是最新地址。'
} else {
    Say ('  index.html：' + $old + '  ->  ' + $Url) 'Green'
}

# ---------- 4. 提交并推送 ----------
try {
    & $git config user.name  'bioteke-sync'
    & $git config user.email 'sync@bioteke.local'
    & $git remote remove origin 2>$null
    & $git remote add origin $pushUrl

    & $git add index.html
    if ($LASTEXITCODE -ne 0) { throw "git add 失败" }

    # 以「暂存区有没有变化」判断要不要推，只看地址字符串会在上次提交失败时永远推不上去
    & $git diff --cached --quiet -- index.html
    if ($LASTEXITCODE -eq 0) {
        Say '  内容与仓库一致，跳过推送。'
        if ($pages) { Say ('  固定地址：' + $pages) 'Green' }
        exit 0
    }

    & $git commit -m ("auto: 更新公网地址 -> {0}" -f $Url)
    if ($LASTEXITCODE -ne 0) { throw "git commit 失败" }

    Say '  正在推送到 GitHub（可能要几秒）...' 'Gray'
    $pushed = $false
    foreach ($b in @('main', 'master')) {
        & $git push origin "HEAD:$b" --set-upstream
        if ($LASTEXITCODE -eq 0) { $pushed = $true; break }
        Say "  $b 推送失败，试下一个分支..." 'Yellow'
    }

    if (-not $pushed) {
        $r = (& $git remote show origin HEAD 2>&1 | Select-Object -First 3)
        Say ("  推送失败，远端提示：{0}" -f ($r -join ' ')) 'Yellow'
        Say '  检查：仓库是否存在、token 有没有 repo 权限、分支名。' 'Yellow'
        exit 3
    }
} catch {
    Say "[失败] $($_.Exception.Message)" 'Red'
    exit 3
}

Say '  推送完成。' 'Green'
if ($pages) {
    Say ''
    Say '  固定地址（GitHub Pages）：' 'Cyan'
    Say ('    ' + $pages) 'Green'
    Say '  Pages 首次发布或刚换分支大约需要 30~60 秒，刷新一次就好。' 'Gray'
}
Say ''
Say '  注：quick Tunnel 每次重启会换地址，所以只要重跑「启动公网穿透」，这里会自动再同步一次。' 'Gray'
