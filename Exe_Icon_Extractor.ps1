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
    Width="440"
    Height="430"
    WindowStyle="None"
    ResizeMode="NoResize"
    AllowsTransparency="False"
    Background="#07090A"
    WindowStartupLocation="CenterScreen"
    ShowInTaskbar="True"
    Title="Icon Extractor">

    <Border
        Background="#07090A"
        BorderBrush="#20252A"
        BorderThickness="1">

        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="44"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- Title bar -->
            <Grid
                x:Name="TitleBar"
                Grid.Row="0"
                Background="#0A0D0F">

                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="44"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="42"/>
                    <ColumnDefinition Width="42"/>
                </Grid.ColumnDefinitions>

                <Border
                    Grid.Column="0"
                    Width="22"
                    Height="22"
                    Margin="12,0,0,0"
                    HorizontalAlignment="Left"
                    VerticalAlignment="Center"
                    Background="#B7F000"
                    CornerRadius="4">

                    <Grid>
                        <Rectangle
                            Width="6"
                            Height="6"
                            Fill="#0A0D0F"
                            HorizontalAlignment="Left"
                            VerticalAlignment="Top"
                            Margin="4,4,0,0"/>

                        <Rectangle
                            Width="6"
                            Height="6"
                            Fill="#0A0D0F"
                            HorizontalAlignment="Right"
                            VerticalAlignment="Top"
                            Margin="0,4,4,0"/>

                        <Rectangle
                            Width="6"
                            Height="6"
                            Fill="#0A0D0F"
                            HorizontalAlignment="Left"
                            VerticalAlignment="Bottom"
                            Margin="4,0,0,4"/>

                        <Rectangle
                            Width="6"
                            Height="6"
                            Fill="#0A0D0F"
                            HorizontalAlignment="Right"
                            VerticalAlignment="Bottom"
                            Margin="0,0,4,4"/>
                    </Grid>
                </Border>

                <TextBlock
                    Grid.Column="1"
                    Text="Icon Extractor"
                    VerticalAlignment="Center"
                    Foreground="#F3F4F5"
                    FontFamily="Segoe UI"
                    FontSize="14"
                    FontWeight="SemiBold"/>

                <Button
                    x:Name="MinimizeButton"
                    Grid.Column="2"
                    Width="42"
                    Height="44"
                    Background="Transparent"
                    BorderThickness="0"
                    Cursor="Hand">

                    <Grid Width="42" Height="44">
                        <Line
                            x:Name="MinimizeLine"
                            X1="13"
                            Y1="22"
                            X2="29"
                            Y2="22"
                            Stroke="#B9BEC5"
                            StrokeThickness="1.2"
                            SnapsToDevicePixels="True"/>
                    </Grid>
                </Button>

                <Button
                    x:Name="CloseButton"
                    Grid.Column="3"
                    Width="42"
                    Height="44"
                    Background="Transparent"
                    BorderThickness="0"
                    Cursor="Hand">

                    <Grid Width="42" Height="44">
                        <Line
                            x:Name="CloseLineOne"
                            X1="13"
                            Y1="14"
                            X2="29"
                            Y2="30"
                            Stroke="#B9BEC5"
                            StrokeThickness="1.2"
                            SnapsToDevicePixels="True"/>

                        <Line
                            x:Name="CloseLineTwo"
                            X1="29"
                            Y1="14"
                            X2="13"
                            Y2="30"
                            Stroke="#B9BEC5"
                            StrokeThickness="1.2"
                            SnapsToDevicePixels="True"/>
                    </Grid>
                </Button>

                <Border
                    Grid.ColumnSpan="4"
                    Height="1"
                    VerticalAlignment="Bottom"
                    Background="#3E5200"/>
            </Grid>

            <!-- Main content -->
            <Grid Grid.Row="1" Margin="28,14,28,20">
                <Grid.RowDefinitions>
                    <RowDefinition Height="82"/>
                    <RowDefinition Height="50"/>
                    <RowDefinition Height="54"/>
                    <RowDefinition Height="62"/>
                    <RowDefinition Height="14"/>
                    <RowDefinition Height="54"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <!-- Main EXE icon -->
                <Grid Grid.Row="0" HorizontalAlignment="Center">
                    <Grid Width="44" Height="54">
                        <Path
                            Data="M 7,2 L 29,2 L 41,14 L 41,51 L 7,51 Z"
                            Stroke="#B7F000"
                            StrokeThickness="3"
                            StrokeLineJoin="Round"
                            Fill="Transparent"/>

                        <Path
                            Data="M 29,2 L 29,14 L 41,14"
                            Stroke="#B7F000"
                            StrokeThickness="3"
                            StrokeLineJoin="Round"
                            Fill="Transparent"/>

                        <TextBlock
                            Text=".EXE"
                            HorizontalAlignment="Center"
                            VerticalAlignment="Bottom"
                            Margin="0,0,0,6"
                            Foreground="#F5F6F7"
                            FontFamily="Segoe UI"
                            FontWeight="Bold"
                            FontSize="12"/>
                    </Grid>
                </Grid>

                <StackPanel Grid.Row="1">
                    <TextBlock
                        x:Name="HeadingText"
                        Text="Ready to extract icons"
                        HorizontalAlignment="Center"
                        Foreground="#F4F5F6"
                        FontFamily="Segoe UI"
                        FontSize="19"
                        FontWeight="SemiBold"/>

                    <TextBlock
                        x:Name="DescriptionText"
                        Text="Choose an EXE or DLL to begin."
                        Margin="0,8,0,0"
                        HorizontalAlignment="Center"
                        Foreground="#8F949C"
                        FontFamily="Segoe UI"
                        FontSize="11.5"/>
                </StackPanel>

                <Button
                    x:Name="BrowseButton"
                    Grid.Row="2"
                    Height="48"
                    Background="#111519"
                    BorderBrush="#8FB700"
                    BorderThickness="1"
                    Foreground="#B7F000"
                    Cursor="Hand">

                    <StackPanel
                        Orientation="Horizontal"
                        HorizontalAlignment="Center">

                        <Grid Width="24" Height="20" Margin="0,0,10,0" VerticalAlignment="Center">
                            <Path
                                Data="M 2,6 L 9,6 L 12,9 L 22,9 L 22,18 L 2,18 Z"
                                Stroke="#B7F000"
                                StrokeThickness="1.7"
                                StrokeLineJoin="Round"
                                Fill="Transparent"/>
                            <Path
                                Data="M 2,6 L 2,3 L 10,3 L 13,6"
                                Stroke="#B7F000"
                                StrokeThickness="1.7"
                                StrokeLineJoin="Round"
                                Fill="Transparent"/>
                        </Grid>

                        <TextBlock
                            x:Name="BrowseButtonText"
                            Text="Choose EXE or DLL"
                            VerticalAlignment="Center"
                            FontFamily="Segoe UI"
                            FontWeight="SemiBold"
                            FontSize="15"
                            Foreground="#B7F000"/>
                    </StackPanel>
                </Button>

                <Grid Grid.Row="3" Margin="0,8,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="16"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Button
                        x:Name="SameFolderButton"
                        Grid.Column="0"
                        Background="#182000"
                        BorderBrush="#B7F000"
                        BorderThickness="1"
                        Cursor="Hand">

                        <StackPanel
                            Orientation="Horizontal"
                            HorizontalAlignment="Center">

                            <Grid Width="24" Height="20" Margin="0,0,9,0" VerticalAlignment="Center">
                                <Path
                                    Data="M 2,6 L 9,6 L 12,9 L 22,9 L 22,18 L 2,18 Z"
                                    Stroke="#B7F000"
                                    StrokeThickness="1.7"
                                    StrokeLineJoin="Round"
                                    Fill="Transparent"/>
                                <Path
                                    Data="M 2,6 L 2,3 L 10,3 L 13,6"
                                    Stroke="#B7F000"
                                    StrokeThickness="1.7"
                                    StrokeLineJoin="Round"
                                    Fill="Transparent"/>
                            </Grid>

                            <TextBlock
                                Text="Same folder"
                                VerticalAlignment="Center"
                                Foreground="#B7F000"
                                FontFamily="Segoe UI"
                                FontSize="14"
                                FontWeight="SemiBold"/>
                        </StackPanel>
                    </Button>

                    <Button
                        x:Name="DownloadsButton"
                        Grid.Column="2"
                        Background="#111519"
                        BorderBrush="#3B4148"
                        BorderThickness="1"
                        Cursor="Hand">

                        <StackPanel
                            Orientation="Horizontal"
                            HorizontalAlignment="Center">

                            <Grid Width="24" Height="22" Margin="0,0,9,0" VerticalAlignment="Center">
                                <Path
                                    Data="M 12,2 L 12,14 M 7,9 L 12,14 L 17,9"
                                    Stroke="#C4C8CE"
                                    StrokeThickness="1.8"
                                    StrokeStartLineCap="Round"
                                    StrokeEndLineCap="Round"
                                    StrokeLineJoin="Round"
                                    Fill="Transparent"/>
                                <Path
                                    Data="M 3,15 L 3,20 L 21,20 L 21,15"
                                    Stroke="#C4C8CE"
                                    StrokeThickness="1.8"
                                    StrokeStartLineCap="Round"
                                    StrokeEndLineCap="Round"
                                    StrokeLineJoin="Round"
                                    Fill="Transparent"/>
                            </Grid>

                            <TextBlock
                                Text="Downloads"
                                VerticalAlignment="Center"
                                Foreground="#C4C8CE"
                                FontFamily="Segoe UI"
                                FontSize="14"/>
                        </StackPanel>
                    </Button>
                </Grid>

                <Grid Grid.Row="4" VerticalAlignment="Center">
                    <Border
                        Height="4"
                        Background="#14181B"/>

                    <Border
                        x:Name="ProgressFill"
                        Width="0"
                        Height="4"
                        HorizontalAlignment="Left"
                        Background="#B7F000"/>
                </Grid>

                <Button
                    x:Name="ExtractButton"
                    Grid.Row="5"
                    Height="48"
                    Background="#B7F000"
                    BorderBrush="#C9FF00"
                    BorderThickness="1"
                    Foreground="#0A0D0F"
                    Cursor="Hand"
                    IsEnabled="False">

                    <StackPanel
                        Orientation="Horizontal"
                        HorizontalAlignment="Center">

                        <Grid Width="25" Height="24" Margin="0,0,10,0" VerticalAlignment="Center">
                            <Path
                                Data="M 12.5,2 L 12.5,15 M 7.5,10 L 12.5,15 L 17.5,10"
                                Stroke="#0A0D0F"
                                StrokeThickness="2"
                                StrokeStartLineCap="Round"
                                StrokeEndLineCap="Round"
                                StrokeLineJoin="Round"
                                Fill="Transparent"/>
                            <Path
                                Data="M 3,15 L 3,22 L 22,22 L 22,15"
                                Stroke="#0A0D0F"
                                StrokeThickness="2"
                                StrokeStartLineCap="Round"
                                StrokeEndLineCap="Round"
                                StrokeLineJoin="Round"
                                Fill="Transparent"/>
                        </Grid>

                        <TextBlock
                            Text="Extract Icons"
                            VerticalAlignment="Center"
                            Foreground="#0A0D0F"
                            FontFamily="Segoe UI"
                            FontSize="15"
                            FontWeight="Bold"/>
                    </StackPanel>
                </Button>

                <TextBlock
                    x:Name="StatusText"
                    Grid.Row="6"
                    Margin="0,7,0,0"
                    Text=""
                    TextAlignment="Center"
                    TextTrimming="CharacterEllipsis"
                    Foreground="#B7F000"
                    FontFamily="Segoe UI"
                    FontSize="11"/>
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
$browseButtonText = $window.FindName("BrowseButtonText")
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
        $sameFolderButton.Background = Get-Brush "#111519"
        $sameFolderButton.BorderBrush = Get-Brush "#3B4148"

        $downloadsButton.Background = Get-Brush "#182000"
        $downloadsButton.BorderBrush = Get-Brush "#B7F000"
    }
    else {
        $sameFolderButton.Background = Get-Brush "#182000"
        $sameFolderButton.BorderBrush = Get-Brush "#B7F000"

        $downloadsButton.Background = Get-Brush "#111519"
        $downloadsButton.BorderBrush = Get-Brush "#3B4148"
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
    $minimizeButton.Background = Get-Brush "#2A2D34"
    $minimizeLine.Stroke = Get-Brush "#FFFFFF"
})

