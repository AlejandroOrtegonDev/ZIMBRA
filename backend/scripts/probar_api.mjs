// Prueba de integración de la API (backend encendido + BD cargada con zimbra.sql).
//
//   cd backend
//   npm run dev          (en otra terminal)
//   npm run test:api
//
// Recorre el proceso comercial completo: login por rol, permisos,
// prospecto -> oportunidad -> propuesta -> venta -> pagos, reportes,
// procedimientos y simulación de errores. CREA datos de prueba
// (un usuario, una oportunidad, propuestas, una venta y pagos).

const API = process.env.API_URL ?? 'http://localhost:3001'
let fallos = 0
let total = 0

function verificar(condicion, descripcion, detalle = '') {
  total++
  if (!condicion) fallos++
  console.log(`${condicion ? '  OK ' : '  FALLO'} ${descripcion}${!condicion && detalle ? ` -> ${detalle}` : ''}`)
}

async function llamar(metodo, ruta, { token, cuerpo } = {}) {
  const respuesta = await fetch(`${API}${ruta}`, {
    method: metodo,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: cuerpo ? JSON.stringify(cuerpo) : undefined,
  })
  const datos = await respuesta.json().catch(() => ({}))
  return { estado: respuesta.status, datos }
}

const login = async (correo, password) => (await llamar('POST', '/api/auth/login', { cuerpo: { correo, password } }))

console.log(`Probando ${API}\n`)

// ---------------------------------------------------------------
console.log('1. Estado y autenticación')
verificar((await llamar('GET', '/api/estado')).estado === 200, 'GET /api/estado responde sin sesión')
verificar((await llamar('GET', '/api/db')).estado === 200, 'GET /api/db: la base de datos responde')
verificar((await llamar('GET', '/api/clientes')).estado === 401, 'Sin token, /api/clientes responde 401')
verificar((await llamar('GET', '/api/clientes', { token: 'x.y.z' })).estado === 401, 'Token falsificado responde 401')
verificar((await login('ana.rodriguez@zimbra-demo.com', 'mala')).estado === 401, 'Contraseña incorrecta responde 401')
verificar((await login('sofia.torres@zimbra-demo.com', '123456')).estado === 403, 'Usuaria desactivada (Sofía) responde 403')

const admin = await login('ana.rodriguez@zimbra-demo.com', 'admin123')
const vendedor = await login('carlos.gomez@zimbra-demo.com', '123456')
const demo = await login('demo@zimbra-demo.com', '123456')
verificar(admin.estado === 200 && admin.datos.usuario.rol === 'admin', 'Login admin (Ana) con rol admin')
verificar(vendedor.estado === 200 && vendedor.datos.usuario.rol === 'user', 'Login vendedor (Carlos) con rol user')
verificar(demo.estado === 200 && demo.datos.usuario.rol === 'user_demo', 'Login demo con rol user_demo')
const tA = admin.datos.token
const tV = vendedor.datos.token
const tD = demo.datos.token

// ---------------------------------------------------------------
console.log('\n2. Registro de usuarios')
const correoNuevo = `prueba.${Date.now()}@correo.com`
const reg = await llamar('POST', '/api/auth/registro', { cuerpo: { nombre: 'Usuario de Prueba', correo: correoNuevo, password: 'clave-segura-1' } })
verificar(reg.estado === 201 && reg.datos.usuario?.rol === 'user_demo', 'Registro crea la cuenta con rol de solo lectura', JSON.stringify(reg.datos))
verificar((await llamar('POST', '/api/auth/registro', { cuerpo: { nombre: 'Otra', correo: correoNuevo, password: 'clave-segura-1' } })).estado === 409, 'Correo repetido responde 409')
verificar((await llamar('POST', '/api/auth/registro', { cuerpo: { nombre: 'Otra', correo: 'x@y.co', password: '123' } })).estado === 400, 'Contraseña corta responde 400')
verificar((await login(correoNuevo, 'clave-segura-1')).estado === 200, 'El usuario registrado puede iniciar sesión')
verificar((await llamar('GET', '/api/auth/perfil', { token: reg.datos.token })).datos.usuario?.correo === correoNuevo, 'GET /api/auth/perfil devuelve la sesión')

