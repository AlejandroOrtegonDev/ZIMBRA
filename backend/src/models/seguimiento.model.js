
import pool from '../config/database.js'

// Obtener el usuario correspondiente al vendedor asignado
async function obtenerUsuarioResponsable(idCliente) {
  const [filas] = await pool.execute(`
    SELECT u.id_usuario
    FROM clientes c
    INNER JOIN clientes_categorias cc
      ON c.id_cliente = cc.id_cliente
    INNER JOIN categorias_clientes cat
      ON cc.id_categoria = cat.id_categoria
    INNER JOIN asignaciones_clientes ac
      ON c.id_cliente = ac.id_cliente
    INNER JOIN vendedores v
      ON ac.id_vendedor = v.id_vendedor
    INNER JOIN usuarios u
      ON v.id_usuario = u.id_usuario
    WHERE c.id_cliente = ?
      AND cat.nombre = 'Prospecto'
      AND c.estado = 1
      AND v.estado = 1
      AND u.estado = 1
    ORDER BY ac.id_asignacion DESC
    LIMIT 1
  `, [idCliente])

  return filas[0]?.id_usuario ?? null
}

// Consultar tareas y eventos de un prospecto
export async function obtenerActividades(idCliente) {
  const [tareas] = await pool.execute(`
    SELECT
      id_tarea AS id_actividad,
      'tarea' AS tipo_actividad,
      titulo,
      descripcion,
      fecha_limite AS fecha_actividad,
      estado
    FROM tareas
    WHERE id_cliente = ?
    ORDER BY fecha_creacion DESC
  `, [idCliente])

  const [eventos] = await pool.execute(`
    SELECT
      id_evento AS id_actividad,
      tipo AS tipo_actividad,
      titulo,
      descripcion,
      fecha_inicio AS fecha_actividad,
      estado
    FROM eventos
    WHERE id_cliente = ?
    ORDER BY fecha_inicio DESC
  `, [idCliente])

  return [...tareas, ...eventos].sort(
    (a, b) => new Date(b.fecha_actividad) - new Date(a.fecha_actividad)
  )
}

// Registrar una tarea para un prospecto
export async function crearTarea(idCliente, datos) {
  const idUsuario = await obtenerUsuarioResponsable(idCliente)

  if (!idUsuario) {
    throw new Error('El prospecto no tiene un vendedor activo asignado')
  }

  const [resultado] = await pool.execute(`
    INSERT INTO tareas (
      id_usuario,
      id_cliente,
      titulo,
      descripcion,
      fecha_limite
    )
    VALUES (?, ?, ?, ?, ?)
  `, [
    idUsuario,
    idCliente,
    datos.titulo,
    datos.descripcion || null,
    datos.fecha_limite || null,
  ])

  return {
    id_tarea: resultado.insertId,
    id_cliente: idCliente,
    id_usuario: idUsuario,
  }
}

// Programar un evento para un prospecto
export async function crearEvento(idCliente, datos) {
  const idUsuario = await obtenerUsuarioResponsable(idCliente)

  if (!idUsuario) {
    throw new Error('El prospecto no tiene un vendedor activo asignado')
  }

  const [resultado] = await pool.execute(`
    INSERT INTO eventos (
      id_usuario,
      id_cliente,
      titulo,
      descripcion,
      fecha_inicio,
      fecha_fin,
      ubicacion,
      tipo
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `, [
    idUsuario,
    idCliente,
    datos.titulo,
    datos.descripcion || null,
    datos.fecha_inicio,
    datos.fecha_fin,
    datos.ubicacion || null,
    datos.tipo || 'otro',
  ])

  return {
    id_evento: resultado.insertId,
    id_cliente: idCliente,
    id_usuario: idUsuario,
  }
}
