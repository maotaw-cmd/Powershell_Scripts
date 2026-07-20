#requires -version 5.1
<#
Maotaw Windows Debloat - PowerShell/WPF edition
Standalone transparent UI with reversible registry tweaks.
Run with: powershell.exe -ExecutionPolicy Bypass -File .\Maotaw_Windows_Debloat_PowerShell.ps1
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    try {
        $arguments = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $PSCommandPath)
        ) -join ' '
        Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs | Out-Null
    }
    catch {
        [System.Windows.MessageBox]::Show(
            'Administrator permission is required to change Windows policies.',
            'Maotaw Windows Debloat',
            'OK',
            'Warning'
        ) | Out-Null
    }
    exit
}

$script:AppName = 'Maotaw Windows Debloat'
$script:BackupDirectory = Join-Path $env:LOCALAPPDATA 'MaotawWindowsDebloat'
$script:BackupPath = Join-Path $script:BackupDirectory 'registry-backup.json'
$script:CurrentOperation = $null
$script:OperationQueue = New-Object System.Collections.ArrayList
$script:OperationResults = New-Object System.Collections.ArrayList
$script:OperationIndex = 0
$script:OperationMode = ''

$script:Tweaks = @(
    [pscustomobject]@{ Id='DisableAdvertisingId'; Group='Privacy & Windows Content'; Label='Disable Advertising ID'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name='Enabled'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableTailoredExperiences'; Group='Privacy & Windows Content'; Label='Disable Tailored Experiences'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\Privacy'; Name='TailoredExperiencesWithDiagnosticDataEnabled'; Value=0 },
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableTailoredExperiencesWithDiagnosticData'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisableAppLaunchTracking'; Group='Privacy & Windows Content'; Label='Disable App Launch Tracking'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_TrackProgs'; Value=0 }
    )},
    [pscustomobject]@{ Id='ReduceDiagnosticData'; Group='Privacy & Windows Content'; Label='Reduce Diagnostic Data'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name='AllowTelemetry'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisableActivityHistory'; Group='Privacy & Windows Content'; Label='Disable Activity History'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\System'; Name='EnableActivityFeed'; Value=0 },
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\System'; Name='PublishUserActivities'; Value=0 },
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\System'; Name='UploadUserActivities'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableClipboardSync'; Group='Privacy & Windows Content'; Label='Disable Clipboard Sync'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\System'; Name='AllowClipboardHistory'; Value=0 },
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\System'; Name='AllowCrossDeviceClipboard'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableTypingPersonalization'; Group='Privacy & Windows Content'; Label='Disable Typing Personalization'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\InputPersonalization'; Name='RestrictImplicitTextCollection'; Value=1 },
        @{ Root='HKCU'; Path='Software\Microsoft\InputPersonalization'; Name='RestrictImplicitInkCollection'; Value=1 },
        @{ Root='HKCU'; Path='Software\Microsoft\InputPersonalization\TrainedDataStore'; Name='HarvestContacts'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableFeedbackRequests'; Group='Privacy & Windows Content'; Label='Disable Feedback Requests'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Siuf\Rules'; Name='NumberOfSIUFInPeriod'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableWindowsTips'; Group='Privacy & Windows Content'; Label='Disable Windows Tips'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338388Enabled'; Value=0 },
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338389Enabled'; Value=0 },
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353694Enabled'; Value=0 },
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353696Enabled'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableSuggestedApps'; Group='Privacy & Windows Content'; Label='Disable Suggested Apps'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SilentInstalledAppsEnabled'; Value=0 },
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableWindowsConsumerFeatures'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisableWelcomeExperience'; Group='Privacy & Windows Content'; Label='Disable Welcome Experience'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-310093Enabled'; Value=0 },
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SoftLandingEnabled'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableLockScreenTips'; Group='Privacy & Windows Content'; Label='Disable Lock Screen Tips'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='RotatingLockScreenOverlayEnabled'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableCopilot'; Group='Privacy & Windows Content'; Label='Disable Windows Copilot'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisableRecall'; Group='Privacy & Windows Content'; Label='Disable Recall Analysis'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='DisableAIDataAnalysis'; Value=1 },
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='AllowRecallEnablement'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableErrorReporting'; Group='Privacy & Windows Content'; Label='Disable Windows Error Reporting'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name='Disabled'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisableLocation'; Group='Privacy & Windows Content'; Label='Disable Location'; Default=$false; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'; Name='DisableLocation'; Value=1 }
    )},
    [pscustomobject]@{ Id='BlockCamera'; Group='Privacy & Windows Content'; Label='Block App Camera Access'; Default=$false; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name='LetAppsAccessCamera'; Value=2 }
    )},
    [pscustomobject]@{ Id='BlockMicrophone'; Group='Privacy & Windows Content'; Label='Block App Microphone Access'; Default=$false; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name='LetAppsAccessMicrophone'; Value=2 }
    )},

    [pscustomobject]@{ Id='DisableWidgets'; Group='Performance & Security'; Label='Disable Widgets'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Dsh'; Name='AllowNewsAndInterests'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableSearchHighlights'; Group='Performance & Security'; Label='Disable Search Highlights'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name='IsDynamicSearchBoxEnabled'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableBingSearch'; Group='Performance & Security'; Label='Disable Bing Search Suggestions'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Policies\Microsoft\Windows\Explorer'; Name='DisableSearchBoxSuggestions'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisableEdgeStartupBoost'; Group='Performance & Security'; Label='Disable Edge Startup Boost'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Edge'; Name='StartupBoostEnabled'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableEdgeBackground'; Group='Performance & Security'; Label='Disable Edge Background Mode'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Edge'; Name='BackgroundModeEnabled'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableDeliveryUploads'; Group='Performance & Security'; Label='Disable Update Peer Uploads'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name='DODownloadMode'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableGameDvr'; Group='Performance & Security'; Label='Disable Game DVR & Capture'; Default=$false; Changes=@(
        @{ Root='HKCU'; Path='System\GameConfigStore'; Name='GameDVR_Enabled'; Value=0 },
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name='AppCaptureEnabled'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableBackgroundApps'; Group='Performance & Security'; Label='Disable Background Store Apps'; Default=$false; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Name='GlobalUserDisabled'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisableNotifications'; Group='Performance & Security'; Label='Disable Notifications'; Default=$false; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\PushNotifications'; Name='ToastEnabled'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableRemoteAssistance'; Group='Performance & Security'; Label='Disable Remote Assistance'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name='fAllowToGetHelp'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableRemoteDesktop'; Group='Performance & Security'; Label='Disable Remote Desktop'; Default=$false; Changes=@(
        @{ Root='HKLM'; Path='SYSTEM\CurrentControlSet\Control\Terminal Server'; Name='fDenyTSConnections'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisableAutoRun'; Group='Performance & Security'; Label='Disable AutoRun'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='NoDriveTypeAutoRun'; Value=255 }
    )},
    [pscustomobject]@{ Id='DisableAutoPlay'; Group='Performance & Security'; Label='Disable AutoPlay'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers'; Name='DisableAutoplay'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisableInsecureGuestLogons'; Group='Performance & Security'; Label='Block Insecure SMB Guest Logons'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation'; Name='AllowInsecureGuestAuth'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableAnonymousSidEnumeration'; Group='Performance & Security'; Label='Block Anonymous SID Enumeration'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SYSTEM\CurrentControlSet\Control\Lsa'; Name='RestrictAnonymousSAM'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisablePasswordReveal'; Group='Performance & Security'; Label='Disable Password Reveal Button'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\CredUI'; Name='DisablePasswordReveal'; Value=1 }
    )},
    [pscustomobject]@{ Id='DisableScriptHost'; Group='Performance & Security'; Label='Disable Windows Script Host'; Default=$false; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Microsoft\Windows Script Host\Settings'; Name='Enabled'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableOneDrive'; Group='Performance & Security'; Label='Disable OneDrive Sync'; Default=$false; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Policies\Microsoft\Windows\OneDrive'; Name='DisableFileSyncNGSC'; Value=1 }
    )},
    [pscustomobject]@{ Id='HideMeetNow'; Group='Performance & Security'; Label='Hide Meet Now'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='HideSCAMeetNow'; Value=1 }
    )},
    [pscustomobject]@{ Id='HidePeopleBar'; Group='Performance & Security'; Label='Hide People Taskbar Button'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People'; Name='PeopleBand'; Value=0 }
    )},
    [pscustomobject]@{ Id='HideTaskbarSearch'; Group='Performance & Security'; Label='Hide Taskbar Search Box'; Default=$false; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\Search'; Name='SearchboxTaskbarMode'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisableTransparency'; Group='Performance & Security'; Label='Disable Transparency Effects'; Default=$false; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='EnableTransparency'; Value=0 }
    )},
    [pscustomobject]@{ Id='PreferPerformanceVisuals'; Group='Performance & Security'; Label='Prefer Performance Visual Effects'; Default=$false; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name='VisualFXSetting'; Value=2 }
    )},
    [pscustomobject]@{ Id='RemoveStartupDelay'; Group='Performance & Security'; Label='Remove Startup App Delay'; Default=$true; Changes=@(
        @{ Root='HKCU'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'; Name='StartupDelayInMSec'; Value=0 }
    )},
    [pscustomobject]@{ Id='DisablePowerThrottling'; Group='Performance & Security'; Label='Disable Power Throttling'; Default=$false; Changes=@(
        @{ Root='HKLM'; Path='SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'; Name='PowerThrottlingOff'; Value=1 }
    )},
    [pscustomobject]@{ Id='OptimizeMultimedia'; Group='Performance & Security'; Label='Optimize Multimedia Scheduling'; Default=$true; Changes=@(
        @{ Root='HKLM'; Path='SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name='SystemResponsiveness'; Value=10 }
    )}
)

function Get-RegistryProviderPath {
    param([string]$Root, [string]$Path)
    if ($Root -eq 'HKLM') { return "Registry::HKEY_LOCAL_MACHINE\$Path" }
    return "Registry::HKEY_CURRENT_USER\$Path"
}

function Get-RegistrySnapshot {
    param($Change)
    $providerPath = Get-RegistryProviderPath -Root $Change.Root -Path $Change.Path
    $snapshot = [ordered]@{
        Root = $Change.Root
        Path = $Change.Path
        Name = $Change.Name
        Existed = $false
        Kind = 'DWord'
        Value = $null
    }
    try {
        if (Test-Path -LiteralPath $providerPath) {
            $key = Get-Item -LiteralPath $providerPath
            $valueNames = $key.GetValueNames()
            if ($valueNames -contains $Change.Name) {
                $snapshot.Existed = $true
                $snapshot.Value = $key.GetValue($Change.Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $snapshot.Kind = $key.GetValueKind($Change.Name).ToString()
            }
        }
    }
    catch { }
    return [pscustomobject]$snapshot
}

function Set-RegistryChange {
    param($Change)

    if ($null -eq $Change) { throw 'Registry change is empty.' }
    if ($Change -is [System.Array]) { throw 'Registry change was incorrectly passed as an array.' }

    $root = [string]$Change.Root
    $path = [string]$Change.Path
    $name = [string]$Change.Name
    $value = [Convert]::ToInt32($Change.Value, [Globalization.CultureInfo]::InvariantCulture)

    if ([string]::IsNullOrWhiteSpace($root) -or [string]::IsNullOrWhiteSpace($path) -or [string]::IsNullOrWhiteSpace($name)) {
        throw 'Registry change has a missing Root, Path, or Name.'
    }

    $providerPath = Get-RegistryProviderPath -Root $root -Path $path
    if (-not (Test-Path -LiteralPath $providerPath)) {
        New-Item -Path $providerPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $providerPath -Name $name -Value $value -PropertyType DWord -Force | Out-Null
}

function Restore-RegistrySnapshot {
    param($Snapshot)
    $providerPath = Get-RegistryProviderPath -Root $Snapshot.Root -Path $Snapshot.Path
    if ($Snapshot.Existed) {
        if (-not (Test-Path -LiteralPath $providerPath)) {
            New-Item -Path $providerPath -Force | Out-Null
        }
        $propertyType = switch ($Snapshot.Kind) {
            'String' { 'String' }
            'ExpandString' { 'ExpandString' }
            'Binary' { 'Binary' }
            'MultiString' { 'MultiString' }
            'QWord' { 'QWord' }
            default { 'DWord' }
        }
        New-ItemProperty -LiteralPath $providerPath -Name $Snapshot.Name -Value $Snapshot.Value -PropertyType $propertyType -Force | Out-Null
    }
    elseif (Test-Path -LiteralPath $providerPath) {
        Remove-ItemProperty -LiteralPath $providerPath -Name $Snapshot.Name -ErrorAction SilentlyContinue
    }
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Maotaw Windows Debloat" Width="796" Height="600"
        WindowStartupLocation="CenterScreen" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent" ResizeMode="NoResize"
        FontFamily="Segoe UI, Arial" Opacity="0.87">
    <Window.Resources>
        <SolidColorBrush x:Key="Accent" Color="#B31622"/>
        <SolidColorBrush x:Key="AccentBright" Color="#D62936"/>
        <SolidColorBrush x:Key="Text" Color="#E6E6E6"/>
        <SolidColorBrush x:Key="Muted" Color="#7D8189"/>
        <SolidColorBrush x:Key="Muted2" Color="#5E636A"/>
        <SolidColorBrush x:Key="Panel" Color="#F507090C"/>
        <SolidColorBrush x:Key="PanelBorder" Color="#111317"/>
        <SolidColorBrush x:Key="RowHover" Color="#B8111418"/>

        <Style x:Key="ToggleStyle" TargetType="CheckBox">
            <Setter Property="Foreground" Value="{StaticResource Text}"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Height" Value="28"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Border x:Name="Row" Background="Transparent" CornerRadius="5" Padding="7,0,6,0">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="32"/></Grid.ColumnDefinitions>
                                <ContentPresenter VerticalAlignment="Center"/>
                                <Border x:Name="Track" Grid.Column="1" Width="27" Height="14" CornerRadius="7"
                                        Background="#24272C" HorizontalAlignment="Right" VerticalAlignment="Center">
                                    <Ellipse x:Name="Knob" Width="10" Height="10" Fill="#777B82"
                                             HorizontalAlignment="Left" Margin="2,0,0,0"/>
                                </Border>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Row" Property="Background" Value="{StaticResource RowHover}"/></Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Track" Property="Background" Value="{StaticResource Accent}"/>
                                <Setter TargetName="Knob" Property="Fill" Value="#F4F4F4"/>
                                <Setter TargetName="Knob" Property="HorizontalAlignment" Value="Right"/>
                                <Setter TargetName="Knob" Property="Margin" Value="0,0,2,0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ActionButton" TargetType="Button">
            <Setter Property="Foreground" Value="#E6E6E6"/><Setter Property="Background" Value="#101216"/>
            <Setter Property="BorderBrush" Value="#17191D"/><Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Cursor" Value="Hand"/><Setter Property="FontSize" Value="12"/><Setter Property="Height" Value="29"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
                <Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                        BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="#171A1F"/></Trigger>
                    <Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Opacity" Value="0.8"/></Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate></Setter.Value></Setter>
        </Style>
        <Style x:Key="AccentButton" TargetType="Button" BasedOn="{StaticResource ActionButton}">
            <Setter Property="Background" Value="{StaticResource Accent}"/><Setter Property="BorderBrush" Value="{StaticResource Accent}"/>
        </Style>
    </Window.Resources>

    <Border x:Name="WindowBorder" CornerRadius="8" Background="#FF010203" BorderBrush="#15171A" BorderThickness="1" ClipToBounds="True">
        <Grid>
            <Canvas x:Name="ParticleCanvas" IsHitTestVisible="False" Panel.ZIndex="0"/>
            <Grid Panel.ZIndex="1">
                <Grid.RowDefinitions><RowDefinition Height="70"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <Border x:Name="TopBar" Grid.Row="0" Background="#FF020304">
                    <Grid>
                        <Canvas Width="42" Height="42" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="17,13,0,0">
                            <Polygon Points="7,30 21,6 35,30" Stroke="#B31622" StrokeThickness="2" Fill="Transparent"/>
                            <Polygon Points="14,27 21,14 28,27" Fill="#B31622"/>
                        </Canvas>
                        <Button x:Name="GearButton" Width="44" Height="44" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,10,12,0"
                                Background="Transparent" BorderThickness="0" Foreground="#7D8189" Cursor="Hand">
                            <Viewbox Width="18" Height="18">
                                <Grid Width="24" Height="24">
                                    <Path Stroke="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}"
                                          StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                          StrokeLineJoin="Round" Fill="Transparent"
                                          Data="M12,8.2 A3.8,3.8 0 1 0 12,15.8 A3.8,3.8 0 1 0 12,8.2 M12,2.5 L13.2,5.1 L16,5.8 L18.3,4.2 L19.8,5.7 L18.2,8 L18.9,10.8 L21.5,12 L18.9,13.2 L18.2,16 L19.8,18.3 L18.3,19.8 L16,18.2 L13.2,18.9 L12,21.5 L10.8,18.9 L8,18.2 L5.7,19.8 L4.2,18.3 L5.8,16 L5.1,13.2 L2.5,12 L5.1,10.8 L5.8,8 L4.2,5.7 L5.7,4.2 L8,5.8 L10.8,5.1 Z"/>
                                </Grid>
                            </Viewbox>
                        </Button>
                    </Grid>
                </Border>

                <Grid x:Name="MainView" Grid.Row="1">
                    <Border Margin="20,12,411,24" Background="{StaticResource Panel}" BorderBrush="{StaticResource PanelBorder}" BorderThickness="1" CornerRadius="8">
                        <Grid><Grid.RowDefinitions><RowDefinition Height="39"/><RowDefinition Height="*"/><RowDefinition Height="31"/></Grid.RowDefinitions>
                            <TextBlock Text="Privacy, ads &amp; Windows content" Margin="14,0,0,0" VerticalAlignment="Center" Foreground="{StaticResource Text}" FontWeight="SemiBold" FontSize="12"/>
                            <StackPanel x:Name="PrivacyPanel" Grid.Row="1" Margin="5,0,5,0"/>
                            <TextBlock Grid.Row="2" Text="Reversible privacy choices. Core Windows security stays enabled."
                                       Margin="14,0,10,0" VerticalAlignment="Center" Foreground="{StaticResource Muted2}" FontSize="10"/>
                        </Grid>
                    </Border>
                    <Border Margin="403,12,20,24" Background="{StaticResource Panel}" BorderBrush="{StaticResource PanelBorder}" BorderThickness="1" CornerRadius="8">
                        <Grid><Grid.RowDefinitions><RowDefinition Height="39"/><RowDefinition Height="*"/><RowDefinition Height="38"/></Grid.RowDefinitions>
                            <TextBlock Text="Debloat, smoothness &amp; hardening" Margin="14,0,0,0" VerticalAlignment="Center" Foreground="{StaticResource Text}" FontWeight="SemiBold" FontSize="12"/>
                            <StackPanel x:Name="SystemPanel" Grid.Row="1" Margin="5,0,5,0"/>
                            <Grid Grid.Row="2" Margin="12,3,12,6"><Grid.ColumnDefinitions><ColumnDefinition Width="116"/><ColumnDefinition Width="*"/><ColumnDefinition Width="139"/></Grid.ColumnDefinitions>
                                <Button x:Name="RestoreButton" Grid.Column="0" Style="{StaticResource ActionButton}">
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                        <Viewbox Width="13" Height="13" Margin="0,0,7,0">
                                            <Canvas Width="16" Height="16">
                                                <Path Stroke="#E6E6E6" StrokeThickness="1.7" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" Fill="Transparent"
                                                      Data="M3.2,6.2 A5.2,5.2 0 1 1 3.4,11.2 M3.2,6.2 L3.2,2.8 M3.2,6.2 L6.6,6.2"/>
                                            </Canvas>
                                        </Viewbox>
                                        <TextBlock Text="Restore" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <Button x:Name="ApplyButton" Grid.Column="2" Style="{StaticResource AccentButton}">
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                        <Viewbox Width="13" Height="13" Margin="0,0,7,0">
                                            <Canvas Width="16" Height="16">
                                                <Path Stroke="#FFFFFF" StrokeThickness="2" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" Fill="Transparent"
                                                      Data="M2.5,8.2 L6.3,12 L13.7,4.2"/>
                                            </Canvas>
                                        </Viewbox>
                                        <TextBlock Text="Apply tweaks" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                            </Grid>
                        </Grid>
                    </Border>
                </Grid>

                <Grid x:Name="SettingsView" Grid.Row="1" Visibility="Collapsed">
                    <Border Margin="24,14,24,16" Background="{StaticResource Panel}" BorderBrush="{StaticResource PanelBorder}" BorderThickness="1" CornerRadius="8">
                        <Grid Margin="8,0,8,0"><Grid.RowDefinitions>
                            <RowDefinition Height="39"/><RowDefinition Height="29"/><RowDefinition Height="33"/><RowDefinition Height="33"/>
                            <RowDefinition Height="16"/><RowDefinition Height="31"/><RowDefinition Height="28"/><RowDefinition Height="36"/><RowDefinition Height="36"/>
                            <RowDefinition Height="16"/><RowDefinition Height="31"/><RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                            <TextBlock Text="Settings &amp; optional tweaks" Margin="6,0,0,0" VerticalAlignment="Center" Foreground="{StaticResource Text}" FontWeight="SemiBold" FontSize="12"/>
                            <TextBlock Grid.Row="1" Text="Appearance" Margin="6,0,0,0" VerticalAlignment="Center" Foreground="{StaticResource Muted}" FontWeight="SemiBold" FontSize="12"/>
                            <Grid Grid.Row="2" Margin="6,0,6,0"><TextBlock Text="Accent color" Foreground="{StaticResource Text}" VerticalAlignment="Center"/><Button x:Name="AccentColorButton" Width="42" Height="20" HorizontalAlignment="Right" Background="#B31622" BorderBrush="#25282D"/></Grid>
                            <Grid Grid.Row="3" Margin="6,0,6,0"><TextBlock Text="Window tint" Foreground="{StaticResource Text}" VerticalAlignment="Center"/><Button x:Name="TintColorButton" Width="42" Height="20" HorizontalAlignment="Right" Background="#FFFFFF" BorderBrush="#25282D"/></Grid>
                            <Border Grid.Row="4" Height="1" Background="#17191D" VerticalAlignment="Center" Margin="6,0,6,0"/>
                            <TextBlock Grid.Row="5" Text="Background" Margin="6,0,0,0" VerticalAlignment="Center" Foreground="{StaticResource Muted}" FontWeight="SemiBold" FontSize="12"/>
                            <CheckBox x:Name="ParticlesToggle" Grid.Row="6" Content="Background particles" IsChecked="True" Style="{StaticResource ToggleStyle}" Margin="0,0,0,0"/>
                            <Grid Grid.Row="7" Margin="7,0,7,0"><Grid.ColumnDefinitions><ColumnDefinition Width="150"/><ColumnDefinition Width="*"/><ColumnDefinition Width="42"/></Grid.ColumnDefinitions>
                                <TextBlock Text="Particle speed" Foreground="{StaticResource Text}" VerticalAlignment="Center"/><Slider x:Name="ParticleSpeed" Grid.Column="1" Minimum="4" Maximum="60" Value="22" VerticalAlignment="Center"/><TextBlock Grid.Column="2" Text="22" x:Name="ParticleSpeedText" Foreground="{StaticResource Muted}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                            <Grid Grid.Row="8" Margin="7,0,7,0"><Grid.ColumnDefinitions><ColumnDefinition Width="150"/><ColumnDefinition Width="*"/><ColumnDefinition Width="42"/></Grid.ColumnDefinitions>
                                <TextBlock Text="Particle amount" Foreground="{StaticResource Text}" VerticalAlignment="Center"/><Slider x:Name="ParticleAmount" Grid.Column="1" Minimum="8" Maximum="70" Value="34" VerticalAlignment="Center"/><TextBlock Grid.Column="2" Text="34" x:Name="ParticleAmountText" Foreground="{StaticResource Muted}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                            <Border Grid.Row="9" Height="1" Background="#17191D" VerticalAlignment="Center" Margin="6,0,6,0"/>
                            <TextBlock Grid.Row="10" Text="Optional debloat" Margin="6,0,0,0" VerticalAlignment="Center" Foreground="{StaticResource Muted}" FontWeight="SemiBold" FontSize="12"/>
                            <StackPanel x:Name="OptionalPanel" Grid.Row="11" Margin="0,0,0,0"/>
                        </Grid>
                    </Border>
                </Grid>

                <Grid x:Name="ProgressView" Grid.RowSpan="2" Visibility="Collapsed">
                    <StackPanel Width="506" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,-12,0,0">
                        <TextBlock x:Name="ProgressTitle" Text="Optimizing Windows" Foreground="{StaticResource Text}" FontSize="19" FontWeight="Bold" HorizontalAlignment="Center"/>
                        <TextBlock x:Name="ProgressCurrent" Foreground="{StaticResource Muted}" FontSize="10" HorizontalAlignment="Center" Margin="0,13,0,25"/>
                        <Border x:Name="ProgressTrack" Height="6" CornerRadius="3" Background="#15191F" BorderBrush="#111317" BorderThickness="1" ClipToBounds="True">
                            <Border x:Name="ProgressFill" Width="0" HorizontalAlignment="Left" CornerRadius="3" Background="{StaticResource Accent}"/>
                        </Border>
                        <TextBlock x:Name="ProgressPercent" Text="0%" Foreground="{StaticResource AccentBright}" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,13,0,0"/>
                        <TextBlock x:Name="ProgressHint" Text="Do not close the application while settings are being changed." Foreground="{StaticResource Muted2}" FontSize="10" HorizontalAlignment="Center" Margin="0,20,0,0"/>
                    </StackPanel>
                </Grid>

                <Grid x:Name="LogView" Grid.RowSpan="2" Visibility="Collapsed" Margin="28,0,28,24">
                    <Grid.RowDefinitions><RowDefinition Height="154"/><RowDefinition Height="*"/><RowDefinition Height="48"/></Grid.RowDefinitions>
                    <StackPanel VerticalAlignment="Bottom" Margin="0,0,0,7">
                        <TextBlock x:Name="LogTitle" Foreground="{StaticResource Text}" FontSize="19" FontWeight="Bold"/>
                        <TextBlock x:Name="LogSummary" Foreground="#43D17D" FontSize="12" FontWeight="SemiBold" Margin="0,5,0,0"/>
                    </StackPanel>
                    <Border Grid.Row="1" Background="#F007090C" BorderBrush="#111317" BorderThickness="1" CornerRadius="9" Padding="14,10">
                        <TextBox x:Name="LogText" Background="Transparent" BorderThickness="0" Foreground="#7D8189" FontFamily="Segoe UI" FontSize="10"
                                 IsReadOnly="True" AcceptsReturn="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"/>
                    </Border>
                    <Button x:Name="BackButton" Grid.Row="2" Width="146" Height="31" HorizontalAlignment="Right" VerticalAlignment="Bottom" Content="Back to tweaks" Style="{StaticResource AccentButton}"/>
                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$TopBar = $window.FindName('TopBar')
$MainView = $window.FindName('MainView')
$SettingsView = $window.FindName('SettingsView')
$ProgressView = $window.FindName('ProgressView')
$LogView = $window.FindName('LogView')
$PrivacyPanel = $window.FindName('PrivacyPanel')
$SystemPanel = $window.FindName('SystemPanel')
$OptionalPanel = $window.FindName('OptionalPanel')
$ApplyButton = $window.FindName('ApplyButton')
$RestoreButton = $window.FindName('RestoreButton')
$BackButton = $window.FindName('BackButton')
$GearButton = $window.FindName('GearButton')
$ProgressTitle = $window.FindName('ProgressTitle')
$ProgressCurrent = $window.FindName('ProgressCurrent')
$ProgressTrack = $window.FindName('ProgressTrack')
$ProgressFill = $window.FindName('ProgressFill')
$ProgressPercent = $window.FindName('ProgressPercent')
$ProgressHint = $window.FindName('ProgressHint')
$LogTitle = $window.FindName('LogTitle')
$LogSummary = $window.FindName('LogSummary')
$LogText = $window.FindName('LogText')
$ParticleCanvas = $window.FindName('ParticleCanvas')
$ParticlesToggle = $window.FindName('ParticlesToggle')
$ParticleSpeed = $window.FindName('ParticleSpeed')
$ParticleAmount = $window.FindName('ParticleAmount')
$ParticleSpeedText = $window.FindName('ParticleSpeedText')
$ParticleAmountText = $window.FindName('ParticleAmountText')
$AccentColorButton = $window.FindName('AccentColorButton')
$TintColorButton = $window.FindName('TintColorButton')
$WindowBorder = $window.FindName('WindowBorder')

$privacyIds = @('DisableAdvertisingId','DisableTailoredExperiences','DisableAppLaunchTracking','ReduceDiagnosticData','DisableActivityHistory','DisableClipboardSync','DisableTypingPersonalization','DisableFeedbackRequests','DisableWindowsTips','DisableSuggestedApps','DisableWelcomeExperience','DisableLockScreenTips','DisableCopilot','DisableRecall')
$systemIds = @('DisableWidgets','DisableSearchHighlights','DisableBingSearch','DisableEdgeStartupBoost','DisableEdgeBackground','DisableDeliveryUploads','DisableGameDvr','DisableBackgroundApps','DisableErrorReporting','RemoveStartupDelay','DisableTransparency','PreferPerformanceVisuals','DisableRemoteAssistance','DisableAutoRun')
$optionalIds = @('HideMeetNow','HidePeopleBar','HideTaskbarSearch','DisableOneDrive','DisablePowerThrottling','OptimizeMultimedia')
$displayLabels = @{
'DisableAdvertisingId'='Disable advertising ID'; 'DisableTailoredExperiences'='Disable tailored experiences'; 'DisableAppLaunchTracking'='Disable app-launch tracking';
'ReduceDiagnosticData'='Reduce diagnostic data'; 'DisableActivityHistory'='Disable activity history'; 'DisableClipboardSync'='Disable clipboard sync';
'DisableTypingPersonalization'='Disable typing personalization'; 'DisableFeedbackRequests'='Disable feedback requests'; 'DisableWindowsTips'='Disable Windows tips';
'DisableSuggestedApps'='Disable suggested apps'; 'DisableWelcomeExperience'='Disable welcome experience'; 'DisableLockScreenTips'='Disable lock-screen tips';
'DisableCopilot'='Disable Copilot'; 'DisableRecall'='Disable Recall data analysis'; 'DisableWidgets'='Disable widgets';
'DisableSearchHighlights'='Disable search highlights'; 'DisableBingSearch'='Disable Bing search suggestions'; 'DisableEdgeStartupBoost'='Disable Edge startup boost';
'DisableEdgeBackground'='Disable Edge background mode'; 'DisableDeliveryUploads'='Disable update peer uploads'; 'DisableGameDvr'='Disable Game DVR / capture';
'DisableBackgroundApps'='Disable background Store apps'; 'DisableErrorReporting'='Disable error reporting'; 'RemoveStartupDelay'='Remove startup app delay';
'DisableTransparency'='Disable transparency effects'; 'PreferPerformanceVisuals'='Prefer performance visuals'; 'DisableRemoteAssistance'='Disable Remote Assistance';
'DisableAutoRun'='Disable AutoRun / AutoPlay'; 'HideMeetNow'='Hide Meet Now'; 'HidePeopleBar'='Hide People taskbar button';
'HideTaskbarSearch'='Hide taskbar search box'; 'DisableOneDrive'='Disable OneDrive file sync'; 'DisablePowerThrottling'='Disable power throttling';
'OptimizeMultimedia'='Optimize multimedia scheduling'
}

$script:ToggleControls = @{}
foreach ($tweak in $script:Tweaks) {
    if (($privacyIds -notcontains $tweak.Id) -and ($systemIds -notcontains $tweak.Id) -and ($optionalIds -notcontains $tweak.Id)) { continue }
    $checkBox = New-Object System.Windows.Controls.CheckBox
    $checkBox.Content = if ($displayLabels.ContainsKey($tweak.Id)) { $displayLabels[$tweak.Id] } else { $tweak.Label }
    $checkBox.IsChecked = [bool]$tweak.Default
    $checkBox.Style = $window.Resources['ToggleStyle']
    $checkBox.Tag = $tweak.Id
    $script:ToggleControls[$tweak.Id] = $checkBox
    if ($privacyIds -contains $tweak.Id) { [void]$PrivacyPanel.Children.Add($checkBox) }
    elseif ($systemIds -contains $tweak.Id) { [void]$SystemPanel.Children.Add($checkBox) }
    else { [void]$OptionalPanel.Children.Add($checkBox) }
}
if ($script:ToggleControls.ContainsKey('DisableAutoRun')) { $script:ToggleControls['DisableAutoPlay'] = $script:ToggleControls['DisableAutoRun'] }

function Show-View {
    param([ValidateSet('Main','Progress','Log')] [string]$Name)
    $MainView.Visibility = if ($Name -eq 'Main') { 'Visible' } else { 'Collapsed' }
    $SettingsView.Visibility = 'Collapsed'
    $GearButton.Visibility = if ($Name -eq 'Main') { 'Visible' } else { 'Collapsed' }
    $ProgressView.Visibility = if ($Name -eq 'Progress') { 'Visible' } else { 'Collapsed' }
    $LogView.Visibility = if ($Name -eq 'Log') { 'Visible' } else { 'Collapsed' }
}

function Update-ProgressUi {
    param([int]$Percent, [string]$Current)
    $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
    $ProgressPercent.Text = "$safePercent%"
    $ProgressCurrent.Text = $Current
    $availableWidth = $ProgressTrack.ActualWidth
    if ($availableWidth -le 0) { $availableWidth = 520 }
    $ProgressFill.Width = $availableWidth * ($safePercent / 100.0)
}

function Save-Backup {
    param([object[]]$Snapshots)
    if (-not (Test-Path -LiteralPath $script:BackupDirectory)) {
        New-Item -ItemType Directory -Path $script:BackupDirectory -Force | Out-Null
    }
    $backupObject = [ordered]@{
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Computer = $env:COMPUTERNAME
        Entries = $Snapshots
    }
    $backupObject | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:BackupPath -Encoding UTF8
}

function Get-SelectedChanges {
    $selected = New-Object System.Collections.ArrayList
    foreach ($tweak in $script:Tweaks) {
        if (-not $script:ToggleControls.ContainsKey($tweak.Id)) { continue }
        if ($script:ToggleControls[$tweak.Id].IsChecked -eq $true) {
            foreach ($change in $tweak.Changes) {
                $copy = [ordered]@{
                    TweakId = $tweak.Id
                    Label = $tweak.Label
                    Root = [string]$change.Root
                    Path = [string]$change.Path
                    Name = [string]$change.Name
                    Value = [int]$change.Value
                }
                [void]$selected.Add([pscustomobject]$copy)
            }
        }
    }
    # Return each registry change as its own pipeline object.
    # Do not use a leading comma here; that wraps all changes into one Object[]
    # and causes Root/Path/Name/Value to become arrays.
    return $selected.ToArray()
}

function Finish-Operation {
    $successCount = @($script:OperationResults | Where-Object { $_.Success }).Count
    $failureCount = @($script:OperationResults | Where-Object { -not $_.Success }).Count
    Update-ProgressUi -Percent 100 -Current 'Completed'
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)
    Start-Sleep -Milliseconds 350

    if ($script:OperationMode -eq 'Apply') {
        $LogTitle.Text = 'Windows optimization complete'
        $LogSummary.Text = "$successCount applied, $failureCount failed. Restart or sign out for every policy to fully refresh."
    }
    else {
        $LogTitle.Text = 'Windows restore complete'
        $LogSummary.Text = "$successCount restored, $failureCount failed. Restart or sign out for every policy to fully refresh."
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("$($script:AppName) - $($script:OperationMode) results")
    $lines.Add(('=' * 72))
    $lines.Add('')
    foreach ($result in $script:OperationResults) {
        $status = if ($result.Success) { if ($script:OperationMode -eq 'Apply') { '[APPLIED]' } else { '[RESTORED]' } } else { '[FAILED]' }
        $lines.Add("$status $($result.Label)")
        $lines.Add("         $($result.Root)\$($result.Path) -> $($result.Name)")
        if (-not $result.Success -and $result.Message) { $lines.Add("         $($result.Message)") }
        $lines.Add('')
    }
    if ($script:OperationMode -eq 'Apply') {
        $lines.Add("Backup: $($script:BackupPath)")
    }
    $lines.Add('')
    $lines.Add('Some changes require Windows Explorer, sign-out, or a restart.')
    $LogText.Text = $lines -join [Environment]::NewLine
    $LogText.ScrollToHome()
    Show-View -Name Log
}

function Process-NextOperation {
    if ($script:OperationIndex -ge $script:OperationQueue.Count) {
        Finish-Operation
        return
    }

    $item = $script:OperationQueue[$script:OperationIndex]
    $ProgressCurrent.Text = $item.Label
    $percentBefore = [int](($script:OperationIndex / [Math]::Max(1, $script:OperationQueue.Count)) * 100)
    Update-ProgressUi -Percent $percentBefore -Current $item.Label
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)

    $success = $true
    $message = ''
    try {
        if ($script:OperationMode -eq 'Apply') {
            Set-RegistryChange -Change $item
        }
        else {
            Restore-RegistrySnapshot -Snapshot $item
        }
    }
    catch {
        $success = $false
        $message = $_.Exception.Message
    }

    [void]$script:OperationResults.Add([pscustomobject]@{
        Success = $success
        Label = $item.Label
        Root = $item.Root
        Path = $item.Path
        Name = $item.Name
        Message = $message
    })

    $script:OperationIndex++
    $percentAfter = [int](($script:OperationIndex / [Math]::Max(1, $script:OperationQueue.Count)) * 100)
    Update-ProgressUi -Percent $percentAfter -Current $item.Label
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)
    Start-Sleep -Milliseconds 38
    Process-NextOperation
}

function Start-Apply {
    $changes = @(Get-SelectedChanges | ForEach-Object { $_ })
    if ($changes.Count -eq 0) {
        [System.Windows.MessageBox]::Show('Select at least one tweak.', $script:AppName, 'OK', 'Information') | Out-Null
        return
    }

    $snapshots = New-Object System.Collections.ArrayList
    foreach ($change in $changes) {
        $snapshot = Get-RegistrySnapshot -Change $change
        $snapshot | Add-Member -NotePropertyName Label -NotePropertyValue $change.Label -Force
        [void]$snapshots.Add($snapshot)
    }
    Save-Backup -Snapshots $snapshots.ToArray()

    $script:OperationQueue.Clear()
    foreach ($change in $changes) { [void]$script:OperationQueue.Add($change) }
    $script:OperationResults.Clear()
    $script:OperationIndex = 0
    $script:OperationMode = 'Apply'
    $ProgressTitle.Text = 'Optimizing Windows'
    $ProgressHint.Text = 'Do not close the application while settings are being changed.'
    Show-View -Name Progress
    Update-ProgressUi -Percent 0 -Current 'Preparing registry backup...'
    $window.Dispatcher.BeginInvoke([Action]{ Process-NextOperation }, [Windows.Threading.DispatcherPriority]::Background) | Out-Null
}

function Start-Restore {
    if (-not (Test-Path -LiteralPath $script:BackupPath)) {
        [System.Windows.MessageBox]::Show('No backup was found. Apply tweaks once before using Restore.', $script:AppName, 'OK', 'Information') | Out-Null
        return
    }

    try {
        $backup = Get-Content -LiteralPath $script:BackupPath -Raw | ConvertFrom-Json
        $entries = @($backup.Entries | ForEach-Object { $_ })
    }
    catch {
        [System.Windows.MessageBox]::Show("The backup file could not be read.`n$($_.Exception.Message)", $script:AppName, 'OK', 'Error') | Out-Null
        return
    }

    if ($entries.Count -eq 0) {
        [System.Windows.MessageBox]::Show('The backup contains no registry entries.', $script:AppName, 'OK', 'Information') | Out-Null
        return
    }

    $script:OperationQueue.Clear()
    foreach ($entry in $entries) { [void]$script:OperationQueue.Add($entry) }
    $script:OperationResults.Clear()
    $script:OperationIndex = 0
    $script:OperationMode = 'Restore'
    $ProgressTitle.Text = 'Restoring Windows'
    $ProgressHint.Text = 'Do not close the application while settings are being restored.'
    Show-View -Name Progress
    Update-ProgressUi -Percent 0 -Current 'Loading registry backup...'
    $window.Dispatcher.BeginInvoke([Action]{ Process-NextOperation }, [Windows.Threading.DispatcherPriority]::Background) | Out-Null
}

$TopBar.Add_MouseLeftButtonDown({
    if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
        $window.DragMove()
    }
})
$ApplyButton.Add_Click({ Start-Apply })
$RestoreButton.Add_Click({ Start-Restore })
$BackButton.Add_Click({ Show-View -Name Main })
$window.Add_KeyDown({ if ($_.Key -eq 'Escape') { $window.Close() } })
$window.Add_ContentRendered({ Update-ProgressUi -Percent 0 -Current '' })



Add-Type -AssemblyName System.Windows.Forms, System.Drawing
function Select-UiColor {
    param([System.Windows.Controls.Button]$Button, [string]$ResourceName, [bool]$IsWindowTint = $false)
    $dialog = New-Object System.Windows.Forms.ColorDialog
    $dialog.FullOpen = $true
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $c = [System.Windows.Media.Color]::FromRgb($dialog.Color.R, $dialog.Color.G, $dialog.Color.B)
    $brush = New-Object System.Windows.Media.SolidColorBrush $c
    $Button.Background = $brush
    if ($IsWindowTint) {
        $darkR = [byte][Math]::Min(255, [int](1 + $dialog.Color.R * 0.035))
        $darkG = [byte][Math]::Min(255, [int](2 + $dialog.Color.G * 0.035))
        $darkB = [byte][Math]::Min(255, [int](3 + $dialog.Color.B * 0.035))
        $WindowBorder.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb($darkR,$darkG,$darkB))
    } else {
        $window.Resources[$ResourceName] = $brush
        $bright = [System.Windows.Media.Color]::FromRgb([byte][Math]::Min(255,$dialog.Color.R+35),[byte][Math]::Min(255,$dialog.Color.G+20),[byte][Math]::Min(255,$dialog.Color.B+20))
        $window.Resources['AccentBright'] = New-Object System.Windows.Media.SolidColorBrush $bright
    }
}
$AccentColorButton.Add_Click({ Select-UiColor -Button $AccentColorButton -ResourceName 'Accent' })
$TintColorButton.Add_Click({ Select-UiColor -Button $TintColorButton -ResourceName '' -IsWindowTint $true })

