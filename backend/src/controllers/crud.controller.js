// Controlador CRUD genérico
// Fabrica listar / obtener / crear / actualizar / eliminar para cualquier modelo
// creado con crearModelo(). Los nombres de tabla y columna vienen del modelo,
// nunca del cliente HTTP.

import ApiError from '../utils/ApiError.js'

function aEntero(valor) {
  if (valor === undefined || valor === '') return undefined

  const numero = Number(valor)
  return Number.isInteger(numero) ? numero : undefined
}

export function crearControladorCrud(modelo, nombre) {
  async function listar(req, res) {
    const { limite, offset, ...resto } = req.query
    const paginacion = { limite: aEntero(limite), offset: aEntero(offset) }

    const filtros = Object.entries(resto).filter(([campo]) =>
      modelo.campos.includes(campo)
    )

    if (filtros.length > 1) {
      throw new ApiError(400, 'Usa un solo filtro por consulta')
    }

    const registros =
      filtros.length === 1
        ? await modelo.obtenerPor(filtros[0][0], filtros[0][1], paginacion)
        : await modelo.obtenerTodos(paginacion)

    res.json({
      ok: true,
      total: registros.length,
      [nombre]: registros,
    })
  }

  async function obtener(req, res) {
    const registro = await modelo.obtenerPorId(req.params.id)

    if (!registro) {
      throw new ApiError(404, `${nombre} no encontrado`)
    }

    res.json({ ok: true, [nombre]: registro })
  }

  async function crear(req, res) {
    if (!req.body || Object.keys(req.body).length === 0) {
      throw new ApiError(400, 'El cuerpo de la petición está vacío')
    }

    const registro = await modelo.crear(req.body)
    res.status(201).json({ ok: true, [nombre]: registro })
  }

  async function actualizar(req, res) {
    const existe = await modelo.obtenerPorId(req.params.id)

    if (!existe) {
      throw new ApiError(404, `${nombre} no encontrado`)
    }

    const registro = await modelo.actualizar(req.params.id, req.body ?? {})
    res.json({ ok: true, [nombre]: registro })
  }

  async function eliminar(req, res) {
    const eliminado = await modelo.eliminar(req.params.id)

    if (!eliminado) {
      throw new ApiError(404, `${nombre} no encontrado`)
    }

    res.json({ ok: true, mensaje: `${nombre} eliminado` })
  }

  return { listar, obtener, crear, actualizar, eliminar }
}
