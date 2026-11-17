// Error de aplicación con código HTTP asociado

export default class ApiError extends Error {
  constructor(estado, mensaje) {
    super(mensaje)
    this.name = 'ApiError'
    this.estado = estado
  }
}
