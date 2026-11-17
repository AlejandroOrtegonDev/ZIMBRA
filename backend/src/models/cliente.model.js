// Clientes, contactos y categorías de clientes

import { crearModelo, crearModeloRelacion } from './base.model.js'
import pool from '../config/database.js'

export const Cliente = crearModelo('clientes', 'id_cliente', [
  'tipo_cliente',
  'nombre',
  'apellido',
  'documento',
  'correo',
  'telefono',
  'direccion',
  'estado',
])

export const Contacto = crearModelo('contactos', 'id_contacto', [
  'id_cliente',
  'nombre',
  'apellido',
  'correo',
  'telefono',
  'cargo',
])

export const CategoriaCliente = crearModelo('categorias_clientes', 'id_categoria', [
  'nombre',
  'descripcion',
])

export const ClienteCategoria = crearModeloRelacion('clientes_categorias', [
  'id_cliente',
  'id_categoria',
])

// Compatibilidad: el controlador de clientes usa estas funciones directamente
export const {
  obtenerTodos,
  obtenerPorId,
  obtenerPor,
  contar,
  crear,
  actualizar,
  eliminar,
} = Cliente


// Consultar todos los prospectos y sus vendedores asignados
export async function obtenerProspectos() {
  const [filas] = await pool.query(`
    SELECT
      c.id_cliente,
      c.tipo_cliente,
      c.nombre,
      c.apellido,
      c.documento,
      c.correo,
      c.telefono,
      c.direccion,
      c.estado,
      c.fecha_creacion,
      v.id_vendedor,
      u.nombre AS vendedor_nombre
    FROM clientes c
    INNER JOIN clientes_categorias cc
      ON c.id_cliente = cc.id_cliente
    INNER JOIN categorias_clientes cat
      ON cc.id_categoria = cat.id_categoria
    LEFT JOIN (
      SELECT a1.id_cliente, a1.id_vendedor
      FROM asignaciones_clientes a1
      INNER JOIN (
        SELECT id_cliente, MAX(id_asignacion) AS ultima_asignacion
        FROM asignaciones_clientes
        GROUP BY id_cliente
      ) ult
        ON a1.id_asignacion = ult.ultima_asignacion
    ) asignacion
      ON c.id_cliente = asignacion.id_cliente
    LEFT JOIN vendedores v
      ON asignacion.id_vendedor = v.id_vendedor
    LEFT JOIN usuarios u
      ON v.id_usuario = u.id_usuario
    WHERE cat.nombre = 'Prospecto'
    ORDER BY c.id_cliente DESC
  `)

  return filas
}

// Consultar vendedores activos
export async function obtenerVendedores() {
  const [filas] = await pool.query(`
    SELECT
      v.id_vendedor,
      v.codigo,
      u.nombre,
      v.especialidad
    FROM vendedores v
    INNER JOIN usuarios u
      ON v.id_usuario = u.id_usuario
    WHERE v.estado = 1
      AND u.estado = 1
    ORDER BY u.nombre
  `)

  return filas
}


// Registrar prospecto con categoría y vendedor en una transacción
export async function crearProspecto(datos) {
  const conexion = await pool.getConnection()

  try {
    await conexion.beginTransaction()

    // Comprobar que el vendedor exista y esté activo
    const [vendedores] = await conexion.execute(
      `SELECT id_vendedor
       FROM vendedores
       WHERE id_vendedor = ? AND estado = 1
       FOR UPDATE`,
      [datos.id_vendedor],
    )

    if (vendedores.length === 0) {
      throw new Error('El vendedor seleccionado no existe o está inactivo')
    }

    // Obtener la categoría Prospecto
    const [categorias] = await conexion.execute(
      `SELECT id_categoria
       FROM categorias_clientes
       WHERE nombre = 'Prospecto'
       LIMIT 1`,
    )

    if (categorias.length === 0) {
      throw new Error('No existe la categoría Prospecto')
    }

    // Insertar información del prospecto
    const [resultado] = await conexion.execute(
      `INSERT INTO clientes
       (tipo_cliente, nombre, apellido, documento, correo,
        telefono, direccion, estado)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        datos.tipo_cliente,
        datos.nombre,
        datos.apellido || null,
        datos.documento || null,
        datos.correo || null,
        datos.telefono || null,
        datos.direccion || null,
      ],
    )

    const idCliente = resultado.insertId
    const idCategoria = categorias[0].id_categoria

    // Relacionar el cliente con la categoría Prospecto
    await conexion.execute(
      `INSERT INTO clientes_categorias
       (id_cliente, id_categoria)
       VALUES (?, ?)`,
      [idCliente, idCategoria],
    )

    // Asignar el vendedor
    await conexion.execute(
      `INSERT INTO asignaciones_clientes
       (id_cliente, id_vendedor)
       VALUES (?, ?)`,
      [idCliente, datos.id_vendedor],
    )

    await conexion.commit()

    return {
      id_cliente: idCliente,
      id_vendedor: datos.id_vendedor,
      id_categoria: idCategoria,
    }
  } catch (error) {
    await conexion.rollback()
    throw error
  } finally {
    conexion.release()
  }
}
