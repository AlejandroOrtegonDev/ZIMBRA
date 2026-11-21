// Simulación automática de concurrencia y bloqueos (Sesión 4).
// Abre dos conexiones independientes (sesión A y sesión B) y reproduce
// los escenarios de database/concurrencia.sql.
//
//   cd backend
//   npm run db:concurrencia
//
// Cambios que deja en la base: una venta de demostración pequeña
// (1 unidad de Zimbra Starter) pagada una sola vez (escenario 2).
// Los demás escenarios terminan en ROLLBACK o restauran el valor.

import '../src/config/env.js'
import mysql from 'mysql2/promise'

const config = {
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER?.trim(),
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
}

const esperar = (ms) => new Promise((r) => setTimeout(r, ms))
const reloj = () => performance.now()
let fallos = 0

function resultado(ok, texto) {
  if (!ok) fallos++
  console.log(`   ${ok ? 'OK ' : 'FALLO'} ${texto}`)
}

async function abrirSesion(nombre) {
  const conexion = await mysql.createConnection(config)
  await conexion.query('SET SESSION innodb_lock_wait_timeout = 10')
  conexion.nombre = nombre
  return conexion
}

// ------------------------------------------------------------
async function escenarioBloqueoFila(A, B) {
  console.log('\n1. Bloqueo de fila con SELECT ... FOR UPDATE')
  const [[venta]] = await A.query('SELECT id_venta FROM ventas ORDER BY id_venta LIMIT 1')

  await A.beginTransaction()
  await A.query('SELECT id_venta FROM ventas WHERE id_venta = ? FOR UPDATE', [venta.id_venta])
  console.log(`   A bloqueó la venta #${venta.id_venta}`)

  await B.beginTransaction()
  const inicio = reloj()
  const consultaB = B.query('SELECT id_venta FROM ventas WHERE id_venta = ? FOR UPDATE', [venta.id_venta])
  console.log('   B pide el mismo candado y queda esperando...')

  await esperar(300)
  try {
    const [esperas] = await A.query(`
      SELECT COUNT(*) AS n
      FROM performance_schema.data_lock_waits w
      JOIN information_schema.INNODB_TRX r ON r.trx_id = w.REQUESTING_ENGINE_TRANSACTION_ID
      WHERE r.trx_mysql_thread_id = ?`, [B.threadId])
    resultado(esperas[0].n > 0, `performance_schema muestra a B (hilo ${B.threadId}) esperando el candado de A`)
  } catch {
    // zimbra_app no tiene el privilegio PROCESS (mínimo privilegio): se omite la inspección
    console.log('   (el usuario actual no puede inspeccionar performance_schema; se mide el tiempo de espera)')
  }

  await esperar(1700)
  await A.commit()
  console.log('   A confirma (COMMIT) a los 2 s')
  await consultaB
  const espera = (reloj() - inicio) / 1000
  await B.commit()
  resultado(espera >= 1.9, `B obtuvo la fila después de esperar ${espera.toFixed(2)} s`)
}

// ------------------------------------------------------------
async function escenarioPagoDoble(A, B) {
  console.log('\n2. Dos cajeros cobran la misma venta a la vez (procesar_pago_venta)')

  // Venta de demostración pequeña: 1 licencia Zimbra Starter
  await A.beginTransaction()
  const [venta] = await A.query(
    "INSERT INTO ventas (id_cliente, id_vendedor, total, estado) VALUES (2, 1, 0, 'pendiente')",
  )
  await A.query(
    'INSERT INTO ventas_productos (id_venta, id_producto, cantidad, precio_unitario, subtotal) VALUES (?, 1, 1, 45000, 45000)',
    [venta.insertId],
  )
  await A.commit()
  console.log(`   Venta de demostración #${venta.insertId} creada por 45.000`)

  const llamar = (conexion) =>
    conexion.query('CALL procesar_pago_venta(?, ?, NULL)', [venta.insertId, `caja ${conexion.nombre}`])

  const [rA, rB] = await Promise.allSettled([llamar(A), llamar(B)])
  const exitos = [rA, rB].filter((r) => r.status === 'fulfilled').length
  const rechazo = [rA, rB].find((r) => r.status === 'rejected')

  resultado(exitos === 1, `Solo una sesión cobró (${exitos} de 2)`)
  if (rechazo) resultado(true, `La otra recibió: "${rechazo.reason.sqlMessage ?? rechazo.reason.message}"`)

  const [[pagos]] = await A.query(
    'SELECT COUNT(*) AS n, SUM(valor) AS total, fn_saldo_venta(?) AS saldo FROM pagos WHERE id_venta = ?',
    [venta.insertId, venta.insertId],
  )
  resultado(pagos.n === 1 && Number(pagos.saldo) === 0, `Pagos registrados: ${pagos.n} por ${pagos.total}; saldo final ${pagos.saldo}`)
}

