// Fábrica de rutas REST a partir de un modelo
//
// crearRutasCrud(Cliente, 'cliente', {
//   antes: [{ metodo: 'get', ruta: '/resumen', handler: fn }],
// })
//
// Las rutas de "antes" se registran primero, para que /resumen no sea
// capturada por /:id.

import { Router } from 'express'
import { crearControladorCrud } from '../controllers/crud.controller.js'

export function crearRutasCrud(modelo, nombre, { antes = [] } = {}) {
  const router = Router()
  const controlador = crearControladorCrud(modelo, nombre)

  for (const { metodo = 'get', ruta, handler } of antes) {
    router[metodo](ruta, handler)
  }

  router.get('/', controlador.listar)
  router.get('/:id', controlador.obtener)
  router.post('/', controlador.crear)
  router.put('/:id', controlador.actualizar)
  router.patch('/:id', controlador.actualizar)
  router.delete('/:id', controlador.eliminar)

  return router
}
