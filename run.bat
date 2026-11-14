@echo off
echo Iniciando entorno de desarrollo...

cmd /k "cd frontend && npm run dev"

start cmd /k "cd backend && npm run dev"

echo Servidores ejecutandose.