// ---------------------------------------------------------------
console.log('\n3. Permisos por rol')
verificar((await llamar('GET', '/api/clientes', { token: tD })).estado === 200, 'Demo puede consultar clientes')
verificar((await llamar('POST', '/api/clientes', { token: tD, cuerpo: { nombre: 'X', tipo_cliente: 'persona' } })).estado === 403, 'Demo NO puede crear clientes (403)')
verificar((await llamar('POST', '/api/transacciones/simular-error/duplicado', { token: tV })).estado === 403, 'Vendedor NO puede usar la simulación de errores (403)')
verificar((await llamar('GET', '/api/reportes/auditoria', { token: tV })).estado === 403, 'Vendedor NO puede ver la auditoría (403)')

// ---------------------------------------------------------------
console.log('\n4. Clientes, prospectos y seguimiento')
const clientes = await llamar('GET', '/api/clientes', { token: tV })
verificar(clientes.estado === 200 && clientes.datos.total >= 60, `Listado de clientes (${clientes.datos.total})`)
const prospectos = await llamar('GET', '/api/clientes/prospectos', { token: tV })
const potenciales = prospectos.datos.prospectos?.filter((p) => p.es_potencial) ?? []
verificar(prospectos.estado === 200 && prospectos.datos.total >= 25, `Prospectos intactos (${prospectos.datos.total})`)
verificar(potenciales.length >= 4, `Prospectos marcados como potenciales: ${potenciales.length}`)
const idProspecto = potenciales[0]?.id_cliente ?? 34
const actividades = await llamar('GET', `/api/clientes/${idProspecto}/actividades`, { token: tV })
verificar(actividades.estado === 200, `Historial de seguimiento del prospecto #${idProspecto} (antes fallaba por eventos.id_cliente)`, JSON.stringify(actividades.datos))
const evento = await llamar('POST', `/api/clientes/${idProspecto}/eventos`, {
  token: tV,
  cuerpo: { titulo: 'Llamada de prueba', tipo: 'llamada', fecha_inicio: '2026-12-01 10:00:00', fecha_fin: '2026-12-01 10:30:00' },
})
verificar(evento.estado === 201, 'Programar llamada para el prospecto', JSON.stringify(evento.datos))
const actividades2 = await llamar('GET', `/api/clientes/${idProspecto}/actividades`, { token: tV })
verificar(actividades2.datos.total === actividades.datos.total + 1, 'La llamada aparece en el historial')

// ---------------------------------------------------------------
console.log('\n5. Oportunidad -> propuesta -> venta (procedimiento) -> pagos (procedimiento)')
const op = await llamar('POST', '/api/oportunidades', {
  token: tV,
  cuerpo: { id_cliente: idProspecto, titulo: 'Oportunidad de prueba API', valor_estimado: 1000000 },
})
verificar(op.estado === 201, 'Crear oportunidad', JSON.stringify(op.datos))

const productos = await llamar('GET', '/api/productos', { token: tV })
verificar(productos.estado === 200 && productos.datos.total >= 25, `Catálogo de productos activos (${productos.datos.total})`)

const prop = await llamar('POST', '/api/propuestas', {
  token: tV,
  cuerpo: { id_oportunidad: op.datos.id_oportunidad, enviar: true, observaciones: 'Prueba', lineas: [{ id_producto: 2, cantidad: 10 }, { id_producto: 6, cantidad: 1 }] },
})
verificar(prop.estado === 201 && prop.datos.propuesta?.valor_total === 1150000, 'Propuesta enviada; el trigger calculó 1.150.000', JSON.stringify(prop.datos))
verificar(prop.datos.propuesta?.estado === 'enviada', 'Estado de la propuesta: enviada')

