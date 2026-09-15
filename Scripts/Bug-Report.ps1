param(
    [ValidateSet('Daily', 'Weekly', 'Monthly')]
    [string]$Period = 'Daily',
    [string]$BasePath = ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Logs\Bug-Report')))
)


[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $BasePath -PathType Container)) {
    $null = New-Item -ItemType Directory -Force -Path $BasePath
}

$ExcludeProviders = @('Schannel')
$ExcludeEventIds  = @(36882, 36888)

function Format-HtmlSafe {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    return [regex]::Replace($Text, '[&<>"\'']', {
        param($m)
        switch ($m.Value) {
            '&'  { '&amp;' }
            '<'  { '&lt;'  }
            '>'  { '&gt;'  }
            '"'  { '&quot;'}
            "'"  { '&#39;' }
        }
    })
}

function Get-CleanEvents {
    param([datetime]$Since, [datetime]$Until = (Get-Date))
    try {
        $all = Get-WinEvent -FilterHashtable @{
            LogName   = @('System', 'Application')
            Level     = 2
            StartTime = $Since
            EndTime   = $Until
        } -ErrorAction Stop
        return $all | Where-Object {
            ($ExcludeProviders -notcontains $_.ProviderName) -and
            ($ExcludeEventIds -notcontains $_.Id)
        } | Select-Object TimeCreated, LogName, Id, ProviderName, Message
    } catch {
        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
            return @()
        }
        Write-Warning ("Get-WinEvent başarısız: " + $_.Exception.Message)
        return @()
    }
}

