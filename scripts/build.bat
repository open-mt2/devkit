@echo off
rem ======================================================
rem The Old Metin2 Project - Automated client build script
rem Windows Build & Packaging Script
rem
rem Mirrors scripts/build.sh (same options, same dist/ layout).
rem ======================================================

setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%"
rem Support both build.bat at the project root and scripts\build.bat.
if /I "%PROJECT_ROOT:~-9%"=="\scripts\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-9%"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
cd /d "%PROJECT_ROOT%"
if errorlevel 1 (
	echo ERROR: cannot enter "%PROJECT_ROOT%".
	exit /b 1
)

set "BUILD_TYPE=Distribute"
set "NUM_JOBS="
set "SKIP_PACK=0"
set "CLEAN_BUILD=0"
set "RUN_TESTS=0"

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="-b" goto arg_build_type
if /I "%~1"=="--build-type" goto arg_build_type
if /I "%~1"=="-j" goto arg_jobs
if /I "%~1"=="--jobs" goto arg_jobs
if /I "%~1"=="-t" goto arg_test
if /I "%~1"=="--test" goto arg_test
if /I "%~1"=="--clean" goto arg_clean
if /I "%~1"=="--skip-pack" goto arg_skip_pack
if /I "%~1"=="-h" goto show_help
if /I "%~1"=="--help" goto show_help
echo Unknown option: %~1
goto show_help

:arg_build_type
if "%~2"=="" (
	echo ERROR: %~1 requires a value.
	exit /b 1
)
set "BUILD_TYPE=%~2"
shift
shift
goto parse_args

:arg_jobs
if "%~2"=="" (
	echo ERROR: %~1 requires a value.
	exit /b 1
)
set "NUM_JOBS=%~2"
shift
shift
goto parse_args

:arg_test
set "RUN_TESTS=1"
shift
goto parse_args

:arg_clean
set "CLEAN_BUILD=1"
shift
goto parse_args

:arg_skip_pack
set "SKIP_PACK=1"
shift
goto parse_args

:args_done

echo ======================================================
echo The Old Metin2 Project - Automated client build script
echo Windows Build Environment
echo ======================================================

rem Check the environment variables (normally set in build.bat or the caller).
if not defined M2_MSVC_DIR (
	echo M2_MSVC_DIR is NOT defined. Please define M2_MSVC_DIR with the path of your local MSVC install.
	exit /b 1
)
if not defined M2_7ZIP_PATH (
	echo M2_7ZIP_PATH is NOT defined. Please define M2_7ZIP_PATH with the path of your local 7-Zip "7z.exe" executable.
	exit /b 1
)
if not exist "%M2_MSVC_DIR%\VC\Auxiliary\Build\vcvars32.bat" (
	echo ERROR: vcvars32.bat not found under "%M2_MSVC_DIR%".
	exit /b 1
)
if not exist "%M2_7ZIP_PATH%" (
	echo ERROR: 7-Zip executable not found: "%M2_7ZIP_PATH%".
	exit /b 1
)

echo [1/5] Checking dependencies...
if not exist "Metin2Client.sln" (
	echo ERROR: Metin2Client.sln not found. Run this script from the client source tree.
	exit /b 1
)
echo   - Build Type:      %BUILD_TYPE%
echo   - 7-Zip:           %M2_7ZIP_PATH%

rem Initialize the MSVC environment
CALL "%M2_MSVC_DIR%\VC\Auxiliary\Build\vcvars32.bat" >nul
if errorlevel 1 exit /b %errorlevel%

if "%CLEAN_BUILD%"=="1" (
	if exist build (
		echo Cleaning build directory: build
		rmdir /S /Q build
	)
)

rem Configure & build
echo.
echo [2/5] Building client binaries...
if defined NUM_JOBS (
	msbuild Metin2Client.sln /p:Configuration=%BUILD_TYPE% /p:Platform="Win32" /m:%NUM_JOBS%
) else (
	msbuild Metin2Client.sln /p:Configuration=%BUILD_TYPE% /p:Platform="Win32"
)
if errorlevel 1 exit /b %errorlevel%

