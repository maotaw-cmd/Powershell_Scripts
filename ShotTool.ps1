Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class HotKeyWindow : NativeWindow {
    public event Action<int> HotKeyPressed;

    public HotKeyWindow() {
        CreateHandle(new CreateParams());
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0312) {
            if (HotKeyPressed != null) {
                HotKeyPressed(m.WParam.ToInt32());
            }
        }
        base.WndProc(ref m);
    }

    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
"@ -ReferencedAssemblies System.Windows.Forms

[System.Windows.Forms.Application]::EnableVisualStyles()

$MOD_ALT = 0x0001
$MOD_CONTROL = 0x0002
$MOD_SHIFT = 0x0004
$MOD_WIN = 0x0008

$HOTKEY_FULL = 1
$HOTKEY_CROP = 2

$saveFolder = Join-Path ([Environment]::GetFolderPath("MyPictures")) "ShotTool"
New-Item -ItemType Directory -Force -Path $saveFolder | Out-Null

$configPath = Join-Path $env:APPDATA "ShotTool\settings.json"
New-Item -ItemType Directory -Force -Path (Split-Path $configPath) | Out-Null

$config = @{
    FullKey = "S"
    FullCtrl = $true
    FullShift = $true
    FullAlt = $false
    FullWin = $false

    CropKey = "X"
    CropCtrl = $true
    CropShift = $true
    CropAlt = $false
    CropWin = $false
}

if (Test-Path $configPath) {
    try {
        $loaded = Get-Content $configPath -Raw | ConvertFrom-Json

        foreach ($key in @($config.Keys)) {
            if ($null -ne $loaded.$key) {
                $config[$key] = $loaded.$key
            }
        }
    } catch {}
}

function Save-Config {
    $config | ConvertTo-Json | Set-Content $configPath
}

function Get-Mods($prefix) {
    $mods = 0

    if ($config["${prefix}Ctrl"]) { $mods = $mods -bor $MOD_CONTROL }
    if ($config["${prefix}Shift"]) { $mods = $mods -bor $MOD_SHIFT }
    if ($config["${prefix}Alt"]) { $mods = $mods -bor $MOD_ALT }
    if ($config["${prefix}Win"]) { $mods = $mods -bor $MOD_WIN }

    return $mods
}

function Get-KeyCode($keyText) {
    try {
        return [int][System.Windows.Forms.Keys]::$keyText
    } catch {
        return [int][System.Windows.Forms.Keys]::S
    }
}

function Hotkey-Text($prefix) {
    $parts = @()

    if ($config["${prefix}Ctrl"]) { $parts += "Ctrl" }
    if ($config["${prefix}Shift"]) { $parts += "Shift" }
    if ($config["${prefix}Alt"]) { $parts += "Alt" }
    if ($config["${prefix}Win"]) { $parts += "Win" }

    $parts += $config["${prefix}Key"]

    return ($parts -join " + ")
}

function Take-FullScreenshot {
    try {
        Start-Sleep -Milliseconds 250

        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

        $graphics.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, $bounds.Size)

        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $filePath = Join-Path $saveFolder "screenshot-$timestamp.png"

        $bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)

        $graphics.Dispose()
        $bitmap.Dispose()

        $notifyIcon.ShowBalloonTip(3000, "Screenshot saved", $filePath, [System.Windows.Forms.ToolTipIcon]::Info)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Screenshot failed: $($_.Exception.Message)", "ShotTool Error")
    }
}

