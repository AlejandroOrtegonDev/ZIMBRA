// Endpoints de negocio (no son CRUD plano: agregan varias tablas o aplican reglas)

import pool from '../config/database.js'
import ApiError from '../utils/ApiError.js'

const ESTADOS_TAREA = ['pendiente', 'en_proceso', 'completada', 'cancelada']

async function uno(sql, valores = []) {
  const [filas] = await pool.query(sql, valores)
  return filas[0] ?? null
}

async function varios(sql, valores = []) {
  const [filas] = await pool.query(sql, valores)
  return filas
}

// GET /api/dashboard -> indicadores generales del CRM
export async function dashboard(req, res) {
  const resumen = await uno(`
    SELECT
      (SELECT COUNT(*) FROM clientes WHERE estado = 1)                       AS clientes_activos,
      (SELECT COUNT(*) FROM oportunidades WHERE estado = 'abierta')          AS oportunidades_abiertas,
      (SELECT IFNULL(SUM(valor_estimado), 0) FROM oportunidades
        WHERE estado = 'abierta')                                            AS pipeline_valor,
      (SELECT COUNT(*) FROM oportunidades WHERE estado = 'ganada')           AS oportunidades_ganadas,
      (SELECT COUNT(*) FROM oportunidades WHERE estado = 'perdida')          AS oportunidades_perdidas,
      (SELECT IFNULL(SUM(total), 0) FROM ventas WHERE estado <> 'cancelada') AS ventas_total,
      (SELECT IFNULL(SUM(valor), 0) FROM pagos WHERE estado = 'aprobado')    AS cobrado,
      (SELECT COUNT(*) FROM tareas
        WHERE estado IN ('pendiente', 'en_proceso'))                         AS tareas_abiertas,
      (SELECT COUNT(*) FROM seguimientos)                                    AS seguimientos,
      (SELECT COUNT(*) FROM campanas_marketing WHERE estado = 'activa')      AS campanas_activas
  `)

  const cerradas = resumen.oportunidades_ganadas + resumen.oportunidades_perdidas
  const tasaConversion = cerradas > 0
    ? Number(((resumen.oportunidades_ganadas / cerradas) * 100).toFixed(2))
    : 0

  res.json({
    ok: true,
    indicadores: {
      ...resumen,
      tasa_conversion: tasaConversion,
      por_cobrar: Number(resumen.ventas_total) - Number(resumen.cobrado),
    },
  })
}

// GET /api/oportunidades/pipeline -> oportunidades abiertas por etapa
export async function pipelineOportunidades(req, res) {
  const etapas = await varios(`
    SELECT e.id_etapa,
           e.nombre,
           e.orden,
           COUNT(o.id_oportunidad)                     AS oportunidades,
           IFNULL(SUM(o.valor_estimado), 0)            AS valor_total
    FROM etapas_ventas e
    LEFT JOIN oportunidades o
           ON o.id_etapa = e.id_etapa AND o.estado = 'abierta'
    GROUP BY e.id_etapa, e.nombre, e.orden
    ORDER BY e.orden
  `)

  res.json({ ok: true, etapas })
}

// PATCH /api/oportunidades/:id/etapa  { "id_etapa": 4 }
export async function moverEtapa(req, res) {
  const idOportunidad = Number(req.params.id)
  const idEtapa = Number(req.body?.id_etapa)

  if (!Number.isInteger(idEtapa)) {
    throw new ApiError(400, 'id_etapa es obligatorio y debe ser numérico')
  }

  const oportunidad = await uno(
    'SELECT * FROM oportunidades WHERE id_oportunidad = ?',
    [idOportunidad]
  )

  if (!oportunidad) {
    throw new ApiError(404, 'Oportunidad no encontrada')
  }

  const etapa = await uno('SELECT * FROM etapas_ventas WHERE id_etapa = ?', [idEtapa])

  if (!etapa) {
    throw new ApiError(400, 'La etapa indicada no existe')
  }

  await pool.query('UPDATE oportunidades SET id_etapa = ? WHERE id_oportunidad = ?', [
    idEtapa,
    idOportunidad,
  ])

  await pool.query('INSERT INTO oportunidades_detalle (id_oportunidad, descripcion) VALUES (?, ?)', [
    idOportunidad,
    `Cambio de etapa: ${oportunidad.id_etapa ?? '-'} -> ${idEtapa} (${etapa.nombre})`,
  ])

  const actualizada = await uno(
    'SELECT * FROM oportunidades WHERE id_oportunidad = ?',
    [idOportunidad]
  )

  res.json({ ok: true, oportunidad: actualizada })
}

