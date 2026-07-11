#requires -Version 5.1

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$ErrorActionPreference = 'Continue'

# -----------------------------------------------------------------------------
# NetScope - One-screen PowerShell WPF network scanner
# Flow: Ready -> Loading -> Results
# Detects devices learned through Wi-Fi and Ethernet on the local LAN.
# -----------------------------------------------------------------------------

$script:IsScanning = $false
$script:PingTimeout = 300
$script:PortTimeout = 120

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="NetScope"
        Width="980"
        Height="670"
        MinWidth="980"
        MinHeight="670"
        MaxWidth="980"
        MaxHeight="670"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        ResizeMode="NoResize"
        AllowsTransparency="True"
        Background="Transparent"
        FontFamily="Segoe UI">

    <Window.Resources>
        <Style x:Key="WindowButton" TargetType="Button">
            <Setter Property="Width" Value="42"/>
            <Setter Property="Height" Value="42"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#7B8389"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Root" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Root" Property="Background" Value="#1B2024"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Root" Property="Opacity" Value="0.7"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="CloseButtonStyle" TargetType="Button" BasedOn="{StaticResource WindowButton}">
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#F04464"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Height" Value="44"/>
            <Setter Property="Padding" Value="24,0"/>
            <Setter Property="Background" Value="#FF295D"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#FF4773"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Root"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Root" Property="Opacity" Value="0.88"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Root" Property="Opacity" Value="0.7"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Root" Property="Opacity" Value="0.4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource PrimaryButton}">
            <Setter Property="Height" Value="38"/>
            <Setter Property="Padding" Value="18,0"/>
            <Setter Property="Background" Value="#15191C"/>
            <Setter Property="BorderBrush" Value="#252B2F"/>
            <Setter Property="Foreground" Value="#D9DDE0"/>
        </Style>

        <Style x:Key="AccentProgress" TargetType="ProgressBar">
            <Setter Property="Height" Value="6"/>
            <Setter Property="Background" Value="#15191C"/>
            <Setter Property="Foreground" Value="#FF295D"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Border Background="{TemplateBinding Background}" CornerRadius="3"/>
                            <Border x:Name="PART_Track" CornerRadius="3"/>
                            <Border x:Name="PART_Indicator"
                                    Background="{TemplateBinding Foreground}"
                                    HorizontalAlignment="Left"
                                    CornerRadius="3"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border Margin="10"
            Background="#0B0E10"
            BorderBrush="#252B2F"
            BorderThickness="1"
            CornerRadius="7">
        <Border.Effect>
            <DropShadowEffect Color="Black" BlurRadius="28" ShadowDepth="0" Opacity="0.58"/>
        </Border.Effect>

        <Grid ClipToBounds="True">
            <Grid.RowDefinitions>
                <RowDefinition Height="3"/>
                <RowDefinition Height="42"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <Border Grid.Row="0">
                <Border.Background>
                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                        <GradientStop Color="#FF244F" Offset="0"/>
                        <GradientStop Color="#FF326C" Offset="0.32"/>
                        <GradientStop Color="#B547FF" Offset="0.67"/>
                        <GradientStop Color="#406CFF" Offset="1"/>
                    </LinearGradientBrush>
                </Border.Background>
            </Border>

            <Grid Grid.Row="1" Background="#0D1012">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="220"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="42"/>
                    <ColumnDefinition Width="42"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="15,0,0,0" VerticalAlignment="Center">
                    <TextBlock Text="Net" Foreground="#FF295D" FontSize="16" FontWeight="Bold"/>
                    <TextBlock Text="Scope" Foreground="#D9DDE0" FontSize="16" FontWeight="Bold"/>
                    <TextBlock Text="LAN Scanner" Foreground="#51585D" FontSize="9" Margin="9,4,0,0"/>
                </StackPanel>

                <Grid x:Name="DragArea" Grid.Column="1" Background="#01000000">
                    <TextBlock Text="Wi-Fi &amp; Ethernet Devices"
                               Foreground="#7B8389"
                               FontSize="11"
                               HorizontalAlignment="Center"
                               VerticalAlignment="Center"/>
                </Grid>

                <Button x:Name="MinButton" Grid.Column="2" Style="{StaticResource WindowButton}" Content="&#xE738;"/>
                <Button x:Name="CloseButton" Grid.Column="3" Style="{StaticResource CloseButtonStyle}" Content="&#xE711;"/>
            </Grid>

            <Grid Grid.Row="2" Margin="38,28,38,30">
                <!-- READY STATE -->
                <Grid x:Name="ReadyView">
                    <Border Width="680"
                            Height="430"
                            HorizontalAlignment="Center"
                            VerticalAlignment="Center"
                            Background="Transparent"
                            BorderThickness="0">
                        <StackPanel HorizontalAlignment="Center"
                                    VerticalAlignment="Center"
                                    Width="480">
                            <TextBlock Text="Discover your local devices"
                                       Foreground="#D9DDE0"
                                       FontSize="22"
                                       FontWeight="SemiBold"
                                       HorizontalAlignment="Center"
                                       Margin="0,22,0,0"/>

                            <TextBlock Text="Find devices connected through Wi-Fi or Ethernet on your local network."
                                       Foreground="#7B8389"
                                       FontSize="10.5"
                                       TextWrapping="Wrap"
                                       TextAlignment="Center"
                                       LineHeight="18"
                                       Margin="0,10,0,0"/>

                            <Button x:Name="StartButton"
                                    Style="{StaticResource PrimaryButton}"
                                    Width="220"
                                    Margin="0,25,0,0">