$minimizeButton.Add_MouseLeave({
    $minimizeButton.Background = Get-Brush "Transparent"
    $minimizeLine.Stroke = Get-Brush "#8A8A91"
})

$closeButton.Add_MouseEnter({
    $closeButton.Background = Get-Brush "#E81123"
    $closeLineOne.Stroke = Get-Brush "#FFFFFF"
    $closeLineTwo.Stroke = Get-Brush "#FFFFFF"
})

$closeButton.Add_MouseLeave({
    $closeButton.Background = Get-Brush "Transparent"
    $closeLineOne.Stroke = Get-Brush "#8A8A91"
    $closeLineTwo.Stroke = Get-Brush "#8A8A91"
})

$browseButton.Add_MouseEnter({
    $browseButton.Background = Get-Brush "#202A00"
    $browseButton.BorderBrush = Get-Brush "#C9FF00"
})

$browseButton.Add_MouseLeave({
    $browseButton.Background = Get-Brush "#111519"
    $browseButton.BorderBrush = Get-Brush "#8FB700"
})

$sameFolderButton.Add_MouseEnter({
    if (-not $script:saveToDownloads) {
        $sameFolderButton.Background = Get-Brush "#263500"
        $sameFolderButton.BorderBrush = Get-Brush "#C9FF00"
    }
    else {
        $sameFolderButton.Background = Get-Brush "#1A2025"
        $sameFolderButton.BorderBrush = Get-Brush "#5B646E"
    }
})

