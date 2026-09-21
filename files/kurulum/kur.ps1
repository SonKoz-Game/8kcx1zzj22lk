[CmdletBinding()]
param(
    [switch]$Uygula,
    [switch]$GeriAl,
    [switch]$UyumsuzKorumayiOnayla,
    [string[]]$Sadece = @(),
    [string[]]$Haric = @(),
    [string]$ResourcesDizini = ''
)

$ErrorActionPreference = 'Stop'

$KURUCU_SURUMU = '1.1.37'
$GUARD_RESOURCE = 'amcaoglu_anticheat'
$SHIM_DIR       = '.amcaoglu'
$MARKER_BEGIN   = '<!-- amcaoglu_anticheat: korumali transport - elle duzenlemeyin -->'
$MARKER_END     = '<!-- /amcaoglu_anticheat -->'
$MIN_MTA_CLIENT = '1.6.0-9.21695'
$MIN_MTA_SERVER = '1.6.0-9.22470'

$CROWN_SCRIPT_DESEN = '<script\b[^>]*\bsrc\s*=\s*["'']([^"'']+)["''][^>]*>'
$CROWN_MARKER_ONEK = '-- amcaoglu_anticheat: crown hile korumasi katmani kaldirildi | '
$CROWN_META_MARKER_ONEK = '<!-- amcaoglu_anticheat: crown-orijinal-src | '
$CROWN_URETILEN_SON_EK = '.amcaoglu.lua'

$kurulumDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$guardDir    = Split-Path -Parent $kurulumDir
$sablonDir   = Join-Path $kurulumDir 'sablon'

$CROWN_YEDEK_DIR = Join-Path $kurulumDir 'yedek'

$resourcesDir = if ($ResourcesDizini) {
    [System.IO.Path]::GetFullPath($ResourcesDizini)
} else {
    $null
}
if (-not $resourcesDir) {
    $aday = Split-Path -Parent $guardDir
    while ($aday) {
        if ((Split-Path -Leaf $aday) -eq 'resources') { $resourcesDir = $aday; break }
        $ust = Split-Path -Parent $aday
        if ($ust -eq $aday) { break }
        $aday = $ust
    }
}

function Yaz([string]$metin, [string]$renk = 'Gray') { Write-Host $metin -ForegroundColor $renk }

