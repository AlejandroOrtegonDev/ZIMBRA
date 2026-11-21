import dotenv from 'dotenv'

// Se carga antes que la base de datos. Si no, las variables del .env llegan vacías.
dotenv.config({ quiet: true })

const requeridas = ['PORT', 'DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD', 'AUTH_SECRET']
const faltantes = requeridas.filter((clave) => !process.env[clave])

if (faltantes.length > 0) {
  console.warn(`Variables de entorno faltantes: ${faltantes.join(', ')}`)
}

if (!process.env.AUTH_SECRET) {
  // Solo para desarrollo: con una clave fija cualquiera podría falsificar sesiones
  process.env.AUTH_SECRET = 'clave-de-desarrollo-cambiar-en-el-env'
  console.warn('AUTH_SECRET no está definida: se usa una clave de desarrollo')
}
