[CmdletBinding()]
param(
    [switch]$GUI
)

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

$ErrorActionPreference = 'Stop'
$downloadUrl = 'https://devffin.github.io/dl/ytlccv/latest.zip'

function Write-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '  ========================================' -ForegroundColor DarkCyan
    Write-Host '             YTLCCV INSTALLER' -ForegroundColor Cyan
    Write-Host '  ========================================' -ForegroundColor DarkCyan
    Write-Host '  Install or update YTLCCV on this PC.' -ForegroundColor Gray
    Write-Host ''
}

function Read-ExtractionPath {
    do {
        $path = Read-Host 'Installation folder (or B to browse)'

        if ($path -eq 'B' -or $path -eq 'b') {
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $dialog.Description = 'Choose where YTLCCV should be installed'
                $dialog.ShowNewFolderButton = $true
                if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $path = $dialog.SelectedPath
                } else {
                    continue
                }
            } catch {
                Write-Host 'Folder browsing is unavailable; enter the path manually.' -ForegroundColor Yellow
                continue
            }
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-Host 'Please enter a folder path.' -ForegroundColor Yellow
            continue
        }

        try {
            $resolvedPath = [System.IO.Path]::GetFullPath($path.Trim().Trim('"'))

            if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
                throw 'The path points to a file, not a folder.'
            }

            if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
                New-Item -ItemType Directory -Path $resolvedPath -Force | Out-Null
            }

            return $resolvedPath
        }
        catch {
            Write-Host "Invalid path: $($_.Exception.Message)" -ForegroundColor Red
        }
    } while ($true)
}

