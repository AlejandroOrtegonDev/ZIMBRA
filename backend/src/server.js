import './config/env.js'
import app from './app.js'
import { comprobarConexion, cerrarPool } from './config/database.js'

const puerto = Number(process.env.PORT)

const servidor = app.listen(puerto, async () => {
  console.log(`Backend escuchando en http://localhost:${puerto}`)

  try {
    await comprobarConexion()
    console.log('Base de datos conectada')
  } catch (error) {
    console.error('No se pudo conectar con la base de datos:', error.message)
  }
})

async function apagar(senal) {
  console.log(`\n${senal} recibido, cerrando servidor...`)
  servidor.close(async () => {
    await cerrarPool()
    process.exit(0)
  })
}

process.on('SIGINT', () => apagar('SIGINT'))
process.on('SIGTERM', () => apagar('SIGTERM'))
