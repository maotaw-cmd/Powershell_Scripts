Write-Host "Offline QR Code Generator" -ForegroundColor Cyan
Write-Host "-------------------------" -ForegroundColor Cyan
Write-Host ""

# -----------------------------
# Setup local QR library
# -----------------------------

$baseFolder = Get-Location
$libFolder = Join-Path $baseFolder "QR-Library"
$outputFolder = Join-Path $baseFolder "QR-Codes"

New-Item -ItemType Directory -Force -Path $libFolder | Out-Null
New-Item -ItemType Directory -Force -Path $outputFolder | Out-Null

$dllPath = Get-ChildItem -Path $libFolder -Recurse -Filter "QRCoder.dll" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "net40|netstandard2.0|net6.0" } |
    Select-Object -First 1

if (!$dllPath) {
    Write-Host "Downloading QR library one time..." -ForegroundColor Yellow

    $zipPath = Join-Path $libFolder "QRCoder.zip"
    $packageUrl = "https://www.nuget.org/api/v2/package/QRCoder/1.4.3"

    Invoke-WebRequest -Uri $packageUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $libFolder -Force

    $dllPath = Get-ChildItem -Path $libFolder -Recurse -Filter "QRCoder.dll" |
        Where-Object { $_.FullName -match "net40|netstandard2.0|net6.0" } |
        Select-Object -First 1

    if (!$dllPath) {
        Write-Host "Could not find QRCoder.dll" -ForegroundColor Red
        exit
    }
}

Add-Type -Path $dllPath.FullName

# -----------------------------
# Helper functions
# -----------------------------

function Read-Required($message) {
    do {
        $value = Read-Host $message
        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host "This field cannot be empty." -ForegroundColor Red
        }
    } while ([string]::IsNullOrWhiteSpace($value))

    return $value.Trim()
}

function Url-Encode($text) {
    return [System.Uri]::EscapeDataString($text)
}

