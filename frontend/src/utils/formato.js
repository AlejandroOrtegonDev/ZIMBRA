// Formato de montos, fechas y números en español (Colombia)

const pesos = new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 })
const numero = new Intl.NumberFormat('es-CO')
const compacto = new Intl.NumberFormat('es-CO', { notation: 'compact', maximumFractionDigits: 1 })

export const formatoPesos = (valor) => pesos.format(Number(valor) || 0)
export const formatoNumero = (valor) => numero.format(Number(valor) || 0)
const unDecimal = new Intl.NumberFormat('es-CO', { minimumFractionDigits: 1, maximumFractionDigits: 1 })
export const formatoPorcentaje = (valor) => `${unDecimal.format(Number(valor) || 0)} %`
export const formatoCompacto = (valor) => `$${compacto.format(Number(valor) || 0)}`

export function formatoFecha(valor, conHora = false) {
  if (!valor) return '—'
  const fecha = new Date(valor)
  if (Number.isNaN(fecha.getTime())) return String(valor)
  return fecha.toLocaleString('es-CO', conHora
    ? { dateStyle: 'medium', timeStyle: 'short' }
    : { dateStyle: 'medium' })
}

export const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
export const MESES_CORTOS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']
