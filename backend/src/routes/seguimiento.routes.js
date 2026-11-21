
import { Router } from 'express'
import * as seguimientoController from '../controllers/seguimiento.controller.js'
import { requierePermiso } from '../middlewares/auth.js'

const router = Router()

// Consultar historial de actividades de un prospecto
router.get('/:id/actividades', requierePermiso('prospectos.ver'), seguimientoController.listarActividades)

// Registrar una tarea para un prospecto
router.post('/:id/tareas', requierePermiso('seguimientos.registrar'), seguimientoController.registrarTarea)

// Programar una llamada, reunión o cita
router.post('/:id/eventos', requierePermiso('seguimientos.registrar'), seguimientoController.registrarEvento)

export default router
