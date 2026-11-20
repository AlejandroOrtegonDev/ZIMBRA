// Punto de entrada de todas las rutas de la API

import { Router } from 'express'
import healthRouter from './health.routes.js'
import clienteRouter from './cliente.routes.js'
import seguimientoRouter from './seguimiento.routes.js'
import oportunidadRouter from './oportunidad.routes.js'
import ventaRouter from './venta.routes.js'

const router = Router()

// Raíz: comprueba conexión y lista las tablas
router.use('/', healthRouter)

// Endpoints de estado bajo /api
router.use('/api', healthRouter)

// Compatibilidad con el frontend actual (GET /api/clients)
router.use('/api/clients', clienteRouter)

// Recurso REST por defecto
router.use('/api/clientes', clienteRouter)

// Seguimiento comercial de prospectos
router.use('/api/clientes', seguimientoRouter)

// Gestión de oportunidades comerciales
router.use('/api/oportunidades', oportunidadRouter)

// Gestión de ventas e inventario
router.use('/api/ventas', ventaRouter)

export default router
