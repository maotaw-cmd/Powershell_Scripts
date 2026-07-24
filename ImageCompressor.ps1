#requires -Version 5.1
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Image Compressor"
        Width="440"
        Height="640"
        WindowStartupLocation="CenterScreen"
        Background="Transparent"
        AllowsTransparency="True"
        WindowStyle="None"
        FontFamily="Segoe UI"
        ResizeMode="NoResize"
        AllowDrop="True">

    <Window.Resources>
        <SolidColorBrush x:Key="Blue" Color="#075CE8"/>
        <SolidColorBrush x:Key="BlueHover" Color="#004FCE"/>
        <SolidColorBrush x:Key="Text" Color="#111827"/>
        <SolidColorBrush x:Key="Muted" Color="#596579"/>

        <Style x:Key="MainButton" TargetType="Button">
            <Setter Property="Height" Value="48"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="#075CE8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd"
                                Background="{TemplateBinding Background}"
                                CornerRadius="7">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#004FCE"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#0044B4"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Bd" Property="Background" Value="#E4E8EE"/>
                                <Setter Property="Foreground" Value="#9BA3AE"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SmallButton" TargetType="Button" BasedOn="{StaticResource MainButton}">
            <Setter Property="Height" Value="36"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>

        <Style x:Key="CaptionButton" TargetType="Button">
            <Setter Property="Width" Value="43"/>
            <Setter Property="Height" Value="42"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="#141922"/>
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
                                <Setter TargetName="Bd" Property="Background" Value="#EDF1F6"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#394457"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Margin" Value="0,0,0,9"/>
        </Style>

        <Style x:Key="ModernSlider" TargetType="Slider">
            <Setter Property="Height" Value="24"/>
            <Setter Property="Minimum" Value="1"/>
            <Setter Property="Maximum" Value="100"/>
            <Setter Property="IsSnapToTickEnabled" Value="False"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Slider">
                        <Grid VerticalAlignment="Center">
                            <Border Height="5" CornerRadius="3" Background="#DFE6F0"/>
                            <Track x:Name="PART_Track">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Command="Slider.DecreaseLarge"
                                                  Background="#075CE8"
                                                  BorderThickness="0">
                                        <RepeatButton.Template>
                                            <ControlTemplate TargetType="RepeatButton">
                                                <Border Background="{TemplateBinding Background}"
                                                        CornerRadius="3"/>
                                            </ControlTemplate>
                                        </RepeatButton.Template>
                                    </RepeatButton>
                                </Track.DecreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb Width="17" Height="17">
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Width="17" Height="17"
                                                        CornerRadius="9"
                                                        Background="White"
                                                        BorderBrush="#075CE8"
                                                        BorderThickness="3"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Command="Slider.IncreaseLarge"
                                                  Background="Transparent"
                                                  BorderThickness="0">
                                        <RepeatButton.Template>
                                            <ControlTemplate TargetType="RepeatButton">
                                                <Border Background="Transparent"/>
                                            </ControlTemplate>
                                        </RepeatButton.Template>
                                    </RepeatButton>
                                </Track.IncreaseRepeatButton>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="InvisibleScrollButton" TargetType="RepeatButton">
            <Setter Property="Focusable" Value="False"/>
            <Setter Property="IsTabStop" Value="False"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RepeatButton">
                        <Border Background="Transparent"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ScrollBar">
            <Setter Property="Width" Value="4"/>
            <Setter Property="MinWidth" Value="4"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Width="4" Background="Transparent">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageUpCommand"
                                                  Style="{StaticResource InvisibleScrollButton}"/>
                                </Track.DecreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb Width="4">
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border x:Name="ThumbBorder"
                                                        Width="4"
                                                        CornerRadius="2"
                                                        Background="#AEB8C6"/>
                                                <ControlTemplate.Triggers>
                                                    <Trigger Property="IsMouseOver" Value="True">
                                                        <Setter TargetName="ThumbBorder"
                                                                Property="Background"
                                                                Value="#7E8A9C"/>
                                                    </Trigger>
                                                    <Trigger Property="IsDragging" Value="True">
                                                        <Setter TargetName="ThumbBorder"
                                                                Property="Background"
                                                                Value="#075CE8"/>
                                                    </Trigger>
                                                </ControlTemplate.Triggers>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageDownCommand"
                                                  Style="{StaticResource InvisibleScrollButton}"/>
                                </Track.IncreaseRepeatButton>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

    </Window.Resources>

    <Border Background="#F8FAFD"
            BorderBrush="#DFE5ED"
            BorderThickness="1"
            CornerRadius="11">
        <Grid ClipToBounds="True">
            <Grid.RowDefinitions>
                <RowDefinition Height="42"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- top bar -->
            <Grid x:Name="TopBar" Grid.Row="0" Background="#F8FAFD">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="43"/>
                    <ColumnDefinition Width="43"/>
                </Grid.ColumnDefinitions>

                <Button x:Name="MinButton"
                        Grid.Column="1"
                        Content="&#xE921;"
                        FontFamily="Segoe MDL2 Assets"
                        FontSize="10"
                        Style="{StaticResource CaptionButton}"/>

                <Button x:Name="CloseButton"
                        Grid.Column="2"
                        Content="&#xE8BB;"
                        FontFamily="Segoe MDL2 Assets"
                        FontSize="13"
                        Style="{StaticResource CaptionButton}"/>
            </Grid>

            <ScrollViewer Grid.Row="1"
                          VerticalScrollBarVisibility="Auto"
                          HorizontalScrollBarVisibility="Disabled"
                          Padding="0,0,3,0">
                <Grid Margin="17,2,14,14">
                    <StackPanel>

                        <!-- compact header -->
                        <Grid Margin="0,0,0,12">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="44"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <Border Width="38" Height="38"
                                    CornerRadius="7"
                                    Background="#075CE8"
                                    VerticalAlignment="Center">
                                <Canvas Width="24" Height="19"
                                        HorizontalAlignment="Center"
                                        VerticalAlignment="Center">
                                    <Path Data="M2,2 L10,9.5 L2,17"
                                          Stroke="White"
                                          StrokeThickness="2.7"
                                          StrokeStartLineCap="Round"
                                          StrokeEndLineCap="Round"
                                          StrokeLineJoin="Round"/>
                                    <Line X1="12" Y1="17" X2="22" Y2="17"
                                          Stroke="White"
                                          StrokeThickness="2.7"
                                          StrokeStartLineCap="Round"/>
                                </Canvas>
                            </Border>

                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Image Compressor"
                                           Foreground="#111827"
                                           FontSize="19"
                                           FontWeight="Bold"/>
                                <TextBlock Text="PowerShell image optimizer"
                                           Foreground="#627086"
                                           FontSize="11"
                                           Margin="0,2,0,0"/>
                            </StackPanel>
                        </Grid>

                        <!-- compact upload area -->
                        <Border x:Name="DropArea"
                                AllowDrop="True"
                                Background="#FBFCFF"
                                BorderBrush="#8CB8FF"
                                BorderThickness="1"
                                CornerRadius="9"
                                Padding="14,12">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="62"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="145"/>
                                </Grid.ColumnDefinitions>

                                <Viewbox Width="48" Height="44"
                                         HorizontalAlignment="Left"
                                         VerticalAlignment="Center">
                                    <Canvas Width="84" Height="76">
                                        <Rectangle Width="78" Height="68"
                                                   RadiusX="12" RadiusY="12"
                                                   Stroke="#0877F2"
                                                   StrokeThickness="4"
                                                   Canvas.Left="3"
                                                   Canvas.Top="3"/>
                                        <Ellipse Width="16" Height="16"
                                                 Stroke="#0877F2"
                                                 StrokeThickness="4"
                                                 Canvas.Left="55"
                                                 Canvas.Top="16"/>
                                        <Path Data="M9,62 L31,37 L47,53 L58,42 L78,65"
                                              Stroke="#0877F2"
                                              StrokeThickness="4"
                                              StrokeLineJoin="Round"
                                              StrokeStartLineCap="Round"
                                              StrokeEndLineCap="Round"/>
                                    </Canvas>
                                </Viewbox>

                                <StackPanel Grid.Column="1"
                                            VerticalAlignment="Center"
                                            Margin="3,0,10,0">
                                    <TextBlock x:Name="DropTitle"
                                               Text=""
                                               Foreground="#111827"
                                               FontSize="14"
                                               FontWeight="SemiBold"
                                               TextTrimming="CharacterEllipsis"/>
                                    <TextBlock x:Name="CountText"
                                               Text="Choose or drop images"
                                               Foreground="#637087"
                                               FontSize="11"
                                               Margin="0,3,0,0"
                                               TextTrimming="CharacterEllipsis"/>
                                </StackPanel>

                                <Button x:Name="UploadButton"
                                        Grid.Column="2"
                                        Height="38"
                                        Content="Choose Images"
                                        Style="{StaticResource SmallButton}"/>
                            </Grid>
                        </Border>

                        <!-- compact settings -->
                        <Border Background="White"
                                BorderBrush="#E3E8EF"
                                BorderThickness="1"
                                CornerRadius="9"
                                Margin="0,11,0,0"
                                Padding="14">
                            <StackPanel>
                                <Grid>
                                    <TextBlock Text="Compression quality"
                                               Foreground="#172033"
                                               FontSize="13"
                                               FontWeight="SemiBold"/>
                                    <TextBlock x:Name="QualityInfo"
                                               Text="75%"
                                               Foreground="#075CE8"
                                               FontSize="13"
                                               FontWeight="Bold"
                                               HorizontalAlignment="Right"/>
                                </Grid>

                                <Slider x:Name="QualitySlider"
                                        Value="75"
                                        TickFrequency="1"
                                        Margin="0,7,0,0"
                                        Style="{StaticResource ModernSlider}"/>

                                <Grid Margin="0,0,0,10">
                                    <TextBlock Text="Smaller"
                                               Foreground="#8A94A3"
                                               FontSize="9"/>
                                    <TextBlock Text="Better quality"
                                               Foreground="#8A94A3"
                                               FontSize="9"
                                               HorizontalAlignment="Right"/>
                                </Grid>

                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="12"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <StackPanel>
                                        <TextBlock Text="Resize"
                                                   Foreground="#172033"
                                                   FontSize="12"
                                                   FontWeight="SemiBold"/>

                                        <ComboBox x:Name="ResizeCombo"
                                                  Height="34"
                                                  Margin="0,6,0,0"
                                                  SelectedIndex="0"
                                                  Background="#F7F9FC"
                                                  BorderBrush="#DCE2EA"
                                                  Foreground="#283347"
                                                  Padding="8,3">
                                            <ComboBoxItem Content="Original size" Tag="1.0"/>
                                            <ComboBoxItem Content="75% size" Tag="0.75"/>
                                            <ComboBoxItem Content="50% size" Tag="0.5"/>
                                            <ComboBoxItem Content="33% size" Tag="0.33"/>
                                        </ComboBox>
                                    </StackPanel>

                                    <StackPanel Grid.Column="2">
                                        <TextBlock Text="Output"
                                                   Foreground="#172033"
                                                   FontSize="12"
                                                   FontWeight="SemiBold"/>
                                        <CheckBox x:Name="ConvertPngCheck"
                                                  Content="PNG to JPG"
                                                  IsChecked="True"
                                                  Margin="0,7,0,4"/>
                                        <CheckBox x:Name="OpenAfterCheck"
                                                  Content="Open when done"
                                                  IsChecked="True"
                                                  Margin="0,0,0,0"/>
                                    </StackPanel>
                                </Grid>

                                <Border Height="1"
                                        Background="#EDF0F4"
                                        Margin="0,11,0,10"/>

                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="12"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <CheckBox x:Name="KeepMetadataCheck"
                                              Content="Keep metadata"
                                              IsChecked="False"
                                              Margin="0,0,0,0"/>

                                    <CheckBox x:Name="OverwriteCheck"
                                              Grid.Column="2"
                                              Content="Overwrite existing"
                                              IsChecked="False"
                                              Margin="0,0,0,0"/>
                                </Grid>

                                <Grid Margin="0,11,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="9"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <Button x:Name="ClearButton"
                                            Content="Clear"
                                            Background="#EEF3FA"
                                            Foreground="#344054"
                                            Style="{StaticResource SmallButton}"/>

                                    <Button x:Name="OpenFolderButton"
                                            Grid.Column="2"
                                            Content="Open Output"
                                            Style="{StaticResource SmallButton}"/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <Button x:Name="CompressButton"
                                Content="Compress Images"
                                IsEnabled="False"
                                Margin="0,11,0,0"
                                Height="44"
                                Style="{StaticResource MainButton}"/>

                        <ProgressBar x:Name="ProgressBar"
                                     Minimum="0"
                                     Maximum="100"
                                     Value="0"
                                     Height="6"
                                     Margin="0,10,0,0"/>

                        <TextBlock x:Name="ResultText"
                                   Text="Waiting for images..."
                                   Foreground="#526074"
                                   FontSize="11"
                                   TextWrapping="Wrap"
                                   Margin="0,7,0,0"/>

                        <TextBlock x:Name="SavedText"
                                   Text=""
                                   Foreground="#0B9F55"
                                   FontSize="15"
                                   FontWeight="Bold"
                                   Margin="0,3,0,0"/>
                    </StackPanel>
                </Grid>
            </ScrollViewer>
        </Grid>
    </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = @(
    "TopBar","MinButton","CloseButton","DropArea","DropTitle","UploadButton",
    "CountText","QualitySlider","QualityInfo","ResizeCombo","ConvertPngCheck",
    "OpenAfterCheck","KeepMetadataCheck","OverwriteCheck","ClearButton",
    "OpenFolderButton","CompressButton","ProgressBar","ResultText","SavedText"
)

