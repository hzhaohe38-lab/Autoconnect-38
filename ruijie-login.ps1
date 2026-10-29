#requires -Version 5.1
<#
  Ruijie Auto Login - PowerShell 版
  直接在有线/无线网络下运行，不依赖 WSL 或 Git Bash。

  用法:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\ruijie-login.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File .\ruijie-login.ps1 -Once
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string[]]$DetectUrl,
    [int]$RetryInterval = 10,
    [switch]$Once
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 does not load System.Net.Http by default
Add-Type -AssemblyName System.Net.Http

# ---------- 定位配置文件 ----------
$Root = $PSScriptRoot
if (-not $ConfigPath) {
    $c1 = Join-Path $Root 'ruijie.conf'
    $c2 = Join-Path $Root 'shell\ruijie.conf'
    if (Test-Path $c1) {
        $ConfigPath = $c1
    } elseif (Test-Path $c2) {
        $ConfigPath = $c2
    } else {
        # 首次运行：稍后用模板在 shell 目录创建
        $ConfigPath = $c2
    }
}
$ConfigPath = [IO.Path]::GetFullPath($ConfigPath)
$ConfigDir = Split-Path $ConfigPath -Parent
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

$examplePath = $null
foreach ($candidate in @(
    (Join-Path $ConfigDir 'ruijie.conf.example'),
    (Join-Path $Root 'shell\ruijie.conf.example')
)) {
    if (Test-Path $candidate) { $examplePath = $candidate; break }
}
if (-not (Test-Path $ConfigPath) -and -not $examplePath) {
    Write-Host '找不到 ruijie.conf，也没有 ruijie.conf.example 模板。' -ForegroundColor Red
    exit 1
}

# ---------- 读取配置 ----------
$cfg = @{}
if (Test-Path $ConfigPath) {
    Get-Content -Path $ConfigPath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        $i = $line.IndexOf('=')
        if ($i -lt 1) { return }
        $key = $line.Substring(0, $i).Trim()
        $val = $line.Substring($i + 1).Trim()
        if ($val.Length -ge 2) {
            $first = $val.Substring(0, 1)
            $last = $val.Substring($val.Length - 1, 1)
            if ($first -eq "'" -and $last -eq "'") {
                $val = $val.Substring(1, $val.Length - 2).Replace("'\''", "'")
            } elseif ($first -eq '"' -and $last -eq '"') {
                $val = $val.Substring(1, $val.Length - 2)
            }
        }
        $cfg[$key] = $val
    }
}

$userId = $cfg['userId']
$password = $cfg['password']
$network = $cfg['network']

$serviceMap = @{
    '移动'   = '%E7%A7%BB%E5%8A%A8'
    'yd'     = '%E7%A7%BB%E5%8A%A8'
    '1'      = '%E7%A7%BB%E5%8A%A8'
    '联通'   = '%E8%81%94%E9%80%9A'
    'lt'     = '%E8%81%94%E9%80%9A'
    '2'      = '%E8%81%94%E9%80%9A'
    '电信'   = '%E7%94%B5%E4%BF%A1'
    'dx'     = '%E7%94%B5%E4%BF%A1'
    '3'      = '%E7%94%B5%E4%BF%A1'
    '校园网' = '%E6%A0%A1%E5%9B%AD%E7%BD%91'
    '教育网' = '%E6%A0%A1%E5%9B%AD%E7%BD%91'
    'edu'    = '%E6%A0%A1%E5%9B%AD%E7%BD%91'
    '0'      = '%E6%A0%A1%E5%9B%AD%E7%BD%91'
}
$serviceNameMap = @{
    '%E7%A7%BB%E5%8A%A8'         = '移动'
    '%E8%81%94%E9%80%9A'         = '联通'
    '%E7%94%B5%E4%BF%A1'         = '电信'
    '%E6%A0%A1%E5%9B%AD%E7%BD%91' = '校园网'
}
function Get-CanonicalNetwork {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $v = $Value.Trim()
    if ($serviceMap.ContainsKey($v)) {
        return $serviceNameMap[$serviceMap[$v]]
    }
    return $null
}

