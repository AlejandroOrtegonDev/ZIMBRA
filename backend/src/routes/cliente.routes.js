// Rutas de clientes

import { Router } from 'express'
import * as clienteController from '../controllers/cliente.controller.js'

const router = Router()

router.get('/', clienteController.listarClientes)
router.get('/:id', clienteController.obtenerCliente)

export default router
