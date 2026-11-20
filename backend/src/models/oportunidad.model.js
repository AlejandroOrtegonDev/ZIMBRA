// Oportunidades, etapas, seguimientos y tareas

import { crearModelo } from './base.model.js'
import pool from '../config/database.js'

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

// Consultar oportunidades con cliente, vendedor y etapa
export async function obtenerOportunidades() {
  const [filas] = await pool.query(`
    SELECT
      o.id_oportunidad,
      o.id_cliente,
      c.nombre AS cliente_nombre,
      c.apellido AS cliente_apellido,
      o.id_vendedor,
      u.nombre AS vendedor_nombre,
      o.id_etapa,
      e.nombre AS etapa_nombre,
      o.titulo,
      o.descripcion,
      o.valor_estimado,
      o.estado,
      o.fecha_cierre,
      o.fecha_creacion
    FROM oportunidades o
    INNER JOIN clientes c
      ON o.id_cliente = c.id_cliente
    LEFT JOIN vendedores v
      ON o.id_vendedor = v.id_vendedor
    LEFT JOIN usuarios u
      ON v.id_usuario = u.id_usuario
    LEFT JOIN etapas_ventas e
      ON o.id_etapa = e.id_etapa
    ORDER BY o.fecha_creacion DESC
  `)

  return filas
}

// Consultar las etapas comerciales
export async function obtenerEtapasVentas() {
  const [filas] = await pool.query(`
    SELECT id_etapa, nombre, orden
    FROM etapas_ventas
    ORDER BY orden ASC
  `)

  return filas
}

// Consultar una oportunidad por ID
export async function obtenerOportunidadPorId(id) {
  const [filas] = await pool.execute(`
    SELECT
      o.*,
      c.nombre AS cliente_nombre,
      c.apellido AS cliente_apellido,
      u.nombre AS vendedor_nombre,
      e.nombre AS etapa_nombre
    FROM oportunidades o
    INNER JOIN clientes c
      ON o.id_cliente = c.id_cliente
    LEFT JOIN vendedores v
      ON o.id_vendedor = v.id_vendedor
    LEFT JOIN usuarios u
      ON v.id_usuario = u.id_usuario
    LEFT JOIN etapas_ventas e
      ON o.id_etapa = e.id_etapa
    WHERE o.id_oportunidad = ?
  `, [id])

  return filas[0] || null
}


