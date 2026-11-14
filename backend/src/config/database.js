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

export default pool