// ------------------------------------------------------------
async function escenarioDeadlock(A, B) {
  console.log('\n3. Interbloqueo (deadlock): A toma 1 -> 2 y B toma 2 -> 1')
  await A.beginTransaction()
  await B.beginTransaction()
  await A.query('SELECT id_cliente FROM clientes WHERE id_cliente = 1 FOR UPDATE')
  await B.query('SELECT id_cliente FROM clientes WHERE id_cliente = 2 FOR UPDATE')
  console.log('   A tiene el cliente 1, B tiene el cliente 2')

  const pasoA = A.query('SELECT id_cliente FROM clientes WHERE id_cliente = 2 FOR UPDATE')
  await esperar(300)
  const pasoB = B.query('SELECT id_cliente FROM clientes WHERE id_cliente = 1 FOR UPDATE')

  const [rA, rB] = await Promise.allSettled([pasoA, pasoB])
  const victima = [rA, rB].find((r) => r.status === 'rejected')
  resultado(
    victima?.reason?.code === 'ER_LOCK_DEADLOCK',
    `MySQL detectó el ciclo: ${victima?.reason?.code} (${victima?.reason?.errno}) en la sesión ${rA.status === 'rejected' ? 'A' : 'B'}`,
  )
  resultado([rA, rB].some((r) => r.status === 'fulfilled'), 'La otra sesión continuó normalmente')
  await A.rollback()
  await B.rollback()
}

// ------------------------------------------------------------
async function escenarioAislamiento(A, B) {
  console.log('\n4. Niveles de aislamiento (lectura repetible vs. confirmada)')
  const [[original]] = await A.query('SELECT id_notificacion, estado FROM notificaciones ORDER BY id_notificacion LIMIT 1')
  const otro = original.estado === 'leida' ? 'pendiente' : 'leida'
  const leer = async () => (await A.query('SELECT estado FROM notificaciones WHERE id_notificacion = ?', [original.id_notificacion]))[0][0].estado

  try {
    await A.query('SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ')
    await A.beginTransaction()
    const antes = await leer()
    await B.query('UPDATE notificaciones SET estado = ? WHERE id_notificacion = ?', [otro, original.id_notificacion])
    const despues = await leer()
    await A.commit()
    resultado(antes === despues, `REPEATABLE READ: A sigue viendo '${despues}' aunque B confirmó '${otro}'`)

    await A.query('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED')
    await A.beginTransaction()
    const antesRC = await leer()
    await B.query('UPDATE notificaciones SET estado = ? WHERE id_notificacion = ?', [original.estado, original.id_notificacion])
    const despuesRC = await leer()
    await A.commit()
    resultado(antesRC !== despuesRC, `READ COMMITTED: A pasó de '${antesRC}' a '${despuesRC}' dentro de la misma transacción`)
  } finally {
    await A.query('SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ')
    await B.query('UPDATE notificaciones SET estado = ? WHERE id_notificacion = ?', [original.estado, original.id_notificacion])
  }
}

// ------------------------------------------------------------
const A = await abrirSesion('A')
const B = await abrirSesion('B')
console.log(`Sesión A = hilo ${A.threadId}, sesión B = hilo ${B.threadId} (usuario ${config.user})`)

try {
  await escenarioBloqueoFila(A, B)
  await escenarioPagoDoble(A, B)
  await escenarioDeadlock(A, B)
  await escenarioAislamiento(A, B)
} finally {
  await A.end()
  await B.end()
}

console.log(fallos === 0 ? '\nTodas las pruebas de concurrencia pasaron.' : `\n${fallos} prueba(s) fallaron.`)
process.exit(fallos === 0 ? 0 : 1)
