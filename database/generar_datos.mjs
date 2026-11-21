// ============================================================
// Generador de la PARTE 2 de zimbra.sql (datos de prueba).
//
// Produce INSERT explícitos con 30+ registros por tabla, respetando
// las reglas de negocio para que los datos sean coherentes:
//   * oportunidad ganada  -> propuesta aceptada -> venta con esa propuesta
//   * oportunidad perdida -> propuesta rechazada (etapa 6)
//   * valor_total de la propuesta = suma de sus detalles
//   * total de la venta = suma de ventas_productos
//   * venta 'pagada' = pagos aprobados que suman exactamente el total
//   * pagos aprobados + pendientes nunca superan el total
//   * el vendedor de la oportunidad/venta es el asignado al cliente
//
// Es determinista (semilla fija): siempre genera los mismos datos.
// Uso:  node database/generar_datos.mjs > salida.sql
// ============================================================

// ---------- utilidades ----------
let semilla = 20261119
function azar() {
  semilla |= 0
  semilla = (semilla + 0x6d2b79f5) | 0
  let t = Math.imul(semilla ^ (semilla >>> 15), 1 | semilla)
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}
const entero = (a, b) => a + Math.floor(azar() * (b - a + 1))
const elegir = (lista) => lista[Math.floor(azar() * lista.length)]
const prob = (p) => azar() < p

const HOY = Date.UTC(2026, 10, 19) // 19-nov-2026 (fecha de referencia)
const DIA = 86400000

function fecha(y, m, d, h = 9, mi = 0) {
  return Date.UTC(y, m - 1, d, h, mi)
}
function txt(ms, conHora = true) {
  const d = new Date(ms)
  const p = (n) => String(n).padStart(2, '0')
  const base = `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}`
  return conHora ? `${base} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:00` : base
}
function entre(desde, hasta) {
  const ms = desde + Math.floor(azar() * Math.max(hasta - desde, 1))
  const d = new Date(ms)
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), entero(8, 17), elegir([0, 15, 30, 45]))
}
const sinTilde = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '')
const slug = (s) => sinTilde(s).toLowerCase().replace(/[^a-z0-9]+/g, '.').replace(/^\.|\.$/g, '')
const dinero = (n) => ({ raw: Number(n).toFixed(2) })
const crudo = (sql) => ({ raw: sql })

function valor(v) {
  if (v === null || v === undefined) return 'NULL'
  if (typeof v === 'number') return String(v)
  if (typeof v === 'object' && 'raw' in v) return v.raw
  return `'${String(v).replace(/\\/g, '\\\\').replace(/'/g, "''")}'`
}

const salida = []
function insertar(tabla, columnas, filas, comentario) {
  if (comentario) salida.push(`-- ${comentario}`)
  salida.push(`INSERT INTO ${tabla} (${columnas.join(', ')}) VALUES`)
  salida.push(filas.map((f) => `(${columnas.map((c) => valor(f[c])).join(', ')})`).join(',\n') + ';\n')
}
function titulo(t) {
  salida.push('-- ------------------------------------------------------------')
  salida.push(`-- ${t}`)
  salida.push('-- ------------------------------------------------------------')
}

// ---------- catálogos de texto ----------
const NOMBRES = ['Andrés', 'Paula', 'Santiago', 'Valeria', 'Juan Camilo', 'Natalia', 'Felipe', 'Daniela', 'Sebastián', 'Carolina', 'Mateo', 'Juliana', 'Alejandro', 'Mariana', 'Nicolás', 'Isabella', 'Gabriel', 'Manuela', 'Tomás', 'Luisa Fernanda', 'David', 'Catalina', 'Esteban', 'Sara', 'Miguel Ángel', 'Verónica', 'Óscar', 'Lina María', 'Hernán', 'Adriana', 'Julián', 'Paola', 'Mauricio', 'Claudia', 'Fabián', 'Diana', 'Germán', 'Liliana', 'Iván', 'Gloria']
const APELLIDOS = ['García', 'Rodríguez', 'López', 'Hernández', 'Moreno', 'Jiménez', 'Muñoz', 'Rojas', 'Díaz', 'Castro', 'Vargas', 'Ortiz', 'Suárez', 'Romero', 'Álvarez', 'Ruiz', 'Cárdenas', 'Mejía', 'Restrepo', 'Gutiérrez', 'Quintero', 'Peña', 'Cortés', 'Arango', 'Zapata', 'Valencia', 'Mendoza', 'Bermúdez', 'Patiño', 'Salazar']
const EMPRESAS = ['Constructora Horizonte S.A.S.', 'Agroindustrias del Valle S.A.', 'Universidad Tecnológica del Caribe', 'Transportes Rápidos del Sur Ltda.', 'Hotel Mirador Andino', 'Laboratorios Biogénesis S.A.S.', 'Distribuidora La Montaña S.A.', 'Colegio Nuevo Horizonte', 'Fundación Manos Unidas', 'Seguros Confianza Plus S.A.', 'Textiles Antioquia S.A.S.', 'Alcaldía Municipal de Chía', 'Ferretería El Constructor', 'Energía Verde Colombia S.A.S.', 'Cooperativa Cafetera del Huila', 'Clínica Los Andes', 'Software Factory Bogotá S.A.S.', 'Inmobiliaria Altos del Prado', 'Restaurantes Sabor Criollo S.A.S.', 'Notaría Quinta de Medellín', 'Editorial Páginas Abiertas', 'Minería Responsable S.A.', 'Centro Médico Santa Lucía', 'Aerolínea Regional Express', 'Banco Cooperativo Solidario', 'Grupo Logístico Atlántico', 'Farmacias Bienestar S.A.S.', 'Instituto de Idiomas Global', 'Consultores Asociados JR', 'Pinturas Arcoíris S.A.', 'Agencia de Viajes Destinos', 'Lácteos La Pradera S.A.', 'Estudio Jurídico Mendoza & Asociados', 'Cámara de Comercio Regional', 'Tienda Virtual Compra Fácil', 'Clínica Veterinaria Huellitas', 'Productora Audiovisual Enfoque', 'Gimnasio Vida Activa', 'Panadería Industrial Trigal', 'Hospital San Vicente']
const CIUDADES = [['Bogotá D.C.', '601'], ['Medellín', '604'], ['Cali', '602'], ['Barranquilla', '605'], ['Bucaramanga', '607'], ['Cartagena', '605'], ['Pereira', '606'], ['Manizales', '606'], ['Cúcuta', '607'], ['Ibagué', '608'], ['Santa Marta', '605'], ['Villavicencio', '608'], ['Pasto', '602'], ['Neiva', '608'], ['Armenia', '606']]
const CARGOS = ['Gerente General', 'Gerente de TI', 'Jefe de Compras', 'Director Administrativo', 'Coordinador de Sistemas', 'Director Financiero', 'Jefe de Infraestructura', 'Analista de Seguridad', 'Asistente de Gerencia', 'Director de Operaciones']
const ESPECIALIDADES = ['Correo corporativo y cuentas empresariales', 'Soluciones de colaboración y seguridad', 'Sector salud y logística', 'Sector educativo', 'Sector público', 'Pymes y comercio', 'Sector financiero', 'Migraciones y despliegues', 'Grandes cuentas', 'Canal de distribuidores']

const ids = (n, desde = 1) => Array.from({ length: n }, (_, i) => i + desde)

// ============================================================
// 1. Compañía
// ============================================================
titulo('10. Información de la compañía')
insertar('info_companie', ['id_compania', 'nombre', 'nit', 'direccion', 'telefono', 'correo', 'logo'], [
  { id_compania: 1, nombre: 'Zimbra Demo S.A.S.', nit: '901555888-1', direccion: 'Calle 93 # 15-20, Bogotá D.C.', telefono: '+57 601 555 0000', correo: 'contacto@zimbra-demo.com', logo: '/img/logo-zimbra-demo.png' },
], 'Tabla de configuración: una sola fila por diseño (la empresa que usa el sistema)')

// ============================================================
// 2. Usuarios, roles, permisos
// ============================================================
const HASH_ADMIN = '$2y$10$lhjAjW4ZIF3N4FrMVYtxzu5/bWIAox9Fu.ZBTZ0E2DIK8BpLwwi.S' // admin123
const HASH_USER = '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry' // 123456

const usuarios = [
  { id_usuario: 1, nombre: 'Ana María Rodríguez', correo: 'ana.rodriguez@zimbra-demo.com', password: HASH_ADMIN, estado: 1, rol: 1 },
  { id_usuario: 2, nombre: 'Carlos Gómez', correo: 'carlos.gomez@zimbra-demo.com', password: HASH_USER, estado: 1, rol: 2 },
  { id_usuario: 3, nombre: 'Laura Martínez', correo: 'laura.martinez@zimbra-demo.com', password: HASH_USER, estado: 1, rol: 2 },
  { id_usuario: 4, nombre: 'Diego Herrera', correo: 'diego.herrera@zimbra-demo.com', password: HASH_USER, estado: 1, rol: 2 },
  { id_usuario: 5, nombre: 'Sofía Torres', correo: 'sofia.torres@zimbra-demo.com', password: HASH_USER, estado: 0, rol: 3 },
]
const correosUsados = new Set(usuarios.map((u) => u.correo))
for (let id = 6; id <= 40; id++) {
  const nombre = `${NOMBRES[(id * 7) % NOMBRES.length]} ${APELLIDOS[(id * 11) % APELLIDOS.length]}`
  let correo = `${slug(nombre)}@zimbra-demo.com`
  let n = 2
  while (correosUsados.has(correo)) correo = `${slug(nombre)}${n++}@zimbra-demo.com`
  correosUsados.add(correo)
  // 6-32 vendedores (rol user), 33-37 marketing/soporte (user), 38 admin, 39-40 demo
  const rol = id === 38 ? 1 : id >= 39 ? 3 : 2
  usuarios.push({ id_usuario: id, nombre, correo, password: id === 38 ? HASH_ADMIN : HASH_USER, estado: 1, rol })
}
usuarios.find((u) => u.id_usuario === 40).correo = 'demo@zimbra-demo.com'
usuarios.find((u) => u.id_usuario === 40).nombre = 'Usuario Demo'
for (const u of usuarios) u.fecha_creacion = txt(fecha(2025, 1, 10) + u.id_usuario * 6 * DIA)

