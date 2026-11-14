// Controladores de clientes

import * as ClienteModel from '../models/cliente.model.js'
import ApiError from '../utils/ApiError.js'

export async function listarClientes(req, res) {
  const clientes = await ClienteModel.obtenerTodos()

  res.json({
    ok: true,
    total: clientes.length,
    clientes,
  })
}

export async function obtenerCliente(req, res) {
  const cliente = await ClienteModel.obtenerPorId(req.params.id)

  if (!cliente) {
    throw new ApiError(404, 'Cliente no encontrado')
  }

  res.json({
    ok: true,
    cliente,
  })
}
