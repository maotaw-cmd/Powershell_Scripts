Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GetCompress"
        Width="1120"
        Height="720"
        WindowStartupLocation="CenterScreen"
        Background="Transparent"
        AllowsTransparency="True"
        WindowStyle="None"
        FontFamily="Segoe UI"
        ResizeMode="NoResize"
        AllowDrop="True">

    <Window.Resources>

        <Style TargetType="{x:Type Button}">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type Button}">
                        <Border x:Name="ButtonBorder"
                                Background="{TemplateBinding Background}"
                                CornerRadius="8"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                BorderBrush="{TemplateBinding BorderBrush}">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.85"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.70"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="InvisibleScrollButton" TargetType="{x:Type RepeatButton}">
            <Setter Property="Focusable" Value="False"/>
            <Setter Property="IsTabStop" Value="False"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type RepeatButton}">
                        <Border Background="Transparent"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="{x:Type ScrollBar}">
            <Setter Property="Width" Value="8"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ScrollBar}">
                        <Grid Width="8" Background="Transparent">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageUpCommand"
                                                  Style="{StaticResource InvisibleScrollButton}"/>
                                </Track.DecreaseRepeatButton>

                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="{x:Type Thumb}">
                                                <Border x:Name="ThumbBorder"
                                                        Width="6"
                                                        CornerRadius="4"
                                                        Background="#4F5570"/>
                                                <ControlTemplate.Triggers>
                                                    <Trigger Property="IsMouseOver" Value="True">
                                                        <Setter TargetName="ThumbBorder" Property="Background" Value="#6366F1"/>
                                                    </Trigger>
                                                    <Trigger Property="IsDragging" Value="True">
                                                        <Setter TargetName="ThumbBorder" Property="Background" Value="#818CF8"/>
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

    <Grid Margin="14">

        <Border CornerRadius="22"
                Background="#E6111220"
                BorderBrush="#22FFFFFF"
                BorderThickness="1">

            <Border.Effect>
                <DropShadowEffect Color="#000000"
                                  BlurRadius="35"
                                  ShadowDepth="0"
                                  Opacity="0.55"/>
            </Border.Effect>

            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="48"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <Grid x:Name="TopBar" Grid.Row="0" Margin="18,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Ellipse Width="12" Height="12" Fill="#FF5F57" Margin="0,0,8,0"/>
                        <Ellipse Width="12" Height="12" Fill="#FFBD2E" Margin="0,0,8,0"/>
                        <Ellipse Width="12" Height="12" Fill="#28C840"/>
                    </StackPanel>

                    <TextBlock Grid.Column="1"
                               Text="GetCompress"
                               Foreground="#D7DAE3"
                               FontSize="13"
                               FontWeight="SemiBold"
                               HorizontalAlignment="Center"
                               VerticalAlignment="Center"/>

                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="MinButton"
                                Content="_"
                                Width="38"
                                Height="28"
                                Background="#222638"
                                Foreground="#D7DAE3"
                                BorderThickness="0"
                                Margin="0,0,8,0"/>

                        <Button x:Name="CloseButton"
                                Content="X"
                                Width="38"
                                Height="28"
                                Background="#EF4444"
                                Foreground="White"
                                BorderThickness="0"/>
                    </StackPanel>
                </Grid>

                <Grid Grid.Row="1" Margin="24,12,24,24">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="360"/>
                    </Grid.ColumnDefinitions>

                    <Grid x:Name="DropArea"
                          Grid.Column="0"
                          AllowDrop="True"
                          Margin="0,0,20,0">

                        <Rectangle RadiusX="18"
                                   RadiusY="18"
                                   Fill="#33141628"
                                   Stroke="#25FFFFFF"
                                   StrokeThickness="1.5"
                                   StrokeDashArray="7 6"/>

                        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">

                            <TextBlock Text="Drag your images here"
                                       Foreground="#F3F4F6"
                                       FontSize="24"
                                       FontWeight="SemiBold"
                                       TextAlignment="Center"/>

                            <TextBlock Text="or upload JPG and PNG files"
                                       Foreground="#8B91A3"
                                       FontSize="14"
                                       TextAlignment="Center"
                                       Margin="0,10,0,26"/>

                            <Button x:Name="UploadButton"
                                    Content="Upload Files"
                                    Width="170"
                                    Height="44"
                                    Background="#6366F1"
                                    Foreground="White"
                                    FontWeight="SemiBold"
                                    BorderThickness="0"/>

                            <TextBlock x:Name="CountText"
                                       Text="No files selected"
                                       Foreground="#A8B1C7"
                                       FontSize="13"
                                       TextAlignment="Center"
                                       Margin="0,22,0,0"/>
                        </StackPanel>
                    </Grid>

                    <Border Grid.Column="1"
                            CornerRadius="18"
                            Background="#66191B2B"
                            BorderBrush="#20FFFFFF"
                            BorderThickness="1"
                            Padding="18">

                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <ScrollViewer Grid.Row="0"
                                          VerticalScrollBarVisibility="Auto"
                                          HorizontalScrollBarVisibility="Disabled"
                                          Margin="0,0,0,16">

                                <StackPanel Margin="0,0,8,0">

                                    <TextBlock Text="Output"
                                               Foreground="#F9FAFB"
                                               FontSize="16"
                                               FontWeight="Bold"
                                               Margin="0,0,0,16"/>

                                    <TextBlock Text="Folder"
                                               Foreground="#8B91A3"
                                               FontSize="12"/>

                                    <TextBox x:Name="FolderBox"
                                             Text="Same as input"
                                             Height="36"
                                             Background="#26293B"
                                             Foreground="#D7DAE3"
                                             BorderThickness="0"
                                             Padding="10,7"
                                             IsReadOnly="True"
                                             Margin="0,7,0,14"/>

                                    <Button x:Name="OpenFolderButton"
                                            Content="Open Output Folder"
                                            Height="36"
                                            Background="#30364A"
                                            Foreground="#D7DAE3"
                                            BorderThickness="0"
                                            Margin="0,0,0,18"/>

                                    <TextBlock Text="File name"
                                               Foreground="#8B91A3"
                                               FontSize="12"/>

                                    <TextBox x:Name="FormatBox"
                                             Text="{}{input}-compressed"
                                             Height="36"
                                             Background="#26293B"
                                             Foreground="#D7DAE3"
                                             BorderThickness="0"
                                             Padding="10,7"
                                             Margin="0,7,0,14"/>

                                    <TextBlock Text="More settings"
                                               Foreground="#8B91A3"
                                               FontSize="12"/>

                                    <StackPanel Margin="0,8,0,20">
                                        <CheckBox x:Name="ConvertPngCheck"
                                                  Content="Convert PNG to JPG"
                                                  Foreground="#C9CEDA"
                                                  FontSize="12"
                                                  IsChecked="True"
                                                  Margin="0,0,0,8"/>

                                        <CheckBox x:Name="OpenAfterCheck"
                                                  Content="Open output folder after compress"
                                                  Foreground="#C9CEDA"
                                                  FontSize="12"
                                                  IsChecked="True"/>
                                    </StackPanel>

                                    <TextBlock Text="Image settings"
                                               Foreground="#F9FAFB"
                                               FontSize="16"
                                               FontWeight="Bold"
                                               Margin="0,0,0,16"/>

                                    <TextBlock Text="Quality"
                                               Foreground="#8B91A3"
                                               FontSize="12"/>

                                    <UniformGrid Columns="3" Margin="0,8,0,14">
                                        <Button x:Name="QOriginal" Content="Original" Margin="0,0,6,6" Height="34" Background="#26293B" Foreground="#D7DAE3" BorderThickness="0"/>
                                        <Button x:Name="QBalanced" Content="Balanced" Margin="3,0,3,6" Height="34" Background="#6366F1" Foreground="White" BorderThickness="0"/>
                                        <Button x:Name="QHigh" Content="High" Margin="6,0,0,6" Height="34" Background="#26293B" Foreground="#D7DAE3" BorderThickness="0"/>
                                        <Button x:Name="QMedium" Content="Medium" Margin="0,0,6,0" Height="34" Background="#26293B" Foreground="#D7DAE3" BorderThickness="0"/>
                                        <Button x:Name="QLow" Content="Low" Margin="3,0,3,0" Height="34" Background="#26293B" Foreground="#D7DAE3" BorderThickness="0"/>
                                    </UniformGrid>

                                    <TextBlock x:Name="QualityInfo"
                                               Text="Quality: 70%"
                                               Foreground="#A8B1C7"
                                               FontSize="12"
                                               Margin="0,0,0,14"/>

                                    <TextBlock Text="Resolution"
                                               Foreground="#8B91A3"
                                               FontSize="12"/>

                                    <UniformGrid Columns="4" Margin="0,8,0,0">
                                        <Button x:Name="R1" Content="1x" Margin="0,0,6,0" Height="34" Background="#6366F1" Foreground="White" BorderThickness="0"/>
                                        <Button x:Name="R075" Content="0.75x" Margin="3,0,3,0" Height="34" Background="#26293B" Foreground="#D7DAE3" BorderThickness="0"/>
                                        <Button x:Name="R05" Content="0.5x" Margin="3,0,3,0" Height="34" Background="#26293B" Foreground="#D7DAE3" BorderThickness="0"/>
                                        <Button x:Name="R033" Content="0.33x" Margin="6,0,0,0" Height="34" Background="#26293B" Foreground="#D7DAE3" BorderThickness="0"/>
                                    </UniformGrid>

                                </StackPanel>
                            </ScrollViewer>

                            <StackPanel Grid.Row="1">

                                <Button x:Name="CompressButton"
                                        Content="Compress Images"
                                        Height="46"
                                        Background="#6366F1"
                                        Foreground="White"
                                        FontWeight="SemiBold"
                                        BorderThickness="0"/>

                                <ProgressBar x:Name="ProgressBar"
                                             Height="8"
                                             Minimum="0"
                                             Maximum="100"
                                             Value="0"
                                             Margin="0,16,0,12"/>

                                <TextBlock x:Name="ResultText"
                                           Text="Waiting for images..."
                                           Foreground="#C9CEDA"
                                           FontSize="13"
                                           TextWrapping="Wrap"/>

                                <TextBlock x:Name="SavedText"
                                           Text=""
                                           Foreground="#22C55E"
                                           FontSize="24"
                                           FontWeight="Bold"
                                           Margin="0,8,0,0"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                </Grid>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$TopBar = $window.FindName("TopBar")
