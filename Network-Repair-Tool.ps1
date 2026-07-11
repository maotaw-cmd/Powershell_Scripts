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
            [System.Windows.MessageBox]::Show('Please save the script to a file and run it as Administrator.', 'Administrator Required', 'OK', 'Warning') | Out-Null
            exit
        }

        Start-Process -FilePath 'powershell.exe' -ArgumentList @('-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $scriptPath)) -Verb RunAs | Out-Null
        exit
    }
    catch {
        [System.Windows.MessageBox]::Show('This tool needs Administrator permissions to repair the network settings.', 'Administrator Required', 'OK', 'Warning') | Out-Null
        exit
    }
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="NetRepair"
        Width="980"
        Height="620"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        FontFamily="Segoe UI">
    <Border CornerRadius="12" Background="#0B0E10" BorderBrush="#252B2F" BorderThickness="1">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="3"/>
                <RowDefinition Height="44"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <Border Grid.Row="0">
                <Border.Background>
                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                        <GradientStop Color="#3BA3FF" Offset="0.0"/>
                        <GradientStop Color="#5D7CFF" Offset="0.55"/>
                        <GradientStop Color="#7A5CFF" Offset="1.0"/>
                    </LinearGradientBrush>
                </Border.Background>
            </Border>

            <Grid Grid.Row="1" x:Name="TitleBar" Background="#0D1012">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="41"/>
                    <ColumnDefinition Width="41"/>
                </Grid.ColumnDefinitions>

                <StackPanel Orientation="Horizontal" Margin="14,0,0,0" VerticalAlignment="Center">
                    <TextBlock Text="Net" Foreground="#3BA3FF" FontWeight="Bold" FontSize="17" VerticalAlignment="Center"/>
                    <TextBlock Text="Repair" Foreground="#D9DDE0" FontWeight="Bold" FontSize="17" VerticalAlignment="Center"/>
                    <TextBlock Text="PowerShell" Margin="12,2,0,0" Foreground="#51585D" FontSize="10" VerticalAlignment="Center"/>
                </StackPanel>

                <Button x:Name="BtnMinimize" Grid.Column="1" Background="Transparent" BorderBrush="Transparent" Foreground="#7B8389" FontFamily="Segoe MDL2 Assets" FontSize="12" Content="&#xE738;" Cursor="Hand"/>
                <Button x:Name="BtnClose" Grid.Column="2" Background="Transparent" BorderBrush="Transparent" Foreground="#7B8389" FontFamily="Segoe MDL2 Assets" FontSize="12" Content="&#xE711;" Cursor="Hand"/>
            </Grid>

            <Grid Grid.Row="2" Margin="46,30,46,30">
                <Grid x:Name="IntroPanel">
                    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="580">
                        <TextBlock Text="&#xE9D2;" FontFamily="Segoe MDL2 Assets" Foreground="#3BA3FF" FontSize="56" HorizontalAlignment="Center"/>
                        <TextBlock Text="One-Click Windows Network Repair" Foreground="#D9DDE0" FontSize="30" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,18,0,0" TextAlignment="Center"/>
                        <TextBlock Text="Fix common internet problems fast. This tool flushes DNS, renews IP, resets Winsock, resets TCP/IP, resets proxy, and restarts active network adapters." Foreground="#7B8389" FontSize="14" HorizontalAlignment="Center" Margin="0,12,0,0" TextAlignment="Center" TextWrapping="Wrap"/>
                        <Button x:Name="BtnStartRepair" Width="240" Height="48" Margin="0,28,0,0" Cursor="Hand" Foreground="White" Background="#3BA3FF" BorderBrush="#6D7DFF" BorderThickness="1" Content="Start Repair">
                            <Button.Template>
                                <ControlTemplate TargetType="Button">
                                    <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7">
                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter TargetName="Bd" Property="Background" Value="#59AFFF"/>
                                        </Trigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Button.Template>
                        </Button>
                        <TextBlock Text="Runs best as Administrator. A restart may be recommended after repair." Foreground="#51585D" FontSize="12" HorizontalAlignment="Center" Margin="0,14,0,0" TextAlignment="Center"/>
                    </StackPanel>
                </Grid>

                <Grid x:Name="LoadingPanel" Visibility="Collapsed">
                    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="520">
                        <TextBlock Text="&#xE895;" FontFamily="Segoe MDL2 Assets" Foreground="#3BA3FF" FontSize="50" HorizontalAlignment="Center"/>
                        <TextBlock Text="Repairing network settings..." Foreground="#D9DDE0" FontSize="28" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,18,0,0" TextAlignment="Center"/>
                        <TextBlock x:Name="LoadingStepText" Text="Preparing repair..." Foreground="#7B8389" FontSize="14" HorizontalAlignment="Center" Margin="0,10,0,0" TextAlignment="Center" TextWrapping="Wrap"/>
                        <ProgressBar x:Name="RepairProgress" Width="360" Height="10" Margin="0,26,0,0" Minimum="0" Maximum="100" Value="0"/>
                        <TextBlock x:Name="ProgressPercentText" Text="0%" Foreground="#D9DDE0" FontSize="14" HorizontalAlignment="Center" Margin="0,12,0,0"/>
                    </StackPanel>
                </Grid>

                <Grid x:Name="DonePanel" Visibility="Collapsed">
                    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="640">
                        <TextBlock Text="&#xE73E;" FontFamily="Segoe MDL2 Assets" Foreground="#39D98A" FontSize="56" HorizontalAlignment="Center"/>
                        <TextBlock Text="Network Repair Completed" Foreground="#D9DDE0" FontSize="30" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,18,0,0" TextAlignment="Center"/>
                        <TextBlock x:Name="DoneSummaryText" Text="The repair steps finished successfully." Foreground="#7B8389" FontSize="14" HorizontalAlignment="Center" Margin="0,12,0,0" TextAlignment="Center" TextWrapping="Wrap"/>

                        <TextBlock Text="Actions completed" Foreground="#D9DDE0" FontSize="16" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,26,0,0"/>
                        <TextBlock x:Name="CompletedStepsText" Foreground="#7B8389" FontSize="13" Margin="0,12,0,0" TextWrapping="Wrap" TextAlignment="Center"/>

                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,28,0,0">
                            <Button x:Name="BtnRunAgain" Width="170" Height="42" Margin="0,0,10,0" Cursor="Hand" Foreground="White" Background="#3BA3FF" BorderBrush="#6D7DFF" BorderThickness="1" Content="Run Again"/>
                            <Button x:Name="BtnOpenNetworkSettings" Width="190" Height="42" Margin="0,0,10,0" Cursor="Hand" Foreground="#D9DDE0" Background="#15191C" BorderBrush="#252B2F" BorderThickness="1" Content="Open Network Settings"/>
                            <Button x:Name="BtnCloseDone" Width="120" Height="42" Cursor="Hand" Foreground="#D9DDE0" Background="#15191C" BorderBrush="#252B2F" BorderThickness="1" Content="Close"/>
                        </StackPanel>
                    </StackPanel>
                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)

