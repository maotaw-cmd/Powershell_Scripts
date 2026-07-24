Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    try {
        $scriptPath = $PSCommandPath
        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            [System.Windows.MessageBox]::Show(
                'Please save the script as NetworkRepair.ps1 and run it again.',
                'Administrator Required',
                'OK',
                'Warning'
            ) | Out-Null
            exit
        }

        Start-Process -FilePath 'powershell.exe' -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $scriptPath)
        ) -Verb RunAs | Out-Null
        exit
    }
    catch {
        [System.Windows.MessageBox]::Show(
            'This tool needs Administrator permission to repair Windows network settings.',
            'Administrator Required',
            'OK',
            'Warning'
        ) | Out-Null
        exit
    }
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Network Repair"
        Width="940"
        Height="680"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        FontFamily="Segoe UI">

    <Window.Resources>
        <LinearGradientBrush x:Key="WindowBackground" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#F8FBFF" Offset="0"/>
            <GradientStop Color="#F1F6FF" Offset="0.55"/>
            <GradientStop Color="#EDF4FF" Offset="1"/>
        </LinearGradientBrush>

        <LinearGradientBrush x:Key="PrimaryButtonBrush" StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#1258F4" Offset="0"/>
            <GradientStop Color="#087DF5" Offset="1"/>
        </LinearGradientBrush>

        <Style x:Key="WindowControlButton" TargetType="Button">
            <Setter Property="Width" Value="38"/>
            <Setter Property="Height" Value="34"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="Foreground" Value="#6E7787"/>
            <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="ControlBorder"
                                Background="{TemplateBinding Background}"
                                CornerRadius="7">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ControlBorder" Property="Background" Value="#E7EEF9"/>
                                <Setter Property="Foreground" Value="#111827"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="ControlBorder" Property="Background" Value="#DCE7F7"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="{StaticResource PrimaryButtonBrush}"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="PrimaryBorder"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="10">
                            <Border.Effect>
                                <DropShadowEffect BlurRadius="14"
                                                  ShadowDepth="4"
                                                  Opacity="0.18"
                                                  Color="#0B65E9"/>
                            </Border.Effect>
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="PrimaryBorder" Property="Opacity" Value="0.91"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="PrimaryBorder" Property="Opacity" Value="0.78"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="PrimaryBorder" Property="Opacity" Value="0.48"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button">
            <Setter Property="Foreground" Value="#172033"/>
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#D8E1EF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="SecondaryBorder"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="9">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="SecondaryBorder" Property="Background" Value="#F4F8FE"/>
                                <Setter TargetName="SecondaryBorder" Property="BorderBrush" Value="#B9CBE4"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="SecondaryBorder" Property="Background" Value="#EAF1FA"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="CheckIcon" TargetType="Border">
            <Setter Property="Width" Value="20"/>
            <Setter Property="Height" Value="20"/>
            <Setter Property="CornerRadius" Value="10"/>
            <Setter Property="Background" Value="#1261F4"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="Margin" Value="0,0,11,0"/>
        </Style>
    </Window.Resources>

    <Border CornerRadius="16"
            BorderBrush="#DDE7F4"
            BorderThickness="1"
            Background="{StaticResource WindowBackground}">
        <Border.Effect>
            <DropShadowEffect BlurRadius="28"
                              ShadowDepth="8"
                              Opacity="0.24"
                              Color="#7486A2"/>
        </Border.Effect>

        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="54"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- Custom title bar -->
            <Grid Grid.Row="0" x:Name="TitleBar" Background="Transparent">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="38"/>
                    <ColumnDefinition Width="38"/>
                    <ColumnDefinition Width="10"/>
                </Grid.ColumnDefinitions>

                <TextBlock Text="Network Repair"
                           Margin="18,0,0,0"
                           VerticalAlignment="Center"
                           Foreground="#111827"
                           FontSize="17"
                           FontWeight="Bold"/>

                <Button x:Name="BtnMinimize"
                        Grid.Column="1"
                        Style="{StaticResource WindowControlButton}"
                        Content="&#xE921;"/>

                <Button x:Name="BtnClose"
                        Grid.Column="2"
                        Style="{StaticResource WindowControlButton}"
                        Content="&#xE8BB;"/>
            </Grid>

            <Grid Grid.Row="1">
                <!-- INTRO -->
                <Grid x:Name="IntroPanel">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="142"/>
                    </Grid.RowDefinitions>

                    <StackPanel Grid.Row="0"
                                Width="720"
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"
                                Margin="0,-10,0,0">

                        <!-- Globe + tool icon -->
                        <Grid Width="112" Height="92" HorizontalAlignment="Center">
                            <TextBlock Text="&#xE774;"
                                       FontFamily="Segoe MDL2 Assets"
                                       FontSize="72"
                                       Foreground="#1762E8"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"/>
                            <Border Width="44"
                                    Height="44"
                                    CornerRadius="22"
                                    Background="#F4F8FF"
                                    HorizontalAlignment="Right"
                                    VerticalAlignment="Bottom"
                                    Margin="0,0,3,1">
                                <TextBlock Text="&#xE90F;"
                                           FontFamily="Segoe MDL2 Assets"
                                           FontSize="33"
                                           Foreground="#1762E8"
                                           HorizontalAlignment="Center"
                                           VerticalAlignment="Center"/>
                            </Border>
                        </Grid>

                        <TextBlock Text="One-Click Windows Network Repair"
                                   Margin="0,18,0,0"
                                   Foreground="#101727"
                                   FontSize="25"
                                   FontWeight="Bold"
                                   TextAlignment="Center"
                                   HorizontalAlignment="Center"/>

                        <TextBlock Text="Fix common internet problems fast. This tool flushes DNS,&#x0a;renews IP, resets Winsock, resets TCP/IP, and&#x0a;restarts network adapters."
                                   Margin="0,10,0,0"
                                   Foreground="#30394A"
                                   FontSize="15"
                                   LineHeight="23"
                                   TextAlignment="Center"
                                   HorizontalAlignment="Center"/>

                        <Button x:Name="BtnStartRepair"
                                Width="258"
                                Height="54"
                                Margin="0,24,0,0"
                                Style="{StaticResource PrimaryButton}"
                                Content="Start Repair"/>
                    </StackPanel>

                    <!-- Feature list -->
                    <Border Grid.Row="1"
                            BorderBrush="#D8E3F1"
                            BorderThickness="0,1,0,0"
                            Background="#F4F8FF"
                            Padding="34,20,34,18">
                        <Grid Width="840" HorizontalAlignment="Center">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="1*"/>
                                <ColumnDefinition Width="1*"/>
                            </Grid.ColumnDefinitions>

                            <StackPanel Grid.Column="0">
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,13">
                                    <Border Style="{StaticResource CheckIcon}">
                                        <TextBlock Text="✓" Foreground="White" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <TextBlock Text="Flushing DNS" Foreground="#273145" FontSize="14" VerticalAlignment="Center"/>
                                </StackPanel>

                                <StackPanel Orientation="Horizontal" Margin="0,0,0,13">
                                    <Border Style="{StaticResource CheckIcon}">
                                        <TextBlock Text="✓" Foreground="White" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <TextBlock Text="Renewing IP" Foreground="#273145" FontSize="14" VerticalAlignment="Center"/>
                                </StackPanel>

                                <StackPanel Orientation="Horizontal">
                                    <Border Style="{StaticResource CheckIcon}">
                                        <TextBlock Text="✓" Foreground="White" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <TextBlock Text="Resetting Winsock" Foreground="#273145" FontSize="14" VerticalAlignment="Center"/>
                                </StackPanel>
                            </StackPanel>

                            <StackPanel Grid.Column="1" Margin="20,0,0,0">
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,13">
                                    <Border Style="{StaticResource CheckIcon}">
                                        <TextBlock Text="✓" Foreground="White" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <TextBlock Text="Resetting TCP/IP" Foreground="#273145" FontSize="14" VerticalAlignment="Center"/>
                                </StackPanel>

                                <StackPanel Orientation="Horizontal" Margin="0,0,0,13">
                                    <Border Style="{StaticResource CheckIcon}">
                                        <TextBlock Text="✓" Foreground="White" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <TextBlock Text="Restarting Adapters" Foreground="#273145" FontSize="14" VerticalAlignment="Center"/>
                                </StackPanel>

                                <StackPanel Orientation="Horizontal">
                                    <Border Style="{StaticResource CheckIcon}">
                                        <TextBlock Text="✓" Foreground="White" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <TextBlock Text="Resetting Proxy" Foreground="#273145" FontSize="14" VerticalAlignment="Center"/>
                                </StackPanel>
                            </StackPanel>
                        </Grid>
                    </Border>
                </Grid>

                <!-- LOADING -->
                <Grid x:Name="LoadingPanel" Visibility="Collapsed">
                    <StackPanel Width="580"
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"
                                Margin="0,-20,0,0">
                        <Grid Width="94" Height="94" HorizontalAlignment="Center">
                            <Ellipse Fill="#E7F0FF"/>
                            <TextBlock Text="&#xE895;"
                                       FontFamily="Segoe MDL2 Assets"
                                       Foreground="#1762E8"
                                       FontSize="46"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"/>
                        </Grid>

                        <TextBlock Text="Repairing network settings..."
                                   Margin="0,22,0,0"
                                   Foreground="#101727"
                                   FontSize="26"
                                   FontWeight="Bold"
                                   TextAlignment="Center"/>

                        <TextBlock x:Name="LoadingStepText"
                                   Text="Preparing repair..."
                                   Margin="0,11,0,0"
                                   Foreground="#4B566A"
                                   FontSize="15"
                                   TextAlignment="Center"
                                   TextWrapping="Wrap"/>

                        <Border Width="430"
                                Height="12"
                                Margin="0,28,0,0"
                                CornerRadius="6"
                                Background="#DCE7F7">
                            <Grid ClipToBounds="True">
                                <ProgressBar x:Name="RepairProgress"
                                             Minimum="0"
                                             Maximum="100"
                                             Value="0"
                                             BorderThickness="0"
                                             Background="Transparent"
                                             Foreground="#1762E8"/>
                            </Grid>
                        </Border>

                        <TextBlock x:Name="ProgressPercentText"
                                   Text="0%"
                                   Margin="0,12,0,0"
                                   Foreground="#1762E8"
                                   FontSize="15"
                                   FontWeight="SemiBold"
                                   TextAlignment="Center"/>

                        <TextBlock Text="Your connection may disconnect briefly while adapters restart."
                                   Margin="0,22,0,0"
                                   Foreground="#7A8496"
                                   FontSize="12"
                                   TextAlignment="Center"/>
                    </StackPanel>
                </Grid>

                <!-- DONE -->
                <Grid x:Name="DonePanel" Visibility="Collapsed" Margin="54,18,54,34">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="20"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="10"/>
                            <RowDefinition Height="250"/>
                            <RowDefinition Height="22"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <Border Grid.Row="0"
                                Width="74"
                                Height="74"
                                CornerRadius="37"
                                Background="#E8F8EF"
                                HorizontalAlignment="Center">
                            <TextBlock x:Name="DoneIcon"
                                       Text="&#xE73E;"
                                       FontFamily="Segoe MDL2 Assets"
                                       Foreground="#20A765"
                                       FontSize="38"
                                       HorizontalAlignment="Center"
                                       VerticalAlignment="Center"/>
                        </Border>

                        <TextBlock Grid.Row="1"
                                   x:Name="DoneTitleText"
                                   Text="Network Repair Completed"
                                   Margin="0,15,0,0"
                                   Foreground="#101727"
                                   FontSize="25"
                                   FontWeight="Bold"
                                   TextAlignment="Center"/>

                        <TextBlock Grid.Row="2"
                                   x:Name="DoneSummaryText"
                                   Text="The repair steps finished successfully."
                                   Margin="0,8,0,0"
                                   Foreground="#586377"
                                   FontSize="13"
                                   TextAlignment="Center"
                                   TextWrapping="Wrap"/>

                        <Grid Grid.Row="4">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Repair details"
                                       Foreground="#182136"
                                       FontSize="15"
                                       FontWeight="SemiBold"
                                       VerticalAlignment="Center"/>
                            <TextBlock x:Name="ResultCountText"
                                       Grid.Column="1"
                                       Text="0 completed  |  0 failed"
                                       Foreground="#68758A"
                                       FontSize="12"
                                       VerticalAlignment="Center"/>
                        </Grid>

                        <TextBox Grid.Row="6"
                                 x:Name="ResultsBox"
                                 Background="#FFFFFF"
                                 Foreground="#334056"
                                 BorderBrush="#D7E2F0"
                                 BorderThickness="1"
                                 Padding="14,12"
                                 FontFamily="Consolas"
                                 FontSize="12"
                                 IsReadOnly="True"
                                 AcceptsReturn="True"
                                 TextWrapping="NoWrap"
                                 VerticalScrollBarVisibility="Auto"
                                 HorizontalScrollBarVisibility="Auto"
                                 SelectionBrush="#BBD6FF"/>

                        <StackPanel Grid.Row="8"
                                    Orientation="Horizontal"
                                    HorizontalAlignment="Center">
                            <Button x:Name="BtnRunAgain"
                                    Width="150"
                                    Height="44"
                                    Margin="0,0,10,0"
                                    Style="{StaticResource PrimaryButton}"
                                    FontSize="14"
                                    Content="Run Again"/>

                            <Button x:Name="BtnOpenNetworkSettings"
                                    Width="190"
                                    Height="44"
                                    Margin="0,0,10,0"
                                    Style="{StaticResource SecondaryButton}"
                                    Content="Open Network Settings"/>

                            <Button x:Name="BtnCloseDone"
                                    Width="110"
                                    Height="44"
                                    Style="{StaticResource SecondaryButton}"
                                    Content="Close"/>
                        </StackPanel>
                    </Grid>
                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)

