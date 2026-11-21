// Vendedores y asignación de clientes

import { crearModelo } from './base.model.js'
import pool from '../config/database.js'

export const Vendedor = crearModelo('vendedores', 'id_vendedor', [
  'id_usuario',
  'codigo',
  'especialidad',
  'estado',
])

export const AsignacionCliente = crearModelo('asignaciones_clientes', 'id_asignacion', [
  'id_cliente',
  'id_vendedor',
])

// Desempeño de todos los vendedores (vista vw_desempeno_vendedores)
export async function listarDesempeno() {
  const [filas] = await pool.query(
    'SELECT * FROM vw_desempeno_vendedores ORDER BY total_vendido DESC, vendedor',
  )
  return filas
}

// Clientes que tiene asignados hoy un vendedor
export async function clientesAsignados(idVendedor) {
  const [filas] = await pool.query(
    `SELECT c.id_cliente, TRIM(CONCAT(c.nombre, ' ', COALESCE(c.apellido, ''))) AS cliente,
            c.tipo_cliente, c.estado, cva.fecha_asignacion,
            GROUP_CONCAT(cat.nombre ORDER BY cat.id_categoria SEPARATOR ', ') AS categorias
     FROM vw_cliente_vendedor_actual cva
     JOIN clientes c ON c.id_cliente = cva.id_cliente
     LEFT JOIN clientes_categorias cc ON cc.id_cliente = c.id_cliente
     LEFT JOIN categorias_clientes cat ON cat.id_categoria = cc.id_categoria
     WHERE cva.id_vendedor = ?
     GROUP BY c.id_cliente, c.nombre, c.apellido, c.tipo_cliente, c.estado, cva.fecha_asignacion
     ORDER BY cliente`,
    [idVendedor],
  )
  return filas
}