function Take-CropScreenshot {
    try {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

        $overlay = New-Object System.Windows.Forms.Form
        $overlay.FormBorderStyle = "None"
        $overlay.StartPosition = "Manual"
        $overlay.Bounds = $screen
        $overlay.TopMost = $true
        $overlay.BackColor = [System.Drawing.Color]::Black
        $overlay.Opacity = 0.35
        $overlay.Cursor = [System.Windows.Forms.Cursors]::Cross
        $overlay.ShowInTaskbar = $false
        $overlay.KeyPreview = $true

        $script:startPoint = $null
        $script:endPoint = $null
        $script:isDragging = $false
        $script:selectedRect = $null

        $overlay.Add_MouseDown({
            $script:isDragging = $true
            $script:startPoint = $_.Location
            $script:endPoint = $_.Location
        })

        $overlay.Add_MouseMove({
            if ($script:isDragging) {
                $script:endPoint = $_.Location
                $overlay.Invalidate()
            }
        })

        $overlay.Add_MouseUp({
            $script:isDragging = $false
            $script:endPoint = $_.Location

            $x = [Math]::Min($script:startPoint.X, $script:endPoint.X)
            $y = [Math]::Min($script:startPoint.Y, $script:endPoint.Y)
            $w = [Math]::Abs($script:startPoint.X - $script:endPoint.X)
            $h = [Math]::Abs($script:startPoint.Y - $script:endPoint.Y)

            if ($w -gt 10 -and $h -gt 10) {
                $script:selectedRect = New-Object System.Drawing.Rectangle $x, $y, $w, $h
            }

            $overlay.Close()
        })

        $overlay.Add_KeyDown({
            if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
                $script:selectedRect = $null
                $overlay.Close()
            }
        })

        $overlay.Add_Paint({
            if ($script:startPoint -and $script:endPoint) {
                $x = [Math]::Min($script:startPoint.X, $script:endPoint.X)
                $y = [Math]::Min($script:startPoint.Y, $script:endPoint.Y)
                $w = [Math]::Abs($script:startPoint.X - $script:endPoint.X)
                $h = [Math]::Abs($script:startPoint.Y - $script:endPoint.Y)

                $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 3
                $_.Graphics.DrawRectangle($pen, $x, $y, $w, $h)
                $pen.Dispose()
            }
        })

        $overlay.ShowDialog() | Out-Null

        if ($script:selectedRect) {
            Start-Sleep -Milliseconds 200

            $bitmap = New-Object System.Drawing.Bitmap $script:selectedRect.Width, $script:selectedRect.Height
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

            $graphics.CopyFromScreen(
                $script:selectedRect.X,
                $script:selectedRect.Y,
                0,
                0,
                $script:selectedRect.Size
            )

            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $filePath = Join-Path $saveFolder "crop-$timestamp.png"

            $bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)

            $graphics.Dispose()
            $bitmap.Dispose()

            $notifyIcon.ShowBalloonTip(3000, "Crop saved", $filePath, [System.Windows.Forms.ToolTipIcon]::Info)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Crop failed: $($_.Exception.Message)", "ShotTool Error")
    }
}

$hotkeyWindow = New-Object HotKeyWindow

function Register-Hotkeys {
    [HotKeyWindow]::UnregisterHotKey($hotkeyWindow.Handle, $HOTKEY_FULL) | Out-Null
    [HotKeyWindow]::UnregisterHotKey($hotkeyWindow.Handle, $HOTKEY_CROP) | Out-Null

    [HotKeyWindow]::RegisterHotKey(
        $hotkeyWindow.Handle,
        $HOTKEY_FULL,
        (Get-Mods "Full"),
        (Get-KeyCode $config.FullKey)
    ) | Out-Null

    [HotKeyWindow]::RegisterHotKey(
        $hotkeyWindow.Handle,
        $HOTKEY_CROP,
        (Get-Mods "Crop"),
        (Get-KeyCode $config.CropKey)
    ) | Out-Null
}

function Capture-Hotkey($textBox, $prefix) {
    $localBox = $textBox
    $localPrefix = $prefix

    $localBox.ReadOnly = $true
    $localBox.BackColor = [System.Drawing.Color]::White
    $localBox.Text = Hotkey-Text $localPrefix

    $localBox.Add_Enter({
        $localBox.Text = "Press shortcut..."
    }.GetNewClosure())

    $localBox.Add_KeyDown({
        param($sender, $e)

        $e.SuppressKeyPress = $true

        $key = $e.KeyCode.ToString()

        if ($key -in @("ControlKey", "ShiftKey", "Menu", "LWin", "RWin")) {
            return
        }

        $config["${localPrefix}Ctrl"] = $e.Control
        $config["${localPrefix}Shift"] = $e.Shift
        $config["${localPrefix}Alt"] = $e.Alt
        $config["${localPrefix}Win"] = ($e.KeyData.ToString() -like "*Win*")
        $config["${localPrefix}Key"] = $key

        $localBox.Text = Hotkey-Text $localPrefix
    }.GetNewClosure())
}

