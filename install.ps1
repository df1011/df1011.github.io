[CmdletBinding()]
param()

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

$ErrorActionPreference = 'Stop'
$downloadUrl = 'https://devffin.github.io/dl/ytlccv/latest.zip'
$tempZip = Join-Path ([System.IO.Path]::GetTempPath()) ('ytlccv-{0}.zip' -f ([guid]::NewGuid()))

function Write-Banner {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor DarkCyan
    Write-Host '          YTLCCV Installer' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Read-ExtractionPath {
    do {
        $path = Read-Host 'Folder where YTLCCV should be extracted'

        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-Host 'Please enter a folder path.' -ForegroundColor Yellow
            continue
        }

        try {
            $resolvedPath = [System.IO.Path]::GetFullPath($path)

            if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
                throw 'The path points to a file, not a folder.'
            }

            if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
                New-Item -ItemType Directory -Path $resolvedPath -Force | Out-Null
                Write-Host "Created folder: $resolvedPath" -ForegroundColor DarkGray
            }

            return $resolvedPath
        }
        catch {
            Write-Host "Invalid path: $($_.Exception.Message)" -ForegroundColor Red
        }
    } while ($true)
}

Write-Banner
$destination = Read-ExtractionPath

try {
    Write-Host 'Downloading YTLCCV...' -ForegroundColor Yellow
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
    Write-Host 'Download complete.' -ForegroundColor Green

    Write-Host "Extracting to: $destination" -ForegroundColor Yellow
    Expand-Archive -LiteralPath $tempZip -DestinationPath $destination -Force
    Write-Host ''
    Write-Host 'Installation completed successfully!' -ForegroundColor Green
}
catch {
    Write-Host ''
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $tempZip) {
        Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
    }
}