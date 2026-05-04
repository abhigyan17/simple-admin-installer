@echo off
setlocal EnableExtensions
title SimpleAdmin Offline Installer -- Foxconn ODU (SDXLEMUR)
color 0A
cls

echo ==============================================================
echo   SimpleAdmin Offline Installer
echo   Foxconn B01W009 / Airtel OD523 (Qualcomm SDXLEMUR)
echo ==============================================================
echo.
echo This installs the SimpleAdmin web panel on your ODU device.
echo Access after install: https://192.168.1.1:8443
echo Credentials:  admin / Asdf@12345
echo.

:: ---- Config ----------------------------------------------------------
set "DEVICE_IP=192.168.1.1"
set "SSH_PORT=2222"
set "SSH_USER=root"
set "SSH_PASS=oelinux123"
set "WORK_DIR=%~dp0"

:: Detect plink
set "PLINK="
if exist "C:\Program Files\PuTTY\plink.exe" set "PLINK=C:\Program Files\PuTTY\plink.exe"
if exist "C:\Program Files (x86)\PuTTY\plink.exe" set "PLINK=C:\Program Files (x86)\PuTTY\plink.exe"
if exist "%WORK_DIR%plink.exe" set "PLINK=%WORK_DIR%plink.exe"

:: Detect pscp
set "PSCP="
if exist "C:\Program Files\PuTTY\pscp.exe" set "PSCP=C:\Program Files\PuTTY\pscp.exe"
if exist "C:\Program Files (x86)\PuTTY\pscp.exe" set "PSCP=C:\Program Files (x86)\PuTTY\pscp.exe"
if exist "%WORK_DIR%pscp.exe" set "PSCP=%WORK_DIR%pscp.exe"

:: SCP options -- force legacy SCP protocol (device has no sftp-server)
set "SCPOPTS=-scp -P %SSH_PORT% -pw %SSH_PASS% -batch"
set "SSHOPTS=-P %SSH_PORT% -pw %SSH_PASS% -batch"

:: ---- Pre-flight checks -----------------------------------------------
echo [CHECK 1/4] Checking PuTTY (plink)...
if "%PLINK%"=="" (
    echo   ERROR: plink.exe not found!
    echo   Download PuTTY from https://www.putty.org and install it.
    pause
    exit /b 1
)
echo   Found: %PLINK%

echo [CHECK 2/4] Checking pscp...
if "%PSCP%"=="" (
    echo   ERROR: pscp.exe not found!
    echo   Install PuTTY (includes pscp.exe).
    pause
    exit /b 1
)
echo   Found: %PSCP%

echo [CHECK 3/4] Checking required files...
if not exist "%WORK_DIR%opt_backup.tar.gz" (
    if not exist "%WORK_DIR%opkg" (
        echo   ERROR: opt_backup.tar.gz not found in %WORK_DIR%
        echo   This file contains the pre-built Entware for the device (~10MB).
        echo   Place opt_backup.tar.gz in the same folder as this installer.
        pause
        exit /b 1
    )
    echo   Found: opkg + IPK packages (will install on device)
) else (
    echo   Found: opt_backup.tar.gz
)
if not exist "%WORK_DIR%offline_setup.sh" (
    echo   ERROR: offline_setup.sh not found in %WORK_DIR%
    pause
    exit /b 1
)
echo   Found: offline_setup.sh

echo [CHECK 4/4] Testing SSH connection to device (%DEVICE_IP%)...
"%PLINK%" %SSHOPTS% %SSH_USER%@%DEVICE_IP% "echo SSH_OK" 2>nul | find "SSH_OK" >nul
if errorlevel 1 (
    echo   ERROR: Cannot connect to %DEVICE_IP%:%SSH_PORT% via SSH.
    echo   Make sure:
    echo     - Device is connected (LAN cable or USB)
    echo     - Device IP is %DEVICE_IP%
    echo     - SSH is on port %SSH_PORT% with credentials %SSH_USER%/%SSH_PASS%
    pause
    exit /b 1
)
echo   SSH connection: OK

echo.
echo ==============================================================
echo   All checks passed. Starting installation...
echo ==============================================================
echo.

:: ---- Step 1: Create install directory on device ----------------------
echo [STEP 1/5] Creating /tmp/install on device...
"%PLINK%" %SSHOPTS% %SSH_USER%@%DEVICE_IP% "mkdir -p /tmp/install && echo ok"

:: ---- Step 2: Transfer files via pscp (SCP protocol) ------------------
echo [STEP 2/5] Transferring files to device...
echo   Note: Using legacy SCP protocol (device has no sftp-server).

