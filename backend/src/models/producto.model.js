// Productos, sus detalles y categorías

import { crearModelo, crearModeloRelacion } from './base.model.js'
import pool from '../config/database.js'

export const CategoriaProducto = crearModelo('categorias_productos', 'id_categoria', [
  'nombre',
  'descripcion',
])

export const Producto = crearModelo('productos', 'id_producto', [
  'nombre',
  'descripcion',
  'precio',
  'stock',
  'estado',
])

export const ProductoDetalle = crearModelo('productos_detalles', 'id_detalle', [
  'id_producto',
  'atributo',
  'valor',
])

export const ProductoCategoria = crearModeloRelacion('productos_categorias', [
  'id_producto',
  'id_categoria',
])

// Catálogo para los formularios: solo productos activos
export async function listarActivos() {
  const [filas] = await pool.query(
    `SELECT id_producto, nombre, descripcion, precio, stock
     FROM productos
     WHERE estado = 1
     ORDER BY nombre`,
  )
  return filas
}