titulo('1. Usuarios, roles y permisos')
insertar('usuarios', ['id_usuario', 'nombre', 'correo', 'password', 'estado', 'fecha_creacion'], usuarios)

insertar('roles', ['id_rol', 'nombre', 'descripcion'], [
  { id_rol: 1, nombre: 'admin', descripcion: 'Acceso total: gestiona usuarios, configuración, auditoría y reportes' },
  { id_rol: 2, nombre: 'user', descripcion: 'Operación comercial: clientes, oportunidades, propuestas, ventas, pagos y reportes' },
  { id_rol: 3, nombre: 'user_demo', descripcion: 'Solo lectura: consulta información y reportes, no puede modificar nada' },
], 'Catálogo cerrado: el ENUM solo admite 3 niveles de acceso (decisión de diseño)')

const PERMISOS = [
  ['usuarios.gestionar', 'Crear, editar, activar y desactivar usuarios'],
  ['clientes.ver', 'Consultar la lista y el detalle de los clientes'],
  ['clientes.crear', 'Registrar clientes nuevos'],
  ['clientes.editar', 'Modificar los datos de un cliente'],
  ['oportunidades.gestionar', 'Crear oportunidades y moverlas de etapa'],
  ['campanas.gestionar', 'Crear y administrar campañas de marketing'],
  ['ventas.registrar', 'Registrar ventas y sus pagos'],
  ['reportes.ver', 'Consultar reportes comerciales'],
  ['auditoria.ver', 'Revisar el historial de auditoría'],
  ['configuracion.editar', 'Cambiar la configuración del sistema'],
  ['clientes.desactivar', 'Desactivar clientes sin borrar su historial'],
  ['prospectos.ver', 'Consultar prospectos y su seguimiento'],
  ['prospectos.crear', 'Registrar prospectos y asignar vendedor'],
  ['oportunidades.ver', 'Consultar oportunidades comerciales'],
  ['propuestas.ver', 'Consultar propuestas comerciales'],
  ['propuestas.crear', 'Crear propuestas con su detalle de productos'],
  ['propuestas.aprobar', 'Cambiar el estado de una propuesta (enviar, aceptar, rechazar)'],
  ['ventas.ver', 'Consultar ventas y su saldo'],
  ['pagos.registrar', 'Registrar y aprobar pagos'],
  ['pagos.ver', 'Consultar pagos'],
  ['vendedores.ver', 'Consultar vendedores y su desempeño'],
  ['vendedores.gestionar', 'Crear vendedores y reasignar clientes'],
  ['campanas.ver', 'Consultar campañas de marketing'],
  ['productos.ver', 'Consultar el catálogo de productos'],
  ['productos.gestionar', 'Crear productos y actualizar precios'],
  ['seguimientos.registrar', 'Registrar tareas, llamadas y reuniones'],
  ['eventos.gestionar', 'Administrar el calendario comercial'],
  ['tareas.gestionar', 'Crear y cerrar tareas'],
  ['correos.enviar', 'Enviar correos a clientes'],
  ['reportes.exportar', 'Generar y descargar reportes'],
]
insertar('permisos', ['id_permiso', 'nombre', 'descripcion'], PERMISOS.map(([nombre, descripcion], i) => ({ id_permiso: i + 1, nombre, descripcion })))

const PERM_USER = [2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 24, 26, 27, 28, 29, 30]
const PERM_DEMO = [2, 8, 12, 14, 15, 18, 20, 21, 23, 24]
insertar('usuarios_roles', ['id_usuario', 'id_rol'], usuarios.map((u) => ({ id_usuario: u.id_usuario, id_rol: u.rol })))
insertar('roles_permisos', ['id_rol', 'id_permiso'], [
  ...ids(30).map((p) => ({ id_rol: 1, id_permiso: p })),
  ...PERM_USER.map((p) => ({ id_rol: 2, id_permiso: p })),
  ...PERM_DEMO.map((p) => ({ id_rol: 3, id_permiso: p })),
])
insertar('configuracion_usuario', ['id_configuracion', 'id_usuario', 'zona_horaria', 'idioma', 'notificaciones'],
  usuarios.map((u) => ({ id_configuracion: u.id_usuario, id_usuario: u.id_usuario, zona_horaria: 'America/Bogota', idioma: u.id_usuario % 9 === 0 ? 'en' : 'es', notificaciones: u.id_usuario % 4 === 0 ? 0 : 1 })))

// ============================================================
// 3. Vendedores (30: usuarios 2, 3, 4 y 6..32)
// ============================================================
const vendedores = []
const usuariosVendedores = [2, 3, 4, ...ids(27, 6)]
usuariosVendedores.forEach((idUsuario, i) => {
  const id = i + 1
  vendedores.push({
    id_vendedor: id,
    id_usuario: idUsuario,
    codigo: `VEN-${String(id).padStart(3, '0')}`,
    especialidad: id <= 3 ? ESPECIALIDADES[i] : ESPECIALIDADES[id % ESPECIALIDADES.length],
    estado: id === 30 ? 0 : 1, // un vendedor retirado
  })
})
const usuarioDe = (idVendedor) => vendedores[idVendedor - 1].id_usuario
const vendedoresActivos = vendedores.filter((v) => v.estado === 1).map((v) => v.id_vendedor)

titulo('3. Vendedores')
insertar('vendedores', ['id_vendedor', 'id_usuario', 'codigo', 'especialidad', 'estado'], vendedores)

// ============================================================
// 4. Clientes
//    1,2,4,6,8 y 9..33  -> clientes con compras (30)
//    3,5,7 y 34..55     -> prospectos (25)
//    56..60             -> inactivos (5)
// ============================================================
const clientes = [
  { id_cliente: 1, tipo_cliente: 'empresa', nombre: 'Tecnología Andina S.A.S.', apellido: null, documento: '900123456-7', correo: 'contacto@tecandina.com', telefono: '+57 601 555 0101', direccion: 'Carrera 11 # 93-45, Bogotá D.C.', estado: 1 },
  { id_cliente: 2, tipo_cliente: 'empresa', nombre: 'Comercializadora El Sol Ltda.', apellido: null, documento: '900987654-1', correo: 'gerencia@elsol.com.co', telefono: '+57 604 555 0202', direccion: 'Calle 10 # 40-12, Medellín', estado: 1 },
  { id_cliente: 3, tipo_cliente: 'persona', nombre: 'María Fernanda', apellido: 'López', documento: '1020304050', correo: 'maria.lopez@correo.com', telefono: '+57 310 555 0303', direccion: 'Calle 45 # 12-30, Bogotá D.C.', estado: 1 },
  { id_cliente: 4, tipo_cliente: 'empresa', nombre: 'Inversiones Pacífico S.A.', apellido: null, documento: '890456123-9', correo: 'info@invpacifico.com', telefono: '+57 602 555 0404', direccion: 'Avenida 6N # 23-10, Cali', estado: 1 },
  { id_cliente: 5, tipo_cliente: 'persona', nombre: 'Jorge Enrique', apellido: 'Ramírez', documento: '79456123', correo: 'jorge.ramirez@correo.com', telefono: '+57 315 555 0505', direccion: 'Carrera 7 # 72-15, Bogotá D.C.', estado: 1 },
  { id_cliente: 6, tipo_cliente: 'empresa', nombre: 'Clínica San Rafael', apellido: null, documento: '860012345-4', correo: 'administracion@clinicasr.com', telefono: '+57 601 555 0606', direccion: 'Calle 100 # 20-55, Bogotá D.C.', estado: 1 },
  { id_cliente: 7, tipo_cliente: 'persona', nombre: 'Camila Andrea', apellido: 'Vargas', documento: '1015987654', correo: 'camila.vargas@correo.com', telefono: '+57 300 555 0707', direccion: 'Carrera 53 # 79-20, Barranquilla', estado: 1 },
  { id_cliente: 8, tipo_cliente: 'empresa', nombre: 'Logística del Norte S.A.S.', apellido: null, documento: '901234567-8', correo: 'operaciones@logisnorte.com', telefono: '+57 607 555 0808', direccion: 'Calle 15 # 30-40, Bucaramanga', estado: 1 },
]
const fechasCreacionOriginales = ['2026-09-05 09:15:00', '2026-09-08 10:30:00', '2026-09-12 14:00:00', '2026-08-20 08:45:00', '2026-09-20 11:20:00', '2026-09-25 16:10:00', '2026-10-01 09:00:00', '2026-08-25 13:40:00']
clientes.forEach((c, i) => { c.fecha_creacion = fechasCreacionOriginales[i] })

const documentos = new Set(clientes.map((c) => c.documento))
let empresaIdx = 0
for (let id = 9; id <= 60; id++) {
  const [ciudad, indicativo] = elegir(CIUDADES)
  const direccion = `${elegir(['Calle', 'Carrera', 'Avenida', 'Transversal', 'Diagonal'])} ${entero(1, 150)} # ${entero(1, 99)}-${entero(1, 99)}, ${ciudad}`
  let c
  if (id % 4 === 0) {
    const nombre = NOMBRES[(id * 3) % NOMBRES.length]
    const apellido = APELLIDOS[(id * 5) % APELLIDOS.length]
    let doc = String(entero(1000000000, 1099999999))
    while (documentos.has(doc)) doc = String(entero(1000000000, 1099999999))
    c = { id_cliente: id, tipo_cliente: 'persona', nombre, apellido, documento: doc, correo: `${slug(nombre)}.${slug(apellido)}${id}@correo.com`, telefono: `+57 3${entero(0, 2)}${entero(0, 9)} ${entero(100, 999)} ${entero(1000, 9999)}`, direccion }
  } else {
    const nombre = EMPRESAS[empresaIdx++]
    let doc = `${entero(800000000, 901999999)}-${entero(0, 9)}`
    while (documentos.has(doc)) doc = `${entero(800000000, 901999999)}-${entero(0, 9)}`
    const dominio = slug(nombre.replace(/S\.A\.S\.|S\.A\.|Ltda\./g, '')).replace(/\./g, '').slice(0, 18)
    c = { id_cliente: id, tipo_cliente: 'empresa', nombre, apellido: null, documento: doc, correo: `contacto@${dominio}.com.co`, telefono: `+57 ${indicativo} ${entero(200, 799)} ${entero(1000, 9999)}`, direccion }
  }
  documentos.add(c.documento)
  c.estado = id >= 56 ? 0 : 1
  // los clientes con compras se crearon antes; los prospectos, más recientes
  c.fecha_creacion = txt(id <= 33 ? entre(fecha(2025, 9, 1), fecha(2026, 3, 1)) : entre(fecha(2026, 3, 1), fecha(2026, 10, 25)))
  clientes.push(c)
}
const CLIENTES_COMPRA = [1, 2, 4, 6, 8, ...ids(25, 9)]
const PROSPECTOS = [3, 5, 7, ...ids(22, 34)]
const INACTIVOS = ids(5, 56)
const VIP = [1, 4, 9, 14, 19, 24, 29]

