
import { Router } from 'express'
import * as seguimientoController from '../controllers/seguimiento.controller.js'

const router = Router()

// Consultar historial de actividades de un prospecto
router.get('/:id/actividades', seguimientoController.listarActividades)

// Registrar una tarea para un prospecto
router.post('/:id/tareas', seguimientoController.registrarTarea)

// Programar una llamada, reunión o cita
router.post('/:id/eventos', seguimientoController.registrarEvento)

export default router