$UploadButton = $window.FindName("UploadButton")
$CountText = $window.FindName("CountText")
$FolderBox = $window.FindName("FolderBox")
$FormatBox = $window.FindName("FormatBox")
$ConvertPngCheck = $window.FindName("ConvertPngCheck")
$OpenAfterCheck = $window.FindName("OpenAfterCheck")
$CompressButton = $window.FindName("CompressButton")
$ProgressBar = $window.FindName("ProgressBar")
$ResultText = $window.FindName("ResultText")
$SavedText = $window.FindName("SavedText")
$QualityInfo = $window.FindName("QualityInfo")
$OpenFolderButton = $window.FindName("OpenFolderButton")
$MinButton = $window.FindName("MinButton")
$CloseButton = $window.FindName("CloseButton")

$QOriginal = $window.FindName("QOriginal")
$QBalanced = $window.FindName("QBalanced")
$QHigh = $window.FindName("QHigh")
$QMedium = $window.FindName("QMedium")
$QLow = $window.FindName("QLow")

$R1 = $window.FindName("R1")
$R075 = $window.FindName("R075")
$R05 = $window.FindName("R05")
$R033 = $window.FindName("R033")

$selectedFiles = New-Object System.Collections.Generic.List[string]
$script:Quality = 70
$script:Scale = 1.0
$script:LastOutputFolder = $null

