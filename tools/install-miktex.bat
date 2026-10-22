@echo off
rem Instala pgf-go en MiKTeX para usarlo con \usepackage{pgf-go}.
rem Copia los modulos (latex\*.sty), los archivos Lua (latex\*.lua) y las imagenes de los perfiles
rem (img\pgfgo-*) a <UserData>\tex\latex\pgf-go y actualiza la base de nombres de MiKTeX.
rem Con un argumento, instala en esa raiz en lugar de UserData (por ejemplo, para probar).
setlocal

set "SRC=%~dp0.."

if "%~1"=="" (
	for /f "tokens=1,*" %%a in ('initexmf --report ^| findstr /b "UserData:"') do set "ROOT=%%b"
) else (
	set "ROOT=%~1"
)
if not defined ROOT (
	echo No se encontro la carpeta UserData de MiKTeX ^(initexmf --report^).
	exit /b 1
)
set "DEST=%ROOT%\tex\latex\pgf-go"

rem Una copia anterior en la carpeta de instalacion de MiKTeX taparia a esta.
if "%~1"=="" (
	for /f "tokens=1,*" %%a in ('initexmf --report ^| findstr /b "UserInstall:"') do (
		if exist "%%b\tex\latex\pgf-go" (
			echo Borrando la copia anterior: %%b\tex\latex\pgf-go
			rd /s /q "%%b\tex\latex\pgf-go"
		)
	)
)

rem La carpeta se vacia antes de copiar: no quedan modulos que ya no existen.
if exist "%DEST%" rd /s /q "%DEST%"
mkdir "%DEST%" || exit /b 1
copy /y "%SRC%\latex\*.sty" "%DEST%" >nul || exit /b 1
copy /y "%SRC%\latex\*.lua" "%DEST%" >nul || exit /b 1
copy /y "%SRC%\img\pgfgo-*" "%DEST%" >nul || exit /b 1
echo pgf-go instalado en %DEST%

if "%~1"=="" (
	initexmf --update-fndb
	echo.
	echo pgf-go.sty se encuentra en:
	kpsewhich pgf-go.sty
	kpsewhich pgfgo-board.jpg
)
endlocal