titulo('2. Clientes, contactos, categorías y etiquetas')
insertar('categorias_clientes', ['id_categoria', 'nombre', 'descripcion'], [
  { id_categoria: 1, nombre: 'Prospecto', descripcion: 'Cliente potencial aún no convertido' },
  { id_categoria: 2, nombre: 'Cliente activo', descripcion: 'Cliente con compras o contrato vigente' },
  { id_categoria: 3, nombre: 'Cliente VIP', descripcion: 'Cliente estratégico de alto valor' },
  { id_categoria: 4, nombre: 'Inactivo', descripcion: 'Cliente sin actividad reciente' },
  { id_categoria: 5, nombre: 'Potencial', descripcion: 'Prospecto con alto nivel de interacción reciente (lo calcula actualizar_clientes_potenciales)' },
], 'Catálogo de segmentos: 5 valores fijos por diseño')
insertar('clientes', ['id_cliente', 'tipo_cliente', 'nombre', 'apellido', 'documento', 'correo', 'telefono', 'direccion', 'estado', 'fecha_creacion'], clientes)

// Contactos: los originales + uno por cliente (dos para la mitad de las empresas)
const contactos = [
  { id_contacto: 1, id_cliente: 1, nombre: 'Juan Pablo', apellido: 'Pérez', correo: 'juan.perez@tecandina.com', telefono: '+57 601 555 0111', cargo: 'Gerente de TI' },
  { id_contacto: 2, id_cliente: 1, nombre: 'Andrea', apellido: 'Salazar', correo: 'andrea.salazar@tecandina.com', telefono: '+57 601 555 0112', cargo: 'Jefa de Compras' },
  { id_contacto: 3, id_cliente: 2, nombre: 'Ricardo', apellido: 'Molina', correo: 'ricardo.molina@elsol.com.co', telefono: '+57 604 555 0211', cargo: 'Gerente General' },
  { id_contacto: 4, id_cliente: 3, nombre: 'María Fernanda', apellido: 'López', correo: 'maria.lopez@correo.com', telefono: '+57 310 555 0303', cargo: 'Independiente' },
  { id_contacto: 5, id_cliente: 4, nombre: 'Valentina', apellido: 'Cruz', correo: 'valentina.cruz@invpacifico.com', telefono: '+57 602 555 0411', cargo: 'Directora Administrativa' },
  { id_contacto: 6, id_cliente: 5, nombre: 'Jorge Enrique', apellido: 'Ramírez', correo: 'jorge.ramirez@correo.com', telefono: '+57 315 555 0505', cargo: 'Consultor' },
  { id_contacto: 7, id_cliente: 6, nombre: 'Felipe', apellido: 'Ospina', correo: 'felipe.ospina@clinicasr.com', telefono: '+57 601 555 0611', cargo: 'Director Médico' },
  { id_contacto: 8, id_cliente: 8, nombre: 'Sandra Milena', apellido: 'Ríos', correo: 'sandra.rios@logisnorte.com', telefono: '+57 607 555 0811', cargo: 'Jefa de Operaciones' },
]
contactos.push({ id_contacto: 9, id_cliente: 7, nombre: 'Camila Andrea', apellido: 'Vargas', correo: 'camila.vargas@correo.com', telefono: '+57 300 555 0707', cargo: 'Independiente' })
for (const c of clientes.filter((x) => x.id_cliente >= 9)) {
  if (c.tipo_cliente === 'persona') {
    contactos.push({ id_contacto: contactos.length + 1, id_cliente: c.id_cliente, nombre: c.nombre, apellido: c.apellido, correo: c.correo, telefono: c.telefono, cargo: 'Independiente' })
    continue
  }
  const dominio = c.correo.split('@')[1]
  const cantidad = c.id_cliente % 2 === 0 ? 2 : 1
  for (let k = 0; k < cantidad; k++) {
    const nombre = elegir(NOMBRES)
    const apellido = elegir(APELLIDOS)
    contactos.push({ id_contacto: contactos.length + 1, id_cliente: c.id_cliente, nombre, apellido, correo: `${slug(nombre).split('.')[0]}.${slug(apellido)}@${dominio}`, telefono: `+57 3${entero(0, 2)}${entero(0, 9)} ${entero(100, 999)} ${entero(1000, 9999)}`, cargo: elegir(CARGOS) })
  }
}
insertar('contactos', ['id_contacto', 'id_cliente', 'nombre', 'apellido', 'correo', 'telefono', 'cargo'], contactos)

const cc = []
for (const id of CLIENTES_COMPRA) {
  cc.push({ id_cliente: id, id_categoria: 2 })
  if (VIP.includes(id)) cc.push({ id_cliente: id, id_categoria: 3 })
}
for (const id of PROSPECTOS) cc.push({ id_cliente: id, id_categoria: 1 })
for (const id of INACTIVOS) cc.push({ id_cliente: id, id_categoria: 4 })
insertar('clientes_categorias', ['id_cliente', 'id_categoria'], cc)

const ETIQUETAS = [['Cliente potencial', '#3498db'], ['Interesado en correo', '#2ecc71'], ['Seguimiento urgente', '#e74c3c'], ['Referido', '#9b59b6'], ['Decisor', '#1abc9c'], ['Influenciador', '#16a085'], ['Técnico', '#27ae60'], ['Financiero', '#2980b9'], ['Compras', '#8e44ad'], ['Renovación próxima', '#f39c12'], ['Sector salud', '#d35400'], ['Sector educación', '#c0392b'], ['Sector público', '#7f8c8d'], ['Pyme', '#34495e'], ['Gran cuenta', '#e67e22'], ['Interesado en seguridad', '#e84393'], ['Interesado en migración', '#00b894'], ['Prueba gratuita activa', '#00cec9'], ['Asistió a webinar', '#0984e3'], ['Solicitó demo', '#6c5ce7'], ['Sin respuesta', '#b2bec3'], ['Promotor', '#55efc4'], ['Detractor', '#ff7675'], ['Newsletter', '#74b9ff'], ['Evento presencial', '#a29bfe'], ['Contacto principal', '#fdcb6e'], ['Facturación', '#e17055'], ['Soporte', '#636e72'], ['Alta prioridad', '#d63031'], ['Baja prioridad', '#81ecec']]
insertar('etiquetas', ['id_etiqueta', 'nombre', 'color'], ETIQUETAS.map(([nombre, color], i) => ({ id_etiqueta: i + 1, nombre, color })))
const ce = [[1, 2], [2, 1], [3, 2], [4, 1], [5, 3], [6, 4], [7, 2], [8, 1]].map(([a, b]) => ({ id_contacto: a, id_etiqueta: b }))
for (const c of contactos.filter((x) => x.id_contacto >= 9)) {
  const primera = entero(1, 30)
  ce.push({ id_contacto: c.id_contacto, id_etiqueta: primera })
  if (prob(0.4)) ce.push({ id_contacto: c.id_contacto, id_etiqueta: (primera % 30) + 1 })
}
insertar('contactos_etiquetas', ['id_contacto', 'id_etiqueta'], ce)

// Asignaciones: cada cliente tiene un vendedor; algunos fueron reasignados
const vendedorDe = { 1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 3, 8: 2 }
const asignaciones = []
const fechasAsigOriginales = ['2026-09-05 09:15:00', '2026-09-08 10:30:00', '2026-09-12 14:00:00', '2026-08-20 08:45:00', '2026-09-20 11:20:00', '2026-09-25 16:10:00', '2026-10-01 09:00:00', '2026-08-25 13:40:00']
for (let id = 1; id <= 8; id++) asignaciones.push({ id_asignacion: id, id_cliente: id, id_vendedor: vendedorDe[id], fecha_asignacion: fechasAsigOriginales[id - 1] })
for (const c of clientes.filter((x) => x.id_cliente >= 9)) {
  const v = vendedoresActivos[(c.id_cliente * 7) % vendedoresActivos.length]
  const creado = Date.parse(c.fecha_creacion.replace(' ', 'T') + 'Z')
  // reasignación: primero estuvo con otro vendedor (el retirado, VEN-030, en algunos casos)
  if (c.id_cliente % 5 === 0) {
    asignaciones.push({ id_asignacion: asignaciones.length + 1, id_cliente: c.id_cliente, id_vendedor: c.id_cliente % 10 === 0 ? 30 : vendedoresActivos[(c.id_cliente * 3) % vendedoresActivos.length], fecha_asignacion: txt(creado + DIA) })
  }
  asignaciones.push({ id_asignacion: asignaciones.length + 1, id_cliente: c.id_cliente, id_vendedor: v, fecha_asignacion: txt(creado + (c.id_cliente % 5 === 0 ? 20 : 1) * DIA) })
  vendedorDe[c.id_cliente] = v
}
insertar('asignaciones_clientes', ['id_asignacion', 'id_cliente', 'id_vendedor', 'fecha_asignacion'], asignaciones)

