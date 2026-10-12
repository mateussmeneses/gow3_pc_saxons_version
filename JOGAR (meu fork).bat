@echo off
rem ============================================================================
rem  Abre o launcher do SEU fork, apontando para o seu dump.
rem  Duplo-clique neste arquivo. Nada precisa ser compilado: o gow3-probe.exe
rem  ja esta em out\. Na janela do launcher, clique PLAY.
rem
rem  No jogo: tecla Insert (ou R3+L2 no controle) abre o menu -> aba Game ->
rem  ative "Unlock Very Hard" ANTES de iniciar uma partida nova.
rem ============================================================================

setlocal
cd /d "%~dp0"

rem Pasta do seu dump (tem eboot.bin, sce_sys, sce_module). Ajuste se mudar.
set "GOW3_GAME_DIR=C:\Users\Mateus\Downloads\games\CUSA01623"

rem Usa o probe recem-compilado em out\ (nao procura em bin\).
set "GOW3_PROBE=%~dp0out\gow3-probe.exe"

rem DLLs do MSYS2 CLANG64 que o probe precisa em runtime.
set "PATH=C:\msys64\clang64\bin;%PATH%"

python "%~dp0launcher\gow3_launcher_win.py"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo Launcher saiu com codigo %RC%. Se a janela nem abriu, rode este .bat
  echo por um terminal para ver a mensagem de erro.
  pause
)
endlocal
