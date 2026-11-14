// Punto de entrada de todas las rutas de la API

import { Router } from 'express'
import healthRouter from './health.routes.js'
import clienteRouter from './cliente.routes.js'

const router = Router()

// Raíz: comprueba conexión y lista las tablas
router.use('/', healthRouter)

// Endpoints de estado bajo /api
router.use('/api', healthRouter)

// Compatibilidad con el frontend actual (GET /api/clients)
router.use('/api/clients', clienteRouter)

// Recurso REST por defecto
router.use('/api/clientes', clienteRouter)

export default router
