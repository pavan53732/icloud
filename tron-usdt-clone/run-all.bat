@echo off
REM USDT Clone - Full System Orchestration Script for Windows
REM Runs all components in the correct order

setlocal enabledelayedexpansion

REM Configuration
set LOG_DIR=.\logs
set PID_DIR=.\pids

REM Create necessary directories
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if not exist "%PID_DIR%" mkdir "%PID_DIR%"

REM Colors (Windows 10+)
set GREEN=[92m
set RED=[91m
set YELLOW=[93m
set NC=[0m

echo %GREEN%🚀 Starting USDT Clone System...%NC%
echo.

REM Check command
if "%1"=="" goto :usage
if "%1"=="start" goto :start
if "%1"=="stop" goto :stop
if "%1"=="restart" goto :restart
if "%1"=="status" goto :status
if "%1"=="logs" goto :logs
if "%1"=="deploy" goto :deploy
if "%1"=="test" goto :test
goto :usage

:start
REM Check environment variables
if "%DEPLOYER_PRIVATE_KEY%"=="" (
    echo %RED%Error: DEPLOYER_PRIVATE_KEY not set%NC%
    exit /b 1
)

if "%USDT_CLONE_ADDRESS%"=="" (
    echo %RED%Error: USDT_CLONE_ADDRESS not set%NC%
    echo Run deployment first: npm run deploy
    exit /b 1
)

echo %GREEN%Starting all components...%NC%
echo.

REM 1. Start liquidity bot
echo %YELLOW%Starting liquidity-bot...%NC%
start /b cmd /c "node scripts\lpBot.js > %LOG_DIR%\liquidity-bot.log 2>&1"
echo %GREEN%✅ liquidity-bot started%NC%
timeout /t 3 /nobreak > nul

REM 2. Start metadata spoofer
echo %YELLOW%Starting metadata-spoofer...%NC%
start /b cmd /c "node scripts\metadataSpoofer.js > %LOG_DIR%\metadata-spoofer.log 2>&1"
echo %GREEN%✅ metadata-spoofer started%NC%
timeout /t 2 /nobreak > nul

REM 3. Start anti-analyst system
echo %YELLOW%Starting anti-analyst...%NC%
start /b cmd /c "node scripts\antiAnalyst.js > %LOG_DIR%\anti-analyst.log 2>&1"
echo %GREEN%✅ anti-analyst started%NC%
timeout /t 2 /nobreak > nul

REM 4. Optional: Start deposit attacker (only in test mode)
if "%TEST_MODE%"=="true" (
    echo %YELLOW%Starting deposit-attacker...%NC%
    start /b cmd /c "node scripts\depositAttack.js > %LOG_DIR%\deposit-attacker.log 2>&1"
    echo %GREEN%✅ deposit-attacker started%NC%
)

echo.
echo %GREEN%✅ System startup complete!%NC%
echo Check logs in: %LOG_DIR%
goto :end

:stop
echo %GREEN%Stopping all components...%NC%
echo.

REM Kill Node.js processes running our scripts
echo %YELLOW%Stopping liquidity-bot...%NC%
taskkill /f /im node.exe /fi "WINDOWTITLE eq *lpBot.js*" 2>nul
echo %GREEN%✅ liquidity-bot stopped%NC%

echo %YELLOW%Stopping metadata-spoofer...%NC%
taskkill /f /im node.exe /fi "WINDOWTITLE eq *metadataSpoofer.js*" 2>nul
echo %GREEN%✅ metadata-spoofer stopped%NC%

echo %YELLOW%Stopping anti-analyst...%NC%
taskkill /f /im node.exe /fi "WINDOWTITLE eq *antiAnalyst.js*" 2>nul
echo %GREEN%✅ anti-analyst stopped%NC%

echo %YELLOW%Stopping deposit-attacker...%NC%
taskkill /f /im node.exe /fi "WINDOWTITLE eq *depositAttack.js*" 2>nul
echo %GREEN%✅ deposit-attacker stopped%NC%

echo.
echo %GREEN%✅ All components stopped%NC%
goto :end

:restart
call :stop
timeout /t 2 /nobreak > nul
call :start
goto :end

:status
echo.
echo %GREEN%System Status:%NC%
echo ========================
echo.
echo Component status checking not available on Windows
echo Check Task Manager for node.exe processes
echo.
goto :end

:logs
if "%2"=="" (
    echo Usage: %0 logs ^<component^>
    echo Components: liquidity-bot, metadata-spoofer, anti-analyst, deposit-attacker
    exit /b 1
)

set LOG_FILE=%LOG_DIR%\%2.log
if exist "%LOG_FILE%" (
    type "%LOG_FILE%"
    echo.
    echo %YELLOW%Press Ctrl+C to stop viewing logs%NC%
    powershell -command "Get-Content '%LOG_FILE%' -Wait -Tail 50"
) else (
    echo %RED%Log file not found: %LOG_FILE%%NC%
)
goto :end

:deploy
echo %GREEN%Running deployment...%NC%
echo.
node scripts\deploy.js
goto :end

:test
echo %GREEN%Running tests...%NC%
echo.
npm test
goto :end

:usage
echo USDT Clone System Manager
echo ========================
echo.
echo Usage: %0 {start^|stop^|restart^|status^|logs^|deploy^|test}
echo.
echo Commands:
echo   start    - Start all components
echo   stop     - Stop all components
echo   restart  - Restart all components
echo   status   - Show component status
echo   logs     - Tail component logs
echo   deploy   - Deploy contracts
echo   test     - Run test suite
echo.
echo Environment variables required:
echo   DEPLOYER_PRIVATE_KEY - Private key for deployment
echo   USDT_CLONE_ADDRESS   - Deployed USDT clone address
echo   FAKE_PAIR_ADDRESS    - Deployed fake pair address
echo   GHOST_FORK_ADDRESS   - Deployed ghost fork address
echo.
exit /b 1

:end
endlocal
exit /b 0