$names = @(
    'TitleBar', 'BtnMinimize', 'BtnClose',
    'IntroPanel', 'LoadingPanel', 'DonePanel',
    'BtnStartRepair', 'LoadingStepText', 'RepairProgress', 'ProgressPercentText',
    'DoneIcon', 'DoneTitleText', 'DoneSummaryText', 'ResultCountText', 'ResultsBox',
    'BtnRunAgain', 'BtnOpenNetworkSettings', 'BtnCloseDone'
)

foreach ($name in $names) {
    Set-Variable -Name $name -Value $Window.FindName($name) -Scope Script
}

$script:RepairLog = New-Object System.Collections.Generic.List[string]
$script:SuccessCount = 0
$script:FailureCount = 0

function Update-UI {
    $Window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-State {
    param([ValidateSet('Intro', 'Loading', 'Done')][string]$State)

    $IntroPanel.Visibility = 'Collapsed'
    $LoadingPanel.Visibility = 'Collapsed'
    $DonePanel.Visibility = 'Collapsed'

    switch ($State) {
        'Intro'   { $IntroPanel.Visibility = 'Visible' }
        'Loading' { $LoadingPanel.Visibility = 'Visible' }
        'Done'    { $DonePanel.Visibility = 'Visible' }
    }

    Update-UI
}

function Set-Progress {
    param(
        [int]$Percent,
        [string]$StepText
    )

    $RepairProgress.Value = $Percent
    $ProgressPercentText.Text = "$Percent%"
    $LoadingStepText.Text = $StepText
    Update-UI
}

function Add-RepairLog {
    param([string]$Line)
    [void]$script:RepairLog.Add($Line)
}

function Invoke-NativeCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $textOutput = ($output | Out-String).Trim()

    if ($exitCode -ne 0) {
        if ([string]::IsNullOrWhiteSpace($textOutput)) {
            throw "$FilePath exited with code $exitCode."
        }
        throw "$FilePath exited with code $exitCode.`r`n$textOutput"
    }

    return $textOutput
}