// ============================================================
// 5. Productos
// ============================================================
// tipo: 'u' = por usuario (licencias), 's' = servicio
const productos = [
  [1, 'Zimbra Starter', 'Plan básico de correo para pequeños equipos.', 45000, 'u', 5000],
  [2, 'Zimbra Professional', 'Plan profesional con calendario y colaboración.', 85000, 'u', 4000],
  [3, 'Zimbra Enterprise', 'Plan empresarial de alta disponibilidad.', 145000, 'u', 3000],
  [4, 'Módulo Antispam Avanzado', 'Filtro antispam y antiphishing gestionado.', 25000, 'u', 8000],
  [5, 'Zimbra Suite Plus', 'Suite de colaboración y movilidad.', 120000, 'u', 2500],
  [6, 'Soporte Premium 24/7', 'Soporte prioritario con SLA de 4 horas.', 300000, 's', 999],
  [7, 'Zimbra Basic Cloud', 'Correo en la nube para microempresas.', 30000, 'u', 6000],
  [8, 'Migración de buzones', 'Migración asistida desde otro proveedor (por buzón).', 40000, 'u', 9000],
  [9, 'Capacitación virtual', 'Sesión de capacitación en línea para usuarios finales.', 450000, 's', 500],
  [10, 'Capacitación presencial', 'Jornada de capacitación en sitio (por día).', 1800000, 's', 200],
  [11, 'Módulo de Cifrado S/MIME', 'Firma y cifrado de correos.', 35000, 'u', 5000],
  [12, 'Archivado y eDiscovery', 'Retención legal y búsqueda de correos.', 55000, 'u', 4000],
  [13, 'Backup en la nube', 'Respaldo diario de buzones (por usuario).', 20000, 'u', 9000],
  [14, 'Almacenamiento adicional 50 GB', 'Ampliación de cuota por usuario.', 15000, 'u', 9000],
  [15, 'Zimbra Connect', 'Videoconferencia integrada (por usuario).', 60000, 'u', 4000],
  [16, 'Zimbra Talk', 'Chat corporativo (por usuario).', 25000, 'u', 6000],
  [17, 'Zimbra Docs', 'Edición colaborativa de documentos (por usuario).', 30000, 'u', 6000],
  [18, 'Conector Outlook', 'Sincronización con Microsoft Outlook (por usuario).', 18000, 'u', 7000],
  [19, 'Sincronización móvil ActiveSync', 'Correo y calendario en el móvil (por usuario).', 22000, 'u', 7000],
  [20, 'Consultoría de arquitectura', 'Hora de consultoría especializada.', 250000, 's', 2000],
  [21, 'Implementación on-premise', 'Despliegue en servidores del cliente.', 8500000, 's', 100],
  [22, 'Implementación en nube privada', 'Despliegue en nube privada administrada.', 6500000, 's', 100],
  [23, 'Licencia de alta disponibilidad', 'Clúster activo-pasivo.', 2500000, 's', 300],
  [24, 'Auditoría de seguridad de correo', 'Revisión de configuración y riesgos.', 4200000, 's', 150],
  [25, 'Soporte Estándar 8x5', 'Soporte en horario laboral (por mes).', 120000, 's', 2000],
  [26, 'Paquete educación', 'Licencia académica (por usuario).', 12000, 'u', 20000],
  [27, 'Paquete salud con cumplimiento', 'Correo con controles para datos clínicos (por usuario).', 95000, 'u', 3000],
  [28, 'Integración API con CRM', 'Conexión del correo con el CRM del cliente.', 3800000, 's', 150],
  [29, 'Monitoreo y alertas 24/7', 'Monitoreo de la plataforma (por mes).', 900000, 's', 500],
  [30, 'Filtro DLP', 'Prevención de fuga de información (por usuario).', 28000, 'u', 6000],
].map(([id_producto, nombre, descripcion, precio, tipo, stock]) => ({ id_producto, nombre, descripcion, precio, tipo, stock, estado: id_producto === 7 ? 0 : 1 }))
const precioDe = (id) => productos[id - 1].precio

titulo('6. Productos y categorías')
const CATEGORIAS_PRODUCTOS = ['Correo corporativo', 'Seguridad', 'Colaboración', 'Soporte', 'Migración', 'Almacenamiento', 'Movilidad', 'Respaldo', 'Archivado', 'Antispam', 'Cifrado', 'Capacitación', 'Consultoría', 'Licenciamiento', 'Integraciones', 'Videoconferencia', 'Mensajería instantánea', 'Documentos', 'Cumplimiento normativo', 'Alta disponibilidad', 'Nube pública', 'Nube privada', 'On-premise', 'Sector salud', 'Sector educación', 'Monitoreo', 'Productividad', 'Pymes', 'Grandes empresas', 'Servicios profesionales']
insertar('categorias_productos', ['id_categoria', 'nombre', 'descripcion'], CATEGORIAS_PRODUCTOS.map((nombre, i) => ({ id_categoria: i + 1, nombre, descripcion: `Productos y servicios de ${nombre.toLowerCase()}` })))
insertar('productos', ['id_producto', 'nombre', 'descripcion', 'precio', 'stock', 'estado'], productos.map((p) => ({ ...p, precio: dinero(p.precio) })))

const det = [[1, 'Usuarios incluidos', '10'], [1, 'Almacenamiento', '10 GB por usuario'], [2, 'Usuarios incluidos', '50'], [2, 'Almacenamiento', '50 GB por usuario'], [3, 'Usuarios incluidos', 'Ilimitados'], [3, 'Alta disponibilidad', 'Sí'], [4, 'Vigencia', '12 meses'], [5, 'Movilidad', 'Android e iOS'], [6, 'Tiempo de respuesta', '4 horas']]
det.push([4, 'Modalidad', 'Por usuario'], [5, 'Vigencia', '12 meses'], [6, 'Vigencia', '12 meses'])
for (const p of productos.filter((x) => x.id_producto >= 7)) {
  det.push([p.id_producto, 'Modalidad', p.tipo === 'u' ? 'Por usuario' : 'Por servicio'])
  det.push([p.id_producto, 'Vigencia', p.tipo === 'u' ? '12 meses' : elegir(['Única vez', '1 mes', '12 meses'])])
}
insertar('productos_detalles', ['id_detalle', 'id_producto', 'atributo', 'valor'], det.map(([id_producto, atributo, v], i) => ({ id_detalle: i + 1, id_producto, atributo, valor: v })))

const pc = [[1, 1], [2, 1], [2, 3], [3, 1], [3, 3], [4, 2], [5, 3], [6, 4]]
const CAT_PROD = { 1: [28], 3: [29], 4: [10], 5: [7], 6: [26], 7: [1, 21], 8: [5, 30], 9: [12, 30], 10: [12, 30], 11: [2, 11], 12: [9, 19], 13: [8, 6], 14: [6, 21], 15: [16, 27], 16: [17, 27], 17: [18, 3], 18: [15, 27], 19: [7, 15], 20: [13, 30], 21: [23, 30], 22: [22, 30], 23: [20, 29], 24: [2, 19], 25: [4, 14], 26: [25, 14], 27: [24, 19], 28: [15, 13], 29: [26, 4], 30: [2, 19] }
for (const [p, cats] of Object.entries(CAT_PROD)) for (const c of cats) pc.push([Number(p), c])
insertar('productos_categorias', ['id_producto', 'id_categoria'], pc.map(([id_producto, id_categoria]) => ({ id_producto, id_categoria })))

// ============================================================
// 6. Oportunidades, propuestas, ventas y pagos
// ============================================================
const PLANES = [1, 2, 3, 5, 26, 27]
const COMPLEMENTOS_U = [4, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 30]
const SERVICIOS = [[6, 1, 1], [9, 1, 4], [10, 1, 3], [20, 8, 40], [21, 1, 1], [22, 1, 1], [23, 1, 1], [24, 1, 1], [25, 6, 12], [28, 1, 1], [29, 3, 12]]

function lineasAleatorias() {
  const plan = elegir(PLANES)
  const usuariosN = plan === 26 ? entero(200, 900) : entero(15, 320)
  const lineas = [[plan, usuariosN]]
  const extras = entero(0, 2)
  const usados = new Set([plan])
  for (let k = 0; k < extras; k++) {
    if (prob(0.55)) {
      const comp = elegir(COMPLEMENTOS_U)
      if (!usados.has(comp)) { usados.add(comp); lineas.push([comp, usuariosN]) }
    } else {
      const [srv, a, b] = elegir(SERVICIOS)
      if (!usados.has(srv)) { usados.add(srv); lineas.push([srv, entero(a, b)]) }
    }
  }
  return lineas
}
const totalDe = (lineas) => lineas.reduce((s, [p, q]) => s + precioDe(p) * q, 0)
const tituloDe = (lineas) => {
  const plan = productos[lineas[0][0] - 1].nombre
  return elegir([`Correo corporativo ${plan} para ${lineas[0][1]} usuarios`, `Migración a ${plan}`, `Renovación de licencias ${plan}`, `Implementación ${plan} con soporte`, `Suite colaborativa ${plan}`])
}

const oportunidades = []
const opDetalle = []
const propuestas = []
const propDet = []
const ventas = []
const ventasProd = []
const pagos = []

