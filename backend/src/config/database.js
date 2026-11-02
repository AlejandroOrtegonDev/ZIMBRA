//este archivo crea la configuración de la base de datos

import './env.js'
import mysql from 'mysql2/promise'

//crea el pool de conexiones
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

//hace una consulta a la base de datos para comprobar si está conectada
export async function comprobarConexion() {
  const [filas] = await pool.query('SELECT 1 AS ok')
  return filas[0]
}

export default pool
