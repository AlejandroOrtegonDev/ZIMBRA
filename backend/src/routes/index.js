// Punto de entrada de todas las rutas de la API

import { Router } from 'express'
import healthRouter from './health.routes.js'
import authRouter from './auth.routes.js'
import clienteRouter from './cliente.routes.js'
import seguimientoRouter from './seguimiento.routes.js'
import comercialRouter from './comercial.routes.js'
import reporteRouter from './reporte.routes.js'
import negocioRouter from './negocio.routes.js'
import { crearRutasCrud } from './crud.routes.js'
import { crearControladorCrud } from '../controllers/crud.controller.js'
import { autenticar } from '../middlewares/auth.js'

// Modelos para el CRUD genérico
import { Contacto, CategoriaCliente } from '../models/cliente.model.js'
import { Usuario, Rol, Permiso } from '../models/usuario.model.js'
import { AsignacionCliente } from '../models/vendedor.model.js'
import { EtapaVenta, Seguimiento, Tarea } from '../models/oportunidad.model.js'
import { Campana, CampanaInteraccion } from '../models/campana.model.js'
import { CategoriaProducto } from '../models/producto.model.js'
import { Evento } from '../models/evento.model.js'
import { ActividadWeb, Notificacion } from '../models/actividad.model.js'
import { Etiqueta } from '../models/etiqueta.model.js'
import { Correo } from '../models/correo.model.js'
import { Reporte, Auditoria } from '../models/reporte.model.js'
import { Compania } from '../models/compania.model.js'
import { ConfiguracionUsuario } from '../models/configuracion.model.js'

const router = Router()

// ---- Rutas públicas ----

// Raíz: comprueba conexión y lista las tablas
router.use('/', healthRouter)

// Endpoints de estado bajo /api
router.use('/api', healthRouter)

// Registro e inicio de sesión
router.use('/api/auth', authRouter)

// ---- A partir de aquí todo exige sesión (token) ----
router.use('/api', autenticar)

// Compatibilidad con el frontend anterior (GET /api/clients)
router.use('/api/clients', clienteRouter)

// Recurso REST por defecto
router.use('/api/clientes', clienteRouter)

// Seguimiento comercial de prospectos
router.use('/api/clientes', seguimientoRouter)

// Endpoints de negocio: dashboard, pipeline, detalles y permisos.
// Van antes del CRUD genérico para que /roles/matriz y /usuarios/:id/permisos
// no los capture /:id.
router.use('/api', negocioRouter)

// Oportunidades, productos, vendedores, propuestas, ventas y pagos
router.use('/api', comercialRouter)

// Reportes, auditoría y simulación de errores (antes del CRUD de reportes)
router.use('/api', reporteRouter)

// ---- CRUD genérico ----
// Solo para recursos que no tienen ya una ruta propia con permisos.
// Clientes, prospectos, oportunidades, productos, propuestas, ventas,
// vendedores, pagos, usuarios y roles de escritura siguen con sus rutas
// específicas (ver README).

router.use('/api/contactos', crearRutasCrud(Contacto, 'contacto'))
router.use('/api/categorias-clientes', crearRutasCrud(CategoriaCliente, 'categoria_cliente'))
router.use('/api/roles', crearRutasCrud(Rol, 'rol'))
router.use('/api/permisos', crearRutasCrud(Permiso, 'permiso'))
router.use('/api/asignaciones', crearRutasCrud(AsignacionCliente, 'asignacion'))
router.use('/api/etapas', crearRutasCrud(EtapaVenta, 'etapa'))
router.use('/api/seguimientos', crearRutasCrud(Seguimiento, 'seguimiento'))
router.use('/api/tareas', crearRutasCrud(Tarea, 'tarea'))
router.use('/api/campanas', crearRutasCrud(Campana, 'campana'))
router.use('/api/campanas-interacciones', crearRutasCrud(CampanaInteraccion, 'interaccion'))
router.use('/api/categorias-productos', crearRutasCrud(CategoriaProducto, 'categoria_producto'))
router.use('/api/eventos', crearRutasCrud(Evento, 'evento'))
router.use('/api/actividad', crearRutasCrud(ActividadWeb, 'actividad'))
router.use('/api/notificaciones', crearRutasCrud(Notificacion, 'notificacion'))
router.use('/api/etiquetas', crearRutasCrud(Etiqueta, 'etiqueta'))
router.use('/api/correos', crearRutasCrud(Correo, 'correo'))
router.use('/api/reportes', crearRutasCrud(Reporte, 'reporte'))
router.use('/api/auditoria', crearRutasCrud(Auditoria, 'auditoria'))
router.use('/api/compania', crearRutasCrud(Compania, 'compania'))
router.use('/api/configuracion', crearRutasCrud(ConfiguracionUsuario, 'configuracion'))

// Usuarios: solo lectura. El alta y la edición de contraseña van por
// /api/auth (bcrypt); un POST genérico guardaría la clave en texto plano.
const usuarios = crearControladorCrud(Usuario, 'usuario')
router.get('/api/usuarios', usuarios.listar)
router.get('/api/usuarios/:id', usuarios.obtener)

export default router