:: Installer script
"%PSCP%" %SCPOPTS% "%WORK_DIR%offline_setup.sh" %SSH_USER%@%DEVICE_IP%:/tmp/install/offline_setup.sh
if errorlevel 1 goto scp_fail
echo   [OK] offline_setup.sh

:: Entware backup (preferred) or opkg + IPK packages
if exist "%WORK_DIR%opt_backup.tar.gz" (
    echo   Transferring opt_backup.tar.gz (~10MB, please wait)...
    "%PSCP%" %SCPOPTS% "%WORK_DIR%opt_backup.tar.gz" %SSH_USER%@%DEVICE_IP%:/data/opt_backup.tar.gz
    if errorlevel 1 goto scp_fail
    echo   [OK] opt_backup.tar.gz -> /data/ (persistent)
) else (
    "%PSCP%" %SCPOPTS% "%WORK_DIR%opkg" %SSH_USER%@%DEVICE_IP%:/tmp/install/opkg
    if errorlevel 1 goto scp_fail
    "%PSCP%" %SCPOPTS% "%WORK_DIR%opkg.conf" %SSH_USER%@%DEVICE_IP%:/tmp/install/opkg.conf
    "%PSCP%" %SCPOPTS% "%WORK_DIR%*.ipk" %SSH_USER%@%DEVICE_IP%:/tmp/install/
    echo   [OK] opkg + IPK packages
)

:: Web files (www/, console/, script/) -- from quectel-rgmii-toolkit
if exist "%WORK_DIR%www" (
    "%PSCP%" %SCPOPTS% -r "%WORK_DIR%www" %SSH_USER%@%DEVICE_IP%:/tmp/install/
    echo   [OK] www/
)
if exist "%WORK_DIR%console" (
    "%PSCP%" %SCPOPTS% -r "%WORK_DIR%console" %SSH_USER%@%DEVICE_IP%:/tmp/install/
    echo   [OK] console/
)
if exist "%WORK_DIR%script" (
    "%PSCP%" %SCPOPTS% -r "%WORK_DIR%script" %SSH_USER%@%DEVICE_IP%:/tmp/install/
    echo   [OK] script/
)

:: socat-at-bridge -- needed for AT command CGI functionality
if exist "%WORK_DIR%socat-at-bridge" (
    "%PSCP%" %SCPOPTS% -r "%WORK_DIR%socat-at-bridge" %SSH_USER%@%DEVICE_IP%:/tmp/install/
    echo   [OK] socat-at-bridge/
) else (
    echo   [INFO] socat-at-bridge not in bundle (installer will use device copy if present)
)

:: ---- Step 3: Run installer on device ---------------------------------
echo.
echo [STEP 3/5] Running installer on device...
echo   This sets up lighttpd, socat bridges, systemd services, SSL cert.
echo.
"%PLINK%" %SSHOPTS% %SSH_USER%@%DEVICE_IP% "chmod +x /tmp/install/offline_setup.sh && sh /tmp/install/offline_setup.sh 2>&1"

:: ---- Step 4: Verify --------------------------------------------------
echo.
echo [STEP 4/5] Verifying installation...
"%PLINK%" %SSHOPTS% %SSH_USER%@%DEVICE_IP% "echo '  lighttpd:' $(systemctl is-active lighttpd) && echo '  socat-smd7:' $(systemctl is-active socat-smd7) && echo '  AT bridge:' $(systemctl is-active socat-smd7-to-ttyIN2) && netstat -tlnp 2>/dev/null | grep 8443 && echo '  port 8443: listening'"

:: ---- Step 5: Cleanup -------------------------------------------------
echo.
echo [STEP 5/5] Cleanup...
"%PLINK%" %SSHOPTS% %SSH_USER%@%DEVICE_IP% "rm -rf /tmp/install && echo 'tmp cleaned'"

:: ---- Done ------------------------------------------------------------
echo.
echo ==============================================================
echo   INSTALLATION COMPLETE
echo ==============================================================
echo.
echo   Open your browser and go to:
echo     https://%DEVICE_IP%:8443
echo.
echo   Login with:
echo     Username: admin
echo     Password: Asdf@12345
echo.
echo   NOTE: You will get a certificate warning (self-signed cert).
echo         Click "Advanced" and "Proceed" to continue.
echo.
echo   Features available:
echo     - AT Command panel (read modem responses, send custom AT commands)
echo     - Device info, network status, signal strength
echo     - Web terminal (ttyd) at /console
echo     - SMS, ping, TTL override, watchcat
echo.
echo   All services auto-start on every reboot.
echo.
pause
exit /b 0

:scp_fail
echo.
echo   ERROR: File transfer (SCP) failed!
echo   Make sure plink can reach the device:
echo     "%PLINK%" %SSHOPTS% root@192.168.1.1 "uptime"
echo.
pause
exit /b 1