function Get-DosyaHash([string]$yol) {
    if (-not (Test-Path -LiteralPath $yol -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $yol -Algorithm SHA256).Hash
}

function Test-DosyaAyni([string]$sol, [string]$sag) {
    $solHash = Get-DosyaHash $sol
    $sagHash = Get-DosyaHash $sag
    return $null -ne $solHash -and $solHash -eq $sagHash
}

function Test-ShimGuncel([string]$dizin) {
    $shimPath = Join-Path $dizin $SHIM_DIR
    foreach ($ad in @('transport_server.lua', 'transport_client.lua')) {
        if (-not (Test-DosyaAyni (Join-Path $sablonDir $ad) (Join-Path $shimPath $ad))) {
            return $false
        }
    }
    return $true
}

function Compare-MtaSurumu([string]$sol, [string]$sag) {
    $solParcalar = @([regex]::Matches($sol, '\d+') | ForEach-Object { [int64]$_.Value })
    $sagParcalar = @([regex]::Matches($sag, '\d+') | ForEach-Object { [int64]$_.Value })
    $uzunluk = [math]::Max($solParcalar.Count, $sagParcalar.Count)
    for ($i = 0; $i -lt $uzunluk; $i++) {
        $solDeger = if ($i -lt $solParcalar.Count) { $solParcalar[$i] } else { 0 }
        $sagDeger = if ($i -lt $sagParcalar.Count) { $sagParcalar[$i] } else { 0 }
        if ($solDeger -gt $sagDeger) { return 1 }
        if ($solDeger -lt $sagDeger) { return -1 }
    }
    return 0
}

function Get-MtaSurumOzelligi([string]$etiket, [string]$ad) {
    $eslesme = [regex]::Match($etiket, ('\b' + [regex]::Escape($ad) + '\s*=\s*["'']([^"'']+)["'']'), 'IgnoreCase')
    if ($eslesme.Success) { return $eslesme.Groups[1].Value }
    return $null
}

function Get-EnAzMtaSurumu([string]$mevcut, [string]$gerekli) {
    if ($mevcut -and (Compare-MtaSurumu $mevcut $gerekli) -ge 0) { return $mevcut }
    return $gerekli
}

function Get-MetaMinimumVersion([string]$metin) {
    $eslesme = [regex]::Match($metin, '<min_mta_version\b[^>]*/\s*>', 'IgnoreCase')
    if (-not $eslesme.Success) { return $null }
    return [pscustomobject]@{
        Client = Get-MtaSurumOzelligi $eslesme.Value 'client'
        Server = Get-MtaSurumOzelligi $eslesme.Value 'server'
    }
}

function Test-MetaMinimumVersion([string]$metin) {
    $surum = Get-MetaMinimumVersion $metin
    return $null -ne $surum `
        -and (Compare-MtaSurumu $surum.Client $MIN_MTA_CLIENT) -ge 0 `
        -and (Compare-MtaSurumu $surum.Server $MIN_MTA_SERVER) -ge 0
}

function Set-MetaMinimumVersionText([string]$metin) {
    $eslesme = [regex]::Match($metin, '(?im)^(?<girinti>[ \t]*)<min_mta_version\b[^>]*/\s*>')
    if ($eslesme.Success) {
        $client = Get-EnAzMtaSurumu (Get-MtaSurumOzelligi $eslesme.Value 'client') $MIN_MTA_CLIENT
        $server = Get-EnAzMtaSurumu (Get-MtaSurumOzelligi $eslesme.Value 'server') $MIN_MTA_SERVER
        $etiket = $eslesme.Groups['girinti'].Value + "<min_mta_version client=`"$client`" server=`"$server`" />"
        return $metin.Substring(0, $eslesme.Index) + $etiket + $metin.Substring($eslesme.Index + $eslesme.Length)
    }

    $kapanis = [regex]::Match($metin, '</meta\s*>', 'IgnoreCase')
    $etiket = "    <min_mta_version client=`"$MIN_MTA_CLIENT`" server=`"$MIN_MTA_SERVER`" />"
    if ($kapanis.Success) { return Add-Blok $metin $kapanis.Index $etiket }
    return $metin.TrimEnd() + "`n" + $etiket + "`n"
}

function Test-MetaShimGuncel([string]$metaPath, [bool]$crownOnceYuklensin = $false, [string]$crownSrc = '') {
    $metin = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8
    if ($null -eq $metin) { return $false }
    $markerSayisi = [regex]::Matches($metin, [regex]::Escape($MARKER_BEGIN)).Count
    $scriptler = [regex]::Matches($metin, '<script\b[^>]*\bsrc\s*=\s*["'']([^"'']+)["''][^>]*>', 'IgnoreCase')
    $serverIndex = 0
    if ($crownOnceYuklensin) {
        $serverIndex = -1
        for ($i = 0; $i -lt $scriptler.Count; $i++) {
            if ($scriptler[$i].Groups[1].Value.Replace('\', '/') -ieq $crownSrc) {
                $serverIndex = $i + 1
                break
            }
        }
    }
    $dogruSira = $serverIndex -ge 0 `
        -and $scriptler.Count -gt ($serverIndex + 1) `
        -and $scriptler[$serverIndex].Groups[1].Value.Replace('\', '/') -eq "$SHIM_DIR/transport_server.lua" `
        -and $scriptler[$serverIndex + 1].Groups[1].Value.Replace('\', '/') -eq "$SHIM_DIR/transport_client.lua"
    return $markerSayisi -eq 2 `
        -and $dogruSira `
        -and [regex]::IsMatch($metin, '<include\b[^>]*\bresource\s*=\s*["'']' + [regex]::Escape($GUARD_RESOURCE) + '["''][^>]*/\s*>', 'IgnoreCase') `
        -and (Test-MetaMinimumVersion $metin) `
        -and $metin.Contains("src=`"$SHIM_DIR/transport_server.lua`"") `
        -and $metin.Contains("src=`"$SHIM_DIR/transport_client.lua`"") `
        -and $metin.Contains('export function="dispatchProtectedEvent"')
}

function Get-MetaScripts([string]$metaPath) {
    $metin = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8
    if (-not $metin) { return $null }

    try {
        $xml = [xml]$metin
        if ($xml.meta) { return @($xml.meta.script) }
    } catch { }

    $eslesmeler = [regex]::Matches($metin, '<script\b[^>]*\bsrc\s*=\s*["'']([^"'']+)["''][^>]*>', 'IgnoreCase')
    if ($eslesmeler.Count -eq 0) { return $null }

    $sonuc = @()
    foreach ($m in $eslesmeler) {
        $etiket = $m.Value
        $tur = 'server'
        $turEslesme = [regex]::Match($etiket, '\btype\s*=\s*["'']([^"'']+)["'']', 'IgnoreCase')
        if ($turEslesme.Success) { $tur = $turEslesme.Groups[1].Value }
        $sonuc += [pscustomobject]@{ src = $m.Groups[1].Value; type = $tur }
    }
    return $sonuc
}

function Get-CrownBilgisi([string]$dizin, [string]$metaMetin) {
    $eslesmeler = @()
    $scriptYollari = @()
    foreach ($m in [regex]::Matches($metaMetin, $CROWN_SCRIPT_DESEN, 'IgnoreCase')) {
        $yol = $m.Groups[1].Value.Replace('\', '/')
        $aday = Test-CrownScriptAdayi $dizin $yol $true
        if ($aday.Taninir -and $scriptYollari -notcontains $yol) {
            $scriptYollari += $yol
            $eslesmeler += $m
        }
    }
    $eslesme = if ($eslesmeler.Count -gt 0) { $eslesmeler[0] } else { $null }

    $klasorVar = $false
    foreach ($f in Get-ChildItem -LiteralPath $dizin -File -Recurse -ErrorAction SilentlyContinue) {
        $goreli = $f.FullName.Substring($dizin.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/'
        if ($goreli -match '(?i)(^|/)\.amcaoglu/' -or $goreli.EndsWith($CROWN_URETILEN_SON_EK, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $aday = Test-CrownScriptAdayi $dizin $goreli
        if ($aday.Taninir) { $klasorVar = $true; break }
    }

    $oncekiScript = $false
    if ($null -ne $eslesme -and $eslesme.Success) {
        $oncesi = $metaMetin.Substring(0, $eslesme.Index)
        $shimDeseni = [regex]::Escape($MARKER_BEGIN) + '.*?' + [regex]::Escape($MARKER_END)
        $oncesi = [regex]::Replace($oncesi, $shimDeseni, '', 'Singleline')
        $oncekiScript = [regex]::IsMatch($oncesi, '<script\b', 'IgnoreCase')
    }

    return [pscustomobject]@{
        Var          = ($eslesmeler.Count -gt 0 -or $klasorVar)
        MetadaVar    = $eslesmeler.Count -gt 0
        KlasorVar    = $klasorVar
        OncekiScript = $oncekiScript
        ScriptYollari = $scriptYollari
    }
}

function Test-CrownScriptAdayi([string]$dizin, [string]$scriptYolu, [bool]$aktifManifest = $false) {
    $bos = [pscustomobject]@{ Taninir = $false; KaynakTam = $null; Sebep = '' }
    $goreli = $scriptYolu.Replace('\', '/').TrimStart('/')
    if (-not $goreli -or $goreli -match '(?:^|/)\.\.(?:/|$)' -or $goreli -match '(?i)(^|/)\.amcaoglu/') { return $bos }

    $resourceRoot = [System.IO.Path]::GetFullPath($dizin).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    try { $aktifTam = [System.IO.Path]::GetFullPath((Join-Path $dizin ($goreli -replace '/', '\'))) }
    catch { return $bos }
    if (-not $aktifTam.StartsWith($resourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) { return $bos }
    if ([System.IO.Path]::GetExtension($aktifTam) -notin @('.lua', '.luac')) { return $bos }

    $kaynakTam = if ($goreli.EndsWith($CROWN_URETILEN_SON_EK, [System.StringComparison]::OrdinalIgnoreCase)) {
        $aktifTam.Substring(0, $aktifTam.Length - $CROWN_URETILEN_SON_EK.Length) + '.lua'
    } elseif ([System.IO.Path]::GetExtension($aktifTam) -ieq '.luac') {
        [System.IO.Path]::ChangeExtension($aktifTam, '.lua')
    } else { $aktifTam }

    if (Test-Path -LiteralPath $kaynakTam -PathType Leaf) {
        try { $test = Clear-CrownBundle $kaynakTam $false } catch { $test = $null }
        if ($test -and $test.Durum -in @('temizlendi', 'zaten-temiz')) {
            return [pscustomobject]@{ Taninir = $true; KaynakTam = $kaynakTam; Sebep = 'icerik imzasi' }
        }
    }

    if (($aktifManifest -or [System.IO.Path]::GetExtension($aktifTam) -ieq '.luac') -and $goreli -match '(^|/)\.[^/]+/') {
        return [pscustomobject]@{ Taninir = $true; KaynakTam = $kaynakTam; Sebep = 'gizli aktif bundle' }
    }
    return $bos
}

function Test-CrownKorumaYolu($crown, [string]$goreliYol) {
    $goreli = $goreliYol.Replace('\', '/').TrimStart('/')
    foreach ($bundle in @($crown.ScriptYollari)) {
        $bundleYolu = $bundle.Replace('\', '/').TrimStart('/')
        $bundleDir = ('' + [System.IO.Path]::GetDirectoryName($bundleYolu)).Replace('\', '/').Trim('/')
        if ($bundleDir -and $goreli.StartsWith($bundleDir + '/', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        if (-not $bundleDir -and $goreli -ieq $bundleYolu) { return $true }
    }
    return $false
}

$CROWN_KURALLARI = @(
    @{ Ad = 'restart sayaci';             Desen = '(?s)addEventHandler\("onClientResourceStart",[ \t]*resourceRoot,[ \t]*function\(\)\r?\n[ \t]*local[ \t]+counter[ \t]*=[ \t]*getElementData\(resourceRoot,[ \t]*"restart_counter"\).*?\r?\nend\)[ \t]*\r?\n' }
    @{ Ad = 'loadstring override';        Desen = '(?s)function[ \t]+overrideLoadString\(\).*?\r?\nend\)[ \t]*\r?\n' }
    @{ Ad = 'decodeEvent komutu';         Desen = '(?s)addCommandHandler\("decodeEvent",.*?\r?\nend\)[ \t]*\r?\n' }
    @{ Ad = 'addDebugHook kisiti';        Desen = '(?s)local[ \t]+function[ \t]+_triggerServerEventCrown\(.*?function[ \t]+addDebugHook\(hookType,[ \t]*callbackFunction,[ \t]*nameList\).*?\r?\nend\r?\n' }
    @{ Ad = 'triggerServerEvent';         Desen = '(?s)function[ \t]+triggerServerEvent\(eventName,[ \t]*\.\.\.\).*?\r?\nend\r?\n' }
    @{ Ad = 'minimal paket azaltma sayaci'; Opsiyonel = $true; Desen = '(?s)if[ \t]+localPlayer[ \t]+then\r?\n[ \t]*setTimer\(function\(\)\r?\n[ \t]*if[ \t]+packetsCountPerSecond[ \t]*>[ \t]*0[ \t]+then\r?\n[ \t]*packetsCountPerSecond[ \t]*=[ \t]*packetsCountPerSecond[ \t]*-[ \t]*1\r?\n[ \t]*end\r?\n[ \t]*end,[ \t]*150,[ \t]*0\)\r?\nend[ \t]*\r?\n' }
    @{ Ad = 'tam paket azaltma sayaci';    Opsiyonel = $true; Desen = '(?s)(if[ \t]+localPlayer[ \t]+then\r?\n)[ \t]*setTimer\(function\(\)\r?\n[ \t]*if[ \t]+packetsCountPerSecond[ \t]*>[ \t]*0[ \t]+then\r?\n[ \t]*packetsCountPerSecond[ \t]*=[ \t]*packetsCountPerSecond[ \t]*-[ \t]*1\r?\n[ \t]*end\r?\n[ \t]*end,[ \t]*150,[ \t]*0\)\r?\n'
       Yerine = '$1' }
    @{ Ad = 'importer oop uyumlulugu';     Opsiyonel = $true; Desen = 'local[ \t]+imports[ \t]*=[ \t]*self\.scripts[ \t]*==[ \t]*"\*"[ \t]+and[ \t]+resource:getExportedFunctions\(\)[ \t]+or[ \t]+split\(self\.scripts,[ \t]*","\)'
       Yerine = "local exportedFunctions = resource and getResourceExportedFunctions(resource)`n`tlocal imports = self.scripts == `"*`" and (type(exportedFunctions) == `"table`" and exportedFunctions or {}) or split(self.scripts, `",`")" }
    @{ Ad = 'triggerLatentServerEvent';   Desen = '(?s)function[ \t]+triggerLatentServerEvent\(eventName,[ \t]*\.\.\.\).*?\r?\nend\r?\n' }
)

function Get-MetinHash([string]$metin) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bayt = [System.Text.Encoding]::UTF8.GetBytes($metin)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bayt)) -replace '-', '').Substring(0, 16).ToLower()
    } finally { $sha.Dispose() }
}

function Get-CrownKaynakBootstrapIstisnasi([string]$bundlePath) {
    if (-not $bundlePath.EndsWith($CROWN_URETILEN_SON_EK, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    $kok = $bundlePath.Substring(0, $bundlePath.Length - $CROWN_URETILEN_SON_EK.Length)
    $kaynakPath = $kok + '.lua'
    if (-not (Test-Path -LiteralPath $kaynakPath -PathType Leaf)) { return $null }

    $kaynakMetin = Get-Content -LiteralPath $kaynakPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $kaynakMetin) { return $null }
    $eslesme = [regex]::Match($kaynakMetin, 'getResourceName\(getThisResource\(\)\)[ \t]*~=[ \t]*"([^"]+)"')
    if (-not $eslesme.Success) { return $null }
    return $eslesme.Groups[1].Value
}

function Clear-CrownBundle([string]$bundlePath, [bool]$uygula) {
    $metin = Get-Content -LiteralPath $bundlePath -Raw -Encoding UTF8
    if ($null -eq $metin) {
        return [pscustomobject]@{ Durum = 'taninmadi'; Sebep = 'dosya okunamadi'; Kaldirilan = 0; Metin = $null }
    }

    if ($metin.StartsWith($CROWN_MARKER_ONEK)) {
        $onarilan = $metin
        $onarimNedeni = @()

        $oopKurali = $CROWN_KURALLARI | Where-Object { $_.Ad -eq 'importer oop uyumlulugu' }
        if ([regex]::IsMatch($onarilan, $oopKurali.Desen)) {
            $onarilan = [regex]::Replace($onarilan, $oopKurali.Desen, $oopKurali.Yerine)
            $onarimNedeni += 'importer OOP uyumlulugu'
        }

        $eskiOopDeseni = 'local[ \t]+imports[ \t]*=[ \t]*self\.scripts[ \t]*==[ \t]*"\*"[ \t]+and[ \t]+\(resource[ \t]+and[ \t]+getResourceExportedFunctions\(resource\)[ \t]+or[ \t]+\{\}\)[ \t]+or[ \t]+split\(self\.scripts,[ \t]*","\)'
        if ([regex]::IsMatch($onarilan, $eskiOopDeseni)) {
            $onarilan = [regex]::Replace($onarilan, $eskiOopDeseni, $oopKurali.Yerine)
            $onarimNedeni += 'importer sonuc dogrulamasi'
        }

        $kaynakBootstrapIstisnasi = Get-CrownKaynakBootstrapIstisnasi $bundlePath
        $bootstrapIstisnasi = [regex]::Match($onarilan, '(getResourceName\(getThisResource\(\)\)[ \t]*~=[ \t]*")([^"]+)(")')
        if ($kaynakBootstrapIstisnasi -and $bootstrapIstisnasi.Success -and $kaynakBootstrapIstisnasi -ne $bootstrapIstisnasi.Groups[2].Value) {
            $yerine = '${1}' + $kaynakBootstrapIstisnasi + '${3}'
            $onarilan = [regex]::Replace($onarilan, '(getResourceName\(getThisResource\(\)\)[ \t]*~=[ \t]*")([^"]+)(")', $yerine, 1)
            $onarimNedeni += 'UI bootstrap hedefi'
        }

        $artikSayacDeseni = ($CROWN_KURALLARI | Where-Object { $_.Ad -eq 'minimal paket azaltma sayaci' }).Desen
        if ($onarilan -match 'packetsCountPerSecond' -and [regex]::IsMatch($onarilan, $artikSayacDeseni)) {
            $onarilan = [regex]::Replace($onarilan, $artikSayacDeseni, '')
            $onarilan = [regex]::Replace($onarilan, '(\r?\n){3,}', "`n`n")
            $onarimNedeni += 'minimal paket sayaci'
        }

        $loaderVar = $onarilan -match '(?m)^local[ \t]+_loadstring[ \t]*=[ \t]*loadstring[ \t]*\r?$'
        $loaderVar = $loaderVar -and ($onarilan -match '(?s)loadGameCode[ \t]*=[ \t]*function\(code\).*?return[ \t]+_loadstring\(code\).*?end')
        $bootstrapVar = $onarilan -match 'loadGameCode\(injectHooks\(\)\)\(\)'
        $importerVar = $onarilan -match 'function[ \t]+importer:from\('

        if ($onarimNedeni.Count -gt 0 -and $loaderVar -and ($bootstrapVar -or -not $importerVar)) {
            if ($uygula) {
                [System.IO.File]::WriteAllText($bundlePath, $onarilan, (New-Object System.Text.UTF8Encoding($false)))
            }
            return [pscustomobject]@{ Durum = 'temizlendi'; Sebep = ($onarimNedeni -join ', ') + ' onarildi'; Kaldirilan = $onarimNedeni.Count; Metin = $onarilan }
        }

        if ($loaderVar -and ($bootstrapVar -or -not $importerVar)) {
            return [pscustomobject]@{ Durum = 'zaten-temiz'; Sebep = ''; Kaldirilan = 0; Metin = $onarilan }
        }

        if (-not $loaderVar) {
            $satirSonu = $onarilan.IndexOf("`n")
            if ($satirSonu -lt 0) {
                return [pscustomobject]@{ Durum = 'taninmadi'; Sebep = 'eski crown marker satiri bozuk'; Kaldirilan = 0; Metin = $null }
            }
            $loader = "`nlocal _loadstring = loadstring`n`nloadGameCode = function(code)`n`treturn _loadstring(code)`nend`n"
            $onarilan = $onarilan.Insert($satirSonu + 1, $loader)
        }
        if (-not $bootstrapVar) {
            $eskiBaslatma = '(?s)if[ \t]+localPlayer[ \t]+then\r?\n[ \t]*(importer:import\("\*"\):from\("[^"]+"\))[ \t]*\r?\nend'
            $eslesme = [regex]::Match($onarilan, $eskiBaslatma)
            if (-not $eslesme.Success) {
                return [pscustomobject]@{ Durum = 'taninmadi'; Sebep = 'eski temizlenmis crown bootstrap blogu bulunamadi'; Kaldirilan = 0; Metin = $null }
            }
            $kaynakBootstrapIstisnasi = Get-CrownKaynakBootstrapIstisnasi $bundlePath
            if (-not $kaynakBootstrapIstisnasi) {
                return [pscustomobject]@{ Durum = 'taninmadi'; Sebep = 'orijinal crown bootstrap hedefi bulunamadi'; Kaldirilan = 0; Metin = $null }
            }
            $yeniBaslatma = "if localPlayer then`n`t$($eslesme.Groups[1].Value)`n`n`tif getResourceName(getThisResource()) ~= `"$kaynakBootstrapIstisnasi`" then`n`t`tloadGameCode(injectHooks())()`n`tend`nend"
            $onarilan = $onarilan.Substring(0, $eslesme.Index) + $yeniBaslatma + $onarilan.Substring($eslesme.Index + $eslesme.Length)
        }

        if ($onarilan -notmatch 'loadGameCode\(injectHooks\(\)\)\(\)') {
            return [pscustomobject]@{ Durum = 'taninmadi'; Sebep = 'crown bootstrap onarimi dogrulanamadi'; Kaldirilan = 0; Metin = $null }
        }
        if ($uygula) {
            [System.IO.File]::WriteAllText($bundlePath, $onarilan, (New-Object System.Text.UTF8Encoding($false)))
        }
        return [pscustomobject]@{ Durum = 'temizlendi'; Sebep = 'eski UI bootstrap onarildi'; Kaldirilan = 0; Metin = $onarilan }
    }

    $hash = Get-MetinHash $metin

    $yeni = $metin
    $sayac = 0
    foreach ($kural in $CROWN_KURALLARI) {
        $eslesmeler = [regex]::Matches($yeni, $kural.Desen)
        if ($eslesmeler.Count -eq 0 -and $kural.ContainsKey('Opsiyonel') -and $kural.Opsiyonel) {
            continue
        }
        if ($eslesmeler.Count -ne 1) {
            return [pscustomobject]@{
                Durum      = 'taninmadi'
                Sebep      = ("'{0}' kurali {1} kez eslesti (1 bekleniyordu)" -f $kural.Ad, $eslesmeler.Count)
                Kaldirilan = 0
                Metin      = $null
            }
        }

        $yerine = ''
        if ($kural.ContainsKey('Yerine')) { $yerine = $kural.Yerine }
        $yeni = [regex]::Replace($yeni, $kural.Desen, $yerine)
        $sayac++
    }

    $yeni = [regex]::Replace($yeni, '(\r?\n){3,}', "`n`n")
    $yeni = $CROWN_MARKER_ONEK + $hash + "`n" + $yeni.TrimStart("`r", "`n")

    if ($uygula) {
        if (-not (Test-Path -LiteralPath $CROWN_YEDEK_DIR)) {
            New-Item -ItemType Directory -Force -Path $CROWN_YEDEK_DIR | Out-Null
        }
        $yedek = Join-Path $CROWN_YEDEK_DIR ($hash + '.lua')
        if (-not (Test-Path -LiteralPath $yedek)) {
            Copy-Item -LiteralPath $bundlePath -Destination $yedek -Force
        }
        [System.IO.File]::WriteAllText($bundlePath, $yeni, (New-Object System.Text.UTF8Encoding($false)))
    }

    return [pscustomobject]@{ Durum = 'temizlendi'; Sebep = ''; Kaldirilan = $sayac; Metin = $yeni }
}

function Restore-CrownKlasoru([string]$dizin, [bool]$uygula) {
    $dokunuldu = $false
    foreach ($f in Get-ChildItem -LiteralPath $dizin -File -Recurse -Filter *.lua -ErrorAction SilentlyContinue) {
            if ($f.FullName -match '(?i)[\\/]\.amcaoglu[\\/]') { continue }
            if ($f.Name.EndsWith($CROWN_URETILEN_SON_EK, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $metin = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
            if ($null -eq $metin -or -not $metin.StartsWith($CROWN_MARKER_ONEK)) { continue }

            $satirSonu = $metin.IndexOf("`n")
            if ($satirSonu -lt 0) { continue }
            $hash = $metin.Substring($CROWN_MARKER_ONEK.Length, $satirSonu - $CROWN_MARKER_ONEK.Length).Trim()

            $yedek = Join-Path $CROWN_YEDEK_DIR ($hash + '.lua')
            if (-not (Test-Path -LiteralPath $yedek)) {
                Yaz "    ! $($f.Name): yedek bulunamadi ($hash.lua), geri alinamadi" 'Yellow'
                continue
            }

            if ($uygula) { Copy-Item -LiteralPath $yedek -Destination $f.FullName -Force }
            $dokunuldu = $true
    }

    return $dokunuldu
}

function Get-CrownDagitimPlani([object[]]$hedefler) {
    $varyantOnbellegi = @{}
    $ogeler = @()
    $hatalar = @()

    foreach ($h in $hedefler) {
        if (-not $h.Crown.MetadaVar) { continue }

        $resourceRoot = [System.IO.Path]::GetFullPath($h.Dizin).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        foreach ($aktifYolHam in $h.Crown.ScriptYollari) {
            $aktifYol = $aktifYolHam.Replace('\', '/')
            $aktifDizin = ('' + [System.IO.Path]::GetDirectoryName($aktifYol)).Replace('\', '/')
            $crownRootHam = if ($aktifDizin) { Join-Path $h.Dizin ($aktifDizin -replace '/', '\') } else { $h.Dizin }
            $crownRoot = [System.IO.Path]::GetFullPath($crownRootHam).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
            $kaynakYol = if ($aktifYol.EndsWith($CROWN_URETILEN_SON_EK, [System.StringComparison]::OrdinalIgnoreCase)) {
                $aktifYol.Substring(0, $aktifYol.Length - $CROWN_URETILEN_SON_EK.Length) + '.lua'
            } elseif ([System.IO.Path]::GetExtension($aktifYol) -ieq '.luac') {
                [System.IO.Path]::ChangeExtension($aktifYol, '.lua').Replace('\', '/')
            } else {
                $aktifYol
            }

            try {
                $kaynakTam = [System.IO.Path]::GetFullPath((Join-Path $h.Dizin ($kaynakYol -replace '/', '\')))
            } catch {
                $hatalar += ("{0}: {1} (gecersiz kaynak yolu)" -f $h.Ad, $kaynakYol)
                continue
            }
            if (-not $kaynakTam.StartsWith($resourceRoot, [System.StringComparison]::OrdinalIgnoreCase) `
                -or -not $kaynakTam.StartsWith($crownRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $hatalar += ("{0}: {1} (resource disina cikiyor)" -f $h.Ad, $kaynakYol)
                continue
            }
            if (-not (Test-Path -LiteralPath $kaynakTam -PathType Leaf)) {
                $hatalar += ("{0}: {1} icin kaynak .lua bulunamadi" -f $h.Ad, $aktifYol)
                continue
            }

            $kaynakHash = Get-DosyaHash $kaynakTam
            if (-not $varyantOnbellegi.ContainsKey($kaynakHash)) {
                $temizlik = Clear-CrownBundle $kaynakTam $false
                if ($temizlik.Durum -notin @('temizlendi', 'zaten-temiz') -or -not $temizlik.Metin) {
                    $varyantOnbellegi[$kaynakHash] = [pscustomobject]@{
                        Basarili = $false
                        Sebep = $temizlik.Sebep
                        Metin = $null
                        TemizHash = $null
                    }
                } else {
                    $varyantOnbellegi[$kaynakHash] = [pscustomobject]@{
                        Basarili = $true
                        Sebep = ''
                        Metin = $temizlik.Metin
                        TemizHash = Get-MetinHash $temizlik.Metin
                    }
                }
            }

            $varyant = $varyantOnbellegi[$kaynakHash]
            if (-not $varyant.Basarili) {
                $hatalar += ("{0}: {1} ({2})" -f $h.Ad, $kaynakYol, $varyant.Sebep)
                continue
            }

            $hedefYol = if ($aktifYol.EndsWith($CROWN_URETILEN_SON_EK, [System.StringComparison]::OrdinalIgnoreCase)) {
                $aktifYol
            } else {
                $dizinParcasi = [System.IO.Path]::GetDirectoryName($aktifYol).Replace('\', '/')
                $dosyaGovdesi = [System.IO.Path]::GetFileNameWithoutExtension($aktifYol)
                (($dizinParcasi.TrimEnd('/') + '/' + $dosyaGovdesi + $CROWN_URETILEN_SON_EK).TrimStart('/'))
            }
            $hedefTam = [System.IO.Path]::GetFullPath((Join-Path $h.Dizin ($hedefYol -replace '/', '\')))
            if (-not $hedefTam.StartsWith($crownRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $hatalar += ("{0}: uretilen Crown yolu guvenli degil" -f $h.Ad)
                continue
            }

            $ogeler += [pscustomobject]@{
                Resource = $h.Ad
                MetaPath = $h.MetaPath
                OrijinalSrc = $aktifYol
                HedefSrc = $hedefYol
                HedefTam = $hedefTam
                KaynakHash = $kaynakHash
                TemizHash = $varyant.TemizHash
                Metin = $varyant.Metin
            }
        }
    }

    $basariliVaryantlar = @($varyantOnbellegi.Values | Where-Object { $_.Basarili } | Select-Object -ExpandProperty TemizHash -Unique)
    return [pscustomobject]@{
        Basarili = $true
        Ogeler = $ogeler
        Hatalar = $hatalar
        VaryantSayisi = $basariliVaryantlar.Count
    }
}

function Set-CrownMetaYonlendirme([string]$metaPath, [object[]]$ogeler, [bool]$uygula) {
    $metin = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8
    $degisti = $false

    foreach ($oge in $ogeler) {
        if ($oge.OrijinalSrc -eq $oge.HedefSrc) { continue }

        $eslesme = $null
        foreach ($m in [regex]::Matches($metin, $CROWN_SCRIPT_DESEN, 'IgnoreCase')) {
            if ($m.Groups[1].Value.Replace('\', '/') -ieq $oge.OrijinalSrc) {
                $eslesme = $m
                break
            }
        }
        if ($null -eq $eslesme) { return $false }

        $etiket = $eslesme.Value
        $src = [regex]::Match($etiket, '\bsrc\s*=\s*(["''])([^"'']+)(["''])', 'IgnoreCase')
        if (-not $src.Success) { return $false }
        $goreliIndex = $src.Groups[2].Index
        $yeniEtiket = $etiket.Substring(0, $goreliIndex) + $oge.HedefSrc + $etiket.Substring($goreliIndex + $src.Groups[2].Length)
        $kod = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($oge.OrijinalSrc))
        $satirBasi = $metin.LastIndexOf("`n", [Math]::Max(0, $eslesme.Index - 1)) + 1
        $girinti = $metin.Substring($satirBasi, $eslesme.Index - $satirBasi)
        $marker = "$CROWN_META_MARKER_ONEK$kod -->"
        $yeniParca = $yeniEtiket + "`n" + $girinti + $marker
        $metin = $metin.Substring(0, $eslesme.Index) + $yeniParca + $metin.Substring($eslesme.Index + $eslesme.Length)
        $degisti = $true
    }

    if ($uygula -and $degisti) {
        [System.IO.File]::WriteAllText($metaPath, $metin, (New-Object System.Text.UTF8Encoding($false)))
    }
    return $true
}

function Restore-CrownMetaYonlendirme([string]$metaPath, [bool]$uygula) {
    $metin = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8
    $desen = '(?m)^([ \t]*<script\b[^>]*\bsrc\s*=\s*["'']([^"'']+)["''][^>]*>)[ \t]*\r?\n[ \t]*' + [regex]::Escape($CROWN_META_MARKER_ONEK) + '([A-Za-z0-9+/=]+)[ \t]*-->'
    $eslesmeler = [regex]::Matches($metin, $desen, 'IgnoreCase')
    if ($eslesmeler.Count -eq 0) { return $false }

    for ($i = $eslesmeler.Count - 1; $i -ge 0; $i--) {
        $m = $eslesmeler[$i]
        try { $orijinal = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($m.Groups[3].Value)) }
        catch { continue }
        if ($orijinal -match '(?:^|/)\.\.(?:/|$)') { continue }

        $etiket = $m.Groups[1].Value
        $src = [regex]::Match($etiket, '\bsrc\s*=\s*(["''])([^"'']+)(["''])', 'IgnoreCase')
        if (-not $src.Success) { continue }
        $goreliIndex = $src.Groups[2].Index
        $yeniEtiket = $etiket.Substring(0, $goreliIndex) + $orijinal + $etiket.Substring($goreliIndex + $src.Groups[2].Length)
        $metin = $metin.Substring(0, $m.Index) + $yeniEtiket + $metin.Substring($m.Index + $m.Length)
    }

    if ($uygula) {
        [System.IO.File]::WriteAllText($metaPath, $metin, (New-Object System.Text.UTF8Encoding($false)))
    }
    return $true
}

function Remove-UretilenCrownDosyalari([string]$dizin, [bool]$uygula) {
    $bulundu = $false
    foreach ($f in Get-ChildItem -LiteralPath $dizin -File -Recurse -Filter "*$CROWN_URETILEN_SON_EK" -ErrorAction SilentlyContinue) {
            $metin = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if (-not $metin.StartsWith($CROWN_MARKER_ONEK)) { continue }
            $bulundu = $true
            if ($uygula) { Remove-Item -LiteralPath $f.FullName -Force }
    }
    return $bulundu
}

function Test-CrownDagitimGuncel([object[]]$ogeler) {
    foreach ($oge in $ogeler) {
        if (-not (Test-Path -LiteralPath $oge.HedefTam -PathType Leaf)) { return $false }
        $metin = Get-Content -LiteralPath $oge.HedefTam -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if (-not $metin -or (Get-MetinHash $metin) -ne $oge.TemizHash) { return $false }
    }
    return $true
}

function Test-UyumsuzDebugHookKorumalari([object[]]$hedefler) {
    $sonuc = @()
    foreach ($h in $hedefler) {
        foreach ($f in Get-ChildItem -LiteralPath $h.Dizin -File -Recurse -Filter *.lua -ErrorAction SilentlyContinue) {
            $goreli = $f.FullName.Substring($h.Dizin.Length).TrimStart([char[]]@('\', '/'))
            if (Test-CrownKorumaYolu $h.Crown $goreli) { continue }
            $icerik = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $icerik) { continue }

            $preFunction = $icerik -match 'addDebugHook\s*\(\s*["'']preFunction["'']'
            $addDebugHookHedefi = $icerik -match 'functionName\s*==\s*["'']addDebugHook["'']'
            $engelliyor = $icerik -match 'return\s+["'']skip["'']'
            if ($preFunction -and $addDebugHookHedefi -and $engelliyor) {
                $sonuc += [pscustomobject]@{ Resource = $h.Ad; Dosya = $goreli }
            }
        }
    }
    return $sonuc
}

function Test-GlobalSarmalayiciCakismalari([object[]]$hedefler) {
    $sonuc = @()
    $clientFonksiyonlari = @('triggerServerEvent', 'triggerLatentServerEvent', 'addEvent')
    $serverFonksiyonlari = @(
        'addEvent', 'addEventHandler', 'removeEventHandler',
        'triggerClientEvent', 'triggerLatentClientEvent',
        'setElementPosition', 'cancelEvent', 'wasEventCancelled', 'getCancelReason'
    )

    foreach ($h in $hedefler) {
        $resourceRoot = [System.IO.Path]::GetFullPath($h.Dizin).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        foreach ($script in $h.Scripts) {
            if (-not $script.src) { continue }
            $goreli = ('' + $script.src).Replace('\', '/')
            if ($goreli -match '(?i)(^|/)\.amcaoglu/' -or (Test-CrownKorumaYolu $h.Crown $goreli) -or [System.IO.Path]::GetExtension($goreli) -ine '.lua') { continue }

            try { $tam = [System.IO.Path]::GetFullPath((Join-Path $h.Dizin ($goreli -replace '/', '\'))) }
            catch { continue }
            if (-not $tam.StartsWith($resourceRoot, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $tam -PathType Leaf)) { continue }

            $icerik = Get-Content -LiteralPath $tam -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if (-not $icerik) { continue }
            $tur = ('' + $script.type).ToLower()
            $adaylar = @()
            if ($tur -eq 'client' -or $tur -eq 'shared') { $adaylar += $clientFonksiyonlari }
            if ($tur -eq 'server' -or $tur -eq 'shared' -or $tur -eq '') { $adaylar += $serverFonksiyonlari }

            $bulunan = @()
            foreach ($ad in $adaylar | Select-Object -Unique) {
                $desen = '(?m)^[ \t]*(?:function[ \t]+' + [regex]::Escape($ad) + '[ \t]*\(|' + [regex]::Escape($ad) + '[ \t]*=)'
                if ([regex]::IsMatch($icerik, $desen)) { $bulunan += $ad }
            }
            if ($bulunan.Count -gt 0) {
                $sonuc += [pscustomobject]@{
                    Resource = $h.Ad
                    Dosya = $goreli
                    Fonksiyonlar = ($bulunan -join ', ')
                }
            }
        }
    }
    return $sonuc
}

function Get-CrownNotu($crown) {
    if (-not $crown.Var) { return '' }
    if (-not $crown.MetadaVar) { return 'crown klasoru var ama meta.xml bundle yuklemiyor' }
    if ($crown.OncekiScript) { return 'crown tespit edildi, crown ONCESINDE baska script var' }
    return 'crown tespit edildi'
}

function Get-HedefResourceler {
    $hedefler = @()
    $gorulenDizinler = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $resourcesRoot = [System.IO.Path]::GetFullPath($resourcesDir).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $guardRoot = [System.IO.Path]::GetFullPath($guardDir).TrimEnd('\', '/')

    foreach ($metaDosyasi in Get-ChildItem -LiteralPath $resourcesDir -File -Recurse -Filter 'meta.xml' -ErrorAction SilentlyContinue) {
        $dir = $metaDosyasi.Directory
        $tamDizin = [System.IO.Path]::GetFullPath($dir.FullName).TrimEnd('\', '/')
        if (-not (($tamDizin + [System.IO.Path]::DirectorySeparatorChar).StartsWith($resourcesRoot, [System.StringComparison]::OrdinalIgnoreCase))) { continue }
        if ($tamDizin -eq $guardRoot -or $tamDizin.StartsWith($guardRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        if (-not $gorulenDizinler.Add($tamDizin)) { continue }
        $metaPath = $metaDosyasi.FullName

        $ad = $dir.Name
        if ($ad -eq $GUARD_RESOURCE) { continue }
        if ($Sadece.Count -gt 0 -and $Sadece -notcontains $ad) { continue }
        if ($Haric -contains $ad) { continue }

        $scripts = Get-MetaScripts $metaPath
        if ($null -eq $scripts) {
            Yaz "  ! $ad : meta.xml okunamadi, atlandi" 'Yellow'
            continue
        }
        if (@($scripts | Where-Object { $_.src }).Count -eq 0) { continue }

        $metaMetin = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8

        $hedefler += [pscustomobject]@{
            Ad       = $ad
            Dizin    = $dir.FullName
            MetaPath = $metaPath
            Scripts  = $scripts
            Crown    = (Get-CrownBilgisi $dir.FullName $metaMetin)
        }
    }
    return $hedefler
}

function Test-EventCakismasi([object[]]$hedefler) {
    $sahipler   = @{}
    $taranamayan = @()

    foreach ($h in $hedefler) {
        $luaSayisi  = 0
        $luacSayisi = 0

        foreach ($f in Get-ChildItem -LiteralPath $h.Dizin -Recurse -File -ErrorAction SilentlyContinue) {
            if ($f.Extension -eq '.luac') { $luacSayisi++; continue }
            if ($f.Extension -ne '.lua') { continue }
            $luaSayisi++

            $icerik = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $icerik) { continue }
            foreach ($m in [regex]::Matches($icerik, 'addEvent\s*\(\s*["'']([^"'']+)["'']\s*,\s*true')) {
                $ad = $m.Groups[1].Value
                if (-not $sahipler.ContainsKey($ad)) { $sahipler[$ad] = New-Object System.Collections.Generic.HashSet[string] }
                [void]$sahipler[$ad].Add($h.Ad)
            }
        }

        if ($luaSayisi -eq 0 -and $luacSayisi -gt 0) { $taranamayan += $h.Ad }
    }

    $cakisan = @()
    foreach ($ad in $sahipler.Keys) {
        if ($sahipler[$ad].Count -gt 1) {
            $cakisan += [pscustomobject]@{ Event = $ad; Resourceler = ($sahipler[$ad] -join ', ') }
        }
    }

    return [pscustomobject]@{
        Cakisan     = $cakisan
        Taranamayan = $taranamayan
    }
}

function Get-ClientDataAnahtarlari([object[]]$hedefler) {
    $anahtarlar = New-Object System.Collections.Generic.HashSet[string]
    $dinamik = New-Object System.Collections.Generic.HashSet[string]
    $taranamayan = @()

    foreach ($h in $hedefler) {
        $clientYollari = New-Object System.Collections.Generic.HashSet[string]
        foreach ($s in $h.Scripts) {
            if (-not $s.src) { continue }
            $tur = ('' + $s.type).ToLower()
            if ($tur -eq 'client' -or $tur -eq 'shared') {
                [void]$clientYollari.Add(($s.src -replace '\\', '/').ToLower())
            }
        }

        foreach ($f in @(Get-ChildItem -LiteralPath $h.Dizin -Recurse -File -Filter '*.lua' -ErrorAction SilentlyContinue)) {
            $goreli = $f.FullName.Substring($h.Dizin.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/'
            $kucuk = $goreli.ToLower()
            if ($kucuk -match '(^|/)\.amcaoglu/' -or (Test-CrownKorumaYolu $h.Crown $goreli)) { continue }
            if ($kucuk -match '(^|/)client(?:/|[^/]*\.lua$)') {
                [void]$clientYollari.Add($kucuk)
            }
        }
        if ($clientYollari.Count -eq 0) { continue }

        $derlenmisVar = $false
        foreach ($yol in $clientYollari) {
            $tam = Join-Path $h.Dizin ($yol -replace '/', '\')
            if (-not (Test-Path -LiteralPath $tam -PathType Leaf)) { continue }
            if ([System.IO.Path]::GetExtension($tam) -eq '.luac') {
                $kaynakEs = [System.IO.Path]::ChangeExtension($tam, '.lua')
                if (Test-Path -LiteralPath $kaynakEs -PathType Leaf) {
                    $tam = $kaynakEs
                } else {
                    $derlenmisVar = $true
                    continue
                }
            }

            $icerik = Get-Content -LiteralPath $tam -Raw -ErrorAction SilentlyContinue
            if (-not $icerik) { continue }
            foreach ($m in [regex]::Matches($icerik, 'setElementData\s*\(\s*[^,]+,\s*["'']([^"'']+)["'']')) {
                [void]$anahtarlar.Add($m.Groups[1].Value)
            }
            foreach ($m in [regex]::Matches($icerik, '[:\.]setData\s*\(\s*["'']([^"'']+)["'']')) {
                [void]$anahtarlar.Add($m.Groups[1].Value)
            }
            if ([regex]::IsMatch($icerik, 'setElementData\s*\(\s*[^,]+,\s*[^"''\s]') `
                -or [regex]::IsMatch($icerik, '[:\.]setData\s*\(\s*[^"''\s]')) {
                $goreliKaynak = $tam.Substring($h.Dizin.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/'
                [void]$dinamik.Add("$($h.Ad)/$goreliKaynak")
            }
        }
        if ($derlenmisVar) { $taranamayan += $h.Ad }
    }

    return [pscustomobject]@{
        Anahtarlar  = (@($anahtarlar) | Sort-Object)
        Dinamik     = (@($dinamik) | Sort-Object)
        Taranamayan = $taranamayan
    }
}

function Get-ServerDataAnahtarlari([object[]]$hedefler) {
    $anahtarlar = New-Object System.Collections.Generic.HashSet[string]
    $dinamik = New-Object System.Collections.Generic.HashSet[string]
    $taranamayan = @()

    foreach ($h in $hedefler) {
        $serverYollari = New-Object System.Collections.Generic.HashSet[string]
        foreach ($s in $h.Scripts) {
            if (-not $s.src) { continue }
            $tur = ('' + $s.type).ToLower()
            if ($tur -eq '') { $tur = 'server' }
            if ($tur -eq 'server') {
                [void]$serverYollari.Add(($s.src -replace '\\', '/').ToLower())
            }
        }
        if ($serverYollari.Count -eq 0) { continue }

        $derlenmisVar = $false
        foreach ($yol in $serverYollari) {
            $tam = Join-Path $h.Dizin ($yol -replace '/', '\')
            if (-not (Test-Path -LiteralPath $tam -PathType Leaf)) { continue }
            if ([System.IO.Path]::GetExtension($tam) -eq '.luac') {
                $kaynakEs = [System.IO.Path]::ChangeExtension($tam, '.lua')
                if (Test-Path -LiteralPath $kaynakEs -PathType Leaf) {
                    $tam = $kaynakEs
                } else {
                    $derlenmisVar = $true
                    continue
                }
            }

            $icerik = Get-Content -LiteralPath $tam -Raw -ErrorAction SilentlyContinue
            if (-not $icerik) { continue }

            foreach ($m in [regex]::Matches($icerik, 'setElementData\s*\(\s*[^,]+,\s*["'']([^"'']+)["'']\s*\.\.')) {
                [void]$dinamik.Add($m.Groups[1].Value)
            }
            foreach ($m in [regex]::Matches($icerik, 'setElementData\s*\(\s*[^,]+,\s*["'']([^"'']+)["'']\s*,')) {
                [void]$anahtarlar.Add($m.Groups[1].Value)
            }
        }
        if ($derlenmisVar) { $taranamayan += $h.Ad }
    }

    return [pscustomobject]@{
        Anahtarlar  = (@($anahtarlar) | Sort-Object)
        Dinamik     = (@($dinamik) | Sort-Object)
        Taranamayan = $taranamayan
    }
}

function Find-LuaAtama([string]$metin, [string]$ad) {
    $desen = [regex]::Escape($ad) + '\s*=\s*\{'
    foreach ($m in [regex]::Matches($metin, $desen)) {
        $satirBasi = $metin.LastIndexOf("`n", $m.Index) + 1
        $onEk = $metin.Substring($satirBasi, $m.Index - $satirBasi)
        if ($onEk -notmatch '--') { return $m }
    }
    return $null
}

function Get-LuaListesi([string]$metin, [string]$ad) {
    $bas = Find-LuaAtama $metin $ad
    if ($null -eq $bas) { return @() }

    $derinlik = 0
    $sonuc = @()
    for ($i = $bas.Index + $bas.Length - 1; $i -lt $metin.Length; $i++) {
        $c = $metin[$i]
        if ($c -eq '{') { $derinlik++ }
        elseif ($c -eq '}') { $derinlik--; if ($derinlik -eq 0) { break } }
    }
    $govde = $metin.Substring($bas.Index + $bas.Length, $i - ($bas.Index + $bas.Length))
    foreach ($m in [regex]::Matches($govde, '["'']([^"'']+)["'']')) { $sonuc += $m.Groups[1].Value }
    return $sonuc
}

function Set-SerbestAnahtarlar([string]$configPath, [string[]]$anahtarlar, [bool]$uygula) {
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        return [pscustomobject]@{ Durum = 'config-yok'; Eklenen = @(); Atlanan = @(); Degisti = $false }
    }

    $metin = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
    $bas = Find-LuaAtama $metin 'serbestAnahtarlar'
    if ($null -eq $bas) {
        return [pscustomobject]@{ Durum = 'anahtar-yok'; Eklenen = @(); Atlanan = @(); Degisti = $false }
    }

    $korumali = @(Get-LuaListesi $metin 'korumaliAnahtarlar')
    $onEkler  = @(Get-LuaListesi $metin 'korumaliOnEkler')

    $eklenen = @()
    $atlanan = @()
    foreach ($a in $anahtarlar) {
        $carpisti = $korumali -contains $a
        if (-not $carpisti) {
            foreach ($p in $onEkler) { if ($a.StartsWith($p)) { $carpisti = $true; break } }
        }
        if ($carpisti) { $atlanan += $a } else { $eklenen += $a }
    }

    $derinlik = 0
    for ($i = $bas.Index + $bas.Length - 1; $i -lt $metin.Length; $i++) {
        $c = $metin[$i]
        if ($c -eq '{') { $derinlik++ }
        elseif ($c -eq '}') { $derinlik--; if ($derinlik -eq 0) { break } }
    }

    $satirlar = @('')
    $satirlar += "        -- kur.ps1 tarafindan uretildi: client script'lerinde setElementData ile"
    $satirlar += "        -- yazildigi tespit edilen anahtarlar. Elle duzenleyebilirsiniz; kurulum"
    $satirlar += "        -- tekrar calistirilirsa bu blok yeniden uretilir."
    foreach ($a in $eklenen) { $satirlar += ('        "{0}",' -f ($a -replace '"', '\"')) }
    $satirlar += '    '
    $yeniGovde = ($satirlar -join "`n")

    $yeni = $metin.Substring(0, $bas.Index + $bas.Length) + $yeniGovde + $metin.Substring($i)
    $degisti = $yeni -ne $metin
    if ($uygula -and $degisti) {
        [System.IO.File]::WriteAllText($configPath, $yeni, (New-Object System.Text.UTF8Encoding($false)))
    }

    return [pscustomobject]@{ Durum = 'tamam'; Eklenen = $eklenen; Atlanan = $atlanan; Degisti = $degisti }
}

function Set-SunucuVeriAnahtarlari([string]$configPath, [string[]]$anahtarlar, [bool]$uygula) {
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        return [pscustomobject]@{ Durum = 'config-yok'; Eklenen = @(); Atlanan = @(); Degisti = $false }
    }

    $metin = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
    $bas = Find-LuaAtama $metin 'sunucuVeriAnahtarlari'
    if ($null -eq $bas) {
        return [pscustomobject]@{ Durum = 'anahtar-yok'; Eklenen = @(); Atlanan = @(); Degisti = $false }
    }

    $serbest  = @(Get-LuaListesi $metin 'serbestAnahtarlar')
    $korumali = @(Get-LuaListesi $metin 'korumaliAnahtarlar')
    $onEkler  = @(Get-LuaListesi $metin 'korumaliOnEkler')

    $eklenen = @()
    $atlanan = @()
    foreach ($a in $anahtarlar) {
        if ($serbest -contains $a) { $atlanan += $a; continue }
        if ($korumali -contains $a) { $atlanan += $a; continue }
        $onEkKapsiyor = $false
        foreach ($p in $onEkler) { if ($a.StartsWith($p)) { $onEkKapsiyor = $true; break } }
        if ($onEkKapsiyor) { $atlanan += $a; continue }
        $eklenen += $a
    }

    $derinlik = 0
    for ($i = $bas.Index + $bas.Length - 1; $i -lt $metin.Length; $i++) {
        $c = $metin[$i]
        if ($c -eq '{') { $derinlik++ }
        elseif ($c -eq '}') { $derinlik--; if ($derinlik -eq 0) { break } }
    }

    $satirlar = @('')
    $satirlar += "        -- kur.ps1 tarafindan uretildi: meta.xml'e gore SERVER script'lerinde"
    $satirlar += "        -- setElementData ile yazildigi tespit edilen anahtarlar. Client'in"
    $satirlar += "        -- yazdigi anahtarlar bu listeye alinmaz. Kurulum tekrar"
    $satirlar += "        -- calistirilirsa bu blok yeniden uretilir."
    foreach ($a in $eklenen) { $satirlar += ('        "{0}",' -f ($a -replace '"', '\"')) }
    $satirlar += '    '
    $yeniGovde = ($satirlar -join "`n")

    $yeni = $metin.Substring(0, $bas.Index + $bas.Length) + $yeniGovde + $metin.Substring($i)
    $degisti = $yeni -ne $metin
    if ($uygula -and $degisti) {
        [System.IO.File]::WriteAllText($configPath, $yeni, (New-Object System.Text.UTF8Encoding($false)))
    }

    return [pscustomobject]@{ Durum = 'tamam'; Eklenen = $eklenen; Atlanan = $atlanan; Degisti = $degisti }
}

function Set-LuaBoolean([string]$configPath, [string]$ad, [bool]$deger, [bool]$uygula) {
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        return [pscustomobject]@{ Durum = 'config-yok'; Degisti = $false; Deger = $deger }
    }
    $metin = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
    $desen = '(?m)^(\s*)' + [regex]::Escape($ad) + '(\s*=\s*)(true|false)(\s*,)'
    $eslesme = [regex]::Match($metin, $desen)
    if (-not $eslesme.Success) {
        return [pscustomobject]@{ Durum = 'anahtar-yok'; Degisti = $false; Deger = $deger }
    }

    $yeniDeger = if ($deger) { 'true' } else { 'false' }
    $yeni = $metin.Substring(0, $eslesme.Groups[3].Index) + $yeniDeger + $metin.Substring($eslesme.Groups[3].Index + $eslesme.Groups[3].Length)
    $degisti = $yeni -ne $metin
    if ($uygula -and $degisti) {
        [System.IO.File]::WriteAllText($configPath, $yeni, (New-Object System.Text.UTF8Encoding($false)))
    }
    return [pscustomobject]@{ Durum = 'tamam'; Degisti = $degisti; Deger = $deger }
}

function Get-BasBlogu([bool]$includeEkle = $true) {
    $satirlar = @($MARKER_BEGIN)
    if ($includeEkle) { $satirlar += "    <include resource=`"$GUARD_RESOURCE`" />" }
    $satirlar += "    <script src=`"$SHIM_DIR/transport_server.lua`" type=`"server`" />"
    $satirlar += "    <script src=`"$SHIM_DIR/transport_client.lua`" type=`"client`" cache=`"false`" />"
    $satirlar += $MARKER_END
    return $satirlar -join "`n"
}

function Get-SonBlok {
    return @(
        $MARKER_BEGIN,
        "    <export function=`"dispatchProtectedEvent`" type=`"server`" />",
        $MARKER_END
    ) -join "`n"
}

function Remove-ShimSatirlari([string]$metin) {
    $desen = '\r?\n?[ \t]*' + [regex]::Escape($MARKER_BEGIN) + '.*?' + [regex]::Escape($MARKER_END) + '[ \t]*\r?\n?'
    return [regex]::Replace($metin, $desen, "`n", 'Singleline')
}

function Add-Blok([string]$metin, [int]$konum, [string]$blok) {
    $oncesi  = $metin.Substring(0, $konum)
    $sonrasi = $metin.Substring($konum)

    $satirBasi = $oncesi.LastIndexOf("`n") + 1
    $sonSatir  = $oncesi.Substring($satirBasi)

    if ($sonSatir -match '^[ \t]*$') {
        return $oncesi.Substring(0, $satirBasi) + $blok + "`n" + $sonSatir + $sonrasi
    }

    return $oncesi + "`n" + $blok + "`n" + $sonrasi
}

function Set-MetaShim([string]$metaPath, [bool]$crownOnceYuklensin = $false, [string]$crownSrc = '') {
    $metin = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8
    $metin = Remove-ShimSatirlari $metin
    $guardZatenDahil = [regex]::IsMatch($metin, '<include\b[^>]*\bresource\s*=\s*["'']' + [regex]::Escape($GUARD_RESOURCE) + '["''][^>]*/\s*>', 'IgnoreCase')

    $ilk = [regex]::Match($metin, '<script\b')
    if (-not $ilk.Success) { return $false }

    $konum = $ilk.Index
    if ($crownOnceYuklensin) {
        $crown = $null
        foreach ($m in [regex]::Matches($metin, $CROWN_SCRIPT_DESEN, 'IgnoreCase')) {
            if ($m.Groups[1].Value.Replace('\', '/') -ieq $crownSrc) { $crown = $m; break }
        }
        if ($null -ne $crown -and $crown.Success) {
            $konum = $crown.Index + $crown.Length
            $satirSonu = $metin.IndexOf("`n", $konum)
            if ($satirSonu -ge 0) { $konum = $satirSonu + 1 }
        }
    }

    $metin = Add-Blok $metin $konum (Get-BasBlogu (-not $guardZatenDahil))

    $kapanis = [regex]::Match($metin, '</meta\s*>')
    if ($kapanis.Success) {
        $yeni = Add-Blok $metin $kapanis.Index (Get-SonBlok)
    } else {
        $yeni = $metin.TrimEnd() + "`n" + (Get-SonBlok) + "`n"
    }
    $yeni = Set-MetaMinimumVersionText $yeni
    [System.IO.File]::WriteAllText($metaPath, $yeni, (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

Yaz ""
Yaz "  amcaoglu_anticheat $KURUCU_SURUMU - korumali transport kurulumu" 'Cyan'
Yaz "  resources: $(if ($resourcesDir) { $resourcesDir } else { '(bulunamadi)' })"
Yaz ""

if (-not $resourcesDir -or -not (Test-Path -LiteralPath $resourcesDir)) {
    Yaz "  HATA: resources klasoru bulunamadi." 'Red'
    Yaz "  amcaoglu_anticheat sunucunun resources klasorune kopyalanmis olmali;" 'Red'
    Yaz "  bu betik oradaki kurulum/ klasorunden calistirilir." 'Red'
    exit 1
}
foreach ($gerekli in @('transport_server.lua', 'transport_client.lua')) {
    if (-not (Test-Path -LiteralPath (Join-Path $sablonDir $gerekli))) {
        Yaz "  HATA: sablon eksik -> kurulum/sablon/$gerekli" 'Red'
        exit 1
    }
}

$hedefler = Get-HedefResourceler
Yaz "  Hedef resource sayisi: $(@($hedefler).Count)"

$crownlu = @($hedefler | Where-Object { $_.Crown.Var })
if ($crownlu.Count -gt 0) {
    Yaz "  Crown bundle tespit edilen resource: $($crownlu.Count)" 'Cyan'
}
Yaz ""

if ($GeriAl) {
    $temizlenen = 0
    foreach ($h in $hedefler) {
        $shimPath   = Join-Path $h.Dizin $SHIM_DIR
        $dokunuldu  = $false

        if (Restore-CrownMetaYonlendirme $h.MetaPath ([bool]$Uygula)) { $dokunuldu = $true }
        if (Remove-UretilenCrownDosyalari $h.Dizin ([bool]$Uygula)) { $dokunuldu = $true }

        if (Test-Path -LiteralPath $shimPath) {
            if ($Uygula) { Remove-Item -LiteralPath $shimPath -Recurse -Force }
            $dokunuldu = $true
        }

        $metin = Get-Content -LiteralPath $h.MetaPath -Raw -Encoding UTF8
        if ($metin -match [regex]::Escape($MARKER_BEGIN)) {
            if ($Uygula) {
                $geri = (Remove-ShimSatirlari $metin).TrimStart("`r", "`n")
                [System.IO.File]::WriteAllText($h.MetaPath, $geri, (New-Object System.Text.UTF8Encoding($false)))
            }
            $dokunuldu = $true
        }

        if (Restore-CrownKlasoru $h.Dizin ([bool]$Uygula)) { $dokunuldu = $true }

        if ($dokunuldu) { $temizlenen++; Yaz "  - $($h.Ad)" }
    }

    Yaz ""
    if ($Uygula) {
        Yaz "  $temizlenen resource geri alindi." 'Green'

        $kalan = 0
        foreach ($h in $hedefler) {
            foreach ($f in Get-ChildItem -LiteralPath $h.Dizin -File -Recurse -Filter *.lua -ErrorAction SilentlyContinue) {
                    if ($f.FullName -match '(?i)[\\/]\.amcaoglu[\\/]') { continue }
                    $m = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
                    if ($m -and $m.StartsWith($CROWN_MARKER_ONEK)) { $kalan++ }
            }
        }

        if (Test-Path -LiteralPath $CROWN_YEDEK_DIR) {
            if ($kalan -eq 0) {
                Remove-Item -LiteralPath $CROWN_YEDEK_DIR -Recurse -Force
            } else {
                Yaz "  $kalan bundle hala temizlenmis durumda, yedekler kurulum/yedek/ altinda tutuluyor." 'Yellow'
            }
        }
    }
    else { Yaz "  $temizlenen resource geri alinacak. Uygulamak icin: .\kur.ps1 -GeriAl -Uygula" 'Yellow' }
    exit 0
}

Yaz "  Event adi cakismasi kontrol ediliyor..." 'DarkGray'
$tarama = Test-EventCakismasi $hedefler
if ($tarama.Cakisan.Count -gt 0) {
    Yaz "  $($tarama.Cakisan.Count) event adi birden fazla resource'ta tanimli." 'DarkGray'
    Yaz "  Korumali kanal bunu MTA gibi ele alir: paket kayitli butun" 'DarkGray'
    Yaz "  resource'lara dagitilir, hicbiri sessizce dusmez." 'DarkGray'
    foreach ($c in $tarama.Cakisan | Sort-Object Event) {
        Yaz ("    - {0}: {1}" -f $c.Event, $c.Resourceler) 'DarkGray'
    }
} else {
    Yaz "  Cakisma yok." 'DarkGray'
}
if ($tarama.Taranamayan.Count -gt 0) {
    Yaz "  NOT: $($tarama.Taranamayan.Count) resource derlenmis (.luac), event adlari okunamadi." 'Yellow'
    Yaz "  Bunlar icin cakisma taramasi bir sey soylemiyor: $($tarama.Taranamayan -join ', ')" 'DarkGray'
}
Yaz ""

$globalCakismalar = @(Test-GlobalSarmalayiciCakismalari $hedefler)
if ($globalCakismalar.Count -gt 0) {
    Yaz "  UYUMSUZ GLOBAL SARMALAYICI TESPIT EDILDI" 'Red'
    Yaz "  Bu resource'lar MTA transport fonksiyonlarini kendileri degistiriyor." 'Red'
    Yaz "  Kurucu paket adina bakarak tahmin yapmaz; kodu ezip sistemi bozmak" 'Red'
    Yaz "  yerine dosyayi ve cakisan fonksiyonu nokta atisi raporlar:" 'Red'
    foreach ($u in $globalCakismalar) {
        Yaz ("    - {0}: {1} [{2}]" -f $u.Resource, $u.Dosya, $u.Fonksiyonlar) 'Yellow'
    }
    Yaz ""
    if ($Uygula -and -not $UyumsuzKorumayiOnayla) {
        Yaz "  HATA: Guvenli kurulum durduruldu; hicbir dosya degistirilmedi." 'Red'
        exit 2
    }
}

$uyumsuzKorumalar = @(Test-UyumsuzDebugHookKorumalari $hedefler)
if ($uyumsuzKorumalar.Count -gt 0) {
    Yaz "  UYUMSUZ ESKI KORUMA TESPIT EDILDI" 'Red'
    Yaz "  Asagidaki kod, diger resource'larin addDebugHook kayitlarini global" 'Red'
    Yaz "  olarak engelleyebilir; amcaoglu_anticheat'in injector ve native" 'Red'
    Yaz "  korumalarinin bir bolumunu calisamaz hale getirir:" 'Red'
    foreach ($u in $uyumsuzKorumalar) {
        Yaz ("    - {0}: {1}" -f $u.Resource, $u.Dosya) 'Yellow'
    }
    Yaz "  Bu eski korumayi baslatmayin/kaldirin. Dosya pakette bilerek kapali" 'Yellow'
    Yaz "  tutulacaksa kurulumu -UyumsuzKorumayiOnayla ile acikca onaylayin." 'Yellow'
    Yaz ""

    if ($Uygula -and -not $UyumsuzKorumayiOnayla) {
        Yaz "  HATA: Guvenli kurulum durduruldu; hicbir dosya degistirilmedi." 'Red'
        exit 2
    }
}

$kurulan = 0
$atlanan = 0
$guncel = 0
$crownTemizlenen = 0

$crownDagitim = Get-CrownDagitimPlani $hedefler
$gecerliCrownOgeleri = @()
if ($crownDagitim.Ogeler.Count -gt 0) {
    foreach ($metaGrubu in $crownDagitim.Ogeler | Group-Object MetaPath) {
        if (-not (Set-CrownMetaYonlendirme $metaGrubu.Name @($metaGrubu.Group) $false)) {
            $crownDagitim.Hatalar += ("{0}: meta.xml yonlendirmesi dogrulanamadi" -f $metaGrubu.Group[0].Resource)
        } else {
            $gecerliCrownOgeleri += @($metaGrubu.Group)
        }
    }
}
$crownDagitim.Ogeler = @($gecerliCrownOgeleri)
$crownDagitimAktif = $crownDagitim.Ogeler.Count -gt 0
if ($crownDagitimAktif) {
    Yaz "  Crown kaynak analizi: $($crownDagitim.Ogeler.Count) aktif bundle," 'Cyan'
    Yaz "  $($crownDagitim.VaryantSayisi) benzersiz varyant. Her varyant yalniz bir kez temizlenecek." 'Cyan'
    Yaz "  Orijinal .lua/.luac dosyalari korunup uretilen temiz kopyalara yonlendirilecek." 'DarkGray'
    Yaz ""
}
if ($crownDagitim.Hatalar.Count -gt 0) {
    Yaz "  BAZI KORUMA BUNDLE'LARI TEMIZLENEMEDI" 'Yellow'
    Yaz "  Kaynagi dogrulanan resource'lar kurulacak; asagidakiler diger" 'Yellow'
    Yaz "  resource'larin donusumunu artik durdurmayacak." 'DarkGray'
    foreach ($hata in $crownDagitim.Hatalar) { Yaz "    - $hata" 'DarkGray' }
    Yaz ""
}

foreach ($h in $hedefler) {
    $shimPath  = Join-Path $h.Dizin $SHIM_DIR
    $crownNotu = Get-CrownNotu $h.Crown
    $crownOgeleri = @($crownDagitim.Ogeler | Where-Object { $_.MetaPath -eq $h.MetaPath })
    $crownIslenebilir = $crownOgeleri.Count -gt 0
    $crownOnceYuklensin = -not $crownIslenebilir -and $h.Crown.MetadaVar
    $crownSrc = if ($h.Crown.ScriptYollari.Count -gt 0) { $h.Crown.ScriptYollari[0] } else { '' }
    if ($crownIslenebilir) {
        $crownNotu = "$crownNotu, ortak temiz varyanta yonlendirilecek"
    } elseif ($h.Crown.MetadaVar) {
        $crownNotu = "$crownNotu, kaynak temizlenemedigi icin korundu"
    }
    $kurulumGuncel = (Test-ShimGuncel $h.Dizin) `
        -and (Test-MetaShimGuncel $h.MetaPath $crownOnceYuklensin $crownSrc) `
        -and (-not $crownIslenebilir -or (Test-CrownDagitimGuncel $crownOgeleri))

    if (-not $Uygula) {
        $durum = if ($kurulumGuncel) { 'zaten guncel' } elseif (Test-Path -LiteralPath $shimPath) { 'guncellenecek' } else { 'kurulacak' }
        if ($crownNotu) { $durum = "$durum  ($crownNotu)" }
        Yaz ("  {0,-32} {1}" -f $h.Ad, $durum)
        if ($kurulumGuncel) { $guncel++ } else { $kurulan++ }
        continue
    }

    if ($kurulumGuncel) {
        $guncel++
        Yaz ("  {0,-32} zaten guncel" -f $h.Ad) 'DarkGray'
        continue
    }

    New-Item -ItemType Directory -Force -Path $shimPath | Out-Null
    foreach ($sablon in @('transport_server.lua', 'transport_client.lua')) {
        Copy-Item -LiteralPath (Join-Path $sablonDir $sablon) -Destination (Join-Path $shimPath $sablon) -Force
    }

    if ($crownIslenebilir) {
        foreach ($oge in $crownOgeleri) {
            [System.IO.File]::WriteAllText($oge.HedefTam, $oge.Metin, (New-Object System.Text.UTF8Encoding($false)))
        }
        if (-not (Set-CrownMetaYonlendirme $h.MetaPath $crownOgeleri $true)) {
            throw "Crown meta.xml yonlendirmesi uygulanamadi: $($h.Ad)"
        }
        $crownTemizlenen += $crownOgeleri.Count
    }

    if (Set-MetaShim $h.MetaPath $crownOnceYuklensin $crownSrc) {
        $kurulan++
        $durum = 'tamam'
        if ($crownNotu) { $durum = "tamam  ($crownNotu)" }

        $renk = 'Green'
        if ($h.Crown.OncekiScript -or ($h.Crown.Var -and -not $h.Crown.MetadaVar)) { $renk = 'Yellow' }
        if ($crownTemizlik -and ($crownTemizlik.Taninmayan.Count -gt 0 -or $crownTemizlik.Derlenmis.Count -gt 0)) { $renk = 'Yellow' }
        Yaz ("  {0,-32} {1}" -f $h.Ad, $durum) $renk
    } else {
        $atlanan++
        Yaz ("  {0,-32} meta.xml'de <script> yok, atlandi" -f $h.Ad) 'Yellow'
    }
}

$veriTarama = Get-ClientDataAnahtarlari $hedefler
$serbest = Set-SerbestAnahtarlar (Join-Path $guardDir 'config.lua') $veriTarama.Anahtarlar ([bool]$Uygula)

$sunucuTarama = Get-ServerDataAnahtarlari $hedefler
$clientYazilan = New-Object System.Collections.Generic.HashSet[string]
foreach ($a in $veriTarama.Anahtarlar) { [void]$clientYazilan.Add($a) }
$sunucuyaOzel = @($sunucuTarama.Anahtarlar | Where-Object { -not $clientYazilan.Contains($_) })
$configPath = Join-Path $guardDir 'config.lua'
$sunucu = Set-SunucuVeriAnahtarlari $configPath $sunucuyaOzel ([bool]$Uygula)
$anaKoruma = Set-LuaBoolean $configPath 'elementDataKorumasi' $true ([bool]$Uygula)
$otomatikKoruma = Set-LuaBoolean $configPath 'otomatikVeriKorumasi' $true ([bool]$Uygula)
$yuksekVeriHazir = $serbest.Durum -eq 'tamam' `
    -and @($serbest.Atlanan).Count -eq 0 `
    -and @($veriTarama.Taranamayan).Count -eq 0 `
    -and @($veriTarama.Dinamik).Count -eq 0
$yuksekKoruma = if ($yuksekVeriHazir) {
    Set-LuaBoolean $configPath 'tumVerileriKoru' $true ([bool]$Uygula)
} else { $null }

Yaz ""
if ($serbest.Durum -eq 'tamam') {
    if ($Uygula) {
        if ($serbest.Degisti) {
            Yaz "  config.lua -> serbestAnahtarlar: $(@($serbest.Eklenen).Count) anahtar yazildi." 'Green'
        } else {
            Yaz "  config.lua -> serbestAnahtarlar zaten guncel ($(@($serbest.Eklenen).Count) anahtar)." 'DarkGray'
        }
    } else {
        if ($serbest.Degisti) {
            Yaz "  config.lua -> serbestAnahtarlar: $(@($serbest.Eklenen).Count) anahtar yazilacak." 'Cyan'
        } else {
            Yaz "  config.lua -> serbestAnahtarlar zaten guncel ($(@($serbest.Eklenen).Count) anahtar)." 'DarkGray'
        }
    }
    Yaz "  Bunlar client script'lerinizin kendi yazdigi anahtarlardir; beyaz liste" 'DarkGray'
    Yaz "  modunda (tumVerileriKoru = true) serbest kalmalari gerekir." 'DarkGray'

    if (@($serbest.Atlanan).Count -gt 0) {
        Yaz ""
        Yaz "  DIKKAT: su anahtarlari client YAZIYOR ama korumali listede oldugu icin" 'Yellow'
        Yaz "  serbest birakilmadilar:" 'Yellow'
        foreach ($a in $serbest.Atlanan) { Yaz "    - $a" 'Yellow' }
        Yaz "  Bu anahtarlari client'tan yazan kod artik calismayacak. Dogru cozum o" 'DarkGray'
        Yaz "  yazimi server tarafina almaktir; korumadan cikarmak degil." 'DarkGray'
    }

    if (@($veriTarama.Taranamayan).Count -gt 0) {
        Yaz ""
        Yaz "  NOT: su resource'larda derlenmis (.luac) client script var, anahtarlari" 'Yellow'
        Yaz "  okunamadi: $($veriTarama.Taranamayan -join ', ')" 'DarkGray'
        Yaz "  Beyaz liste modunu acmadan once bunlarin yazdigi anahtarlari elle ekleyin." 'DarkGray'
    }

    if (@($veriTarama.Dinamik).Count -gt 0) {
        Yaz ""
        Yaz "  NOT: su client dosyalarinda elementData adi dinamik uretiliyor:" 'Yellow'
        foreach ($d in $veriTarama.Dinamik) { Yaz "    - $d" 'DarkGray' }
        Yaz "  Dinamik adlar kesinlestirilmeden tumVerileriKoru otomatik acilmaz." 'DarkGray'
    }
} elseif ($serbest.Durum -eq 'config-yok') {
    Yaz "  NOT: config.lua bulunamadi, serbestAnahtarlar uretilmedi." 'Yellow'
} else {
    Yaz "  NOT: config.lua icinde serbestAnahtarlar bulunamadi, uretim atlandi." 'Yellow'
}

Yaz ""
if ($sunucu.Durum -eq 'tamam') {
    $fiil = if ($Uygula) { 'yazildi' } else { 'yazilacak' }
    if ($sunucu.Degisti) {
        Yaz "  config.lua -> sunucuVeriAnahtarlari: $(@($sunucu.Eklenen).Count) anahtar $fiil." 'Green'
    } else {
        Yaz "  config.lua -> sunucuVeriAnahtarlari zaten guncel ($(@($sunucu.Eklenen).Count) anahtar)." 'DarkGray'
    }
    Yaz "  Bunlar meta.xml'e gore YALNIZ server script'lerinin yazdigi anahtarlardir." 'DarkGray'
    Yaz "  Client bunlara dokunursa degisiklik geri alinir. Ceza uretmez: ayni" 'DarkGray'
    Yaz "  anahtara 3 farkli oyuncudan yazim gelirse koruma kendiliginden kalkar." 'DarkGray'

    if (@($sunucuTarama.Dinamik).Count -gt 0) {
        Yaz ""
        Yaz "  DIKKAT: su anahtarlar server'da birlestirilerek uretiliyor, tam adlari" 'Yellow'
        Yaz "  statik olarak okunamadi:" 'Yellow'
        foreach ($d in $sunucuTarama.Dinamik) { Yaz "    - $d..." 'Yellow' }
        Yaz "  Bunlari korumak icin config.lua icindeki korumaliOnEkler listesine on ek" 'DarkGray'
        Yaz "  olarak ekleyin." 'DarkGray'
    }

    if (@($sunucuTarama.Taranamayan).Count -gt 0) {
        Yaz ""
        Yaz "  NOT: su resource'larda derlenmis (.luac) server script var, anahtarlari" 'Yellow'
        Yaz "  okunamadi: $($sunucuTarama.Taranamayan -join ', ')" 'DarkGray'
        Yaz "  Bunlarin anahtarlari calisma aninda ogrenilecek." 'DarkGray'
    }
} elseif ($sunucu.Durum -eq 'anahtar-yok') {
    Yaz "  NOT: config.lua icinde sunucuVeriAnahtarlari bulunamadi, uretim atlandi." 'Yellow'
}

Yaz ""
if ($anaKoruma.Durum -eq 'tamam' -and $otomatikKoruma.Durum -eq 'tamam') {
    $kip = if ($Uygula) { 'acik' } else { 'acik olacak' }
    Yaz "  Data koruma motoru ve otomatik server-data korumasi $kip." 'Green'
}
if ($yuksekVeriHazir -and $yuksekKoruma -and $yuksekKoruma.Durum -eq 'tamam') {
    $kip = if ($Uygula) { 'ACILDI' } else { 'ACILACAK' }
    Yaz "  YUKSEK DATA KORUMASI ${kip}: tumVerileriKoru=true" 'Green'
    Yaz "  Client yalniz kurucunun dogruladigi serbestAnahtarlar listesini yazabilir." 'DarkGray'
} else {
    Yaz "  YUKSEK DATA KORUMASI OTOMATIK ACILMADI." 'Yellow'
    Yaz "  Neden: eksik/derlenmis/dinamik client data kullanimi veya korumali liste cakismasi." 'DarkGray'
    Yaz "  Mevcut kritik anahtarlar ve baska oyuncuya yazim yine kesin engellenir." 'DarkGray'
}

if ($crownTemizlenen -gt 0) {
    Yaz ""
    Yaz "  $crownTemizlenen crown bundle'indan hile koruma katmani kaldirildi." 'Green'
    Yaz "  Kaldirilanlar: loadstring kilidi, addDebugHook kisiti, istemciden" 'DarkGray'
    Yaz "  sunucuya eski gonderim, paket sayaci ve sac.punish raporlamasi." 'DarkGray'
    Yaz "  HTML/CEF uyumlulugu icin yerel event sifreleme, sunucudan istemciye" 'DarkGray'
    Yaz "  esleme ve paketin UI loadGameCode/injectHooks bootstrap'i korundu." 'DarkGray'
}

$crownKlasor = @($hedefler | Where-Object { $_.Crown.KlasorVar -and -not $_.Crown.MetadaVar })
if ($crownKlasor.Count -gt 0) {
    Yaz ""
    Yaz "  NOT: su resource'larda otomatik taninan bundle var ama meta.xml bunu yuklemiyor:" 'DarkGray'
    foreach ($h in $crownKlasor) { Yaz "    - $($h.Ad)" 'DarkGray' }
    Yaz "  Artik kullanilmayan dosya olabilir; blok normal konumuna kondu." 'DarkGray'
}

Yaz ""
if ($Uygula) {
    Yaz "  Saglik ozeti: $guncel guncel, $kurulan kuruldu/guncellendi, $atlanan atlandi." 'Green'
    Yaz ""
    Yaz "  Sunucuyu yeniden baslatin (refresh + restart yeterli degildir:" 'Yellow'
    Yaz "  meta.xml degistigi icin resource'lar bastan yuklenmelidir)." 'Yellow'
    Yaz "  Geri almak icin: .\kur.ps1 -GeriAl -Uygula" 'DarkGray'
} else {
    Yaz "  Saglik ozeti: $guncel guncel, $kurulan guncellenecek, $atlanan atlanacak." 'Cyan'
    Yaz "  Hicbir dosya degistirilmedi." 'Cyan'
    Yaz "  Uygulamak icin: .\kur.ps1 -Uygula" 'Cyan'
}
Yaz ""