// GET /api/clientes/:id/detalle -> cliente con todo su contexto comercial
export async function detalleCliente(req, res) {
  const id = Number(req.params.id)

  const cliente = await uno('SELECT * FROM clientes WHERE id_cliente = ?', [id])

  if (!cliente) {
    throw new ApiError(404, 'Cliente no encontrado')
  }

  const [contactos, categorias, asignaciones, oportunidades, ventas] = await Promise.all([
    varios('SELECT * FROM contactos WHERE id_cliente = ?', [id]),
    varios(
      `SELECT cc.id_categoria, cat.nombre
       FROM clientes_categorias cc
       JOIN categorias_clientes cat ON cat.id_categoria = cc.id_categoria
       WHERE cc.id_cliente = ?`,
      [id]
    ),
    varios(
      `SELECT a.id_asignacion, a.fecha_asignacion, v.id_vendedor, v.codigo, u.nombre AS vendedor
       FROM asignaciones_clientes a
       JOIN vendedores v ON v.id_vendedor = a.id_vendedor
       JOIN usuarios u   ON u.id_usuario = v.id_usuario
       WHERE a.id_cliente = ?
       ORDER BY a.fecha_asignacion DESC`,
      [id]
    ),
    varios(
      `SELECT o.*, e.nombre AS etapa
       FROM oportunidades o
       LEFT JOIN etapas_ventas e ON e.id_etapa = o.id_etapa
       WHERE o.id_cliente = ?
       ORDER BY o.fecha_creacion DESC`,
      [id]
    ),
    varios(
      'SELECT * FROM ventas WHERE id_cliente = ? ORDER BY fecha DESC',
      [id]
    ),
  ])

  res.json({
    ok: true,
    cliente,
    contactos,
    categorias,
    asignaciones,
    oportunidades,
    ventas,
    resumen: {
      contactos: contactos.length,
      oportunidades_abiertas: oportunidades.filter((o) => o.estado === 'abierta').length,
      total_vendido: ventas
        .filter((v) => v.estado !== 'cancelada')
        .reduce((suma, v) => suma + Number(v.total), 0),
    },
  })
}

// GET /api/ventas/:id/detalle -> venta con productos, pagos y cliente
export async function detalleVenta(req, res) {
  const id = Number(req.params.id)

  const venta = await uno('SELECT * FROM ventas WHERE id_venta = ?', [id])

  if (!venta) {
    throw new ApiError(404, 'Venta no encontrada')
  }

  const [productos, pagos, cliente] = await Promise.all([
    varios(
      `SELECT vp.*, p.nombre AS producto
       FROM ventas_productos vp
       JOIN productos p ON p.id_producto = vp.id_producto
       WHERE vp.id_venta = ?`,
      [id]
    ),
    varios('SELECT * FROM pagos WHERE id_venta = ? ORDER BY fecha', [id]),
    uno('SELECT * FROM clientes WHERE id_cliente = ?', [venta.id_cliente]),
  ])

  const pagado = pagos
    .filter((p) => p.estado === 'aprobado')
    .reduce((suma, p) => suma + Number(p.valor), 0)

  res.json({
    ok: true,
    venta,
    cliente,
    productos,
    pagos,
    resumen: {
      total: Number(venta.total),
      pagado,
      saldo: Number(venta.total) - pagado,
    },
  })
}

