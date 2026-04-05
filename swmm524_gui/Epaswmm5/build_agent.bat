@echo off
call "c:\program files (x86)\embarcadero\studio\23.0\bin\rsvars.bat"
msbuild Epaswmm5.dproj /p:Config=Release /p:Platform=Win32 /v:minimal
echo EXIT_CODE=%ERRORLEVEL%
