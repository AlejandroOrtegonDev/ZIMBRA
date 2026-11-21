// Oportunidades, etapas, seguimientos y tareas

import { crearModelo } from './base.model.js'
import pool, { ejecutarComoUsuario } from '../config/database.js'

export const EtapaVenta = crearModelo('etapas_ventas', 'id_etapa', ['nombre', 'orden'])

export const Oportunidad = crearModelo('oportunidades', 'id_oportunidad', [
  'id_cliente',
  'id_vendedor',
  'id_etapa',
  'titulo',
  'descripcion',
  'valor_estimado',
  'estado',
  'fecha_cierre',
])

export const OportunidadDetalle = crearModelo('oportunidades_detalle', 'id_detalle', [
  'id_oportunidad',
  'descripcion',
  'fecha',
])

export const Seguimiento = crearModelo('seguimientos', 'id_seguimiento', [
  'id_oportunidad',
  'id_usuario',
  'tipo',
  'descripcion',
  'fecha',
])

export const Tarea = crearModelo('tareas', 'id_tarea', [
  'id_usuario',
  'id_cliente',
  'id_oportunidad',
  'titulo',
  'descripcion',
  'fecha_limite',
  'estado',
])

// Listado con cliente, vendedor y etapa
export async function listar({ estado, id_cliente } = {}) {
  const filtros = []
  const valores = []

  if (estado) {
    filtros.push('o.estado = ?')
    valores.push(estado)
  }
  if (id_cliente) {
    filtros.push('o.id_cliente = ?')
    valores.push(id_cliente)
  }

  const [filas] = await pool.query(
    `SELECT o.id_oportunidad, o.titulo, o.estado, o.valor_estimado, o.fecha_cierre, o.fecha_creacion,
            o.id_cliente, TRIM(CONCAT(c.nombre, ' ', COALESCE(c.apellido, ''))) AS cliente,
            o.id_vendedor, u.nombre AS vendedor,
            o.id_etapa, e.nombre AS etapa
     FROM oportunidades o
     JOIN clientes c ON c.id_cliente = o.id_cliente
     LEFT JOIN vendedores v ON v.id_vendedor = o.id_vendedor
     LEFT JOIN usuarios u ON u.id_usuario = v.id_usuario
     LEFT JOIN etapas_ventas e ON e.id_etapa = o.id_etapa
     ${filtros.length ? `WHERE ${filtros.join(' AND ')}` : ''}
     ORDER BY o.fecha_creacion DESC, o.id_oportunidad DESC`,
    valores,
  )
  return filas
}

// Nueva oportunidad en etapa 1, asignada al vendedor actual del cliente
export async function crear(datos, idUsuario) {
  return ejecutarComoUsuario(idUsuario, async (conexion) => {
    const [clientes] = await conexion.execute(
      `SELECT c.id_cliente, c.estado, cva.id_vendedor
       FROM clientes c
       LEFT JOIN vw_cliente_vendedor_actual cva ON cva.id_cliente = c.id_cliente
       WHERE c.id_cliente = ?`,
      [datos.id_cliente],
    )

    if (clientes.length === 0) return { error: 'El cliente no existe' }
    if (Number(clientes[0].estado) !== 1) return { error: 'El cliente está desactivado' }

    const [resultado] = await conexion.execute(
      `INSERT INTO oportunidades (id_cliente, id_vendedor, id_etapa, titulo, descripcion, valor_estimado, fecha_cierre)
       VALUES (?, ?, 1, ?, ?, ?, ?)`,
      [
        datos.id_cliente,
        clientes[0].id_vendedor ?? null,
        datos.titulo,
        datos.descripcion || null,
        datos.valor_estimado ?? 0,
        datos.fecha_cierre || null,
      ],
    )

    return { id_oportunidad: resultado.insertId }
  })
}