function Invoke-Step {
    param(
        [string]$Name,
        [string]$CommandText,
        [int]$Percent,
        [scriptblock]$Action
    )

    Set-Progress -Percent $Percent -StepText $Name
    Add-RepairLog ('-' * 72)
    Add-RepairLog "STEP: $Name"
    Add-RepairLog "COMMAND: $CommandText"

    try {
        $output = & $Action 2>&1 | Out-String
        $output = $output.Trim()

        Add-RepairLog 'STATUS: SUCCESS'
        if (-not [string]::IsNullOrWhiteSpace($output)) {
            Add-RepairLog 'OUTPUT:'
            foreach ($line in ($output -split "`r?`n")) {
                Add-RepairLog "  $line"
            }
        }
        else {
            Add-RepairLog 'OUTPUT: Command completed without additional output.'
        }

        $script:SuccessCount++
    }
    catch {
        Add-RepairLog 'STATUS: FAILED'
        Add-RepairLog "ERROR: $($_.Exception.Message)"
        $script:FailureCount++
    }

    Add-RepairLog ''
    Start-Sleep -Milliseconds 250
    Update-UI
}

function Get-ActiveAdapters {
    try {
        return Get-NetAdapter -ErrorAction Stop | Where-Object {
            $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true
        }
    }
    catch {
        return @()
    }
}

