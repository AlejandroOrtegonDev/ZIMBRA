// Rutas de estado del servicio

import { Router } from 'express'
import * as healthController from '../controllers/health.controller.js'

const router = Router()

router.get('/', healthController.estadoGeneral)
router.get('/estado', healthController.estado)
router.get('/db', healthController.estadoBaseDatos)

export default router