# ---------- 配置写入 ----------
function Set-ConfigValue {
    param([string]$Text, [string]$Key, [string]$Value)
    $escaped = $Value.Replace("'", "'\''")
    $newLine = "$Key='$escaped'"
    $pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=.*$'
    if ([regex]::IsMatch($Text, $pattern)) {
        return [regex]::Replace($Text, $pattern, $newLine.Replace('$', '$$'))
    }
    return $Text.TrimEnd("`n") + "`n" + $newLine + "`n"
}

function Save-Config {
    param([string]$Path, [string]$UserId, [string]$Password, [string]$Network)
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path $Path) {
        $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    } elseif ($examplePath -and (Test-Path $examplePath)) {
        $text = [IO.File]::ReadAllText($examplePath, [Text.Encoding]::UTF8)
    } else {
        $text = @(
            '# Ruijie auto login configuration',
            'userId=',
            'password=',
            'timeInterval=3600',
            'log_path=./ruijie.log',
            'log_save_day=7',
            'log_clear_day=0',
            "network='校园网'"
        ) -join "`n"
    }
    $text = $text -replace "`r`n", "`n"
    $text = Set-ConfigValue -Text $text -Key 'userId' -Value $UserId
    $text = Set-ConfigValue -Text $text -Key 'password' -Value $Password
    $text = Set-ConfigValue -Text $text -Key 'network' -Value $Network
    [IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------- 首次运行交互 ----------
function Read-UserId {
    param([string]$Default)
    while ($true) {
        $hint = '学号/账号'
        if ($Default) { $hint += " [$Default]" }
        $v = (Read-Host -Prompt $hint).Trim()
        if (-not $v -and $Default) { $v = $Default }
        if ($v) { return $v }
        Write-Host '账号不能为空，请重新输入。' -ForegroundColor Yellow
    }
}

function Read-Password {
    param([string]$Existing)
    while ($true) {
        $hint = '密码'
        if ($Existing) { $hint += '（直接回车保留原密码）' }
        $sec = Read-Host -Prompt $hint -AsSecureString
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        try {
            $v = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
        if (-not $v -and $Existing) { return $Existing }
        if ($v) { return $v }
        Write-Host '密码不能为空，请重新输入。' -ForegroundColor Yellow
    }
}

function Read-Operator {
    param([string]$Default)
    Write-Host ''
    Write-Host '请选择运营商:'
    Write-Host '  1) 移动'
    Write-Host '  2) 联通'
    Write-Host '  3) 电信'
    Write-Host '  0) 校园网'
    while ($true) {
        $hint = '输入序号或名称'
        if ($Default) { $hint += " [$Default]" }
        $v = (Read-Host -Prompt $hint).Trim()
        if (-not $v -and $Default) { $v = $Default }
        $canonical = Get-CanonicalNetwork $v
        if ($canonical) { return $canonical }
        Write-Host '输入无效，请输入 1/2/3/0 或 移动/联通/电信/校园网。' -ForegroundColor Yellow
    }
}

$currentNetwork = Get-CanonicalNetwork $network
$needAccount = [string]::IsNullOrWhiteSpace($userId) -or [string]::IsNullOrWhiteSpace($password)

if ($needAccount) {
    if ([Console]::IsInputRedirected) {
        Write-Host "配置文件缺少账号信息，且当前不是交互式终端。请先编辑: $ConfigPath" -ForegroundColor Red
        exit 1
    }
    Write-Host ''
    Write-Host '=========================================' -ForegroundColor Cyan
    Write-Host '        首次运行 - 填写账号信息' -ForegroundColor Cyan
    Write-Host '=========================================' -ForegroundColor Cyan
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "将创建配置文件: $ConfigPath"
    }
    $userId = Read-UserId -Default $userId
    $password = Read-Password -Existing $password
    $network = Read-Operator -Default $currentNetwork
    Save-Config -Path $ConfigPath -UserId $userId -Password $password -Network $network
    Write-Host ''
    Write-Host "配置已保存: $ConfigPath" -ForegroundColor Green
    Write-Host '以后直接运行即可，不需要再次输入。' -ForegroundColor Green
    $currentNetwork = Get-CanonicalNetwork $network
} elseif (-not $currentNetwork) {
    if ([Console]::IsInputRedirected) {
        Write-Host "配置文件中的 network 无效: $network" -ForegroundColor Red
        exit 1
    }
    $network = Read-Operator -Default '校园网'
    Save-Config -Path $ConfigPath -UserId $userId -Password $password -Network $network
    Write-Host "配置已保存: $ConfigPath" -ForegroundColor Green
    $currentNetwork = Get-CanonicalNetwork $network
}

if (-not $currentNetwork) {
    Write-Host "未知的 network 值: $network（可选：移动/联通/电信/校园网）" -ForegroundColor Red
    exit 1
}
$service = $serviceMap[$currentNetwork]
$serviceName = $serviceNameMap[$service]
$network = $currentNetwork

$interval = 3600
if ($cfg.ContainsKey('timeInterval')) {
    $tmp = 0
    if ([int]::TryParse($cfg['timeInterval'], [ref]$tmp)) { $interval = $tmp }
}
if ($interval -lt 600) { $interval = 600 }
if ($RetryInterval -lt 5) { $RetryInterval = 5 }

$logPath = 'ruijie.log'
if ($cfg.ContainsKey('log_path') -and $cfg['log_path']) { $logPath = $cfg['log_path'] }
if ([IO.Path]::IsPathRooted($logPath)) {
    $LogFile = $logPath
} else {
    $LogFile = Join-Path $ConfigDir $logPath
}
$LogFile = [IO.Path]::GetFullPath($LogFile)

$DetectUrls = @(
    'http://www.google.cn/generate_204',
    'http://connect.rom.miui.com/generate_204',
    'http://wifi.vivo.com.cn/generate_204'
)
if ($DetectUrl) { $DetectUrls = $DetectUrl }

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ---------- 日志 ----------
function Write-Log {
    param(
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level,
        [string]$Message
    )
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] [$Level] $Message"
    $color = switch ($Level) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'DarkGray' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
    try {
        [IO.File]::AppendAllText($LogFile, $line + "`r`n", $Utf8NoBom)
    } catch {
    }
}

