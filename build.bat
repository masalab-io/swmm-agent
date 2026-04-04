@echo off
call "c:\program files (x86)\embarcadero\studio\23.0\bin\rsvars.bat"
msbuild "C:\Chaitanya\MasaLab\009SWMMAgent\swmm524_gui\Epaswmm5\Epaswmm5.dproj" /t:Build /p:Config=Release /p:Platform=Win32 /nologo /v:minimal
