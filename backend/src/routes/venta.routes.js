
import { Router } from 'express'
import * as ventaController from '../controllers/venta.controller.js'

const router = Router()

// Consultar ventas
router.get('/', ventaController.listarVentas)

// Consultar propuestas disponibles
router.get('/propuestas-disponibles', ventaController.listarPropuestasDisponibles)

// Consultar productos disponibles
router.get('/productos-disponibles', ventaController.listarProductosDisponibles)

// Registrar una venta
router.post('/', ventaController.registrarVenta)

export default router
