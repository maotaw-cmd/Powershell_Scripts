#requires -version 5.1
<#
    EXE / DLL Icon Extractor - PowerShell WPF
    Single-file Windows script

    Features:
    - Compact 300x300 borderless transparent UI
    - Choose EXE or DLL
    - Same folder or Downloads output
    - Extracts RT_GROUP_ICON resources
    - Detects Discord/Electron app-* folders
    - Falls back to ExtractIconEx / SHGetFileInfo
    - Saves real .ico files
    - Opens the output folder automatically
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing

$interop = @"
using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;
using Microsoft.Win32.SafeHandles;

public static class IconExtractorNative
{
    private const uint LOAD_LIBRARY_AS_DATAFILE = 0x00000002;
    private const uint LOAD_LIBRARY_AS_IMAGE_RESOURCE = 0x00000020;
    private const uint SHGFI_ICON = 0x000000100;
    private const uint SHGFI_LARGEICON = 0x000000000;

    private static readonly IntPtr RT_ICON = (IntPtr)3;
    private static readonly IntPtr RT_GROUP_ICON = (IntPtr)14;

    [StructLayout(LayoutKind.Sequential)]
    private struct GRPICONDIR
    {
        public ushort idReserved;
        public ushort idType;
        public ushort idCount;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 2)]
    private struct GRPICONDIRENTRY
    {
        public byte bWidth;
        public byte bHeight;
        public byte bColorCount;
        public byte bReserved;
        public ushort wPlanes;
        public ushort wBitCount;
        public uint dwBytesInRes;
        public ushort nID;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 2)]
    private struct ICONDIR
    {
        public ushort idReserved;
        public ushort idType;
        public ushort idCount;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 2)]
    private struct ICONDIRENTRY
    {
        public byte bWidth;
        public byte bHeight;
        public byte bColorCount;
        public byte bReserved;
        public ushort wPlanes;
        public ushort wBitCount;
        public uint dwBytesInRes;
        public uint dwImageOffset;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct SHFILEINFO
    {
        public IntPtr hIcon;
        public int iIcon;
        public uint dwAttributes;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string szDisplayName;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)]
        public string szTypeName;
    }

    private delegate bool EnumResNameProc(
        IntPtr hModule,
        IntPtr lpszType,
        IntPtr lpszName,
        IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr LoadLibraryEx(
        string lpFileName,
        IntPtr hFile,
        uint dwFlags);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool FreeLibrary(IntPtr hModule);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool EnumResourceNames(
        IntPtr hModule,
        IntPtr lpszType,
        EnumResNameProc lpEnumFunc,
        IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr FindResource(
        IntPtr hModule,
        IntPtr lpName,
        IntPtr lpType);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr LoadResource(
        IntPtr hModule,
        IntPtr hResInfo);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr LockResource(
        IntPtr hResData);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint SizeofResource(
        IntPtr hModule,
        IntPtr hResInfo);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern uint ExtractIconEx(
        string szFileName,
        int nIconIndex,
        IntPtr[] phiconLarge,
        IntPtr[] phiconSmall,
        uint nIcons);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr SHGetFileInfo(
        string pszPath,
        uint dwFileAttributes,
        out SHFILEINFO psfi,
        uint cbFileInfo,
        uint uFlags);

    [DllImport("user32.dll")]
    private static extern bool DestroyIcon(IntPtr hIcon);

    private static bool IsIntResource(IntPtr value)
    {
        long raw = value.ToInt64();
        return (raw >> 16) == 0;
    }

    private static IntPtr MakeIntResource(ushort id)
    {
        return (IntPtr)id;
    }

    private sealed class ResourceName
    {
        public bool IsInteger;
        public ushort Id;
        public string Name;
    }

    private sealed class IconImage
    {
        public ICONDIRENTRY Entry;
        public byte[] Bytes;
    }

    public static string[] BuildCandidates(string source)
    {
        var result = new List<string>();

        Action<string> add = path =>
        {
            if (String.IsNullOrWhiteSpace(path))
                return;

            try
            {
                if (!File.Exists(path))
                    return;

                if (!result.Contains(path, StringComparer.OrdinalIgnoreCase))
                    result.Add(path);
            }
            catch { }
        };

        add(source);

        string parent = Path.GetDirectoryName(source);
        string selectedName = Path.GetFileName(source);

        if (!String.IsNullOrWhiteSpace(parent) && Directory.Exists(parent))
        {
            try
            {
                var appFolders = Directory.GetDirectories(parent, "app-*")
                    .OrderByDescending(x => x, StringComparer.OrdinalIgnoreCase);

                foreach (string folder in appFolders)
                {
                    add(Path.Combine(folder, selectedName));
                    add(Path.Combine(folder, "Discord.exe"));
                    add(Path.Combine(folder, "DiscordCanary.exe"));
                    add(Path.Combine(folder, "DiscordPTB.exe"));
                    add(Path.Combine(folder, "Slack.exe"));
                    add(Path.Combine(folder, "Spotify.exe"));
                }
            }
            catch { }
        }

        return result.ToArray();
    }

    public static int ExtractAll(string source, string outputDirectory)
    {
        Directory.CreateDirectory(outputDirectory);

        foreach (string candidate in BuildCandidates(source))
        {
            int embedded = ExtractEmbedded(candidate, outputDirectory);

            if (embedded > 0)
                return embedded;
        }

        return ExtractShellFallback(source, outputDirectory) ? 1 : 0;
    }

    private static int ExtractEmbedded(string source, string outputDirectory)
    {
        IntPtr module = LoadLibraryEx(
            source,
            IntPtr.Zero,
            LOAD_LIBRARY_AS_DATAFILE | LOAD_LIBRARY_AS_IMAGE_RESOURCE);

        if (module == IntPtr.Zero)
            return 0;

        try
        {
            var names = new List<ResourceName>();

            EnumResNameProc callback = (hModule, type, name, param) =>
            {
                if (IsIntResource(name))
                {
                    names.Add(new ResourceName
                    {
                        IsInteger = true,
                        Id = unchecked((ushort)name.ToInt64())
                    });
                }
                else
                {
                    names.Add(new ResourceName
                    {
                        IsInteger = false,
                        Name = Marshal.PtrToStringUni(name)
                    });
                }

                return true;
            };

            EnumResourceNames(
                module,
                RT_GROUP_ICON,
                callback,
                IntPtr.Zero);

            int extracted = 0;
            int index = 0;

            foreach (ResourceName resourceName in names)
            {
                index++;

                try
                {
                    var images = BuildIconImages(
                        module,
                        resourceName);

                    if (images == null || images.Count == 0)
                        continue;

                    string prefix = Sanitize(Path.GetFileNameWithoutExtension(source));
                    string resourcePart = resourceName.IsInteger
                        ? "icon_" + resourceName.Id
                        : "icon_" + Sanitize(resourceName.Name);

                    string baseName = prefix + "_" + resourcePart;
                    string outputPath = UniquePath(
                        outputDirectory,
                        baseName,
                        ".ico");

                    WriteIco(outputPath, images);
                    extracted++;
                }
                catch { }
            }

            return extracted;
        }
        finally
        {
            FreeLibrary(module);
        }
    }

    private static List<IconImage> BuildIconImages(
        IntPtr module,
        ResourceName groupName)
    {
        IntPtr namePtr = groupName.IsInteger
            ? MakeIntResource(groupName.Id)
            : Marshal.StringToHGlobalUni(groupName.Name);

        try
        {
            IntPtr groupResource = FindResource(
                module,
                namePtr,
                RT_GROUP_ICON);

            if (groupResource == IntPtr.Zero)
                return null;

            byte[] groupBytes = ReadResourceBytes(
                module,
                groupResource);

            if (groupBytes == null || groupBytes.Length < 6)
                return null;

            ushort reserved = BitConverter.ToUInt16(groupBytes, 0);
            ushort type = BitConverter.ToUInt16(groupBytes, 2);
            ushort count = BitConverter.ToUInt16(groupBytes, 4);

            if (reserved != 0 || type != 1 || count == 0)
                return null;

            int entrySize = 14;
            int required = 6 + count * entrySize;

            if (groupBytes.Length < required)
                return null;

            var images = new List<IconImage>();
            int offset = 6;

            for (int i = 0; i < count; i++)
            {
                byte width = groupBytes[offset + 0];
                byte height = groupBytes[offset + 1];
                byte colorCount = groupBytes[offset + 2];
                byte entryReserved = groupBytes[offset + 3];
                ushort planes = BitConverter.ToUInt16(groupBytes, offset + 4);
                ushort bitCount = BitConverter.ToUInt16(groupBytes, offset + 6);
                uint bytesInResource = BitConverter.ToUInt32(groupBytes, offset + 8);
                ushort resourceId = BitConverter.ToUInt16(groupBytes, offset + 12);

                IntPtr iconResource = FindResource(
                    module,
                    MakeIntResource(resourceId),
                    RT_ICON);

                if (iconResource == IntPtr.Zero)
                    return null;

                byte[] imageBytes = ReadResourceBytes(
                    module,
                    iconResource);

                if (imageBytes == null || imageBytes.Length == 0)
                    return null;

                images.Add(new IconImage
                {
                    Entry = new ICONDIRENTRY
                    {
                        bWidth = width,
                        bHeight = height,
                        bColorCount = colorCount,
                        bReserved = entryReserved,
                        wPlanes = planes,
                        wBitCount = bitCount,
                        dwBytesInRes = (uint)imageBytes.Length,
                        dwImageOffset = 0
                    },
                    Bytes = imageBytes
                });

                offset += entrySize;
            }

            return images;
        }
        finally
        {
            if (!groupName.IsInteger && namePtr != IntPtr.Zero)
                Marshal.FreeHGlobal(namePtr);
        }
    }

    private static byte[] ReadResourceBytes(
        IntPtr module,
        IntPtr resource)
    {
        uint size = SizeofResource(module, resource);

        if (size == 0)
            return null;

        IntPtr loaded = LoadResource(module, resource);

        if (loaded == IntPtr.Zero)
            return null;

        IntPtr pointer = LockResource(loaded);

        if (pointer == IntPtr.Zero)
            return null;

        byte[] bytes = new byte[size];
        Marshal.Copy(pointer, bytes, 0, (int)size);
        return bytes;
    }

    private static void WriteIco(
        string outputPath,
        List<IconImage> images)
    {
        using (var stream = new FileStream(
            outputPath,
            FileMode.Create,
            FileAccess.Write))
        using (var writer = new BinaryWriter(stream))
        {
            writer.Write((ushort)0);
            writer.Write((ushort)1);
            writer.Write((ushort)images.Count);

            uint offset = (uint)(6 + images.Count * 16);

            foreach (IconImage image in images)
            {
                var entry = image.Entry;
                entry.dwImageOffset = offset;

                writer.Write(entry.bWidth);
                writer.Write(entry.bHeight);
                writer.Write(entry.bColorCount);
                writer.Write(entry.bReserved);
                writer.Write(entry.wPlanes);
                writer.Write(entry.wBitCount);
                writer.Write(entry.dwBytesInRes);
                writer.Write(entry.dwImageOffset);

                offset += entry.dwBytesInRes;
            }

            foreach (IconImage image in images)
                writer.Write(image.Bytes);
        }
    }

    private static bool ExtractShellFallback(
        string source,
        string outputDirectory)
    {
        foreach (string candidate in BuildCandidates(source))
        {
            IntPtr iconHandle = IntPtr.Zero;

            try
            {
                IntPtr[] large = new IntPtr[1];
                IntPtr[] small = new IntPtr[1];

                uint count = ExtractIconEx(
                    candidate,
                    0,
                    large,
                    small,
                    1);

                if (small[0] != IntPtr.Zero)
                    DestroyIcon(small[0]);

                if (count > 0 && large[0] != IntPtr.Zero)
                {
                    iconHandle = large[0];
                }
                else
                {
                    SHFILEINFO info;

                    IntPtr result = SHGetFileInfo(
                        candidate,
                        0,
                        out info,
                        (uint)Marshal.SizeOf(typeof(SHFILEINFO)),
                        SHGFI_ICON | SHGFI_LARGEICON);

                    if (result != IntPtr.Zero)
                        iconHandle = info.hIcon;
                }

                if (iconHandle == IntPtr.Zero)
                    continue;

                using (Icon icon = Icon.FromHandle(iconHandle))
                using (Icon clone = (Icon)icon.Clone())
                {
                    string outputPath = UniquePath(
                        outputDirectory,
                        "application_icon",
                        ".ico");

                    using (var stream = new FileStream(
                        outputPath,
                        FileMode.Create,
                        FileAccess.Write))
                    {
                        clone.Save(stream);
                    }
                }

                return true;
            }
            catch { }
            finally
            {
                if (iconHandle != IntPtr.Zero)
                    DestroyIcon(iconHandle);
            }
        }

        return false;
    }

    private static string UniquePath(
        string directory,
        string baseName,
        string extension)
    {
        string cleanBase = Sanitize(baseName);
        string path = Path.Combine(
            directory,
            cleanBase + extension);

        int duplicate = 2;

        while (File.Exists(path))
        {
            path = Path.Combine(
                directory,
                cleanBase + "_" + duplicate + extension);

            duplicate++;
        }

        return path;
    }

    private static string Sanitize(string value)
    {
        if (String.IsNullOrWhiteSpace(value))
            return "icon";

        foreach (char invalid in Path.GetInvalidFileNameChars())
            value = value.Replace(invalid, '_');

        return value.Trim().TrimEnd('.');
    }
}
"@

Add-Type -TypeDefinition $interop -ReferencedAssemblies System.Drawing

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Width="300"
    Height="300"
    WindowStyle="None"
    ResizeMode="NoResize"
    AllowsTransparency="True"
    Background="Transparent"
    WindowStartupLocation="CenterScreen"
    ShowInTaskbar="True"
    Title="Icon Extractor">

    <Border
        CornerRadius="10"
        Background="#DD08080B">

        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="28"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <Grid
                x:Name="TitleBar"
                Grid.Row="0"
                Background="#09090B">

                <TextBlock
                    Text="Icon Extractor"
                    Margin="12,0,70,0"
                    VerticalAlignment="Center"
                    Foreground="#EAEAEA"
                    FontFamily="Segoe UI"
                    FontSize="11"/>

                <StackPanel
                    HorizontalAlignment="Right"
                    Orientation="Horizontal">

                    <Button
                        x:Name="MinimizeButton"
                        Width="28"
                        Height="28"
                        Background="Transparent"
                        BorderThickness="0"
                        Cursor="Hand">

                        <Grid Width="28" Height="28">
                            <Line
                                x:Name="MinimizeLine"
                                X1="9"
                                Y1="14"
                                X2="19"
                                Y2="14"
                                Stroke="#8A8A91"
                                StrokeThickness="1.2"
                                SnapsToDevicePixels="True"/>
                        </Grid>
                    </Button>

                    <Button
                        x:Name="CloseButton"
                        Width="28"
                        Height="28"
                        Background="Transparent"
                        BorderThickness="0"
                        Cursor="Hand">

                        <Grid Width="28" Height="28">
                            <Line
                                x:Name="CloseLineOne"
                                X1="9"
                                Y1="9"
                                X2="19"
                                Y2="19"
                                Stroke="#8A8A91"
                                StrokeThickness="1.2"
                                SnapsToDevicePixels="True"/>

                            <Line
                                x:Name="CloseLineTwo"
                                X1="19"
                                Y1="9"
                                X2="9"
                                Y2="19"
                                Stroke="#8A8A91"
                                StrokeThickness="1.2"
                                SnapsToDevicePixels="True"/>
                        </Grid>
                    </Button>
                </StackPanel>
            </Grid>

            <Grid Grid.Row="1">
                <TextBlock
                    x:Name="HeadingText"
                    Text="Ready to extract icons"
                    Margin="28,39,28,0"
                    Height="30"
                    VerticalAlignment="Top"
                    TextAlignment="Center"
                    Foreground="#ECECEC"
                    FontFamily="Segoe UI"
                    FontWeight="SemiBold"
                    FontSize="14"/>

                <TextBlock
                    x:Name="DescriptionText"
                    Text="Choose an EXE or DLL to begin."
                    Margin="24,69,24,0"
                    Height="25"
                    VerticalAlignment="Top"
                    TextAlignment="Center"
                    TextTrimming="CharacterEllipsis"
                    Foreground="#8C8C94"
                    FontFamily="Segoe UI"
                    FontSize="10.5"/>

                <Button
                    x:Name="BrowseButton"
                    Content="Choose EXE or DLL"
                    Margin="44,108,44,0"
                    Height="34"
                    VerticalAlignment="Top"
                    Foreground="#D7D7DA"
                    Background="#111116"
                    BorderBrush="#2A2A30"
                    BorderThickness="1"
                    FontFamily="Segoe UI"
                    FontSize="10.5"
                    Cursor="Hand"/>

                <Grid
                    Margin="45,154,45,0"
                    Height="28"
                    VerticalAlignment="Top">

                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="94"/>
                        <ColumnDefinition Width="18"/>
                        <ColumnDefinition Width="94"/>
                    </Grid.ColumnDefinitions>

                    <Button
                        x:Name="SameFolderButton"
                        Grid.Column="0"
                        Content="Same folder"
                        Foreground="White"
                        Background="#321116"
                        BorderBrush="#E52F3B"
                        BorderThickness="1"
                        FontFamily="Segoe UI"
                        FontSize="10"
                        Cursor="Hand"/>

                    <Button
                        x:Name="DownloadsButton"
                        Grid.Column="2"
                        Content="Downloads"
                        Foreground="#8F8F97"
                        Background="#0F0F13"
                        BorderBrush="#29292F"
                        BorderThickness="1"
                        FontFamily="Segoe UI"
                        FontSize="10"
                        Cursor="Hand"/>
                </Grid>

                <Grid
                    Margin="58,198,58,0"
                    Height="4"
                    VerticalAlignment="Top">

                    <Border
                        Background="#151519"
                        CornerRadius="2"/>

                    <Border
                        x:Name="ProgressFill"
                        Width="0"
                        HorizontalAlignment="Left"
                        Background="#E52F3B"
                        CornerRadius="2"/>
                </Grid>

                <Button
                    x:Name="ExtractButton"
                    Content="Extract Icons"
                    Margin="72,212,72,0"
                    Height="30"
                    VerticalAlignment="Top"
                    Foreground="#62626A"
                    Background="#121216"
                    BorderBrush="#29292F"
                    BorderThickness="1"
                    FontFamily="Segoe UI"
                    FontSize="10.5"
                    Cursor="Hand"
                    IsEnabled="False"/>

                <TextBlock
                    x:Name="StatusText"
                    Text=""
                    Margin="18,247,18,0"
                    Height="24"
                    VerticalAlignment="Top"
                    TextAlignment="Center"
                    TextTrimming="CharacterEllipsis"
                    Foreground="#67D391"
                    FontFamily="Segoe UI"
                    FontSize="9.5"/>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml

try {
    $window = [Windows.Markup.XamlReader]::Load($reader)
}
catch {
    [System.Windows.MessageBox]::Show(
        "The interface could not be loaded.`n`n$($_.Exception.Message)",
        "Icon Extractor",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null

    return
}

$titleBar = $window.FindName("TitleBar")
$minimizeButton = $window.FindName("MinimizeButton")
$closeButton = $window.FindName("CloseButton")
$minimizeLine = $window.FindName("MinimizeLine")
$closeLineOne = $window.FindName("CloseLineOne")
$closeLineTwo = $window.FindName("CloseLineTwo")
$browseButton = $window.FindName("BrowseButton")
$sameFolderButton = $window.FindName("SameFolderButton")
$downloadsButton = $window.FindName("DownloadsButton")
$extractButton = $window.FindName("ExtractButton")
$progressFill = $window.FindName("ProgressFill")
$headingText = $window.FindName("HeadingText")
$descriptionText = $window.FindName("DescriptionText")
$statusText = $window.FindName("StatusText")

$script:selectedFile = $null
$script:saveToDownloads = $false

$brushConverter = New-Object Windows.Media.BrushConverter

function Get-Brush {
    param([Parameter(Mandatory = $true)][string]$Color)

    return $brushConverter.ConvertFromString($Color)
}

function Set-OutputChoice {
    param([bool]$Downloads)

    $script:saveToDownloads = $Downloads

    if ($Downloads) {
        $sameFolderButton.Background = Get-Brush "#0F0F13"
        $sameFolderButton.BorderBrush = Get-Brush "#29292F"
        $sameFolderButton.Foreground = Get-Brush "#8F8F97"

        $downloadsButton.Background = Get-Brush "#321116"
        $downloadsButton.BorderBrush = Get-Brush "#E52F3B"
        $downloadsButton.Foreground = Get-Brush "White"
    }
    else {
        $sameFolderButton.Background = Get-Brush "#321116"
        $sameFolderButton.BorderBrush = Get-Brush "#E52F3B"
        $sameFolderButton.Foreground = Get-Brush "White"

        $downloadsButton.Background = Get-Brush "#0F0F13"
        $downloadsButton.BorderBrush = Get-Brush "#29292F"
        $downloadsButton.Foreground = Get-Brush "#8F8F97"
    }
}

function Get-OutputFolder {
    $baseName = [IO.Path]::GetFileNameWithoutExtension($script:selectedFile) + "_Icons"

    if ($script:saveToDownloads) {
        $downloads = [Environment]::GetFolderPath("UserProfile")
        return Join-Path (Join-Path $downloads "Downloads") $baseName
    }

    $parent = [IO.Path]::GetDirectoryName($script:selectedFile)
    return Join-Path $parent $baseName
}

$titleBar.Add_MouseLeftButtonDown({
    param($sender, $eventArgs)

    if ($eventArgs.ChangedButton -eq [Windows.Input.MouseButton]::Left) {
        $window.DragMove()
    }
})

$minimizeButton.Add_Click({
    $window.WindowState = "Minimized"
})

$closeButton.Add_Click({
    $window.Close()
})

$minimizeButton.Add_MouseEnter({
    $minimizeButton.Background = Get-Brush "#151519"
    $minimizeLine.Stroke = Get-Brush "#FFFFFF"
})

$minimizeButton.Add_MouseLeave({
    $minimizeButton.Background = Get-Brush "Transparent"
    $minimizeLine.Stroke = Get-Brush "#8A8A91"
})

$closeButton.Add_MouseEnter({
    $closeButton.Background = Get-Brush "#5A151C"
    $closeLineOne.Stroke = Get-Brush "#FFFFFF"
    $closeLineTwo.Stroke = Get-Brush "#FFFFFF"
})

$closeButton.Add_MouseLeave({
    $closeButton.Background = Get-Brush "Transparent"
    $closeLineOne.Stroke = Get-Brush "#8A8A91"
    $closeLineTwo.Stroke = Get-Brush "#8A8A91"
})

$browseButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = "Executable Files (*.exe;*.dll)|*.exe;*.dll|EXE Files (*.exe)|*.exe|DLL Files (*.dll)|*.dll|All Files (*.*)|*.*"
    $dialog.Multiselect = $false
    $dialog.CheckFileExists = $true

    if ($dialog.ShowDialog() -eq $true) {
        $script:selectedFile = $dialog.FileName
        $descriptionText.Text = [IO.Path]::GetFileName($dialog.FileName)
        $headingText.Text = "Ready for extraction"
        $browseButton.Content = "Choose another file"
        $extractButton.IsEnabled = $true
        $extractButton.Foreground = Get-Brush "White"
        $extractButton.Background = Get-Brush "#461319"
        $extractButton.BorderBrush = Get-Brush "#E52F3B"
        $progressFill.Width = 184
        $statusText.Text = ""
    }
})