if "%RUN_TESTS%"=="1" (
	echo.
	echo [2b/5] Running CTest test suites...
	ctest --test-dir build --output-on-failure
	if errorlevel 1 exit /b !errorlevel!
)

rem Assemble dist package
echo.
echo [3/5] Assembling client distribution directory in "dist"...
if "%CLEAN_BUILD%"=="1" (
	if exist dist rmdir /S /Q dist
)
if not exist dist mkdir dist

set "BUILT_BIN=build\bin\%BUILD_TYPE%"
if not exist "%BUILT_BIN%\UserInterface.exe" (
	echo ERROR: Executable "%BUILT_BIN%\UserInterface.exe" not found after build!
	exit /b 1
)
copy /Y "%BUILT_BIN%\UserInterface.exe" "dist\metin2client.exe" >nul
copy /Y "%BUILT_BIN%\UserInterface.exe" "dist\metin2.exe" >nul
echo   - Installed executable: dist\metin2client.exe

if exist "%BUILT_BIN%\Config.exe" (
	copy /Y "%BUILT_BIN%\Config.exe" "dist\config.exe" >nul
	echo   - Installed configuration utility: dist\config.exe
)

rem Copy over the data from the bin directory, mirroring build.sh.
echo.
echo [4/5] Copying asset and runtime data from bin\...
if exist bin\ (
	for %%F in ("bin\*") do (
		if not exist "%%~fF\" (
			if /I not "%%~xF"==".dll" copy /Y "%%~fF" "dist\" >nul
		)
	)

	for %%D in (BGM lib mark miles screenshot upload) do (
		if not exist "dist\%%D\" mkdir "dist\%%D"
		if exist "bin\%%D\" xcopy "bin\%%D\*" "dist\%%D\" /E /Y /Q >nul
	)
	del /S /Q "dist\.gitignore" >nul 2>&1

	if exist treecache\ (
		if not exist "dist\treecache\" mkdir "dist\treecache"
		copy /Y "treecache\*.tree" "dist\treecache\" >nul
		echo   - Installed tree geometry cache: dist\treecache
	)

	if not exist "dist\pack\" mkdir "dist\pack"
	if exist "bin\pack\Index" copy /Y "bin\pack\Index" "dist\pack\" >nul
	if exist "bin\pack\*.rdch" copy /Y "bin\pack\*.rdch" "dist\pack\" >nul
) else (
	echo WARNING: "bin" directory not found. Skipping asset copy.
)

rem Build and copy pack archives
echo.
if "%SKIP_PACK%"=="1" (
	echo [5/5] Skipping pack archives creation ^(--skip-pack: preserving existing archives in dist\pack\^).
	if not exist "dist\pack\" mkdir "dist\pack"
	if exist "bin\pack\*.zip" copy /Y "bin\pack\*.zip" "dist\pack\" >nul
) else (
	echo [5/5] Compressing and installing pack archives into dist\pack\...
	if exist "bin\pack\" (
		del /F /Q "bin\pack\*.zip" >nul 2>&1
		set "PACK_COUNT=0"
		for /d %%P in ("bin\pack\*") do (
			echo   - Packing %%~nxP...
			"%M2_7ZIP_PATH%" a -tzip "dist\pack\%%~nxP.zip" "%%~fP\*" >nul
			if errorlevel 1 exit /b !errorlevel!
			set /A PACK_COUNT+=1
		)
		echo   - Total pack archives created: !PACK_COUNT!
	) else (
		echo   - No bin\pack directory; nothing to pack.
	)
)

echo.
echo ======================================================
echo Client package successfully assembled!
echo Location: %PROJECT_ROOT%\dist
echo.
echo To run the client:
echo   cd dist ^&^& metin2client.exe
echo ======================================================
exit /b 0

:show_help
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   -b, --build-type ^<TYPE^>   MSBuild configuration (Distribute, Release, Debug). Default: Distribute
echo   -j, --jobs ^<N^>            Number of parallel build jobs (msbuild /m:N)
echo   -t, --test                Run CTest test suites after build
echo   --clean                   Remove existing build/dist directories before building
echo   --skip-pack               Skip packing bin\pack\* zip archives
echo   -h, --help                Show this help message
exit /b 1
