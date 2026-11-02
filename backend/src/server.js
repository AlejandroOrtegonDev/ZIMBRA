import './config/env.js'
import app from './app.js'
import { comprobarConexion } from './config/database.js'

const puerto = Number(process.env.PORT) 

app.listen(puerto, async () => {
  console.log(`Backend escuchando en http://localhost:${puerto}`)

  try {
    //comprueba si la base de datos está conectada
    await comprobarConexion()
    console.log('Base de datos conectada')
  } catch (error) {
    console.error('No se pudo conectar con la base de datos:', error.message)
  }
})
