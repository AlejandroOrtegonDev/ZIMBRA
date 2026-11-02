<<<<<<< HEAD
# Sistema de Gestión Comercial Zimbra

Aplicación web académica para registrar prospectos, darles seguimiento comercial y consultar la actividad de ventas. Está inspirada en el caso de estudio de Zimbra. No replica el software original ni su arquitectura interna.

<p>
  <img alt="React" src="https://img.shields.io/badge/React-19-149ECA?logo=react&logoColor=white" />
  <img alt="Vite" src="https://img.shields.io/badge/Vite-8-646CFF?logo=vite&logoColor=white" />
  <img alt="Express" src="https://img.shields.io/badge/Express-5-000000?logo=express&logoColor=white" />
  <img alt="MySQL" src="https://img.shields.io/badge/MySQL-local-4479A1?logo=mysql&logoColor=white" />
</p>

## Estado actual

React y Express ya se comunican en local. La pantalla inicial consulta `GET /api/estado` y `GET /api/db`.

La segunda ruta abre un grupo de conexiones con MySQL y ejecuta `SELECT 1`. Las tablas de prospectos, vendedores y ventas todavía no existen.

## Estructura

```text
zimbra/
├── frontend/                 React + Vite
│   └── src/
│       ├── services/api.js   Llamadas al backend
│       ├── App.jsx
│       └── main.jsx
├── backend/                  API REST
│   ├── src/
│   │   ├── app.js
│   │   ├── server.js
│   │   └── routes/estado.routes.js
│   ├── .env                  Puerto local (no se sube a Git)
│   └── .env.example
├── PROYECTO_ZIMBRA.md
└── README.md
```

## Requisitos

- Windows 11
- [Node.js](https://nodejs.org/) 20 o superior (en este equipo se usó la versión 22)
- npm
- MySQL Server en local, con una base de datos llamada `zimbra`

## Dependencias

El backend usa:

- Express 5, para la API
- CORS, para aceptar peticiones desde React
- dotenv, para leer el archivo `.env`
- mysql2, para conectar con MySQL
- Nodemon, para reiniciar el servidor en desarrollo

El frontend usa:

- React 19 y React DOM
- Vite 8, para el servidor de desarrollo
- ESLint, para revisar el código

## Instalación

En PowerShell, instala los paquetes de cada carpeta:

```powershell
cd C:\Users\joseo\OneDrive\Escritorio\zimbra\backend
npm install

cd C:\Users\joseo\OneDrive\Escritorio\zimbra\frontend
npm install
```

En `backend`, copia `.env.example` como `.env` y escribe el usuario y la contraseña de MySQL. El archivo de ejemplo ya trae el puerto `3001`, el host `localhost` y la base `zimbra`.

## Puesta en marcha

Abre dos terminales de PowerShell.

**Terminal 1, desde la carpeta `backend`:**

```powershell
cd C:\Users\joseo\OneDrive\Escritorio\zimbra\backend
npm run dev
```

Debes ver: `Backend escuchando en http://localhost:3001`.

**Terminal 2, desde la carpeta `frontend`:**

```powershell
cd C:\Users\joseo\OneDrive\Escritorio\zimbra\frontend
npm run dev
```

Abre `http://localhost:5173`. Si la conexión funciona, la página muestra: **El backend de Zimbra está funcionando**.

## Comprobación directa de la API

Con el backend encendido, en otra terminal:

```powershell
Invoke-RestMethod http://localhost:3001/api/estado
```

La respuesta esperada es un objeto con `ok: true` y el mensaje del servidor.
=======
# ZIMBRA
>>>>>>> 63a21c946fa6fdf6d1d6b188be5ffda3e10a20ce
