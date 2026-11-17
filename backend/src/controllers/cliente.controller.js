// Controladores de clientes

import * as ClienteModel from '../models/cliente.model.js'
import ApiError from '../utils/ApiError.js'

// Validar que el ID sea un número entero positivo
function validarId(id) {
  const numero = Number(id)

  if (!Number.isInteger(numero) || numero <= 0) {
    throw new ApiError(400, 'El ID del cliente no es válido')
  }

  return numero
}

// Obtener todos los clientes
export async function listarClientes(req, res) {
  const clientes = await ClienteModel.obtenerTodos()

  res.json({
    ok: true,
    total: clientes.length,
    clientes,
  })
}

// Obtener un cliente por ID
export async function obtenerCliente(req, res) {
  const id = validarId(req.params.id)
  const cliente = await ClienteModel.obtenerPorId(id)

  if (!cliente) {
    throw new ApiError(404, 'Cliente no encontrado')
  }

  res.json({
    ok: true,
    cliente,
  })
}

// Registrar un cliente
export async function crearCliente(req, res) {
  const {
    tipo_cliente,
    nombre,
    apellido,
    documento,
    correo,
    telefono,
    direccion,
  } = req.body

  if (!nombre || !nombre.trim()) {
    throw new ApiError(400, 'El nombre es obligatorio')
  }

  if (!['persona', 'empresa'].includes(tipo_cliente)) {
    throw new ApiError(400, 'El tipo de cliente no es válido')
  }

  if (
    correo &&
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)
  ) {
    throw new ApiError(400, 'El correo electrónico no es válido')
  }

  try {
    const cliente = await ClienteModel.crear({
      tipo_cliente,
      nombre: nombre.trim(),
      apellido,
      documento,
      correo,
      telefono,
      direccion,
      estado: 1,
    })

    res.status(201).json({
      ok: true,
      mensaje: 'Cliente registrado correctamente',
      cliente,
    })
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      throw new ApiError(409, 'El documento ya está registrado')
    }

    throw error
  }
}

// Actualizar información de un cliente
export async function actualizarCliente(req, res) {
  const id = validarId(req.params.id)
  const existente = await ClienteModel.obtenerPorId(id)

  if (!existente) {
    throw new ApiError(404, 'Cliente no encontrado')
  }

  const camposPermitidos = [
    'tipo_cliente',
    'nombre',
    'apellido',
    'documento',
    'correo',
    'telefono',
    'direccion',
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
    datos.tipo_cliente !== undefined &&
    !['persona', 'empresa'].includes(datos.tipo_cliente)
  ) {
    throw new ApiError(400, 'El tipo de cliente no es válido')
  }

  if (
    datos.nombre !== undefined &&
    (typeof datos.nombre !== 'string' || !datos.nombre.trim())
  ) {
    throw new ApiError(400, 'El nombre no puede estar vacío')
  }

  if (
    datos.correo &&
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(datos.correo)
  ) {
    throw new ApiError(400, 'El correo electrónico no es válido')
  }

  if (datos.nombre) {
    datos.nombre = datos.nombre.trim()
  }

  try {
    const cliente = await ClienteModel.actualizar(id, datos)

    res.json({
      ok: true,
      mensaje: 'Cliente actualizado correctamente',
      cliente,
    })
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      throw new ApiError(409, 'El documento ya está registrado')
    }

    throw error
  }
}

// Desactivar un cliente sin borrar su historial
export async function desactivarCliente(req, res) {
  const id = validarId(req.params.id)
  const existente = await ClienteModel.obtenerPorId(id)

  if (!existente) {
    throw new ApiError(404, 'Cliente no encontrado')
  }

  if (existente.estado === 0) {
    throw new ApiError(400, 'El cliente ya está desactivado')
  }

  const cliente = await ClienteModel.actualizar(id, {
    estado: 0,
  })

  res.json({
    ok: true,
    mensaje: 'Cliente desactivado correctamente',
    cliente,
  })
}


// Listar prospectos
export async function listarProspectos(req, res) {
  const prospectos = await ClienteModel.obtenerProspectos()

  res.json({
    ok: true,
    total: prospectos.length,
    prospectos,
  })
}

// Listar vendedores disponibles
export async function listarVendedores(req, res) {
  const vendedores = await ClienteModel.obtenerVendedores()

  res.json({
    ok: true,
    total: vendedores.length,
    vendedores,
  })
}


// Registrar un prospecto y asignar vendedor
export async function crearProspecto(req, res) {
  const {
    tipo_cliente,
    nombre,
    apellido,
    documento,
    correo,
    telefono,
    direccion,
    id_vendedor,
  } = req.body

  if (!nombre || typeof nombre !== 'string' || !nombre.trim()) {
    throw new ApiError(400, 'El nombre es obligatorio')
  }

  if (!['persona', 'empresa'].includes(tipo_cliente)) {
    throw new ApiError(400, 'El tipo de cliente no es válido')
  }

  if (!id_vendedor || !Number.isInteger(Number(id_vendedor)) || Number(id_vendedor) <= 0) {
    throw new ApiError(400, 'Debes seleccionar un vendedor válido')
  }

  if (
    correo &&
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)
  ) {
    throw new ApiError(400, 'El correo electrónico no es válido')
  }

  try {
    const prospecto = await ClienteModel.crearProspecto({
      tipo_cliente,
      nombre: nombre.trim(),
      apellido,
      documento,
      correo,
      telefono,
      direccion,
      id_vendedor: Number(id_vendedor),
    })

    res.status(201).json({
      ok: true,
      mensaje: 'Prospecto registrado y vendedor asignado correctamente',
      prospecto,
    })
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      throw new ApiError(409, 'El documento ya está registrado')
    }

    if (error.message.includes('vendedor seleccionado') ||
        error.message.includes('categoría Prospecto')) {
      throw new ApiError(400, error.message)
    }

    throw error
  }
}
