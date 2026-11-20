
import { Router } from 'express'
import * as oportunidadController from '../controllers/oportunidad.controller.js'

const router = Router()

// Consultar todas las oportunidades
router.get('/', oportunidadController.listarOportunidades)

// Consultar las etapas comerciales
router.get('/etapas', oportunidadController.listarEtapas)

// Registrar una oportunidad
router.post('/', oportunidadController.crearOportunidad)

// Consultar una oportunidad por ID
router.get('/:id', oportunidadController.obtenerOportunidad)

// Actualizar una oportunidad
router.put('/:id', oportunidadController.actualizarOportunidad)

export default router
