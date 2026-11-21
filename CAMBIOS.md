# Registro de cambios – completar el taller al 100 %

Fecha: 19–20 de noviembre de 2026. Respaldo previo completo del proyecto:
`..\BACKUP-20261119-231928` (sin `node_modules`).

## Correcciones críticas (Fase 0)

| Problema | Corrección |
| --- | --- |
| `seguimiento.model.js` usaba `eventos.id_cliente`, que no existía: el historial y el registro de llamadas de un prospecto devolvían error 500 | Se agregó `eventos.id_cliente` (FK, `ON DELETE SET NULL`) y se ligaron los eventos de prueba a sus clientes |
| `actualizar_clientes_potenciales` borraba la categoría *Prospecto*: a las 6 horas desaparecían todos los prospectos (verificado: 3 → 0) | Nueva categoría *Potencial* (5); el procedimiento solo recalcula esa marca |
| La venta 2 se generó de una propuesta *enviada* (no aceptada) y quedaba sobrepagada (26.550.000 sobre 21.550.000) | Datos corregidos; triggers impiden pagar de más y aceptan la propuesta al venderla |
| `procesar_pago_venta` no bloqueaba la venta ni consideraba pagos previos | Ahora usa `FOR UPDATE`, calcula el saldo con `fn_saldo_venta` y admite pagos parciales |
| `SET GLOBAL event_scheduler` detenía el script sin privilegio de administrador | Se ejecuta dentro de un procedimiento con manejador: avisa y continúa |
| `/register` solo escribía en consola (en inglés) | Registro e inicio de sesión reales con bcrypt y sesiones firmadas |

## Archivos

**Modificados:** `zimbra.sql` (reconstruido por sesiones), `README.md`, `backend/.env.example`, `backend/package.json` y `package-lock.json` (dependencia `bcryptjs`), `backend/scripts/verificar_modelos.mjs`, `backend/src/config/{database,env}.js`, `backend/src/middlewares/errorHandler.js`, `backend/src/models/{cliente,evento,oportunidad,producto,propuesta,reporte,vendedor,venta}.model.js`, `backend/src/routes/{index,cliente,seguimiento}.routes.js`, `frontend/src/{App,main,SeguimientoProspecto}.jsx`, `frontend/src/services/api.js`, `frontend/src/pages/register/register.{jsx,css}`.

**Nuevos:**
- Base de datos: `database/concurrencia.sql`, `database/generar_datos.mjs`
- Documentación: `docs/requerimientos.md`, `docs/modelo-datos.md`, `docs/cumplimiento-taller.md`, `CAMBIOS.md`
- Backend: `controllers/{auth,catalogo,propuesta,reporte,venta}.controller.js`, `models/auth.model.js`, `routes/{auth,comercial,reporte}.routes.js`, `middlewares/auth.js`, `utils/{token,validar}.js`, `scripts/{probar_api,simular_concurrencia}.mjs`
- Frontend: `pages/{Dashboard,Propuestas,Ventas,Vendedores,Reportes}.jsx`, `pages/modulos.css`, `pages/login/Login.jsx`, `components/Graficos.jsx`, `components/graficos.css`, `utils/{formato,colores}.js`

**Sin cambios:** `PROYECTO_ZIMBRA.md`, `run.bat`, `FIX_SUMMARY.md` (documento histórico: describe `src/api/api.js`, que ya no existe).

## Pruebas ejecutadas (base MySQL 8.4 limpia en Docker)

| Prueba | Resultado |
| --- | --- |
| `zimbra.sql` completo | exit 0; pruebas 9.1–9.9 con el valor esperado; 6/6 simulaciones con ROLLBACK correcto |
| Coherencia de datos (8 consultas) | 0 inconsistencias |
| Permisos de los 3 usuarios MySQL | Permitido y denegado según lo diseñado (1142/1143) |
| `npm run db:check` | 39 tablas, 39 modelos, 0 errores |
| `npm run test:api` | 56 de 56 correctas |
| `npm run db:concurrencia` (como `zimbra_app`) | 4 escenarios correctos |
| ESLint y `vite build` | sin errores |
| Flujo en Chrome (registro, rol de solo lectura, propuesta, venta, pagos, seguimiento, simulación) | 14/14, sin errores de consola |
