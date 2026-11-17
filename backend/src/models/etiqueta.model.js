// Etiquetas de contactos

import { crearModelo, crearModeloRelacion } from './base.model.js'

export const Etiqueta = crearModelo('etiquetas', 'id_etiqueta', ['nombre', 'color'])

export const ContactoEtiqueta = crearModeloRelacion('contactos_etiquetas', [
  'id_contacto',
  'id_etiqueta',
])
