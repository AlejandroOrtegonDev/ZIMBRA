
import * as SeguimientoModel from '../models/seguimiento.model.js'
import ApiError from '../utils/ApiError.js'

// Validar ID del prospecto
function validarId(id) {
  const numero = Number(id)

  if (!Number.isInteger(numero) || numero <= 0) {
    throw new ApiError(400, 'El ID del prospecto no es válido')
  }

  return numero
}

// Consultar historial de actividades
export async function listarActividades(req, res) {
  const idCliente = validarId(req.params.id)

  const actividades = await SeguimientoModel.obtenerActividades(idCliente)

  res.json({
    ok: true,
    total: actividades.length,
    actividades,
  })
}

// Registrar una tarea
export async function registrarTarea(req, res) {
  const idCliente = validarId(req.params.id)
  const { titulo, descripcion, fecha_limite } = req.body

  if (!titulo || typeof titulo !== 'string' || !titulo.trim()) {
    throw new ApiError(400, 'El título de la tarea es obligatorio')
  }

  if (
    fecha_limite &&
    Number.isNaN(Date.parse(fecha_limite))
  ) {
    throw new ApiError(400, 'La fecha límite no es válida')
  }

  try {
    const tarea = await SeguimientoModel.crearTarea(idCliente, {
      titulo: titulo.trim(),
      descripcion,
      fecha_limite: fecha_limite || null,
    })

    res.status(201).json({
      ok: true,
      mensaje: 'Tarea registrada correctamente',
      tarea,
    })
  } catch (error) {
    if (error.message.includes('vendedor activo asignado')) {
      throw new ApiError(400, error.message)
    }

    throw error
  }
}

// Programar una llamada, reunión o cita
export async function registrarEvento(req, res) {
  const idCliente = validarId(req.params.id)

  const {
    titulo,
    descripcion,
    fecha_inicio,
    fecha_fin,
    ubicacion,
    tipo,
  } = req.body

  if (!titulo || typeof titulo !== 'string' || !titulo.trim()) {
    throw new ApiError(400, 'El título del evento es obligatorio')
  }

  if (!fecha_inicio || !fecha_fin) {
    throw new ApiError(400, 'Las fechas de inicio y fin son obligatorias')
  }

  if (
    Number.isNaN(Date.parse(fecha_inicio)) ||
    Number.isNaN(Date.parse(fecha_fin))
  ) {
    throw new ApiError(400, 'Las fechas del evento no son válidas')
  }

  if (new Date(fecha_fin) <= new Date(fecha_inicio)) {
    throw new ApiError(400, 'La fecha de fin debe ser posterior a la de inicio')
  }

  const tiposPermitidos = ['reunion', 'llamada', 'cita', 'otro']

  if (tipo && !tiposPermitidos.includes(tipo)) {
    throw new ApiError(400, 'El tipo de evento no es válido')
  }

  try {
    const evento = await SeguimientoModel.crearEvento(idCliente, {
      titulo: titulo.trim(),
      descripcion,
      fecha_inicio,
      fecha_fin,
      ubicacion,
      tipo,
    })

    res.status(201).json({
      ok: true,
      mensaje: 'Evento programado correctamente',
      evento,
    })
  } catch (error) {
    if (error.message.includes('vendedor activo asignado')) {
      throw new ApiError(400, error.message)
    }

    throw error
  }
}
