// Middleware central de manejo de errores

export function errorHandler(error, req, res, next) {
  const estado = error.estado ?? 500

  if (estado >= 500) {
    console.error(error)
  }

  res.status(estado).json({
    ok: false,
    mensaje:
      estado >= 500 ? 'Error interno del servidor' : error.message,
  })
}
