#requires -Version 5.1
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:ScriptFolder = if ($PSScriptRoot) {
    $PSScriptRoot
}
else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

if ([string]::IsNullOrWhiteSpace($script:ScriptFolder)) {
    $script:ScriptFolder = (Get-Location).Path
}

$script:ToolsFolder    = Join-Path $script:ScriptFolder "YouTube-MP3-Tools"
$script:DownloadFolder = Join-Path $script:ScriptFolder "Downloads"
$script:YtDlp          = Join-Path $script:ToolsFolder "yt-dlp.exe"
$script:Deno           = Join-Path $script:ToolsFolder "deno.exe"
$script:Ffmpeg          = Join-Path $script:ToolsFolder "ffmpeg.exe"
$script:Ffprobe         = Join-Path $script:ToolsFolder "ffprobe.exe"
$script:StateFile       = Join-Path $env:TEMP ("youtube_mp3_state_" + [guid]::NewGuid().ToString("N") + ".json")

$script:Worker       = $null
$script:WorkerHandle = $null
$script:Timer        = $null
$script:OutputFile   = $null

New-Item -ItemType Directory -Path $script:ToolsFolder -Force | Out-Null
New-Item -ItemType Directory -Path $script:DownloadFolder -Force | Out-Null

[xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="YouTube to MP3"
    Width="488"
    Height="443"
    WindowStartupLocation="CenterScreen"
    WindowStyle="None"
    ResizeMode="NoResize"
    AllowsTransparency="True"
    Background="Transparent"
    FontFamily="Segoe UI">

    <Window.Resources>
        <Style x:Key="CaptionButton" TargetType="Button">
            <Setter Property="Width" Value="45"/>
            <Setter Property="Height" Value="45"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#1D222B"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#EEF1F5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="BlueButton" TargetType="Button">
            <Setter Property="Height" Value="40"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="#0866F5"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd"
                                Background="{TemplateBinding Background}"
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#005BEA"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#004CC7"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Bd" Property="Background" Value="#E7EBF0"/>
                                <Setter Property="Foreground" Value="#A3A9B2"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="OutlineButton" TargetType="Button">
            <Setter Property="Height" Value="38"/>
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="Foreground" Value="#171B22"/>
            <Setter Property="BorderBrush" Value="#D8DEE8"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#F6F8FB"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="#ADB3BC"/>
                                <Setter TargetName="Bd" Property="Background" Value="#FAFBFC"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="UrlTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="Foreground" Value="#1B2028"/>
            <Setter Property="BorderBrush" Value="#D7DEE8"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="47,0,14,0"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border x:Name="Bd"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="7">
                            <ScrollViewer x:Name="PART_ContentHost"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="Bd" Property="BorderBrush" Value="#86AFF0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border CornerRadius="8"
            Background="#FBFCFE"
            BorderBrush="#E1E5EB"
            BorderThickness="1">
        <Grid ClipToBounds="True">
            <Grid.RowDefinitions>
                <RowDefinition Height="45"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- TOP BAR -->
            <Grid x:Name="TopBar" Grid.Row="0" Background="#FBFCFE">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="45"/>
                    <ColumnDefinition Width="45"/>
                    <ColumnDefinition Width="45"/>
                </Grid.ColumnDefinitions>

                <StackPanel Orientation="Horizontal"
                            Margin="11,0,0,0"
                            VerticalAlignment="Center">
                    <Border Width="22" Height="22" CornerRadius="5" Background="#0866F5">
                        <TextBlock Text="&#xE8D6;"
                                   FontFamily="Segoe MDL2 Assets"
                                   Foreground="White"
                                   FontSize="13"
                                   HorizontalAlignment="Center"
                                   VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="YouTube to MP3"
                               Foreground="#171A20"
                               FontSize="14"
                               FontWeight="SemiBold"
                               Margin="10,0,0,0"
                               VerticalAlignment="Center"/>
                </StackPanel>

                <Button x:Name="MinimizeButton"
                        Grid.Column="1"
                        Content="&#xE921;"
                        FontFamily="Segoe MDL2 Assets"
                        FontSize="10"
                        Style="{StaticResource CaptionButton}"/>

                <Button Grid.Column="2"
                        Content="&#xE922;"
                        FontFamily="Segoe MDL2 Assets"
                        FontSize="10"
                        IsHitTestVisible="False"
                        Style="{StaticResource CaptionButton}"/>

                <Button x:Name="CloseButton"
                        Grid.Column="3"
                        Content="&#xE8BB;"
                        FontFamily="Segoe MDL2 Assets"
                        FontSize="12"
                        Style="{StaticResource CaptionButton}"/>
            </Grid>

            <Border Grid.Row="0"
                    Height="1"
                    VerticalAlignment="Bottom"
                    Background="#E8EBF0"/>

            <!-- CONTENT -->
            <Grid Grid.Row="1" Margin="13,20,13,11">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="20"/>
                    <RowDefinition Height="42"/>
                    <RowDefinition Height="17"/>
                    <RowDefinition Height="53"/>
                    <RowDefinition Height="20"/>
                    <RowDefinition Height="77"/>
                </Grid.RowDefinitions>

                <!-- YouTube logo / title -->
                <StackPanel Grid.Row="0" HorizontalAlignment="Center">
                    <Border Width="74" Height="54" CornerRadius="15" Background="#FF0000">
                        <Path Data="M 0,0 L 18,11 L 0,22 Z"
                              Fill="White"
                              Width="18"
                              Height="22"
                              Stretch="Fill"
                              HorizontalAlignment="Center"
                              VerticalAlignment="Center"/>
                    </Border>

                    <TextBlock Text="YouTube to MP3"
                               Foreground="#111318"
                               FontSize="21"
                               FontWeight="Bold"
                               HorizontalAlignment="Center"
                               Margin="0,14,0,0"/>

                    <TextBlock Text="Convert YouTube videos to high-quality MP3"
                               Foreground="#657080"
                               FontSize="12.5"
                               HorizontalAlignment="Center"
                               Margin="0,4,0,0"/>
                </StackPanel>

                <!-- URL -->
                <Grid Grid.Row="2">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="9"/>
                        <ColumnDefinition Width="94"/>
                    </Grid.ColumnDefinitions>

                    <Grid>
                        <TextBox x:Name="UrlTextBox"
                                 Style="{StaticResource UrlTextBox}"
                                 Height="42"/>

                        <TextBlock Text="&#xE71B;"
                                   FontFamily="Segoe MDL2 Assets"
                                   Foreground="#61728A"
                                   FontSize="16"
                                   IsHitTestVisible="False"
                                   Margin="17,0,0,0"
                                   HorizontalAlignment="Left"
                                   VerticalAlignment="Center"/>

                        <TextBlock x:Name="UrlPlaceholder"
                                   Text="Paste YouTube video link here..."
                                   Foreground="#8290A4"
                                   FontSize="13"
                                   Margin="47,0,0,0"
                                   HorizontalAlignment="Left"
                                   VerticalAlignment="Center"
                                   IsHitTestVisible="False"/>
                    </Grid>

                    <Button x:Name="PasteButton"
                            Grid.Column="2"
                            Content="Paste"
                            Style="{StaticResource BlueButton}"/>
                </Grid>

                <!-- MAIN DOWNLOAD BUTTON -->
                <Button x:Name="ConvertButton"
                        Grid.Row="4"
                        Width="275"
                        Height="53"
                        HorizontalAlignment="Center"
                        IsEnabled="False"
                        Style="{StaticResource BlueButton}">
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                        <TextBlock Text="&#xE8D6;"
                                   FontFamily="Segoe MDL2 Assets"
                                   FontSize="17"
                                   Margin="0,0,11,0"
                                   VerticalAlignment="Center"/>
                        <TextBlock x:Name="ConvertButtonText"
                                   Text="Convert to MP3"
                                   FontSize="15"
                                   FontWeight="SemiBold"
                                   VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>

                <!-- RESULT CARD -->
                <Border Grid.Row="6"
                        Background="#F7F9FC"
                        BorderBrush="#E2E7EF"
                        BorderThickness="1"
                        CornerRadius="7">
                    <Grid Margin="14,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="43"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="122"/>
                        </Grid.ColumnDefinitions>

                        <Border Width="40" Height="40" CornerRadius="20"
                                Background="#E7F0FF"
                                VerticalAlignment="Center">
                            <TextBlock Text="&#xE8D6;"
                                       FontFamily="Segoe MDL2 Assets"
                                       Foreground="#0866F5"
                                       FontSize="20"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"/>
                        </Border>

                        <StackPanel Grid.Column="1"
                                    Margin="12,0,10,0"
                                    VerticalAlignment="Center">
                            <TextBlock x:Name="ResultTitle"
                                       Text="Your MP3 file will appear here"
                                       Foreground="#151920"
                                       FontSize="13"
                                       FontWeight="SemiBold"
                                       TextTrimming="CharacterEllipsis"/>
                            <TextBlock x:Name="ResultSubtitle"
                                       Text="Ready to convert"
                                       Foreground="#748093"
                                       FontSize="11"
                                       Margin="0,5,0,0"
                                       TextTrimming="CharacterEllipsis"/>
                        </StackPanel>

                        <Button x:Name="DownloadButton"
                                Grid.Column="2"
                                Width="122"
                                Height="38"
                                IsEnabled="False"
                                Style="{StaticResource OutlineButton}">
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                <TextBlock Text="&#xE896;"
                                           FontFamily="Segoe MDL2 Assets"
                                           FontSize="16"
                                           Margin="0,0,10,0"
                                           VerticalAlignment="Center"/>
                                <TextBlock Text="Download"
                                           FontSize="13"
                                           VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                </Border>

                <!-- PROGRESS OVERLAY -->
                <Border x:Name="ProgressOverlay"
                        Grid.RowSpan="7"
                        Visibility="Collapsed"
                        Background="#F7FAFE"
                        CornerRadius="7">
                    <StackPanel HorizontalAlignment="Center"
                                VerticalAlignment="Center"
                                Width="390">
                        <Border Width="72" Height="72" CornerRadius="36" Background="#E7F0FF">
                            <TextBlock Text="&#xE8D6;"
                                       FontFamily="Segoe MDL2 Assets"
                                       Foreground="#0866F5"
                                       FontSize="34"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"/>
                        </Border>

                        <TextBlock x:Name="ProgressTitle"
                                   Text="Preparing converter..."
                                   Foreground="#111318"
                                   FontSize="20"
                                   FontWeight="Bold"
                                   HorizontalAlignment="Center"
                                   Margin="0,18,0,0"/>

                        <TextBlock x:Name="ProgressMessage"
                                   Text="Checking required tools"
                                   Foreground="#687486"
                                   FontSize="12"
                                   HorizontalAlignment="Center"
                                   Margin="0,6,0,0"/>

                        <Grid Width="390" Margin="0,27,0,0">
                            <Border Height="8" Background="#E7ECF3" CornerRadius="4"/>
                            <Border x:Name="ProgressFill"
                                    Width="0"
                                    Height="8"
                                    Background="#0866F5"
                                    CornerRadius="4"
                                    HorizontalAlignment="Left"/>
                        </Grid>

                        <Grid Width="390" Margin="0,9,0,0">
                            <TextBlock x:Name="ProgressStep"
                                       Text="Starting..."
                                       Foreground="#6B7584"
                                       FontSize="11"/>
                            <TextBlock x:Name="ProgressPercent"
                                       Text="0%"
                                       Foreground="#505A68"
                                       FontSize="11"
                                       HorizontalAlignment="Right"/>
                        </Grid>
                    </StackPanel>
                </Border>
            </Grid>
        </Grid>
    </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)

