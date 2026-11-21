// Configuración del pool de conexiones a MySQL

import './env.js'
import mysql from 'mysql2/promise'

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER?.trim(),
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  // DECIMAL llega como número (los montos caben sin pérdida en un double)
  decimalNumbers: true,
})

// Comprueba que la base de datos responde
export async function comprobarConexion() {
  const [filas] = await pool.query('SELECT 1 AS ok')
  return filas[0]
}

export async function listarTablas() {
  const [tablas] = await pool.query('SHOW TABLES')
  return tablas
}

export async function cerrarPool() {
  await pool.end()
}

// Ejecuta una operación con una conexión propia en la que se define
// @usuario_actual: los triggers de auditoría registran así quién hizo
// el cambio. La variable se limpia antes de devolver la conexión al pool.
export async function ejecutarComoUsuario(idUsuario, operacion) {
  const conexion = await pool.getConnection()

  try {
    await conexion.query('SET @usuario_actual = ?', [idUsuario ?? null])
    return await operacion(conexion)
  } finally {
    await conexion.query('SET @usuario_actual = NULL').catch(() => {})
    conexion.release()
  }
}

// Igual que la anterior, pero dentro de una transacción: COMMIT si la
// operación termina bien, ROLLBACK si lanza cualquier error.
export async function transaccionComoUsuario(idUsuario, operacion) {
  return ejecutarComoUsuario(idUsuario, async (conexion) => {
    await conexion.beginTransaction()

    try {
      const resultado = await operacion(conexion)
      await conexion.commit()
      return resultado
    } catch (error) {
      await conexion.rollback()
      throw error
    }
  })
}

// CALL devuelve [resultado1, resultado2, ..., OkPacket]: se quita el OkPacket
export function resultadosDeCall(filas) {
  return Array.isArray(filas) ? filas.filter(Array.isArray) : []
}

export default pool
