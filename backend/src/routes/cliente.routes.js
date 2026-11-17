import { Router } from 'express'
import * as clienteController from '../controllers/cliente.controller.js'

const router = Router()

// Clientes
router.get('/', clienteController.listarClientes)
router.post('/', clienteController.crearCliente)

// Rutas específicas: deben ir primero
router.get('/prospectos', clienteController.listarProspectos)
router.post('/prospectos', clienteController.crearProspecto)
router.get('/vendedores', clienteController.listarVendedores)


// Rutas dinámicas: deben ir después
router.get('/:id', clienteController.obtenerCliente)
router.put('/:id', clienteController.actualizarCliente)
router.delete('/:id', clienteController.desactivarCliente)

export default router