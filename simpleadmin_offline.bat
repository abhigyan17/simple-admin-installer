@echo off
setlocal
title Quectel SimpleAdmin Auto-Installer
color 0B

:: 1. Setup working directory
set "WORK_DIR=D:\Browsers_Downloads\airtel ODU research\SimpleAdmin"
echo ==================================================
echo Setting up staging folder at %WORK_DIR%...
echo ==================================================
if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"
cd /d "%WORK_DIR%"

:: 2. Download scripts directly from GitHub
echo.
echo ==================================================
echo Step 1: Downloading Scripts from GitHub...
echo ==================================================
curl -s -L -o update_socat-at-bridge.sh "https://raw.githubusercontent.com/iamromulan/quectel-rgmii-toolkit/SDXLEMUR/simpleupdates/scripts/update_socat-at-bridge.sh"
curl -s -L -o update_simplefirewall.sh "https://raw.githubusercontent.com/iamromulan/quectel-rgmii-toolkit/SDXLEMUR/simpleupdates/scripts/update_simplefirewall.sh"
curl -s -L -o update_simpleadmin.sh "https://raw.githubusercontent.com/iamromulan/quectel-rgmii-toolkit/SDXLEMUR/simpleupdates/scripts/update_simpleadmin.sh"
curl -s -L -o htpasswd "https://raw.githubusercontent.com/iamromulan/quectel-rgmii-toolkit/SDXLEMUR/simpleadmin/htpasswd"
curl -s -L -o simplepasswd "https://raw.githubusercontent.com/iamromulan/quectel-rgmii-toolkit/SDXLEMUR/simpleadmin/simplepasswd"
echo Scripts downloaded successfully!

:: 3. Generate and run PowerShell script to dynamically fetch .ipk packages and their dependencies
echo.
echo ==================================================
echo Step 2: Fetching latest .ipk packages and dependencies from Entware
echo ==================================================
python -c "script = '''$url = \"http://bin.entware.net/armv7sf-k3.2/\"\n$packages = \"entware-opt\", \"lighttpd\", \"shadow-useradd\", \"shadow-login\", \"shadow-passwd\", \"lighttpd-mod-authn_file\", \"lighttpd-mod-auth\", \"lighttpd-mod-cgi\", \"lighttpd-mod-openssl\", \"lighttpd-mod-proxy\"\nWrite-Host \"Downloading Packages.gz index...\" -ForegroundColor Cyan\n$gzPath = \"$PWD\Packages.gz\"\nInvoke-WebRequest -Uri \"$url/Packages.gz\" -OutFile $gzPath\nWrite-Host \"Extracting and parsing dependencies...\" -ForegroundColor Cyan\n[System.IO.Compression.GZipStream]$stream = New-Object System.IO.Compression.GZipStream ([System.IO.File]::OpenRead($gzPath), [System.IO.Compression.CompressionMode]::Decompress)\n$reader = New-Object System.IO.StreamReader ($stream)\n$content = $reader.ReadToEnd()\n$reader.Close()\n$lines = $content -split \"`n\"\n$deps = @{}\n$pkgs = @{}\n$current = \"\"\nforeach ($l in $lines) {\n    if ($l -match \"^Package: \") { $current = $l.Substring(9).Trim(); $pkgs[$current] = \"\" }\n    if ($l -match \"^Depends: \") { $deps[$current] = $l.Substring(9).Trim() }\n    if ($l -match \"^Filename: \") { $pkgs[$current] = $l.Substring(10).Trim() }\n}\n$required = New-Object System.Collections.Generic.HashSet[string]\nfunction Get-Deps ($pkg) {\n    if ($required.Contains($pkg)) { return }\n    $required.Add($pkg) | Out-Null\n    if ($deps.ContainsKey($pkg)) {\n        $pkgDeps = $deps[$pkg] -split \", \"\n        foreach ($d in $pkgDeps) { if ($d) { Get-Deps $d } }\n    }\n}\nforeach ($p in $packages) { Get-Deps $p }\nWrite-Host \"Total required packages: $($required.Count)\" -ForegroundColor Yellow\nforeach ($p in $required) {\n    $filename = $pkgs[$p]\n    if ($filename) {\n        if (-not (Test-Path $filename)) {\n            Write-Host \"Downloading $filename...\"\n            Invoke-WebRequest -Uri \"$url$filename\" -OutFile $filename\n        } else {\n            Write-Host \"Skipping $filename (already exists)...\" -ForegroundColor DarkGray\n        }\n    }\n}\nWrite-Host \"Downloading Entware opkg installer binary...\" -ForegroundColor Cyan\nInvoke-WebRequest -Uri \"$url/installer/opkg\" -OutFile \"opkg\"\nInvoke-WebRequest -Uri \"$url/installer/opkg.conf\" -OutFile \"opkg.conf\"'''; open('download_packages.ps1', 'w').write(script)"

PowerShell -NoProfile -ExecutionPolicy Bypass -File download_packages.ps1
del download_packages.ps1

:: 4. Verify ADB Connection
echo.
echo ==================================================
echo Step 3: Checking ADB Connection
echo ==================================================
adb devices
echo.
echo Make sure your device is listed above! 
echo If it says "unauthorized" or is blank, fix your ADB connection before continuing.
pause

:: 5. Push files and execute installation
echo.
echo ==================================================
echo Step 4: Pushing files to the modem via ADB...
echo ==================================================
adb shell "mkdir -p /tmp/offline_files"
adb push . /tmp/offline_files/

echo.
echo ==================================================
echo Step 5: Executing installation on the modem...
echo ==================================================
:: Mount filesystem as read/write
adb shell "mount -o remount,rw /"

:: Critical Fix for SDXLEMUR: Create symlink from /data to /usrdata
echo Creating /usrdata partition symlink if missing...
adb shell "if [ ! -d /usrdata ]; then ln -s /data /usrdata; fi"

:: Bootstrapping Entware Handled by offline_setup.sh
echo Setting permissions and moving password handlers...
adb shell "cd /tmp/offline_files && chmod +x *.sh htpasswd simplepasswd"
adb shell "mkdir -p /usrdata/root/bin"
adb shell "mv /tmp/offline_files/htpasswd /usrdata/root/bin/htpasswd"
adb shell "mv /tmp/offline_files/simplepasswd /usrdata/root/bin/simplepasswd"


:: Run the offline setup script

adb shell "cd /tmp/offline_files && ./offline_setup.sh"

:: Cleanup
adb shell "rm -rf /tmp/offline_files"
adb shell "mount -o remount,ro /"

echo.
echo ==================================================
echo INSTALLATION COMPLETE!
echo You can now access SimpleAdmin via your web browser.
echo ==================================================
pause