// Punto de entrada de todas las rutas de la API

import { Router } from 'express'
import healthRouter from './health.routes.js'
import authRouter from './auth.routes.js'
import clienteRouter from './cliente.routes.js'
import seguimientoRouter from './seguimiento.routes.js'
import comercialRouter from './comercial.routes.js'
import reporteRouter from './reporte.routes.js'
import { autenticar } from '../middlewares/auth.js'

const router = Router()

// ---- Rutas públicas ----

// Raíz: comprueba conexión y lista las tablas
router.use('/', healthRouter)

// Endpoints de estado bajo /api
router.use('/api', healthRouter)

// Registro e inicio de sesión
router.use('/api/auth', authRouter)

// ---- A partir de aquí todo exige sesión (token) ----
router.use('/api', autenticar)

// Compatibilidad con el frontend anterior (GET /api/clients)
router.use('/api/clients', clienteRouter)

// Recurso REST por defecto
router.use('/api/clientes', clienteRouter)

// Seguimiento comercial de prospectos
router.use('/api/clientes', seguimientoRouter)

// Oportunidades, productos, vendedores, propuestas, ventas y pagos
router.use('/api', comercialRouter)

// Reportes, auditoría y simulación de errores
router.use('/api', reporteRouter)

export default router