function Get-ShortText {
    param([string]$Text, [int]$Max = 300)
    if (-not $Text) { return '' }
    $s = ($Text -replace '\s+', ' ').Trim()
    if ($s.Length -gt $Max) { return $s.Substring(0, $Max) + '...' }
    return $s
}

# ---------- 网络接口 ----------
$script:LastNetSig = ''
function Write-NetworkInfo {
    $routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object { $_.RouteMetric + $_.InterfaceMetric })

    $items = @()
    foreach ($r in $routes) {
        $addr = Get-NetIPAddress -InterfaceIndex $r.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $addr) { continue }
        if ($addr.IPAddress -like '169.254.*') { continue }
        $adapter = Get-NetAdapter -InterfaceIndex $r.InterfaceIndex -ErrorAction SilentlyContinue
        $alias = if ($adapter) { $adapter.Name } else { "接口$($r.InterfaceIndex)" }
        $items += [pscustomobject]@{
            Alias   = $alias
            IP      = $addr.IPAddress
            Gateway = $r.NextHop
            Metric  = $r.RouteMetric + $r.InterfaceMetric
        }
    }
    $items = @($items | Sort-Object Metric | Group-Object Alias | ForEach-Object { $_.Group[0] })

    $sig = ($items | ForEach-Object { "$($_.Alias)|$($_.IP)|$($_.Gateway)" }) -join ';'
    if ($sig -eq $script:LastNetSig) { return }
    $script:LastNetSig = $sig

    if ($items.Count -eq 0) {
        Write-Log WARN '没有检测到可用网络接口（无默认路由或未获取到 IP）'
        return
    }

    Write-Log INFO '当前网络接口:'
    foreach ($n in $items) {
        $type = '有线'
        if ($n.Alias -match 'WLAN|Wi-Fi|Wireless|无线') { $type = '无线' }
        Write-Log INFO ("  {0}  {1}  IP={2}  网关={3}" -f $n.Alias, $type, $n.IP, $n.Gateway)
    }

    $first = $items | Select-Object -First 1
    Write-Log INFO ("请求默认走: {0} (网关 {1})" -f $first.Alias, $first.Gateway)
}

