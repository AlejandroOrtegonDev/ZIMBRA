import * as OportunidadModel from '../models/oportunidad.model.js'
import ApiError from '../utils/ApiError.js'

// Validar identificadores
function validarId(id) {
  const numero = Number(id)

  if (!Number.isInteger(numero) || numero <= 0) {
    throw new ApiError(400, 'El ID no es válido')
  }

  return numero
}

// Listar oportunidades
export async function listarOportunidades(req, res) {
  const oportunidades = await OportunidadModel.obtenerOportunidades()

  res.json({
    ok: true,
    total: oportunidades.length,
    oportunidades,
  })
}

// Listar etapas comerciales
export async function listarEtapas(req, res) {
  const etapas = await OportunidadModel.obtenerEtapasVentas()

  res.json({
    ok: true,
    total: etapas.length,
    etapas,
  })
}

// Consultar oportunidad por ID
export async function obtenerOportunidad(req, res) {
  const id = validarId(req.params.id)

  const oportunidad =
    await OportunidadModel.obtenerOportunidadPorId(id)

  if (!oportunidad) {
    throw new ApiError(404, 'Oportunidad no encontrada')
  }

  res.json({
    ok: true,
    oportunidad,
  })
}

// Registrar oportunidad
export async function crearOportunidad(req, res) {
  const {
    id_cliente,
    id_vendedor,
    id_etapa,
    titulo,
    descripcion,
    valor_estimado,
    fecha_cierre,
  } = req.body

  if (!id_cliente || !titulo || !titulo.trim()) {
    throw new ApiError(400, 'El cliente y el título son obligatorios')
  }

  const valor = Number(valor_estimado ?? 0)

  if (!Number.isFinite(valor) || valor < 0) {
    throw new ApiError(400, 'El valor estimado no es válido')
  }

  try {
    const oportunidad = await OportunidadModel.Oportunidad.crear({
      id_cliente: validarId(id_cliente),
      id_vendedor: id_vendedor ? validarId(id_vendedor) : null,
      id_etapa: id_etapa ? validarId(id_etapa) : null,
      titulo: titulo.trim(),
      descripcion: descripcion || null,
      valor_estimado: valor,
      estado: 'abierta',
      fecha_cierre: fecha_cierre || null,
    })

    res.status(201).json({
      ok: true,
      mensaje: 'Oportunidad registrada correctamente',
      oportunidad,
    })
  } catch (error) {
    if (error.code === 'ER_NO_REFERENCED_ROW_2') {
      throw new ApiError(400, 'El cliente, vendedor o etapa no existe')
    }

    throw error
  }
}

// Actualizar oportunidad
export async function actualizarOportunidad(req, res) {
  const id = validarId(req.params.id)

  const existente =
    await OportunidadModel.obtenerOportunidadPorId(id)

  if (!existente) {
    throw new ApiError(404, 'Oportunidad no encontrada')
  }

  const camposPermitidos = [
    'id_cliente',
    'id_vendedor',
    'id_etapa',
    'titulo',
    'descripcion',
    'valor_estimado',
    'estado',
    'fecha_cierre',
  ]

  const datos = {}

  for (const campo of camposPermitidos) {
    if (req.body[campo] !== undefined) {
      datos[campo] = req.body[campo]
    }
  }

  if (Object.keys(datos).length === 0) {
    throw new ApiError(400, 'No se enviaron datos para actualizar')
  }

  if (
    datos.titulo !== undefined &&
    (typeof datos.titulo !== 'string' || !datos.titulo.trim())
  ) {
    throw new ApiError(400, 'El título no puede estar vacío')
  }

  if (datos.titulo) {
    datos.titulo = datos.titulo.trim()
  }

  if (
    datos.estado !== undefined &&
    !['abierta', 'ganada', 'perdida'].includes(datos.estado)
  ) {
    throw new ApiError(400, 'El estado de la oportunidad no es válido')
  }

  if (datos.valor_estimado !== undefined) {
    datos.valor_estimado = Number(datos.valor_estimado)

    if (
      !Number.isFinite(datos.valor_estimado) ||
      datos.valor_estimado < 0
    ) {
      throw new ApiError(400, 'El valor estimado no es válido')
    }
  }

  for (const campo of ['id_cliente', 'id_vendedor', 'id_etapa']) {
    if (datos[campo] !== undefined && datos[campo] !== null) {
      datos[campo] = validarId(datos[campo])
    }
  }

  try {
    const oportunidad = await OportunidadModel.Oportunidad.actualizar(
      id,
      datos,
    )

    res.json({
      ok: true,
      mensaje: 'Oportunidad actualizada correctamente',
      oportunidad,
    })
  } catch (error) {
    if (error.code === 'ER_NO_REFERENCED_ROW_2') {
      throw new ApiError(400, 'El cliente, vendedor o etapa no existe')
    }

    throw error
  }
}