const repetida = await llamar('POST', '/api/propuestas', {
  token: tV,
  cuerpo: { id_oportunidad: op.datos.id_oportunidad, lineas: [{ id_producto: 2, cantidad: 1 }, { id_producto: 2, cantidad: 1 }] },
})
verificar(repetida.estado === 400, 'Productos repetidos en la propuesta responde 400')

const idPropuesta = prop.datos.propuesta.id_propuesta
const venta = await llamar('POST', `/api/propuestas/${idPropuesta}/venta`, { token: tV })
verificar(venta.estado === 201 && venta.datos.venta?.total === 1150000, 'sp_registrar_venta_desde_propuesta crea la venta', JSON.stringify(venta.datos))
const idVenta = venta.datos.venta?.id_venta

const doble = await llamar('POST', `/api/propuestas/${idPropuesta}/venta`, { token: tV })
verificar(doble.estado === 400 && /ya se convirtió/.test(doble.datos.mensaje), `Vender dos veces la misma propuesta: "${doble.datos.mensaje}"`)

const propDespues = await llamar('GET', `/api/propuestas/${idPropuesta}`, { token: tV })
verificar(propDespues.datos.propuesta?.estado === 'aceptada' && propDespues.datos.propuesta?.estado_oportunidad === 'ganada', 'Trigger: propuesta aceptada y oportunidad ganada')

const prospectos2 = await llamar('GET', '/api/clientes/prospectos', { token: tV })
verificar(!prospectos2.datos.prospectos.some((p) => p.id_cliente === idProspecto), 'Trigger: el prospecto se convirtió en cliente activo')

const abono = await llamar('POST', `/api/ventas/${idVenta}/pagos`, { token: tV, cuerpo: { metodo_pago: 'pse', valor: 150000 } })
verificar(abono.estado === 201 && abono.datos.resultado?.saldo === 1000000, 'procesar_pago_venta: abono de 150.000 deja saldo 1.000.000', JSON.stringify(abono.datos))
const excedido = await llamar('POST', `/api/ventas/${idVenta}/pagos`, { token: tV, cuerpo: { metodo_pago: 'pse', valor: 5000000 } })
verificar(excedido.estado === 400, `Pago mayor al saldo: "${excedido.datos.mensaje}"`)
const resto = await llamar('POST', `/api/ventas/${idVenta}/pagos`, { token: tV, cuerpo: { metodo_pago: 'transferencia' } })
verificar(resto.estado === 201 && resto.datos.venta?.estado === 'pagada', 'Pago del saldo: la venta queda pagada')
const cancelarPagada = await llamar('PATCH', `/api/ventas/${idVenta}/cancelar`, { token: tV })
verificar(cancelarPagada.estado === 400, `Cancelar venta pagada: "${cancelarPagada.datos.mensaje}"`)

// Aprobar un pago pendiente (venta 4 trae uno sin aprobar)
const venta4 = await llamar('GET', '/api/ventas/4', { token: tV })
const pendiente = venta4.datos.venta?.pagos.find((p) => p.estado === 'pendiente')
if (pendiente) {
  const aprobado = await llamar('PATCH', `/api/pagos/${pendiente.id_pago}/estado`, { token: tV, cuerpo: { estado: 'aprobado' } })
  verificar(aprobado.estado === 200 && aprobado.datos.venta?.estado === 'pagada', 'Aprobar pago pendiente: el trigger marca la venta 4 como pagada')
} else {
  verificar(venta4.datos.venta?.estado === 'pagada', 'Venta 4 ya estaba pagada (pago aprobado en una ejecución anterior)')
}

