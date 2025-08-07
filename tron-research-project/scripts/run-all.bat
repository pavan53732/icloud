@echo off
REM =====================================
REM     FakeUSDT Full Deployment Script
REM =====================================
REM
REM This script automates the entire deployment and operation process
REM for the FakeUSDT ecosystem on Windows
REM

echo =====================================
echo     FakeUSDT Deployment System
echo =====================================
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    exit /b 1
)

REM Check if npm is installed
npm --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: npm is not installed or not in PATH
    exit /b 1
)

REM Set environment variables
if "%TRON_NETWORK%"=="" (
    set TRON_NETWORK=https://api.trongrid.io
)

if "%PRIVATE_KEY%"=="" (
    echo ERROR: PRIVATE_KEY environment variable not set
    echo Please set your private key:
    echo   set PRIVATE_KEY=your_private_key_here
    exit /b 1
)

REM Create necessary directories
echo Creating project directories...
if not exist "..\logs" mkdir "..\logs"
if not exist "..\build" mkdir "..\build"
if not exist "..\kyc" mkdir "..\kyc"

REM Install dependencies
echo.
echo Installing dependencies...
cd ..
call npm install --silent
if %errorlevel% neq 0 (
    echo ERROR: Failed to install dependencies
    exit /b 1
)
cd scripts

REM Step 1: Deploy contracts
echo.
echo =====================================
echo Step 1: Deploying Contracts
echo =====================================
node deploy.js
if %errorlevel% neq 0 (
    echo ERROR: Contract deployment failed
    exit /b 1
)

REM Extract contract addresses from deployment.json
echo.
echo Extracting contract addresses...
for /f "tokens=2 delims=:, " %%a in ('findstr /i "FakeUSDT" ..\deployment.json') do set FAKE_USDT_ADDRESS=%%~a
for /f "tokens=2 delims=:, " %%a in ('findstr /i "FakeUniswapV2Pair" ..\deployment.json') do set FAKE_PAIR_ADDRESS=%%~a

echo FakeUSDT Address: %FAKE_USDT_ADDRESS%
echo FakePair Address: %FAKE_PAIR_ADDRESS%

REM Step 2: Verify contracts
echo.
echo =====================================
echo Step 2: Verifying Contracts
echo =====================================
timeout /t 10 /nobreak >nul
node verifyContract.js
if %errorlevel% neq 0 (
    echo WARNING: Contract verification failed
    echo Continuing without verification...
)

REM Step 3: Start liquidity bot
echo.
echo =====================================
echo Step 3: Starting Liquidity Bot
echo =====================================
echo Starting bot in background...
start /b "LiquidityBot" cmd /c "node lpBot.js > ..\logs\lpbot.log 2>&1"
echo Liquidity bot started (PID: check lpbot.log)

REM Wait for bot initialization
timeout /t 5 /nobreak >nul

REM Step 4: Test deposit functionality
echo.
echo =====================================
echo Step 4: Testing Deposit Function
echo =====================================
node fakeDeposit.js deposit generic 100 --address %FAKE_PAIR_ADDRESS%
if %errorlevel% neq 0 (
    echo WARNING: Test deposit failed
)

REM Step 5: Monitor system
echo.
echo =====================================
echo Step 5: System Monitoring
echo =====================================
echo.
echo System is now running!
echo.
echo Contract Addresses:
echo   FakeUSDT: %FAKE_USDT_ADDRESS%
echo   FakePair: %FAKE_PAIR_ADDRESS%
echo.
echo Monitoring Dashboard:
echo   Logs: ..\logs\
echo   Shadow logs: ..\logs\shadow.log
echo   Event logs: ..\logs\events.log
echo   Deposit logs: ..\logs\deposits.log
echo.
echo Available Commands:
echo   1. View bot status: type ..\logs\lpbot.log
echo   2. Execute deposit: node fakeDeposit.js deposit [dapp] [amount]
echo   3. Monitor deposit: node fakeDeposit.js monitor [txid]
echo   4. Stop all: Ctrl+C
echo.
echo =====================================

REM Keep script running
:monitor_loop
echo.
echo [%date% %time%] System running...
timeout /t 60 /nobreak >nul

REM Check if bot is still running
tasklist /fi "windowtitle eq LiquidityBot*" 2>nul | find /i "cmd.exe" >nul
if %errorlevel% neq 0 (
    echo WARNING: Liquidity bot stopped! Restarting...
    start /b "LiquidityBot" cmd /c "node lpBot.js >> ..\logs\lpbot.log 2>&1"
)

goto monitor_loop

:end
echo.
echo Script terminated.
pause