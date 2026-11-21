// Consultas de autenticación: registro, login y permisos

import pool, { transaccionComoUsuario } from '../config/database.js'

export async function buscarPorCorreo(correo) {
  const [filas] = await pool.execute(
    `SELECT id_usuario, nombre, correo, password, estado
     FROM usuarios
     WHERE correo = ?
     LIMIT 1`,
    [correo],
  )
  return filas[0] ?? null
}

// Rol y lista de permisos de un usuario
export async function obtenerAcceso(idUsuario) {
  const [roles] = await pool.execute(
    `SELECT r.nombre
     FROM usuarios_roles ur
     JOIN roles r ON r.id_rol = ur.id_rol
     WHERE ur.id_usuario = ?
     ORDER BY FIELD(r.nombre, 'admin', 'user', 'user_demo')
     LIMIT 1`,
    [idUsuario],
  )

  const [permisos] = await pool.execute(
    `SELECT DISTINCT p.nombre
     FROM usuarios_roles ur
     JOIN roles_permisos rp ON rp.id_rol = ur.id_rol
     JOIN permisos p ON p.id_permiso = rp.id_permiso
     WHERE ur.id_usuario = ?
     ORDER BY p.nombre`,
    [idUsuario],
  )

  return {
    rol: roles[0]?.nombre ?? null,
    permisos: permisos.map((p) => p.nombre),
  }
}

// Registro: usuario + rol + configuración en una sola transacción.
// Los usuarios que se registran solos reciben el rol de solo lectura
// (user_demo); un administrador puede subirles el nivel después.
export async function registrar({ nombre, correo, passwordHash }) {
  return transaccionComoUsuario(null, async (conexion) => {
    const [resultado] = await conexion.execute(
      'INSERT INTO usuarios (nombre, correo, password, estado) VALUES (?, ?, ?, 1)',
      [nombre, correo, passwordHash],
    )
    const idUsuario = resultado.insertId

    const [roles] = await conexion.execute("SELECT id_rol FROM roles WHERE nombre = 'user_demo'")
    if (roles.length === 0) {
      throw new Error('No existe el rol user_demo')
    }

    await conexion.execute('INSERT INTO usuarios_roles (id_usuario, id_rol) VALUES (?, ?)', [idUsuario, roles[0].id_rol])
    await conexion.execute('INSERT INTO configuracion_usuario (id_usuario) VALUES (?)', [idUsuario])

    return idUsuario
  })
}
