# Cumplimiento de la Guía del Taller Grupal – Caso Zimbra

Cada actividad de la guía, dónde está implementada y cómo se comprobó. Las pruebas se ejecutaron sobre una base MySQL 8.4 limpia cargada con `zimbra.sql`.

## Sesión 1 – Diseño y requerimientos

| Actividad | Evidencia | Verificación |
| --- | --- | --- |
| Procesos clave: clientes, propuestas, ventas, marketing, reportes | `docs/requerimientos.md` (tabla de procesos) | — |
| DMR con mínimo 6 tablas | `docs/modelo-datos.md` (39 tablas, diagramas Mermaid) | Conteo final de `zimbra.sql`: 39 tablas |
| Llaves primarias, foráneas y restricciones | `zimbra.sql` PARTE 1: PK en todas las tablas, 47 FK con `ON DELETE` justificado, 23 `CHECK`, `UNIQUE`, `ENUM` | Simulaciones `llave_foranea` (1452), `duplicado` (1062), `restriccion` (3819) |
| Requerimientos funcionales y no funcionales | `docs/requerimientos.md` (RF-01 a RF-18, RNF-01 a RNF-12) | — |
| Entregable: DMR con justificación (2 páginas) | `docs/modelo-datos.md`, sección 3 | Pendiente de su equipo: maquetar el documento final |

## Sesión 2 – Base de datos y transacciones

| Actividad | Evidencia | Verificación |
| --- | --- | --- |
| `CREATE TABLE` | `zimbra.sql` PARTE 1 | El script corre de punta a punta (exit 0) |
| Mínimo 30 registros por tabla | PARTE 2 (`database/generar_datos.mjs`): 35 tablas con 30 a 124 registros | Conteo final de la PARTE 9. Excepciones de catálogo por diseño: `roles` 3 (ENUM), `etapas_ventas` 6, `categorias_clientes` 5, `info_companie` 1 |
| Datos coherentes | Totales = suma de líneas; ventas pagadas = pagos aprobados; propuestas vendidas = aceptadas | 8 consultas de coherencia con 0 inconsistencias |
| `BEGIN TRANSACTION` / `COMMIT` | PARTE 5.1: alta comercial atómica | Resultado `5.1 COMMIT` |
| `ROLLBACK` | PARTE 5.2: subida de precios deshecha | `5.2 después del ROLLBACK: precio original intacto` |
| `SAVEPOINT` | PARTE 5.3: venta con `ROLLBACK TO SAVEPOINT` | Total 90.000 con 1 producto |
| Simulación de errores y recuperación | PARTE 5.5: `sp_simular_error` (6 tipos); módulo Reportes (admin) | Los 6 casos: "ROLLBACK correcto: la base de datos quedó exactamente igual" |
| Conexión inicial del backend | `backend/src/config/database.js`; `GET /api/estado`, `/api/db` | `npm run test:api`, sección 1 |

## Sesión 3 – Automatización y lógica avanzada

| Actividad | Evidencia | Verificación |
| --- | --- | --- |
| Triggers (p. ej. actualizar estado de propuesta) | 39 triggers (PARTE 4): venta → propuesta **aceptada** → oportunidad **ganada**; rechazo → oportunidad perdida; transiciones válidas; totales; stock; pagos; conversión de prospecto; actividad; auditoría | Pruebas 9.3 a 9.6 del script; `npm run test:api`, sección 5 |
| Procedimientos almacenados (p. ej. reportes mensuales) | `sp_reporte_ventas_mensual`, `procesar_pago_venta`, `sp_registrar_venta_desde_propuesta`, `sp_simular_error`, `actualizar_clientes_potenciales`, `sp_recalcular_estado_venta`, `registrar_auditoria` | Reporte de octubre 2026 con resumen, vendedores y productos |
| Funciones UDF | `fn_total_propuesta`, `fn_total_venta`, `fn_total_pagado`, `fn_saldo_venta`, `fn_comision_vendedor`, `fn_tasa_conversion`, `fn_puntaje_cliente`, `fn_puntos_accion` | Usadas en vistas, triggers, procedimientos y la API |
| Evento programado | `ev_clasificar_clientes_potenciales` (cada 6 h) | Prueba 9.7: los prospectos se conservan y se marca el potencial |
| Endpoints que llaman procedimientos y funciones | `POST /api/propuestas/:id/venta`, `POST /api/ventas/:id/pagos`, `GET /api/reportes/mensual`, `POST /api/transacciones/simular-error/:tipo`; UDF en `/api/ventas`, `/api/vendedores`, `/api/clientes/prospectos` | `npm run test:api`: 56/56 |
| Formularios básicos (clientes/propuestas) | Clientes, prospectos, seguimiento, **propuestas con líneas de productos**, oportunidades, pagos, registro de usuarios | Flujo automatizado en Chrome: registro, propuesta, venta, pago (14/14) |

## Sesión 4 – Optimización, seguridad y sustentación

| Actividad | Evidencia | Verificación |
| --- | --- | --- |
| Vistas para reportes | 10 vistas (PARTE 7): ventas mensuales, embudo, desempeño, campañas, cartera, ventas, propuestas, prospectos, indicadores, vendedor actual | Tablero y Reportes del frontend |
| Índices | 13 índices (PARTE 6) | `EXPLAIN`: ventas ALL 36 filas → range 7; pagos ALL 53 → range 3 con "Using index"; actividad ALL 126 → range 26; clientes ALL 61 → range 3 |
| Simulación de concurrencia y bloqueos | `database/concurrencia.sql` (5 escenarios para dos pestañas) y `npm run db:concurrencia` | Espera de 2,01 s por candado; 1 cobro de 2 simultáneos; deadlock 1213 detectado; REPEATABLE READ vs. READ COMMITTED |
| Roles y permisos en la BD | PARTE 8: `CREATE ROLE`, `GRANT` por tabla, vista, procedimiento y columna; 3 usuarios | `zimbra_analista`: 1142 al leer `clientes`; `zimbra_auditor`: 1143 en `password`; `zimbra_app`: sin DELETE en pagos, sin UPDATE en auditoría, sin DROP |
| Frontend final con reportes y visualización | Tablero (indicadores, ventas por mes, embudo, ranking), Reportes (mensual, campañas, cartera, auditoría), Ventas, Vendedores | Capturas revisadas; ESLint y build sin errores |
| Demostración práctica | Guion en `README.md`, sección 7 | — |
| Documento final (máx. 8 páginas, APA) y presentación oral | Insumos: este archivo, `requerimientos.md`, `modelo-datos.md`, `README.md` | **Pendiente de su equipo**: redacción en normas APA y diapositivas |
