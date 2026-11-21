// Validaciones comunes de entrada

import ApiError from './ApiError.js'

export function validarId(valor, nombre = 'ID') {
  const numero = Number(valor)

  if (!Number.isInteger(numero) || numero <= 0) {
    throw new ApiError(400, `El ${nombre} no es válido`)
  }

  return numero
}

export function validarOpcion(valor, opciones, nombre) {
  if (!opciones.includes(valor)) {
    throw new ApiError(400, `${nombre} no válido. Opciones: ${opciones.join(', ')}`)
  }

  return valor
}

export function validarMonto(valor, nombre = 'valor') {
  const numero = Number(valor)

  if (!Number.isFinite(numero) || numero <= 0) {
    throw new ApiError(400, `El ${nombre} debe ser un número mayor que cero`)
  }

  return Math.round(numero * 100) / 100
}
