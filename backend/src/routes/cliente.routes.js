import { Router } from 'express'
import * as clienteController from '../controllers/cliente.controller.js'
import { requierePermiso } from '../middlewares/auth.js'

const router = Router()

// Clientes
router.get('/', requierePermiso('clientes.ver'), clienteController.listarClientes)
router.post('/', requierePermiso('clientes.crear'), clienteController.crearCliente)

// Rutas específicas: deben ir primero
router.get('/prospectos', requierePermiso('prospectos.ver'), clienteController.listarProspectos)
router.post('/prospectos', requierePermiso('prospectos.crear'), clienteController.crearProspecto)
router.get('/vendedores', requierePermiso('vendedores.ver', 'prospectos.crear'), clienteController.listarVendedores)


// Rutas dinámicas: deben ir después
router.get('/:id', requierePermiso('clientes.ver'), clienteController.obtenerCliente)
router.put('/:id', requierePermiso('clientes.editar'), clienteController.actualizarCliente)
router.delete('/:id', requierePermiso('clientes.desactivar'), clienteController.desactivarCliente)

export default router
