// Middleware para rutas no encontradas

export function notFound(req, res) {
  res.status(404).json({
    ok: false,
    mensaje: `Ruta no encontrada: ${req.method} ${req.originalUrl}`,
  })
}