function Show-Settings {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "ShotTool Settings"
    $form.Size = New-Object System.Drawing.Size(440, 250)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.KeyPreview = $true

    $label1 = New-Object System.Windows.Forms.Label
    $label1.Text = "Instant screenshot hotkey:"
    $label1.Location = New-Object System.Drawing.Point(25, 30)
    $label1.Size = New-Object System.Drawing.Size(180, 25)

    $fullBox = New-Object System.Windows.Forms.TextBox
    $fullBox.Location = New-Object System.Drawing.Point(220, 27)
    $fullBox.Size = New-Object System.Drawing.Size(170, 25)

    $label2 = New-Object System.Windows.Forms.Label
    $label2.Text = "Crop screenshot hotkey:"
    $label2.Location = New-Object System.Drawing.Point(25, 75)
    $label2.Size = New-Object System.Drawing.Size(180, 25)

    $cropBox = New-Object System.Windows.Forms.TextBox
    $cropBox.Location = New-Object System.Drawing.Point(220, 72)
    $cropBox.Size = New-Object System.Drawing.Size(170, 25)

    Capture-Hotkey $fullBox "Full"
    Capture-Hotkey $cropBox "Crop"

    $info = New-Object System.Windows.Forms.Label
    $info.Text = "Click inside a box, then press your shortcut.`nExample: Ctrl + Shift + S or Ctrl + Alt + X"
    $info.Location = New-Object System.Drawing.Point(25, 120)
    $info.Size = New-Object System.Drawing.Size(360, 45)

    $saveBtn = New-Object System.Windows.Forms.Button
    $saveBtn.Text = "Save"
    $saveBtn.Location = New-Object System.Drawing.Point(25, 170)
    $saveBtn.Size = New-Object System.Drawing.Size(100, 32)

    $saveBtn.Add_Click({
        Save-Config
        Register-Hotkeys
        [System.Windows.Forms.MessageBox]::Show("Hotkeys saved.", "ShotTool")
        $form.Close()
    })

    $form.Controls.AddRange(@($label1, $fullBox, $label2, $cropBox, $info, $saveBtn))
    $form.ShowDialog() | Out-Null
}

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Text = "ShotTool"
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$notifyIcon.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip

$itemFull = New-Object System.Windows.Forms.ToolStripMenuItem "Instant Screenshot"
$itemFull.Add_Click({ Take-FullScreenshot })

$itemCrop = New-Object System.Windows.Forms.ToolStripMenuItem "Crop Screenshot"
$itemCrop.Add_Click({ Take-CropScreenshot })

$itemSettings = New-Object System.Windows.Forms.ToolStripMenuItem "Settings / Hotkeys"
$itemSettings.Add_Click({ Show-Settings })

$itemOpen = New-Object System.Windows.Forms.ToolStripMenuItem "Open Folder"
$itemOpen.Add_Click({ Start-Process explorer.exe "`"$saveFolder`"" })

$itemExit = New-Object System.Windows.Forms.ToolStripMenuItem "Exit"
$itemExit.Add_Click({
    [HotKeyWindow]::UnregisterHotKey($hotkeyWindow.Handle, $HOTKEY_FULL) | Out-Null
    [HotKeyWindow]::UnregisterHotKey($hotkeyWindow.Handle, $HOTKEY_CROP) | Out-Null
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$menu.Items.Add($itemFull) | Out-Null
$menu.Items.Add($itemCrop) | Out-Null
$menu.Items.Add($itemSettings) | Out-Null
$menu.Items.Add($itemOpen) | Out-Null
$menu.Items.Add($itemExit) | Out-Null

$notifyIcon.ContextMenuStrip = $menu

$hotkeyWindow.add_HotKeyPressed({
    param($id)

    if ($id -eq $HOTKEY_FULL) {
        Take-FullScreenshot
    }

    if ($id -eq $HOTKEY_CROP) {
        Take-CropScreenshot
    }
})

Register-Hotkeys

$notifyIcon.ShowBalloonTip(
    4000,
    "ShotTool running",
    "Right-click tray icon. Open Settings to change hotkeys.",
    [System.Windows.Forms.ToolTipIcon]::Info
)

[System.Windows.Forms.Application]::Run()