# ---------- HTTP ----------
function New-Client {
    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $false
    $handler.UseProxy = $false
    $handler.UseCookies = $false
    $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(8)
    return $client
}

function Invoke-HttpGet {
    param([string]$Url)
    $client = New-Client
    try {
        $resp = $client.GetAsync($Url).GetAwaiter().GetResult()
        $code = [int]$resp.StatusCode
        $body = ''
        if ($resp.Content) {
            $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
        $location = $null
        if ($resp.Headers.Location) { $location = $resp.Headers.Location.ToString() }
        return [pscustomobject]@{ Code = $code; Body = $body; Location = $location }
    } finally {
        $client.Dispose()
    }
}

function Resolve-PortalUrl {
    param([string]$Raw, [string]$BaseUrl)
    $u = [System.Net.WebUtility]::HtmlDecode($Raw).Trim()
    if ($u -match '^//') { $u = 'http:' + $u }
    if ($u -notmatch '^https?://') {
        try {
            $base = New-Object System.Uri($BaseUrl)
            $u = (New-Object System.Uri($base, $u)).AbsoluteUri
        } catch {
        }
    }
    return $u
}

function Get-PortalUrl {
    param([string]$Body, [string]$Location, [string]$BaseUrl)
    if ($Location) { return (Resolve-PortalUrl -Raw $Location -BaseUrl $BaseUrl) }
    if (-not $Body) { return $null }

    $all = @()
    foreach ($m in [regex]::Matches($Body, 'https?://[^\s''"<>]+')) {
        $all += $m.Value
    }
    if ($all.Count -eq 0) { return $null }

    $portal = $all | Where-Object { $_ -match 'index\.jsp|eportal|InterFace\.do' } | Select-Object -First 1
    if (-not $portal) { $portal = $all | Select-Object -First 1 }
    return (Resolve-PortalUrl -Raw $portal -BaseUrl $BaseUrl)
}

# ---------- 联网检测 ----------
function Test-Network {
    foreach ($u in $DetectUrls) {
        try {
            $r = Invoke-HttpGet -Url $u
            if ($r.Code -eq 204) {
                return [pscustomobject]@{ Online = $true; Portal = $null; Code = 204; Source = $u }
            }
            Write-Log DEBUG ("检测 {0} -> HTTP {1}" -f $u, $r.Code)
            $portal = Get-PortalUrl -Body $r.Body -Location $r.Location -BaseUrl $u
            if ($portal) {
                return [pscustomobject]@{ Online = $false; Portal = $portal; Code = $r.Code; Source = $u }
            }
        } catch {
            Write-Log DEBUG ("检测 {0} -> 失败: {1}" -f $u, $_.Exception.Message)
        }
    }
    return [pscustomobject]@{ Online = $false; Portal = $null; Code = $null; Source = $null }
}

# ---------- 登录 ----------
function Invoke-Login {
    param([string]$PortalUrl)

    $q = ''
    $base = $PortalUrl
    $idx = $PortalUrl.IndexOf('?')
    if ($idx -ge 0) {
        $base = $PortalUrl.Substring(0, $idx)
        $q = $PortalUrl.Substring($idx + 1)
    }

    if ($base -match 'index\.jsp') {
        $loginUrl = $base -replace 'index\.jsp', 'InterFace.do?method=login'
    } else {
        $loginUrl = $base.TrimEnd('/') + '/InterFace.do?method=login'
    }

    # FormUrlEncodedContent will URL-encode the values, so the already-encoded
    # pieces must be reduced to their single-encoded form first:
    #   service     "移动"    -> %E7%A7%BB%E5%8A%A8  (same as the shell version)
    #   queryString a%3Db%26c -> a%253Db%2526c      (same as the shell version)
    $q = $q -replace '&', '%26'
    $q = $q -replace '=', '%3D'

    Write-Log INFO ("认证页: {0}" -f $PortalUrl)
    Write-Log INFO ("登录接口: {0}" -f $loginUrl)
    Write-Log INFO ("运营商: {0} ({1})" -f $serviceName, $service)

    $fields = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $fields['userId'] = $userId
    $fields['password'] = $password
    $fields['service'] = $serviceName
    $fields['queryString'] = $q
    $fields['operatorPwd'] = ''
    $fields['operatorUserId'] = ''
    $fields['validcode'] = ''
    $fields['passwordEncrypt'] = 'false'

    $content = New-Object System.Net.Http.FormUrlEncodedContent($fields)
    $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/x-www-form-urlencoded; charset=UTF-8')

    $cookie = 'EPORTAL_COOKIE_USERNAME=; EPORTAL_COOKIE_PASSWORD=; EPORTAL_COOKIE_SERVER=; EPORTAL_COOKIE_SERVER_NAME=; EPORTAL_AUTO_LAND=; EPORTAL_USER_GROUP=; EPORTAL_COOKIE_OPERATORPWD=;'

    $client = New-Client
    try {
        $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, $loginUrl)
        $req.Headers.TryAddWithoutValidation('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36') | Out-Null
        $req.Headers.TryAddWithoutValidation('Referer', $PortalUrl) | Out-Null
        $req.Headers.TryAddWithoutValidation('Cookie', $cookie) | Out-Null
        $req.Headers.TryAddWithoutValidation('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8') | Out-Null
        $req.Content = $content

        $resp = $client.SendAsync($req).GetAwaiter().GetResult()
        $code = [int]$resp.StatusCode
        $body = ''
        if ($resp.Content) {
            $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
        Write-Log INFO ("服务器返回: HTTP {0}  {1}" -f $code, (Get-ShortText -Text $body -Max 300))
    } catch {
        Write-Log ERROR ("提交登录请求失败: {0}" -f $_.Exception.Message)
        return $false
    } finally {
        $client.Dispose()
    }

    Start-Sleep -Seconds 2
    $after = Test-Network
    if ($after.Online) {
        Write-Log OK '登录成功，网络已恢复'
        return $true
    }
    Write-Log ERROR '登录请求已发送，但网络仍未恢复'
    return $false
}

# ---------- 主流程 ----------
Write-Host ''
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host '           Ruijie Auto Login' -ForegroundColor Cyan
Write-Host '=========================================' -ForegroundColor Cyan
Write-Log INFO ("配置文件: {0}" -f $ConfigPath)
Write-Log INFO ("日志文件: {0}" -f $LogFile)
Write-Log INFO ("账号: {0}    运营商: {1} ({2})" -f $userId, $serviceName, $service)
Write-Log INFO ("在线检测间隔: {0} 秒    失败重试间隔: {1} 秒" -f $interval, $RetryInterval)
Write-Log INFO ("检测地址: {0}" -f ($DetectUrls -join ', '))
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host ''

$exitCode = 0
while ($true) {
    Write-NetworkInfo
    $state = Test-Network

    if ($state.Online) {
        Write-Log OK ("已在线 (HTTP 204, 检测: {0})" -f $state.Source)
        if ($Once) { break }
        Write-Log INFO ("下次检测: {0} 秒后" -f $interval)
        Start-Sleep -Seconds $interval
        continue
    }

    if (-not $state.Portal) {
        Write-Log WARN ("没有获取到认证页地址（检测地址均不可达），{0} 秒后重试" -f $RetryInterval)
        if ($Once) { $exitCode = 1; break }
        Start-Sleep -Seconds $RetryInterval
        continue
    }

    Write-Log WARN ("未登录 (HTTP {0})，准备登录" -f $state.Code)
    $ok = Invoke-Login -PortalUrl $state.Portal
    if ($ok) { $exitCode = 0 } else { $exitCode = 1 }

    if ($Once) { break }

    if ($ok) {
        Write-Log INFO ("下次检测: {0} 秒后" -f $interval)
        Start-Sleep -Seconds $interval
    } else {
        Write-Log WARN ("{0} 秒后重试" -f $RetryInterval)
        Start-Sleep -Seconds $RetryInterval
    }
}

exit $exitCode
