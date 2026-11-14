// Endpoints de estado del servicio y de la base de datos

import { comprobarConexion, listarTablas } from '../config/database.js'

export function estado(req, res) {
  res.json({
    ok: true,
    mensaje: 'El backend de Zimbra está funcionando',
  })
}

export async function estadoBaseDatos(req, res) {
  await comprobarConexion()

  res.json({
    ok: true,
    mensaje: 'Base de datos conectada',
  })
}

export async function estadoGeneral(req, res) {
  await comprobarConexion()
  const tablas = await listarTablas()

  res.json({
    ok: true,
    mensaje: 'Base de datos conectada',
    tablas,
  })
}
