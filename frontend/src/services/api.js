// Dirección del backend. React corre en el puerto 5173 y Express en el 3001.
const API_URL = 'http://localhost:3001'

async function consultar(ruta) {
  const respuesta = await fetch(`${API_URL}${ruta}`)

  if (!respuesta.ok) {
    throw new Error('El backend respondió con un error')
  }

  return respuesta.json()
}

export function obtenerEstado() {
  return consultar('/api/estado')
}

export function obtenerBaseDatos() {
  return consultar('/api/db')
}
