#requires -Version 5.1
<#
Starts the DenOS live ISO in a dedicated VirtualBox VM.
This script never selects or passes a physical host disk to VirtualBox.
#>
[CmdletBinding()]
param(
    [switch]$WithDisk,
    [switch]$BootInstalled
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$VmName = 'DenOS 0.1'
$ControllerName = 'DenOS SATA'
$VmRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'DenOS-VM'))
$VmDirectory = Join-Path $VmRoot $VmName
$ExpectedConfig = Join-Path $VmDirectory ($VmName + '.vbox')
$DiskPath = Join-Path $VmDirectory 'DenOS-24GB.vdi'
$IsoPath = Join-Path $PSScriptRoot 'DenOS-0.1-amd64.iso'
$ManifestPath = Join-Path $VmRoot 'launcher.json'

function Find-VBoxManage {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe')
    )
    foreach ($name in @('VBOX_MSI_INSTALL_PATH', 'VBOX_INSTALL_PATH')) {
        $location = [Environment]::GetEnvironmentVariable($name)
        if ($location) { $candidates += Join-Path $location 'VBoxManage.exe' }
    }
    $command = Get-Command 'VBoxManage.exe' -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw 'VirtualBox was not found. Install Oracle VirtualBox 7.1 or newer, then run this launcher again.'
}

function Invoke-VBox {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        # Capture native stderr so a failed command produces one useful error.
        $ErrorActionPreference = 'Continue'
        $output = @(& $script:VBoxManage @Arguments 2>&1)
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    if ($code -ne 0) {
        throw ('VirtualBox command failed: ' + $Arguments[0] + [Environment]::NewLine + (($output | Out-String).Trim()))
    }
    return @($output | ForEach-Object { $_.ToString() })
}

function ConvertFrom-VBoxInfo {
    param([string[]]$Lines)
    $result = @{}
    foreach ($line in $Lines) {
        if ($line -match '^(?:"(?<quoted>[^"\r\n]+)"|(?<plain>[^=]+))=(?<value>.*)$') {
            $key = if ($Matches['quoted']) { $Matches['quoted'] } else { $Matches['plain'] }
            $value = $Matches['value'].Trim()
            if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2).Replace('\"', '"').Replace('\\', '\')
            }
            $result[$key] = $value
        }
    }
    return $result
}

