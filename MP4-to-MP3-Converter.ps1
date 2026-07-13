#requires -Version 5.1
<#
    MP4 to MP3 Converter
    One-page WPF flow:
      1. Upload or drag an MP4
      2. Convert
      3. Save/download the MP3

    FFmpeg:
      - Uses ffmpeg.exe beside this script first.
      - Then checks PATH.
      - Otherwise downloads FFmpeg once into a tools folder beside this script.
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:SelectedFile = $null
$script:OutputFile = $null
$script:Worker = $null
$script:Timer = $null
$script:StateFile = Join-Path $env:TEMP ("mp4_to_mp3_state_" + [guid]::NewGuid().ToString("N") + ".json")
$script:ScriptFolder = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($script:ScriptFolder)) { $script:ScriptFolder = (Get-Location).Path }
$script:AppRoot = Join-Path $script:ScriptFolder "MP4-to-MP3-Tools"
$script:FfmpegRoot = Join-Path $script:AppRoot "ffmpeg"
$script:FfmpegExe = $null

[xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="MP4 to MP3"
    Width="980"
    Height="610"
    WindowStartupLocation="CenterScreen"
    WindowStyle="None"
    ResizeMode="NoResize"
    Background="#07090A"
    AllowsTransparency="False">

    <Window.Resources>
        <Style x:Key="MainButton" TargetType="Button">
            <Setter Property="Height" Value="48"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="#D82937"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border
                            x:Name="ButtonBorder"
                            Background="{TemplateBinding Background}"
                            CornerRadius="5">
                            <ContentPresenter
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Background" Value="#EF3345"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Background" Value="#B51E2D"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="ButtonBorder" Property="Background" Value="#311216"/>
                                <Setter Property="Foreground" Value="#6E6667"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="GhostButton" TargetType="Button">
            <Setter Property="Height" Value="44"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Foreground" Value="#D4D6D7"/>
            <Setter Property="Background" Value="#111415"/>
            <Setter Property="BorderBrush" Value="#283032"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border
                            x:Name="ButtonBorder"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="5">
                            <ContentPresenter
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Background" Value="#181C1D"/>
                                <Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#D82937"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border BorderBrush="#263132" BorderThickness="1">
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="245"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- LEFT PANEL -->
            <Grid Grid.Column="0">
                <Grid.Background>
                    <RadialGradientBrush Center="0.18,0.12" GradientOrigin="0.18,0.12" RadiusX="1.1" RadiusY="1.0">
                        <GradientStop Color="#7B181A" Offset="0"/>
                        <GradientStop Color="#250D0E" Offset="0.43"/>
                        <GradientStop Color="#100808" Offset="1"/>
                    </RadialGradientBrush>
                </Grid.Background>

                <Grid.RowDefinitions>
                    <RowDefinition Height="106"/>
                    <RowDefinition Height="1"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="92"/>
                </Grid.RowDefinitions>

                <Grid Grid.Row="0">
                    <Canvas Width="76" Height="68" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <Polygon Fill="#EFEAE4" Points="2,28 18,10 29,18 12,37"/>
                        <Polygon Fill="#EFEAE4" Points="14,39 39,9 50,17 25,48"/>
                        <Polygon Fill="#EFEAE4" Points="29,50 58,15 69,23 41,58"/>
                        <Polygon Fill="#EFEAE4" Points="11,36 42,61 34,69 2,44"/>
                    </Canvas>
                </Grid>

                <Border Grid.Row="1" Background="#63302E" Margin="24,0"/>

                <StackPanel Grid.Row="2" Margin="26,28,22,0">
                    <TextBlock Text="MP4 TO MP3"
                               Foreground="White"
                               FontSize="20"
                               FontWeight="Bold"/>
                    <TextBlock Text="Audio Converter"
                               Foreground="#A77D75"
                               FontSize="12"
                               Margin="0,4,0,32"/>

                    <Grid Margin="0,0,0,24">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="34"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name="StepOneCircle" Width="26" Height="26" CornerRadius="13"
                                Background="#D82937" HorizontalAlignment="Left">
                            <TextBlock Text="1" Foreground="White" FontWeight="Bold"
                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <StackPanel Grid.Column="1">
                            <TextBlock x:Name="StepOneTitle" Text="Choose video"
                                       Foreground="White" FontSize="13" FontWeight="SemiBold"/>
                            <TextBlock Text="Upload or drag an MP4"
                                       Foreground="#6F7476" FontSize="10" Margin="0,3,0,0"/>
                        </StackPanel>
                    </Grid>

                    <Grid Margin="0,0,0,24">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="34"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name="StepTwoCircle" Width="26" Height="26" CornerRadius="13"
                                Background="#252A2B" HorizontalAlignment="Left">
                            <TextBlock Text="2" Foreground="#777C7E" FontWeight="Bold"
                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <StackPanel Grid.Column="1">
                            <TextBlock x:Name="StepTwoTitle" Text="Convert audio"
                                       Foreground="#777C7E" FontSize="13" FontWeight="SemiBold"/>
                            <TextBlock Text="Extract high-quality MP3"
                                       Foreground="#515658" FontSize="10" Margin="0,3,0,0"/>
                        </StackPanel>
                    </Grid>

                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="34"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name="StepThreeCircle" Width="26" Height="26" CornerRadius="13"
                                Background="#252A2B" HorizontalAlignment="Left">
                            <TextBlock Text="3" Foreground="#777C7E" FontWeight="Bold"
                                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <StackPanel Grid.Column="1">
                            <TextBlock x:Name="StepThreeTitle" Text="Save MP3"
                                       Foreground="#777C7E" FontSize="13" FontWeight="SemiBold"/>
                            <TextBlock Text="Download the finished file"
                                       Foreground="#515658" FontSize="10" Margin="0,3,0,0"/>
                        </StackPanel>
                    </Grid>
                </StackPanel>

                <Grid Grid.Row="3" Margin="26,0,22,20" VerticalAlignment="Bottom">
                    <Border Height="1" Background="#63302E" VerticalAlignment="Top"/>
                    <StackPanel Margin="0,18,0,0">
                        <TextBlock Text="POWERED BY FFMPEG"
                                   Foreground="#9E7771"
                                   FontSize="10"
                                   FontWeight="SemiBold"/>
                        <TextBlock Text="Private  |  Local  |  No upload"
                                   Foreground="#585C5E"
                                   FontSize="10"
                                   Margin="0,4,0,0"/>
                    </StackPanel>
                </Grid>
            </Grid>

            <!-- MAIN AREA -->
            <Grid Grid.Column="1" Background="#080A0B">
                <Grid.RowDefinitions>
                    <RowDefinition Height="46"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <!-- TOP BAR -->
                <Grid Grid.Row="0" Background="#090B0C" x:Name="TopBar">
                    <StackPanel Orientation="Horizontal" Margin="28,0,0,0" VerticalAlignment="Center">
                        <Border Width="22" Height="22" CornerRadius="4" Background="#351217" Margin="0,0,10,0">
                            <Grid>
                                <Rectangle Width="3" Height="11" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="3,-3,0,0"/>
                                <Ellipse Width="7" Height="7" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="-3,7,0,0"/>
                                <Rectangle Width="8" Height="3" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="6,-10,0,0"/>
                            </Grid>
                        </Border>
                        <TextBlock Text="Converter" Foreground="#8A8E90" FontSize="12"/>
                        <TextBlock Text=">" Foreground="#454A4C" FontSize="14" Margin="12,0,12,0"/>
                        <TextBlock x:Name="TopStatus" Text="Select video" Foreground="#C8CBCD" FontSize="12"/>
                    </StackPanel>

                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="MinimizeButton" Width="45" Height="46" Content="-"
                                Foreground="#8A8E90" Background="Transparent" BorderThickness="0"
                                FontSize="15" Cursor="Hand"/>
                        <Button x:Name="CloseButton" Width="45" Height="46" Content="X"
                                Foreground="#8A8E90" Background="Transparent" BorderThickness="0"
                                FontSize="13" FontWeight="SemiBold" Cursor="Hand"/>
                    </StackPanel>
                </Grid>

                <Grid Grid.Row="1" Margin="42,32,42,36">

                    <!-- SELECT VIEW -->
                    <Grid x:Name="SelectView" Visibility="Visible">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="22"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="22"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <StackPanel>
                            <TextBlock Text="Convert MP4 to MP3"
                                       Foreground="#F2F2F2"
                                       FontSize="27"
                                       FontWeight="SemiBold"/>
                            <TextBlock Text="Choose a video and extract its audio as a high-quality MP3 file."
                                       Foreground="#7F8587"
                                       FontSize="13"
                                       Margin="0,8,0,0"/>
                        </StackPanel>

                        <Border x:Name="DropZone"
                                Grid.Row="2"
                                AllowDrop="True"
                                Background="#0C0F10"
                                BorderBrush="#283032"
                                BorderThickness="1"
                                CornerRadius="7">
                            <Grid>
                                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                                    <Border Width="72" Height="72" CornerRadius="36" Background="#251014"
                                            HorizontalAlignment="Center">
                                        <Grid Width="44" Height="44" HorizontalAlignment="Center" VerticalAlignment="Center">
                                            <Rectangle Width="5" Height="24" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="8,-5,0,0"/>
                                            <Ellipse Width="14" Height="14" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="-5,17,0,0"/>
                                            <Rectangle Width="19" Height="5" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="16,-24,0,0"/>
                                        </Grid>
                                    </Border>

                                    <TextBlock x:Name="DropTitle"
                                               Text="Drop your MP4 video here"
                                               Foreground="#E0E2E3"
                                               FontSize="17"
                                               FontWeight="SemiBold"
                                               HorizontalAlignment="Center"
                                               Margin="0,20,0,0"/>

                                    <TextBlock x:Name="DropSubtitle"
                                               Text="or click below to choose a file"
                                               Foreground="#666C6E"
                                               FontSize="12"
                                               HorizontalAlignment="Center"
                                               Margin="0,7,0,0"/>

                                    <Button x:Name="ChooseFileButton"
                                            Content="Choose MP4 File"
                                            Width="184"
                                            Margin="0,22,0,0"
                                            Style="{StaticResource GhostButton}"/>
                                </StackPanel>

                                <Border x:Name="SelectedFileCard"
                                        Visibility="Collapsed"
                                        Background="#101314"
                                        BorderBrush="#3A2427"
                                        BorderThickness="1"
                                        CornerRadius="6"
                                        Margin="24"
                                        VerticalAlignment="Bottom"
                                        Height="76">
                                    <Grid Margin="17,0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="44"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <Border Width="34" Height="34" CornerRadius="4" Background="#351217"
                                                VerticalAlignment="Center">
                                            <Path Data="M 0,0 L 11,6 L 0,12 Z" Fill="#EF3345" Width="11" Height="12" Stretch="Fill" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="12,0">
                                            <TextBlock x:Name="SelectedFileName"
                                                       Foreground="#F0F0F0"
                                                       FontSize="13"
                                                       FontWeight="SemiBold"
                                                       TextTrimming="CharacterEllipsis"/>
                                            <TextBlock x:Name="SelectedFileInfo"
                                                       Foreground="#676D6F"
                                                       FontSize="10"
                                                       Margin="0,4,0,0"/>
                                        </StackPanel>
                                        <Button x:Name="RemoveFileButton"
                                                Grid.Column="2"
                                                Content="X"
                                                Width="31"
                                                Height="31"
                                                Foreground="#8A8E90"
                                                Background="Transparent"
                                                BorderThickness="0"
                                                FontSize="20"
                                                Cursor="Hand"/>
                                    </Grid>
                                </Border>
                            </Grid>
                        </Border>

                        <Button x:Name="ConvertButton"
                                Grid.Row="4"
                                Content="Convert to MP3"
                                IsEnabled="False"
                                Style="{StaticResource MainButton}"/>
                    </Grid>

                    <!-- LOADING VIEW -->
                    <Grid x:Name="LoadingView" Visibility="Collapsed">
                        <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="470">
                            <Border Width="86" Height="86" CornerRadius="43" Background="#251014">
                                <Grid>
                                    <Grid Width="48" Height="48" HorizontalAlignment="Center" VerticalAlignment="Center">
                                    <Rectangle Width="5" Height="27" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="9,-6,0,0"/>
                                    <Ellipse Width="15" Height="15" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="-5,19,0,0"/>
                                    <Rectangle Width="21" Height="5" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="18,-28,0,0"/>
                                </Grid>
                                </Grid>
                            </Border>

                            <TextBlock x:Name="LoadingTitle"
                                       Text="Converting your video..."
                                       Foreground="#F2F2F2"
                                       FontSize="23"
                                       FontWeight="SemiBold"
                                       HorizontalAlignment="Center"
                                       Margin="0,25,0,0"/>

                            <TextBlock x:Name="LoadingSubtitle"
                                       Text="Extracting audio and encoding MP3"
                                       Foreground="#7E8486"
                                       FontSize="12"
                                       HorizontalAlignment="Center"
                                       Margin="0,8,0,0"/>

                            <Grid Margin="0,34,0,0">
                                <Border Height="6" Background="#252A2B" CornerRadius="3"/>
                                <Border x:Name="ProgressFill"
                                        Height="6"
                                        Width="0"
                                        Background="#D82937"
                                        CornerRadius="3"
                                        HorizontalAlignment="Left"/>
                            </Grid>

                            <Grid Margin="0,12,0,0">
                                <TextBlock x:Name="ProgressStatus"
                                           Text="Preparing converter..."
                                           Foreground="#7E8486"
                                           FontSize="11"/>
                                <TextBlock x:Name="ProgressPercent"
                                           Text="0%"
                                           Foreground="#A8ADAF"
                                           FontSize="11"
                                           HorizontalAlignment="Right"/>
                            </Grid>

                            <TextBlock x:Name="LoadingFileName"
                                       Foreground="#4F5557"
                                       FontSize="10"
                                       HorizontalAlignment="Center"
                                       TextTrimming="CharacterEllipsis"
                                       Margin="0,26,0,0"/>
                        </StackPanel>
                    </Grid>

                    <!-- RESULT VIEW -->
                    <Grid x:Name="ResultView" Visibility="Collapsed">
                        <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="490">
                            <Border Width="90" Height="90" CornerRadius="45" Background="#182C23">
                                <Path Data="M 2,12 L 9,19 L 24,3" Stroke="#55D58A" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Width="28" Height="24" Stretch="Uniform" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>

                            <TextBlock Text="Your MP3 is ready"
                                       Foreground="#F2F2F2"
                                       FontSize="25"
                                       FontWeight="SemiBold"
                                       HorizontalAlignment="Center"
                                       Margin="0,24,0,0"/>

                            <TextBlock Text="The audio was extracted successfully."
                                       Foreground="#7F8587"
                                       FontSize="12"
                                       HorizontalAlignment="Center"
                                       Margin="0,8,0,0"/>

                            <Border Background="#0E1112"
                                    BorderBrush="#283032"
                                    BorderThickness="1"
                                    CornerRadius="6"
                                    Height="78"
                                    Margin="0,29,0,0">
                                <Grid Margin="17,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="45"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <Border Width="35" Height="35" CornerRadius="18" Background="#351217"
                                            VerticalAlignment="Center">
                                        <Grid Width="22" Height="22" HorizontalAlignment="Center" VerticalAlignment="Center">
                                            <Rectangle Width="3" Height="13" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="5,-3,0,0"/>
                                            <Ellipse Width="8" Height="8" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="-3,9,0,0"/>
                                            <Rectangle Width="10" Height="3" Fill="#EF3345" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="9,-14,0,0"/>
                                        </Grid>
                                    </Border>
                                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="12,0,0,0">
                                        <TextBlock x:Name="ResultFileName"
                                                   Foreground="#F0F0F0"
                                                   FontSize="13"
                                                   FontWeight="SemiBold"
                                                   TextTrimming="CharacterEllipsis"/>
                                        <TextBlock x:Name="ResultFileInfo"
                                                   Foreground="#676D6F"
                                                   FontSize="10"
                                                   Margin="0,5,0,0"/>
                                    </StackPanel>
                                </Grid>
                            </Border>

                            <Button x:Name="SaveMp3Button"
                                    Content="Save / Download MP3"
                                    Margin="0,24,0,0"
                                    Style="{StaticResource MainButton}"/>

                            <Grid Margin="0,12,0,0">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="10"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Button x:Name="OpenFolderButton"
                                        Content="Open Output Folder"
                                        Style="{StaticResource GhostButton}"/>
                                <Button x:Name="ConvertAnotherButton"
                                        Grid.Column="2"
                                        Content="Convert Another"
                                        Style="{StaticResource GhostButton}"/>
                            </Grid>
                        </StackPanel>
                    </Grid>

                    <!-- ERROR VIEW -->
                    <Grid x:Name="ErrorView" Visibility="Collapsed">
                        <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="500">
                            <Border Width="86" Height="86" CornerRadius="43" Background="#321216">
                                <TextBlock Text="!"
                                           Foreground="#EF3345"
                                           FontSize="43"
                                           FontWeight="Bold"
                                           HorizontalAlignment="Center"
                                           VerticalAlignment="Center"/>
                            </Border>

                            <TextBlock Text="Conversion failed"
                                       Foreground="#F2F2F2"
                                       FontSize="24"
                                       FontWeight="SemiBold"
                                       HorizontalAlignment="Center"
                                       Margin="0,24,0,0"/>

                            <TextBlock x:Name="ErrorMessage"
                                       Text="Something went wrong."
                                       Foreground="#8A8E90"
                                       FontSize="12"
                                       TextAlignment="Center"
                                       TextWrapping="Wrap"
                                       HorizontalAlignment="Center"
                                       Margin="0,10,0,0"/>

                            <Button x:Name="TryAgainButton"
                                    Content="Try Again"
                                    Width="220"
                                    Margin="0,26,0,0"
                                    Style="{StaticResource MainButton}"/>
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
    "TopBar","TopStatus","MinimizeButton","CloseButton",
    "SelectView","LoadingView","ResultView","ErrorView",
    "DropZone","DropTitle","DropSubtitle","ChooseFileButton",
    "SelectedFileCard","SelectedFileName","SelectedFileInfo","RemoveFileButton",
    "ConvertButton","LoadingTitle","LoadingSubtitle","ProgressFill",
    "ProgressStatus","ProgressPercent","LoadingFileName",
    "ResultFileName","ResultFileInfo","SaveMp3Button","OpenFolderButton",
    "ConvertAnotherButton","ErrorMessage","TryAgainButton",
    "StepOneCircle","StepOneTitle","StepTwoCircle","StepTwoTitle",
    "StepThreeCircle","StepThreeTitle"
)