function New-DarkHtmlReport {
    param(
        [string]$Title,
        [string]$Subtitle,
        [string]$Window,
        [int]$TotalEvents,
        [array]$Events,
        [array]$GroupedByLog,
        [array]$GroupedByProvider,
        [array]$GroupedById,
        [array]$GroupedByDay
    )

    $sb = New-Object System.Text.StringBuilder

    $sTitle = Format-HtmlSafe $Title
    $sSub   = Format-HtmlSafe $Subtitle
    $sWin   = Format-HtmlSafe $Window

    [void]$sb.Append('<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">')
    [void]$sb.Append('<meta name="viewport" content="width=device-width,initial-scale=1.0">')
    [void]$sb.Append("<title>$sTitle</title><style>")
    [void]$sb.Append('*,::before,::after{box-sizing:border-box;margin:0;padding:0}')
    [void]$sb.Append('body{font-family:"Segoe UI",system-ui,-apple-system,sans-serif;background:#0d1117;color:#c9d1d9;padding:24px;line-height:1.6}')
    [void]$sb.Append('.hdr{max-width:1200px;margin:0 auto 28px;padding:24px 32px;background:linear-gradient(135deg,#161b22,#1c2333);border:1px solid #30363d;border-radius:12px}')
    [void]$sb.Append('.hdr h1{font-size:26px;font-weight:700;color:#f0f6fc;letter-spacing:-0.3px}')
    [void]$sb.Append('.hdr .m{font-size:14px;color:#8b949e;margin-top:8px}')
    [void]$sb.Append('.hdr .m span{margin-right:20px}')
    [void]$sb.Append('.bdg{display:inline-block;padding:4px 12px;border-radius:20px;font-size:13px;font-weight:600}')
    [void]$sb.Append('.bdg-err{background:#3d1114;color:#ff6b6b;border:1px solid #5c1a1e}')
    [void]$sb.Append('.g{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;max-width:1200px;margin:0 auto 28px}')
    [void]$sb.Append('.c{background:#161b22;border:1px solid #30363d;border-radius:10px;padding:18px 22px;transition:border-color .2s}')
    [void]$sb.Append('.c:hover{border-color:#58a6ff}')
    [void]$sb.Append('.c .v{font-size:28px;font-weight:700;color:#f0f6fc}')
    [void]$sb.Append('.c .l{font-size:12px;color:#8b949e;text-transform:uppercase;letter-spacing:.5px;margin-top:4px}')
    [void]$sb.Append('.s{max-width:1200px;margin:0 auto 28px;background:#161b22;border:1px solid #30363d;border-radius:10px;overflow:hidden}')
    [void]$sb.Append('.st{padding:14px 22px;font-size:15px;font-weight:700;color:#f0f6fc;background:#1c2333;border-bottom:1px solid #30363d;text-transform:uppercase;letter-spacing:.4px}')
    [void]$sb.Append('table{width:100%;border-collapse:collapse;font-size:13px}')
    [void]$sb.Append('th{background:#1c2333;color:#8b949e;font-weight:600;text-align:left;padding:10px 14px;border-bottom:1px solid #30363d;white-space:nowrap;text-transform:uppercase;font-size:11px;letter-spacing:.4px}')
    [void]$sb.Append('td{padding:10px 14px;border-bottom:1px solid #21262d;color:#c9d1d9;vertical-align:top}')
    [void]$sb.Append('tr:nth-child(even) td{background:#0d1117}tr:hover td{background:#1f2937}')
    [void]$sb.Append('.sw{overflow-x:auto}')
    [void]$sb.Append('.tp,.te{display:inline-block;padding:2px 8px;border-radius:4px;font-size:12px;font-weight:500;font-family:"Cascadia Code","Fira Code",monospace}')
    [void]$sb.Append('.tp{background:#1f3a5f;color:#79c0ff}.te{background:#2d1b4e;color:#c9b1ff}')
    [void]$sb.Append('.mc{max-width:480px;word-break:break-word;white-space:pre-wrap;font-size:12px;color:#c9d1d9}')
    [void]$sb.Append('.f{text-align:center;color:#484f58;font-size:12px;padding:20px;max-width:1200px;margin:0 auto}')
    [void]$sb.Append('.filter-bar{max-width:1200px;margin:0 auto 28px;background:#161b22;border:1px solid #30363d;border-radius:10px;padding:16px 22px}')
    [void]$sb.Append('.fb-r{display:flex;flex-wrap:wrap;gap:10px;align-items:center}')
    [void]$sb.Append('.fb-r+.fb-r{margin-top:10px}')
    [void]$sb.Append('.filter-bar input[type=text]{background:#0d1117;border:1px solid #30363d;border-radius:6px;padding:8px 12px;color:#c9d1d9;font-size:13px;flex:1;min-width:120px}')
    [void]$sb.Append('.filter-bar input[type=text]:focus{border-color:#58a6ff;outline:none}')
    [void]$sb.Append('.filter-bar label{color:#8b949e;font-size:13px;cursor:pointer;display:inline-flex;align-items:center;gap:5px}')
    [void]$sb.Append('.filter-bar input[type=checkbox]{width:16px;height:16px;accent-color:#58a6ff;cursor:pointer}')
    [void]$sb.Append('.fcnt{color:#58a6ff;font-size:13px;font-weight:600;margin-left:auto}')
    [void]$sb.Append('.clr{background:transparent;border:1px solid #30363d;color:#8b949e;border-radius:6px;padding:6px 14px;font-size:12px;cursor:pointer}')
    [void]$sb.Append('.clr:hover{border-color:#58a6ff;color:#58a6ff}')
    [void]$sb.Append('</style></head><body><div class="hdr"><h1>')
    [void]$sb.Append($sTitle)
    [void]$sb.Append('</h1><div class="m"><span>')
    [void]$sb.Append($sSub)
    [void]$sb.Append('</span><span>')
    [void]$sb.Append($sWin)
    [void]$sb.Append('</span><span class="bdg bdg-err">')
    [void]$sb.Append($TotalEvents)
    [void]$sb.Append(' olay</span></div></div>')

    if ($TotalEvents -gt 0) {
        [void]$sb.Append('<div class="filter-bar"><div class="fb-r">')
        [void]$sb.Append('<input type="text" id="f-pr" placeholder="Sağlayıcı...">')
        [void]$sb.Append('<input type="text" id="f-eid" placeholder="Olay kodu...">')
        [void]$sb.Append('<input type="text" id="f-msg" placeholder="Mesajda ara...">')
        [void]$sb.Append('<button class="clr" onclick="cf()">Temizle</button>')
        [void]$sb.Append('</div><div class="fb-r">')
        [void]$sb.Append('<label><input type="checkbox" id="f-sys" checked> Sistem</label>')
        [void]$sb.Append('<label><input type="checkbox" id="f-app" checked> Uygulama</label>')
        [void]$sb.Append('<span class="fcnt" id="fcnt"></span>')
        [void]$sb.Append('</div></div>')
    }

    [void]$sb.Append('<div class="g">')
    [void]$sb.Append('<div class="c"><div class="v">')
    [void]$sb.Append($TotalEvents)
    [void]$sb.Append('</div><div class="l">Toplam Olay</div></div>')

    if ($TotalEvents -gt 0 -and $Events -and $GroupedByLog) {
        $sys = (($GroupedByLog | Where-Object Name -eq 'System') | Select-Object -First 1 -ExpandProperty Count) -as [int]
        $app = (($GroupedByLog | Where-Object Name -eq 'Application') | Select-Object -First 1 -ExpandProperty Count) -as [int]
        if (-not $sys) { $sys = 0 }; if (-not $app) { $app = 0 }
        [void]$sb.Append('<div class="c"><div class="v">')
        [void]$sb.Append($sys)
        [void]$sb.Append('</div><div class="l">Sistem Günlüğü</div></div>')
        [void]$sb.Append('<div class="c"><div class="v">')
        [void]$sb.Append($app)
        [void]$sb.Append('</div><div class="l">Uygulama Günlüğü</div></div>')
    }
    [void]$sb.Append('</div>')

    if ($GroupedByProvider) {
        [void]$sb.Append('<div class="s"><div class="st">En Çok Hata Üreten Sağlayıcılar</div><div class="sw"><table><thead><tr><th>#</th><th>Sağlayıcı</th><th>Adet</th></tr></thead><tbody>')
        $i = 1
        foreach ($g in $GroupedByProvider) {
            $sn = Format-HtmlSafe $g.Name
            [void]$sb.Append("<tr><td>$i</td><td><span class=""tp"">$sn</span></td><td>$($g.Count)</td></tr>")
            $i++
        }
        [void]$sb.Append('</tbody></table></div></div>')
    }

    if ($GroupedById) {
        [void]$sb.Append('<div class="s"><div class="st">En Sık Görülen Olay Kodları</div><div class="sw"><table><thead><tr><th>#</th><th>Olay Kodu</th><th>Adet</th></tr></thead><tbody>')
        $i = 1
        foreach ($g in $GroupedById) {
            [void]$sb.Append("<tr><td>$i</td><td><span class=""te"">$($g.Name)</span></td><td>$($g.Count)</td></tr>")
            $i++
        }
        [void]$sb.Append('</tbody></table></div></div>')
    }

    if ($GroupedByDay) {
        [void]$sb.Append('<div class="s"><div class="st">Günlere Göre Dağılım</div><div class="sw"><table><thead><tr><th>Tarih</th><th>Olay Sayısı</th></tr></thead><tbody>')
        foreach ($g in $GroupedByDay) {
            [void]$sb.Append("<tr><td>$($g.Name)</td><td>$($g.Count)</td></tr>")
        }
        [void]$sb.Append('</tbody></table></div></div>')
    }

    if ($TotalEvents -gt 0 -and $Events) {
        [void]$sb.Append('<div class="s"><div class="st">Tüm Olaylar</div><div class="sw"><table id="tbl-events"><thead><tr><th>Zaman</th><th>Günlük</th><th>Kod</th><th>Sağlayıcı</th><th>Mesaj</th></tr></thead><tbody>')
        $fmt = 'yyyy-MM-dd HH:mm:ss'
        foreach ($evt in $Events) {
            $sLog   = Format-HtmlSafe $evt.LogName
            $sProv  = Format-HtmlSafe $evt.ProviderName
            $sMsg   = ''
            if ($evt.Message) {
                $sMsg = Format-HtmlSafe $evt.Message
                $sMsg = [regex]::Replace($sMsg, '\r\n?|\n', '<br>')
            }
            [void]$sb.Append("<tr data-lg=""$sLog"" data-pr=""$sProv"" data-eid=""$($evt.Id)""><td style=""white-space:nowrap"">$($evt.TimeCreated.ToString($fmt))</td><td>$sLog</td><td><span class=""te"">$($evt.Id)</span></td><td><span class=""tp"">$sProv</span></td><td class=""mc"">$sMsg</td></tr>")
        }
        [void]$sb.Append('</tbody></table></div></div>')
    }

    $now = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    [void]$sb.Append('<div class="f">Oluşturulma: ')
    [void]$sb.Append($now)
    [void]$sb.Append(' &mdash; Koyu Tema Raporu</div>')

    if ($TotalEvents -gt 0) {
    [void]$sb.Append('<script>')
    [void]$sb.Append('function af(){var p=document.getElementById("f-pr").value.toLowerCase(),e=document.getElementById("f-eid").value,m=document.getElementById("f-msg").value.toLowerCase(),cs=document.getElementById("f-sys").checked,ca=document.getElementById("f-app").checked;var r=document.querySelectorAll("#tbl-events tbody tr"),v=0;for(var i=0;i<r.length;i++){var w=r[i],s=true,g=w.getAttribute("data-lg");if(g==="System"&&!cs)s=false;if(g==="Application"&&!ca)s=false;if(s&&p){var n=(w.getAttribute("data-pr")||"").toLowerCase();if(n.indexOf(p)===-1)s=false}if(s&&e){var d=(w.getAttribute("data-eid")||"");if(d.indexOf(e)===-1)s=false}if(s&&m){var t=(w.cells[4].textContent||"").toLowerCase();if(t.indexOf(m)===-1)s=false}w.style.display=s?"":"none";if(s)v++}')
    [void]$sb.Append('var fc=document.getElementById("fcnt");if(fc)fc.textContent=v+" / "+r.length+" olay"}')
    [void]$sb.Append('function cf(){document.getElementById("f-pr").value="";document.getElementById("f-eid").value="";document.getElementById("f-msg").value="";af()}')
    [void]$sb.Append('document.addEventListener("DOMContentLoaded",function(){af();["f-pr","f-eid","f-msg"].forEach(function(i){var el=document.getElementById(i);if(el)el.addEventListener("input",af)});["f-sys","f-app"].forEach(function(i){var el=document.getElementById(i);if(el)el.addEventListener("change",af)})})')
    [void]$sb.Append('</script></body></html>')
    }

    return $sb.ToString()
}

