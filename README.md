# Sistema de Gestión Comercial Zimbra

Aplicación web académica para registrar prospectos, darles seguimiento comercial y consultar la actividad de ventas. Está inspirada en el caso de estudio de Zimbra. No replica el software original ni su arquitectura interna.

<p>
  <img alt="React" src="https://img.shields.io/badge/React-19-149ECA?logo=react&logoColor=white" />
  <img alt="Vite" src="https://img.shields.io/badge/Vite-8-646CFF?logo=vite&logoColor=white" />
  <img alt="Express" src="https://img.shields.io/badge/Express-5-000000?logo=express&logoColor=white" />
  <img alt="MySQL" src="https://img.shields.io/badge/MySQL-local-4479A1?logo=mysql&logoColor=white" />
</p>

## Estado actual

React y Express se comunican en local. La pantalla inicial consulta `GET /api/estado` y `GET /api/db`.

El backend ya tiene la arquitectura en capas (rutas → controladores → modelos) y los 39 modelos del esquema están generados y validados contra la base de datos. El frontend aún consume solo los endpoints de estado y la lectura de clientes.

## Estructura general

```text
zimbra/
├── frontend/                 React + Vite
│   └── src/
│       ├── services/api.js   Llamadas al backend
│       ├── App.jsx
│       └── main.jsx
├── backend/                  API REST
│   ├── src/                  Ver detalle en "Estructura del backend"
│   ├── scripts/              Herramientas de mantenimiento
│   ├── .env                  Puerto y credenciales locales (no se sube a Git)
│   └── .env.example
├── run.bat                   Levanta frontend y backend a la vez
├── zimbra.sql                Esquema de la base de datos (39 tablas)
├── seed_datos_prueba.sql     Datos de prueba
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

---

# Estructura del backend

```text
backend/src/
├── server.js                 Arranque del proceso
├── app.js                    Ensamble de la aplicación Express
├── config/
│   ├── env.js                Carga y validación de variables
│   └── database.js           Pool de conexiones MySQL
├── routes/
│   ├── index.js              Registro de todas las rutas
│   ├── health.routes.js      Estado del servicio y de la BD
│   └── cliente.routes.js     Rutas de clientes
├── controllers/
│   ├── health.controller.js
│   └── cliente.controller.js
├── models/
│   ├── base.model.js         Fábrica de modelos CRUD
│   └── *.model.js            Un archivo por dominio
├── middlewares/
│   ├── notFound.js           404 para rutas inexistentes
│   └── errorHandler.js       Error centralizado
└── utils/
    └── ApiError.js           Error con código HTTP
```

El flujo de una petición es siempre el mismo:

```text
Petición HTTP → routes (define la URL) → controller (arma la respuesta)
              → model (habla con MySQL) → config/database.js (pool)
```

## server.js

Punto de entrada. Lee el puerto del `.env`, arranca el servidor y al iniciar comprueba la conexión con MySQL. También registra el apagado ordenado: al recibir `SIGINT` o `SIGTERM` (Ctrl+C) cierra el servidor HTTP y después el pool de conexiones, para no dejar conexiones colgando.

No contiene lógica de negocio. Si algo cambia en cómo se expone el servicio, se cambia aquí.

## app.js

Ensamble de la aplicación. Solo hace tres cosas:

1. Registra los middlewares globales: `cors` (acepta `http://localhost:5173`) y `express.json` (lee cuerpos JSON).
2. Monta `apiRouter` desde `routes/index.js`.
3. Cierra con `notFound` y `errorHandler`, que van al final a propósito.

Regla: aquí no se escribe ninguna ruta de negocio. Todo recurso nuevo se agrega en `routes/index.js`.

## config/env.js

Ejecuta `dotenv.config()` y revisa que existan `PORT`, `DB_HOST`, `DB_NAME`, `DB_USER` y `DB_PASSWORD`. Si falta alguna, imprime un aviso en consola.

Este archivo se importa primero (antes que `database.js`), porque si no, las variables llegan vacías y el pool se crea con credenciales incorrectas.

## config/database.js

Crea el pool de conexiones con `mysql2/promise` usando las variables del `.env`. Exporta cuatro cosas:

- `pool` (default): lo usan los modelos para ejecutar consultas.
- `comprobarConexion()`: ejecuta `SELECT 1` y confirma que MySQL responde.
- `listarTablas()`: devuelve `SHOW TABLES`, usada por la raíz de la API.
- `cerrarPool()`: cierra las conexiones al apagar el servidor.

Es el único archivo del proyecto que toca `mysql.createPool`.

## routes/

Define **qué URL existe y qué controlador la atiende**. Nada más: no consulta la base de datos ni arma respuestas.