foreach ($name in $names) {
    Set-Variable -Name $name -Value $Window.FindName($name) -Scope Script
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

function Set-StepState {
    param(
        [ValidateSet("Select","Convert","Result")]
        [string]$Step
    )

    $inactiveBackground = [Windows.Media.BrushConverter]::new().ConvertFromString("#252A2B")
    $inactiveText = [Windows.Media.BrushConverter]::new().ConvertFromString("#777C7E")
    $activeBackground = [Windows.Media.BrushConverter]::new().ConvertFromString("#D82937")
    $activeText = [Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
    $doneBackground = [Windows.Media.BrushConverter]::new().ConvertFromString("#24563A")
    $doneText = [Windows.Media.BrushConverter]::new().ConvertFromString("#77D69D")

    $StepOneCircle.Background = $inactiveBackground
    $StepTwoCircle.Background = $inactiveBackground
    $StepThreeCircle.Background = $inactiveBackground
    $StepOneTitle.Foreground = $inactiveText
    $StepTwoTitle.Foreground = $inactiveText
    $StepThreeTitle.Foreground = $inactiveText

    switch ($Step) {
        "Select" {
            $StepOneCircle.Background = $activeBackground
            $StepOneTitle.Foreground = $activeText
        }
        "Convert" {
            $StepOneCircle.Background = $doneBackground
            $StepOneTitle.Foreground = $doneText
            $StepTwoCircle.Background = $activeBackground
            $StepTwoTitle.Foreground = $activeText
        }
        "Result" {
            $StepOneCircle.Background = $doneBackground
            $StepOneTitle.Foreground = $doneText
            $StepTwoCircle.Background = $doneBackground
            $StepTwoTitle.Foreground = $doneText
            $StepThreeCircle.Background = $activeBackground
            $StepThreeTitle.Foreground = $activeText
        }
    }
}

function Show-View {
    param(
        [ValidateSet("Select","Loading","Result","Error")]
        [string]$Name
    )

    $SelectView.Visibility = "Collapsed"
    $LoadingView.Visibility = "Collapsed"
    $ResultView.Visibility = "Collapsed"
    $ErrorView.Visibility = "Collapsed"

    switch ($Name) {
        "Select" {
            $SelectView.Visibility = "Visible"
            $TopStatus.Text = "Select video"
            Set-StepState "Select"
        }
        "Loading" {
            $LoadingView.Visibility = "Visible"
            $TopStatus.Text = "Converting"
            Set-StepState "Convert"
        }
        "Result" {
            $ResultView.Visibility = "Visible"
            $TopStatus.Text = "MP3 ready"
            Set-StepState "Result"
        }
        "Error" {
            $ErrorView.Visibility = "Visible"
            $TopStatus.Text = "Conversion failed"
            Set-StepState "Convert"
        }
    }
}

function Reset-Selection {
    $script:SelectedFile = $null
    $script:OutputFile = $null
    $SelectedFileCard.Visibility = "Collapsed"
    $DropTitle.Text = "Drop your MP4 video here"
    $DropSubtitle.Text = "or click below to choose a file"
    $ConvertButton.IsEnabled = $false
    Show-View "Select"
}

function Set-SelectedFile {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        [System.Windows.MessageBox]::Show(
            "The selected file could not be found.",
            "Invalid file",
            "OK",
            "Warning") | Out-Null
        return
    }

    $extension = [IO.Path]::GetExtension($Path)
    if ($extension -notin @(".mp4", ".m4v", ".mov", ".mkv", ".avi", ".webm")) {
        [System.Windows.MessageBox]::Show(
            "Please choose an MP4 or another supported video file.",
            "Unsupported file",
            "OK",
            "Warning") | Out-Null
        return
    }

    $item = Get-Item -LiteralPath $Path
    $script:SelectedFile = $item.FullName

    $SelectedFileName.Text = $item.Name
    $SelectedFileInfo.Text = "$(Format-FileSize $item.Length)  |  $($item.Extension.TrimStart('.').ToUpper()) video"
    $SelectedFileCard.Visibility = "Visible"
    $DropTitle.Text = "Video selected"
    $DropSubtitle.Text = "Ready to extract the audio"
    $ConvertButton.IsEnabled = $true
}

function Select-VideoFile {
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = "Choose a video"
    $dialog.Filter = "Video files|*.mp4;*.m4v;*.mov;*.mkv;*.avi;*.webm|MP4 video|*.mp4|All files|*.*"
    $dialog.Multiselect = $false

    if ($dialog.ShowDialog() -eq $true) {
        Set-SelectedFile $dialog.FileName
    }
}

function Find-Ffmpeg {
    $command = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    if (Test-Path -LiteralPath $script:FfmpegRoot) {
        $candidate = Get-ChildItem -LiteralPath $script:FfmpegRoot -Filter ffmpeg.exe -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($candidate) {
            return $candidate.FullName
        }
    }

    return $null
}

function Start-Conversion {
    if (-not $script:SelectedFile -or -not (Test-Path -LiteralPath $script:SelectedFile)) {
        return
    }

    $inputItem = Get-Item -LiteralPath $script:SelectedFile
    # Always save beside the selected video. Never overwrite an existing file.
    $defaultOutput = Join-Path $inputItem.DirectoryName ($inputItem.BaseName + ".mp3")
    $copyNumber = 1
    while (Test-Path -LiteralPath $defaultOutput) {
        $defaultOutput = Join-Path $inputItem.DirectoryName (
            $inputItem.BaseName + " (" + $copyNumber + ").mp3"
        )
        $copyNumber++
    }

    $script:OutputFile = $defaultOutput
    $LoadingFileName.Text = $inputItem.Name
    $ProgressFill.Width = 0
    $ProgressPercent.Text = "0%"
    $ProgressStatus.Text = "Preparing converter..."
    $LoadingTitle.Text = "Converting your video..."
    $LoadingSubtitle.Text = "Extracting audio and encoding MP3"
    Show-View "Loading"

    if (Test-Path -LiteralPath $script:StateFile) {
        Remove-Item -LiteralPath $script:StateFile -Force -ErrorAction SilentlyContinue
    }

    $inputPath = $script:SelectedFile
    $outputPath = $script:OutputFile
    $statePath = $script:StateFile
    $appRoot = $script:AppRoot
    $ffmpegRoot = $script:FfmpegRoot

    $workerScript = {
        param($InputPath, $OutputPath, $StatePath, $AppRoot, $FfmpegRoot)

        $ErrorActionPreference = "Stop"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        function Write-State {
            param(
                [string]$Stage,
                [double]$Progress,
                [string]$Message,
                [string]$ErrorText = ""
            )

            $object = [ordered]@{
                stage = $Stage
                progress = $Progress
                message = $Message
                error = $ErrorText
                updated = [DateTime]::UtcNow.ToString("o")
            }

            # Write directly. The UI already retries if it catches the file mid-write.
            # This avoids the Windows Move-Item "file already exists" race.
            $json = $object | ConvertTo-Json -Compress
            [System.IO.File]::WriteAllText($StatePath, $json, [System.Text.UTF8Encoding]::new($false))
        }

        try {
            Write-State "checking" 2 "Checking FFmpeg..."

            $ffmpeg = $null

            # Reuse a local copy immediately on every later run.
            $localBesideScript = Join-Path (Split-Path -Parent $AppRoot) "ffmpeg.exe"
            if (Test-Path -LiteralPath $localBesideScript) {
                $ffmpeg = $localBesideScript
            }

            if (-not $ffmpeg -and (Test-Path -LiteralPath $FfmpegRoot)) {
                $candidate = Get-ChildItem -LiteralPath $FfmpegRoot -Filter ffmpeg.exe -Recurse -File -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($candidate) {
                    $ffmpeg = $candidate.FullName
                }
            }

            if (-not $ffmpeg) {
                $pathCommand = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
                if ($pathCommand) {
                    $ffmpeg = $pathCommand.Source
                }
            }

            if (-not $ffmpeg) {
                Write-State "downloading" 6 "Connecting to the FFmpeg download..."

                New-Item -ItemType Directory -Path $AppRoot -Force | Out-Null
                $zipPath = Join-Path $AppRoot "ffmpeg-release-essentials.zip"
                $partialPath = $zipPath + ".part"
                $downloadUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

                Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $partialPath -Force -ErrorAction SilentlyContinue

                # Stream the file manually instead of WebClient.DownloadFile().
                # This gives the UI real download progress and prevents it from
                # appearing frozen at 6 percent during the first run.
                $request = [System.Net.HttpWebRequest]::Create($downloadUrl)
                $request.Method = "GET"
                $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MP4ToMP3Converter/1.1"
                $request.AllowAutoRedirect = $true
                $request.Timeout = 30000
                $request.ReadWriteTimeout = 30000
                $request.KeepAlive = $false

                $response = $null
                $inputStream = $null
                $outputStream = $null

                try {
                    $response = $request.GetResponse()
                    $totalBytes = [long]$response.ContentLength
                    $inputStream = $response.GetResponseStream()
                    $outputStream = [System.IO.File]::Open(
                        $partialPath,
                        [System.IO.FileMode]::Create,
                        [System.IO.FileAccess]::Write,
                        [System.IO.FileShare]::None)

                    $buffer = New-Object byte[] 1048576
                    $downloadedBytes = 0L
                    $lastReported = -1

                    while (($bytesRead = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                        $outputStream.Write($buffer, 0, $bytesRead)
                        $downloadedBytes += $bytesRead

                        if ($totalBytes -gt 0) {
                            $downloadPercent = [Math]::Min(100.0, ($downloadedBytes * 100.0) / $totalBytes)
                            $uiProgress = 6.0 + ($downloadPercent * 0.46) # 6% to 52%
                            $rounded = [int][Math]::Floor($downloadPercent)

                            if ($rounded -ne $lastReported) {
                                $downloadedMB = $downloadedBytes / 1MB
                                $totalMB = $totalBytes / 1MB
                                Write-State "downloading" $uiProgress ("Downloading FFmpeg... {0:N1} / {1:N1} MB" -f $downloadedMB, $totalMB)
                                $lastReported = $rounded
                            }
                        }
                        else {
                            $downloadedMB = $downloadedBytes / 1MB
                            Write-State "downloading" 28 ("Downloading FFmpeg... {0:N1} MB" -f $downloadedMB)
                        }
                    }
                }
                finally {
                    if ($outputStream) { $outputStream.Dispose() }
                    if ($inputStream) { $inputStream.Dispose() }
                    if ($response) { $response.Dispose() }
                }

                if (-not (Test-Path -LiteralPath $partialPath)) {
                    throw "The FFmpeg download did not create a file."
                }

                $downloadedFile = Get-Item -LiteralPath $partialPath
                if ($downloadedFile.Length -lt 5MB) {
                    Remove-Item -LiteralPath $partialPath -Force -ErrorAction SilentlyContinue
                    throw "The FFmpeg download was incomplete. Check your internet connection and try again."
                }

                # Move safely even on Windows PowerShell 5.1, where Move-Item -Force
                # can still fail when the destination exists.
                Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
                [System.IO.File]::Move($partialPath, $zipPath)
                Write-State "extracting" 55 "Installing FFmpeg..."

                $extractRoot = Join-Path $AppRoot ("ffmpeg_extract_" + [guid]::NewGuid().ToString("N"))
                New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

                try {
                    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
                }
                catch {
                    Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
                    throw "The FFmpeg ZIP could not be extracted. Please run the converter again. Details: $($_.Exception.Message)"
                }

                Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue

                $candidate = Get-ChildItem -LiteralPath $extractRoot -Filter ffmpeg.exe -Recurse -File -ErrorAction SilentlyContinue |
                    Select-Object -First 1

                if (-not $candidate) {
                    Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
                    throw "FFmpeg was installed, but ffmpeg.exe could not be found."
                }

                # Copy only the small executable folder we need into the stable local cache.
                $binFolder = $candidate.Directory.FullName
                if (Test-Path -LiteralPath $FfmpegRoot) {
                    Remove-Item -LiteralPath $FfmpegRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $FfmpegRoot -Force | Out-Null
                Copy-Item -Path (Join-Path $binFolder "*") -Destination $FfmpegRoot -Recurse -Force
                Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue

                $ffmpeg = Join-Path $FfmpegRoot "ffmpeg.exe"
                if (-not (Test-Path -LiteralPath $ffmpeg)) {
                    throw "FFmpeg was extracted, but the local executable could not be created."
                }
            }

            Write-State "probing" 62 "Reading video information..."

            $ffprobe = Join-Path ([IO.Path]::GetDirectoryName($ffmpeg)) "ffprobe.exe"
            $durationSeconds = 0.0

            if (Test-Path -LiteralPath $ffprobe) {
                $probeInfo = New-Object System.Diagnostics.ProcessStartInfo
                $probeInfo.FileName = $ffprobe
                $probeInfo.Arguments = "-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 `"$InputPath`""
                $probeInfo.UseShellExecute = $false
                $probeInfo.CreateNoWindow = $true
                $probeInfo.RedirectStandardOutput = $true
                $probeInfo.RedirectStandardError = $true

                $probe = New-Object System.Diagnostics.Process
                $probe.StartInfo = $probeInfo
                $null = $probe.Start()
                $probeOutput = $probe.StandardOutput.ReadToEnd()
                $probe.WaitForExit()

                [double]::TryParse(
                    $probeOutput.Trim(),
                    [Globalization.NumberStyles]::Float,
                    [Globalization.CultureInfo]::InvariantCulture,
                    [ref]$durationSeconds) | Out-Null
            }

            Write-State "converting" 65 "Extracting audio..."

            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $ffmpeg
            $processInfo.Arguments = "-y -hide_banner -loglevel error -i `"$InputPath`" -vn -codec:a libmp3lame -b:a 256k -ar 44100 -threads 0 -progress pipe:1 -nostats `"$OutputPath`""
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $null = $process.Start()

            while (-not $process.StandardOutput.EndOfStream) {
                $line = $process.StandardOutput.ReadLine()

                if ($line -like "out_time_ms=*") {
                    $valueText = $line.Substring("out_time_ms=".Length)
                    $microseconds = 0L

                    if ([long]::TryParse($valueText, [ref]$microseconds) -and $durationSeconds -gt 0) {
                        $currentSeconds = $microseconds / 1000000.0
                        $conversionRatio = [Math]::Min(1.0, $currentSeconds / $durationSeconds)
                        $progress = 65.0 + ($conversionRatio * 33.0)
                        Write-State "converting" $progress "Encoding MP3..."
                    }
                }
                elseif ($line -eq "progress=end") {
                    Write-State "finishing" 98 "Finishing MP3 file..."
                }
            }

            $errorOutput = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            if ($process.ExitCode -ne 0) {
                if ([string]::IsNullOrWhiteSpace($errorOutput)) {
                    $errorOutput = "FFmpeg exited with code $($process.ExitCode)."
                }

                throw $errorOutput.Trim()
            }

            if (-not (Test-Path -LiteralPath $OutputPath)) {
                throw "The MP3 output file was not created."
            }

            Write-State "complete" 100 "Conversion complete."
        }
        catch {
            Write-State "error" 0 "Conversion failed." $_.Exception.Message
        }
    }

    $script:Worker = [PowerShell]::Create()
    $null = $script:Worker.AddScript($workerScript)
    $null = $script:Worker.AddArgument($inputPath)
    $null = $script:Worker.AddArgument($outputPath)
    $null = $script:Worker.AddArgument($statePath)
    $null = $script:Worker.AddArgument($appRoot)
    $null = $script:Worker.AddArgument($ffmpegRoot)
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
            $availableWidth = 470.0
            $ProgressFill.Width = $availableWidth * ($progress / 100.0)
            $ProgressPercent.Text = "$([Math]::Round($progress))%"
            $ProgressStatus.Text = [string]$state.message

            switch ([string]$state.stage) {
                "downloading" {
                    $LoadingTitle.Text = "Preparing the converter..."
                    $LoadingSubtitle.Text = "Downloading FFmpeg once for future conversions"
                }
                "extracting" {
                    $LoadingTitle.Text = "Installing converter..."
                    $LoadingSubtitle.Text = "This only happens on the first run"
                }
                "converting" {
                    $LoadingTitle.Text = "Converting your video..."
                    $LoadingSubtitle.Text = "Extracting audio and encoding a 256 kbps MP3"
                }
                "complete" {
                    $script:Timer.Stop()

                    if ($script:Worker -and $script:WorkerHandle) {
                        try { $script:Worker.EndInvoke($script:WorkerHandle) } catch {}
                        $script:Worker.Dispose()
                        $script:Worker = $null
                    }

                    $outputItem = Get-Item -LiteralPath $script:OutputFile
                    $ResultFileName.Text = $outputItem.Name
                    $ResultFileInfo.Text = "$(Format-FileSize $outputItem.Length)  |  MP3 audio  |  320 kbps"
                    Show-View "Result"
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
                        $message = "The video could not be converted."
                    }

                    if ($message.Length -gt 600) {
                        $message = $message.Substring(0, 600) + "..."
                    }

                    $ErrorMessage.Text = $message
                    Show-View "Error"
                }
            }
        }
        catch {
            # State file can be replaced while it is being read. Try again next tick.
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
    $CloseButton.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#D82937")
    $CloseButton.Foreground = [Windows.Media.Brushes]::White
})

$CloseButton.Add_MouseLeave({
    $CloseButton.Background = [Windows.Media.Brushes]::Transparent
    $CloseButton.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#8A8E90")
})

$ChooseFileButton.Add_Click({
    Select-VideoFile
})

$DropZone.Add_MouseLeftButtonDown({
    if (-not $script:SelectedFile) {
        Select-VideoFile
    }
})

$DropZone.Add_DragEnter({
    if ($_.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        $_.Effects = [Windows.DragDropEffects]::Copy
        $DropZone.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#D82937")
        $DropZone.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#111314")
    }
    else {
        $_.Effects = [Windows.DragDropEffects]::None
    }

    $_.Handled = $true
})

$DropZone.Add_DragLeave({
    $DropZone.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#283032")
    $DropZone.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#0C0F10")
})

$DropZone.Add_Drop({
    $DropZone.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString("#283032")
    $DropZone.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#0C0F10")

    if ($_.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        $files = $_.Data.GetData([Windows.DataFormats]::FileDrop)
        if ($files.Count -gt 0) {
            Set-SelectedFile $files[0]
        }
    }
})

$RemoveFileButton.Add_Click({
    Reset-Selection
})

$ConvertButton.Add_Click({
    Start-Conversion
})

$SaveMp3Button.Add_Click({
    if (-not $script:OutputFile -or -not (Test-Path -LiteralPath $script:OutputFile)) {
        return
    }

    $source = Get-Item -LiteralPath $script:OutputFile
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = "Save MP3"
    $dialog.Filter = "MP3 audio|*.mp3"
    $dialog.FileName = $source.Name
    $dialog.DefaultExt = ".mp3"
    $dialog.AddExtension = $true

    if ($dialog.ShowDialog() -eq $true) {
        $destination = $dialog.FileName

        if ([string]::Equals($source.FullName, $destination, [StringComparison]::OrdinalIgnoreCase)) {
            [System.Windows.MessageBox]::Show(
                "The MP3 is already saved in this location.",
                "MP3 saved",
                "OK",
                "Information") | Out-Null
        }
        else {
            Copy-Item -LiteralPath $source.FullName -Destination $destination -Force
            [System.Windows.MessageBox]::Show(
                "MP3 saved successfully.",
                "Complete",
                "OK",
                "Information") | Out-Null
        }
    }
})

$OpenFolderButton.Add_Click({
    if ($script:OutputFile -and (Test-Path -LiteralPath $script:OutputFile)) {
        Start-Process explorer.exe -ArgumentList "/select,`"$script:OutputFile`""
    }
})

$ConvertAnotherButton.Add_Click({
    Reset-Selection
})

$TryAgainButton.Add_Click({
    if ($script:SelectedFile -and (Test-Path -LiteralPath $script:SelectedFile)) {
        Start-Conversion
    }
    else {
        Reset-Selection
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
    Remove-Item -LiteralPath ($script:StateFile + ".tmp") -Force -ErrorAction SilentlyContinue
})

Set-StepState "Select"
$Window.ShowDialog() | Out-Null