function Clean-OldReports {
    param([string]$Path, [int]$Keep)
    try {
        $files = @(Get-ChildItem -LiteralPath $Path -Filter '*.html' -Recurse | Sort-Object LastWriteTime -Descending)
        if ($files.Count -gt $Keep) {
            $files | Select-Object -Skip $Keep | Remove-Item -Force
            Write-Host ("[~] {0} eski dosya temizlendi" -f ($files.Count - $Keep)) -ForegroundColor Yellow
        }
    } catch {
        Write-Warning ("Temizlik başarısız: " + $_.Exception.Message)
    }
}

try {
    $Until = Get-Date
    $Cfg = @{
        Daily   = @{ Days = 1;  Folder = 'Daily';   Prefix = 'Bug-Report-Daily';   Keep = 30 }
        Weekly  = @{ Days = 7;  Folder = 'Weekly';  Prefix = 'Bug-Report-Weekly';  Keep = 4 }
        Monthly = @{ Days = 30; Folder = 'Monthly'; Prefix = 'Bug-Report-Monthly'; Keep = 3 }
    }[$Period]
    $Until = Get-Date
    $Since = $Until.AddDays(-$Cfg.Days)

    if ($Period -eq 'Weekly') {
        $Title      = "HAFTALIK RAPOR - HATA KAYITLARI"
        $Subtitle   = ("Aralık: {0} - {1}" -f $Since.ToString('yyyy-MM-dd'), $Until.ToString('yyyy-MM-dd'))
        $Window     = "Son 7 gün"
    } elseif ($Period -eq 'Monthly') {
        $Title      = "AYLIK RAPOR - HATA KAYITLARI"
        $Subtitle   = ("Ay: {0}" -f $Until.ToString('yyyy-MM'))
        $Window     = "Son 30 gün"
    } else {
        $Title      = "GÜNLÜK RAPOR - HATA KAYITLARI"
        $Subtitle   = ("Tarih: {0}" -f $Until.ToString('yyyy-MM-dd'))
        $Window     = "Son 24 saat"
    }

    $OutPath = Join-Path $BasePath $Cfg.Folder
    $null = New-Item -ItemType Directory -Force -Path $OutPath

    $Events = Get-CleanEvents -Since $Since -Until $Until
    $Total = if ($Events) { @($Events).Count } else { 0 }

    $Stamp = $Until.ToString('yyyyMMdd_HHmmss')
    $OutFile = Join-Path $OutPath ("$($Cfg.Prefix)_{0}.html" -f $Stamp)
    $IndexFile = Join-Path $OutPath 'index.txt'
    if (-not (Test-Path -LiteralPath $IndexFile)) {
        Set-Content -LiteralPath $IndexFile -Value ("Script: Bug-Report $Period - Dir: $OutPath - Created: " + $Until.ToString('yyyyMMdd_HHmmss')) -Encoding utf8
    }
    Add-Content -LiteralPath $IndexFile -Value ($Stamp + ' ' + [System.IO.Path]::GetFileName($OutFile)) -Encoding utf8
    Write-Host "[+] Dizin: $IndexFile" -ForegroundColor Green

    Write-Host ("[*] {0} olay bulundu" -f $Total) -ForegroundColor Cyan

    $html = New-DarkHtmlReport `
        -Title $Title `
        -Subtitle $Subtitle `
        -Window $Window `
        -TotalEvents $Total `
        -Events $Events `
        -GroupedByLog       ($Events | Group-Object LogName       | Sort-Object Count -Descending) `
        -GroupedByProvider  ($Events | Group-Object ProviderName  | Sort-Object Count -Descending) `
        -GroupedById        ($Events | Group-Object Id            | Sort-Object Count -Descending) `
        -GroupedByDay       ($Events | Group-Object { $_.TimeCreated.ToString('yyyy-MM-dd') } | Sort-Object Name)

    [System.IO.File]::WriteAllText($OutFile, $html, (New-Object System.Text.UTF8Encoding $true))
    Write-Host "[+] Rapor kaydedildi: $OutFile" -ForegroundColor Green

    Clean-OldReports -Path (Join-Path $BasePath $Cfg.Folder) -Keep $Cfg.Keep
    try { while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } } catch { }
} catch {
    Write-Host "[!] ÖLÜMCÜL HATA: $_" -ForegroundColor Red
    exit 1
}
