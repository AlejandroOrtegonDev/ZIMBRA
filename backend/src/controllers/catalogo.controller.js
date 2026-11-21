// Oportunidades, productos y vendedores (datos que usan los formularios)

import * as OportunidadModel from '../models/oportunidad.model.js'
import * as ProductoModel from '../models/producto.model.js'
import * as VendedorModel from '../models/vendedor.model.js'
import ApiError from '../utils/ApiError.js'
import { validarId, validarOpcion } from '../utils/validar.js'

export async function listarOportunidades(req, res) {
  const estado = req.query.estado
    ? validarOpcion(req.query.estado, ['abierta', 'ganada', 'perdida'], 'Estado')
    : undefined
  const idCliente = req.query.id_cliente ? validarId(req.query.id_cliente, 'ID del cliente') : undefined

  const oportunidades = await OportunidadModel.listar({ estado, id_cliente: idCliente })
  res.json({ ok: true, total: oportunidades.length, oportunidades })
}

export async function crearOportunidad(req, res) {
  const idCliente = validarId(req.body.id_cliente, 'ID del cliente')
  const titulo = typeof req.body.titulo === 'string' ? req.body.titulo.trim() : ''

  if (titulo.length < 3) throw new ApiError(400, 'El título debe tener al menos 3 caracteres')

  const valor = req.body.valor_estimado === undefined || req.body.valor_estimado === ''
    ? 0
    : Number(req.body.valor_estimado)

  if (!Number.isFinite(valor) || valor < 0) throw new ApiError(400, 'El valor estimado no es válido')

  if (req.body.fecha_cierre && Number.isNaN(Date.parse(req.body.fecha_cierre))) {
    throw new ApiError(400, 'La fecha de cierre no es válida')
  }

  const resultado = await OportunidadModel.crear(
    {
      id_cliente: idCliente,
      titulo: titulo.slice(0, 200),
      descripcion: typeof req.body.descripcion === 'string' ? req.body.descripcion.trim() : null,
      valor_estimado: valor,
      fecha_cierre: req.body.fecha_cierre || null,
    },
    req.usuario.id_usuario,
  )

  if (resultado.error) throw new ApiError(400, resultado.error)

  res.status(201).json({ ok: true, mensaje: 'Oportunidad creada', id_oportunidad: resultado.id_oportunidad })
}

export async function listarProductos(req, res) {
  const productos = await ProductoModel.listarActivos()
  res.json({ ok: true, total: productos.length, productos })
}

export async function listarDesempenoVendedores(req, res) {
  const vendedores = await VendedorModel.listarDesempeno()
  res.json({ ok: true, total: vendedores.length, vendedores })
}

export async function clientesDeVendedor(req, res) {
  const clientes = await VendedorModel.clientesAsignados(validarId(req.params.id, 'ID del vendedor'))
  res.json({ ok: true, total: clientes.length, clientes })
}
