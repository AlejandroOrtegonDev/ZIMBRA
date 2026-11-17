import dotenv from 'dotenv'

// Se carga antes que la base de datos. Si no, las variables del .env llegan vacías.
dotenv.config()

const requeridas = ['PORT', 'DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD']
const faltantes = requeridas.filter((clave) => !process.env[clave])

if (faltantes.length > 0) {
  console.warn(`Variables de entorno faltantes: ${faltantes.join(', ')}`)
}
