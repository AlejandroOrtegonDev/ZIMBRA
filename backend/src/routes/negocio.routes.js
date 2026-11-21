// Endpoints de negocio que no encajan en un CRUD plano:
// agregan varias tablas o aplican reglas de la base de datos.

import { Router } from 'express'
import * as negocio from '../controllers/negocio.controller.js'

const router = Router()

// Tablero con indicadores calculados sobre tablas base
router.get('/dashboard', negocio.dashboard)

// Oportunidades por etapa y cambio de etapa
router.get('/oportunidades/pipeline', negocio.pipelineOportunidades)
router.patch('/oportunidades/:id/etapa', negocio.moverEtapa)

// Fichas con información relacionada
router.get('/clientes/:id/detalle', negocio.detalleCliente)
router.get('/ventas/:id/detalle', negocio.detalleVenta)
router.get('/productos/:id/detalle', negocio.detalleProducto)

// Acciones puntuales
router.patch('/tareas/:id/estado', negocio.cambiarEstadoTarea)
router.patch('/notificaciones/:id/leida', negocio.marcarNotificacionLeida)

// Permisos
router.get('/roles/matriz', negocio.matrizPermisos)
router.get('/usuarios/:id/permisos', negocio.permisosUsuario)

export default router