$names = @(
    "TopBar","MinimizeButton","CloseButton",
    "UrlTextBox","UrlPlaceholder","PasteButton","ConvertButton","ConvertButtonText",
    "ResultTitle","ResultSubtitle","DownloadButton",
    "ProgressOverlay","ProgressTitle","ProgressMessage","ProgressFill","ProgressStep","ProgressPercent"
)

foreach ($name in $names) {
    Set-Variable -Name $name -Value $Window.FindName($name) -Scope Script
}

function Update-UrlState {
    $hasUrl = -not [string]::IsNullOrWhiteSpace($UrlTextBox.Text)
    $UrlPlaceholder.Visibility = if ($hasUrl) { "Collapsed" } else { "Visible" }
    $ConvertButton.IsEnabled = $hasUrl -and ($ProgressOverlay.Visibility -ne "Visible")
}

function Format-FileSize {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return "{0:N1} MB" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N0} KB" -f ($Bytes / 1KB)
    }

    return "$Bytes bytes"
}

function Normalize-YouTubeUrl {
    param([string]$Url)

    $clean = $Url.Trim()

    try {
        $uri = [Uri]$clean

        if ($uri.Host -match "(^|\.)youtube\.com$" -and $clean -match "[?&]v=([^&]+)") {
            return "https://www.youtube.com/watch?v=$($matches[1])"
        }

        if ($uri.Host -match "(^|\.)youtu\.be$") {
            $id = $uri.AbsolutePath.Trim("/")
            if (-not [string]::IsNullOrWhiteSpace($id)) {
                return "https://www.youtube.com/watch?v=$id"
            }
        }
    }
    catch {}

    return $clean
}