- `index.js`: punto de entrada de la API. Aquí se declaran los prefijos y se montan los routers de cada recurso. Es el único archivo que conoce todas las rutas.
- `health.routes.js`: `/`, `/estado` y `/db` (diagnóstico).
- `cliente.routes.js`: `GET /` y `GET /:id`.

Para agregar un recurso nuevo: crear `nombre.routes.js`, importar el controlador, declarar sus verbos y montarlo en `index.js` con su prefijo.

## controllers/

Capa que traduce la petición HTTP a una respuesta HTTP. Recibe `req`, extrae parámetros, llama al modelo y responde JSON.

- No escribe SQL.
- No decide estados HTTP de error manualmente: lanza `ApiError` (por ejemplo 404) y el middleware de errores responde.
- Usa funciones `async` directamente: Express 5 captura las promesas rechazadas y las manda al manejador de errores, por eso no se necesita `try/catch` en cada controlador.

`health.controller.js` tiene `estado`, `estadoBaseDatos` y `estadoGeneral`. `cliente.controller.js` tiene `listarClientes` y `obtenerCliente`.

## models/

Única capa que conoce SQL. Cada modelo representa una tabla y expone sus consultas.

### base.model.js

Fábrica para no repetir el mismo CRUD 39 veces. Exporta dos funciones:

`crearModelo(tabla, columnaId, campos)` — para tablas con clave primaria simple. Devuelve un objeto con:

- `obtenerTodos({ limite, offset })`: lista con paginación opcional.
- `obtenerPorId(id)`: un registro o `null`.
- `obtenerPor(campo, valor, { limite, offset })`: filtra por una columna declarada (por ejemplo, contactos de un cliente).
- `contar()`: total de filas.
- `crear(datos)`: inserta y devuelve el registro creado.
- `actualizar(id, datos)`: actualiza solo los campos enviados; si no hay ninguno, devuelve el registro sin cambios.
- `eliminar(id)`: devuelve `true` si borró algo.

`crearModeloRelacion(tabla, claves, campos)` — para tablas puente con clave primaria compuesta. Devuelve:

- `obtenerTodos()`
- `obtenerPorClave({ ... })`
- `listarPor(campo, valor)`
- `crear(datos)`
- `eliminar({ ... })`
- `existe({ ... })`

**Seguridad en las consultas.** Los valores siempre van parametrizados con `?`. Los nombres de tabla y columna vienen del código (nunca del request) y se validan con la expresión regular `^[a-z][a-z0-9_]*$` antes de interpolarlos. `obtenerPor` y `listarPor` además solo aceptan columnas declaradas en el modelo, así que un atacante no puede filtrar por una columna arbitraria.

### Modelos por dominio

Los archivos agrupan tablas relacionadas. Cada uno exporta objetos con el nombre del modelo:

| Archivo | Modelos |
| --- | --- |
| `usuario.model.js` | Usuario, Rol, Permiso, UsuarioRol, RolPermiso |
| `cliente.model.js` | Cliente, Contacto, CategoriaCliente, ClienteCategoria |
| `vendedor.model.js` | Vendedor, AsignacionCliente |
| `oportunidad.model.js` | EtapaVenta, Oportunidad, OportunidadDetalle, Seguimiento, Tarea |
| `campana.model.js` | Campana, CampanaCliente, CampanaInteraccion |
| `producto.model.js` | CategoriaProducto, Producto, ProductoDetalle, ProductoCategoria |
| `propuesta.model.js` | Propuesta, PropuestaDetalle |
| `venta.model.js` | Venta, VentaProducto, Pago |
| `actividad.model.js` | ActividadWeb, Notificacion |
| `compania.model.js` | Compania |
| `evento.model.js` | Evento |
| `etiqueta.model.js` | Etiqueta, ContactoEtiqueta |
| `correo.model.js` | Correo, CorreoDestinatario |
| `reporte.model.js` | Reporte, Auditoria |
| `configuracion.model.js` | ConfiguracionUsuario |

Las tablas puente (`usuarios_roles`, `roles_permisos`, `clientes_categorias`, `campanas_clientes`, `productos_categorias`, `contactos_etiquetas`) usan `crearModeloRelacion`.

Nota sobre `cliente.model.js`: además de exportar `Cliente`, reexporta sus funciones de forma directa (`obtenerTodos`, `obtenerPorId`, etc.) para que el controlador existente funcione sin cambios.

Ejemplo de uso:

```js
import { Cliente, Contacto } from '../models/cliente.model.js'

const clientes = await Cliente.obtenerTodos({ limite: 20 })
const contactos = await Contacto.obtenerPor('id_cliente', 1)
const nuevo = await Cliente.crear({ tipo_cliente: 'persona', nombre: 'Ana' })
```

## middlewares/

- `notFound.js`: va después de todas las rutas. Responde `404` con la ruta pedida, para que el cliente no reciba el HTML por defecto de Express.
- `errorHandler.js`: va de último. Toma el código de `ApiError` si existe, si no usa `500`. Solo imprime el error en consola cuando es `500` o más, y nunca devuelve la traza al cliente.

