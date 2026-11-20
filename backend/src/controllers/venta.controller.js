
import * as VentaModel from '../models/venta.model.js'
import ApiError from '../utils/ApiError.js'

// Validar identificadores
function validarId(id) {
  const numero = Number(id)

  if (!Number.isInteger(numero) || numero <= 0) {
    throw new ApiError(400, 'El ID no es válido')
  }

  return numero
}

// Registrar una venta con sus productos
export async function registrarVenta(req, res) {
  const idPropuesta = validarId(req.body.id_propuesta)
  const { productos } = req.body

  try {
    const venta = await VentaModel.crearVentaConProductos(
      idPropuesta,
      productos,
    )

    res.status(201).json({
      ok: true,
      mensaje: 'Venta registrada e inventario actualizado correctamente',
      venta,
    })
  } catch (error) {
    const erroresValidacion = [
      'La propuesta no existe',
      'La propuesta debe estar aceptada',
      'Esta propuesta ya tiene una venta registrada',
      'Debes agregar al menos un producto',
    ]

    const errorInventario =
      error.message.includes('Stock insuficiente') ||
      error.message.includes('no existe o está inactivo')

    if (erroresValidacion.includes(error.message) || errorInventario) {
      throw new ApiError(400, error.message)
    }

    throw error
  }
}


 // Listar ventas registradas
export async function listarVentas(req, res) {
  const ventas = await VentaModel.obtenerVentas()

  res.json({
    ok: true,
    total: ventas.length,
    ventas,
  })
}

// Listar propuestas aceptadas sin venta
export async function listarPropuestasDisponibles(req, res) {
  const propuestas = await VentaModel.obtenerPropuestasDisponibles()

  res.json({
    ok: true,
    total: propuestas.length,
    propuestas,
  })
}

// Listar productos disponibles
export async function listarProductosDisponibles(req, res) {
  const productos = await VentaModel.obtenerProductosDisponibles()

  res.json({
    ok: true,
    total: productos.length,
    productos,
  })
}

