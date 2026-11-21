// Registro, inicio de sesión y perfil

import bcrypt from 'bcryptjs'
import * as AuthModel from '../models/auth.model.js'
import ApiError from '../utils/ApiError.js'
import { crearToken } from '../utils/token.js'

const CORREO_VALIDO = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

async function construirSesion(usuario) {
  const acceso = await AuthModel.obtenerAcceso(usuario.id_usuario)

  const datos = {
    id_usuario: usuario.id_usuario,
    nombre: usuario.nombre,
    correo: usuario.correo,
    rol: acceso.rol,
    permisos: acceso.permisos,
  }

  return { token: crearToken(datos), usuario: datos }
}

export async function registro(req, res) {
  const nombre = typeof req.body.nombre === 'string' ? req.body.nombre.trim() : ''
  const correo = typeof req.body.correo === 'string' ? req.body.correo.trim().toLowerCase() : ''
  const password = typeof req.body.password === 'string' ? req.body.password : ''

  if (nombre.length < 3) {
    throw new ApiError(400, 'El nombre debe tener al menos 3 caracteres')
  }
  if (!CORREO_VALIDO.test(correo)) {
    throw new ApiError(400, 'El correo electrónico no es válido')
  }
  if (password.length < 8) {
    throw new ApiError(400, 'La contraseña debe tener al menos 8 caracteres')
  }

  if (await AuthModel.buscarPorCorreo(correo)) {
    throw new ApiError(409, 'Ya existe una cuenta con ese correo')
  }

  const passwordHash = await bcrypt.hash(password, 10)

  let idUsuario
  try {
    idUsuario = await AuthModel.registrar({ nombre, correo, passwordHash })
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') throw new ApiError(409, 'Ya existe una cuenta con ese correo')
    throw error
  }

  const sesion = await construirSesion({ id_usuario: idUsuario, nombre, correo })

  res.status(201).json({
    ok: true,
    mensaje: 'Cuenta creada correctamente',
    ...sesion,
  })
}

export async function login(req, res) {
  const correo = typeof req.body.correo === 'string' ? req.body.correo.trim().toLowerCase() : ''
  const password = typeof req.body.password === 'string' ? req.body.password : ''

  if (!correo || !password) {
    throw new ApiError(400, 'Ingrese su correo y contraseña')
  }

  const usuario = await AuthModel.buscarPorCorreo(correo)

  // Mismo mensaje si el correo no existe o la clave es incorrecta:
  // no se revela qué cuentas existen.
  if (!usuario || !(await bcrypt.compare(password, usuario.password))) {
    throw new ApiError(401, 'Correo o contraseña incorrectos')
  }

  if (Number(usuario.estado) !== 1) {
    throw new ApiError(403, 'La cuenta está desactivada. Contacte al administrador.')
  }

  const sesion = await construirSesion(usuario)

  res.json({
    ok: true,
    mensaje: 'Sesión iniciada',
    ...sesion,
  })
}

export function perfil(req, res) {
  res.json({ ok: true, usuario: req.usuario })
}
