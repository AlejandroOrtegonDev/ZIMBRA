@echo off
setlocal

set "ROOT=%~dp0"
cd /d "%ROOT%"

echo Iniciando entorno de desarrollo...

if not exist "frontend\node_modules" (
    echo Instalando dependencias del frontend...
    pushd frontend
    call npm install
    popd
)

if not exist "backend\node_modules" (
    echo Instalando dependencias del backend...
    pushd backend
    call npm install
    popd
)

start "Zimbra Frontend" cmd /k "cd /d "%ROOT%frontend" && npm run dev"
start "Zimbra Backend" cmd /k "cd /d "%ROOT%backend" && npm run dev"

echo Servidores ejecutandose.
echo Frontend: http://localhost:5173
echo Backend:  http://localhost:3001

endlocal