// --- registros originales (corregidos para que sean coherentes) ---
oportunidades.push(
  { id_oportunidad: 1, id_cliente: 1, id_vendedor: 1, id_etapa: 5, titulo: 'Migración a correo corporativo Zimbra', descripcion: 'Migración de 250 buzones a Zimbra Collaboration Professional con soporte anual.', valor_estimado: 21550000, estado: 'ganada', fecha_cierre: '2026-10-12', fecha_creacion: '2026-09-10 09:00:00' },
  { id_oportunidad: 2, id_cliente: 2, id_vendedor: 1, id_etapa: 3, titulo: 'Licencias Zimbra Collaboration Professional', descripcion: 'Renovación de 120 licencias y módulo antispam avanzado.', valor_estimado: 13200000, estado: 'abierta', fecha_cierre: '2026-11-30', fecha_creacion: '2026-09-18 10:15:00' },
  { id_oportunidad: 3, id_cliente: 4, id_vendedor: 2, id_etapa: 5, titulo: 'Implementación suite colaborativa', descripcion: 'Implementación de Zimbra Enterprise para 400 usuarios con migración incluida.', valor_estimado: 58300000, estado: 'ganada', fecha_cierre: '2026-10-05', fecha_creacion: '2026-08-25 08:30:00' },
  { id_oportunidad: 4, id_cliente: 6, id_vendedor: 3, id_etapa: 2, titulo: 'Correo seguro para personal médico', descripcion: 'Solución de correo con cifrado y cumplimiento para 90 usuarios de la clínica.', valor_estimado: 12800000, estado: 'abierta', fecha_cierre: '2027-01-31', fecha_creacion: '2026-10-02 11:45:00' },
  { id_oportunidad: 5, id_cliente: 8, id_vendedor: 2, id_etapa: 6, titulo: 'Renovación plataforma logística', descripcion: 'Renovación de la plataforma de correo y colaboración para operaciones.', valor_estimado: 8700000, estado: 'perdida', fecha_cierre: '2026-09-30', fecha_creacion: '2026-08-30 15:20:00' },
)
opDetalle.push(
  [1, 'Reunión inicial con el área de TI. Se identificaron 250 buzones.', '2026-09-12 10:00:00'],
  [1, 'Se envió propuesta económica y plan de migración por fases.', '2026-10-10 16:30:00'],
  [2, 'Cliente solicita descuento por renovación anticipada.', '2026-10-18 09:20:00'],
  [3, 'Propuesta aceptada. Inicia implementación el 5 de octubre.', '2026-10-05 12:00:00'],
  [4, 'Primera llamada con el director médico. Interés en cifrado.', '2026-10-08 15:00:00'],
  [5, 'El cliente decidió continuar con su proveedor actual.', '2026-09-30 17:10:00'],
  [1, 'Propuesta aceptada por gerencia. Se firma el contrato.', '2026-10-12 09:30:00'],
)
propuestas.push(
  { id_propuesta: 1, id_oportunidad: 1, fecha: '2026-10-10', estado: 'aceptada', observaciones: 'Incluye migración y capacitación para 250 usuarios.' },
  { id_propuesta: 2, id_oportunidad: 2, fecha: '2026-10-18', estado: 'enviada', observaciones: 'Descuento del 8% por renovación anticipada.' },
  { id_propuesta: 3, id_oportunidad: 3, fecha: '2026-09-25', estado: 'aceptada', observaciones: 'Aprobada por el comité directivo del cliente.' },
  { id_propuesta: 4, id_oportunidad: 5, fecha: '2026-09-10', estado: 'rechazada', observaciones: 'El cliente decidió no renovar con nosotros.' },
)
propDet.push([1, 2, 250], [1, 6, 1], [2, 2, 120], [2, 4, 120], [3, 3, 400], [3, 6, 1], [4, 5, 60], [4, 4, 60])
ventas.push(
  { id_venta: 1, id_cliente: 4, id_vendedor: 2, id_propuesta: 3, fecha: '2026-10-05 12:30:00', estado: 'pagada', lineas: [[3, 400], [6, 1]] },
  { id_venta: 2, id_cliente: 1, id_vendedor: 1, id_propuesta: 1, fecha: '2026-10-12 09:45:00', estado: 'pendiente', lineas: [[2, 250], [6, 1]] },
  { id_venta: 3, id_cliente: 2, id_vendedor: 1, id_propuesta: null, fecha: '2026-10-22 15:10:00', estado: 'pagada', lineas: [[2, 40], [4, 40]] },
  { id_venta: 4, id_cliente: 6, id_vendedor: 3, id_propuesta: null, fecha: '2026-10-28 11:05:00', estado: 'pendiente', lineas: [[1, 20], [4, 20]] },
)
pagos.push(
  [1, 'transferencia', 29150000, '2026-10-06 10:00:00', 'aprobado'],
  [1, 'transferencia', 29150000, '2026-10-20 10:00:00', 'aprobado'],
  // abono aprobado: la venta 2 queda con saldo 16.550.000 (lo paga la demo de procesar_pago_venta)
  [2, 'tarjeta', 5000000, '2026-10-13 09:30:00', 'aprobado'],
  [3, 'pse', 4400000, '2026-10-22 16:00:00', 'aprobado'],
  // pago registrado pero sin aprobar: al aprobarlo, el trigger marca la venta como pagada
  [4, 'efectivo', 1400000, '2026-10-29 11:00:00', 'pendiente'],
)

// --- 26 oportunidades ganadas (clientes 8 y 9..33), una venta por mes ---
const GANADAS = [8, ...ids(25, 9)]
GANADAS.forEach((idCliente, k) => {
  const mes = 1 + (k % 11) // enero a noviembre de 2026
  const fVenta = mes === 11 ? entre(fecha(2026, 11, 2), fecha(2026, 11, 14)) : entre(fecha(2026, mes, 2), fecha(2026, mes, 27))
  const fProp = fVenta - entero(3, 12) * DIA
  const fCrea = fProp - entero(10, 35) * DIA
  const idOp = oportunidades.length + 1
  const idProp = propuestas.length + 1
  const idVenta = ventas.length + 1
  const v = vendedorDe[idCliente]
  const lineas = lineasAleatorias()
  oportunidades.push({ id_oportunidad: idOp, id_cliente: idCliente, id_vendedor: v, id_etapa: 5, titulo: tituloDe(lineas), descripcion: 'Oportunidad cerrada con venta.', valor_estimado: totalDe(lineas), estado: 'ganada', fecha_cierre: txt(fVenta, false), fecha_creacion: txt(fCrea) })
  opDetalle.push([idOp, 'Levantamiento de necesidades con el cliente.', txt(fCrea + 2 * DIA)], [idOp, 'Propuesta aceptada; se registra la venta.', txt(fVenta)])
  propuestas.push({ id_propuesta: idProp, id_oportunidad: idOp, fecha: txt(fProp, false), estado: 'aceptada', observaciones: elegir(['Aprobada por gerencia.', 'Incluye capacitación inicial.', 'Precio sostenido por 12 meses.', 'Aceptada tras ajuste de alcance.']) })
  for (const [p, q] of lineas) propDet.push([idProp, p, q])
  // las ventas recientes quedan pendientes; las antiguas, pagadas
  const estado = fVenta >= fecha(2026, 10, 1) ? 'pendiente' : k % 9 === 4 ? 'pendiente' : 'pagada'
  ventas.push({ id_venta: idVenta, id_cliente: idCliente, id_vendedor: v, id_propuesta: idProp, fecha: txt(fVenta), estado, lineas })
})

// --- 7 oportunidades perdidas (propuesta rechazada) ---
const PERDIDAS = [10, 14, 19, 46, 47, 48, 49]
for (const idCliente of PERDIDAS) {
  const fCierre = entre(fecha(2026, 2, 1), fecha(2026, 10, 30))
  const fProp = fCierre - entero(5, 15) * DIA
  const fCrea = fProp - entero(10, 30) * DIA
  const idOp = oportunidades.length + 1
  const idProp = propuestas.length + 1
  const lineas = lineasAleatorias()
  oportunidades.push({ id_oportunidad: idOp, id_cliente: idCliente, id_vendedor: vendedorDe[idCliente], id_etapa: 6, titulo: tituloDe(lineas), descripcion: 'Oportunidad cerrada sin venta.', valor_estimado: totalDe(lineas), estado: 'perdida', fecha_cierre: txt(fCierre, false), fecha_creacion: txt(fCrea) })
  opDetalle.push([idOp, elegir(['El cliente eligió otro proveedor.', 'Presupuesto congelado hasta el próximo año.', 'Precio por encima de lo esperado.', 'El proyecto fue cancelado por el cliente.']), txt(fCierre)])
  propuestas.push({ id_propuesta: idProp, id_oportunidad: idOp, fecha: txt(fProp, false), estado: 'rechazada', observaciones: 'Rechazada por el cliente.' })
  for (const [p, q] of lineas) propDet.push([idProp, p, q])
}

// --- 12 oportunidades abiertas de prospectos (etapas 1 a 4) ---
const ABIERTAS = ids(12, 34)
ABIERTAS.forEach((idCliente, k) => {
  const etapa = 1 + (k % 4)
  const fCrea = entre(fecha(2026, 8, 15), fecha(2026, 11, 5))
  const idOp = oportunidades.length + 1
  const lineas = lineasAleatorias()
  oportunidades.push({ id_oportunidad: idOp, id_cliente: idCliente, id_vendedor: vendedorDe[idCliente], id_etapa: etapa, titulo: tituloDe(lineas), descripcion: 'Oportunidad en curso.', valor_estimado: totalDe(lineas), estado: 'abierta', fecha_cierre: txt(entre(fecha(2026, 12, 1), fecha(2027, 3, 31)), false), fecha_creacion: txt(fCrea) })
  opDetalle.push([idOp, elegir(['Primer contacto por formulario web.', 'El prospecto pidió una demo.', 'Se solicitó información de precios.', 'Llamada de calificación realizada.']), txt(fCrea + DIA)])
  if (etapa >= 2) {
    const idProp = propuestas.length + 1
    propuestas.push({ id_propuesta: idProp, id_oportunidad: idOp, fecha: txt(Math.min(fCrea + entero(5, 12) * DIA, HOY - DIA), false), estado: etapa === 2 ? 'borrador' : 'enviada', observaciones: etapa === 2 ? 'En preparación.' : 'Enviada, pendiente de respuesta.' })
    for (const [p, q] of lineas) propDet.push([idProp, p, q])
  }
})

// --- 5 ventas directas (sin propuesta) a clientes existentes ---
const DIRECTAS = [[11, 3, 'pagada'], [15, 5, 'pagada'], [20, 7, 'cancelada'], [25, 9, 'pagada'], [30, 10, 'cancelada']]
for (const [idCliente, mes, estado] of DIRECTAS) {
  const plan = elegir([1, 2, 4, 13])
  ventas.push({ id_venta: ventas.length + 1, id_cliente: idCliente, id_vendedor: vendedorDe[idCliente], id_propuesta: null, fecha: txt(entre(fecha(2026, mes, 3), fecha(2026, mes, 26))), estado, lineas: [[plan, entero(5, 40)], ...(prob(0.5) ? [[25, entero(1, 6)]] : [])] })
}

