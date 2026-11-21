# Sistema de Gestión Comercial Zimbra

Sistema transaccional académico (Taller Grupal – Caso Zimbra, *Sistemas Transaccionales en SQL*) que simula los procesos de **marketing y ventas**: prospectos, oportunidades, propuestas, ventas, pagos, campañas y reportes. Está inspirado en el caso de estudio de Zimbra; no replica el software original ni su arquitectura interna.

<p>
  <img alt="React" src="https://img.shields.io/badge/React-19-149ECA?logo=react&logoColor=white" />
  <img alt="Vite" src="https://img.shields.io/badge/Vite-8-646CFF?logo=vite&logoColor=white" />
  <img alt="Express" src="https://img.shields.io/badge/Express-5-000000?logo=express&logoColor=white" />
  <img alt="MySQL" src="https://img.shields.io/badge/MySQL-8.0.16+-4479A1?logo=mysql&logoColor=white" />
</p>

| Capa | Contenido |
| --- | --- |
| **Base de datos** (`zimbra.sql`) | 39 tablas, 47 llaves foráneas, 23 restricciones CHECK, 30+ registros por tabla, transacciones ACID con SAVEPOINT, simulación de errores, 39 triggers, 7 procedimientos, 8 funciones UDF, 1 evento, 10 vistas, 13 índices, 3 roles y 3 usuarios MySQL |
| **Backend** (`backend/`) | API REST Express 5 + mysql2, inicio de sesión con bcrypt y token firmado, permisos por rol, endpoints que llaman procedimientos, funciones y vistas |
| **Frontend** (`frontend/`) | React 19 + Vite: inicio de sesión y registro, tablero con gráficos, clientes, prospectos y seguimiento, propuestas, ventas y pagos, vendedores y reportes |

El cumplimiento punto por punto de la guía está en [`docs/cumplimiento-taller.md`](docs/cumplimiento-taller.md).

---

## 1. Requisitos

