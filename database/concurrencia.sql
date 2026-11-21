-- ============================================================
-- Simulación de CONCURRENCIA Y BLOQUEOS (Sesión 4)
--
-- Se necesitan DOS conexiones a la vez. En MySQL Workbench abra dos
-- pestañas de consulta (File > New Query Tab) sobre la misma conexión:
-- "SESIÓN A" y "SESIÓN B". Ejecute cada línea con Ctrl+Enter en el
-- orden indicado por los números (A1, B1, A2...).
--
-- Versión automática de las mismas pruebas:
--   cd backend
--   npm run db:concurrencia
--
-- Antes de empezar, en AMBAS pestañas:
USE zimbra;
-- (Opcional) que la espera de un bloqueo no pase de 10 segundos:
SET SESSION innodb_lock_wait_timeout = 10;
-- ============================================================


-- ============================================================
-- ESCENARIO 1. Bloqueo de fila con SELECT ... FOR UPDATE
-- Dos cajeros intentan cobrar la misma venta al mismo tiempo.
-- ============================================================

-- A1 (Sesión A): abre una transacción y bloquea la venta 9
START TRANSACTION;
SELECT id_venta, total, estado, fn_saldo_venta(id_venta) AS saldo
FROM ventas WHERE id_venta = 9 FOR UPDATE;

-- B1 (Sesión B): intenta bloquear la MISMA fila.
--     Se queda "ejecutando" (esperando) porque A tiene el candado.
START TRANSACTION;
SELECT id_venta, total, estado FROM ventas WHERE id_venta = 9 FOR UPDATE;

-- A2 (Sesión A, mientras B espera): ver quién espera a quién
SELECT r.trx_mysql_thread_id AS sesion_que_espera,
       b.trx_mysql_thread_id AS sesion_que_bloquea,
       r.trx_query           AS consulta_en_espera
FROM performance_schema.data_lock_waits w
JOIN information_schema.INNODB_TRX r ON r.trx_id = w.REQUESTING_ENGINE_TRANSACTION_ID
JOIN information_schema.INNODB_TRX b ON b.trx_id = w.BLOCKING_ENGINE_TRANSACTION_ID;

-- A3 (Sesión A): confirma. En ese instante B recibe la fila y continúa.
COMMIT;

-- B2 (Sesión B): libera
COMMIT;


-- ============================================================
-- ESCENARIO 2. Actualización perdida evitada
-- Ambos cajeros cobran el saldo completo de la venta 9 con el
-- procedimiento procesar_pago_venta (usa FOR UPDATE por dentro).
-- ============================================================

-- A1 y B1: ejecute CASI al mismo tiempo en las dos pestañas
CALL procesar_pago_venta(9, 'transferencia', NULL);
-- Resultado: una sesión registra el pago y deja la venta 'pagada';
-- la otra espera el candado, ve la venta ya pagada y recibe el error
-- "La venta no está pendiente (estado: pagada)". Nunca hay doble cobro.
-- (Si la venta 9 ya está pagada, use otra pendiente:
--  SELECT id_venta FROM vw_cartera_pendiente WHERE saldo > 0;)


-- ============================================================
-- ESCENARIO 3. Interbloqueo (deadlock)
-- A bloquea el producto 1 y luego quiere el 2; B al revés.
-- ============================================================

-- A1
START TRANSACTION;
UPDATE productos SET stock = stock - 1 WHERE id_producto = 1;

-- B1
START TRANSACTION;
UPDATE productos SET stock = stock - 1 WHERE id_producto = 2;

-- A2 (queda esperando a B)
UPDATE productos SET stock = stock - 1 WHERE id_producto = 2;

-- B2 (cierra el ciclo: MySQL detecta el interbloqueo de inmediato)
UPDATE productos SET stock = stock - 1 WHERE id_producto = 1;
-- Una de las dos recibe:
--   ERROR 1213 (40001): Deadlock found when trying to get lock;
--   try restarting transaction
-- InnoDB deshace esa transacción (la "víctima") y la otra continúa.

-- A3 y B3: cierre ambas sin dejar cambios
ROLLBACK;

-- Ver el último interbloqueo detectado (sección LATEST DETECTED DEADLOCK)
SHOW ENGINE INNODB STATUS;
-- Prevención: acceder siempre a las filas en el mismo orden
-- (por ejemplo, por id_producto ascendente) y reintentar ante 1213.


-- ============================================================
-- ESCENARIO 4. Niveles de aislamiento: lectura repetible vs. confirmada
-- ============================================================

-- A1: REPEATABLE READ (valor por defecto de InnoDB)
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT precio FROM productos WHERE id_producto = 3;   -- p. ej. 145000

-- B1: cambia el precio y confirma (autocommit)
UPDATE productos SET precio = precio + 1000 WHERE id_producto = 3;

-- A2: en REPEATABLE READ sigue viendo el valor anterior (misma foto)
SELECT precio FROM productos WHERE id_producto = 3;   -- 145000
COMMIT;
SELECT precio FROM productos WHERE id_producto = 3;   -- 146000 (ya fuera de la transacción)

-- A3: ahora con READ COMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT precio FROM productos WHERE id_producto = 3;   -- 146000

-- B2: devuelve el precio
UPDATE productos SET precio = precio - 1000 WHERE id_producto = 3;

-- A4: en READ COMMITTED ve el cambio confirmado por B (lectura no repetible)
SELECT precio FROM productos WHERE id_producto = 3;   -- 145000
COMMIT;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;


-- ============================================================
-- ESCENARIO 5. Lectura compartida (FOR SHARE)
-- Varias sesiones pueden leer con candado compartido, pero nadie
-- puede modificar la fila hasta que todas terminen.
-- ============================================================

-- A1
START TRANSACTION;
SELECT id_producto, stock FROM productos WHERE id_producto = 6 FOR SHARE;

-- B1: también puede leer con FOR SHARE (no espera)...
START TRANSACTION;
SELECT id_producto, stock FROM productos WHERE id_producto = 6 FOR SHARE;
-- ...pero si intenta modificar, espera a que A termine:
UPDATE productos SET stock = stock WHERE id_producto = 6;

-- A2: libera; B continúa
COMMIT;

-- B2
ROLLBACK;