// totales: propuesta = suma de detalle; oportunidad con propuesta = total de su propuesta
const totalPropuesta = {}
for (const [idProp, p, q] of propDet) totalPropuesta[idProp] = (totalPropuesta[idProp] ?? 0) + precioDe(p) * q
for (const pr of propuestas) {
  pr.valor_total = totalPropuesta[pr.id_propuesta]
  const op = oportunidades[pr.id_oportunidad - 1]
  op.valor_estimado = pr.valor_total
}

// pagos de las ventas generadas
for (const v of ventas.filter((x) => x.id_venta >= 5)) {
  v.total = totalDe(v.lineas)
  const base = Date.parse(v.fecha.replace(' ', 'T') + 'Z')
  const metodo = elegir(['transferencia', 'tarjeta', 'pse', 'efectivo'])
  if (v.estado === 'pagada') {
    if (v.total > 20000000 || prob(0.35)) {
      const primera = Math.round(v.total / 2)
      pagos.push([v.id_venta, metodo, primera, txt(base + entero(1, 5) * DIA), 'aprobado'])
      pagos.push([v.id_venta, metodo, v.total - primera, txt(base + entero(15, 30) * DIA), 'aprobado'])
    } else {
      pagos.push([v.id_venta, metodo, v.total, txt(base + entero(1, 10) * DIA), 'aprobado'])
    }
    if (v.id_venta % 6 === 0) pagos.push([v.id_venta, 'tarjeta', v.total, txt(base), 'rechazado']) // intento fallido previo
  } else if (v.estado === 'pendiente') {
    if (v.id_venta % 3 !== 0) pagos.push([v.id_venta, metodo, Math.round(v.total * 0.4), txt(Math.min(base + entero(1, 4) * DIA, HOY - DIA)), 'aprobado'])
  }
}
for (const v of ventas) v.total = totalDe(v.lineas)
// comprobación: ningún pago supera el total y las ventas pagadas cuadran
for (const v of ventas) {
  const ok = pagos.filter((p) => p[0] === v.id_venta && p[4] === 'aprobado').reduce((s, p) => s + p[2], 0)
  const comprometido = pagos.filter((p) => p[0] === v.id_venta && p[4] !== 'rechazado').reduce((s, p) => s + p[2], 0)
  if (comprometido > v.total) throw new Error(`Venta ${v.id_venta}: pagos superan el total`)
  if (v.estado === 'pagada' && ok !== v.total) throw new Error(`Venta ${v.id_venta}: pagada sin cubrir el total`)
  if (v.estado !== 'pagada' && ok >= v.total) throw new Error(`Venta ${v.id_venta}: debería estar pagada`)
}

titulo('4. Oportunidades y seguimientos')
insertar('etapas_ventas', ['id_etapa', 'nombre', 'orden'], ['Prospecto', 'Contacto realizado', 'Propuesta enviada', 'Negociación', 'Cierre ganado', 'Cierre perdido'].map((nombre, i) => ({ id_etapa: i + 1, nombre, orden: i + 1 })), 'Catálogo del embudo de ventas: 6 etapas fijas por diseño')
insertar('oportunidades', ['id_oportunidad', 'id_cliente', 'id_vendedor', 'id_etapa', 'titulo', 'descripcion', 'valor_estimado', 'estado', 'fecha_cierre', 'fecha_creacion'], oportunidades.map((o) => ({ ...o, valor_estimado: dinero(o.valor_estimado) })))
insertar('oportunidades_detalle', ['id_detalle', 'id_oportunidad', 'descripcion', 'fecha'], opDetalle.map(([id_oportunidad, descripcion, f], i) => ({ id_detalle: i + 1, id_oportunidad, descripcion, fecha: f })))

// Seguimientos: los 6 originales + uno o dos por oportunidad
const seguimientos = [
  [1, 2, 'reunion', 'Reunión de levantamiento de requerimientos con TI.', '2026-09-12 10:00:00'],
  [1, 2, 'correo', 'Envío de propuesta técnica y comercial.', '2026-10-10 16:30:00'],
  [1, 2, 'llamada', 'Llamada de cierre: gerencia aprueba la propuesta.', '2026-10-11 11:00:00'],
  [2, 2, 'llamada', 'Negociación de descuento por renovación anticipada.', '2026-10-18 09:20:00'],
  [3, 3, 'reunion', 'Cierre de negociación y firma de acta de inicio.', '2026-10-05 12:00:00'],
  [4, 4, 'correo', 'Envío de brochure de seguridad y cumplimiento.', '2026-10-09 08:40:00'],
]
const TIPOS_SEG = [['llamada', 'Llamada de seguimiento con el cliente.'], ['correo', 'Correo con información solicitada.'], ['reunion', 'Reunión de revisión de alcance.'], ['demo', 'Demostración del producto.'], ['visita', 'Visita a las instalaciones del cliente.']]
for (const o of oportunidades.filter((x) => x.id_oportunidad >= 5)) {
  const inicio = Date.parse(o.fecha_creacion.replace(' ', 'T') + 'Z')
  const fin = o.estado === 'abierta' ? HOY - DIA : Date.parse(o.fecha_cierre + 'T12:00:00Z')
  const n = o.id_oportunidad % 3 === 0 ? 2 : 1
  for (let k = 0; k < n; k++) {
    const [tipo, desc] = elegir(TIPOS_SEG)
    seguimientos.push([o.id_oportunidad, usuarioDe(o.id_vendedor), tipo, desc, txt(entre(inicio + DIA, Math.max(fin, inicio + 2 * DIA)))])
  }
}
insertar('seguimientos', ['id_seguimiento', 'id_oportunidad', 'id_usuario', 'tipo', 'descripcion', 'fecha'], seguimientos.map(([id_oportunidad, id_usuario, tipo, descripcion, f], i) => ({ id_seguimiento: i + 1, id_oportunidad, id_usuario, tipo, descripcion, fecha: f })))

// Tareas
const tareas = [
  [2, 1, 1, 'Enviar contrato de migración', 'Preparar contrato con alcance y cronograma.', '2026-11-15 17:00:00', 'completada'],
  [2, 2, 2, 'Confirmar número de licencias', 'Validar inventario de buzones del cliente.', '2026-11-20 12:00:00', 'pendiente'],
  [3, 4, 3, 'Programar kickoff de implementación', 'Coordinar reunión de inicio con el cliente.', '2026-10-08 10:00:00', 'completada'],
  [4, 6, 4, 'Agendar demo de cifrado', 'Demostración del módulo de seguridad al cliente.', '2026-11-25 15:30:00', 'pendiente'],
  [1, null, null, 'Revisar reporte mensual de ventas', 'Consolidar indicadores de octubre.', '2026-11-05 09:00:00', 'completada'],
  [5, null, null, 'Preparar campaña de fin de año', 'Diseñar piezas y segmentar base de clientes.', '2026-11-30 18:00:00', 'en_proceso'],
]
const TITULOS_TAREA = ['Llamar al prospecto', 'Enviar cotización actualizada', 'Agendar demo', 'Enviar caso de éxito', 'Confirmar decisor de compra', 'Preparar propuesta técnica', 'Hacer seguimiento a la propuesta']
for (const o of oportunidades.filter((x) => x.estado === 'abierta' && x.id_oportunidad > 5)) {
  for (let k = 0; k < 2; k++) {
    const limite = entre(HOY - 20 * DIA, HOY + 40 * DIA)
    tareas.push([usuarioDe(o.id_vendedor), o.id_cliente, o.id_oportunidad, elegir(TITULOS_TAREA), 'Tarea de seguimiento comercial.', txt(limite), limite < HOY ? (prob(0.8) ? 'completada' : 'cancelada') : elegir(['pendiente', 'en_proceso'])])
  }
}
for (const idCliente of [3, 5, 7, 46, 50, 51, 52, 53, 54, 55]) {
  const limite = entre(HOY - 10 * DIA, HOY + 30 * DIA)
  tareas.push([usuarioDe(vendedorDe[idCliente]), idCliente, null, 'Contactar al prospecto', 'Primer contacto para calificar interés.', txt(limite), limite < HOY ? 'completada' : 'pendiente'])
}
insertar('tareas', ['id_tarea', 'id_usuario', 'id_cliente', 'id_oportunidad', 'titulo', 'descripcion', 'fecha_limite', 'estado'], tareas.map(([id_usuario, id_cliente, id_oportunidad, t, descripcion, fecha_limite, estado], i) => ({ id_tarea: i + 1, id_usuario, id_cliente, id_oportunidad, titulo: t, descripcion, fecha_limite, estado })))

titulo('7. Propuestas comerciales')
insertar('propuestas', ['id_propuesta', 'id_oportunidad', 'fecha', 'valor_total', 'estado', 'observaciones'], propuestas.map((p) => ({ ...p, valor_total: dinero(p.valor_total) })))
insertar('propuestas_detalles', ['id_detalle', 'id_propuesta', 'id_producto', 'cantidad', 'precio_unitario', 'subtotal'], propDet.map(([id_propuesta, id_producto, cantidad], i) => ({ id_detalle: i + 1, id_propuesta, id_producto, cantidad, precio_unitario: dinero(precioDe(id_producto)), subtotal: dinero(precioDe(id_producto) * cantidad) })))

titulo('8. Ventas y pagos')
insertar('ventas', ['id_venta', 'id_cliente', 'id_vendedor', 'id_propuesta', 'fecha', 'total', 'estado'], ventas.map((v) => ({ ...v, total: dinero(v.total) })))
for (const v of ventas) for (const [p, q] of v.lineas) ventasProd.push([v.id_venta, p, q])
insertar('ventas_productos', ['id_detalle', 'id_venta', 'id_producto', 'cantidad', 'precio_unitario', 'subtotal'], ventasProd.map(([id_venta, id_producto, cantidad], i) => ({ id_detalle: i + 1, id_venta, id_producto, cantidad, precio_unitario: dinero(precioDe(id_producto)), subtotal: dinero(precioDe(id_producto) * cantidad) })))
insertar('pagos', ['id_pago', 'id_venta', 'metodo_pago', 'valor', 'fecha', 'estado'], pagos.map(([id_venta, metodo_pago, v, f, estado], i) => ({ id_pago: i + 1, id_venta, metodo_pago, valor: dinero(v), fecha: f, estado })))

