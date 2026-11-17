@echo off
setlocal enableextensions disabledelayedexpansion

rem ====================================================================
rem   Intrepid Parallel  --  Publish SITE
rem ====================================================================
rem   O site da Intrepid Parallel, na raiz do dominio:
rem   https://intrepidparallel.com/ (16 linguas; desde 15/11/2026).
rem   Desde 17/11/2026 vive neste repositorio, e ja nao na pasta raiz\ do
rem   repositorio da mBrothers (que fica como legado).
rem
rem   Este script:
rem     1. confere que esta no repositorio e no ramo certos;
rem     2. gera os dicionarios (tools\textos-raiz.py), as 15 paginas por
rem        idioma e o sitemap.xml (tools\gerar-raiz.py);
rem     3. publica o site no servidor (a porta de publicacao da Cobleza);
rem     4. faz o commit e o push para o GitHub;
rem     5. confere que o site responde.
rem
rem   A chave SSH de publicacao fica so no PC de quem publica, em
rem   %USERPROFILE%\.ssh\sites-publicar-intrepidparallel. No servidor ela so
rem   consegue publicar, voltar a versao anterior e listar as versoes:
rem     ssh -i <chave> sites@136.144.201.147 voltar raiz
rem     ssh -i <chave> sites@136.144.201.147 versoes raiz
rem
rem   O pacote faz-se com o tools\empacotar.py, e NAO com o tar do Windows:
rem   esse marcava as pastas como so de leitura (o OneDrive poe-lhes esse
rem   atributo) e o servidor nao conseguia escrever nelas (06/11/2026).
rem   O ssh vai pelo caminho inteiro. E corre-se no cmd, nao no PowerShell
rem   antigo, que estraga os bytes do pacote no "|".
rem ====================================================================

set "SITE_DIR=%~dp0"
set "URL=https://intrepidparallel.com/"
set "SERVIDOR=sites@136.144.201.147"
set "CHAVE=%USERPROFILE%\.ssh\sites-publicar-intrepidparallel"
set "SSH=%SystemRoot%\System32\OpenSSH\ssh.exe"
set "CURL=%SystemRoot%\System32\curl.exe"

echo.
echo ==========================================
echo   Intrepid Parallel  --  Publish SITE
echo ==========================================
echo.

cd /d "%SITE_DIR%"

rem -- 1. Repositorio, ramo e ferramentas -----------------------------
echo [1/5] A validar o repositorio...
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [ERRO] Esta pasta nao e um repositorio git.
    pause
    exit /b 1
)
set "REMOTE="
for /f "tokens=*" %%r in ('git remote get-url origin 2^>nul') do set "REMOTE=%%r"
echo       %REMOTE%
echo %REMOTE% | findstr /i "intrepidparallel" >nul
if errorlevel 1 (
    echo [ERRO] O remote nao parece ser o da Intrepid Parallel. Abortado por seguranca.
    pause
    exit /b 1
)
set "RAMO="
for /f "tokens=*" %%b in ('git branch --show-current 2^>nul') do set "RAMO=%%b"
if /i not "%RAMO%"=="main" (
    echo [ERRO] O ramo actual e "%RAMO%", e so se publica do main. Abortado.
    pause
    exit /b 1
)
if not exist "%CHAVE%" (
    echo [ERRO] Nao encontro a chave de publicacao em %CHAVE%.
    pause
    exit /b 1
)
if not exist "%SSH%" (
    echo [ERRO] Nao encontro o ssh do Windows em %SSH%.
    pause
    exit /b 1
)
echo       OK

rem -- 2. Os textos e as paginas por idioma ---------------------------
rem   Os dicionarios (i18n\) saem de tools\textos-raiz.py; as 15 pastas de
rem   lingua e o sitemap.xml saem de tools\gerar-raiz.py. Nunca se editam a
rem   mao. Se um falhar, nao se publica.
echo.
echo [2/5] A gerar o site, nas 16 linguas...
python -X utf8 "%SITE_DIR%tools\textos-raiz.py"
if errorlevel 1 (
    echo [ERRO] Os textos do site falharam. Abortado.
    pause
    exit /b 1
)
python -X utf8 "%SITE_DIR%tools\gerar-raiz.py"
if errorlevel 1 (
    echo [ERRO] O gerador do site falhou. Abortado.
    pause
    exit /b 1
)
echo       OK

rem -- 3. O site no servidor ------------------------------------------
rem   O pacote leva so o que esta na lista do tools\empacotar.py: fora ficam
rem   o .git, as ferramentas, os dicionarios, o email\ e o 404 do GitHub.
rem   As pastas vao com 755 e os ficheiros com 644.
echo.
echo [3/5] A publicar o site no servidor...
python "%SITE_DIR%tools\empacotar.py" | "%SSH%" -i "%CHAVE%" -o IdentitiesOnly=yes -o BatchMode=yes %SERVIDOR% publicar raiz
if errorlevel 1 (
    echo [ERRO] A publicacao no servidor falhou. Nada foi para o GitHub.
    pause
    exit /b 1
)
echo       OK

rem -- 4. Commit e push para o GitHub ---------------------------------
rem   O git add vai pelos caminhos (o repositorio e PUBLICO): o site, as
rem   ferramentas e este .cmd. A mensagem do commit nao se pergunta. Quem
rem   quiser outra passa-a como argumento:
rem     __publicar-site_IntrepidParallel.cmd "Os cartoes dos produtos"
set "MSG=Site: atualizacao"
if not "%~1"=="" set "MSG=%~1"
echo.
echo [4/5] GitHub: commit e push...
git status --short
git add index.html legal.html llms.txt og.png robots.txt sitemap.xml favicon.ico assets fonts i18n tools pt br es fr it de pl ru ar hi zh zh-tw ja ko .gitignore __publicar-site_IntrepidParallel.cmd
if errorlevel 1 (
    echo [ERRO] git add falhou. O site ja esta no servidor.
    pause
    exit /b 1
)
git commit -m "%MSG%"
if errorlevel 1 echo       (nada para commit)
git push origin main
if errorlevel 1 (
    echo [ERRO] git push falhou. O site ja esta no servidor. Verifica 'git status' e 'gh auth status'.
    pause
    exit /b 1
)
echo       OK

rem -- 5. Conferir ----------------------------------------------------
echo.
echo [5/5] A conferir o site...
rem   O curl vai sem aspas a volta do caminho: o caminho do System32 nao tem
rem   espacos, e um "for /f" com varias aspas perde a primeira e a ultima.
set "ESTADO="
for /f %%s in ('%CURL% -s -o NUL -w "%%{http_code}" %URL%') do set "ESTADO=%%s"
echo       %URL% respondeu %ESTADO%
if not "%ESTADO%"=="200" (
    echo [AVISO] Esperava 200. Para voltar a versao anterior:
    echo         "%SSH%" -i "%CHAVE%" %SERVIDOR% voltar raiz
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   Site publicado!
echo.
echo   %URL%
echo ==========================================
echo.
pause
exit /b 0