<TextBlock Text="Scan network"/>
                            </Button>

                            <TextBlock x:Name="ReadyHint"
                                       Text="Checking active connection..."
                                       Foreground="#51585D"
                                       FontSize="9.5"
                                       HorizontalAlignment="Center"
                                       Margin="0,14,0,0"/>
                        </StackPanel>
                    </Border>

                    <!-- Hidden values used internally by the scanner. -->
                    <StackPanel Visibility="Collapsed">
                        <TextBlock x:Name="AdapterText"/>
                        <TextBlock x:Name="LocalIPText"/>
                        <TextBlock x:Name="GatewayText"/>
                    </StackPanel>
                </Grid>

                <!-- LOADING STATE -->
                <Grid x:Name="LoadingView" Visibility="Collapsed">
                    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="610">
                            <TextBlock Text="&#xE895;"
                                       FontFamily="Segoe MDL2 Assets"
                                       Foreground="#FF295D"
                                       FontSize="38"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"/>
                            <TextBlock Text="Scanning your local network"
                                       Foreground="#D9DDE0"
                                       FontSize="23"
                                       FontWeight="SemiBold"
                                       HorizontalAlignment="Center"
                                       Margin="0,24,0,0"/>
                            <TextBlock x:Name="ProgressPercent"
                                       Text="0%"
                                       Foreground="#FF4773"
                                       FontSize="14"
                                       FontWeight="SemiBold"
                                       HorizontalAlignment="Center"
                                       Margin="0,10,0,14"/>
                            <ProgressBar x:Name="ScanProgress" Style="{StaticResource AccentProgress}" Width="560" Minimum="0" Maximum="100" Value="0"/>
                            <TextBlock x:Name="LoadingStatus"
                                       Text="Preparing scan..."
                                       Foreground="#7B8389"
                                       FontSize="10.5"
                                       HorizontalAlignment="Center"
                                       Margin="0,18,0,0"/>
                            <TextBlock Text="Please keep this window open while the scan is running."
                                       Foreground="#51585D"
                                       FontSize="9"
                                       HorizontalAlignment="Center"
                                       Margin="0,8,0,0"/>
                    </StackPanel>
                </Grid>

                <!-- RESULTS STATE -->
                <Grid x:Name="ResultsView" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="68"/>
                        <RowDefinition Height="54"/>
                        <RowDefinition Height="27"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <Grid Grid.Row="0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="44"/>
                            <ColumnDefinition Width="14"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="145"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="&#xE716;"
                                   FontFamily="Segoe MDL2 Assets"
                                   Foreground="#FF295D"
                                   FontSize="23"
                                   Width="44"
                                   Height="44"
                                   HorizontalAlignment="Center"
                                   VerticalAlignment="Center"
                                   TextAlignment="Center"/>
                        <StackPanel Grid.Column="2">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="Devices found" Foreground="#D9DDE0" FontSize="21" FontWeight="SemiBold"/>
                                <TextBlock x:Name="DeviceCountText"
                                           Text="0"
                                           Foreground="#39D98A"
                                           FontSize="11"
                                           FontWeight="Bold"
                                           VerticalAlignment="Center"
                                           Margin="10,1,0,0"/>
                            </StackPanel>
                            <TextBlock x:Name="ResultSubtitle" Text="Local devices currently visible to Windows." Foreground="#7B8389" FontSize="10.5" Margin="0,4,0,0"/>
                        </StackPanel>
                        <Button x:Name="ScanAgainButton" Grid.Column="3" Style="{StaticResource SecondaryButton}" Width="145" VerticalAlignment="Top">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,8,0"/>
                                <TextBlock Text="Scan again"/>
                            </StackPanel>
                        </Button>
                    </Grid>

                    <Border Grid.Row="1"
                            Background="Transparent"
                            BorderBrush="#1B2023"
                            BorderThickness="0,0,0,1"
                            Padding="15,0"
                            Margin="0,0,0,10">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="24"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="&#xE774;" FontFamily="Segoe MDL2 Assets" Foreground="#FF295D" FontSize="13" VerticalAlignment="Center"/>
                            <TextBlock x:Name="NetworkSummaryText" Grid.Column="1" Text="Network details" Foreground="#7B8389" FontSize="10" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                            <TextBlock x:Name="ScanTimeText" Grid.Column="2" Text="" Foreground="#51585D" FontSize="9" VerticalAlignment="Center"/>
                        </Grid>
                    </Border>

                    <Grid Grid.Row="2" Margin="15,0,15,7">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="48"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="130"/>
                            <ColumnDefinition Width="190"/>
                            <ColumnDefinition Width="88"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Grid.Column="1" Text="DEVICE" Foreground="#51585D" FontSize="8.5" FontWeight="SemiBold"/>
                        <TextBlock Grid.Column="2" Text="IP ADDRESS" Foreground="#51585D" FontSize="8.5" FontWeight="SemiBold"/>
                        <TextBlock Grid.Column="3" Text="TYPE" Foreground="#51585D" FontSize="8.5" FontWeight="SemiBold"/>
                        <TextBlock Grid.Column="4" Text="STATUS" Foreground="#51585D" FontSize="8.5" FontWeight="SemiBold"/>
                    </Grid>

                    <Border Grid.Row="3" Background="Transparent" BorderThickness="0">
                        <Grid>
                            <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Margin="8,0,8,0">
                                <StackPanel x:Name="DeviceList"/>
                            </ScrollViewer>
                            <StackPanel x:Name="NoDevicesPanel" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed">
                                <TextBlock Text="&#xE946;" FontFamily="Segoe MDL2 Assets" Foreground="#51585D" FontSize="38" HorizontalAlignment="Center"/>
                                <TextBlock Text="No devices were discovered" Foreground="#D9DDE0" FontSize="13" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,12,0,0"/>
                                <TextBlock Text="Check that you are connected to the same router, then scan again." Foreground="#7B8389" FontSize="10" HorizontalAlignment="Center" Margin="0,6,0,0"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