// ============================================================
// 7. Campañas de marketing
// ============================================================
const campanas = [
  { id_campana: 1, nombre: 'Lanzamiento Zimbra 2026', descripcion: 'Campaña de posicionamiento de la nueva suite.', fecha_inicio: '2026-10-01', fecha_fin: '2026-12-31', presupuesto: 5000000, estado: 'activa' },
  { id_campana: 2, nombre: 'Webinar colaboración empresarial', descripcion: 'Webinar sobre productividad y correo corporativo.', fecha_inicio: '2026-08-01', fecha_fin: '2026-09-15', presupuesto: 2500000, estado: 'finalizada' },
  { id_campana: 3, nombre: 'Campaña fin de año', descripcion: 'Ofertas de renovación para clientes existentes.', fecha_inicio: '2026-11-15', fecha_fin: '2026-12-31', presupuesto: 3500000, estado: 'activa' },
]
const TEMAS = ['Webinar seguridad del correo', 'Newsletter mensual', 'Feria tecnológica', 'Campaña sector salud', 'Campaña sector educación', 'Prueba gratuita 60 días', 'Caso de éxito migración', 'Promoción pymes', 'Evento de clientes VIP', 'Remarketing en redes', 'Encuesta de satisfacción', 'Lanzamiento Zimbra Connect', 'Semana de la ciberseguridad', 'Campaña sector público', 'Desayuno ejecutivo']
for (let id = 4; id <= 30; id++) {
  const inicio = entre(fecha(2025, 7, 1), fecha(2027, 1, 31))
  const fin = inicio + entero(14, 75) * DIA
  let estado = fin < HOY ? 'finalizada' : inicio > HOY ? 'planificada' : 'activa'
  if (id === 12 || id === 25) estado = 'cancelada'
  const tema = TEMAS[id % TEMAS.length]
  const mes = new Date(inicio).toLocaleString('es-CO', { month: 'long', timeZone: 'UTC' })
  campanas.push({ id_campana: id, nombre: `${tema} - ${mes} ${new Date(inicio).getUTCFullYear()}`, descripcion: `Campaña de marketing: ${tema.toLowerCase()}.`, fecha_inicio: txt(inicio, false), fecha_fin: txt(fin, false), presupuesto: entero(8, 90) * 100000, estado })
}
titulo('5. Campañas de marketing')
insertar('campanas_marketing', ['id_campana', 'nombre', 'descripcion', 'fecha_inicio', 'fecha_fin', 'presupuesto', 'estado'], campanas.map((c) => ({ ...c, presupuesto: dinero(c.presupuesto) })))

const camCli = [[1, 1, '2026-10-01 08:00:00'], [1, 3, '2026-10-01 08:00:00'], [1, 7, '2026-10-02 09:30:00'], [2, 2, '2026-08-01 10:00:00'], [2, 5, '2026-08-01 10:00:00'], [3, 4, '2026-11-15 08:00:00'], [3, 6, '2026-11-15 08:00:00'], [3, 8, '2026-11-15 08:00:00']]
const parUsado = new Set(camCli.map(([a, b]) => `${a}-${b}`))
const interacciones = [
  [1, 1, 'correo', 'Abrió el correo y solicitó información.', '2026-10-03 09:12:00'],
  [1, 3, 'correo', 'Sin respuesta después de dos envíos.', '2026-10-10 14:25:00'],
  [1, 7, 'formulario', 'Registró sus datos para una demo.', '2026-10-05 18:40:00'],
  [2, 2, 'webinar', 'Asistió al webinar completo.', '2026-08-20 17:00:00'],
  [2, 5, 'webinar', 'Asistió parcialmente y pidió grabación.', '2026-08-20 17:00:00'],
  [3, 4, 'llamada', 'Interesado en la oferta de renovación.', '2026-11-17 10:15:00'],
]
const RESULTADOS = [['correo', 'Abrió el correo.'], ['correo', 'Hizo clic en el enlace de la oferta.'], ['formulario', 'Completó el formulario de contacto.'], ['webinar', 'Asistió al webinar.'], ['llamada', 'Atendió la llamada y pidió cotización.'], ['descarga', 'Descargó el material de la campaña.'], ['visita', 'Visitó la página de la campaña.']]
for (const c of campanas.filter((x) => x.id_campana >= 4 && x.estado !== 'planificada' && x.estado !== 'cancelada')) {
  const n = entero(2, 4)
  for (let k = 0; k < n; k++) {
    const idCliente = entero(1, 55)
    if (parUsado.has(`${c.id_campana}-${idCliente}`)) continue
    parUsado.add(`${c.id_campana}-${idCliente}`)
    const ini = Date.parse(c.fecha_inicio + 'T08:00:00Z')
    camCli.push([c.id_campana, idCliente, txt(ini)])
    const finReal = Math.min(Date.parse(c.fecha_fin + 'T18:00:00Z'), HOY - DIA)
    const nInter = entero(1, 2)
    for (let j = 0; j < nInter; j++) {
      const [tipo, resultado] = elegir(RESULTADOS)
      interacciones.push([c.id_campana, idCliente, tipo, resultado, txt(entre(ini, Math.max(finReal, ini + DIA)))])
    }
  }
}
insertar('campanas_clientes', ['id_campana', 'id_cliente', 'fecha_asignacion'], camCli.map(([id_campana, id_cliente, f]) => ({ id_campana, id_cliente, fecha_asignacion: f })))
insertar('campanas_interacciones', ['id_interaccion', 'id_campana', 'id_cliente', 'tipo', 'resultado', 'fecha'], interacciones.map(([id_campana, id_cliente, tipo, resultado, f], i) => ({ id_interaccion: i + 1, id_campana, id_cliente, tipo, resultado, fecha: f })))

// ============================================================
// 8. Actividad web, notificaciones, eventos, correos, reportes, auditoría
// ============================================================
titulo('9. Actividad e historial')
const actividad = [
  [2, 1, 'visita', 'Visitó la página de planes empresariales.', '2026-09-10 09:05:00'],
  [2, 1, 'descarga', 'Descargó el comparativo de planes.', '2026-09-10 09:12:00'],
  [3, 3, 'formulario', 'Solicitó una prueba gratuita de 60 días.', '2026-09-12 14:20:00'],
  [3, 3, 'visita', 'Visitó la sección de preguntas frecuentes.', '2026-09-12 14:35:00'],
  [4, 6, 'descarga', 'Descargó el documento de seguridad y cifrado.', '2026-10-02 11:50:00'],
  [5, 7, 'visita', 'Visitó la página de la campaña de fin de año.', '2026-10-05 18:30:00'],
  [2, 2, 'correo', 'Hizo clic en el correo de renovación.', '2026-10-18 09:10:00'],
  [4, 8, 'visita', 'Visitó la página de soporte premium.', '2026-10-03 13:45:00'],
].map(([u, c, a, d, f]) => ({ id_usuario: u, id_cliente: c, accion: a, descripcion: d, fecha: f }))
const ACCIONES = [['visita', 'Visitó la página de precios.'], ['visita', 'Visitó el blog de seguridad.'], ['descarga', 'Descargó la ficha técnica.'], ['formulario', 'Envió el formulario de contacto.'], ['correo', 'Abrió el boletín mensual.'], ['webinar', 'Se registró a un webinar.'], ['prueba', 'Activó la prueba gratuita de 60 días.'], ['demo', 'Solicitó una demostración.']]
for (let k = 0; k < 92; k++) {
  const [accion, descripcion] = elegir(ACCIONES)
  actividad.push({ id_usuario: null, id_cliente: entero(1, 60), accion, descripcion, fecha: txt(entre(fecha(2026, 1, 5), fecha(2026, 10, 15))) })
}
// Actividad reciente (relativa a NOW()) de 4 prospectos: el procedimiento
// actualizar_clientes_potenciales() los marcará como 'Potencial'.
for (const idCliente of [34, 35, 36, 37]) {
  const pasos = [['visita', 12], ['descarga', 9], ['webinar', 9], ['formulario', 5], ['visita', 2], ['demo', 1]]
  for (const [accion, dias] of pasos) {
    actividad.push({ id_usuario: null, id_cliente: idCliente, accion, descripcion: `Actividad reciente: ${accion}.`, fecha: crudo(`NOW() - INTERVAL ${dias + (idCliente % 3)} DAY`) })
  }
}
insertar('actividad_web', ['id_actividad', 'id_usuario', 'id_cliente', 'accion', 'descripcion', 'fecha'], actividad.map((a, i) => ({ id_actividad: i + 1, ...a })))

const notificaciones = [
  [2, 'Nueva tarea asignada', 'Tienes una tarea pendiente: enviar contrato de migración.', 'leida', '2026-10-25 08:00:00'],
  [2, 'Propuesta aceptada', 'Tecnología Andina S.A.S. aceptó la propuesta de migración.', 'leida', '2026-10-12 11:30:00'],
  [3, 'Propuesta aceptada', 'La propuesta de Inversiones Pacífico S.A. fue aceptada.', 'leida', '2026-10-05 12:10:00'],
  [4, 'Recordatorio de demo', 'Demo de cifrado con Clínica San Rafael el 25 de noviembre.', 'pendiente', '2026-11-01 09:00:00'],
  [5, 'Campaña próxima a iniciar', 'La campaña de fin de año inicia el 15 de noviembre.', 'leida', '2026-11-02 10:00:00'],
  [1, 'Reporte mensual disponible', 'El reporte de ventas de octubre está listo para revisión.', 'leida', '2026-11-01 07:30:00'],
]
for (const t of tareas.slice(6, 40)) {
  notificaciones.push([t[0], 'Nueva tarea asignada', `Tienes una tarea: ${t[3].toLowerCase()}.`, prob(0.5) ? 'leida' : 'pendiente', txt(Date.parse(t[5].replace(' ', 'T') + 'Z') - 3 * DIA)])
}
insertar('notificaciones', ['id_notificacion', 'id_usuario', 'titulo', 'mensaje', 'estado', 'fecha'], notificaciones.map(([id_usuario, t, mensaje, estado, f], i) => ({ id_notificacion: i + 1, id_usuario, titulo: t, mensaje, estado, fecha: f })))

