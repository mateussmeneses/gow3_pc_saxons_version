# Reproduce: fork with cheats and resolution on a shifted dump

Guide to rebuild, from scratch, your version of the port running on your dump
(CUSA01623 01.02, sha256 `6e72330e…`, a build whose code is shifted relative to
the reference). The result: Very Hard and the other cheats, the enemy health
bar, and 480p/720p resolution working.

Paths used here (adjust to yours):

- Fork: `C:\projetos\fork\gow3_pc_saxons_version`
- Game dump: `C:\Users\Mateus\Downloads\games\CUSA01623` (has `eboot.bin`,
  `sce_sys`, `sce_module`)

---

## 1. Install MSYS2 and the toolchain (once)

1. Install MSYS2:

   ```powershell
   winget install MSYS2.MSYS2
   ```

2. Open the **MSYS2 CLANG64** shortcut (not "MSYS2 MSYS" nor "UCRT64"). Install
   the toolchain and the libraries:

   ```bash
   pacman -S --needed git patch \
     mingw-w64-clang-x86_64-{toolchain,cmake,ninja,pkgconf,python} \
     mingw-w64-clang-x86_64-{vulkan-headers,vulkan-loader,vulkan-memory-allocator,glslang} \
     mingw-w64-clang-x86_64-{sdl3,fmt,boost,robin-map,xxhash,ffmpeg,zydis} \
     mingw-w64-clang-x86_64-{spirv-tools,spirv-headers,spirv-cross}
   ```

   When it lists the `toolchain` group members, press **Enter** (installs all)
   and confirm with **Y** on the following prompts.

3. Check the toolchain responds:

   ```bash
   clang --version && cmake --version && ninja --version && pkg-config --version
   ```

---

## 2. Build the fork (in the MSYS2 CLANG64 shell)

```bash
cd /c/projetos/fork/gow3_pc_saxons_version
git submodule update --init --recursive
bash build.sh
```

`build.sh` compiles the whole shadPS4 core: it is **slow** (several minutes) and
writes progress to `out/gpu-build.log` (the terminal stays quiet). Wait for:

```
Built C:/projetos/fork/gow3_pc_saxons_version/out/gow3-probe.exe
```

To follow progress, in another CLANG64 shell:

```bash
tail -f /c/projetos/fork/gow3_pc_saxons_version/out/gpu-build.log
```

> Fast rebuild after editing the code (only what changed):
> ```bash
> ninja -C out/gpu gow3-probe
> cp out/gpu/gow3-probe.exe out/gow3-probe.exe
> ```

---

## 3. Run with the launcher (normal use)

In PowerShell, from the fork folder:

```powershell
$env:GOW3_GAME_DIR = 'C:\Users\Mateus\Downloads\games\CUSA01623'
python launcher/gow3_launcher_win.py
```

On the **Game** page, pick the game folder. On **Home / Performance**, set:

- **Render resolution:** `native`, `480p` or `720p` (see limitations below).
- **Engine FPS:** keep `60` for now (see limitations).
- **Display mode:** `windowed` for a 16:10 screen (1920x1200) without stretching.

Click **PLAY**. With the in-game menu (**Insert** key, or **R3+L2** on the
controller), **Game** tab, enable **Unlock Very Hard** before starting a new
game.

---

## 4. Run without the launcher (quick test / debugging)

`run.py` reads the `gow3.ini` pointed to by `GOW3_CONFIG`. Important: write the
ini **without a BOM** (PowerShell's `Set-Content -Encoding utf8` adds a BOM and
breaks the first line's parsing). Use `WriteAllText` with UTF8 no-BOM:

```powershell
$fork = 'C:\projetos\fork\gow3_pc_saxons_version'
$ini  = "$fork\out\my_gow3.ini"
$enc  = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($ini, @"
render_resolution=720p
engine_fps=60
display_mode=windowed
output_res=1920x1200
vsync=1
cheat_very_hard=1
"@, $enc)

$env:GOW3_GAME_DIR = 'C:\Users\Mateus\Downloads\games\CUSA01623'
$env:GOW3_PROBE    = "$fork\out\gow3-probe.exe"
$env:GOW3_CONFIG   = $ini
$env:GOW3_TIMEOUT  = '12'      # auto-closes after 12 s (remove to play)

python "$fork\run.py" *> "$fork\out\my_run.log"
```

Then read the log in a **separate** command (capturing and reading in the same
PowerShell line yields an empty log):

```powershell
Get-Content "$fork\out\my_run.log" |
  Select-String 'Cheats:|Health display|^Patches:|presenter ready|VideoOut'
```

---

## 5. What you should see in the log (success criteria)

```
Patches: recognized dump, relocating for shifted build (0x120/-0x10/-0x8 by region)
Patches: CUSA01623; 11 writes from ['Skip Any Video With X Button', 'Resolution Patch - 720p']
Patches: 11 writes, 42 bytes applied, 0 pointers rebased
Cheats: relocated for this build (code shifted by -16 bytes)
Cheats: Very Hard unlock ready (live toggle, initially disabled unless saved)
Cheats: infinite double jumps ready ...
Health display: damage hook ready (enemy health bar in the menu)
GPU: window and Vulkan presenter ready; ...
VideoOut: vblank 60 Hz, ...
```

`ready` (not `unavailable`) on each cheat = working. `N writes applied` with
N>0 = resolution/patches applied.

---

## 6. Known limitations on this dump

- **480p and 720p work.** 1440p/1800p/4K do **not** yet: one write address
  (`0x60953d`) is ambiguous and needs disassembly to relocate safely. Choosing
  1440p/1800p/4K falls back to native with a log warning
  (`Resolution Patch - … skipped on this dump`), without crashing.
- **120/240 FPS patch not yet** on this dump: its `lea` carries an embedded
  rip-relative displacement that a plain address shift cannot fix. Use
  `engine_fps=60`.
- **Green/blue/gold and red-orb multipliers** stay disabled (shifted composite
  signature). The orb **cheats** and the **damage** multiplier work.

These show up in the log as `skipped`/`unavailable` — they never corrupt the game.

---

## 7. Package your release

In the MSYS2 CLANG64 shell:

```bash
cd /c/projetos/fork/gow3_pc_saxons_version
bash build.sh
WINPYTHON="/c/Users/Mateus/AppData/Local/Python/pythoncore-3.14-64/python.exe" \
  bash packaging/windows/package.sh
```

(`WINPYTHON` points PyInstaller at a python.org interpreter; drop it if yours is
auto-detected under `C:\Python3*`.) Output goes to `dist/gow3-windows/` and the
`.zip`: `God of War III.exe` + DLLs, ready to distribute. (No game files are
included.)

---

## 8. Extend to 4K and FPS (optional, future)

The measurement tools are in `tools/`:

- `tools/vaddr_bytes.py <eboot.elf> <ps4_vaddr> [n]` — read bytes at a PS4
  address, mapping both segments (code and data) correctly.
- `tools/vaddr_bytes.py <eboot.elf> --scan <hex>` — scan for bytes and report
  the vaddr.
- `tools/scan_sig.py`, `tools/elf_map.py`, `tools/measure_offsets.py`,
  `tools/find_originals.py` — measure hook/patch deltas.

The prepared `eboot.elf` lands in `out/eboot.elf` after a run. To support 4K:
measure the `0x60953d` site by disassembly and add the region (with the correct
delta) to `PATCH_PROFILES` in `scripts/patches.py`. For FPS: recompute the
`disp32` of the `lea` at `0x48ff1a` and write it relocated.