// GET /api/productos/:id/detalle -> producto con atributos y categorías
export async function detalleProducto(req, res) {
  const id = Number(req.params.id)

  const producto = await uno('SELECT * FROM productos WHERE id_producto = ?', [id])

  if (!producto) {
    throw new ApiError(404, 'Producto no encontrado')
  }

  const [detalles, categorias] = await Promise.all([
    varios('SELECT * FROM productos_detalles WHERE id_producto = ?', [id]),
    varios(
      `SELECT cp.id_categoria, c.nombre
       FROM productos_categorias cp
       JOIN categorias_productos c ON c.id_categoria = cp.id_categoria
       WHERE cp.id_producto = ?`,
      [id]
    ),
  ])

  res.json({ ok: true, producto, detalles, categorias })
}

// PATCH /api/tareas/:id/estado  { "estado": "completada" }
export async function cambiarEstadoTarea(req, res) {
  const id = Number(req.params.id)
  const estado = req.body?.estado

  if (!ESTADOS_TAREA.includes(estado)) {
    throw new ApiError(400, `estado debe ser uno de: ${ESTADOS_TAREA.join(', ')}`)
  }

  const tarea = await uno('SELECT * FROM tareas WHERE id_tarea = ?', [id])

  if (!tarea) {
    throw new ApiError(404, 'Tarea no encontrada')
  }

  await pool.query('UPDATE tareas SET estado = ? WHERE id_tarea = ?', [estado, id])

  res.json({ ok: true, tarea: { ...tarea, estado } })
}

// PATCH /api/notificaciones/:id/leida
export async function marcarNotificacionLeida(req, res) {
  const id = Number(req.params.id)

  const notificacion = await uno(
    'SELECT * FROM notificaciones WHERE id_notificacion = ?',
    [id]
  )

  if (!notificacion) {
    throw new ApiError(404, 'Notificación no encontrada')
  }

  await pool.query('UPDATE notificaciones SET estado = ? WHERE id_notificacion = ?', [
    'leida',
    id,
  ])

  res.json({ ok: true, notificacion: { ...notificacion, estado: 'leida' } })
}

// GET /api/roles/matriz -> qué puede hacer cada rol
// El esquema nuevo no tiene la tabla matriz_permisos: la matriz se arma
// cruzando roles y permisos con roles_permisos.
export async function matrizPermisos(req, res) {
  const [roles, permisos, asignaciones] = await Promise.all([
    varios('SELECT id_rol, nombre, descripcion FROM roles ORDER BY id_rol'),
    varios('SELECT id_permiso, nombre, descripcion FROM permisos ORDER BY id_permiso'),
    varios('SELECT id_rol, id_permiso FROM roles_permisos'),
  ])

  const concedidos = new Set(asignaciones.map((a) => `${a.id_rol}:${a.id_permiso}`))

  const matriz = roles.map((rol) => ({
    ...rol,
    permisos: permisos.map((permiso) => ({
      ...permiso,
      asignado: concedidos.has(`${rol.id_rol}:${permiso.id_permiso}`),
    })),
  }))

  res.json({ ok: true, matriz })
}

// GET /api/usuarios/:id/permisos -> rol y permisos efectivos del usuario
export async function permisosUsuario(req, res) {
  const id = Number(req.params.id)

  const usuario = await uno(
    `SELECT u.id_usuario, u.nombre, u.correo, u.estado,
            r.id_rol, r.nombre AS rol, r.descripcion AS descripcion_rol
     FROM usuarios u
     LEFT JOIN usuarios_roles ur ON ur.id_usuario = u.id_usuario
     LEFT JOIN roles r           ON r.id_rol = ur.id_rol
     WHERE u.id_usuario = ?`,
    [id]
  )

  if (!usuario) {
    throw new ApiError(404, 'Usuario no encontrado')
  }

  const permisos = usuario.id_rol
    ? await varios(
        `SELECT p.id_permiso, p.nombre, p.descripcion
         FROM roles_permisos rp
         JOIN permisos p ON p.id_permiso = rp.id_permiso
         WHERE rp.id_rol = ?
         ORDER BY p.id_permiso`,
        [usuario.id_rol]
      )
    : []

  res.json({ ok: true, usuario, permisos })
}