$script:SettingsOpen = $false
$GearButton.Add_Click({
    $script:SettingsOpen = -not $script:SettingsOpen
    $MainView.Visibility = if ($script:SettingsOpen) { 'Collapsed' } else { 'Visible' }
    $SettingsView.Visibility = if ($script:SettingsOpen) { 'Visible' } else { 'Collapsed' }
    $GearButton.Foreground = if ($script:SettingsOpen) { $window.Resources['AccentBright'] } else { $window.Resources['Muted'] }
})

$ParticleSpeed.Add_ValueChanged({ $ParticleSpeedText.Text = [string][int]$ParticleSpeed.Value })
$ParticleAmount.Add_ValueChanged({ $ParticleAmountText.Text = [string][int]$ParticleAmount.Value })

$script:Particles = New-Object System.Collections.Generic.List[object]
$random = New-Object System.Random
for ($i = 0; $i -lt 70; $i++) {
    $dot = New-Object System.Windows.Shapes.Ellipse
    $size = 1.2 + ($random.NextDouble() * 2.0)
    $dot.Width = $size; $dot.Height = $size
    $dot.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb([byte](40 + $random.Next(55)),255,255,255))
    $ParticleCanvas.Children.Add($dot) | Out-Null
    $script:Particles.Add([pscustomobject]@{ Shape=$dot; X=$random.NextDouble()*790; Y=70+$random.NextDouble()*520; Factor=0.42+$random.NextDouble()*0.72; Phase=$random.NextDouble()*6.28 })
}
$particleTimer = New-Object System.Windows.Threading.DispatcherTimer
$particleTimer.Interval = [TimeSpan]::FromMilliseconds(33)
$particleTimer.Add_Tick({
    $enabled = ($ParticlesToggle.IsChecked -eq $true) -and ($ProgressView.Visibility -ne 'Visible') -and ($LogView.Visibility -ne 'Visible')
    $ParticleCanvas.Visibility = if ($enabled) { 'Visible' } else { 'Collapsed' }
    if (-not $enabled) { return }
    $count = [Math]::Min([int]$ParticleAmount.Value, $script:Particles.Count)
    $speed = [double]$ParticleSpeed.Value * 0.033
    for ($i=0; $i -lt $script:Particles.Count; $i++) {
        $p=$script:Particles[$i]
        $p.Shape.Visibility = if ($i -lt $count) { 'Visible' } else { 'Collapsed' }
        if ($i -ge $count) { continue }
        $p.Y -= $speed * $p.Factor
        if ($p.Y -lt 72) { $p.Y=596; $p.X=$random.NextDouble()*790 }
        [System.Windows.Controls.Canvas]::SetLeft($p.Shape, $p.X + [Math]::Sin(([Environment]::TickCount/1000.0)*0.36+$p.Phase)*8)
        [System.Windows.Controls.Canvas]::SetTop($p.Shape, $p.Y)
    }
})
$particleTimer.Start()

[void]$window.ShowDialog()
