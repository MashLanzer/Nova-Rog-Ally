$ErrorActionPreference = "Stop"

$sig = @'
using System;
using System.Runtime.InteropServices;
public static class DX {
    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_STATE { public uint dwPacketNumber; public XINPUT_GAMEPAD Gamepad; }
    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_GAMEPAD { public ushort wButtons; public byte bLeftTrigger; public byte bRightTrigger; public short sThumbLX; public short sThumbLY; public short sThumbRX; public short sThumbRY; }
    [DllImport("xinput1_4.dll")] public static extern int XInputGetState(uint dwUserIndex, out XINPUT_STATE pState);
}
'@
Add-Type -TypeDefinition $sig -Language CSharp

$log = Join-Path $PSScriptRoot "diagrun.log"

function Name-Bits([int]$b) {
    $n = @()
    if ($b -band 0x0001) { $n += "DPAD_UP" }
    if ($b -band 0x0002) { $n += "DPAD_DOWN" }
    if ($b -band 0x0004) { $n += "DPAD_LEFT" }
    if ($b -band 0x0008) { $n += "DPAD_RIGHT" }
    if ($b -band 0x0010) { $n += "â‰¡START(Menu)" }
    if ($b -band 0x0020) { $n += "BACK(View)" }
    if ($b -band 0x0040) { $n += "L3" }
    if ($b -band 0x0080) { $n += "R3" }
    if ($b -band 0x0100) { $n += "LB" }
    if ($b -band 0x0200) { $n += "RB" }
    if ($b -band 0x1000) { $n += "A" }
    if ($b -band 0x2000) { $n += "B" }
    if ($b -band 0x4000) { $n += "X" }
    if ($b -band 0x8000) { $n += "Y" }
    if ($n.Count -eq 0) { return "(ninguno)" }
    return ($n -join "+")
}

Out-File -FilePath $log -Encoding utf8 -InputObject "=== Calibracion 2 ==="

$prevB = @(0,0,0,0)
$prevT = @(@(0,0,0,0,0,0), @(0,0,0,0,0,0), @(0,0,0,0,0,0), @(0,0,0,0,0,0))
while ($true) {
    for ($u = 0; $u -lt 4; $u++) {
        $st = New-Object DX+XINPUT_STATE
        $r = [DX]::XInputGetState([uint32]$u, [ref]$st)
        if ($r -ne 0) { continue }
        $b = $st.Gamepad.wButtons
        $lt = $st.Gamepad.bLeftTrigger
        $rt = $st.Gamepad.bRightTrigger
        $now = @($b, $lt, $rt, $st.Gamepad.sThumbLX, $st.Gamepad.sThumbLY, $st.Gamepad.sThumbRX, $st.Gamepad.sThumbRY)
        if ($b -ne $prevB[$u] -or $lt -ne $prevT[$u][0] -or $rt -ne $prevT[$u][1] -or [Math]::Abs($now[3]-$prevT[$u][2]) -gt 2000 -or [Math]::Abs($now[4]-$prevT[$u][3]) -gt 2000 -or [Math]::Abs($now[5]-$prevT[$u][4]) -gt 2000 -or [Math]::Abs($now[6]-$prevT[$u][5]) -gt 2000) {
            $line = (Get-Date -Format "HH:mm:ss.fff") + "  pad$u  btn=0x{0:X4} ($($st.Gamepad.wButtons))  LT=$lt RT=$rt  LX=$($st.Gamepad.sThumbLX) LY=$($st.Gamepad.sThumbLY) RX=$($st.Gamepad.sThumbRX) RY=$($st.Gamepad.sThumbRY)  -> $(Name-Bits $b)" -f $b
            Out-File -FilePath $log -Append -Encoding utf8 -InputObject $line
            $prevB[$u] = $b
            $prevT[$u] = $now
        }
    }
    Start-Sleep -Milliseconds 40
}