$sameFolderButton.Add_Click({
    Set-OutputChoice -Downloads $false
})

$downloadsButton.Add_Click({
    Set-OutputChoice -Downloads $true
})

$extractButton.Add_Click({
    if (-not $script:selectedFile) {
        return
    }

    $extractButton.IsEnabled = $false
    $extractButton.Content = "Extracting..."
    $headingText.Text = "Extracting icons..."
    $progressFill.Width = 132
    $statusText.Foreground = Get-Brush "#67D391"
    $statusText.Text = "Please wait..."
    $window.Dispatcher.Invoke([action]{}, "Render")

    try {
        $outputFolder = Get-OutputFolder

        try {
            $count = [IconExtractorNative]::ExtractAll(
                $script:selectedFile,
                $outputFolder
            )
        }
        catch [System.UnauthorizedAccessException] {
            # Protected locations such as Program Files cannot normally be
            # written to by a non-elevated PowerShell process. Fall back to
            # Downloads automatically instead of terminating the app.
            $downloadsRoot = Join-Path `
                ([Environment]::GetFolderPath("UserProfile")) `
                "Downloads"

            $fallbackName = `
                [IO.Path]::GetFileNameWithoutExtension($script:selectedFile) +
                "_Icons"

            $outputFolder = Join-Path $downloadsRoot $fallbackName

            $count = [IconExtractorNative]::ExtractAll(
                $script:selectedFile,
                $outputFolder
            )

            $script:saveToDownloads = $true
            Set-OutputChoice -Downloads $true
        }
        catch [System.Reflection.TargetInvocationException] {
            # Add-Type method calls commonly wrap the real C# exception.
            $realException = $_.Exception.InnerException

            if ($realException -is [System.UnauthorizedAccessException]) {
                $downloadsRoot = Join-Path `
                    ([Environment]::GetFolderPath("UserProfile")) `
                    "Downloads"

                $fallbackName = `
                    [IO.Path]::GetFileNameWithoutExtension($script:selectedFile) +
                    "_Icons"

                $outputFolder = Join-Path $downloadsRoot $fallbackName

                $count = [IconExtractorNative]::ExtractAll(
                    $script:selectedFile,
                    $outputFolder
                )

                $script:saveToDownloads = $true
                Set-OutputChoice -Downloads $true
            }
            else {
                throw $realException
            }
        }

        if ($count -gt 0) {
            $progressFill.Width = 184
            $headingText.Text = "Extraction complete"
            $statusText.Foreground = Get-Brush "#67D391"
            $statusText.Text = "Saved $count icon file(s) to Downloads or the selected folder."
            Start-Process explorer.exe -ArgumentList "`"$outputFolder`""
        }
        else {
            $progressFill.Width = 0
            $headingText.Text = "No icon found"
            $statusText.Foreground = Get-Brush "#EF6672"
            $statusText.Text = "No application icon could be extracted."
        }
    }
    catch {
        $progressFill.Width = 0
        $headingText.Text = "Extraction failed"
        $statusText.Foreground = Get-Brush "#EF6672"

        $message = $_.Exception.Message

        if ($_.Exception.InnerException) {
            $message = $_.Exception.InnerException.Message
        }

        if ($message -match "access|denied|unauthorized") {
            $statusText.Text = "Access denied. Select Downloads and try again."
        }
        else {
            $statusText.Text = $message
        }
    }
    finally {
        $extractButton.Content = "Extract Icons"
        $extractButton.IsEnabled = $true
    }
})

Set-OutputChoice -Downloads $false
[void]$window.ShowDialog()