- Windows 10/11
- [Node.js](https://nodejs.org/) 20 o superior (probado con 24)
- MySQL Server **8.0.16 o superior** (las restricciones CHECK se aplican desde esa versión) y MySQL Workbench
- Un usuario MySQL con privilegios de administrador (por ejemplo `root`) **solo para cargar el script**

## 2. Instalación paso a paso (PowerShell)

### 2.1 Base de datos

> ⚠️ `zimbra.sql` **borra y recrea** la base `zimbra` y los usuarios MySQL `zimbra_app`, `zimbra_analista` y `zimbra_auditor`. Si tiene datos propios en una base llamada `zimbra`, respáldelos antes:
> `mysqldump -u root -p zimbra > respaldo_zimbra.sql`

Si `mysql` no está en el PATH, use la ruta completa del cliente:

```powershell
cd C:\ruta\del\proyecto
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p --default-character-set=utf8mb4 -e "source zimbra.sql"
```

O en **MySQL Workbench**: *File → Open SQL Script → zimbra.sql* y ejecutar todo (icono del rayo). El script desactiva por su cuenta el *safe updates* de Workbench.

Al final del script se ven las pruebas automáticas (`9.1` a `9.9`) y el conteo de objetos: 39 tablas, 10 vistas, 39 triggers, 7 procedimientos, 8 funciones, etc.

### 2.2 Backend

```powershell
cd backend
npm install
Copy-Item .env.example .env
```

El `.env` de ejemplo ya usa el usuario de mínimo privilegio que crea el script (`zimbra_app`). Solo cambie `AUTH_SECRET` por un texto aleatorio:

```powershell
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

```powershell
npm run dev        # http://localhost:3001
```

Debe aparecer `Backend escuchando en http://localhost:3001` y `Base de datos conectada`.

### 2.3 Frontend

```powershell
cd frontend
npm install
npm run dev        # http://localhost:5173
```

También puede usar `run.bat` (doble clic) para abrir ambos servidores.

### 2.4 Cuentas de prueba

| Rol | Correo | Contraseña | Puede |
| --- | --- | --- | --- |
| Administrador | `ana.rodriguez@zimbra-demo.com` | `admin123` | Todo, incluida la auditoría y la simulación de errores |
| Comercial (vendedor) | `carlos.gomez@zimbra-demo.com` | `123456` | Clientes, prospectos, propuestas, ventas, pagos, reportes |
| Solo lectura | `demo@zimbra-demo.com` | `123456` | Consultar (sin botones de escritura) |
| Desactivada | `sofia.torres@zimbra-demo.com` | `123456` | No puede iniciar sesión |

Las cuentas creadas desde `/register` reciben el rol de solo lectura.

---

## 3. Pruebas automáticas

| Comando (carpeta `backend`) | Qué comprueba |
| --- | --- |
| `npm run db:check` | Que los 39 modelos coinciden con las columnas reales de la BD |
| `npm run test:api` | 56 verificaciones de la API con el backend encendido: login por rol, permisos, flujo prospecto → oportunidad → propuesta → venta → pagos, triggers, procedimientos, vistas y simulación de errores. **Crea datos de prueba.** |
| `npm run db:concurrencia` | Dos conexiones simultáneas: bloqueo de fila con `FOR UPDATE`, doble cobro evitado, interbloqueo (error 1213) y niveles de aislamiento |

El script `zimbra.sql` también se prueba solo: la PARTE 9 ejecuta las pruebas de triggers dentro de una transacción y termina con `ROLLBACK`.

---

## 4. Estructura

```text
├── zimbra.sql                    Script SQL final (sesiones 1 a 4)
├── database/
│   ├── concurrencia.sql          Demostración de bloqueos con dos pestañas de Workbench
│   └── generar_datos.mjs         Generador reproducible de la PARTE 2 (datos de prueba)
├── docs/
│   ├── requerimientos.md         Requerimientos funcionales y no funcionales (Sesión 1)
│   ├── modelo-datos.md           Diagrama modelo relacional (DMR) y justificación
│   └── cumplimiento-taller.md    Requisito de la guía → dónde está implementado
├── backend/
│   ├── src/
│   │   ├── server.js / app.js
│   │   ├── config/               env.js (variables), database.js (pool, transacciones, @usuario_actual)
│   │   ├── routes/               auth, cliente, seguimiento, comercial, reporte, health
│   │   ├── controllers/          validan la entrada y responden JSON
│   │   ├── models/               única capa con SQL (consultas parametrizadas)
│   │   ├── middlewares/          auth (token + permisos), errorHandler (errores MySQL → HTTP)
│   │   └── utils/                ApiError, token (HMAC-SHA256), validar
│   └── scripts/                  verificar_modelos, probar_api, simular_concurrencia
└── frontend/src/
    ├── main.jsx                  /login, /register o el panel (exige sesión)
    ├── App.jsx                   Menú por permisos, clientes y prospectos
    ├── SeguimientoProspecto.jsx  Tareas, llamadas y reuniones de un prospecto
    ├── pages/                    Dashboard, Propuestas, Ventas, Vendedores, Reportes, login, register
    ├── components/Graficos.jsx   Columnas, barras, indicadores y tabla de datos (SVG, sin librerías)
    ├── services/api.js           Todas las llamadas al backend + sesión
    └── utils/                    formato (pesos, fechas, %), colores de los gráficos
```

Flujo de una petición: `ruta → middleware de permisos → controlador (valida) → modelo (SQL) → MySQL (triggers/procedimientos)`.

---

## 5. Base de datos: organización de `zimbra.sql`

| Parte | Contenido | Sesión |
| --- | --- | --- |
| 1 | Esquema: 39 tablas, PK, FK con `ON DELETE` justificado, 23 `CHECK`, `UNIQUE` | 1 |
| 2 | Datos de prueba coherentes: 30+ registros en cada tabla de negocio | 2 |
| 3 | Funciones UDF: `fn_puntos_accion`, `fn_puntaje_cliente`, `fn_total_propuesta`, `fn_total_venta`, `fn_total_pagado`, `fn_saldo_venta`, `fn_comision_vendedor`, `fn_tasa_conversion` | 3 |
| 4 | Triggers (reglas de negocio, actividad, auditoría), procedimientos y evento | 3 |
| 5 | Transacciones ACID: `COMMIT`, `ROLLBACK`, `SAVEPOINT`, procedimiento con `FOR UPDATE`, 6 simulaciones de error con recuperación | 2 |
| 6 | 13 índices y comparación `EXPLAIN` sin/con índice, `EXPLAIN ANALYZE` | 4 |
| 7 | 10 vistas para reportes | 4 |
| 8 | Roles y usuarios MySQL con mínimo privilegio | 4 |
| 9 | Pruebas automáticas y verificación final | — |

**Tablas de catálogo con menos de 30 filas (por diseño):** `roles` (3: el `ENUM` solo admite `admin`, `user`, `user_demo`), `etapas_ventas` (6 etapas del embudo), `categorias_clientes` (5 segmentos) e `info_companie` (1: la empresa dueña del sistema). Las otras 35 tablas tienen entre 30 y 124 registros.

### Reglas de negocio automatizadas (triggers)

- Al **vender una propuesta**, la propuesta pasa a *aceptada*, la oportunidad a *ganada* (etapa 5) y el prospecto a *Cliente activo*.
- Una propuesta **enviada** mueve la oportunidad a la etapa 3; una **rechazada** la marca *perdida*. *Aceptada* y *rechazada* son estados finales.
- El **valor de la propuesta** y el **total de la venta** se recalculan solos a partir de sus líneas.
- Cada producto vendido **descuenta stock** (y falla si no alcanza); cancelar una venta lo **devuelve**.
- Un **pago** no puede superar el saldo; la venta queda *pagada* cuando los pagos aprobados cubren el total.
- Cada cambio en clientes, oportunidades, propuestas, ventas y pagos queda en **auditoría** con el usuario que lo hizo.
- El evento `ev_clasificar_clientes_potenciales` (cada 6 horas) marca como **Potencial** a los prospectos con alta interacción reciente, sin quitarles la categoría *Prospecto*.

### Usuarios MySQL (PARTE 8)

| Usuario | Rol | Permisos |
| --- | --- | --- |
| `zimbra_app` / `ZimbraApp#2026` | `rol_zimbra_aplicacion` | Lee todo, ejecuta procedimientos; escribe solo en tablas operativas. No puede borrar ventas ni pagos, ni tocar la auditoría ni el esquema |
| `zimbra_analista` / `ZimbraAnalista#2026` | `rol_zimbra_reportes` | Solo las vistas y `sp_reporte_ventas_mensual` |
| `zimbra_auditor` / `ZimbraAuditor#2026` | `rol_zimbra_reportes` + `rol_zimbra_auditoria` | Auditoría y actividad; ve los usuarios **sin** la columna `password` |

Las contraseñas son de laboratorio: cámbielas fuera del aula.

---

## 6. Endpoints de la API

Todas las rutas, salvo las públicas, exigen `Authorization: Bearer <token>` y el permiso indicado (tabla `roles_permisos`).

| Método | Ruta | Permiso | Usa en la BD |
| --- | --- | --- | --- |
| GET | `/api/estado`, `/api/db` | público | — |
| POST | `/api/auth/registro`, `/api/auth/login` | público | transacción usuario + rol + configuración |
| GET | `/api/auth/perfil` | sesión | — |
| GET/POST | `/api/clientes` | clientes.ver / clientes.crear | trigger de auditoría |
| GET/PUT/DELETE | `/api/clientes/:id` | clientes.ver / editar / desactivar | |
| GET/POST | `/api/clientes/prospectos` | prospectos.ver / prospectos.crear | vista `vw_prospectos` (UDF `fn_puntaje_cliente`), transacción |
| GET | `/api/clientes/:id/actividades` | prospectos.ver | |
| POST | `/api/clientes/:id/tareas`, `/api/clientes/:id/eventos` | seguimientos.registrar | |
| GET/POST | `/api/oportunidades` | oportunidades.ver / gestionar | vista `vw_cliente_vendedor_actual` |
| GET | `/api/productos` | productos.ver | |
| GET/POST | `/api/propuestas` | propuestas.ver / crear | vista `vw_propuestas_resumen`; triggers de total |
| GET | `/api/propuestas/:id` | propuestas.ver | |
| PATCH | `/api/propuestas/:id/estado` | propuestas.aprobar | triggers de estado |
| POST | `/api/propuestas/:id/venta` | ventas.registrar | **procedimiento** `sp_registrar_venta_desde_propuesta` |
| GET | `/api/ventas`, `/api/ventas/:id` | ventas.ver | vista `vw_ventas_detalle`, UDF `fn_total_pagado`, `fn_saldo_venta` |
| POST | `/api/ventas/:id/pagos` | pagos.registrar | **procedimiento** `procesar_pago_venta` |
| PATCH | `/api/pagos/:idPago/estado` | pagos.registrar | trigger que recalcula la venta |
| PATCH | `/api/ventas/:id/cancelar` | ventas.registrar | triggers de validación y stock |
| GET | `/api/vendedores`, `/api/vendedores/:id/clientes` | vendedores.ver | vista `vw_desempeno_vendedores` |
| GET | `/api/reportes/dashboard?anio=` | reportes.ver | vistas `vw_indicadores_generales`, `vw_ventas_mensuales`, `vw_embudo_oportunidades`, `vw_cartera_pendiente` |
| GET | `/api/reportes/mensual?anio=&mes=` | reportes.ver | **procedimiento** `sp_reporte_ventas_mensual` (UDF de comisión y conversión) |
| GET | `/api/reportes/campanas`, `/api/reportes/cartera`, `/api/reportes/anios` | reportes.ver | vistas |
| GET | `/api/reportes/auditoria` | auditoria.ver | |
| POST | `/api/transacciones/simular-error/:tipo` | auditoria.ver | **procedimiento** `sp_simular_error` |

Los errores de reglas de negocio (`SIGNAL`, `CHECK`, llaves) llegan como `400/409` con un mensaje claro: `{ "ok": false, "mensaje": "El pago de ... supera el saldo pendiente de ..." }`.

---

## 7. Guion sugerido para la demostración (15 min)

1. **BD:** ejecutar `zimbra.sql` y mostrar el conteo final y las pruebas 9.x.
2. **Login** como Carlos (vendedor). **Prospectos** → ver seguimiento → registrar una llamada.
3. **Propuestas** → *Nueva propuesta* → elegir oportunidad, agregar 2 productos → *Guardar y enviar* (el total lo calcula un trigger).
4. En el detalle → *Registrar venta* (procedimiento): la propuesta queda *aceptada* y la oportunidad *ganada*.
5. **Ventas** → abono parcial → intentar pagar de más (error del trigger) → pagar el saldo: venta *pagada*.
6. **Login** como Ana (admin) → **Reportes** → reporte mensual (procedimiento) → *Simulación de errores* (ROLLBACK) → auditoría con el nombre de Carlos.
7. **Tablero**: indicadores y gráficos sobre las vistas.
8. **Concurrencia:** `npm run db:concurrencia` o `database/concurrencia.sql` en dos pestañas de Workbench.
9. **Seguridad:** conectarse como `zimbra_analista` y mostrar el error 1142 al consultar `clientes`.

## 8. Integración de Rama-Pacheco (rama_fusion)

Se conservan los avances de ambas versiones. Lo de Sebastián sigue siendo la
base del proceso comercial; de Pacheco se incorporó la capa CRUD genérica y
los endpoints de negocio.

### Endpoints de negocio (nuevos)

| Método | Ruta | Descripción |
| --- | --- | --- |
| GET | `/api/dashboard` | Indicadores calculados sobre tablas base (pipeline, cobrado, conversión) |
| GET | `/api/oportunidades/pipeline` | Oportunidades abiertas agrupadas por etapa |
| PATCH | `/api/oportunidades/:id/etapa` | Mueve la oportunidad de etapa y deja historial |
| GET | `/api/clientes/:id/detalle` | Cliente con contactos, categorías, asignaciones, oportunidades y ventas |
| GET | `/api/ventas/:id/detalle` | Venta con productos, pagos, cliente y saldo |
| GET | `/api/productos/:id/detalle` | Producto con atributos y categorías |
| PATCH | `/api/tareas/:id/estado` | Cambia el estado de la tarea |
| PATCH | `/api/notificaciones/:id/leida` | Marca la notificación como leída |
| GET | `/api/roles/matriz` | Qué permisos tiene cada rol |
| GET | `/api/usuarios/:id/permisos` | Rol y permisos efectivos del usuario |

Todas exigen sesión (token). `/api/roles/matriz` se arma cruzando `roles`,
`permisos` y `roles_permisos`: el esquema nuevo no tiene la tabla
`matriz_permisos` que usaba la versión de Pacheco.

### CRUD genérico (`GET /`, `GET /:id`, `POST /`, `PUT/PATCH /:id`, `DELETE /:id`)

`/api/contactos`, `/api/categorias-clientes`, `/api/roles`, `/api/permisos`,
`/api/asignaciones`, `/api/etapas`, `/api/seguimientos`, `/api/tareas`,
`/api/campanas`, `/api/campanas-interacciones`, `/api/categorias-productos`,
`/api/eventos`, `/api/actividad`, `/api/notificaciones`, `/api/etiquetas`,
`/api/correos`, `/api/reportes`, `/api/auditoria`, `/api/compania`,
`/api/configuracion`.

Parámetros: `?limite=20&offset=0` para paginar y un filtro por campo del
modelo (`?estado=pendiente`).

### Decisiones de la integración

- **Clientes, prospectos, oportunidades, productos, propuestas, ventas,
  vendedores y pagos** conservan las rutas específicas (permisos por rol,
  validaciones y procedimientos de la base). El CRUD genérico no las reemplaza.
- **Usuarios**: solo `GET /api/usuarios` y `GET /api/usuarios/:id`. El alta y
  la clave van por `/api/auth` porque usan bcrypt; un `POST` genérico
  guardaría la contraseña en texto plano.
- **Pagos**: no hay CRUD. Se registran con `POST /api/ventas/:id/pagos`
  (`procesar_pago_venta`) y se aprueban/rechazan con
  `PATCH /api/pagos/:idPago/estado`; así no se puede borrar un pago y dejar
  el saldo de la venta incoherente.
- **`errorHandler`**: conserva la traducción por `errno` de Sebastián y añade
  la traducción por `code` de Pacheco como respaldo.