function Restart-ActiveAdapters {
    $adapters = Get-ActiveAdapters
    if (-not $adapters) {
        throw 'No active physical Wi-Fi or Ethernet adapters were found.'
    }

    $messages = New-Object System.Collections.Generic.List[string]
    foreach ($adapter in $adapters) {
        Restart-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop | Out-Null
        [void]$messages.Add("Restarted adapter: $($adapter.InterfaceAlias) [$($adapter.LinkSpeed)]")
    }

    return ($messages -join [Environment]::NewLine)
}

function Run-NetworkRepair {
    $BtnStartRepair.IsEnabled = $false
    $script:RepairLog.Clear()
    $script:SuccessCount = 0
    $script:FailureCount = 0
    $RepairProgress.Value = 0
    $ProgressPercentText.Text = '0%'
    Show-State 'Loading'

    Add-RepairLog 'NETWORK REPAIR - WINDOWS NETWORK REPAIR REPORT'
    Add-RepairLog "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-RepairLog "Computer: $env:COMPUTERNAME"
    Add-RepairLog "User: $env:USERNAME"
    Add-RepairLog ''

    Invoke-Step -Name 'Preparing repair...' -CommandText 'Initialize repair session' -Percent 5 -Action {
        Start-Sleep -Milliseconds 350
        'Administrator permission confirmed.'
    }

    Invoke-Step -Name 'Flushing DNS cache...' -CommandText 'ipconfig /flushdns' -Percent 18 -Action {
        Invoke-NativeCommand -FilePath 'ipconfig.exe' -Arguments @('/flushdns')
    }

    Invoke-Step -Name 'Registering DNS again...' -CommandText 'ipconfig /registerdns' -Percent 30 -Action {
        Invoke-NativeCommand -FilePath 'ipconfig.exe' -Arguments @('/registerdns')
    }

    Invoke-Step -Name 'Releasing current IP...' -CommandText 'ipconfig /release' -Percent 42 -Action {
        Invoke-NativeCommand -FilePath 'ipconfig.exe' -Arguments @('/release')
    }

    Invoke-Step -Name 'Renewing IP address...' -CommandText 'ipconfig /renew' -Percent 55 -Action {
        Invoke-NativeCommand -FilePath 'ipconfig.exe' -Arguments @('/renew')
    }

    Invoke-Step -Name 'Resetting proxy settings...' -CommandText 'netsh winhttp reset proxy' -Percent 67 -Action {
        Invoke-NativeCommand -FilePath 'netsh.exe' -Arguments @('winhttp', 'reset', 'proxy')
    }

    Invoke-Step -Name 'Resetting Winsock...' -CommandText 'netsh winsock reset' -Percent 79 -Action {
        Invoke-NativeCommand -FilePath 'netsh.exe' -Arguments @('winsock', 'reset')
    }

    Invoke-Step -Name 'Resetting TCP/IP stack...' -CommandText 'netsh int ip reset' -Percent 91 -Action {
        Invoke-NativeCommand -FilePath 'netsh.exe' -Arguments @('int', 'ip', 'reset')
    }

    Invoke-Step -Name 'Restarting active adapters...' -CommandText 'Restart-NetAdapter for active physical adapters' -Percent 100 -Action {
        Restart-ActiveAdapters
    }

    Add-RepairLog ('=' * 72)
    Add-RepairLog "Finished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-RepairLog "Successful steps: $script:SuccessCount"
    Add-RepairLog "Failed steps: $script:FailureCount"
    Add-RepairLog 'Note: Restart Windows to fully apply Winsock and TCP/IP resets.'

    $ResultsBox.Text = ($script:RepairLog -join [Environment]::NewLine)
    $ResultsBox.ScrollToHome()
    $ResultCountText.Text = "$script:SuccessCount completed  |  $script:FailureCount failed"

    $brushConverter = New-Object System.Windows.Media.BrushConverter

    if ($script:FailureCount -eq 0) {
        $DoneIcon.Text = [char]0xE73E
        $DoneIcon.Foreground = $brushConverter.ConvertFromString('#20A765')
        $DoneTitleText.Text = 'Network Repair Completed'
        $DoneSummaryText.Text = 'Every repair step completed. Restart Windows to fully apply the Winsock and TCP/IP resets.'
        $ResultCountText.Foreground = $brushConverter.ConvertFromString('#20A765')
    }
    else {
        $DoneIcon.Text = [char]0xE783
        $DoneIcon.Foreground = $brushConverter.ConvertFromString('#D98A16')
        $DoneTitleText.Text = 'Repair Finished with Warnings'
        $DoneSummaryText.Text = 'The repair continued after errors. Read the report below to see which actions succeeded or failed.'
        $ResultCountText.Foreground = $brushConverter.ConvertFromString('#D98A16')
    }

    $BtnStartRepair.IsEnabled = $true
    Show-State 'Done'
}

$TitleBar.Add_MouseLeftButtonDown({
    if ($_.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        $Window.DragMove()
    }
})

$BtnMinimize.Add_Click({ $Window.WindowState = 'Minimized' })
$BtnClose.Add_Click({ $Window.Close() })
$BtnCloseDone.Add_Click({ $Window.Close() })
$BtnRunAgain.Add_Click({ Run-NetworkRepair })
$BtnOpenNetworkSettings.Add_Click({
    try {
        Start-Process 'ms-settings:network-status'
    }
    catch {}
})
$BtnStartRepair.Add_Click({ Run-NetworkRepair })

Show-State 'Intro'
$Window.ShowDialog() | Out-Null
