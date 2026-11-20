// Ventas, productos vendidos y pagos

import { crearModelo } from './base.model.js'
import pool from '../config/database.js'

export const Venta = crearModelo('ventas', 'id_venta', [
  'id_cliente',
  'id_vendedor',
  'id_propuesta',
  'fecha',
  'total',
  'estado',
])

export const VentaProducto = crearModelo('ventas_productos', 'id_detalle', [
  'id_venta',
  'id_producto',
  'cantidad',
  'precio_unitario',
  'subtotal',
])

export const Pago = crearModelo('pagos', 'id_pago', [
  'id_venta',
  'metodo_pago',
  'valor',
  'fecha',
  'estado',
])



// Registrar una venta y descontar inventario mediante transacción
export async function crearVentaConProductos(idPropuesta, productos) {
  const conexion = await pool.getConnection()

  try {
    await conexion.beginTransaction()

    // 1. Consultar y bloquear la propuesta
    const [propuestas] = await conexion.execute(
      `SELECT
        p.id_propuesta,
        p.estado,
        p.valor_total,
        o.id_cliente,
        o.id_vendedor
       FROM propuestas p
       INNER JOIN oportunidades o
         ON p.id_oportunidad = o.id_oportunidad
       WHERE p.id_propuesta = ?
       FOR UPDATE`,
      [idPropuesta],
    )

    if (propuestas.length === 0) {
      throw new Error('La propuesta no existe')
    }

    const propuesta = propuestas[0]

    if (propuesta.estado !== 'aceptada') {
      throw new Error('La propuesta debe estar aceptada')
    }

    // 2. Evitar registrar dos ventas para la misma propuesta
    const [ventasExistentes] = await conexion.execute(
      `SELECT id_venta
       FROM ventas
       WHERE id_propuesta = ?
       LIMIT 1`,
      [idPropuesta],
    )

    if (ventasExistentes.length > 0) {
      throw new Error('Esta propuesta ya tiene una venta registrada')
    }

    if (!Array.isArray(productos) || productos.length === 0) {
      throw new Error('Debes agregar al menos un producto')
    }

    // 3. Calcular el total y validar existencias
    let total = 0
    const productosValidados = []

    for (const item of productos) {
      const idProducto = Number(item.id_producto)
      const cantidad = Number(item.cantidad)

      if (
        !Number.isInteger(idProducto) ||
        idProducto <= 0 ||
        !Number.isInteger(cantidad) ||
        cantidad <= 0
      ) {
        throw new Error('Los productos o cantidades no son válidos')
      }

      const [filas] = await conexion.execute(
        `SELECT id_producto, nombre, precio, stock, estado
         FROM productos
         WHERE id_producto = ?
         FOR UPDATE`,
        [idProducto],
      )

      if (filas.length === 0 || Number(filas[0].estado) !== 1) {
        throw new Error(`El producto ${idProducto} no existe o está inactivo`)
      }

      const producto = filas[0]

      if (Number(producto.stock) < cantidad) {
        throw new Error(
          `Stock insuficiente para ${producto.nombre}. Disponible: ${producto.stock}`,
        )
      }

      const precio = Number(producto.precio)
      const subtotal = precio * cantidad

      total += subtotal

      productosValidados.push({
        id_producto: idProducto,
        nombre: producto.nombre,
        cantidad,
        precio_unitario: precio,
        subtotal,
      })
    }

    // 4. Crear la venta
    const [resultadoVenta] = await conexion.execute(
      `INSERT INTO ventas
       (id_cliente, id_vendedor, id_propuesta, total, estado)
       VALUES (?, ?, ?, ?, 'pendiente')`,
      [
        propuesta.id_cliente,
        propuesta.id_vendedor,
        idPropuesta,
        total,
      ],
    )

    const idVenta = resultadoVenta.insertId

    // 5. Registrar productos y descontar existencias
    for (const producto of productosValidados) {
      await conexion.execute(
        `INSERT INTO ventas_productos
         (id_venta, id_producto, cantidad, precio_unitario, subtotal)
         VALUES (?, ?, ?, ?, ?)`,
        [
          idVenta,
          producto.id_producto,
          producto.cantidad,
          producto.precio_unitario,
          producto.subtotal,
        ],
      )

      const [actualizacion] = await conexion.execute(
        `UPDATE productos
         SET stock = stock - ?
         WHERE id_producto = ?
           AND stock >= ?`,
        [
          producto.cantidad,
          producto.id_producto,
          producto.cantidad,
        ],
      )

      if (actualizacion.affectedRows !== 1) {
        throw new Error(
          `No fue posible descontar el inventario de ${producto.nombre}`,
        )
      }
    }

    // 6. Confirmar toda la operación
    await conexion.commit()

    return {
      id_venta: idVenta,
      id_propuesta: idPropuesta,
      total,
      estado: 'pendiente',
      productos: productosValidados,
    }
  } catch (error) {
    await conexion.rollback()
    throw error
  } finally {
    conexion.release()
  }
}


// Listar ventas con información del cliente, vendedor y propuesta
export async function obtenerVentas() {
  const [filas] = await pool.query(`
    SELECT
      v.id_venta,
      v.id_cliente,
      c.nombre AS cliente_nombre,
      c.apellido AS cliente_apellido,
      v.id_vendedor,
      u.nombre AS vendedor_nombre,
      v.id_propuesta,
      p.estado AS estado_propuesta,
      v.fecha,
      v.total,
      v.estado
    FROM ventas v
    INNER JOIN clientes c
      ON v.id_cliente = c.id_cliente
    LEFT JOIN vendedores ve
      ON v.id_vendedor = ve.id_vendedor
    LEFT JOIN usuarios u
      ON ve.id_usuario = u.id_usuario
    LEFT JOIN propuestas p
      ON v.id_propuesta = p.id_propuesta
    ORDER BY v.fecha DESC
  `)

  return filas
}

// Consultar propuestas aceptadas que todavía no tienen venta
export async function obtenerPropuestasDisponibles() {
  const [filas] = await pool.query(`
    SELECT
      p.id_propuesta,
      p.id_oportunidad,
      p.fecha,
      p.valor_total,
      o.titulo AS oportunidad,
      o.id_cliente,
      c.nombre AS cliente_nombre,
      c.apellido AS cliente_apellido,
      o.id_vendedor,
      u.nombre AS vendedor_nombre
    FROM propuestas p
    INNER JOIN oportunidades o
      ON p.id_oportunidad = o.id_oportunidad
    INNER JOIN clientes c
      ON o.id_cliente = c.id_cliente
    LEFT JOIN vendedores ve
      ON o.id_vendedor = ve.id_vendedor
    LEFT JOIN usuarios u
      ON ve.id_usuario = u.id_usuario
    LEFT JOIN ventas v
      ON p.id_propuesta = v.id_propuesta
    WHERE p.estado = 'aceptada'
      AND v.id_venta IS NULL
    ORDER BY p.fecha_creacion DESC
  `)

  return filas
}

// Consultar productos activos disponibles en inventario
export async function obtenerProductosDisponibles() {
  const [filas] = await pool.query(`
    SELECT
      id_producto,
      nombre,
      descripcion,
      precio,
      stock
    FROM productos
    WHERE estado = 1
      AND stock > 0
    ORDER BY nombre ASC
  `)

  return filas
}