function Test-MatchingFileStructure {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    $archivePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    try {
        foreach ($entry in $archive.Entries) {
            $entryPath = $entry.FullName.Replace('\', '/').TrimStart('/')
            if ([string]::IsNullOrWhiteSpace($entryPath)) { continue }

            $isDirectory = $entry.FullName.EndsWith('/') -or $entry.FullName.EndsWith('\')
            if (-not $isDirectory) { [void]$archivePaths.Add($entryPath) }

            $directoryPath = if ($isDirectory) {
                $entryPath.TrimEnd('/')
            } else {
                [System.IO.Path]::GetDirectoryName($entryPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
            }
            while (-not [string]::IsNullOrWhiteSpace($directoryPath)) {
                [void]$archivePaths.Add($directoryPath.Replace('\', '/'))
                $parent = [System.IO.Path]::GetDirectoryName($directoryPath)
                if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $directoryPath) { break }
                $directoryPath = $parent
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    $destinationRoot = [System.IO.Path]::GetFullPath($DestinationPath)
    if (-not $destinationRoot.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $destinationRoot += [System.IO.Path]::DirectorySeparatorChar
    }

    foreach ($item in @(Get-ChildItem -LiteralPath $DestinationPath -Force -Recurse)) {
        $relativePath = $item.FullName.Substring($destinationRoot.Length).Replace('\', '/')
        if (-not $archivePaths.Contains($relativePath)) { return $false }
    }

    return $true
}

function Install-Ytlccv {
    param(
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][scriptblock]$OnStatus
    )

    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) ('ytlccv-{0}.zip' -f ([guid]::NewGuid()))
    try {
        & $OnStatus 'Downloading the latest YTLCCV archive...' 15
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing

        & $OnStatus 'Checking the destination folder...' 45
        $existingItems = @(Get-ChildItem -LiteralPath $Destination -Force -Recurse)
        if ($existingItems.Count -gt 0 -and -not (Test-MatchingFileStructure -ArchivePath $tempZip -DestinationPath $Destination)) {
            throw 'The destination contains files or folders that do not match YTLCCV. Choose an empty folder or an existing YTLCCV installation.'
        }

        & $OnStatus 'Extracting files...' 70
        Expand-Archive -LiteralPath $tempZip -DestinationPath $Destination -Force
        & $OnStatus 'Installation completed successfully.' 100
    }
    finally {
        if (Test-Path -LiteralPath $tempZip) {
            Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
        }
    }
}

function Start-TuiInstaller {
    Write-Banner
    Write-Host '  [1] Install / update in this terminal' -ForegroundColor White
    Write-Host '  [2] Open graphical installer' -ForegroundColor White
    Write-Host '  [Q] Quit' -ForegroundColor DarkGray
    Write-Host ''
    $choice = (Read-Host 'Select an option').Trim().ToUpperInvariant()

    if ($choice -eq '2') {
        Start-GuiInstaller
        return
    }
    if ($choice -eq 'Q') { return }
    if ($choice -ne '1') {
        Write-Host 'Please select 1, 2, or Q.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        Start-TuiInstaller
        return
    }

    $destination = Read-ExtractionPath
    Write-Host ''
    try {
        Install-Ytlccv -Destination $destination -OnStatus {
            param($Message, $Percent)
            Write-Progress -Activity 'YTLCCV installation' -Status $Message -PercentComplete $Percent
            Write-Host ('  {0}' -f $Message) -ForegroundColor Cyan
        }
        Write-Progress -Activity 'YTLCCV installation' -Completed
        Write-Host "`nInstalled to: $destination" -ForegroundColor Green
    }
    catch {
        Write-Progress -Activity 'YTLCCV installation' -Completed
        Write-Host "`nInstallation failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Start-GuiInstaller {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
    }
    catch {
        throw 'The graphical installer requires Windows PowerShell with Windows Forms.'
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'YTLCCV Installer'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(560, 270)
    $form.MinimumSize = New-Object System.Drawing.Size(560, 270)
    $form.MaximizeBox = $false
    $form.FormBorderStyle = 'FixedDialog'
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Install or update YTLCCV'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(22, 18)
    $title.Size = New-Object System.Drawing.Size(490, 34)
    $form.Controls.Add($title)

    $description = New-Object System.Windows.Forms.Label
    $description.Text = 'Choose an empty folder or an existing YTLCCV installation folder.'
    $description.Location = New-Object System.Drawing.Point(24, 58)
    $description.Size = New-Object System.Drawing.Size(500, 24)
    $form.Controls.Add($description)

    $pathBox = New-Object System.Windows.Forms.TextBox
    $pathBox.Location = New-Object System.Drawing.Point(24, 95)
    $pathBox.Size = New-Object System.Drawing.Size(390, 27)
    $pathBox.Anchor = 'Top, Left, Right'
    $form.Controls.Add($pathBox)

    $browseButton = New-Object System.Windows.Forms.Button
    $browseButton.Text = 'Browse...'
    $browseButton.Location = New-Object System.Drawing.Point(424, 93)
    $browseButton.Size = New-Object System.Drawing.Size(100, 30)
    $browseButton.Anchor = 'Top, Right'
    $form.Controls.Add($browseButton)

    $status = New-Object System.Windows.Forms.Label
    $status.Text = 'Ready.'
    $status.Location = New-Object System.Drawing.Point(24, 139)
    $status.Size = New-Object System.Drawing.Size(500, 24)
    $form.Controls.Add($status)

    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Location = New-Object System.Drawing.Point(24, 168)
    $progress.Size = New-Object System.Drawing.Size(500, 18)
    $progress.Minimum = 0
    $progress.Maximum = 100
    $form.Controls.Add($progress)

    $installButton = New-Object System.Windows.Forms.Button
    $installButton.Text = 'Install'
    $installButton.Location = New-Object System.Drawing.Point(344, 198)
    $installButton.Size = New-Object System.Drawing.Size(86, 30)
    $installButton.Anchor = 'Bottom, Right'
    $form.Controls.Add($installButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Close'
    $cancelButton.Location = New-Object System.Drawing.Point(438, 198)
    $cancelButton.Size = New-Object System.Drawing.Size(86, 30)
    $cancelButton.Anchor = 'Bottom, Right'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    $form.CancelButton = $cancelButton

    $browseButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Choose where YTLCCV should be installed'
        $dialog.ShowNewFolderButton = $true
        if (-not [string]::IsNullOrWhiteSpace($pathBox.Text) -and (Test-Path -LiteralPath $pathBox.Text -PathType Container)) {
            $dialog.SelectedPath = $pathBox.Text
        }
        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $pathBox.Text = $dialog.SelectedPath
        }
    })

    $installButton.Add_Click({
        try {
            if ([string]::IsNullOrWhiteSpace($pathBox.Text)) { throw 'Enter or browse to an installation folder.' }
            $destination = [System.IO.Path]::GetFullPath($pathBox.Text.Trim().Trim('"'))
            if (Test-Path -LiteralPath $destination -PathType Leaf) { throw 'The selected path is a file, not a folder.' }
            if (-not (Test-Path -LiteralPath $destination -PathType Container)) {
                New-Item -ItemType Directory -Path $destination -Force | Out-Null
            }

            $installButton.Enabled = $false
            $browseButton.Enabled = $false
            $pathBox.Enabled = $false
            $status.Text = 'Starting...'
            $form.Refresh()
            [System.Windows.Forms.Application]::DoEvents()

            Install-Ytlccv -Destination $destination -OnStatus {
                param($Message, $Percent)
                $status.Text = $Message
                $progress.Value = [Math]::Max(0, [Math]::Min(100, [int]$Percent))
                $form.Refresh()
                [System.Windows.Forms.Application]::DoEvents()
            }

            [System.Windows.Forms.MessageBox]::Show($form, "YTLCCV was installed to:`n$destination", 'Installation complete', 'OK', 'Information') | Out-Null
            $status.Text = 'Installation completed successfully.'
        }
        catch {
            $status.Text = 'Installation failed.'
            [System.Windows.Forms.MessageBox]::Show($form, $_.Exception.Message, 'Installation failed', 'OK', 'Error') | Out-Null
        }
        finally {
            $installButton.Enabled = $true
            $browseButton.Enabled = $true
            $pathBox.Enabled = $true
        }
    })

    [void]$form.ShowDialog()
    $form.Dispose()
}

if ($GUI) {
    Start-GuiInstaller
} else {
    Start-TuiInstaller
}
