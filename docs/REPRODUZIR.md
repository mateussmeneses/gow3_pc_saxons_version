# Reproduzir: fork com cheats e resolução no dump deslocado

Guia para reconstruir, do zero, a sua versão do port rodando no seu dump
(CUSA01623 01.02, sha256 `6e72330e…`, um build com o código deslocado em
relação ao de referência). Ao final: Very Hard e os outros cheats, barra de
vida e resolução 480p/720p funcionando.

Caminhos usados aqui (ajuste se os seus forem outros):

- Fork: `C:\projetos\fork\gow3_pc_saxons_version`
- Dump do jogo: `C:\Users\Mateus\Downloads\games\CUSA01623` (tem `eboot.bin`,
  `sce_sys`, `sce_module`)

---

## 1. Instalar o MSYS2 e a toolchain (uma vez só)

1. Instale o MSYS2:

   ```powershell
   winget install MSYS2.MSYS2
   ```

2. Abra o atalho **MSYS2 CLANG64** (não o "MSYS2 MSYS" nem o "UCRT64"). Instale
   a toolchain e as bibliotecas:

   ```bash
   pacman -S --needed git patch \
     mingw-w64-clang-x86_64-{toolchain,cmake,ninja,pkgconf,python} \
     mingw-w64-clang-x86_64-{vulkan-headers,vulkan-loader,vulkan-memory-allocator,glslang} \
     mingw-w64-clang-x86_64-{sdl3,fmt,boost,robin-map,xxhash,ffmpeg,zydis} \
     mingw-w64-clang-x86_64-{spirv-tools,spirv-headers,spirv-cross}
   ```

   Quando ele listar os membros do grupo `toolchain`, aperte **Enter** (instala
   todos) e confirme com **Y** nas perguntas seguintes.

3. Confira que a toolchain respondeu:

   ```bash
   clang --version && cmake --version && ninja --version && pkg-config --version
   ```

---

## 2. Buildar o fork (no shell MSYS2 CLANG64)

```bash
cd /c/projetos/fork/gow3_pc_saxons_version
git submodule update --init --recursive
bash build.sh
```

O `build.sh` compila o shadPS4 inteiro: é **demorado** (vários minutos) e
escreve o progresso em `out/gpu-build.log` (o terminal fica quieto). Espere
terminar com:

```
Built C:/projetos/fork/gow3_pc_saxons_version/out/gow3-probe.exe
```

Se quiser acompanhar o progresso, em outro shell CLANG64:

```bash
tail -f /c/projetos/fork/gow3_pc_saxons_version/out/gpu-build.log
```

> Rebuild rápido depois de mexer no código (só o que mudou):
> ```bash
> ninja -C out/gpu gow3-probe
> cp out/gpu/gow3-probe.exe out/gow3-probe.exe
> ```

---

## 3. Rodar com o launcher (uso normal)

No PowerShell, na pasta do fork:

```powershell
$env:GOW3_GAME_DIR = 'C:\Users\Mateus\Downloads\games\CUSA01623'
python launcher/gow3_launcher_win.py
```

Na página **Game**, escolha a pasta do jogo. Em **Home / Performance**, ajuste:

- **Render resolution:** `native`, `480p` ou `720p` (ver limitações abaixo).
- **Engine FPS:** deixe em `60` por enquanto (ver limitações).
- **Display mode:** `windowed` para a sua tela 16:10 (1920x1200) sem distorção.

Clique em **PLAY**. Com o menu in-game (tecla **Insert**, ou **R3+L2** no
controle), aba **Game**, ative **Unlock Very Hard** antes de abrir uma partida
nova.

---

## 4. Rodar sem o launcher (para teste rápido / depuração)

O `run.py` usa o `gow3.ini` apontado por `GOW3_CONFIG`. Importante: grave o ini
**sem BOM** (o `Set-Content -Encoding utf8` do PowerShell adiciona BOM e quebra
a leitura da primeira linha). Use `WriteAllText` com UTF8 sem BOM:

```powershell
$fork = 'C:\projetos\fork\gow3_pc_saxons_version'
$ini  = "$fork\out\meu_gow3.ini"
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
$env:GOW3_TIMEOUT  = '12'      # fecha sozinho após 12 s (remova para jogar)

python "$fork\run.py" *> "$fork\out\meu_run.log"
```

Depois leia o log **em outro comando** (capturar e ler na mesma linha do
PowerShell dá log vazio):

```powershell
Get-Content "$fork\out\meu_run.log" |
  Select-String 'Cheats:|Health display|^Patches:|presenter ready|VideoOut'
```

---

## 5. O que você deve ver no log (critério de sucesso)

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

`ready` (não `unavailable`) em cada cheat = funcionando. `N writes applied`
com N>0 = resolução/patches aplicados.

---

## 6. Limitações conhecidas neste dump

- **480p e 720p funcionam.** 1440p/1800p/4K ainda **não**: um endereço de
  escrita (`0x60953d`) é ambíguo e precisa de disassembly para relocar com
  segurança. Escolher 1440p/1800p/4K cai para nativo com um aviso no log
  (`Resolution Patch - … skipped on this dump`), sem travar.
- **Patch de 120/240 FPS ainda não** neste dump: o `lea` dele tem um
  deslocamento relativo embutido que um shift simples de endereço não corrige.
  Use `engine_fps=60`.
- **Multiplicadores de orbs verde/azul/dourado e red orbs** ficam desativados
  (assinatura composta deslocada). Os **cheats** de orbs e o multiplicador de
  **dano** funcionam.

Esses pontos aparecem no log como `skipped`/`unavailable` — nunca corrompem.

---

## 7. Empacotar a sua release

No shell MSYS2 CLANG64:

```bash
cd /c/projetos/fork/gow3_pc_saxons_version
bash build.sh
bash packaging/windows/package.sh
```

Saída em `dist/gow3-windows/` e no `.zip`: `God of War III.exe` + DLLs, pronto
para distribuir. (Nenhum arquivo do jogo é incluído.)

---

## 8. Estender para 4K e FPS (opcional, futuro)

As ferramentas de medição estão em `tools/`:

- `tools/vaddr_bytes.py <eboot.elf> <ps4_vaddr> [n]` — lê bytes num endereço
  PS4 mapeando os dois segmentos (código e dados) corretamente.
- `tools/vaddr_bytes.py <eboot.elf> --scan <hex>` — procura bytes e reporta o
  vaddr.
- `tools/scan_sig.py`, `tools/elf_map.py`, `tools/measure_offsets.py`,
  `tools/find_originals.py` — medem deltas de hooks/patches.

O `eboot.elf` preparado fica em `out/eboot.elf` depois de uma execução. Para
suportar 4K: medir o site `0x60953d` por disassembly e adicionar a região (com
o delta correto) em `PATCH_PROFILES` dentro de `scripts/patches.py`. Para o
FPS: recalcular o `disp32` do `lea` em `0x48ff1a` e escrevê-lo relocado.
