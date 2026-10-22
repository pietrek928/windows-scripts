# Requires Administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator to enable/disable devices!"
    exit 1
}

function Show-PadAudio {
    Clear-Host
    Write-Host "=== UNIVERSAL CONTROLLER AUDIO MANAGER ===" -ForegroundColor Cyan
    Write-Host "Note: Ensure your controllers are currently TURNED ON and CONNECTED.`n" -ForegroundColor Yellow

    # Media = Device Manager "Sound, video and game controllers"; do not include HIDClass (that is the pad itself).
    $script:audioDevs = @(Get-PnpDevice -PresentOnly | Where-Object {
        $_.Class -match '^(Media|AudioEndpoint|SoftwareDevice)$' -and
        $_.FriendlyName -match 'Wireless Controller|DualSense|DualShock|PlayStation|Froggiex'
    } | Select-Object InstanceId, FriendlyName, Status, Problem, Class)

    if ($audioDevs.Count -eq 0) {
        Write-Host "No controller audio devices found." -ForegroundColor Green
        Write-Host "-> If your pad is connected, it means it doesn't broadcast audio. You are good to game!" -ForegroundColor Gray
        return
    }

    $index = 1
    foreach ($dev in $audioDevs) {
        if ($dev.Status -eq 'OK') {
            Write-Host -NoNewline "[$index] " -ForegroundColor White
            Write-Host -NoNewline "[AUDIO ON]  " -ForegroundColor Red
            Write-Host "$($dev.FriendlyName) ($($dev.Class))"
        } elseif ($dev.Status -eq 'Error' -or $dev.Problem -eq 22) {
            Write-Host -NoNewline "[$index] " -ForegroundColor White
            Write-Host -NoNewline "[MUTED]     " -ForegroundColor Green
            Write-Host "$($dev.FriendlyName) ($($dev.Class))" -ForegroundColor DarkGray
        } else {
            Write-Host "[$index] [$($dev.Status)] $($dev.FriendlyName)" -ForegroundColor Yellow
        }
        $index++
    }
    Write-Host ""
}

while ($true) {
    Show-PadAudio

    if ($audioDevs.Count -eq 0) {
        Read-Host "`nPress Enter to quit"
        break
    }

    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "[1-$($audioDevs.Count)] - Enter number to TOGGLE STATE (Mute/Unmute)"
    Write-Host "[Q] - Quit"

    $choice = Read-Host "`nSelect action"

    if ($choice -eq 'q' -or $choice -eq 'Q') {
        Write-Host "Closing..." -ForegroundColor Cyan
        break
    }

    $n = 0
    if ([int]::TryParse($choice, [ref]$n) -and $n -ge 1 -and $n -le $audioDevs.Count) {
        $selectedDev = $audioDevs[$n - 1]

        try {
            if ($selectedDev.Status -eq 'OK') {
                Write-Host "Muting device: $($selectedDev.FriendlyName)..." -ForegroundColor Yellow
                Disable-PnpDevice -InstanceId $selectedDev.InstanceId -Confirm:$false -ErrorAction Stop
            } else {
                Write-Host "Unmuting device: $($selectedDev.FriendlyName)..." -ForegroundColor Yellow
                Enable-PnpDevice -InstanceId $selectedDev.InstanceId -Confirm:$false -ErrorAction Stop
            }

            Write-Host "Changes applied. Please wait a moment..." -ForegroundColor Gray
            Start-Sleep -Seconds 2
        } catch {
            Write-Host "Failed to toggle device: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Press Enter to continue"
        }
    } else {
        Write-Host "Invalid choice. Press Enter to try again." -ForegroundColor Red
        Read-Host
    }
}
