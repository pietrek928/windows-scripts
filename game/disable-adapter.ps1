# Requires Administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator to enable/disable devices!"
    exit 1
}

function Show-BluetoothAdapters {
    Clear-Host
    Write-Host "=== BLUETOOTH ADAPTER MANAGER ===" -ForegroundColor Cyan
    Write-Host ""

    # Physical radios use USB/PCI/ACPI InstanceIds; BTH*/BTHENUM* are software or paired endpoints.
    # -PresentOnly hides disconnected ghost devices (e.g. BARROT).
    $script:btDevices = @(Get-PnpDevice -Class Bluetooth -PresentOnly | Where-Object {
        $_.InstanceId -match '^(USB|PCI|ACPI)\\' -and
        $_.FriendlyName -notmatch 'Enumerator|RFCOMM|Hands-Free|Audio|MAP|Tethering|AVRCP|Network|Service|Identification'
    } | Select-Object InstanceId, FriendlyName, Status, Problem, Class)

    if ($btDevices.Count -eq 0) {
        Write-Host "No physical Bluetooth adapters detected." -ForegroundColor Red
        return
    }

    $index = 1
    foreach ($dev in $btDevices) {
        if ($dev.Status -eq 'OK') {
            Write-Host -NoNewline "[$index] " -ForegroundColor White
            Write-Host -NoNewline "[ACTIVE]    " -ForegroundColor Green
        } elseif ($dev.Status -eq 'Error' -or $dev.Problem -eq 22) {
            Write-Host -NoNewline "[$index] " -ForegroundColor White
            Write-Host -NoNewline "[DISABLED]  " -ForegroundColor DarkGray
        } else {
            Write-Host -NoNewline "[$index] " -ForegroundColor White
            Write-Host -NoNewline "[$($dev.Status)] " -ForegroundColor Yellow
        }

        # Built-in chips often still use USB\VID_ (internal USB); label by bus, not External/Built-in.
        $busType = if ($dev.InstanceId -match '^USB\\') {
            "USB-attached radio"
        } elseif ($dev.InstanceId -match '^(PCI|ACPI)\\') {
            "PCI/ACPI radio"
        } else {
            "Unknown bus"
        }

        Write-Host "$($dev.FriendlyName) | Type: $busType"
        $index++
    }
    Write-Host ""
}

while ($true) {
    Show-BluetoothAdapters

    if ($btDevices.Count -eq 0) {
        Read-Host "`nPress Enter to quit"
        break
    }

    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "[1-$($btDevices.Count)] - Enter number to TOGGLE STATE (Enable/Disable) of the device"
    Write-Host "[Q] - Quit"

    $choice = Read-Host "`nSelect action"

    if ($choice -eq 'q' -or $choice -eq 'Q') {
        Write-Host "Closing..." -ForegroundColor Cyan
        break
    }

    $n = 0
    if ([int]::TryParse($choice, [ref]$n) -and $n -ge 1 -and $n -le $btDevices.Count) {
        $selectedDev = $btDevices[$n - 1]

        try {
            if ($selectedDev.Status -eq 'OK') {
                Write-Host "Disabling device: $($selectedDev.FriendlyName)..." -ForegroundColor Yellow
                Disable-PnpDevice -InstanceId $selectedDev.InstanceId -Confirm:$false -ErrorAction Stop
            } else {
                Write-Host "Enabling device: $($selectedDev.FriendlyName)..." -ForegroundColor Yellow
                Enable-PnpDevice -InstanceId $selectedDev.InstanceId -Confirm:$false -ErrorAction Stop
            }

            Write-Host "Changes applied. Please wait a moment..." -ForegroundColor Gray
            Start-Sleep -Seconds 3
        } catch {
            Write-Host "Failed to toggle device: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Press Enter to continue"
        }
    } else {
        Write-Host "Invalid choice. Press Enter to try again." -ForegroundColor Red
        Read-Host
    }
}
