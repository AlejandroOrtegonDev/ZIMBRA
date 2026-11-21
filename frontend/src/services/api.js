// Dirección del backend. React corre en el puerto 5173 y Express en el 3001.

const API_URL = 'http://localhost:3001'
const CLAVE_SESION = 'zimbra_sesion'

// ---------------------------------------------------------------
// Sesión (token + datos del usuario) guardada en el navegador
// ---------------------------------------------------------------
export function obtenerSesion() {
  try {
    return JSON.parse(localStorage.getItem(CLAVE_SESION)) ?? null
  } catch {
    return null
  }
}

function guardarSesion(sesion) {
  localStorage.setItem(CLAVE_SESION, JSON.stringify({ token: sesion.token, usuario: sesion.usuario }))
}

export function cerrarSesion() {
  localStorage.removeItem(CLAVE_SESION)
  window.location.href = '/login'
}

// ¿El usuario de la sesión tiene alguno de estos permisos?
export function tienePermiso(...permisos) {
  const propios = obtenerSesion()?.usuario?.permisos ?? []
  return permisos.some((permiso) => propios.includes(permiso))
}

// ---------------------------------------------------------------
// Petición genérica
// ---------------------------------------------------------------
async function consultar(ruta, opciones = {}) {
  const token = obtenerSesion()?.token

  const respuesta = await fetch(`${API_URL}${ruta}`, {
    ...opciones,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...opciones.headers,
    },
  })

  const datos = await respuesta.json().catch(() => ({}))

  // Token vencido o inválido: volver al inicio de sesión
  if (respuesta.status === 401 && token && !ruta.startsWith('/api/auth/')) {
    cerrarSesion()
  }

  if (!respuesta.ok) {
    throw new Error(
      datos.mensaje || 'Ocurrió un error al comunicarse con el servidor',
    )
  }

  return datos
}

const enviar = (metodo, cuerpo) => ({ method: metodo, body: JSON.stringify(cuerpo ?? {}) })

// ---------------------------------------------------------------
// Autenticación
// ---------------------------------------------------------------
export async function iniciarSesion(correo, password) {
  const datos = await consultar('/api/auth/login', enviar('POST', { correo, password }))
  guardarSesion(datos)
  return datos
}

export async function registrarUsuario(usuario) {
  const datos = await consultar('/api/auth/registro', enviar('POST', usuario))
  guardarSesion(datos)
  return datos
}

// Consultar estado del servidor
export function obtenerEstado() {
  return consultar('/api/estado')
}

// Consultar conexión con MySQL
export function obtenerBaseDatos() {
  return consultar('/api/db')
}

// ---------------------------------------------------------------
// Clientes y prospectos
// ---------------------------------------------------------------

// Listar clientes
export function obtenerClientes() {
  return consultar('/api/clientes')
}

// Consultar prospectos
export function obtenerProspectos() {
  return consultar('/api/clientes/prospectos')
}

// Consultar vendedores disponibles
export function obtenerVendedores() {
  return consultar('/api/clientes/vendedores')
}

// Registrar prospecto y asignar vendedor
export function crearProspecto(prospecto) {
  return consultar('/api/clientes/prospectos', enviar('POST', prospecto))
}

// Registrar cliente
export function crearCliente(cliente) {
  return consultar('/api/clientes', enviar('POST', cliente))
}

// Consultar un cliente
export function obtenerCliente(id) {
  return consultar(`/api/clientes/${id}`)
}

// Actualizar cliente
export function actualizarCliente(id, cliente) {
  return consultar(`/api/clientes/${id}`, enviar('PUT', cliente))
}

// Desactivar cliente
export function desactivarCliente(id) {
  return consultar(`/api/clientes/${id}`, { method: 'DELETE' })
}


// Consultar actividades de un prospecto
export function obtenerActividades(idCliente) {
  return consultar(`/api/clientes/${idCliente}/actividades`)
}

// Registrar una tarea de seguimiento
export function crearTarea(idCliente, tarea) {
  return consultar(`/api/clientes/${idCliente}/tareas`, enviar('POST', tarea))
}

// Programar una llamada, reunión o cita
export function crearEvento(idCliente, evento) {
  return consultar(`/api/clientes/${idCliente}/eventos`, enviar('POST', evento))
}

// ---------------------------------------------------------------
// Proceso comercial
// ---------------------------------------------------------------
export function obtenerOportunidades(filtros = {}) {
  const parametros = new URLSearchParams(filtros).toString()
  return consultar(`/api/oportunidades${parametros ? `?${parametros}` : ''}`)
}

export function crearOportunidad(oportunidad) {
  return consultar('/api/oportunidades', enviar('POST', oportunidad))
}

export function obtenerProductos() {
  return consultar('/api/productos')
}

export function obtenerPropuestas(estado) {
  return consultar(`/api/propuestas${estado ? `?estado=${estado}` : ''}`)
}

export function obtenerPropuesta(id) {
  return consultar(`/api/propuestas/${id}`)
}

export function crearPropuesta(propuesta) {
  return consultar('/api/propuestas', enviar('POST', propuesta))
}

export function cambiarEstadoPropuesta(id, estado) {
  return consultar(`/api/propuestas/${id}/estado`, enviar('PATCH', { estado }))
}

// Procedimiento sp_registrar_venta_desde_propuesta
export function convertirPropuestaEnVenta(id) {
  return consultar(`/api/propuestas/${id}/venta`, enviar('POST'))
}

export function obtenerVentas(estado) {
  return consultar(`/api/ventas${estado ? `?estado=${estado}` : ''}`)
}

export function obtenerVenta(id) {
  return consultar(`/api/ventas/${id}`)
}

// Procedimiento procesar_pago_venta (valor vacío = todo el saldo)
export function registrarPago(idVenta, pago) {
  return consultar(`/api/ventas/${idVenta}/pagos`, enviar('POST', pago))
}

export function cambiarEstadoPago(idPago, estado) {
  return consultar(`/api/pagos/${idPago}/estado`, enviar('PATCH', { estado }))
}

export function cancelarVenta(idVenta) {
  return consultar(`/api/ventas/${idVenta}/cancelar`, enviar('PATCH'))
}

export function obtenerDesempenoVendedores() {
  return consultar('/api/vendedores')
}

export function obtenerClientesDeVendedor(id) {
  return consultar(`/api/vendedores/${id}/clientes`)
}

// ---------------------------------------------------------------
// Reportes
// ---------------------------------------------------------------
export function obtenerDashboard(anio) {
  return consultar(`/api/reportes/dashboard?anio=${anio}`)
}

// Procedimiento sp_reporte_ventas_mensual
export function obtenerReporteMensual(anio, mes) {
  return consultar(`/api/reportes/mensual?anio=${anio}&mes=${mes}`)
}

export function obtenerAniosReporte() {
  return consultar('/api/reportes/anios')
}

export function obtenerCampanas() {
  return consultar('/api/reportes/campanas')
}

export function obtenerCartera() {
  return consultar('/api/reportes/cartera')
}

export function obtenerAuditoria() {
  return consultar('/api/reportes/auditoria')
}

// Procedimiento sp_simular_error
export function simularError(tipo) {
  return consultar(`/api/transacciones/simular-error/${tipo}`, enviar('POST'))
}
