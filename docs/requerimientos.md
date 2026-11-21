# Requerimientos del Sistema de Gestión Comercial Zimbra

Entregable de la **Sesión 1 – Diseño y requerimientos**. Cada requerimiento indica dónde quedó implementado.

## Procesos clave identificados en el caso

| Proceso | Descripción | Tablas principales |
| --- | --- | --- |
| Clientes y prospectos | Captar visitantes, registrarlos como prospectos, calificarlos y asignarles un vendedor | `clientes`, `contactos`, `clientes_categorias`, `asignaciones_clientes`, `actividad_web` |
| Propuestas | Cotizar productos a una oportunidad y llevarla por el embudo | `oportunidades`, `etapas_ventas`, `propuestas`, `propuestas_detalles` |
| Ventas | Convertir propuestas en ventas, cobrar y controlar el inventario | `ventas`, `ventas_productos`, `pagos`, `productos` |
| Marketing | Campañas, clientes impactados e interacciones | `campanas_marketing`, `campanas_clientes`, `campanas_interacciones` |
| Reportes | Indicadores comerciales y auditoría | vistas `vw_*`, `reportes_generados`, `auditoria` |

## Requerimientos funcionales

| Código | Requerimiento | Implementación |
| --- | --- | --- |
| RF-01 | Registrar usuarios e iniciar sesión con contraseña cifrada | `POST /api/auth/registro`, `/login` (bcrypt); pantallas `/register` y `/login` |
| RF-02 | Controlar el acceso por rol (administrador, comercial, solo lectura) | Tablas `roles`, `permisos`, `roles_permisos`; middleware `requierePermiso`; menú y botones según permisos |
| RF-03 | Registrar, editar, consultar y desactivar clientes sin borrar su historial | Módulo Clientes; `estado = 0` en lugar de `DELETE` |
| RF-04 | Registrar prospectos y asignarles un vendedor en una sola operación | `crearProspecto` (transacción: cliente + categoría + asignación) |
| RF-05 | Registrar tareas, llamadas y reuniones de seguimiento de un prospecto | `SeguimientoProspecto.jsx`; tablas `tareas`, `eventos` |
| RF-06 | Clasificar automáticamente a los prospectos con alta interacción como *Potencial* | Procedimiento `actualizar_clientes_potenciales` + evento cada 6 h + UDF `fn_puntos_accion` |
| RF-07 | Crear oportunidades y moverlas por las etapas del embudo | `POST /api/oportunidades`; triggers de propuestas mueven la etapa |
| RF-08 | Crear propuestas con varios productos; el valor se calcula a partir de las líneas | Módulo Propuestas; triggers `trg_propuestas_detalles_total_*` |
| RF-09 | Enviar, aceptar o rechazar propuestas; actualizar el estado de la oportunidad | `PATCH /api/propuestas/:id/estado`; triggers `trg_propuestas_validar_estado`, `trg_propuestas_actualizar_oportunidad` |
| RF-10 | Convertir una propuesta en venta copiando sus productos | Procedimiento `sp_registrar_venta_desde_propuesta` |
| RF-11 | Registrar pagos parciales o totales sin superar el saldo | Procedimiento `procesar_pago_venta`; trigger `trg_pagos_validar` |
| RF-12 | Aprobar o rechazar pagos pendientes y actualizar el estado de la venta | Trigger `trg_pagos_estado_venta_upd` |
| RF-13 | Controlar el stock al vender y devolverlo al cancelar | Triggers `trg_ventas_productos_validar`, `trg_ventas_devolver_stock` |
| RF-14 | Consultar el desempeño de los vendedores (conversión, comisión, ventas) | Vista `vw_desempeno_vendedores`; UDF `fn_tasa_conversion`, `fn_comision_vendedor` |
| RF-15 | Generar el reporte mensual de ventas | Procedimiento `sp_reporte_ventas_mensual`; módulo Reportes |
| RF-16 | Ver un tablero con indicadores y gráficos | Módulo Tablero sobre las vistas `vw_indicadores_generales`, `vw_ventas_mensuales`, `vw_embudo_oportunidades` |
| RF-17 | Medir la efectividad de las campañas de marketing | Vista `vw_efectividad_campanas` |
| RF-18 | Registrar automáticamente quién cambia clientes, oportunidades, propuestas, ventas y pagos | Triggers `trg_*_auditar_*` + `@usuario_actual` |

## Requerimientos no funcionales

| Código | Requerimiento | Cómo se cumple |
| --- | --- | --- |
| RNF-01 Integridad | Ningún dato inconsistente puede guardarse | PK, 47 FK, 23 CHECK, UNIQUE y triggers con `SIGNAL` |
| RNF-02 Atomicidad | Las operaciones de varios pasos son todo o nada | Transacciones en procedimientos y en el backend (`transaccionComoUsuario`); demostración en `sp_simular_error` |
| RNF-03 Concurrencia | Dos usuarios no pueden cobrar dos veces la misma venta ni venderla dos veces | `SELECT ... FOR UPDATE` en los procedimientos; `UNIQUE (id_propuesta)` en ventas; prueba `npm run db:concurrencia` |
| RNF-04 Seguridad de la BD | La aplicación se conecta con privilegios mínimos | Usuario `zimbra_app` (PARTE 8), sin DROP ni DELETE en tablas críticas |
| RNF-05 Seguridad de la aplicación | Contraseñas con hash y rutas protegidas | bcrypt; token HMAC-SHA256 con vencimiento de 8 h; permisos por ruta |
| RNF-06 Prevención de inyección SQL | Ningún dato del usuario se concatena en SQL | Consultas parametrizadas (`?`) en todos los modelos |
| RNF-07 Rendimiento | Las consultas de reportes usan índices | 13 índices; comparación con `EXPLAIN` en la PARTE 6 |
| RNF-08 Auditabilidad | Los cambios importantes quedan registrados | Tabla `auditoria` llenada por triggers |
| RNF-09 Usabilidad | Interfaz en español, mensajes de error claros | Errores MySQL traducidos a mensajes de negocio (`errorHandler`) |
| RNF-10 Accesibilidad de los gráficos | Los datos se pueden leer sin depender del color | Leyenda, tooltip, etiquetas de texto y tabla con los datos de cada gráfico |
| RNF-11 Mantenibilidad | Capas separadas y verificables | rutas → controladores → modelos; `npm run db:check` |
| RNF-12 Reproducibilidad | El sistema se instala desde cero con un solo script | `zimbra.sql` + `database/generar_datos.mjs` |