function Assert-InVmRoot {
    param([string]$Path)
    $fullPath = [IO.Path]::GetFullPath($Path)
    $prefix = $script:VmRoot.TrimEnd('\') + '\'
    if (-not $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing a VM path outside the dedicated folder: $fullPath"
    }
}

function Assert-NoReparsePoints {
    param([string]$Path)
    $currentPath = [IO.Path]::GetFullPath($Path)
    while ($currentPath -and ($currentPath -eq $script:VmRoot -or $currentPath.StartsWith($script:VmRoot + '\', [StringComparison]::OrdinalIgnoreCase))) {
        if (Test-Path -LiteralPath $currentPath) {
            $item = Get-Item -LiteralPath $currentPath -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Refusing a symbolic link or junction in the VM folder: $currentPath"
            }
        }
        $currentPath = [IO.Path]::GetDirectoryName($currentPath)
    }
}

function Save-Manifest {
    param([object]$Data)
    Assert-InVmRoot $script:ManifestPath
    Assert-NoReparsePoints $script:ManifestPath
    [IO.File]::WriteAllText($script:ManifestPath, ($Data | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
}

function Get-ManagedVmInfo {
    param([object]$Manifest)
    $info = ConvertFrom-VBoxInfo (Invoke-VBox -Arguments @('showvminfo', $Manifest.VmId, '--machinereadable'))
    if (-not $info.ContainsKey('CfgFile') -or -not $info.ContainsKey('UUID')) {
        throw 'VirtualBox did not return a machine configuration path and UUID.'
    }
    Assert-InVmRoot $info.CfgFile
    Assert-NoReparsePoints $info.CfgFile
    $actualConfig = [IO.Path]::GetFullPath($info.CfgFile)
    if ($actualConfig -ne $script:ExpectedConfig -or $info.UUID -ne $Manifest.VmId -or $info.name -ne $script:VmName) {
        throw 'The registered VM does not match this launcher and its dedicated configuration. No VM settings were changed.'
    }
    # A user may have changed an owned VM in VirtualBox Manager. Do not start
    # it with an unexpected shared folder, forwarded port, or storage medium.
    foreach ($key in @($info.Keys)) {
        if ($key -match '^SharedFolder' -or $key -match '^Forwarding\(') {
            throw 'This VM has shared folders or forwarded network ports. Remove those additions in VirtualBox Manager before using this launcher.'
        }
    }
    $controllers = @($info.Keys | Where-Object { $_ -match '^storagecontrollername\d+$' } | ForEach-Object { $info[$_] })
    if (@($controllers | Where-Object { $_ -ne $script:ControllerName }).Count -gt 0) {
        throw 'This VM has an unexpected storage controller. The launcher will not change or start it.'
    }
    $slotPattern = '^' + [regex]::Escape($script:ControllerName) + '-(?<port>\d+)-(?<device>\d+)$'
    foreach ($key in @($info.Keys)) {
        if ($key -match $slotPattern) {
            $slot = $Matches.port + '-' + $Matches.device
            $medium = $info[$key]
            if ($medium -in @('none', 'emptydrive', '')) { continue }
            $expected = if ($slot -eq '0-0') { $script:IsoPath } elseif ($slot -eq '1-0') { $script:DiskPath } else { $null }
            if (-not $expected -or [IO.Path]::GetFullPath($medium) -ne $expected) {
                throw "Unexpected attached storage in $key. The launcher will not change or start this VM."
            }
            if ($slot -eq '1-0') { Assert-NoReparsePoints $medium }
        }
    }
    return $info
}

try {
    $script:VBoxManage = Find-VBoxManage
    $version = (Invoke-VBox -Arguments @('--version')) -join ''
    if ($version -notmatch '^(?<major>\d+)\.(?<minor>\d+)' -or [int]$Matches.major -lt 7 -or ([int]$Matches.major -eq 7 -and [int]$Matches.minor -lt 1)) {
        throw "This launcher requires VirtualBox 7.1 or newer. Found: $version"
    }
    if (-not $BootInstalled -and -not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
        throw "Keep this launcher beside DenOS-0.1-amd64.iso. The ISO was not found at: $IsoPath"
    }
    Assert-NoReparsePoints $VmRoot
    $registered = @()
    foreach ($line in (Invoke-VBox -Arguments @('list', 'vms'))) {
        if ($line -match '^"(?<name>.*)" \{(?<id>[0-9a-fA-F-]+)\}$' -and $Matches.name -eq $VmName) {
            $registered += $Matches.id
        }
    }
    if ($registered.Count -gt 1) { throw 'More than one VM has the DenOS name. Resolve that conflict in VirtualBox Manager first.' }

    $firstRun = $registered.Count -eq 0
    if (-not $firstRun) {
        if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
            throw "A VM named '$VmName' already exists, but this launcher does not own it. Rename that VM in VirtualBox Manager before trying again. It has not been changed."
        }
        Assert-NoReparsePoints $ManifestPath
        $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
        if ($manifest.Schema -ne 1 -or $manifest.VmId -ne $registered[0] -or $manifest.ConfigFile -ne $ExpectedConfig) {
            throw 'The existing DenOS VM does not match the launcher ownership file. It has not been changed.'
        }
    }
    else {
        if ($BootInstalled) { throw 'No DenOS VM exists yet. Start the live ISO and install to its optional virtual disk first.' }
        if (Test-Path -LiteralPath $VmRoot) {
            if (@(Get-ChildItem -LiteralPath $VmRoot -Force).Count -gt 0) {
                throw "The dedicated folder is not empty but no matching VM is registered: $VmRoot. Add its existing .vbox file in VirtualBox Manager, or choose a fresh folder for these launcher files. Nothing was overwritten."
            }
        }
        else { $null = New-Item -ItemType Directory -Path $VmRoot }
        Assert-InVmRoot $ExpectedConfig
        Assert-NoReparsePoints $ExpectedConfig
        $manifest = [pscustomobject]@{
            Schema = 1
            VmId = [guid]::NewGuid().ToString()
            ConfigFile = $ExpectedConfig
            DiskRequested = [bool]$WithDisk
        }
        Save-Manifest $manifest
        Write-Host 'Creating the dedicated DenOS virtual machine...'
        $null = Invoke-VBox -Arguments @('createvm', '--name', $VmName, '--platform-architecture', 'x86', '--ostype', 'Debian_64', '--basefolder', $VmRoot, '--uuid', $manifest.VmId, '--register')
    }

    $info = Get-ManagedVmInfo $manifest
    if ($info.VMState -eq 'running') {
        Write-Host 'DenOS is already running. Open its existing VirtualBox window.'
        exit 0
    }
    if ($info.VMState -notin @('poweroff', 'aborted')) {
        throw "DenOS is in state '$($info.VMState)'. Shut it down in VirtualBox Manager first. Saved sessions are never discarded by this launcher."
    }

    if ($WithDisk) {
        $manifest.DiskRequested = $true
        Save-Manifest $manifest
    }
    if ($BootInstalled -and -not (Test-Path -LiteralPath $DiskPath -PathType Leaf)) {
        throw 'The optional virtual disk does not exist. Run Start-DenOS.cmd -WithDisk, then use the DenOS installer inside the live desktop.'
    }

    Write-Host 'Applying DenOS VM settings (4 GB RAM, 2 CPUs, EFI, host sharing disabled)...'
    $settings = @('modifyvm', $manifest.VmId,
        '--memory', '4096', '--cpus', '2', '--vram', '128',
        '--graphicscontroller', 'vmsvga', '--accelerate-3d', 'off',
        '--firmware', 'efi64', '--ioapic', 'on', '--rtc-use-utc', 'on',
        '--nic1', 'nat', '--nic-type1', '82540EM', '--cable-connected1', 'on',
        '--nic-promisc1', 'deny', '--nat-localhostreachable1', 'off',
        '--nic2', 'none', '--nic3', 'none', '--nic4', 'none',
        '--nic5', 'none', '--nic6', 'none', '--nic7', 'none', '--nic8', 'none',
        '--clipboard-mode', 'disabled', '--clipboard-file-transfers', 'disabled',
        '--drag-and-drop', 'disabled', '--audio-enabled', 'on',
        '--audio-controller', 'hda', '--audio-in', 'off', '--audio-out', 'on',
        '--mouse', 'ps2', '--keyboard', 'ps2',
        '--usb-ohci', 'off', '--usb-ehci', 'off', '--usb-xhci', 'off',
        '--uart1', 'off', '--uart2', 'off', '--uart3', 'off', '--uart4', 'off',
        '--lpt1', 'off', '--lpt2', 'off', '--vrde', 'off', '--recording', 'off',
        '--boot3', 'none', '--boot4', 'none')
    if ($BootInstalled) { $settings += @('--boot1', 'disk', '--boot2', 'dvd') }
    else { $settings += @('--boot1', 'dvd', '--boot2', 'disk') }
    $null = Invoke-VBox -Arguments $settings

    if (-not (@($info.Keys | Where-Object { $_ -match '^storagecontrollername\d+$' }).Count)) {
        $null = Invoke-VBox -Arguments @('storagectl', $manifest.VmId, '--name', $ControllerName, '--add', 'sata', '--controller', 'IntelAhci', '--portcount', '2', '--hostiocache', 'off', '--bootable', 'on')
    }
    if ($manifest.DiskRequested) {
        Assert-InVmRoot $DiskPath
        Assert-NoReparsePoints $DiskPath
        if (-not (Test-Path -LiteralPath $DiskPath -PathType Leaf)) {
            Write-Host 'Creating the sparse 24 GB virtual disk...'
            $null = Invoke-VBox -Arguments @('createmedium', 'disk', '--filename', $DiskPath, '--size', '24576', '--format', 'VDI', '--variant', 'Standard')
        }
        $null = Invoke-VBox -Arguments @('storageattach', $manifest.VmId, '--storagectl', $ControllerName, '--port', '1', '--device', '0', '--type', 'hdd', '--medium', $DiskPath, '--nonrotational', 'on')
    }
    $dvdMedium = if ($BootInstalled) { 'emptydrive' } else { $IsoPath }
    $null = Invoke-VBox -Arguments @('storageattach', $manifest.VmId, '--storagectl', $ControllerName, '--port', '0', '--device', '0', '--type', 'dvddrive', '--medium', $dvdMedium)

    # Re-read the actual registered configuration immediately before starting.
    $null = Get-ManagedVmInfo $manifest
    Write-Host ''
    Write-Host ('VM files: ' + $VmRoot)
    Write-Host 'NAT is available; DenOS itself begins each fresh boot offline.'
    Write-Host 'Clipboard, drag-and-drop, USB passthrough, shared folders and microphone input are disabled.'
    Write-Host 'Starting DenOS in a VirtualBox window...'
    $null = Invoke-VBox -Arguments @('startvm', $manifest.VmId, '--type', 'gui')
    Write-Host 'Use the Right Ctrl key to release the keyboard and mouse from the VM.'
    exit 0
}
catch {
    Write-Host ''
    Write-Host ('DenOS could not start: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'No physical host disk is selected by this launcher. See WINDOWS-LAUNCHER.txt for recovery steps.'
    exit 1
}
