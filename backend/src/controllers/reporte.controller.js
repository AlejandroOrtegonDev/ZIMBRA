// Reportes, tablero y demostraciones transaccionales

import * as ReporteModel from '../models/reporte.model.js'
import ApiError from '../utils/ApiError.js'
import { validarOpcion } from '../utils/validar.js'

function validarAnio(valor) {
  const anio = Number(valor)
  if (!Number.isInteger(anio) || anio < 2000 || anio > 2100) throw new ApiError(400, 'El año no es válido')
  return anio
}

export async function dashboard(req, res) {
  const anio = req.query.anio ? validarAnio(req.query.anio) : new Date().getFullYear()
  const datos = await ReporteModel.obtenerDashboard(anio)

  res.json({ ok: true, anio, ...datos })
}

// Llama al procedimiento sp_reporte_ventas_mensual y deja constancia
// en reportes_generados con el usuario que lo pidió
export async function reporteMensual(req, res) {
  const anio = validarAnio(req.query.anio)
  const mes = Number(req.query.mes)

  if (!Number.isInteger(mes) || mes < 1 || mes > 12) throw new ApiError(400, 'El mes debe estar entre 1 y 12')

  const reporte = await ReporteModel.reporteMensual(anio, mes, req.usuario.id_usuario)
  res.json({ ok: true, ...reporte })
}

export async function aniosDisponibles(req, res) {
  res.json({ ok: true, anios: await ReporteModel.aniosDisponibles() })
}

export async function campanas(req, res) {
  const campanas = await ReporteModel.listarCampanas()
  res.json({ ok: true, total: campanas.length, campanas })
}

export async function cartera(req, res) {
  const cartera = await ReporteModel.listarCartera()
  res.json({ ok: true, total: cartera.length, cartera })
}

export async function auditoria(req, res) {
  res.json({ ok: true, auditoria: await ReporteModel.auditoriaReciente(40) })
}

const TIPOS_ERROR = ['llave_foranea', 'duplicado', 'restriccion', 'stock', 'sobrepago', 'propuesta_rechazada']

// Llama al procedimiento sp_simular_error (Sesión 2: error + ROLLBACK)
export async function simularError(req, res) {
  const tipo = validarOpcion(req.params.tipo, TIPOS_ERROR, 'Tipo de simulación')
  const resultado = await ReporteModel.simularError(tipo)

  res.json({ ok: true, resultado })
}
