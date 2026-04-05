@echo off
setlocal

set REPO=%~dp0
if exist "%~dp0build.env.bat" call "%~dp0build.env.bat"

set SIGNTOOL=c:\program files (x86)\Microsoft Visual Studio\Shared\NuGetPackages\microsoft.windows.sdk.buildtools\10.0.26100.1742\bin\10.0.26100.0\x64\signtool.exe
set CERT_PFX=C:\Chaitanya\MasaLab\masalab-codesign.pfx
set DELPHI_RSVARS=c:\program files (x86)\embarcadero\studio\23.0\bin\rsvars.bat
set DELPHI_PROJ=%REPO%swmm524_gui\Epaswmm5\Epaswmm5.dproj
set DELPHI_BUILD=%REPO%swmm524_gui\Epaswmm5\Build\Win32\
set PLUGIN_DIST=%REPO%plugin\dist\

echo === Building Delphi (Epaswmm5.exe) ===
call "%DELPHI_RSVARS%"
msbuild "%DELPHI_PROJ%" /t:Build /p:Config=Release /p:Platform=Win32 /nologo /v:minimal
if errorlevel 1 ( echo FAILED: Delphi build & exit /b 1 )

echo   ^-^> Copying 3 binaries to plugin/dist/
copy /y "%DELPHI_BUILD%Epaswmm5.exe" "%PLUGIN_DIST%Epaswmm5.exe"
if errorlevel 1 ( echo FAILED: copy Epaswmm5.exe & exit /b 1 )
copy /y "%DELPHI_BUILD%runswmm.exe"  "%PLUGIN_DIST%runswmm.exe"
if errorlevel 1 ( echo FAILED: copy runswmm.exe & exit /b 1 )
copy /y "%DELPHI_BUILD%swmm5.dll"    "%PLUGIN_DIST%swmm5.dll"
if errorlevel 1 ( echo FAILED: copy swmm5.dll & exit /b 1 )

echo.
echo === Building .NET CLI (swmm_cli.exe) ===
dotnet publish "%REPO%cli\SwmmCli\SwmmCli.csproj" /nologo /v:minimal
if errorlevel 1 ( echo FAILED: dotnet publish & exit /b 1 )

echo.
echo === Signing binaries ===
if not defined CERT_PASS ( echo SKIPPED: CERT_PASS not set & goto done )
"%SIGNTOOL%" sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /f "%CERT_PFX%" /p "%CERT_PASS%" "%PLUGIN_DIST%Epaswmm5.exe" "%PLUGIN_DIST%runswmm.exe" "%PLUGIN_DIST%swmm5.dll" "%REPO%plugin\bin\swmm_cli.exe"
if errorlevel 1 ( echo FAILED: signing & exit /b 1 )

:done
echo.
echo === Plugin ready ===
echo   plugin\dist\Epaswmm5.exe
echo   plugin\bin\swmm_cli.exe
