// Reportes generados y auditoría

import { crearModelo } from './base.model.js'
import pool, { ejecutarComoUsuario, resultadosDeCall } from '../config/database.js'

export const Reporte = crearModelo('reportes_generados', 'id_reporte', [
  'id_usuario',
  'nombre',
  'tipo',
  'archivo',
])

export const Auditoria = crearModelo('auditoria', 'id_auditoria', [
  'id_usuario',
  'tabla_afectada',
  'operacion',
  'registro_id',
  'descripcion',
  'fecha',
])

// Datos del tablero principal: todo sale de las vistas de la Sesión 4
export async function obtenerDashboard(anio) {
  const [[indicadores]] = await pool.query('SELECT * FROM vw_indicadores_generales')

  const [ventasMensuales] = await pool.query(
    'SELECT * FROM vw_ventas_mensuales WHERE anio = ? ORDER BY mes',
    [anio],
  )

  const [embudo] = await pool.query('SELECT * FROM vw_embudo_oportunidades ORDER BY orden')

  const [vendedores] = await pool.query(
    `SELECT id_vendedor, codigo, vendedor, total_vendido, total_recaudado, tasa_conversion,
            oportunidades_ganadas, oportunidades_perdidas
     FROM vw_desempeno_vendedores
     WHERE total_vendido > 0
     ORDER BY total_vendido DESC
     LIMIT 8`,
  )

  const [cartera] = await pool.query(
    'SELECT * FROM vw_cartera_pendiente ORDER BY por_recaudar DESC LIMIT 8',
  )

  return { indicadores, ventasMensuales, embudo, vendedores, cartera }
}

export async function listarCampanas() {
  const [filas] = await pool.query(
    'SELECT * FROM vw_efectividad_campanas ORDER BY fecha_inicio DESC',
  )
  return filas
}

export async function listarCartera() {
  const [filas] = await pool.query('SELECT * FROM vw_cartera_pendiente ORDER BY dias_desde_venta DESC')
  return filas
}

// Años con ventas (para el selector del reporte mensual)
export async function aniosDisponibles() {
  const [filas] = await pool.query('SELECT DISTINCT anio FROM vw_ventas_mensuales ORDER BY anio DESC')
  return filas.map((f) => f.anio)
}

// Procedimiento sp_reporte_ventas_mensual: 3 resultados
export async function reporteMensual(anio, mes, idUsuario) {
  return ejecutarComoUsuario(idUsuario, async (conexion) => {
    const [filas] = await conexion.query('CALL sp_reporte_ventas_mensual(?, ?, ?)', [anio, mes, idUsuario])
    const [resumen, vendedores, productos] = resultadosDeCall(filas)
    return { resumen: resumen?.[0] ?? null, vendedores: vendedores ?? [], productos: productos ?? [] }
  })
}

// Procedimiento sp_simular_error: demostración de ROLLBACK (Sesión 2)
export async function simularError(tipo) {
  const [filas] = await pool.query('CALL sp_simular_error(?)', [tipo])
  return resultadosDeCall(filas)[0]?.[0] ?? null
}

// Últimos movimientos registrados por los triggers de auditoría
export async function auditoriaReciente(limite = 30) {
  const [filas] = await pool.query(
    `SELECT a.id_auditoria, a.tabla_afectada, a.operacion, a.registro_id, a.descripcion, a.fecha,
            u.nombre AS usuario
     FROM auditoria a
     LEFT JOIN usuarios u ON u.id_usuario = a.id_usuario
     ORDER BY a.id_auditoria DESC
     LIMIT ?`,
    [limite],
  )
  return filas
}