$sameFolderButton.Add_MouseLeave({
    Set-OutputChoice -Downloads $script:saveToDownloads
})

$downloadsButton.Add_MouseEnter({
    if ($script:saveToDownloads) {
        $downloadsButton.Background = Get-Brush "#263500"
        $downloadsButton.BorderBrush = Get-Brush "#C9FF00"
    }
    else {
        $downloadsButton.Background = Get-Brush "#1A2025"
        $downloadsButton.BorderBrush = Get-Brush "#5B646E"
    }
})

$downloadsButton.Add_MouseLeave({
    Set-OutputChoice -Downloads $script:saveToDownloads
})

$extractButton.Add_MouseEnter({
    if ($extractButton.IsEnabled) {
        $extractButton.Background = Get-Brush "#C9FF00"
        $extractButton.BorderBrush = Get-Brush "#E1FF66"
    }
})

$extractButton.Add_MouseLeave({
    if ($extractButton.IsEnabled) {
        $extractButton.Background = Get-Brush "#B7F000"
        $extractButton.BorderBrush = Get-Brush "#C9FF00"
    }
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
        $browseButtonText.Text = "Choose another file"
        $extractButton.IsEnabled = $true
        $extractButton.Foreground = Get-Brush "#0A0D0F"
        $extractButton.Background = Get-Brush "#B7F000"
        $extractButton.BorderBrush = Get-Brush "#C9FF00"
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
    $headingText.Text = "Extracting icons..."
    $headingText.Text = "Extracting icons..."
    $progressFill.Width = 132
    $statusText.Foreground = Get-Brush "#B7F000"
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
            $statusText.Foreground = Get-Brush "#B7F000"
            $statusText.Text = "Saved $count icon file(s) to Downloads or the selected folder."
            Start-Process explorer.exe -ArgumentList "`"$outputFolder`""
        }
        else {
            $progressFill.Width = 0
            $headingText.Text = "No icon found"
            $statusText.Foreground = Get-Brush "#FF6670"
            $statusText.Text = "No application icon could be extracted."
        }
    }
    catch {
        $progressFill.Width = 0
        $headingText.Text = "Extraction failed"
        $statusText.Foreground = Get-Brush "#FF6670"

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
        $headingText.Text = "Ready for extraction"
        $extractButton.IsEnabled = $true
        $extractButton.Background = Get-Brush "#B7F000"
        $extractButton.BorderBrush = Get-Brush "#C9FF00"
        $extractButton.Foreground = Get-Brush "#0A0D0F"
    }
})

Set-OutputChoice -Downloads $false
[void]$window.ShowDialog()
