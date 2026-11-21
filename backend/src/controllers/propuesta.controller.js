// Propuestas comerciales

import * as PropuestaModel from '../models/propuesta.model.js'
import ApiError from '../utils/ApiError.js'
import { validarId, validarOpcion } from '../utils/validar.js'

const ESTADOS = ['borrador', 'enviada', 'aceptada', 'rechazada']

export async function listarPropuestas(req, res) {
  const estado = req.query.estado ? validarOpcion(req.query.estado, ESTADOS, 'Estado') : undefined
  const propuestas = await PropuestaModel.listar({ estado })

  res.json({ ok: true, total: propuestas.length, propuestas })
}

export async function obtenerPropuesta(req, res) {
  const propuesta = await PropuestaModel.obtenerDetalle(validarId(req.params.id, 'ID de la propuesta'))

  if (!propuesta) throw new ApiError(404, 'Propuesta no encontrada')

  res.json({ ok: true, propuesta })
}

export async function crearPropuesta(req, res) {
  const idOportunidad = validarId(req.body.id_oportunidad, 'ID de la oportunidad')
  const lineas = Array.isArray(req.body.lineas) ? req.body.lineas : []

  if (lineas.length === 0) {
    throw new ApiError(400, 'La propuesta debe tener al menos un producto')
  }

  const productos = new Set()
  const lineasValidas = lineas.map((linea, i) => {
    const idProducto = validarId(linea.id_producto, `producto de la línea ${i + 1}`)
    const cantidad = Number(linea.cantidad)

    if (!Number.isInteger(cantidad) || cantidad <= 0 || cantidad > 100000) {
      throw new ApiError(400, `La cantidad de la línea ${i + 1} debe ser un entero entre 1 y 100000`)
    }
    if (productos.has(idProducto)) {
      throw new ApiError(400, 'No repita productos: ajuste la cantidad de la línea existente')
    }

    productos.add(idProducto)
    return { id_producto: idProducto, cantidad }
  })

  const observaciones = typeof req.body.observaciones === 'string' ? req.body.observaciones.trim().slice(0, 1000) : ''

  const idPropuesta = await PropuestaModel.crear(
    { id_oportunidad: idOportunidad, observaciones, lineas: lineasValidas, enviar: req.body.enviar === true },
    req.usuario.id_usuario,
  )

  res.status(201).json({
    ok: true,
    mensaje: req.body.enviar === true ? 'Propuesta creada y enviada' : 'Propuesta creada como borrador',
    propuesta: await PropuestaModel.obtenerDetalle(idPropuesta),
  })
}

export async function cambiarEstadoPropuesta(req, res) {
  const id = validarId(req.params.id, 'ID de la propuesta')
  const estado = validarOpcion(req.body.estado, ['enviada', 'aceptada', 'rechazada'], 'Estado')

  const actualizada = await PropuestaModel.cambiarEstado(id, estado, req.usuario.id_usuario)
  if (!actualizada) throw new ApiError(404, 'Propuesta no encontrada')

  res.json({
    ok: true,
    mensaje: `Propuesta ${estado}`,
    propuesta: await PropuestaModel.obtenerDetalle(id),
  })
}

// Llama al procedimiento sp_registrar_venta_desde_propuesta
export async function convertirEnVenta(req, res) {
  const id = validarId(req.params.id, 'ID de la propuesta')
  const venta = await PropuestaModel.convertirEnVenta(id, req.usuario.id_usuario)

  res.status(201).json({
    ok: true,
    mensaje: `Venta #${venta.id_venta} registrada a partir de la propuesta`,
    venta,
  })
}
