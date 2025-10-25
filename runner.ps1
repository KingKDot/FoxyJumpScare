param(
    [switch]$Debug
)

$ProgressPreference = 'SilentlyContinue'

Set-StrictMode -Version Latest

$BaseRawUrl = 'https://raw.githubusercontent.com/KingKDot/FoxyJumpScare/main/FoxyJumpScare/assets'

function Set-SystemVolume100 {
    $csharp = @"
using System;
using System.Runtime.InteropServices;
public static class WinMM {
    [DllImport("winmm.dll")]
    public static extern int waveOutSetVolume(IntPtr hwo, uint dwVolume);
}
"@
    Add-Type -TypeDefinition $csharp -PassThru | Out-Null
    $vol = [uint32]::Parse((65535).ToString())
    $volumeBoth = ($vol -bor ($vol -shl 16)) -as [uint32]
    [WinMM]::waveOutSetVolume([IntPtr]::Zero, $volumeBoth) | Out-Null
}

function Download-Assets {
    $frames = @(
        'frame000.png','frame001.png','frame002.png','frame003.png','frame004.png','frame005.png','frame006.png','frame007.png','frame008.png','frame009.png',
        'frame0010.png','frame0011.png','frame0012.png','frame0013.png'
    )

    $frameData = @()

    foreach ($f in $frames) {
        $url = "$BaseRawUrl/frames/$f"
        try {
            $bytes = (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content
            $frameData += @{ name = $f; bytes = $bytes }
        } catch {
            Write-Error "Failed to download $url : $_"
        }
    }

    # wav
    $wavUrl = "$BaseRawUrl/jumpscare.wav"
    $wavBytes = $null
    try {
        $wavBytes = (Invoke-WebRequest -Uri $wavUrl -UseBasicParsing -ErrorAction Stop).Content
    } catch {
        Write-Error "Failed to download $wavUrl : $_"
    }

    return @{ frames = $frameData; wav = $wavBytes }
}

function Run-Jumpscare {
    param(
        [object[]]$FrameData,
        [byte[]]$WavBytes
    )
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop

        [System.Windows.Forms.Application]::EnableVisualStyles()
        [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

        $form = New-Object System.Windows.Forms.Form
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $form.BackColor = [System.Drawing.Color]::Black
        $form.AllowTransparency = $true
        $form.TransparencyKey = [System.Drawing.Color]::Black
        $form.TopMost = $true

        $pictureBox = New-Object System.Windows.Forms.PictureBox
        $pictureBox.Dock = [System.Windows.Forms.DockStyle]::Fill
        $pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
        $pictureBox.BackColor = [System.Drawing.Color]::Black
        $pictureBox.Margin = New-Object System.Windows.Forms.Padding(0)
        $pictureBox.Padding = New-Object System.Windows.Forms.Padding(0)
        $form.Controls.Add($pictureBox)

        $images = New-Object System.Collections.Generic.List[System.Drawing.Image]
        foreach ($frameItem in $FrameData) {
            try {
                $stream = New-Object System.IO.MemoryStream(, $frameItem.bytes)
                $img = [System.Drawing.Image]::FromStream($stream)
                [void]$images.Add($img)
            } catch {
                Write-Error "Failed to load image $($frameItem.name) : $_"
            }
        }

        if ($images.Count -eq 0) {
            Write-Error "[UI] No images to display; aborting UI."
            return
        }

        $soundPlayer = $null
        $soundStream = $null
        if ($WavBytes) {
            try {
                $soundStream = New-Object System.IO.MemoryStream(, $WavBytes)
                $soundPlayer = New-Object System.Media.SoundPlayer($soundStream)
            } catch {
                Write-Error "Failed to create sound player: $_"
            }
        }

        $state = @{ current = 0 }
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 33 # ~30 fps

        $timer.Add_Tick({
            if ($state.current -lt $images.Count) {
                $pictureBox.Image = $images[$state.current]
                if ($Debug) { Write-Host "Frame $($state.current) of $($images.Count)" }
                $state.current++
            }
            
            if ($state.current -ge $images.Count) {
                $timer.Stop()
                try { 
                    if ($soundPlayer) { $soundPlayer.Stop() } 
                } catch {}
                $form.Close()
            }
        })

        $form.Add_Shown({
            try { 
                if ($soundPlayer) { $soundPlayer.Play() } 
            } catch {
                Write-Error "Failed to play sound: $_"
            }
            $timer.Start()
        })

        [System.Windows.Forms.Application]::Run($form)

    } catch {
        Write-Error "[UI] Unhandled exception: $_"
        Write-Error $_.Exception.StackTrace
    } finally {
        try {
            foreach ($img in $images) { 
                try { $img.Dispose() } catch {} 
            }
        } catch {}
        
        try { 
            if ($timer) { $timer.Stop(); $timer.Dispose() }
        } catch {}
        
        try { 
            if ($soundStream) { $soundStream.Close(); $soundStream.Dispose() } 
        } catch {}
    }
}

function Main {
    try {
        if ($Debug) { Write-Host "Downloading assets..." }
        $assets = Download-Assets
        
        if (-not $assets.frames -or $assets.frames.Count -eq 0) {
            Write-Error "No assets downloaded. Exiting."
            return
        }

        if ($Debug) { Write-Host "Downloaded $($assets.frames.Count) frames and WAV file" }

        if ($Debug) { Write-Host "Setting system volume to 100%..." }
        Set-SystemVolume100

        if ($Debug) { Write-Host "Starting jumpscare..." }
        
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop

        $sortedFrames = $assets.frames | Sort-Object { [int]($_.name -replace '.*frame(\d+)\.png', '$1') }
        
        Run-Jumpscare -FrameData $sortedFrames -WavBytes $assets.wav

        if ($Debug) { Write-Host "Jumpscare completed" }

    } catch {
        Write-Error "Fatal error: $_"
        Write-Error $_.Exception.StackTrace
    }
}

Main