function Log([string]$msg) {
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $msg
    Out-File -FilePath $EventLog -Append -Encoding utf8 -InputObject $line
}

function Send-Key([int]$vk) {
    [AX]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [AX]::keybd_event([byte]$vk, 0, $KEYUP, [UIntPtr]::Zero)
}

function Send-WinH {
    [AX]::keybd_event([byte]$VK_LWIN, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [AX]::keybd_event([byte]$VK_H, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [AX]::keybd_event([byte]$VK_H, 0, $KEYUP, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [AX]::keybd_event([byte]$VK_LWIN, 0, $KEYUP, [UIntPtr]::Zero)
}

$mutex = New-Object System.Threading.Mutex($false, "Local\VoiceAssistant")
if (-not $mutex.WaitOne(0)) {
    Write-Output "VoiceAssistant ya esta ejecutandose."
    exit 0
}

$capture = New-Object System.Windows.Forms.Form
$capture.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$capture.ShowInTaskbar = $false
$capture.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$capture.Size = New-Object System.Drawing.Size(1, 40)
$capture.Location = New-Object System.Drawing.Point(-5000, -5000)
$capture.TopMost = $true
$capture.Text = "voice-capture"
$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true
$tb.AcceptsReturn = $true
$tb.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$tb.Dock = [System.Windows.Forms.DockStyle]::Fill
$capture.Controls.Add($tb)

function Show-Capture {
    $tb.Clear()
    $capture.Show()
    $capture.Activate()
    [AX]::keybd_event([byte]$VK_MENU, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 20
    [AX]::keybd_event([byte]$VK_MENU, 0, $KEYUP, [UIntPtr]::Zero)
    [AX]::SetForegroundWindow($capture.Handle) | Out-Null
    Start-Sleep -Milliseconds 200
    $tb.Focus()
}

function Show-Popup([string]$text) {
    try {
        $f = New-Object System.Windows.Forms.Form
        $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $f.ShowInTaskbar = $false
        $f.TopMost = $true
        $f.BackColor = [System.Drawing.Color]::FromArgb(28, 32, 42)
        $f.ForeColor = [System.Drawing.Color]::White
        $f.Padding = New-Object System.Windows.Forms.Padding(14)
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $text
        $l.AutoSize = $false
        $l.MaximumSize = New-Object System.Drawing.Size(600, 0)
        $l.ForeColor = $f.ForeColor
        $l.BackColor = $f.BackColor
        $l.Font = New-Object System.Drawing.Font("Segoe UI", 10.5)
        $l.Dock = [System.Windows.Forms.DockStyle]::Fill
        $f.Controls.Add($l)
        $f.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $f.AutoSize = $true
        $f.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $scr = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $f.Location = New-Object System.Drawing.Point(($scr.Right - $f.Width - 24), ($scr.Bottom - $f.Height - 48))
        $f.Show()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt $PopupMs) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }
        $f.Close()
    } catch {
        Log "popup error: $($_.Exception.Message)"
    }
}

function Submit-Command([string]$text) {
    Log "SUBMIT: $text"
    $out = @()
    try {
        $out = & $OCODECLI run --auto --dir "$WORKDIR" $text 2>&1
    } catch {
        $out = @("ERROR headless: $($_.Exception.Message)")
    }
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $full = ($out | Out-String)
    Out-File -FilePath $ReplyLog -Append -Encoding utf8 -InputObject ("=== " + $now + " ===")
    Out-File -FilePath $ReplyLog -Append -Encoding utf8 -InputObject $full

    $lines = @($out) | Where-Object { $_ -and $_.ToString().Trim().Length -gt 0 }
    $clean = $lines | Where-Object { $_.ToString() -notmatch '^\s*>' }
    $reply = (($clean | ForEach-Object { $_.ToString() }) -join " ").Trim()
    if ($reply.Length -eq 0) { $reply = "(sin respuesta)" }
    if ($reply.Length -gt 1000) { $reply = $reply.Substring(0, 1000) + " [...]" }
    Log "REPLY: $reply"
    Show-Popup $reply
}

Log "VoiceAssistant iniciado (trigger: mantener â‰¡ 1,1 s; destino: opencode CLI headless)."