function Show-ProgressView {
    $ProgressOverlay.Visibility = "Visible"
    $ConvertButton.IsEnabled = $false
    $PasteButton.IsEnabled = $false
    $UrlTextBox.IsEnabled = $false
    $DownloadButton.IsEnabled = $false
}

function Hide-ProgressView {
    $ProgressOverlay.Visibility = "Collapsed"
    $PasteButton.IsEnabled = $true
    $UrlTextBox.IsEnabled = $true
    Update-UrlState
}

function Write-UiState {
    param(
        [string]$Stage,
        [double]$Progress,
        [string]$Message,
        [string]$Detail = "",
        [string]$Output = "",
        [string]$ErrorText = ""
    )

    $obj = [ordered]@{
        stage    = $Stage
        progress = $Progress
        message  = $Message
        detail   = $Detail
        output   = $Output
        error    = $ErrorText
        updated  = [DateTime]::UtcNow.ToString("o")
    }

    $json = $obj | ConvertTo-Json -Compress
    [IO.File]::WriteAllText($script:StateFile, $json, [Text.UTF8Encoding]::new($false))
}

function Start-YouTubeDownload {
    $rawUrl = $UrlTextBox.Text

    if ([string]::IsNullOrWhiteSpace($rawUrl)) {
        return
    }

    $url = Normalize-YouTubeUrl $rawUrl
    $UrlTextBox.Text = $url

    $script:OutputFile = $null
    $ResultTitle.Text = "Your MP3 file will appear here"
    $ResultSubtitle.Text = "Preparing download..."
    $DownloadButton.IsEnabled = $false

    $ProgressFill.Width = 0
    $ProgressPercent.Text = "0%"
    $ProgressTitle.Text = "Preparing converter..."
    $ProgressMessage.Text = "Checking required tools"
    $ProgressStep.Text = "Starting..."
    Show-ProgressView

    Remove-Item -LiteralPath $script:StateFile -Force -ErrorAction SilentlyContinue

    $toolsFolder = $script:ToolsFolder
    $downloadFolder = $script:DownloadFolder
    $ytDlp = $script:YtDlp
    $deno = $script:Deno
    $ffmpeg = $script:Ffmpeg
    $ffprobe = $script:Ffprobe
    $stateFile = $script:StateFile

    $workerScript = {
        param(
            $Url,
            $ToolsFolder,
            $DownloadFolder,
            $YtDlp,
            $Deno,
            $Ffmpeg,
            $Ffprobe,
            $StateFile
        )

        $ErrorActionPreference = "Stop"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        function Set-State {
            param(
                [string]$Stage,
                [double]$Progress,
                [string]$Message,
                [string]$Detail = "",
                [string]$Output = "",
                [string]$ErrorText = ""
            )

            $obj = [ordered]@{
                stage    = $Stage
                progress = $Progress
                message  = $Message
                detail   = $Detail
                output   = $Output
                error    = $ErrorText
                updated  = [DateTime]::UtcNow.ToString("o")
            }

            [IO.File]::WriteAllText(
                $StateFile,
                ($obj | ConvertTo-Json -Compress),
                [Text.UTF8Encoding]::new($false)
            )
        }

        function Download-File {
            param(
                [string]$Uri,
                [string]$Destination,
                [double]$StartPercent,
                [double]$EndPercent,
                [string]$Label
            )

            $partial = $Destination + ".part"
            Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue

            $request = [System.Net.HttpWebRequest]::Create($Uri)
            $request.Method = "GET"
            $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
            $request.AllowAutoRedirect = $true
            $request.Timeout = 30000
            $request.ReadWriteTimeout = 30000

            $response = $null
            $input = $null
            $output = $null

            try {
                $response = $request.GetResponse()
                $total = [long]$response.ContentLength
                $input = $response.GetResponseStream()
                $output = [IO.File]::Open(
                    $partial,
                    [IO.FileMode]::Create,
                    [IO.FileAccess]::Write,
                    [IO.FileShare]::None
                )

                $buffer = New-Object byte[] 1048576
                $downloaded = 0L
                $last = -1

                while (($read = $input.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $output.Write($buffer, 0, $read)
                    $downloaded += $read

                    if ($total -gt 0) {
                        $ratio = [Math]::Min(1.0, $downloaded / [double]$total)
                        $progress = $StartPercent + (($EndPercent - $StartPercent) * $ratio)
                        $whole = [int]($ratio * 100)

                        if ($whole -ne $last) {
                            Set-State "tools" $progress $Label (
                                "{0:N1} / {1:N1} MB" -f ($downloaded / 1MB), ($total / 1MB)
                            )
                            $last = $whole
                        }
                    }
                }
            }
            finally {
                if ($output) { $output.Dispose() }
                if ($input) { $input.Dispose() }
                if ($response) { $response.Dispose() }
            }

            [IO.File]::Move($partial, $Destination)
        }

        try {
            New-Item -ItemType Directory -Path $ToolsFolder -Force | Out-Null
            New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null

            Set-State "tools" 2 "Preparing converter..." "Checking yt-dlp"

            if (-not (Test-Path -LiteralPath $YtDlp)) {
                Download-File `
                    -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" `
                    -Destination $YtDlp `
                    -StartPercent 3 `
                    -EndPercent 18 `
                    -Label "Downloading yt-dlp..."
            }

            Set-State "tools" 19 "Preparing converter..." "Checking Deno"

            if (-not (Test-Path -LiteralPath $Deno)) {
                $denoZip = Join-Path $ToolsFolder "deno.zip"
                $denoTemp = Join-Path $ToolsFolder ("deno_temp_" + [guid]::NewGuid().ToString("N"))

                Download-File `
                    -Uri "https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip" `
                    -Destination $denoZip `
                    -StartPercent 20 `
                    -EndPercent 34 `
                    -Label "Downloading Deno..."

                New-Item -ItemType Directory -Path $denoTemp -Force | Out-Null
                Expand-Archive -LiteralPath $denoZip -DestinationPath $denoTemp -Force

                $found = Get-ChildItem -LiteralPath $denoTemp -Filter "deno.exe" -Recurse -File |
                    Select-Object -First 1

                if (-not $found) {
                    throw "deno.exe was not found in the downloaded archive."
                }

                Copy-Item -LiteralPath $found.FullName -Destination $Deno -Force
                Remove-Item -LiteralPath $denoZip -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $denoTemp -Recurse -Force -ErrorAction SilentlyContinue
            }

            Set-State "tools" 35 "Preparing converter..." "Checking FFmpeg"

            if (-not (Test-Path -LiteralPath $Ffmpeg)) {
                $ffmpegZip = Join-Path $ToolsFolder "ffmpeg.zip"
                $ffmpegTemp = Join-Path $ToolsFolder ("ffmpeg_temp_" + [guid]::NewGuid().ToString("N"))

                Download-File `
                    -Uri "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" `
                    -Destination $ffmpegZip `
                    -StartPercent 36 `
                    -EndPercent 52 `
                    -Label "Downloading FFmpeg..."

                New-Item -ItemType Directory -Path $ffmpegTemp -Force | Out-Null
                Expand-Archive -LiteralPath $ffmpegZip -DestinationPath $ffmpegTemp -Force

                $ffmpegFound = Get-ChildItem -LiteralPath $ffmpegTemp -Filter "ffmpeg.exe" -Recurse -File |
                    Select-Object -First 1
                $ffprobeFound = Get-ChildItem -LiteralPath $ffmpegTemp -Filter "ffprobe.exe" -Recurse -File |
                    Select-Object -First 1

                if (-not $ffmpegFound) {
                    throw "ffmpeg.exe was not found in the downloaded archive."
                }

                Copy-Item -LiteralPath $ffmpegFound.FullName -Destination $Ffmpeg -Force

                if ($ffprobeFound) {
                    Copy-Item -LiteralPath $ffprobeFound.FullName -Destination $Ffprobe -Force
                }

                Remove-Item -LiteralPath $ffmpegZip -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $ffmpegTemp -Recurse -Force -ErrorAction SilentlyContinue
            }

            Set-State "metadata" 54 "Reading video information..." "Fetching title"

            $beforeFiles = @(
                Get-ChildItem -LiteralPath $DownloadFolder -Filter "*.mp3" -File -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty FullName
            )

            $outputTemplate = Join-Path $DownloadFolder "%(title)s.%(ext)s"

            $psi = New-Object Diagnostics.ProcessStartInfo
            $psi.FileName = $YtDlp
            $psi.Arguments = @(
                "--no-playlist",
                "--newline",
                "--progress",
                "--js-runtimes", "`"deno:$Deno`"",
                "--remote-components", "`"ejs:npm`"",
                "--ffmpeg-location", "`"$ToolsFolder`"",
                "--extract-audio",
                "--audio-format", "mp3",
                "--audio-quality", "0",
                "--embed-thumbnail",
                "--embed-metadata",
                "--windows-filenames",
                "--retries", "10",
                "--fragment-retries", "10",
                "-o", "`"$outputTemplate`"",
                "`"$Url`""
            ) -join " "

            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true

            $process = New-Object Diagnostics.Process
            $process.StartInfo = $psi
            $null = $process.Start()

            $lastLine = ""

            while (-not $process.StandardOutput.EndOfStream) {
                $line = $process.StandardOutput.ReadLine()

                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $lastLine = $line

                    if ($line -match "\[download\]\s+([0-9.]+)%") {
                        $downloadPercent = [double]$matches[1]
                        $uiProgress = 56 + ($downloadPercent * 0.33)
                        Set-State "download" $uiProgress "Downloading audio..." $line
                    }
                    elseif ($line -match "\[ExtractAudio\]") {
                        Set-State "convert" 92 "Converting to MP3..." "Extracting high-quality audio"
                    }
                    elseif ($line -match "\[Metadata\]|\[EmbedThumbnail\]") {
                        Set-State "finish" 97 "Finishing MP3..." "Embedding metadata and thumbnail"
                    }
                    else {
                        Set-State "download" 58 "Downloading audio..." $line
                    }
                }
            }

            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            if ($process.ExitCode -ne 0) {
                if ([string]::IsNullOrWhiteSpace($stderr)) {
                    $stderr = "yt-dlp exited with code $($process.ExitCode)."
                }

                throw $stderr.Trim()
            }

            $afterFiles = @(
                Get-ChildItem -LiteralPath $DownloadFolder -Filter "*.mp3" -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending
            )

            $created = $afterFiles |
                Where-Object { $_.FullName -notin $beforeFiles } |
                Select-Object -First 1

            if (-not $created) {
                $created = $afterFiles | Select-Object -First 1
            }

            if (-not $created) {
                throw "The download finished, but no MP3 file was found."
            }

            Set-State "complete" 100 "MP3 ready" "Download completed" $created.FullName
        }
        catch {
            Set-State "error" 0 "Download failed" "" "" $_.Exception.Message
        }
    }

    $script:Worker = [PowerShell]::Create()
    $null = $script:Worker.AddScript($workerScript)
    $null = $script:Worker.AddArgument($url)
    $null = $script:Worker.AddArgument($toolsFolder)
    $null = $script:Worker.AddArgument($downloadFolder)
    $null = $script:Worker.AddArgument($ytDlp)
    $null = $script:Worker.AddArgument($deno)
    $null = $script:Worker.AddArgument($ffmpeg)
    $null = $script:Worker.AddArgument($ffprobe)
    $null = $script:Worker.AddArgument($stateFile)

    $script:WorkerHandle = $script:Worker.BeginInvoke()

    if ($script:Timer) {
        $script:Timer.Stop()
    }

    $script:Timer = New-Object Windows.Threading.DispatcherTimer
    $script:Timer.Interval = [TimeSpan]::FromMilliseconds(180)

    $script:Timer.Add_Tick({
        if (-not (Test-Path -LiteralPath $script:StateFile)) {
            return
        }

        try {
            $raw = Get-Content -LiteralPath $script:StateFile -Raw -ErrorAction Stop

            if ([string]::IsNullOrWhiteSpace($raw)) {
                return
            }

            $state = $raw | ConvertFrom-Json
            $progress = [Math]::Max(0, [Math]::Min(100, [double]$state.progress))

            $ProgressFill.Width = 390 * ($progress / 100.0)
            $ProgressPercent.Text = "$([Math]::Round($progress))%"
            $ProgressTitle.Text = [string]$state.message
            $ProgressStep.Text = [string]$state.detail

            switch ([string]$state.stage) {
                "tools" {
                    $ProgressMessage.Text = "This setup is only required the first time"
                }
                "metadata" {
                    $ProgressMessage.Text = "Connecting to YouTube"
                }
                "download" {
                    $ProgressMessage.Text = "Downloading the video audio"
                }
                "convert" {
                    $ProgressMessage.Text = "Extracting high-quality MP3 audio"
                }
                "finish" {
                    $ProgressMessage.Text = "Saving metadata and thumbnail"
                }
                "complete" {
                    $script:Timer.Stop()

                    if ($script:Worker -and $script:WorkerHandle) {
                        try { $script:Worker.EndInvoke($script:WorkerHandle) } catch {}
                        $script:Worker.Dispose()
                        $script:Worker = $null
                    }

                    $script:OutputFile = [string]$state.output

                    if ($script:OutputFile -and (Test-Path -LiteralPath $script:OutputFile)) {
                        $item = Get-Item -LiteralPath $script:OutputFile
                        $ResultTitle.Text = $item.BaseName
                        $ResultSubtitle.Text = "$(Format-FileSize $item.Length)  |  MP3 audio"
                        $DownloadButton.IsEnabled = $true
                    }

                    Hide-ProgressView
                }
                "error" {
                    $script:Timer.Stop()

                    if ($script:Worker -and $script:WorkerHandle) {
                        try { $script:Worker.EndInvoke($script:WorkerHandle) } catch {}
                        $script:Worker.Dispose()
                        $script:Worker = $null
                    }

                    $message = [string]$state.error

                    if ([string]::IsNullOrWhiteSpace($message)) {
                        $message = "The YouTube video could not be downloaded."
                    }

                    if ($message.Length -gt 700) {
                        $message = $message.Substring(0, 700) + "..."
                    }

                    Hide-ProgressView

                    $ResultTitle.Text = "Download failed"
                    $ResultSubtitle.Text = "Check the link and try again"

                    [Windows.MessageBox]::Show(
                        $message,
                        "YouTube to MP3",
                        "OK",
                        "Error"
                    ) | Out-Null
                }
            }
        }
        catch {
            # The state file may be changing while it is read. Try again next tick.
        }
    })

    $script:Timer.Start()
}