foreach ($name in $names) {
    Set-Variable -Name $name -Value $window.FindName($name) -Scope Script
}

$selectedFiles = New-Object System.Collections.Generic.List[string]
$script:Quality = 75
$script:Scale = 1.0
$script:LastOutputFolder = $null

function Format-Size {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N0} KB" -f ($Bytes / 1KB) }
    return "$Bytes bytes"
}

function Update-SelectionUi {
    $count = $selectedFiles.Count

    if ($count -eq 0) {
        $DropTitle.Text = ""
        $CountText.Text = "Choose or drop images"
        $CompressButton.IsEnabled = $false
    }
    elseif ($count -eq 1) {
        $DropTitle.Text = "1 image selected"
        $CountText.Text = [IO.Path]::GetFileName($selectedFiles[0])
        $CompressButton.IsEnabled = $true
    }
    else {
        $DropTitle.Text = "$count images selected"
        $CountText.Text = "Ready to compress all selected images."
        $CompressButton.IsEnabled = $true
    }
}

function Update-OutputFolder {
    if ($selectedFiles.Count -gt 0) {
        $firstFile = Get-Item -LiteralPath $selectedFiles[0]
        $script:LastOutputFolder = Join-Path $firstFile.DirectoryName "Compressed"
    }
}

function Add-Images {
    param([string[]]$Paths)

    $allowed = @(".jpg", ".jpeg", ".png", ".bmp")

    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $item = Get-Item -LiteralPath $path

        if ($item.PSIsContainer) {
            $files = Get-ChildItem -LiteralPath $item.FullName -File |
                Where-Object { $allowed -contains $_.Extension.ToLowerInvariant() }
        }
        else {
            $files = @($item)
        }

        foreach ($file in $files) {
            if ($allowed -contains $file.Extension.ToLowerInvariant()) {
                if (-not $selectedFiles.Contains($file.FullName)) {
                    [void]$selectedFiles.Add($file.FullName)
                }
            }
        }
    }

    Update-OutputFolder
    Update-SelectionUi
    $ProgressBar.Value = 0
    $ResultText.Text = "Ready to compress."
    $SavedText.Text = ""
}

