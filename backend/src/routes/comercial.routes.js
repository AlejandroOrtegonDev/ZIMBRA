// Proceso comercial: oportunidades, productos, propuestas, ventas y pagos

import { Router } from 'express'
import * as catalogo from '../controllers/catalogo.controller.js'
import * as propuestas from '../controllers/propuesta.controller.js'
import * as ventas from '../controllers/venta.controller.js'
import { requierePermiso } from '../middlewares/auth.js'

const router = Router()

// Oportunidades
router.get('/oportunidades', requierePermiso('oportunidades.ver'), catalogo.listarOportunidades)
router.post('/oportunidades', requierePermiso('oportunidades.gestionar'), catalogo.crearOportunidad)

// Catálogo de productos
router.get('/productos', requierePermiso('productos.ver'), catalogo.listarProductos)

// Vendedores y su desempeño
router.get('/vendedores', requierePermiso('vendedores.ver'), catalogo.listarDesempenoVendedores)
router.get('/vendedores/:id/clientes', requierePermiso('vendedores.ver'), catalogo.clientesDeVendedor)

// Propuestas
router.get('/propuestas', requierePermiso('propuestas.ver'), propuestas.listarPropuestas)
router.get('/propuestas/:id', requierePermiso('propuestas.ver'), propuestas.obtenerPropuesta)
router.post('/propuestas', requierePermiso('propuestas.crear'), propuestas.crearPropuesta)
router.patch('/propuestas/:id/estado', requierePermiso('propuestas.aprobar'), propuestas.cambiarEstadoPropuesta)
// Procedimiento sp_registrar_venta_desde_propuesta
router.post('/propuestas/:id/venta', requierePermiso('ventas.registrar'), propuestas.convertirEnVenta)

// Ventas y pagos
router.get('/ventas', requierePermiso('ventas.ver'), ventas.listarVentas)
router.get('/ventas/:id', requierePermiso('ventas.ver'), ventas.obtenerVenta)
// Procedimiento procesar_pago_venta
router.post('/ventas/:id/pagos', requierePermiso('pagos.registrar'), ventas.registrarPago)
router.patch('/ventas/:id/cancelar', requierePermiso('ventas.registrar'), ventas.cancelarVenta)
router.patch('/pagos/:idPago/estado', requierePermiso('pagos.registrar'), ventas.cambiarEstadoPago)

export default router