$brushConverter = New-Object Windows.Media.BrushConverter

function Brush($hex) {
    return $brushConverter.ConvertFromString($hex)
}

function Format-Size($bytes) {
    if ($bytes -ge 1GB) { return "$([math]::Round($bytes / 1GB, 2)) GB" }
    if ($bytes -ge 1MB) { return "$([math]::Round($bytes / 1MB, 2)) MB" }
    if ($bytes -ge 1KB) { return "$([math]::Round($bytes / 1KB, 2)) KB" }
    return "$bytes bytes"
}

function Set-ButtonGroup($buttons, $selected) {
    foreach ($btn in $buttons) {
        $btn.Background = Brush "#26293B"
        $btn.Foreground = Brush "#D7DAE3"
    }

    $selected.Background = Brush "#6366F1"
    $selected.Foreground = Brush "#FFFFFF"
}

function Set-Quality($value, $button) {
    $script:Quality = $value
    $QualityInfo.Text = "Quality: $value%"
    Set-ButtonGroup @($QOriginal, $QBalanced, $QHigh, $QMedium, $QLow) $button
}

function Set-Resolution($value, $button) {
    $script:Scale = $value
    Set-ButtonGroup @($R1, $R075, $R05, $R033) $button
}

function Update-OutputFolder {
    if ($selectedFiles.Count -gt 0) {
        $firstFile = Get-Item $selectedFiles[0]
        $folder = Join-Path $firstFile.DirectoryName "Compressed"
        $script:LastOutputFolder = $folder
        $FolderBox.Text = $folder
    }
}