function Open-Images {
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = "Choose images"
    $dialog.Filter = "Image files|*.jpg;*.jpeg;*.png;*.bmp"
    $dialog.Multiselect = $true

    if ($dialog.ShowDialog() -eq $true) {
        Add-Images -Paths $dialog.FileNames
    }
}

function Open-OutputFolder {
    if (-not $script:LastOutputFolder) {
        Update-OutputFolder
    }

    if (-not $script:LastOutputFolder) {
        [Windows.MessageBox]::Show(
            "Choose an image first.",
            "No output folder",
            "OK",
            "Information"
        ) | Out-Null
        return
    }

    New-Item -ItemType Directory -Path $script:LastOutputFolder -Force | Out-Null
    Start-Process explorer.exe -ArgumentList "`"$script:LastOutputFolder`""
}

function Get-OutputPath {
    param(
        [IO.FileInfo]$File,
        [bool]$SaveAsJpg
    )

    $outputFolder = Join-Path $File.DirectoryName "Compressed"
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
    $script:LastOutputFolder = $outputFolder

    $baseName = [IO.Path]::GetFileNameWithoutExtension($File.Name) + "-compressed"
    $extension = if ($SaveAsJpg) { ".jpg" } else { ".png" }
    $output = Join-Path $outputFolder ($baseName + $extension)

    if ([bool]$OverwriteCheck.IsChecked) {
        return $output
    }

    $index = 1
    while (Test-Path -LiteralPath $output) {
        $output = Join-Path $outputFolder ("{0}-{1}{2}" -f $baseName, $index, $extension)
        $index++
    }

    return $output
}

function Compress-OneImage {
    param([string]$FilePath)

    $file = Get-Item -LiteralPath $FilePath
    $image = $null
    $bitmap = $null
    $graphics = $null
    $encoderParams = $null

    try {
        $image = [Drawing.Image]::FromFile($file.FullName)

        $newWidth = [Math]::Max(1, [int]($image.Width * $script:Scale))
        $newHeight = [Math]::Max(1, [int]($image.Height * $script:Scale))

        $extension = $file.Extension.ToLowerInvariant()
        $saveAsJpg = ($extension -in @(".jpg", ".jpeg", ".bmp")) -or
                     ($extension -eq ".png" -and [bool]$ConvertPngCheck.IsChecked)

        $outputPath = Get-OutputPath -File $file -SaveAsJpg $saveAsJpg

        if ($saveAsJpg) {
            $bitmap = New-Object Drawing.Bitmap($newWidth, $newHeight)
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            $graphics.Clear([Drawing.Color]::White)
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($image, 0, 0, $newWidth, $newHeight)

            $jpgEncoder = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
                Where-Object { $_.MimeType -eq "image/jpeg" } |
                Select-Object -First 1

            $encoderParams = New-Object Drawing.Imaging.EncoderParameters(1)
            $encoderParams.Param[0] = New-Object Drawing.Imaging.EncoderParameter(
                [Drawing.Imaging.Encoder]::Quality,
                [long]$script:Quality
            )

            $bitmap.Save($outputPath, $jpgEncoder, $encoderParams)
        }
        else {
            $bitmap = New-Object Drawing.Bitmap(
                $newWidth,
                $newHeight,
                [Drawing.Imaging.PixelFormat]::Format32bppArgb
            )

            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            $graphics.Clear([Drawing.Color]::Transparent)
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($image, 0, 0, $newWidth, $newHeight)
            $bitmap.Save($outputPath, [Drawing.Imaging.ImageFormat]::Png)
        }

        $oldSize = $file.Length
        $newSize = (Get-Item -LiteralPath $outputPath).Length

        return [PSCustomObject]@{
            Success = $true
            OldSize = $oldSize
            NewSize = $newSize
            Saved = $oldSize - $newSize
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            OldSize = 0
            NewSize = 0
            Saved = 0
            Error = $_.Exception.Message
        }
    }
    finally {
        if ($encoderParams) { $encoderParams.Dispose() }
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($image) { $image.Dispose() }
    }
}

$TopBar.Add_MouseLeftButtonDown({
    if ($_.ChangedButton -eq [Windows.Input.MouseButton]::Left) {
        try { $window.DragMove() } catch {}
    }
})

$MinButton.Add_Click({
    $window.WindowState = "Minimized"
})

$CloseButton.Add_Click({
    $window.Close()
})

$CloseButton.Add_MouseEnter({
    $CloseButton.Background = [Windows.Media.BrushConverter]::new().ConvertFromString("#E81123")
    $CloseButton.Foreground = [Windows.Media.Brushes]::White
})

$CloseButton.Add_MouseLeave({
    $CloseButton.Background = [Windows.Media.Brushes]::Transparent
    $CloseButton.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString("#141922")
})

$UploadButton.Add_Click({
    Open-Images
})

$DropArea.Add_MouseLeftButtonDown({
    Open-Images
})

$window.Add_DragOver({
    if ($_.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        $_.Effects = [Windows.DragDropEffects]::Copy
    }
    else {
        $_.Effects = [Windows.DragDropEffects]::None
    }

    $_.Handled = $true
})

$window.Add_Drop({
    if ($_.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        Add-Images -Paths $_.Data.GetData([Windows.DataFormats]::FileDrop)
    }
})

$QualitySlider.Add_ValueChanged({
    $script:Quality = [int][Math]::Round($QualitySlider.Value)
    $QualityInfo.Text = "$script:Quality%"
})

$ResizeCombo.Add_SelectionChanged({
    $item = $ResizeCombo.SelectedItem

    if ($item -and $item.Tag) {
        $script:Scale = [double]::Parse(
            [string]$item.Tag,
            [Globalization.CultureInfo]::InvariantCulture
        )
    }
})

$ClearButton.Add_Click({
    $selectedFiles.Clear()
    $script:LastOutputFolder = $null
    $ProgressBar.Value = 0
    $ResultText.Text = "Waiting for images..."
    $SavedText.Text = ""
    Update-SelectionUi
})

$OpenFolderButton.Add_Click({
    Open-OutputFolder
})

$CompressButton.Add_Click({
    if ($selectedFiles.Count -eq 0) {
        return
    }

    $CompressButton.IsEnabled = $false
    $UploadButton.IsEnabled = $false
    $ClearButton.IsEnabled = $false
    $ProgressBar.Value = 0
    $ResultText.Text = "Compressing images..."
    $SavedText.Text = ""

    $totalOld = 0L
    $totalNew = 0L
    $totalSaved = 0L
    $success = 0
    $failed = 0
    $index = 0

    foreach ($file in @($selectedFiles)) {
        $index++
        $ResultText.Text = "Compressing $index of $($selectedFiles.Count)..."
        $window.Dispatcher.Invoke(
            [Action]{},
            [Windows.Threading.DispatcherPriority]::Background
        )

        $result = Compress-OneImage -FilePath $file

        if ($result.Success) {
            $success++
            $totalOld += $result.OldSize
            $totalNew += $result.NewSize
            $totalSaved += $result.Saved
        }
        else {
            $failed++
        }

        $ProgressBar.Value = ($index / $selectedFiles.Count) * 100
    }

    $percent = if ($totalOld -gt 0) {
        [Math]::Round(($totalSaved / [double]$totalOld) * 100, 1)
    }
    else {
        0
    }

    $ResultText.Text = "Compressed $success image(s). Original: $(Format-Size $totalOld)  →  New: $(Format-Size $totalNew)"

    if ($failed -gt 0) {
        $ResultText.Text += "  |  $failed failed"
    }

    $SavedText.Text = "Saved $(Format-Size $totalSaved) ($percent%)"

    $CompressButton.IsEnabled = $true
    $UploadButton.IsEnabled = $true
    $ClearButton.IsEnabled = $true

    if ([bool]$OpenAfterCheck.IsChecked) {
        Open-OutputFolder
    }
})

Update-SelectionUi
[void]$window.ShowDialog()
