import express from 'express'
import cors from 'cors'
import { comprobarConexion } from './config/database.js'

const app = express()

app.use(cors({ origin: 'http://localhost:5173' }))
app.use(express.json())

app.get('/', async (req, res) => {
  try {
    await comprobarConexion()
    res.json({
      ok: true,
      mensaje: 'Base de datos conectada',
    })
  } catch (error) {
    console.error(error)
    res.status(500).json({
      ok: false,
      mensaje: 'No se pudo conectar con la base de datos',
    })
  }
})

app.use((error, req, res, next) => {
  console.error(error)
  res.status(500).json({
    ok: false,
    mensaje: 'Error interno del servidor',
  })
})

export default app
