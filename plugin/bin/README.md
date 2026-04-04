# plugin/bin/

Place `swmm_cli.exe` here after building the .NET CLI project.

Build command (from repo root):
```
dotnet publish cli/SwmmCli/SwmmCli.csproj -r win-x64 --self-contained true -p:PublishSingleFile=true -o plugin/bin/
```

This directory is on PATH when the plugin is active.
