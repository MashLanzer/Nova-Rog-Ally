$ErrorActionPreference = "Stop"

$VK_H = 0x48
$VK_RETURN = 0x0D
$VK_ESCAPE = 0x1B
$VK_LWIN = 0x5B
$KEYUP = 0x0002

$XINPUT_START = 0x0010
$XINPUT_BACK = 0x0020
$COMBO = $XINPUT_START -bor $XINPUT_BACK

$LogPath = Join-Path $PSScriptRoot "voicedict.log"

$sig = @'
using System;
using System.Runtime.InteropServices;
public static class XCtrl {
    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_STATE {
        public uint dwPacketNumber;
        public XINPUT_GAMEPAD Gamepad;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_GAMEPAD {
        public ushort wButtons;
        public byte bLeftTrigger;
        public byte bRightTrigger;
        public short sThumbLX;
        public short sThumbLY;
        public short sThumbRX;
        public short sThumbRY;
    }
    [DllImport("xinput1_4.dll")]
    public static extern int XInputGetState(uint dwUserIndex, out XINPUT_STATE pState);
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
'@

Add-Type -TypeDefinition $sig -Language CSharp

function Log($msg) {
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $msg
    Write-Output $line
    Out-File -FilePath $LogPath -Append -Encoding utf8 -InputObject $line
}

function Send-Key([int]$vk) {
    [XCtrl]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [XCtrl]::keybd_event([byte]$vk, 0, $KEYUP, [UIntPtr]::Zero)
}

function Send-WinH {
    [XCtrl]::keybd_event([byte]$VK_LWIN, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [XCtrl]::keybd_event([byte]$VK_H, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [XCtrl]::keybd_event([byte]$VK_H, 0, $KEYUP, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [XCtrl]::keybd_event([byte]$VK_LWIN, 0, $KEYUP, [UIntPtr]::Zero)
}

$mutex = New-Object System.Threading.Mutex($false, "Local\VoiceDictCtrl")
if (-not $mutex.WaitOne(0)) {
    Write-Output "VoiceDict ya se esta ejecutando."
    exit 0
}

Log "VoiceDict iniciado (combo: Select+Start)."

$wasPressed = $false
$armed = $false

while ($true) {
    $pressedNow = $false
    for ($u = 0; $u -lt 4; $u++) {
        $state = New-Object XCtrl+XINPUT_STATE
        $r = [XCtrl]::XInputGetState([uint32]$u, [ref]$state)
        if ($r -eq 0 -and (($state.Gamepad.wButtons -band $COMBO) -eq $COMBO)) {
            $pressedNow = $true
            break
        }
    }

    if ($pressedNow -and -not $wasPressed) {
        if ($armed) {
            Log "ENVIAR"
            Send-Key $VK_ESCAPE
            Start-Sleep -Milliseconds 200
            Send-Key $VK_RETURN
            $armed = $false
        } else {
            Log "DICTADO"
            Send-WinH
            $armed = $true
        }
    }

    $wasPressed = $pressedNow
    Start-Sleep -Milliseconds 40
}