try {
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
}
catch {
    [System.Windows.MessageBox]::Show("The interface could not be loaded.`n`n$($_.Exception.Message)", 'NetScope') | Out-Null
    exit
}

$controlNames = @(
    'DragArea', 'MinButton', 'CloseButton',
    'ReadyView', 'LoadingView', 'ResultsView',
    'StartButton', 'ScanAgainButton',
    'ReadyHint', 'AdapterText', 'LocalIPText', 'GatewayText',
    'ProgressPercent', 'ScanProgress', 'LoadingStatus',
    'DeviceCountText', 'ResultSubtitle', 'NetworkSummaryText', 'ScanTimeText',
    'DeviceList', 'NoDevicesPanel'
)

foreach ($controlName in $controlNames) {
    Set-Variable -Name $controlName -Value $window.FindName($controlName) -Scope Script
}

$script:BrushConverter = New-Object System.Windows.Media.BrushConverter

function New-Brush {
    param([Parameter(Mandatory = $true)][string]$Color)
    return $script:BrushConverter.ConvertFromString($Color)
}

function Invoke-UiRefresh {
    # Correct PowerShell 5.1 dispatcher overload: priority first, delegate second.
    $window.Dispatcher.Invoke(
        [System.Windows.Threading.DispatcherPriority]::Render,
        [Action] { }
    )
}

function Show-State {
    param([ValidateSet('Ready', 'Loading', 'Results')][string]$State)

    $ReadyView.Visibility = [System.Windows.Visibility]::Collapsed
    $LoadingView.Visibility = [System.Windows.Visibility]::Collapsed
    $ResultsView.Visibility = [System.Windows.Visibility]::Collapsed

    switch ($State) {
        'Ready'   { $ReadyView.Visibility = [System.Windows.Visibility]::Visible }
        'Loading' { $LoadingView.Visibility = [System.Windows.Visibility]::Visible }
        'Results' { $ResultsView.Visibility = [System.Windows.Visibility]::Visible }
    }

    Invoke-UiRefresh
}

function Set-ProgressValue {
    param(
        [int]$Value,
        [string]$Status
    )

    $safeValue = [Math]::Max(0, [Math]::Min(100, $Value))
    $ScanProgress.Value = [double]$safeValue
    $ProgressPercent.Text = "$safeValue%"
    $LoadingStatus.Text = $Status
    Invoke-UiRefresh
}

function Convert-IPv4ToNumber {
    param([Parameter(Mandatory = $true)][string]$IPAddress)

    $bytes = [System.Net.IPAddress]::Parse($IPAddress).GetAddressBytes()
    return (
        ([int64]$bytes[0] -shl 24) -bor
        ([int64]$bytes[1] -shl 16) -bor
        ([int64]$bytes[2] -shl 8) -bor
        [int64]$bytes[3]
    )
}

function Convert-NumberToIPv4 {
    param([Parameter(Mandatory = $true)][int64]$Value)

    return '{0}.{1}.{2}.{3}' -f `
        (($Value -shr 24) -band 255), `
        (($Value -shr 16) -band 255), `
        (($Value -shr 8) -band 255), `
        ($Value -band 255)
}

function Get-IPv4ScanRange {
    param(
        [Parameter(Mandatory = $true)][string]$IPAddress,
        [Parameter(Mandatory = $true)][int]$PrefixLength
    )

    if ($PrefixLength -lt 1 -or $PrefixLength -gt 32) {
        $PrefixLength = 24
    }

    # Limit very large corporate/VPN ranges. Known neighbor-table devices are still added.
    $effectivePrefix = $PrefixLength
    $wasLimited = $false
    if ($effectivePrefix -lt 22) {
        $effectivePrefix = 24
        $wasLimited = $true
    }

    $ipNumber = Convert-IPv4ToNumber -IPAddress $IPAddress
    $allBits = [int64]4294967295
    $mask = ($allBits -shl (32 - $effectivePrefix)) -band $allBits
    $networkNumber = $ipNumber -band $mask
    $broadcastNumber = $networkNumber -bor ($allBits -bxor $mask)

    if ($effectivePrefix -ge 31) {
        $firstHost = $networkNumber
        $lastHost = $broadcastNumber
    }
    else {
        $firstHost = $networkNumber + 1
        $lastHost = $broadcastNumber - 1
    }

    $addresses = New-Object 'System.Collections.Generic.List[string]'
    for ($current = $firstHost; $current -le $lastHost; $current++) {
        [void]$addresses.Add((Convert-NumberToIPv4 -Value $current))
    }

    return [PSCustomObject]@{
        Addresses       = @($addresses)
        FirstNumber     = $firstHost
        LastNumber      = $lastHost
        NetworkAddress  = Convert-NumberToIPv4 -Value $networkNumber
        EffectivePrefix = $effectivePrefix
        OriginalPrefix  = $PrefixLength
        WasLimited      = $wasLimited
    }
}