## utils/

- `ApiError.js`: clase de error con un campo `estado`. Se usa así: `throw new ApiError(404, 'Cliente no encontrado')`. El manejador de errores lo convierte en la respuesta JSON.

## scripts/

- `verificar_modelos.mjs`: conecta a la base de datos, compara cada modelo declarado contra `information_schema.COLUMNS` y reporta tablas sin modelo, tablas inexistentes y columnas inexistentes. Se ejecuta con:

```powershell
cd backend
npm run db:check
```

Es útil después de modificar `zimbra.sql`: si agregas una tabla, el script te dice que falta su modelo.

---

# Cómo arrancar el proyecto

## Instalación

En PowerShell:

```powershell
cd C:\Users\joseo\OneDrive\Escritorio\zimbra\backend
npm install

cd C:\Users\joseo\OneDrive\Escritorio\zimbra\frontend
npm install
```

En `backend`, copia `.env.example` como `.env` y escribe el usuario y la contraseña de MySQL. El archivo de ejemplo ya trae el puerto `3001`, el host `localhost` y la base `zimbra`.

Crea la base de datos e importa los datos:

```powershell
mysql -u root -p < zimbra.sql
mysql -u root -p zimbra < seed_datos_prueba.sql
```

## Puesta en marcha

La forma más corta es doble clic en `run.bat` (o desde la raíz):

```powershell
.\run.bat
```

Abre dos ventanas tituladas `Zimbra Frontend` y `Zimbra Backend`, e instala `node_modules` si falta.

También se puede hacer manual, en dos terminales:

```powershell
cd backend
npm run dev
```

```powershell
cd frontend
npm run dev
```

Debes ver `Backend escuchando en http://localhost:3001`. Abre `http://localhost:5173`. Si la conexión funciona, la página muestra: **El backend de Zimbra está funcionando**.

## Scripts disponibles

Backend:

```powershell
npm run dev       # nodemon, reinicia solo al guardar
npm start         # node, modo producción
npm run db:check  # valida los modelos contra la base de datos
```

Frontend:

```powershell
npm run dev       # Vite en http://localhost:5173
npm run build     # compilación de producción
npm run preview   # sirve el build
npm run lint      # ESLint
```

---

# Endpoints de la API

| Método | Ruta | Descripción |
| --- | --- | --- |
| GET | `/` | Comprueba la conexión y lista las tablas de la BD |
| GET | `/api/estado` | Estado del backend |
| GET | `/api/db` | Comprueba la conexión con MySQL |
| GET | `/api/clients` | Lista de clientes (alias por compatibilidad) |
| GET | `/api/clientes` | Lista de clientes, con `total` |
| GET | `/api/clientes/:id` | Un cliente por id |

Formato de respuesta:

```json
{ "ok": true, "total": 8, "clientes": [ ... ] }
```

Errores:

```json
{ "ok": false, "mensaje": "Cliente no encontrado" }
```

## Comprobación directa

Con el backend encendido, en otra terminal:

```powershell
Invoke-RestMethod http://localhost:3001/api/estado
Invoke-RestMethod http://localhost:3001/api/clientes
```

---

# Cómo agregar un recurso nuevo

Ejemplo con productos.

1. **Modelo** (ya existe): `models/producto.model.js` exporta `Producto`.
2. **Controlador**: crea `controllers/producto.controller.js`:

```js
import { Producto } from '../models/producto.model.js'
import ApiError from '../utils/ApiError.js'

export async function listarProductos(req, res) {
  const productos = await Producto.obtenerTodos()
  res.json({ ok: true, productos })
}

export async function obtenerProducto(req, res) {
  const producto = await Producto.obtenerPorId(req.params.id)
  if (!producto) throw new ApiError(404, 'Producto no encontrado')
  res.json({ ok: true, producto })
}

export async function crearProducto(req, res) {
  const producto = await Producto.crear(req.body)
  res.status(201).json({ ok: true, producto })
}
```

3. **Rutas**: crea `routes/producto.routes.js`:

```js
import { Router } from 'express'
import * as productoController from '../controllers/producto.controller.js'

const router = Router()

router.get('/', productoController.listarProductos)
router.get('/:id', productoController.obtenerProducto)
router.post('/', productoController.crearProducto)

export default router
```

4. **Registro**: en `routes/index.js`:

```js
import productoRouter from './producto.routes.js'

router.use('/api/productos', productoRouter)
```

5. **Verifica** con `npm run dev` y `Invoke-RestMethod http://localhost:3001/api/productos`.

Si agregaste una tabla nueva a `zimbra.sql`, ejecuta también `npm run db:check` para confirmar que el modelo coincide con el esquema.