function Add-Images($paths) {
    $allowed = @(".jpg", ".jpeg", ".png")

    foreach ($path in $paths) {
        if (!(Test-Path $path)) { continue }

        $item = Get-Item $path

        if ($item.PSIsContainer) {
            $files = Get-ChildItem -Path $item.FullName -File | Where-Object {
                $allowed -contains $_.Extension.ToLower()
            }
        } else {
            $files = @($item)
        }

        foreach ($file in $files) {
            if ($allowed -contains $file.Extension.ToLower()) {
                if (!$selectedFiles.Contains($file.FullName)) {
                    $selectedFiles.Add($file.FullName)
                }
            }
        }
    }

    if ($selectedFiles.Count -eq 1) {
        $CountText.Text = "1 file selected"
    } else {
        $CountText.Text = "$($selectedFiles.Count) files selected"
    }

    Update-OutputFolder

    $ResultText.Text = "Ready to compress."
    $SavedText.Text = ""
    $ProgressBar.Value = 0
}

function Open-Images {
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = "Image files (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png"
    $dialog.Multiselect = $true

    if ($dialog.ShowDialog() -eq $true) {
        Add-Images $dialog.FileNames
    }
}

function Open-OutputFolder {
    if (!$script:LastOutputFolder -or [string]::IsNullOrWhiteSpace($script:LastOutputFolder)) {
        if ($selectedFiles.Count -gt 0) {
            Update-OutputFolder
        }
    }

    if (!$script:LastOutputFolder -or [string]::IsNullOrWhiteSpace($script:LastOutputFolder)) {
        [System.Windows.MessageBox]::Show("Upload images first so the output folder can be created.", "No output folder")
        return
    }

    New-Item -ItemType Directory -Force -Path $script:LastOutputFolder | Out-Null

    try {
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$script:LastOutputFolder`""
    }
    catch {
        [System.Windows.MessageBox]::Show("Could not open output folder: $script:LastOutputFolder", "Error")
    }
}

function Get-OutputPath($file, $saveAsJpg) {
    $outputFolder = Join-Path $file.DirectoryName "Compressed"
    New-Item -ItemType Directory -Force -Path $outputFolder | Out-Null

    $script:LastOutputFolder = $outputFolder
    $FolderBox.Text = $outputFolder

    $pattern = $FormatBox.Text
    if ([string]::IsNullOrWhiteSpace($pattern)) {
        $pattern = "{input}-compressed"
    }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $newName = $pattern.Replace("{input}", $baseName)

    if ($saveAsJpg) {
        $ext = ".jpg"
    } else {
        $ext = ".png"
    }

    $output = Join-Path $outputFolder "$newName$ext"
    $i = 1

    while (Test-Path $output) {
        $output = Join-Path $outputFolder "$newName-$i$ext"
        $i++
    }

    return $output
}

function Compress-OneImage($filePath) {
    $file = Get-Item $filePath

    $image = $null
    $bitmap = $null
    $graphics = $null

    try {
        $image = [System.Drawing.Image]::FromFile($file.FullName)

        $newWidth = [Math]::Max(1, [int]($image.Width * $script:Scale))
        $newHeight = [Math]::Max(1, [int]($image.Height * $script:Scale))

        $ext = $file.Extension.ToLower()
        $convertPng = [bool]$ConvertPngCheck.IsChecked

        $saveAsJpg = $false

        if ($ext -eq ".jpg" -or $ext -eq ".jpeg") {
            $saveAsJpg = $true
        }

        if ($ext -eq ".png" -and $convertPng) {
            $saveAsJpg = $true
        }

        $outputPath = Get-OutputPath $file $saveAsJpg

        if ($saveAsJpg) {
            $bitmap = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($image, 0, 0, $newWidth, $newHeight)

            $jpgEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
                Where-Object { $_.MimeType -eq "image/jpeg" }

            $encoder = [System.Drawing.Imaging.Encoder]::Quality
            $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($encoder, [long]$script:Quality)

            $bitmap.Save($outputPath, $jpgEncoder, $encoderParams)
        }
        else {
            $bitmap = New-Object System.Drawing.Bitmap($newWidth, $newHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($image, 0, 0, $newWidth, $newHeight)

            $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }

        $oldSize = $file.Length
        $newSize = (Get-Item $outputPath).Length
        $saved = $oldSize - $newSize

        return [PSCustomObject]@{
            Success = $true
            OldSize = $oldSize
            NewSize = $newSize
            Saved = $saved
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            OldSize = 0
            NewSize = 0
            Saved = 0
        }
    }
    finally {
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($image) { $image.Dispose() }
    }
}

$CloseButton.Add_Click({
    $window.Close()
})

$MinButton.Add_Click({
    $window.WindowState = "Minimized"
})

$TopBar.Add_MouseLeftButtonDown({
    try {
        $window.DragMove()
    } catch {}
})

$UploadButton.Add_Click({
    Open-Images
})

$window.Add_DragOver({
    if ($_.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        $_.Effects = [Windows.DragDropEffects]::Copy
    } else {
        $_.Effects = [Windows.DragDropEffects]::None
    }

    $_.Handled = $true
})

$window.Add_Drop({
    $files = $_.Data.GetData([Windows.DataFormats]::FileDrop)
    Add-Images $files
})

$QOriginal.Add_Click({ Set-Quality 95 $QOriginal })
$QBalanced.Add_Click({ Set-Quality 70 $QBalanced })
$QHigh.Add_Click({ Set-Quality 85 $QHigh })
$QMedium.Add_Click({ Set-Quality 55 $QMedium })
$QLow.Add_Click({ Set-Quality 35 $QLow })

$R1.Add_Click({ Set-Resolution 1.0 $R1 })
$R075.Add_Click({ Set-Resolution 0.75 $R075 })
$R05.Add_Click({ Set-Resolution 0.5 $R05 })
$R033.Add_Click({ Set-Resolution 0.33 $R033 })

$OpenFolderButton.Add_Click({
    Open-OutputFolder
})

$CompressButton.Add_Click({
    if ($selectedFiles.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please add images first.", "No images")
        return
    }

    $CompressButton.IsEnabled = $false
    $ProgressBar.Value = 0
    $ResultText.Text = "Compressing..."
    $SavedText.Text = ""

    $totalOld = 0
    $totalNew = 0
    $totalSaved = 0
    $success = 0
    $index = 0

    foreach ($file in $selectedFiles) {
        $index++

        $ResultText.Text = "Compressing $index of $($selectedFiles.Count)..."
        $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)

        $result = Compress-OneImage $file

        if ($result.Success) {
            $success++
            $totalOld += $result.OldSize
            $totalNew += $result.NewSize
            $totalSaved += $result.Saved
        }

        $ProgressBar.Value = ($index / $selectedFiles.Count) * 100
    }

    if ($totalOld -gt 0) {
        $percent = [math]::Round(($totalSaved / $totalOld) * 100, 1)
    } else {
        $percent = 0
    }

    $ResultText.Text = "Compressed $success file(s). Original: $(Format-Size $totalOld) to New: $(Format-Size $totalNew)"
    $SavedText.Text = "Saved $(Format-Size $totalSaved) ($percent%)"

    $CompressButton.IsEnabled = $true

    if ([bool]$OpenAfterCheck.IsChecked) {
        Open-OutputFolder
    }
})

[void]$window.ShowDialog()
