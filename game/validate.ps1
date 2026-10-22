Clear-Host
Write-Host "=== SYSTEM VALIDATION CHECK: CONTROLLER SETUP ===`n" -ForegroundColor Cyan

# 1. BLUETOOTH ADAPTER CHECK
Write-Host "1. BLUETOOTH ADAPTER STATUS" -ForegroundColor White
# Same filter as disable-adapter.ps1: physical radios only (USB/PCI/ACPI), not paired endpoints.
$btAdapters = @(Get-PnpDevice -Class Bluetooth -PresentOnly | Where-Object {
    $_.InstanceId -match '^(USB|PCI|ACPI)\\' -and
    $_.FriendlyName -notmatch 'Enumerator|RFCOMM|Hands-Free|Audio|MAP|Tethering|AVRCP|Network|Service|Identification'
})

$activeAdapters = @($btAdapters | Where-Object { $_.Status -eq 'OK' })

if ($activeAdapters.Count -eq 0) {
    Write-Host "   [ERROR] No active Bluetooth adapters found!" -ForegroundColor Red
} elseif ($activeAdapters.Count -gt 1) {
    Write-Host "   [WARNING] Multiple active Bluetooth adapters detected!" -ForegroundColor Red
    foreach ($a in $activeAdapters) {
        Write-Host "   - $($a.FriendlyName)" -ForegroundColor Yellow
    }
    Write-Host "   -> Please use disable-adapter.ps1 to disable the built-in one." -ForegroundColor Gray
} else {
    $active = $activeAdapters[0]
    $type = if ($active.InstanceId -match '^USB\\') {
        "USB-attached radio"
    } elseif ($active.InstanceId -match '^(PCI|ACPI)\\') {
        "PCI/ACPI radio"
    } else {
        "Unknown bus"
    }

    if ($active.InstanceId -match '^USB\\') {
        Write-Host "   [OK] Only 1 active adapter detected: $($active.FriendlyName) [$type]" -ForegroundColor Green
        Write-Host "   -> Note: laptop chips often use USB too; prefer your gaming dongle if both were enabled." -ForegroundColor Gray
    } else {
        Write-Host "   [WARNING] Only 1 active adapter, and it is a ${type}: $($active.FriendlyName)" -ForegroundColor Yellow
        Write-Host "   -> Make sure your USB adapter is plugged in and enabled." -ForegroundColor Gray
    }
}
Write-Host ""

# 2. CONTROLLER AUDIO CHECK
Write-Host "2. CONTROLLER AUDIO STATUS" -ForegroundColor White
$audioDevs = @(Get-PnpDevice -PresentOnly | Where-Object {
    $_.Class -match '^(Media|AudioEndpoint|SoftwareDevice)$' -and
    $_.FriendlyName -match 'Wireless Controller|DualSense|DualShock|PlayStation|Froggiex'
})

$activeAudio = 0
foreach ($dev in $audioDevs) {
    if ($dev.Status -eq 'OK') {
        $activeAudio++
        Write-Host "   [WARNING] Audio active on: $($dev.FriendlyName)" -ForegroundColor Red
    }
}

if ($activeAudio -gt 0) {
    Write-Host "   -> Use disable-pad-audio.ps1 to mute them and prevent lag." -ForegroundColor Gray
} else {
    Write-Host "   [PERFECT] No controller audio is currently active (Bandwidth is safe)." -ForegroundColor Green
}
Write-Host ""

# 3. CONNECTED PADS CHECK
Write-Host "3. CONNECTED GAMEPADS" -ForegroundColor White
$pads = @(Get-PnpDevice -PresentOnly | Where-Object {
    $_.Class -match '^(Bluetooth|HIDClass)$' -and
    $_.FriendlyName -match 'Wireless Controller|DualSense|DualShock|PlayStation|Froggiex|Gamepad|game controller'
} | Select-Object FriendlyName, Class | Sort-Object FriendlyName -Unique)

if ($pads.Count -eq 0) {
    Write-Host "   [INFO] No connected pads detected right now." -ForegroundColor DarkGray
    Write-Host "   -> Turn them on or pair them in Windows settings." -ForegroundColor Gray
} else {
    foreach ($pad in $pads) {
        Write-Host "   [DETECTED] $($pad.FriendlyName) ($($pad.Class))" -ForegroundColor Cyan
    }
    Write-Host "   [OK] Controllers are visible to the system." -ForegroundColor Green
}
Write-Host ""
Write-Host "Validation complete." -ForegroundColor White
Read-Host "`nPress Enter to exit"