$names = @(
    'TitleBar','BtnMinimize','BtnClose',
    'IntroPanel','LoadingPanel','DonePanel',
    'BtnStartRepair','LoadingStepText','RepairProgress','ProgressPercentText',
    'DoneSummaryText','CompletedStepsText','BtnRunAgain','BtnOpenNetworkSettings','BtnCloseDone'
)

foreach ($name in $names) {
    Set-Variable -Name $name -Value $Window.FindName($name) -Scope Script
}

$script:CompletedSteps = New-Object System.Collections.Generic.List[string]

function Update-UI {
    $Window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-State {
    param([string]$State)

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

function Invoke-Step {
    param(
        [string]$Name,
        [int]$Percent,
        [scriptblock]$Action
    )

    Set-Progress -Percent $Percent -StepText $Name
    & $Action
    [void]$script:CompletedSteps.Add($Name)
    Start-Sleep -Milliseconds 350
    Update-UI
}

function Get-ActiveAdapters {
    try {
        return Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true }
    }
    catch {
        return @()
    }
}

function Restart-ActiveAdapters {
    $adapters = Get-ActiveAdapters
    if (-not $adapters) {
        return
    }

    foreach ($adapter in $adapters) {
        Restart-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    }
}

function Run-NetworkRepair {
    $script:CompletedSteps.Clear()
    Show-State 'Loading'

    try {
        Invoke-Step -Name 'Preparing repair...' -Percent 8 -Action { Start-Sleep -Milliseconds 400 }
        Invoke-Step -Name 'Flushing DNS cache...' -Percent 20 -Action { ipconfig /flushdns | Out-Null }
        Invoke-Step -Name 'Registering DNS again...' -Percent 32 -Action { ipconfig /registerdns | Out-Null }
        Invoke-Step -Name 'Releasing current IP...' -Percent 45 -Action { ipconfig /release | Out-Null }
        Invoke-Step -Name 'Renewing IP address...' -Percent 58 -Action { ipconfig /renew | Out-Null }
        Invoke-Step -Name 'Resetting proxy settings...' -Percent 70 -Action { netsh winhttp reset proxy | Out-Null }
        Invoke-Step -Name 'Resetting Winsock...' -Percent 82 -Action { netsh winsock reset | Out-Null }
        Invoke-Step -Name 'Resetting TCP/IP stack...' -Percent 92 -Action { netsh int ip reset | Out-Null }
        Invoke-Step -Name 'Restarting active adapters...' -Percent 100 -Action { Restart-ActiveAdapters }

        $DoneSummaryText.Text = 'The main repair steps finished. If your internet still acts strange, restart your PC for the full reset to apply.'
        $CompletedStepsText.Text = ($script:CompletedSteps -join [Environment]::NewLine)
    }
    catch {
        $DoneSummaryText.Text = 'Some repair steps failed: ' + $_.Exception.Message
        $CompletedStepsText.Text = if ($script:CompletedSteps.Count -gt 0) {
            ($script:CompletedSteps -join [Environment]::NewLine)
        }
        else {
            'No steps completed.'
        }
    }

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