titulo('11. Eventos, calendario y recordatorios')
const eventos = [
  [2, 1, 'Reunión de cierre - Tecnología Andina', 'Firma del contrato de migración.', '2026-10-12 10:00:00', '2026-10-12 11:30:00', 'Oficina del cliente', 'reunion', 'realizado'],
  [2, 2, 'Llamada de seguimiento - El Sol', 'Confirmar número de licencias para renovación.', '2026-11-20 09:00:00', '2026-11-20 09:30:00', 'Virtual', 'llamada', 'programado'],
  [3, 4, 'Kickoff de implementación - Inversiones Pacífico', 'Inicio formal del proyecto.', '2026-10-08 14:00:00', '2026-10-08 16:00:00', 'Sala de juntas', 'reunion', 'realizado'],
  [4, 6, 'Demo de cifrado - Clínica San Rafael', 'Demostración del módulo de seguridad.', '2026-11-25 15:30:00', '2026-11-25 16:30:00', 'Virtual', 'cita', 'programado'],
  [1, null, 'Comité comercial mensual', 'Revisión de indicadores y metas.', '2026-11-05 09:00:00', '2026-11-05 10:30:00', 'Sala principal', 'reunion', 'realizado'],
]
const TIPOS_EV = [['llamada', 'Llamada de seguimiento', 'Virtual', 30], ['reunion', 'Reunión comercial', 'Oficina del cliente', 90], ['cita', 'Demostración del producto', 'Virtual', 60], ['otro', 'Visita técnica', 'Instalaciones del cliente', 120]]
for (let k = 0; k < 35; k++) {
  const idCliente = k < 20 ? PROSPECTOS[k % PROSPECTOS.length] : CLIENTES_COMPRA[k % CLIENTES_COMPRA.length]
  const [tipo, nombreEv, ubicacion, minutos] = elegir(TIPOS_EV)
  const inicio = entre(fecha(2026, 9, 1), fecha(2026, 12, 20))
  const cli = clientes[idCliente - 1]
  const estado = k % 17 === 5 ? 'cancelado' : inicio < HOY ? 'realizado' : 'programado'
  eventos.push([usuarioDe(vendedorDe[idCliente]), idCliente, `${nombreEv} - ${cli.nombre}`, 'Actividad del calendario comercial.', txt(inicio), txt(inicio + minutos * 60000), ubicacion, tipo, estado])
}
insertar('eventos', ['id_evento', 'id_usuario', 'id_cliente', 'titulo', 'descripcion', 'fecha_inicio', 'fecha_fin', 'ubicacion', 'tipo', 'estado'], eventos.map(([id_usuario, id_cliente, t, descripcion, fecha_inicio, fecha_fin, ubicacion, tipo, estado], i) => ({ id_evento: i + 1, id_usuario, id_cliente, titulo: t, descripcion, fecha_inicio, fecha_fin, ubicacion, tipo, estado })))

titulo('13. Correos y plantillas')
const correos = [
  [2, 'Propuesta comercial - Migración Zimbra', 'Estimado Juan Pablo, adjuntamos la propuesta para la migración de 250 buzones...', '2026-10-10 17:00:00', 'enviado'],
  [2, 'Seguimiento propuesta Tecnología Andina', 'Hola Andrea, queremos conocer sus comentarios sobre la propuesta enviada...', '2026-10-11 11:10:00', 'enviado'],
  [5, 'Lanzamiento Zimbra 2026', 'Conoce las novedades de nuestra suite de colaboración...', '2026-10-03 08:00:00', 'enviado'],
  [3, 'Confirmación de kickoff', 'Confirmamos la reunión de inicio del proyecto para el 8 de octubre...', '2026-10-06 10:00:00', 'enviado'],
  [1, 'Borrador de comunicado interno', 'Equipo, comparto el borrador del comunicado de resultados del trimestre...', null, 'borrador'],
]
const destinatarios = [[1, 'juan.perez@tecandina.com', 'para'], [1, 'andrea.salazar@tecandina.com', 'cc'], [2, 'andrea.salazar@tecandina.com', 'para'], [3, 'contacto@tecandina.com', 'para'], [3, 'maria.lopez@correo.com', 'para'], [4, 'valentina.cruz@invpacifico.com', 'para'], [5, 'equipo@zimbra-demo.com', 'para']]
const ASUNTOS = ['Propuesta comercial', 'Seguimiento a nuestra reunión', 'Información de planes Zimbra', 'Invitación a demostración', 'Confirmación de pago', 'Bienvenida como cliente']
for (let k = 0; k < 25; k++) {
  const contacto = contactos[(k * 3 + 9) % contactos.length]
  const idUsuario = usuarioDe(vendedorDe[contacto.id_cliente])
  const asunto = `${ASUNTOS[k % ASUNTOS.length]} - ${clientes[contacto.id_cliente - 1].nombre}`
  const borrador = k % 8 === 7
  correos.push([idUsuario, asunto, `Hola ${contacto.nombre}, le escribimos en relación con ${asunto.toLowerCase()}...`, borrador ? null : txt(entre(fecha(2026, 3, 1), fecha(2026, 11, 15))), borrador ? 'borrador' : 'enviado'])
  const idCorreo = correos.length
  destinatarios.push([idCorreo, contacto.correo, 'para'])
  if (k % 2 === 0) destinatarios.push([idCorreo, `ventas@zimbra-demo.com`, 'cco'])
}
insertar('correos', ['id_correo', 'id_usuario', 'asunto', 'contenido', 'fecha_envio', 'estado'], correos.map(([id_usuario, asunto, contenido, fecha_envio, estado], i) => ({ id_correo: i + 1, id_usuario, asunto, contenido, fecha_envio, estado })))
insertar('correos_destinatarios', ['id_destinatario', 'id_correo', 'correo', 'tipo'], destinatarios.map(([id_correo, correo, tipo], i) => ({ id_destinatario: i + 1, id_correo, correo, tipo })))

titulo('14. Reportes y auditoría')
const reportes = [
  [1, 'Reporte de ventas octubre 2026', 'ventas', '/reportes/ventas-2026-10.pdf', '2026-11-01 07:30:00'],
  [1, 'Reporte de oportunidades abiertas', 'oportunidades', '/reportes/oportunidades-2026-11.xlsx', '2026-11-02 08:15:00'],
  [2, 'Desempeño del equipo comercial', 'vendedores', '/reportes/equipo-2026-10.pdf', '2026-11-02 09:00:00'],
  [5, 'Resultados campaña webinar', 'campanas', '/reportes/campana-webinar.xlsx', '2026-09-20 16:00:00'],
]
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre']
MESES.slice(0, 9).forEach((m, i) => reportes.push([1, `Reporte de ventas ${m} 2026`, 'ventas', `/reportes/ventas-2026-${String(i + 1).padStart(2, '0')}.pdf`, txt(fecha(2026, i + 2, 1, 7, 30))]))
MESES.forEach((m, i) => reportes.push([38, `Desempeño de vendedores ${m} 2026`, 'vendedores', `/reportes/vendedores-2026-${String(i + 1).padStart(2, '0')}.pdf`, txt(fecha(2026, i + 2, 2, 8))]))
for (let k = 0; k < 7; k++) reportes.push([33 + (k % 5), `Resultados de campañas (corte ${k + 1})`, 'campanas', `/reportes/campanas-corte-${k + 1}.xlsx`, txt(fecha(2026, 3 + k, 15, 16))])
insertar('reportes_generados', ['id_reporte', 'id_usuario', 'nombre', 'tipo', 'archivo', 'fecha_generacion'], reportes.map(([id_usuario, nombre, tipo, archivo, f], i) => ({ id_reporte: i + 1, id_usuario, nombre, tipo, archivo, fecha_generacion: f })))

const auditoria = [
  [1, 'usuarios', 'INSERT', 5, 'Se creó el usuario Sofía Torres.', '2026-09-01 08:00:00'],
  [2, 'clientes', 'INSERT', 1, 'Se registró el cliente Tecnología Andina S.A.S.', '2026-09-05 09:15:00'],
  [2, 'oportunidades', 'INSERT', 1, 'Se creó la oportunidad de migración de correo.', '2026-09-10 09:00:00'],
  [3, 'propuestas', 'UPDATE', 3, 'La propuesta cambió de enviada a aceptada.', '2026-09-25 17:30:00'],
  [2, 'ventas', 'INSERT', 1, 'Se registró la venta a Inversiones Pacífico S.A.', '2026-10-05 12:30:00'],
  [4, 'tareas', 'UPDATE', 3, 'La tarea de kickoff se marcó como completada.', '2026-10-08 16:05:00'],
  [5, 'campanas_marketing', 'INSERT', 3, 'Se creó la campaña de fin de año.', '2026-11-01 10:00:00'],
  [1, 'usuarios', 'UPDATE', 5, 'Se desactivó el usuario Sofía Torres.', '2026-11-03 09:30:00'],
]
for (const v of ventas.filter((x) => x.id_venta >= 5).slice(0, 22)) {
  auditoria.push([usuarioDe(v.id_vendedor), 'ventas', 'INSERT', v.id_venta, `Se registró la venta #${v.id_venta} por ${v.total}.`, v.fecha])
}
insertar('auditoria', ['id_auditoria', 'id_usuario', 'tabla_afectada', 'operacion', 'registro_id', 'descripcion', 'fecha'], auditoria.map(([id_usuario, tabla_afectada, operacion, registro_id, descripcion, f], i) => ({ id_auditoria: i + 1, id_usuario, tabla_afectada, operacion, registro_id, descripcion, fecha: f })))

process.stdout.write(salida.join('\n') + '\n')
