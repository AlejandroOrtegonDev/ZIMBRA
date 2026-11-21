// Middleware central de manejo de errores
//
// Los errores de MySQL que provienen de reglas de negocio (SIGNAL en
// triggers y procedimientos, CHECK, llaves) se devuelven como 4xx con
// un mensaje claro. El resto se registra en consola y se responde 500
// sin exponer detalles internos.

const ERRORES_MYSQL = {
  1644: (e) => [400, e.sqlMessage],                                     // SIGNAL SQLSTATE '45000'
  3819: () => [400, 'Los datos no cumplen una restricción de la base de datos'], // CHECK
  1452: () => [400, 'Uno de los registros relacionados no existe'],    // llave foránea
  1451: () => [409, 'El registro tiene información relacionada y no se puede eliminar'],
  1062: () => [409, 'Ya existe un registro con ese valor único'],      // duplicado
  1213: () => [409, 'Otra operación estaba usando los mismos datos. Intente de nuevo.'], // deadlock
  1205: () => [409, 'Los datos están bloqueados por otra operación. Intente de nuevo.'], // lock wait timeout
  1142: () => [403, 'El usuario de base de datos no tiene permiso para esta operación'],
  1143: () => [403, 'El usuario de base de datos no tiene permiso para esta operación'],
}

export function errorHandler(error, req, res, next) {
  let estado = error.estado ?? 500
  let mensaje = error.message

  if (!error.estado && ERRORES_MYSQL[error.errno]) {
    ;[estado, mensaje] = ERRORES_MYSQL[error.errno](error)
  }

  if (!error.estado && error.type === 'entity.parse.failed') {
    estado = 400
    mensaje = 'El cuerpo de la petición no es un JSON válido'
  }

  if (estado >= 500) {
    console.error(error)
  }

  res.status(estado).json({
    ok: false,
    mensaje: estado >= 500 ? 'Error interno del servidor' : mensaje,
  })
}