$TopBar.Add_MouseLeftButtonDown({
    if ($_.ChangedButton -eq [Windows.Input.MouseButton]::Left) {
        $Window.DragMove()
    }
})

$MinimizeButton.Add_Click({
    $Window.WindowState = "Minimized"
})

$CloseButton.Add_Click({
    $Window.Close()
})

$CloseButton.Add_MouseEnter({
    $CloseButton.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#E81123")
    $CloseButton.Foreground = [Windows.Media.Brushes]::White
})

$CloseButton.Add_MouseLeave({
    $CloseButton.Background = [Windows.Media.Brushes]::Transparent
    $CloseButton.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#1D222B")
})

$UrlTextBox.Add_TextChanged({
    Update-UrlState
})

$PasteButton.Add_Click({
    try {
        if ([Windows.Clipboard]::ContainsText()) {
            $UrlTextBox.Text = [Windows.Clipboard]::GetText().Trim()
            $UrlTextBox.CaretIndex = $UrlTextBox.Text.Length
        }
    }
    catch {}
})

$ConvertButton.Add_Click({
    Start-YouTubeDownload
})

$UrlTextBox.Add_KeyDown({
    if ($_.Key -eq [Windows.Input.Key]::Enter -and $ConvertButton.IsEnabled) {
        Start-YouTubeDownload
        $_.Handled = $true
    }
})

$DownloadButton.Add_Click({
    if (-not $script:OutputFile -or -not (Test-Path -LiteralPath $script:OutputFile)) {
        return
    }

    try {
        Start-Process explorer.exe -ArgumentList "/select,`"$script:OutputFile`""
    }
    catch {
        Start-Process explorer.exe $script:DownloadFolder
    }
})

$Window.Add_Closing({
    if ($script:Timer) {
        $script:Timer.Stop()
    }

    if ($script:Worker) {
        try { $script:Worker.Stop() } catch {}
        try { $script:Worker.Dispose() } catch {}
    }

    Remove-Item -LiteralPath $script:StateFile -Force -ErrorAction SilentlyContinue
})

Update-UrlState
$Window.ShowDialog() | Out-Null