function Get-ActiveNetwork {
    try {
        $candidates = @(
            Get-NetIPConfiguration -ErrorAction Stop |
                Where-Object {
                    $_.IPv4Address -and
                    $_.IPv4DefaultGateway -and
                    $_.NetAdapter.Status -eq 'Up' -and
                    $_.InterfaceAlias -notmatch 'vEthernet|Virtual|VPN|TAP|TUN|Loopback|Bluetooth'
                }
        )

        $network = $candidates |
            Sort-Object {
                $metricInfo = Get-NetIPInterface `
                    -AddressFamily IPv4 `
                    -InterfaceIndex $_.InterfaceIndex `
                    -ErrorAction SilentlyContinue

                if ($metricInfo) { [int]$metricInfo.InterfaceMetric } else { 9999 }
            } |
            Select-Object -First 1

        if (-not $network) {
            $network = Get-NetIPConfiguration |
                Where-Object {
                    $_.IPv4Address -and
                    $_.IPv4DefaultGateway -and
                    $_.NetAdapter.Status -eq 'Up'
                } |
                Select-Object -First 1
        }

        return $network
    }
    catch {
        return $null
    }
}

function Get-ArpTable {
    $table = @{}

    try {
        foreach ($line in (& arp.exe -a 2>$null)) {
            if ($line -match '^\s*(\d{1,3}(?:\.\d{1,3}){3})\s+([0-9A-Fa-f]{2}(?:-[0-9A-Fa-f]{2}){5})\s+') {
                $table[$matches[1]] = $matches[2].ToUpperInvariant()
            }
        }
    }
    catch { }

    return $table
}

function Get-NeighborTable {
    param([Parameter(Mandatory = $true)][int]$InterfaceIndex)

    $table = @{}

    try {
        $neighbors = Get-NetNeighbor `
            -AddressFamily IPv4 `
            -InterfaceIndex $InterfaceIndex `
            -ErrorAction Stop

        foreach ($neighbor in $neighbors) {
            $ip = [string]$neighbor.IPAddress
            $mac = [string]$neighbor.LinkLayerAddress
            $state = [string]$neighbor.State

            if (
                $ip -and
                $mac -match '^[0-9A-Fa-f]{2}(?:[:-][0-9A-Fa-f]{2}){5}$' -and
                $state -notin @('Incomplete', 'Unreachable')
            ) {
                $table[$ip] = $mac.Replace(':', '-').ToUpperInvariant()
            }
        }
    }
    catch { }

    $arp = Get-ArpTable
    foreach ($ip in $arp.Keys) {
        if (-not $table.ContainsKey($ip)) {
            $table[$ip] = $arp[$ip]
        }
    }

    return $table
}

function Get-NetBiosHostName {
    param([Parameter(Mandatory = $true)][string]$IPAddress)

    try {
        foreach ($line in (& nbtstat.exe -A $IPAddress 2>$null)) {
            if ($line -match '^\s*([^\s<]+)\s+<00>\s+UNIQUE') {
                $candidate = $matches[1].Trim()
                if (
                    -not [string]::IsNullOrWhiteSpace($candidate) -and
                    $candidate -ne '__MSBROWSE__' -and
                    $candidate -notmatch 'WORKGROUP|MSHOME'
                ) {
                    return $candidate
                }
            }
        }
    }
    catch { }

    return $null
}

function Get-SafeHostName {
    param([Parameter(Mandatory = $true)][string]$IPAddress)

    try {
        $entry = [System.Net.Dns]::GetHostEntry($IPAddress)
        if ($entry.HostName -and $entry.HostName -ne $IPAddress) {
            return [string]$entry.HostName
        }
    }
    catch { }

    $netBios = Get-NetBiosHostName -IPAddress $IPAddress
    if ($netBios) {
        return [string]$netBios
    }

    return 'Unknown device'
}

function Test-TcpPort {
    param(
        [Parameter(Mandatory = $true)][string]$IPAddress,
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$Timeout = 110
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $asyncResult = $client.BeginConnect($IPAddress, $Port, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($Timeout, $false)) {
            return $false
        }

        $client.EndConnect($asyncResult)
        return $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Get-DeviceClassification {
    param(
        [Parameter(Mandatory = $true)][string]$IPAddress,
        [Parameter(Mandatory = $true)][string]$HostName,
        [int[]]$OpenPorts,
        [string]$Gateway,
        [string]$LocalIP
    )

    $name = $HostName.ToLowerInvariant()
    $glyph = [string][char]0xE946
    $type = 'Unidentified device'

    if ($IPAddress -eq $Gateway) {
        $glyph = [string][char]0xE701
        $type = 'Router'
    }
    elseif ($IPAddress -eq $LocalIP) {
        $glyph = [string][char]0xE7F4
        $type = 'This Windows PC'
    }
    elseif (
        $OpenPorts -contains 9100 -or
        $OpenPorts -contains 631 -or
        $name -match 'printer|epson|canon|laserjet|deskjet|brother[-_. ]?(mfc|dcp|hl|printer)'
    ) {
        $glyph = [string][char]0xE749
        $type = 'Printer'
    }
    elseif (
        $OpenPorts -contains 8008 -or
        $OpenPorts -contains 8009 -or
        $name -match 'chromecast|googlecast|firetv|roku|smarttv|smart-tv|bravia|webos|tizen|television'
    ) {
        $glyph = [string][char]0xE7F4
        $type = 'TV or streaming device'
    }
    elseif ($name -match 'iphone|ipad|ipod' -or $OpenPorts -contains 62078) {
        $glyph = [string][char]0xE8EA
        $type = 'iPhone or iPad'
    }
    elseif ($name -match 'android|galaxy|pixel|phone|tablet|oneplus|xiaomi|redmi|huawei|oppo|realme') {
        $glyph = [string][char]0xE8EA
        $type = 'Android phone or tablet'
    }
    elseif ($name -match 'macbook|imac|mac-mini|macmini') {
        $glyph = [string][char]0xE770
        $type = 'Apple computer'
    }
    elseif (
        $name -match '^desktop-|^laptop-|notebook|surface|windows|^win-|(^|[-_. ])pc$' -or
        $OpenPorts -contains 135 -or
        $OpenPorts -contains 139 -or
        $OpenPorts -contains 445 -or
        $OpenPorts -contains 3389 -or
        $OpenPorts -contains 5357
    ) {
        $glyph = [string][char]0xE7F4
        $type = 'Windows PC'
    }
    elseif ($name -match 'synology|qnap|nas|server') {
        $glyph = [string][char]0xE950
        $type = 'NAS or server'
    }
    elseif ($name -match 'ubuntu|debian|fedora|linux|raspberry|raspberrypi' -or $OpenPorts -contains 22) {
        $glyph = [string][char]0xE770
        $type = 'Linux device'
    }
    elseif (($OpenPorts -contains 80 -or $OpenPorts -contains 443) -and $HostName -eq 'Unknown device') {
        $glyph = [string][char]0xE701
        $type = 'Smart network device'
    }
    elseif ($HostName -eq 'Unknown device') {
        $type = 'Unknown (firewall protected)'
    }

    return [PSCustomObject]@{
        Glyph = $glyph
        Type  = $type
    }
}

function Add-DeviceRow {
    param(
        [Parameter(Mandatory = $true)][string]$Glyph,
        [Parameter(Mandatory = $true)][string]$IPAddress,
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][string]$DeviceType,
        [Parameter(Mandatory = $true)][string]$MAC,
        [Parameter(Mandatory = $true)][string]$Services
    )

    $row = New-Object System.Windows.Controls.Border
    $row.Height = 64
    $row.Margin = [System.Windows.Thickness]::new(0.0)
    $row.CornerRadius = [System.Windows.CornerRadius]::new(0.0)
    $row.Background = [System.Windows.Media.Brushes]::Transparent
    $row.BorderBrush = New-Brush '#1B2023'
    $row.BorderThickness = [System.Windows.Thickness]::new(0.0, 0.0, 0.0, 1.0)
    $row.Padding = [System.Windows.Thickness]::new(14.0, 0.0, 14.0, 0.0)
    $row.ToolTip = "MAC: $MAC`nServices: $Services"

    $grid = New-Object System.Windows.Controls.Grid

    $widths = @(
        [System.Windows.GridLength]::new(48.0),
        [System.Windows.GridLength]::new(1.0, [System.Windows.GridUnitType]::Star),
        [System.Windows.GridLength]::new(130.0),
        [System.Windows.GridLength]::new(190.0),
        [System.Windows.GridLength]::new(88.0)
    )

    foreach ($width in $widths) {
        $column = New-Object System.Windows.Controls.ColumnDefinition
        $column.Width = $width
        [void]$grid.ColumnDefinitions.Add($column)
    }

    $iconBox = New-Object System.Windows.Controls.Border
    $iconBox.Width = 32
    $iconBox.Height = 32
    $iconBox.CornerRadius = [System.Windows.CornerRadius]::new(0.0)
    $iconBox.Background = [System.Windows.Media.Brushes]::Transparent
    $iconBox.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    $iconBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    $iconText = New-Object System.Windows.Controls.TextBlock
    $iconText.Text = $Glyph
    $iconText.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe MDL2 Assets')
    $iconText.Foreground = New-Brush '#FF295D'
    $iconText.FontSize = 16
    $iconText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $iconText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $iconBox.Child = $iconText
    [System.Windows.Controls.Grid]::SetColumn($iconBox, 0)
    [void]$grid.Children.Add($iconBox)

    $namePanel = New-Object System.Windows.Controls.StackPanel
    $namePanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    $nameText = New-Object System.Windows.Controls.TextBlock
    $nameText.Text = $HostName
    $nameText.Foreground = New-Brush '#D9DDE0'
    $nameText.FontSize = 11
    $nameText.FontWeight = [System.Windows.FontWeights]::SemiBold
    $nameText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis

    $detailText = New-Object System.Windows.Controls.TextBlock
    if ($MAC -ne 'Unknown') {
        $detailText.Text = $MAC
    }
    else {
        $detailText.Text = $Services
    }
    $detailText.Foreground = New-Brush '#51585D'
    $detailText.FontSize = 8.5
    $detailText.Margin = [System.Windows.Thickness]::new(0.0, 4.0, 0.0, 0.0)
    $detailText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis

    [void]$namePanel.Children.Add($nameText)
    [void]$namePanel.Children.Add($detailText)
    [System.Windows.Controls.Grid]::SetColumn($namePanel, 1)
    [void]$grid.Children.Add($namePanel)

    $ipText = New-Object System.Windows.Controls.TextBlock
    $ipText.Text = $IPAddress
    $ipText.Foreground = New-Brush '#BFC5CA'
    $ipText.FontSize = 10
    $ipText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [System.Windows.Controls.Grid]::SetColumn($ipText, 2)
    [void]$grid.Children.Add($ipText)

    $typeText = New-Object System.Windows.Controls.TextBlock
    $typeText.Text = $DeviceType
    $typeText.Foreground = New-Brush '#AAB0B5'
    $typeText.FontSize = 9.5
    $typeText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $typeText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [System.Windows.Controls.Grid]::SetColumn($typeText, 3)
    [void]$grid.Children.Add($typeText)

    $statusPanel = New-Object System.Windows.Controls.StackPanel
    $statusPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $statusPanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 7
    $dot.Height = 7
    $dot.Fill = New-Brush '#39D98A'
    $dot.Margin = [System.Windows.Thickness]::new(0.0, 0.0, 7.0, 0.0)

    $statusText = New-Object System.Windows.Controls.TextBlock
    $statusText.Text = 'Online'
    $statusText.Foreground = New-Brush '#6EE7B7'
    $statusText.FontSize = 9.5
    $statusText.FontWeight = [System.Windows.FontWeights]::SemiBold
    $statusText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    [void]$statusPanel.Children.Add($dot)
    [void]$statusPanel.Children.Add($statusText)
    [System.Windows.Controls.Grid]::SetColumn($statusPanel, 4)
    [void]$grid.Children.Add($statusPanel)

    $row.Child = $grid
    [void]$DeviceList.Children.Add($row)
}

function Update-NetworkPreview {
    $network = Get-ActiveNetwork

    if (-not $network) {
        $AdapterText.Text = 'No active network'
        $LocalIPText.Text = '-'
        $GatewayText.Text = '-'
        $ReadyHint.Text = 'Connect to Wi-Fi or Ethernet before scanning.'
        $StartButton.IsEnabled = $false
        return $null
    }

    $ipv4Info = @(
        $network.IPv4Address |
            Where-Object { $_.IPAddress -and $_.IPAddress -notlike '169.254.*' }
    ) | Select-Object -First 1

    if (-not $ipv4Info) {
        $ReadyHint.Text = 'No usable IPv4 address was found.'
        $StartButton.IsEnabled = $false
        return $null
    }

    $localIP = [string]$ipv4Info.IPAddress
    $prefixLength = [int]$ipv4Info.PrefixLength
    $gateway = [string]$network.IPv4DefaultGateway.NextHop
    $adapterName = [string]$network.InterfaceAlias

    $AdapterText.Text = $adapterName
    $LocalIPText.Text = "$localIP/$prefixLength"
    $GatewayText.Text = $gateway
    $ReadyHint.Text = "Ready on $adapterName - $localIP/$prefixLength"
    $StartButton.IsEnabled = $true

    return $network
}

function Show-InlineError {
    param([string]$Message)

    $ReadyHint.Text = $Message
    $ReadyHint.Foreground = New-Brush '#F04464'
    Show-State -State 'Ready'
}

function Invoke-UdpNeighborProbe {
    param(
        [Parameter(Mandatory = $true)][string[]]$Addresses,
        [int]$Port = 9,
        [int]$ProgressStart = 8,
        [int]$ProgressEnd = 20,
        [string]$StatusText = 'Waking and locating local devices...'
    )

    if (-not $Addresses -or $Addresses.Count -eq 0) {
        return
    }

    $payload = [byte[]](0x4E, 0x53)
    $total = [Math]::Max(1, $Addresses.Count)
    $batchSize = 32

    for ($offset = 0; $offset -lt $Addresses.Count; $offset += $batchSize) {
        $udp = New-Object System.Net.Sockets.UdpClient
        try {
            $last = [Math]::Min($offset + $batchSize - 1, $Addresses.Count - 1)
            for ($index = $offset; $index -le $last; $index++) {
                try {
                    [void]$udp.Send($payload, $payload.Length, [string]$Addresses[$index], $Port)
                }
                catch { }
            }
        }
        finally {
            $udp.Close()
        }

        # A small pause gives Windows time to complete ARP resolution for the batch.
        Start-Sleep -Milliseconds 90

        $completed = [Math]::Min($offset + $batchSize, $Addresses.Count)
        $progress = $ProgressStart + [int](($completed / $total) * ($ProgressEnd - $ProgressStart))
        Set-ProgressValue -Value $progress -Status "$StatusText $completed of $($Addresses.Count)"
    }

    Start-Sleep -Milliseconds 450
}

function Invoke-PingSweep {
    param(
        [Parameter(Mandatory = $true)][string[]]$Addresses,
        [int]$Timeout = 300,
        [int]$ProgressStart = 20,
        [int]$ProgressEnd = 38,
        [string]$StatusText = 'Checking device responses...'
    )

    $alive = New-Object 'System.Collections.Generic.List[string]'
    if (-not $Addresses -or $Addresses.Count -eq 0) {
        return @($alive)
    }

    $jobs = New-Object 'System.Collections.Generic.List[object]'
    $total = [Math]::Max(1, $Addresses.Count)
    $sent = 0

    foreach ($ip in $Addresses) {
        $sent++
        $ping = New-Object System.Net.NetworkInformation.Ping
        try {
            $task = $ping.SendPingAsync([string]$ip, $Timeout)
            [void]$jobs.Add([PSCustomObject]@{
                IP   = [string]$ip
                Ping = $ping
                Task = $task
            })
        }
        catch {
            $ping.Dispose()
        }

        if (($sent % 32) -eq 0 -or $sent -eq $Addresses.Count) {
            $progress = $ProgressStart + [int](($sent / $total) * (($ProgressEnd - $ProgressStart) * 0.45))
            Set-ProgressValue -Value $progress -Status "$StatusText $sent of $($Addresses.Count)"
        }
    }

    $waitSeconds = [Math]::Max(4.0, ($Timeout / 1000.0) + 3.0)
    $deadline = [DateTime]::UtcNow.AddSeconds($waitSeconds)

    do {
        $pending = @($jobs | Where-Object { -not $_.Task.IsCompleted }).Count
        if ($pending -le 0) {
            break
        }

        Start-Sleep -Milliseconds 55
        Invoke-UiRefresh
    }
    while ([DateTime]::UtcNow -lt $deadline)

    $read = 0
    foreach ($job in $jobs) {
        $read++
        try {
            if (
                $job.Task.IsCompleted -and
                $job.Task.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion -and
                $job.Task.Result.Status -eq [System.Net.NetworkInformation.IPStatus]::Success
            ) {
                [void]$alive.Add([string]$job.IP)
            }
        }
        catch { }
        finally {
            $job.Ping.Dispose()
        }

        if (($read % 40) -eq 0 -or $read -eq $jobs.Count) {
            $fraction = $read / [Math]::Max(1, $jobs.Count)
            $mid = $ProgressStart + (($ProgressEnd - $ProgressStart) * 0.45)
            $progress = [int]($mid + ($fraction * (($ProgressEnd - $ProgressStart) * 0.55)))
            Set-ProgressValue -Value $progress -Status 'Reading device responses...'
        }
    }

    return @($alive)
}

function Add-NeighborSnapshot {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Discovered,
        [Parameter(Mandatory = $true)][hashtable]$MacCache,
        [Parameter(Mandatory = $true)][hashtable]$Neighbors,
        [Parameter(Mandatory = $true)]$ScanRange
    )

    foreach ($neighborIP in $Neighbors.Keys) {
        try {
            $ip = [string]$neighborIP
            $number = Convert-IPv4ToNumber -IPAddress $ip
            if ($number -ge $ScanRange.FirstNumber -and $number -le $ScanRange.LastNumber) {
                $Discovered[$ip] = $true
                if ($Neighbors[$ip]) {
                    $MacCache[$ip] = [string]$Neighbors[$ip]
                }
            }
        }
        catch { }
    }
}

function Start-NetworkScan {
    if ($script:IsScanning) {
        return
    }

    $script:IsScanning = $true
    $StartButton.IsEnabled = $false
    $ScanAgainButton.IsEnabled = $false
    $ReadyHint.Foreground = New-Brush '#51585D'
    $DeviceList.Children.Clear()
    $NoDevicesPanel.Visibility = [System.Windows.Visibility]::Collapsed
    Show-State -State 'Loading'
    Set-ProgressValue -Value 2 -Status 'Finding your active network...'

    try {
        $network = Get-ActiveNetwork
        if (-not $network) {
            throw 'No active Wi-Fi or Ethernet connection was found.'
        }

        $ipv4Info = @(
            $network.IPv4Address |
                Where-Object { $_.IPAddress -and $_.IPAddress -notlike '169.254.*' }
        ) | Select-Object -First 1

        if (-not $ipv4Info) {
            throw 'Could not detect a usable local IPv4 address.'
        }

        $localIP = [string]$ipv4Info.IPAddress
        $prefixLength = [int]$ipv4Info.PrefixLength
        $gateway = [string]$network.IPv4DefaultGateway.NextHop
        $adapterName = [string]$network.InterfaceAlias
        $interfaceIndex = [int]$network.InterfaceIndex

        $scanRange = Get-IPv4ScanRange -IPAddress $localIP -PrefixLength $prefixLength
        $rangeLabel = "$($scanRange.NetworkAddress)/$($scanRange.EffectivePrefix)"
        $addresses = @($scanRange.Addresses)

        # Keep everything discovered by any method. An ARP/MAC reply counts even if ICMP is blocked.
        $discovered = @{}
        $macCache = @{}

        if ($localIP) { $discovered[$localIP] = $true }
        if ($gateway) { $discovered[$gateway] = $true }

        Set-ProgressValue -Value 6 -Status "Starting reliable discovery on $rangeLabel..."

        # Pass 1: UDP unicast traffic forces Windows to ARP for every address.
        Invoke-UdpNeighborProbe `
            -Addresses $addresses `
            -Port 9 `
            -ProgressStart 7 `
            -ProgressEnd 19 `
            -StatusText 'First discovery pass...'

        # Pass 2: normal ICMP discovery catches devices that answer ping.
        $firstPing = Invoke-PingSweep `
            -Addresses $addresses `
            -Timeout $script:PingTimeout `
            -ProgressStart 19 `
            -ProgressEnd 38 `
            -StatusText 'Checking first responses...'

        foreach ($ip in $firstPing) {
            $discovered[[string]$ip] = $true
        }

        Set-ProgressValue -Value 40 -Status 'Reading the first Ethernet and Wi-Fi neighbor snapshot...'
        Start-Sleep -Milliseconds 400
        $snapshot1 = Get-NeighborTable -InterfaceIndex $interfaceIndex
        Add-NeighborSnapshot -Discovered $discovered -MacCache $macCache -Neighbors $snapshot1 -ScanRange $scanRange

        # Retry only addresses not yet seen. A longer timeout helps sleeping phones and protected PCs.
        $retryAddresses = @(
            $addresses | Where-Object { -not $discovered.ContainsKey([string]$_) }
        )

        if ($retryAddresses.Count -gt 0) {
            Invoke-UdpNeighborProbe `
                -Addresses $retryAddresses `
                -Port 445 `
                -ProgressStart 42 `
                -ProgressEnd 52 `
                -StatusText 'Retrying devices that did not answer...'

            $secondPing = Invoke-PingSweep `
                -Addresses $retryAddresses `
                -Timeout 650 `
                -ProgressStart 52 `
                -ProgressEnd 68 `
                -StatusText 'Waiting longer for sleeping devices...'

            foreach ($ip in $secondPing) {
                $discovered[[string]$ip] = $true
            }
        }
        else {
            Set-ProgressValue -Value 68 -Status 'All visible addresses answered during the first pass.'
        }

        # Final snapshots are deliberately repeated; neighbor entries can appear slightly late.
        Set-ProgressValue -Value 70 -Status 'Collecting final MAC address responses...'
        Start-Sleep -Milliseconds 550
        $snapshot2 = Get-NeighborTable -InterfaceIndex $interfaceIndex
        Add-NeighborSnapshot -Discovered $discovered -MacCache $macCache -Neighbors $snapshot2 -ScanRange $scanRange

        Start-Sleep -Milliseconds 500
        $snapshot3 = Get-NeighborTable -InterfaceIndex $interfaceIndex
        Add-NeighborSnapshot -Discovered $discovered -MacCache $macCache -Neighbors $snapshot3 -ScanRange $scanRange

        $online = @(
            $discovered.Keys |
                Where-Object { $_ -match '^\d{1,3}(?:\.\d{1,3}){3}$' } |
                Sort-Object { [version]$_ } |
                Select-Object -Unique
        )

        Set-ProgressValue -Value 73 -Status "Found $($online.Count) device(s). Identifying them..."

        $portsToCheck = @(22, 80, 135, 139, 443, 445, 631, 3389, 5357, 62078, 8008, 8009, 9100)
        $serviceNames = @{
            22 = 'SSH'; 80 = 'HTTP'; 135 = 'Windows RPC'; 139 = 'NetBIOS';
            443 = 'HTTPS'; 445 = 'SMB'; 631 = 'Printer'; 3389 = 'Remote Desktop';
            5357 = 'Windows Discovery'; 62078 = 'Apple Device'; 8008 = 'Chromecast';
            8009 = 'Chromecast'; 9100 = 'Printer'
        }

        $results = New-Object 'System.Collections.Generic.List[object]'
        $deviceIndex = 0

        foreach ($ip in $online) {
            $deviceIndex++
            $identifyProgress = 73 + [int](($deviceIndex / [Math]::Max(1, $online.Count)) * 23)
            Set-ProgressValue -Value $identifyProgress -Status "Identifying $ip ($deviceIndex of $($online.Count))..."

            $hostName = Get-SafeHostName -IPAddress $ip
            if ($ip -eq $localIP) {
                $hostName = "$env:COMPUTERNAME (This PC)"
            }

            $openPorts = New-Object 'System.Collections.Generic.List[int]'
            $services = New-Object 'System.Collections.Generic.List[string]'

            foreach ($port in $portsToCheck) {
                if (Test-TcpPort -IPAddress $ip -Port $port -Timeout $script:PortTimeout) {
                    [void]$openPorts.Add([int]$port)
                    [void]$services.Add([string]$serviceNames[$port])
                }
            }

            $classification = Get-DeviceClassification `
                -IPAddress $ip `
                -HostName $hostName `
                -OpenPorts @($openPorts) `
                -Gateway $gateway `
                -LocalIP $localIP

            if ($macCache.ContainsKey($ip)) {
                $mac = [string]$macCache[$ip]
            }
            else {
                $mac = 'Unknown'
            }

            if ($services.Count -gt 0) {
                $serviceText = @($services) -join ', '
            }
            else {
                $serviceText = 'No common services detected'
            }

            [void]$results.Add([PSCustomObject]@{
                Glyph    = [string]$classification.Glyph
                IP       = [string]$ip
                HostName = [string]$hostName
                Type     = [string]$classification.Type
                MAC      = [string]$mac
                Services = [string]$serviceText
            })
        }

        Set-ProgressValue -Value 97 -Status 'Building the device list...'

        foreach ($result in $results) {
            Add-DeviceRow `
                -Glyph $result.Glyph `
                -IPAddress $result.IP `
                -HostName $result.HostName `
                -DeviceType $result.Type `
                -MAC $result.MAC `
                -Services $result.Services
        }

        $DeviceCountText.Text = [string]$results.Count
        $ResultSubtitle.Text = 'Multi-pass scan complete. Devices blocking ping are included when their MAC address responds.'
        $NetworkSummaryText.Text = "$adapterName  |  Your IP: $localIP/$prefixLength  |  Router: $gateway  |  Range: $rangeLabel"
        $ScanTimeText.Text = 'Scanned ' + (Get-Date -Format 'HH:mm:ss')

        if ($results.Count -eq 0) {
            $NoDevicesPanel.Visibility = [System.Windows.Visibility]::Visible
        }

        Set-ProgressValue -Value 100 -Status 'Scan complete'
        Start-Sleep -Milliseconds 180
        Show-State -State 'Results'
    }
    catch {
        $message = $_.Exception.Message
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = 'The network scan could not be completed.'
        }

        Show-InlineError -Message $message
    }
    finally {
        $script:IsScanning = $false
        $StartButton.IsEnabled = $true
        $ScanAgainButton.IsEnabled = $true
    }
}

$CloseButton.Add_Click({
    if (-not $script:IsScanning) {
        $window.Close()
    }
})

$MinButton.Add_Click({
    $window.WindowState = [System.Windows.WindowState]::Minimized
})

$DragArea.Add_MouseLeftButtonDown({
    if ($_.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        $window.DragMove()
    }
})

$StartButton.Add_Click({ Start-NetworkScan })
$ScanAgainButton.Add_Click({ Start-NetworkScan })

Show-State -State 'Ready'
[void](Update-NetworkPreview)
$window.Add_ContentRendered({ [void](Update-NetworkPreview) })
[void]$window.ShowDialog()