function Escape-Wifi($text) {
    return $text.Replace("\", "\\").Replace(";", "\;").Replace(",", "\,").Replace(":", "\:")
}

function Save-QRCode($payload, $typeName) {
    $fileName = "qr-$typeName-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".png"
    $outputPath = Join-Path $outputFolder $fileName

    $generator = [QRCoder.QRCodeGenerator]::new()
    $qrData = $generator.CreateQrCode($payload, [QRCoder.QRCodeGenerator+ECCLevel]::Q)

    $qrCode = [QRCoder.PngByteQRCode]::new($qrData)
    $qrBytes = $qrCode.GetGraphic(20)

    [System.IO.File]::WriteAllBytes($outputPath, $qrBytes)

    Write-Host ""
    Write-Host "QR code created!" -ForegroundColor Green
    Write-Host "Type:   $typeName"
    Write-Host "Saved:  $outputPath"
    Write-Host ""
    Write-Host "QR payload:" -ForegroundColor Yellow
    Write-Host $payload
    Write-Host ""
}

# -----------------------------
# Menu
# -----------------------------

Write-Host "Choose QR code type:" -ForegroundColor Yellow
Write-Host "1. Website URL"
Write-Host "2. Plain Text"
Write-Host "3. Phone Call"
Write-Host "4. SMS Message"
Write-Host "5. Email"
Write-Host "6. WiFi Network"
Write-Host "7. vCard Contact"
Write-Host "8. WhatsApp Message"
Write-Host "9. Location"
Write-Host "10. Calendar Event"
Write-Host "11. Custom Payload"
Write-Host ""

$choice = Read-Host "Enter number"

$payload = ""
$typeName = ""

switch ($choice) {

    "1" {
        $url = Read-Required "Enter website URL"

        if ($url -notmatch "^https?://") {
            $url = "https://$url"
        }

        $payload = $url
        $typeName = "url"
    }

    "2" {
        $text = Read-Required "Enter text"
        $payload = $text
        $typeName = "text"
    }

    "3" {
        $phone = Read-Required "Enter phone number"
        $payload = "tel:$phone"
        $typeName = "phone"
    }

    "4" {
        $phone = Read-Required "Enter phone number"
        $message = Read-Host "Enter SMS message"

        $payload = "SMSTO:$phone`:$message"
        $typeName = "sms"
    }

    "5" {
        $email = Read-Required "Enter email address"
        $subject = Read-Host "Enter subject"
        $body = Read-Host "Enter message"

        $payload = "mailto:$email"

        $params = @()

        if (![string]::IsNullOrWhiteSpace($subject)) {
            $params += "subject=$(Url-Encode $subject)"
        }

        if (![string]::IsNullOrWhiteSpace($body)) {
            $params += "body=$(Url-Encode $body)"
        }

        if ($params.Count -gt 0) {
            $payload += "?" + ($params -join "&")
        }

        $typeName = "email"
    }

    "6" {
        $ssid = Read-Required "Enter WiFi name / SSID"
        $password = Read-Host "Enter WiFi password"
        $security = Read-Host "Security type: WPA, WEP, or nopass"

        if ([string]::IsNullOrWhiteSpace($security)) {
            $security = "WPA"
        }

        $hidden = Read-Host "Hidden network? yes/no"

        if ($hidden.ToLower() -eq "yes") {
            $hiddenValue = "true"
        } else {
            $hiddenValue = "false"
        }

        $ssidEscaped = Escape-Wifi $ssid
        $passwordEscaped = Escape-Wifi $password

        if ($security.ToLower() -eq "nopass") {
            $payload = "WIFI:T:nopass;S:$ssidEscaped;H:$hiddenValue;;"
        } else {
            $payload = "WIFI:T:$security;S:$ssidEscaped;P:$passwordEscaped;H:$hiddenValue;;"
        }

        $typeName = "wifi"
    }

    "7" {
        $firstName = Read-Host "First name"
        $lastName = Read-Host "Last name"
        $phone = Read-Host "Phone"
        $email = Read-Host "Email"
        $website = Read-Host "Website"
        $company = Read-Host "Company"
        $jobTitle = Read-Host "Job title"
        $address = Read-Host "Address"

        $fullName = "$firstName $lastName".Trim()

        $payload = @"
BEGIN:VCARD
VERSION:3.0
N:$lastName;$firstName;;;
FN:$fullName
ORG:$company
TITLE:$jobTitle
TEL:$phone
EMAIL:$email
URL:$website
ADR:;;$address;;;;
END:VCARD
"@

        $typeName = "vcard"
    }

    "8" {
        $phone = Read-Required "Enter WhatsApp phone number with country code, example 491701234567"
        $message = Read-Host "Enter WhatsApp message"

        if ([string]::IsNullOrWhiteSpace($message)) {
            $payload = "https://wa.me/$phone"
        } else {
            $payload = "https://wa.me/$phone?text=$(Url-Encode $message)"
        }

        $typeName = "whatsapp"
    }

    "9" {
        $latitude = Read-Required "Enter latitude"
        $longitude = Read-Required "Enter longitude"

        $payload = "geo:$latitude,$longitude"
        $typeName = "location"
    }

    "10" {
        $title = Read-Required "Event title"
        $location = Read-Host "Location"
        $start = Read-Required "Start date/time, example 20260704T140000"
        $end = Read-Required "End date/time, example 20260704T150000"
        $description = Read-Host "Description"

        $payload = @"
BEGIN:VEVENT
SUMMARY:$title
LOCATION:$location
DTSTART:$start
DTEND:$end
DESCRIPTION:$description
END:VEVENT
"@

        $typeName = "event"
    }

    "11" {
        $custom = Read-Required "Enter custom QR payload"
        $payload = $custom
        $typeName = "custom"
    }

    default {
        Write-Host "Invalid choice." -ForegroundColor Red
        exit
    }
}

Save-QRCode -payload $payload -typeName $typeName

Write-Host "Press Enter to close..."
Read-Host
