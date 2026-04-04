# EPA SWMM 5.2.4 GUI — Build Instructions

This document explains how to build the EPA SWMM 5.2.4 Windows GUI application from source using RAD Studio (Delphi 12 Athens). It covers every issue encountered during a real build, including workarounds and pitfalls for both human developers and AI agents.

---

## Project Structure

```
swmm524_gui/
  Components/         EPA custom Delphi component package
    Epa.dpk           Component package definition
    Epa.dproj         Component project file
    Win32/            Build output for the component package (create before building)
    *.pas             Component source files
  Epaswmm5/           Main SWMM GUI application project
    Epaswmm5.dproj    Main project file
    Epaswmm5.vrc      Windows resource compiler script (styles + icons)
    *.vsf             VCL style files (FlatUILight, WedgewoodLight, Windows10ClearDay)
    *.pas / *.dfm     Form and unit source files
```

Build output goes to: `Epaswmm5\Build\Win32\`

---

## Prerequisites

### RAD Studio / Delphi 12 Athens (version 23.0)

The Community Edition is free and sufficient for building the 32-bit GUI. Download from [Embarcadero](https://www.embarcadero.com/products/delphi/starter).

**During installation, you must select the following components:**

| Component | Required | Notes |
|-----------|----------|-------|
| Delphi language | Yes | Core compiler |
| Windows platform | Yes | Required target |
| TeeChart Standard | **Yes — critical** | If omitted, build fails with `Required package 'Tee' not found` |
| DUnit | No | Test framework, not needed |
| InterBase Express | No | Database component, not needed |
| InterBase 2020 Developer Edition | No | Large download, not needed |

> **Community Edition only supports Windows 32-bit.** The 64-bit target will be greyed out. Do not attempt a 64-bit build.

---

## Step 1: Build the EPA Components Package

The main SWMM project depends on a custom Delphi component package that must be built and registered first.

### 1.1 Open the Components project

1. Launch RAD Studio.
2. **File > Open Project** → navigate to `Components/Epa.dproj` → Open.

### 1.2 Configure output directories

1. **Project > Options > Delphi Compiler**
2. Set the following three output paths (create the `Components/Win32/` folder first if it does not exist):

| Setting | Value |
|---------|-------|
| Package output directory | `Components/Win32/` |
| Unit output directory | `Components/Win32/` |
| DCP output directory | `Components/Win32/` |

> **Why redirect the DCP output?** The default DCP output path (`C:\Users\Public\Documents\Embarcadero\Studio\23.0\Dcp\`) may silently reject writes even for the current user due to Windows folder ownership quirks. Setting it to a local project folder avoids this.

### 1.3 Build the package

**Project > Build Epa**

#### Known issue: `hpp\Win32` directory missing

**Error:** `[MakeDir Error] Unable to create directory "C:\Users\Public\Documents\Embarcadero\Studio\23.0\hpp\Win32\"`

**Fix:** Create the directory manually in an elevated terminal:

```
mkdir "C:\Users\Public\Documents\Embarcadero\Studio\23.0\hpp\Win32"
```

Then retry the build.

---

## Step 2: Register the Component Package

After a successful build, install the package into the RAD Studio IDE so it appears on the component palette.

1. **Component > Install Packages** (not "Install Component" — that dialog is for individual unit files, not packages).
2. Click **Add**.
3. Navigate to `Components/Win32/` → select `epa.bpl` → **Open** → **OK**.

The EPA Components package will now appear in the installed packages list.

---

## Step 3: Add Components Folder to the Library Path

The main project needs to locate the component units at compile time.

1. **Tools > Options > Language > Delphi > Library**
2. Set **Selected Platform** to `Windows 32-bit`.
3. Click the `...` button next to **Library path**.
4. In the text box at the bottom of the path editor, type the full absolute path to the `Components/` folder.
5. Click **Add** (the Add button is only enabled after you type in the text box).
6. Click **OK** → **Save**.

---

## Step 4: Install the Required VCL Styles

The main project's `Epaswmm5.vrc` resource script references three VCL style files that are not included with the default RAD Studio installation:

- `FlatUILight.vsf`
- `WedgewoodLight.vsf`
- `Windows10ClearDay.vsf`

These files are already present in the `Epaswmm5/` folder (they are checked into the repository). If they are missing for any reason, follow the steps below to reinstall them from GetIt.

### 4.1 Install from GetIt Package Manager

1. **Tools > GetIt Package Manager**
2. Search for and install each of the following (by Embarcadero Technologies):
   - `VCL Style - FlatUILight`
   - `VCL Style - WedgewoodLight` — install the **VCL** version, not FMX
   - `VCL Style - Windows10ClearDay`

### 4.2 Copy .vsf files into the project folder

GetIt installs style files into the CatalogRepository under your documents folder, not into the system Styles directory. After installing, copy the three files:

