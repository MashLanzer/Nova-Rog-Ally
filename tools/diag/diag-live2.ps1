$ErrorActionPreference = "Stop"
$sig = @'
using System;
using System.Runtime.InteropServices;
public static class DXT {
    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_STATE2 { public uint dwPacketNumber; public XINPUT_GAMEPAD Gamepad; }
    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_GAMEPAD { public ushort wButtons; public byte bLeftTrigger; public byte bRightTrigger; public short sThumbLX; public short sThumbLY; public short sThumbRX; public short sThumbRY; }
    [DllImport("xinput1_4.dll")] public static extern int XInputGetState(uint dwUserIndex, out XINPUT_STATE2 pState);
}
'@
Add-Type -TypeDefinition $sig -Language CSharp -ErrorAction Stop
Write-Host "add-type OK"
$t = [Diagnostics.Stopwatch]::StartNew()
$prev = @(0,0,0,0)
while ($t.ElapsedMilliseconds -lt 6000) {
    for ($u = 0; $u -lt 4; $u++) {
        $st = New-Object DXT+XINPUT_STATE2
        $r = [DXT]::XInputGetState([uint32]$u, [ref]$st)
        if ($r -ne 0) { continue }
        if ($st.Gamepad.wButtons -ne $prev[$u]) {
            Write-Host ("t={0} pad{1} btn=0x{2:X4}" -f $t.ElapsedMilliseconds, $u, $st.Gamepad.wButtons)
            $prev[$u] = $st.Gamepad.wButtons
        }
    }
    Start-Sleep -Milliseconds 40
}
Write-Host "loop terminado sin crash"