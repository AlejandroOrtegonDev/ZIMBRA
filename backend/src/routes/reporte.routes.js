// Reportes (vistas y procedimientos) y demostraciones de la BD

import { Router } from 'express'
import * as reportes from '../controllers/reporte.controller.js'
import { requierePermiso } from '../middlewares/auth.js'

const router = Router()

router.get('/reportes/dashboard', requierePermiso('reportes.ver'), reportes.dashboard)
// Procedimiento sp_reporte_ventas_mensual
router.get('/reportes/mensual', requierePermiso('reportes.ver'), reportes.reporteMensual)
router.get('/reportes/anios', requierePermiso('reportes.ver'), reportes.aniosDisponibles)
router.get('/reportes/campanas', requierePermiso('reportes.ver'), reportes.campanas)
router.get('/reportes/cartera', requierePermiso('reportes.ver'), reportes.cartera)
router.get('/reportes/auditoria', requierePermiso('auditoria.ver'), reportes.auditoria)

// Procedimiento sp_simular_error: error provocado + ROLLBACK (solo admin)
router.post('/transacciones/simular-error/:tipo', requierePermiso('auditoria.ver'), reportes.simularError)

export default router