| Copy from | Copy to |
|-----------|---------|
| `OneDrive\Documents\Embarcadero\Studio\23.0\CatalogRepository\VCLStyle-FlatUILight-2.0\FlatUILight.vsf` | `Epaswmm5\` |
| `OneDrive\Documents\Embarcadero\Studio\23.0\CatalogRepository\VCLStyle-WedgewoodLight-2.0\WedgewoodLight.vsf` | `Epaswmm5\` |
| `OneDrive\Documents\Embarcadero\Studio\23.0\CatalogRepository\VCLStyle-Windows10ClearDay-2.0\Windows10ClearDay.vsf` | `Epaswmm5\` |

> The `.vrc` file references the styles by local filename (no path prefix), so the files must live in the same folder as `Epaswmm5.dproj`.

---

## Step 5: Build the Main Project

1. **File > Open Project** → navigate to `Epaswmm5/Epaswmm5.dproj` → Open.
2. Confirm **Windows 32-bit** is the active target platform (shown in the toolbar dropdown or Projects panel).
3. **Project > Build Epaswmm5**

Build output appears in `Epaswmm5\Build\Win32\`.

### Known issue: Bad unit format (x86 vs x64 mismatch)

**Error:** `[dcc32 Fatal Error] F2048 Bad unit format: 'Dabout.dcu' - Expected version: 36.0, Windows Unicode(x86) Found version: 36.0, Windows Unicode(x64)`

**Cause:** Stale `.dcu` files compiled for 64-bit remain in the project folder (this happens if you accidentally triggered a 64-bit build attempt).

**Fix:** Delete all `.dcu` files in the `Epaswmm5/` folder, then rebuild:

```powershell
Remove-Item "Epaswmm5\*.dcu"
```

### Known issue: MakeDir errors for Win64 directories

Community Edition does not support 64-bit targets. If you see errors about missing `Win64` directories, verify the active platform is `Windows 32-bit` and ignore any Win64-related warnings.

---

## Running the Application

The built `Epaswmm5.exe` requires two runtime files in the same directory as the executable:

| File | Description |
|------|-------------|
| `swmm5.dll` | SWMM simulation engine (32-bit) |
| `runswmm.exe` | Engine launcher helper |

These files are located in `Epaswmm5/bin/` in this repository. **After building, manually copy them into the build output folder** (`Epaswmm5/Build/Win32/`):

```
copy Epaswmm5\bin\swmm5.dll Epaswmm5\Build\Win32\
copy Epaswmm5\bin\runswmm.exe Epaswmm5\Build\Win32\
```

> A post-build event exists in `Epaswmm5.dproj` that attempts to copy these files automatically, but it may not fire correctly depending on RAD Studio version and platform. If the application fails to launch, copy the files manually as shown above.

Verify that `swmm5.dll` is a **32-bit** DLL — a 64-bit DLL will cause error `0xc000007b` on launch.

### Verify DLL bitness (PowerShell)

Write the following to a `.ps1` file and run it with `powershell -ExecutionPolicy Bypass -File check_dll.ps1`:

```powershell
$path = 'C:\Projects\Swmm5.2\Swmm5.2.4\GUI\Win32\swmm5.dll'
$bytes = [System.IO.File]::ReadAllBytes($path)
$pe = [BitConverter]::ToInt32($bytes, 0x3C)
$machine = [BitConverter]::ToUInt16($bytes, $pe + 4)
if ($machine -eq 0x8664) { '64-bit' } elseif ($machine -eq 0x14c) { '32-bit' } else { 'Unknown' }
```

---

## EPA Custom Components Reference

The `Components/` package provides these custom VCL controls:

| Component | Source file | Description |
|-----------|-------------|-------------|
| `OpenTxtFileDialog` | `OpenDlg.pas` | Standard Open File dialog with text file preview |
| `NumEdit` | `NumEdit.pas` | Text box limited to valid numerical values |
| `PageSetupDialog` | `PgSetup.pas` | Printer and page setup dialog (orientation, margins, headers/footers) |
| `VirtualListBox` | `VirtList.pas` | Listbox supporting an unlimited number of items |
| `PrintControl` | `Xprinter.pas` | Non-visual print control for text, tables, and graphics with preview |

---

## Notes for Future Delphi Versions

If you upgrade to a newer RAD Studio version (Delphi 13 or later):

- The version number `23.0` appears in many system paths — update it to match the new version.
- TeeChart Standard may or may not be bundled — if the build fails with `Required package 'Tee' not found`, reinstall RAD Studio and select TeeChart Standard during installation.
- The three VCL styles (FlatUILight, WedgewoodLight, Windows10ClearDay) may be bundled in newer versions. Check `C:\Users\Public\Documents\Embarcadero\Studio\[version]\Styles\` before reinstalling from GetIt.
- The `Epaswmm5.vrc` may need path updates if the style files move.
- Community Edition has always been 32-bit only. For 64-bit builds, a Professional or Enterprise license is required.

---

## Notes for AI Agents

- **There is no command-line build path.** This project requires an interactive RAD Studio IDE session. Automated CI pipelines are not feasible without a licensed RAD Studio install.
- **Write permission issues in Public\Documents are silent.** The folder `C:\Users\Public\Documents\Embarcadero\Studio\23.0\` may appear accessible but reject file writes. Always redirect all output directories (DCP, BPL, DCU) to a local project subfolder.
- **PowerShell execution policy.** By default, PowerShell blocks unsigned scripts. Always run `.ps1` files with `powershell -ExecutionPolicy Bypass -File script.ps1`.
- **Do not interpolate PowerShell commands in bash strings.** The bash shell (Git Bash / WSL) interpolates `$` characters. Write PowerShell logic to a `.ps1` file and invoke it rather than passing inline PowerShell to `powershell -Command`.
- **`Epaswmm5.vrc` is a Windows Resource Compiler script.** Backslashes in path strings inside this file must be doubled (`\\`). The `.vrc` file is compiled into `.res` during the build and may disappear from disk afterward — this is expected behavior.
- **The 64-bit target is greyed out in Community Edition.** Do not attempt to activate or build for Win64. Any errors referencing Win64 directories can be ignored.
- **Stale `.dcu` files cause cryptic errors.** If you see bad unit format errors, delete all `.dcu` files in `Epaswmm5/` and rebuild clean.
