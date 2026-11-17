// Dirección del backend. React corre en el puerto 5173 y Express en el 3001.

const API_URL = 'http://localhost:3001'

async function consultar(ruta, opciones = {}) {
  const respuesta = await fetch(`${API_URL}${ruta}`, {
    headers: {
      'Content-Type': 'application/json',
      ...opciones.headers,
    },
    ...opciones,
  })

  const datos = await respuesta.json()

  if (!respuesta.ok) {
    throw new Error(
      datos.mensaje || 'Ocurrió un error al comunicarse con el servidor',
    )
  }

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
  return consultar('/api/clientes/prospectos', {
    method: 'POST',
    body: JSON.stringify(prospecto),
  })
}

// Registrar cliente
export function crearCliente(cliente) {
  return consultar('/api/clientes', {
    method: 'POST',
    body: JSON.stringify(cliente),
  })
}

// Consultar un cliente
export function obtenerCliente(id) {
  return consultar(`/api/clientes/${id}`)
}

// Actualizar cliente
export function actualizarCliente(id, cliente) {
  return consultar(`/api/clientes/${id}`, {
    method: 'PUT',
    body: JSON.stringify(cliente),
  })
}

// Desactivar cliente
export function desactivarCliente(id) {
  return consultar(`/api/clientes/${id}`, {
    method: 'DELETE',
  })
}


// Consultar actividades de un prospecto
export function obtenerActividades(idCliente) {
  return consultar(`/api/clientes/${idCliente}/actividades`)
}

// Registrar una tarea de seguimiento
export function crearTarea(idCliente, tarea) {
  return consultar(`/api/clientes/${idCliente}/tareas`, {
    method: 'POST',
    body: JSON.stringify(tarea),
  })
}

// Programar una llamada, reunión o cita
export function crearEvento(idCliente, evento) {
  return consultar(`/api/clientes/${idCliente}/eventos`, {
    method: 'POST',
    body: JSON.stringify(evento),
  })
}
