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

function Name-Bits([int]$b) {
    $n = @()
    if ($b -band 0x0001) { $n += "DPAD_ARRIBA" }
    if ($b -band 0x0002) { $n += "DPAD_ABAJO" }
    if ($b -band 0x0004) { $n += "DPAD_IZQ" }
    if ($b -band 0x0008) { $n += "DPAD_DER" }
    if ($b -band 0x0010) { $n += "≡ MENU(START)" }
    if ($b -band 0x0020) { $n += "VIEW(BACK)" }
    if ($b -band 0x0040) { $n += "L3(stick izq)" }
    if ($b -band 0x0080) { $n += "R3(stick der)" }
    if ($b -band 0x0100) { $n += "LB" }
    if ($b -band 0x0200) { $n += "RB" }
    if ($b -band 0x1000) { $n += "A" }
    if ($b -band 0x2000) { $n += "B" }
    if ($b -band 0x4000) { $n += "X" }
    if ($b -band 0x8000) { $n += "Y" }
    return ($n -join "+")
}

Write-Host "=== CALIBRACION EN VIVO ===" -ForegroundColor Cyan
Write-Host "Pulsa cualquier boton 1 segundo y suelta. Aparece aqui si el sistema lo ve." -ForegroundColor Gray
Write-Host ""

$prev = @(0,0,0,0)
$prevStr = ""
while ($true) {
    $curStr = ""
    for ($u = 0; $u -lt 4; $u++) {
        $st = New-Object DX+XINPUT_STATE
        $r = [DX]::XInputGetState([uint32]$u, [ref]$st)
        if ($r -ne 0) { continue }
        $b = $st.Gamepad.wButtons
        if ($b -eq 0) { continue }
        $names = Name-Bits $b
        $curStr = "pad$u " + $names
        if ($b -ne $prev[$u]) {
            Write-Host ("PULSADO: " + $names) -ForegroundColor Green
        }
        $prev[$u] = $b
    }
    if ($curStr -eq "" -and $prevStr -ne "") {
        Write-Host "   (soltado)" -ForegroundColor DarkGray
        $prevStr = ""
    } elseif ($curStr -ne "") {
        $prevStr = $curStr
    }
    Start-Sleep -Milliseconds 25
}