// Rechazar una propuesta abierta -> oportunidad perdida
const op2 = await llamar('POST', '/api/oportunidades', { token: tV, cuerpo: { id_cliente: 3, titulo: 'Oportunidad para rechazar' } })
const prop2 = await llamar('POST', '/api/propuestas', { token: tV, cuerpo: { id_oportunidad: op2.datos.id_oportunidad, enviar: true, lineas: [{ id_producto: 1, cantidad: 5 }] } })
const rechazo = await llamar('PATCH', `/api/propuestas/${prop2.datos.propuesta.id_propuesta}/estado`, { token: tV, cuerpo: { estado: 'rechazada' } })
verificar(rechazo.estado === 200 && rechazo.datos.propuesta?.estado_oportunidad === 'perdida', 'Rechazar propuesta: el trigger marca la oportunidad como perdida')
const reabrir = await llamar('PATCH', `/api/propuestas/${prop2.datos.propuesta.id_propuesta}/estado`, { token: tV, cuerpo: { estado: 'enviada' } })
verificar(reabrir.estado === 400, `Reabrir una propuesta rechazada: "${reabrir.datos.mensaje}"`)
const sinOportunidad = await llamar('POST', '/api/propuestas', { token: tV, cuerpo: { id_oportunidad: op2.datos.id_oportunidad, lineas: [{ id_producto: 1, cantidad: 1 }] } })
verificar(sinOportunidad.estado === 400, 'No se cotiza una oportunidad perdida')

// ---------------------------------------------------------------
console.log('\n6. Reportes (vistas + procedimiento) y vendedores')
const tablero = await llamar('GET', '/api/reportes/dashboard?anio=2026', { token: tD })
verificar(tablero.estado === 200 && tablero.datos.ventasMensuales?.length >= 11 && tablero.datos.embudo?.length === 6, 'Dashboard: 11+ meses y 6 etapas del embudo (rol demo)')
verificar(typeof tablero.datos.indicadores?.total_vendido === 'number', 'Los montos llegan como números')
const mensual = await llamar('GET', '/api/reportes/mensual?anio=2026&mes=10', { token: tV })
verificar(mensual.estado === 200 && mensual.datos.resumen?.mes_nombre === 'octubre' && mensual.datos.vendedores.length > 0, 'sp_reporte_ventas_mensual: resumen + vendedores + productos')
verificar((await llamar('GET', '/api/reportes/mensual?anio=2026&mes=13', { token: tV })).estado === 400, 'Mes inválido responde 400')
verificar((await llamar('GET', '/api/reportes/campanas', { token: tV })).datos.total >= 30, 'Vista de efectividad de campañas')
verificar((await llamar('GET', '/api/reportes/cartera', { token: tV })).estado === 200, 'Vista de cartera pendiente')
const vendedores = await llamar('GET', '/api/vendedores', { token: tV })
verificar(vendedores.estado === 200 && vendedores.datos.total === 30, 'Desempeño de los 30 vendedores (vista + UDF)')
verificar((await llamar('GET', '/api/vendedores/1/clientes', { token: tV })).datos.total > 0, 'Clientes asignados al vendedor 1')

// ---------------------------------------------------------------
console.log('\n7. Simulación de errores (sp_simular_error) y auditoría')
for (const tipo of ['llave_foranea', 'duplicado', 'restriccion', 'stock', 'sobrepago', 'propuesta_rechazada']) {
  const r = await llamar('POST', `/api/transacciones/simular-error/${tipo}`, { token: tA })
  verificar(r.estado === 200 && /ROLLBACK correcto/.test(r.datos.resultado?.resultado), `${tipo}: error ${r.datos.resultado?.codigo_error} y ROLLBACK`)
}
const auditoria = await llamar('GET', '/api/reportes/auditoria', { token: tA })
verificar(
  auditoria.datos.auditoria?.some((a) => a.tabla_afectada === 'ventas' && a.usuario === 'Carlos Gómez'),
  'La auditoría registra a Carlos Gómez como autor de la venta (@usuario_actual)',
)

console.log(`\n${total - fallos} de ${total} verificaciones correctas.`)
process.exit(fallos === 0 ? 0 : 1)
