// Clientes, contactos y categorías de clientes

import { crearModelo, crearModeloRelacion } from './base.model.js'

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
