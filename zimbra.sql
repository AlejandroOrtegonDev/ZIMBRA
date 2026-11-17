-- ============================================================
-- Sistema de Gestión Comercial Zimbra
-- Esquema + datos de prueba en un único archivo
--
-- Ejecutar completo:
--   mysql -u root -p < zimbra.sql
-- O abrirlo en MySQL Workbench y ejecutarlo todo.
--
-- ADVERTENCIA: este script borra la base 'zimbra' si ya existe.
--
-- Contraseñas de prueba:
--   ana.rodriguez@zimbra-demo.com  -> admin123
--   resto de usuarios              -> 123456
-- ============================================================

DROP DATABASE IF EXISTS zimbra;
CREATE DATABASE zimbra
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE zimbra;

-- ============================================================
-- PARTE 1. ESQUEMA
-- ============================================================

-- 1. USUARIOS, ROLES Y PERMISOS

CREATE TABLE usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    estado TINYINT DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ;

-- Solo se permiten 3 niveles de acceso: user_demo, user y admin
CREATE TABLE roles (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    nombre ENUM('user_demo', 'user', 'admin') NOT NULL,
    descripcion TEXT,
    UNIQUE KEY uk_roles_nombre (nombre)
) ;

CREATE TABLE permisos (
    id_permiso INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT
) ;

CREATE TABLE usuarios_roles (
    id_usuario INT NOT NULL,
    id_rol INT NOT NULL,
    PRIMARY KEY (id_usuario, id_rol),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_rol) REFERENCES roles(id_rol)
) ;

CREATE TABLE roles_permisos (
    id_rol INT NOT NULL,
    id_permiso INT NOT NULL,
    PRIMARY KEY (id_rol, id_permiso),
    FOREIGN KEY (id_rol) REFERENCES roles(id_rol),
    FOREIGN KEY (id_permiso) REFERENCES permisos(id_permiso)
) ;

-- 2. CLIENTES Y CONTACTOS

CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    tipo_cliente ENUM('persona', 'empresa') DEFAULT 'persona',
    nombre VARCHAR(150) NOT NULL,
    apellido VARCHAR(150),
    documento VARCHAR(50),
    correo VARCHAR(150),
    telefono VARCHAR(30),
    direccion VARCHAR(255),
    estado TINYINT DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_documento (documento)
) ;

CREATE TABLE contactos (
    id_contacto INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    apellido VARCHAR(150),
    correo VARCHAR(150),
    telefono VARCHAR(30),
    cargo VARCHAR(100),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
) ;

CREATE TABLE categorias_clientes (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT
) ;

CREATE TABLE clientes_categorias (
    id_cliente INT NOT NULL,
    id_categoria INT NOT NULL,
    PRIMARY KEY (id_cliente, id_categoria),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_categoria) REFERENCES categorias_clientes(id_categoria)
) ;

-- 3. VENDEDORES

CREATE TABLE vendedores (
    id_vendedor INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    codigo VARCHAR(50),
    especialidad VARCHAR(150),
    estado TINYINT DEFAULT 1,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
) ;

CREATE TABLE asignaciones_clientes (
    id_asignacion INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_vendedor INT NOT NULL,
    fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_vendedor) REFERENCES vendedores(id_vendedor)
) ;

-- 4. OPORTUNIDADES Y SEGUIMIENTOS

CREATE TABLE etapas_ventas (
    id_etapa INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    orden INT DEFAULT 1
) ;

CREATE TABLE oportunidades (
    id_oportunidad INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_vendedor INT,
    id_etapa INT,
    titulo VARCHAR(200) NOT NULL,
    descripcion TEXT,
    valor_estimado DECIMAL(12,2) DEFAULT 0,
    estado ENUM('abierta', 'ganada', 'perdida') DEFAULT 'abierta',
    fecha_cierre DATE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_vendedor) REFERENCES vendedores(id_vendedor),
    FOREIGN KEY (id_etapa) REFERENCES etapas_ventas(id_etapa)
) ;

CREATE TABLE oportunidades_detalle (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_oportunidad INT NOT NULL,
    descripcion TEXT NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_oportunidad) REFERENCES oportunidades(id_oportunidad)
) ;

CREATE TABLE seguimientos (
    id_seguimiento INT AUTO_INCREMENT PRIMARY KEY,
    id_oportunidad INT NOT NULL,
    id_usuario INT NOT NULL,
    tipo VARCHAR(50),
    descripcion TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_oportunidad) REFERENCES oportunidades(id_oportunidad),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
) ;

CREATE TABLE tareas (
    id_tarea INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    id_cliente INT,
    id_oportunidad INT,
    titulo VARCHAR(200) NOT NULL,
    descripcion TEXT,
    fecha_limite DATETIME,
    estado ENUM('pendiente', 'en_proceso', 'completada', 'cancelada') DEFAULT 'pendiente',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_oportunidad) REFERENCES oportunidades(id_oportunidad)
) ;

-- 5. CAMPAÑAS DE MARKETING

CREATE TABLE campanas_marketing (
    id_campana INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    fecha_inicio DATE,
    fecha_fin DATE,
    presupuesto DECIMAL(12,2) DEFAULT 0,
    estado ENUM('planificada', 'activa', 'finalizada', 'cancelada') DEFAULT 'planificada',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ;

CREATE TABLE campanas_clientes (
    id_campana INT NOT NULL,
    id_cliente INT NOT NULL,
    fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_campana, id_cliente),
    FOREIGN KEY (id_campana) REFERENCES campanas_marketing(id_campana),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
) ;

CREATE TABLE campanas_interacciones (
    id_interaccion INT AUTO_INCREMENT PRIMARY KEY,
    id_campana INT NOT NULL,
    id_cliente INT NOT NULL,
    tipo VARCHAR(50),
    resultado TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_campana) REFERENCES campanas_marketing(id_campana),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
) ;

-- 6. PRODUCTOS Y CATEGORIAS

CREATE TABLE categorias_productos (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT
) ;

CREATE TABLE productos (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(12,2) NOT NULL DEFAULT 0,
    stock INT DEFAULT 0,
    estado TINYINT DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ;

CREATE TABLE productos_detalles (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    atributo VARCHAR(100),
    valor TEXT,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ;

CREATE TABLE productos_categorias (
    id_producto INT NOT NULL,
    id_categoria INT NOT NULL,
    PRIMARY KEY (id_producto, id_categoria),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    FOREIGN KEY (id_categoria) REFERENCES categorias_productos(id_categoria)
) ;

-- 7. PROPUESTAS COMERCIALES

CREATE TABLE propuestas (
    id_propuesta INT AUTO_INCREMENT PRIMARY KEY,
    id_oportunidad INT NOT NULL,
    fecha DATE,
    valor_total DECIMAL(12,2) DEFAULT 0,
    estado ENUM('borrador', 'enviada', 'aceptada', 'rechazada') DEFAULT 'borrador',
    observaciones TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_oportunidad) REFERENCES oportunidades(id_oportunidad)
) ;

CREATE TABLE propuestas_detalles (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_propuesta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT DEFAULT 1,
    precio_unitario DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (id_propuesta) REFERENCES propuestas(id_propuesta),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ;

-- 8. VENTAS Y PAGOS

CREATE TABLE ventas (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_vendedor INT,
    id_propuesta INT,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(12,2) NOT NULL DEFAULT 0,
    estado ENUM('pendiente', 'pagada', 'cancelada') DEFAULT 'pendiente',
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_vendedor) REFERENCES vendedores(id_vendedor),
    FOREIGN KEY (id_propuesta) REFERENCES propuestas(id_propuesta)
) ;

CREATE TABLE ventas_productos (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (id_venta) REFERENCES ventas(id_venta),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ;

CREATE TABLE pagos (
    id_pago INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    metodo_pago VARCHAR(50),
    valor DECIMAL(12,2) NOT NULL,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('pendiente', 'aprobado', 'rechazado') DEFAULT 'pendiente',
    FOREIGN KEY (id_venta) REFERENCES ventas(id_venta)
) ;

-- 9. ACTIVIDAD E HISTORIAL

CREATE TABLE actividad_web (
    id_actividad INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT,              -- NULL si el visitante es anónimo
    id_cliente INT,
    accion VARCHAR(100),
    descripcion TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- SET NULL: el historial de actividad sobrevive si se borra el usuario
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
) ;

CREATE TABLE notificaciones (
    id_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    titulo VARCHAR(200),
    mensaje TEXT,
    estado ENUM('pendiente', 'leida') DEFAULT 'pendiente',
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
) ;

-- 10. INFORMACION DE LA COMPAÑIA

CREATE TABLE info_companie (
    id_compania INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    nit VARCHAR(50),
    direccion VARCHAR(255),
    telefono VARCHAR(30),
    correo VARCHAR(150),
    logo VARCHAR(255)
) ;

-- 11. EVENTOS, CALENDARIO Y RECORDATORIOS

CREATE TABLE eventos (
    id_evento INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    titulo VARCHAR(200) NOT NULL,
    descripcion TEXT,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    ubicacion VARCHAR(255),
    tipo ENUM('reunion', 'llamada', 'cita', 'otro') DEFAULT 'otro',
    estado ENUM('programado', 'realizado', 'cancelado') DEFAULT 'programado',
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
) ;

-- 12. CONTACTOS Y ETIQUETAS

CREATE TABLE etiquetas (
    id_etiqueta INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    color VARCHAR(20)
) ;

CREATE TABLE contactos_etiquetas (
    id_contacto INT NOT NULL,
    id_etiqueta INT NOT NULL,
    PRIMARY KEY (id_contacto, id_etiqueta),
    FOREIGN KEY (id_contacto) REFERENCES contactos(id_contacto),
    FOREIGN KEY (id_etiqueta) REFERENCES etiquetas(id_etiqueta)
) ;

-- 13. CORREOS Y PLANTILLAS

CREATE TABLE correos (
    id_correo INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    asunto VARCHAR(255),
    contenido LONGTEXT,
    fecha_envio DATETIME,
    estado ENUM('borrador', 'enviado', 'recibido') DEFAULT 'borrador',
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
) ;

CREATE TABLE correos_destinatarios (
    id_destinatario INT AUTO_INCREMENT PRIMARY KEY,
    id_correo INT NOT NULL,
    correo VARCHAR(150) NOT NULL,
    tipo ENUM('para', 'cc', 'cco') DEFAULT 'para',
    FOREIGN KEY (id_correo) REFERENCES correos(id_correo)
) ;

-- 14. REPORTES Y AUDITORIA

CREATE TABLE reportes_generados (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    nombre VARCHAR(150),
    tipo VARCHAR(100),
    archivo VARCHAR(255),
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
) ;

CREATE TABLE auditoria (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT,
    tabla_afectada VARCHAR(100),
    operacion ENUM('INSERT', 'UPDATE', 'DELETE'),
    registro_id INT,
    descripcion TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- SET NULL: la auditoría no se pierde si se borra el usuario
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE SET NULL
) ;

-- 15. CONFIGURACION DE USUARIOS

CREATE TABLE configuracion_usuario (
    id_configuracion INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL UNIQUE,
    zona_horaria VARCHAR(100) DEFAULT 'America/Bogota',
    idioma VARCHAR(10) DEFAULT 'es',
    notificaciones TINYINT DEFAULT 1,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
) ;

-- ============================================================
-- PARTE 2. DATOS DE PRUEBA
-- ============================================================

-- ------------------------------------------------------------
-- 10. Información de la compañía
-- ------------------------------------------------------------
INSERT INTO info_companie (id_compania, nombre, nit, direccion, telefono, correo, logo) VALUES
(1, 'Zimbra Demo S.A.S.', '901555888-1', 'Calle 93 # 15-20, Bogotá D.C.', '+57 601 555 0000', 'contacto@zimbra-demo.com', '/img/logo-zimbra-demo.png');

-- ------------------------------------------------------------
-- 1. Usuarios, roles y permisos
-- ------------------------------------------------------------
INSERT INTO usuarios (id_usuario, nombre, correo, password, estado) VALUES
(1, 'Ana María Rodríguez', 'ana.rodriguez@zimbra-demo.com', '$2y$10$lhjAjW4ZIF3N4FrMVYtxzu5/bWIAox9Fu.ZBTZ0E2DIK8BpLwwi.S', 1),
(2, 'Carlos Gómez',       'carlos.gomez@zimbra-demo.com',  '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1),
(3, 'Laura Martínez',     'laura.martinez@zimbra-demo.com','$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1),
(4, 'Diego Herrera',      'diego.herrera@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1),
(5, 'Sofía Torres',       'sofia.torres@zimbra-demo.com',  '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 0);

INSERT INTO roles (id_rol, nombre, descripcion) VALUES
(1, 'admin',     'Acceso total: gestiona usuarios, configuración, auditoría y reportes'),
(2, 'user',      'Operación comercial: clientes, oportunidades, campañas, ventas y reportes'),
(3, 'user_demo', 'Solo lectura: consulta clientes y reportes, no puede modificar nada');

INSERT INTO permisos (id_permiso, nombre, descripcion) VALUES
(1,  'usuarios.gestionar',     'Crear, editar, activar y desactivar usuarios'),
(2,  'clientes.ver',           'Consultar la lista y el detalle de los clientes'),
(3,  'clientes.crear',         'Registrar clientes nuevos'),
(4,  'clientes.editar',        'Modificar los datos de un cliente'),
(5,  'oportunidades.gestionar','Crear oportunidades y moverlas de etapa'),
(6,  'campanas.gestionar',     'Crear y administrar campañas de marketing'),
(7,  'ventas.registrar',       'Registrar ventas y sus pagos'),
(8,  'reportes.ver',           'Consultar reportes comerciales'),
(9,  'auditoria.ver',          'Revisar el historial de auditoría'),
(10, 'configuracion.editar',   'Cambiar la configuración del sistema');

INSERT INTO usuarios_roles (id_usuario, id_rol) VALUES
(1, 1), -- Ana María  -> admin
(2, 2), -- Carlos     -> user
(3, 2), -- Laura      -> user
(4, 2), -- Diego      -> user
(5, 3); -- Sofía      -> user_demo

INSERT INTO roles_permisos (id_rol, id_permiso) VALUES
-- admin: todos los permisos
(1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8), (1, 9), (1, 10),
-- user: operación comercial completa
(2, 2), (2, 3), (2, 4), (2, 5), (2, 6), (2, 7), (2, 8),
-- user_demo: solo lectura
(3, 2), (3, 8);

INSERT INTO configuracion_usuario (id_configuracion, id_usuario, zona_horaria, idioma, notificaciones) VALUES
(1, 1, 'America/Bogota', 'es', 1),
(2, 2, 'America/Bogota', 'es', 1),
(3, 3, 'America/Bogota', 'es', 1),
(4, 4, 'America/Bogota', 'es', 0),
(5, 5, 'America/Bogota', 'es', 1);

-- ------------------------------------------------------------
-- 3. Vendedores
-- ------------------------------------------------------------
INSERT INTO vendedores (id_vendedor, id_usuario, codigo, especialidad, estado) VALUES
(1, 2, 'VEN-001', 'Correo corporativo y cuentas empresariales', 1),
(2, 3, 'VEN-002', 'Soluciones de colaboración y seguridad', 1),
(3, 4, 'VEN-003', 'Sector salud y logística', 1);

-- ------------------------------------------------------------
-- 2. Clientes y contactos
-- ------------------------------------------------------------
INSERT INTO categorias_clientes (id_categoria, nombre, descripcion) VALUES
(1, 'Prospecto',      'Cliente potencial aún no convertido'),
(2, 'Cliente activo', 'Cliente con compras o contrato vigente'),
(3, 'Cliente VIP',    'Cliente estratégico de alto valor'),
(4, 'Inactivo',       'Cliente sin actividad reciente');

INSERT INTO clientes (id_cliente, tipo_cliente, nombre, apellido, documento, correo, telefono, direccion, estado) VALUES
(1, 'empresa', 'Tecnología Andina S.A.S.',        NULL,               '900123456-7',  'contacto@tecandina.com',       '+57 601 555 0101', 'Carrera 11 # 93-45, Bogotá D.C.',        1),
(2, 'empresa', 'Comercializadora El Sol Ltda.',   NULL,               '900987654-1',  'gerencia@elsol.com.co',        '+57 604 555 0202', 'Calle 10 # 40-12, Medellín',             1),
(3, 'persona', 'María Fernanda',                  'López',            '1020304050',   'maria.lopez@correo.com',       '+57 310 555 0303', 'Calle 45 # 12-30, Bogotá D.C.',          1),
(4, 'empresa', 'Inversiones Pacífico S.A.',       NULL,               '890456123-9',  'info@invpacifico.com',         '+57 602 555 0404', 'Avenida 6N # 23-10, Cali',               1),
(5, 'persona', 'Jorge Enrique',                   'Ramírez',          '79456123',     'jorge.ramirez@correo.com',     '+57 315 555 0505', 'Carrera 7 # 72-15, Bogotá D.C.',         1),
(6, 'empresa', 'Clínica San Rafael',              NULL,               '860012345-4',  'administracion@clinicasr.com', '+57 601 555 0606', 'Calle 100 # 20-55, Bogotá D.C.',         1),
(7, 'persona', 'Camila Andrea',                   'Vargas',           '1015987654',   'camila.vargas@correo.com',     '+57 300 555 0707', 'Carrera 53 # 79-20, Barranquilla',       1),
(8, 'empresa', 'Logística del Norte S.A.S.',      NULL,               '901234567-8',  'operaciones@logisnorte.com',   '+57 607 555 0808', 'Calle 15 # 30-40, Bucaramanga',          1);

INSERT INTO contactos (id_contacto, id_cliente, nombre, apellido, correo, telefono, cargo) VALUES
(1, 1, 'Juan Pablo', 'Pérez',   'juan.perez@tecandina.com',     '+57 601 555 0111', 'Gerente de TI'),
(2, 1, 'Andrea',     'Salazar', 'andrea.salazar@tecandina.com', '+57 601 555 0112', 'Jefa de Compras'),
(3, 2, 'Ricardo',    'Molina',  'ricardo.molina@elsol.com.co',  '+57 604 555 0211', 'Gerente General'),
(4, 3, 'María Fernanda', 'López','maria.lopez@correo.com',      '+57 310 555 0303', 'Independiente'),
(5, 4, 'Valentina',  'Cruz',    'valentina.cruz@invpacifico.com','+57 602 555 0411','Directora Administrativa'),
(6, 5, 'Jorge Enrique','Ramírez','jorge.ramirez@correo.com',    '+57 315 555 0505', 'Consultor'),
(7, 6, 'Felipe',     'Ospina',  'felipe.ospina@clinicasr.com',  '+57 601 555 0611', 'Director Médico'),
(8, 8, 'Sandra Milena','Ríos',   'sandra.rios@logisnorte.com',   '+57 607 555 0811', 'Jefa de Operaciones');

INSERT INTO clientes_categorias (id_cliente, id_categoria) VALUES
(1, 2), (1, 3), (2, 2), (3, 1), (4, 2), (5, 1), (6, 2), (7, 1), (8, 2);

INSERT INTO etiquetas (id_etiqueta, nombre, color) VALUES
(1, 'Cliente potencial',      '#3498db'),
(2, 'Interesado en correo',   '#2ecc71'),
(3, 'Seguimiento urgente',    '#e74c3c'),
(4, 'Referido',               '#9b59b6');

INSERT INTO contactos_etiquetas (id_contacto, id_etiqueta) VALUES
(1, 2), (2, 1), (3, 2), (4, 1), (5, 3), (6, 4), (7, 2), (8, 1);

INSERT INTO asignaciones_clientes (id_asignacion, id_cliente, id_vendedor, fecha_asignacion) VALUES
(1, 1, 1, '2026-09-05 09:15:00'),
(2, 2, 1, '2026-09-08 10:30:00'),
(3, 3, 2, '2026-09-12 14:00:00'),
(4, 4, 2, '2026-09-15 08:45:00'),
(5, 5, 3, '2026-09-20 11:20:00'),
(6, 6, 1, '2026-09-25 16:10:00'),
(7, 7, 3, '2026-10-01 09:00:00'),
(8, 8, 2, '2026-10-03 13:40:00');

-- ------------------------------------------------------------
-- 4. Oportunidades y seguimientos
-- ------------------------------------------------------------
INSERT INTO etapas_ventas (id_etapa, nombre, orden) VALUES
(1, 'Prospecto',          1),
(2, 'Contacto realizado', 2),
(3, 'Propuesta enviada',  3),
(4, 'Negociación',        4),
(5, 'Cierre ganado',      5),
(6, 'Cierre perdido',     6);

INSERT INTO oportunidades (id_oportunidad, id_cliente, id_vendedor, id_etapa, titulo, descripcion, valor_estimado, estado, fecha_cierre, fecha_creacion) VALUES
(1, 1, 1, 4, 'Migración a correo corporativo Zimbra',
    'Migración de 250 buzones a Zimbra Collaboration Professional con soporte anual.',
    21550000.00, 'abierta', '2026-12-15', '2026-09-10 09:00:00'),
(2, 2, 1, 3, 'Licencias Zimbra Collaboration Professional',
    'Renovación de 120 licencias y módulo antispam avanzado.',
    13200000.00, 'abierta', '2026-11-30', '2026-09-18 10:15:00'),
(3, 4, 2, 5, 'Implementación suite colaborativa',
    'Implementación de Zimbra Enterprise para 400 usuarios con migración incluida.',
    58300000.00, 'ganada', '2026-10-20', '2026-08-25 08:30:00'),
(4, 6, 3, 2, 'Correo seguro para personal médico',
    'Solución de correo con cifrado y cumplimiento para 90 usuarios de la clínica.',
    12800000.00, 'abierta', '2027-01-31', '2026-10-02 11:45:00'),
(5, 8, 2, 6, 'Renovación plataforma logística',
    'Renovación de la plataforma de correo y colaboración para operaciones.',
    8700000.00, 'perdida', '2026-09-30', '2026-08-30 15:20:00');

INSERT INTO oportunidades_detalle (id_detalle, id_oportunidad, descripcion, fecha) VALUES
(1, 1, 'Reunión inicial con el área de TI. Se identificaron 250 buzones.', '2026-09-12 10:00:00'),
(2, 1, 'Se envió propuesta económica y plan de migración por fases.',      '2026-10-10 16:30:00'),
(3, 2, 'Cliente solicita descuento por renovación anticipada.',            '2026-10-18 09:20:00'),
(4, 3, 'Propuesta aceptada. Inicia implementación el 5 de octubre.',       '2026-10-05 12:00:00'),
(5, 4, 'Primera llamada con el director médico. Interés en cifrado.',      '2026-10-08 15:00:00'),
(6, 5, 'El cliente decidió continuar con su proveedor actual.',            '2026-09-30 17:10:00');

INSERT INTO seguimientos (id_seguimiento, id_oportunidad, id_usuario, tipo, descripcion, fecha) VALUES
(1, 1, 2, 'reunion',   'Reunión de levantamiento de requerimientos con TI.',        '2026-09-12 10:00:00'),
(2, 1, 2, 'correo',    'Envío de propuesta técnica y comercial.',                   '2026-10-10 16:30:00'),
(3, 1, 2, 'llamada',   'Llamada de seguimiento: revisan propuesta con gerencia.',   '2026-10-22 11:00:00'),
(4, 2, 2, 'llamada',   'Negociación de descuento por renovación anticipada.',       '2026-10-18 09:20:00'),
(5, 3, 3, 'reunion',   'Cierre de negociación y firma de acta de inicio.',          '2026-10-05 12:00:00'),
(6, 4, 4, 'correo',    'Envío de brochure de seguridad y cumplimiento.',            '2026-10-09 08:40:00');

INSERT INTO tareas (id_tarea, id_usuario, id_cliente, id_oportunidad, titulo, descripcion, fecha_limite, estado) VALUES
(1, 2, 1, 1, 'Enviar contrato de migración',        'Preparar contrato con alcance y cronograma.',        '2026-11-15 17:00:00', 'en_proceso'),
(2, 2, 2, 2, 'Confirmar número de licencias',       'Validar inventario de buzones del cliente.',         '2026-11-20 12:00:00', 'pendiente'),
(3, 3, 4, 3, 'Programar kickoff de implementación', 'Coordinar reunión de inicio con el cliente.',        '2026-10-08 10:00:00', 'completada'),
(4, 4, 6, 4, 'Agendar demo de cifrado',             'Demostración del módulo de seguridad al cliente.',   '2026-11-25 15:30:00', 'pendiente'),
(5, 1, NULL, NULL, 'Revisar reporte mensual de ventas', 'Consolidar indicadores de octubre.',             '2026-11-05 09:00:00', 'completada'),
(6, 5, NULL, NULL, 'Preparar campaña de fin de año', 'Diseñar piezas y segmentar base de clientes.',       '2026-11-30 18:00:00', 'en_proceso');

-- ------------------------------------------------------------
-- 5. Campañas de marketing
-- ------------------------------------------------------------
INSERT INTO campanas_marketing (id_campana, nombre, descripcion, fecha_inicio, fecha_fin, presupuesto, estado) VALUES
(1, 'Lanzamiento Zimbra 2026',        'Campaña de posicionamiento de la nueva suite.',        '2026-10-01', '2026-12-31', 5000000.00, 'activa'),
(2, 'Webinar colaboración empresarial','Webinar sobre productividad y correo corporativo.',   '2026-08-01', '2026-09-15', 2500000.00, 'finalizada'),
(3, 'Campaña fin de año',             'Ofertas de renovación para clientes existentes.',      '2026-11-15', '2026-12-31', 3500000.00, 'planificada');

INSERT INTO campanas_clientes (id_campana, id_cliente, fecha_asignacion) VALUES
(1, 1, '2026-10-01 08:00:00'),
(1, 3, '2026-10-01 08:00:00'),
(1, 7, '2026-10-02 09:30:00'),
(2, 2, '2026-08-01 10:00:00'),
(2, 5, '2026-08-01 10:00:00'),
(3, 4, '2026-11-15 08:00:00'),
(3, 6, '2026-11-15 08:00:00'),
(3, 8, '2026-11-15 08:00:00');

INSERT INTO campanas_interacciones (id_interaccion, id_campana, id_cliente, tipo, resultado, fecha) VALUES
(1, 1, 1, 'correo',    'Abrió el correo y solicitó información.',       '2026-10-03 09:12:00'),
(2, 1, 3, 'correo',    'Sin respuesta después de dos envíos.',          '2026-10-10 14:25:00'),
(3, 1, 7, 'formulario','Registró sus datos para una demo.',             '2026-10-05 18:40:00'),
(4, 2, 2, 'webinar',   'Asistió al webinar completo.',                  '2026-08-20 17:00:00'),
(5, 2, 5, 'webinar',   'Asistió parcialmente y pidió grabación.',       '2026-08-20 17:00:00'),
(6, 3, 4, 'llamada',   'Interesado en la oferta de renovación.',        '2026-11-20 10:15:00');

-- ------------------------------------------------------------
-- 6. Productos y categorías
-- ------------------------------------------------------------
INSERT INTO categorias_productos (id_categoria, nombre, descripcion) VALUES
(1, 'Correo corporativo', 'Planes de correo y colaboración'),
(2, 'Seguridad',          'Módulos de protección y cifrado'),
(3, 'Colaboración',       'Herramientas de trabajo en equipo'),
(4, 'Soporte',            'Servicios de soporte y acompañamiento');

INSERT INTO productos (id_producto, nombre, descripcion, precio, stock, estado) VALUES
(1, 'Zimbra Starter',             'Plan básico de correo para pequeños equipos.',        45000.00, 100, 1),
(2, 'Zimbra Professional',        'Plan profesional con calendario y colaboración.',     85000.00,  80, 1),
(3, 'Zimbra Enterprise',          'Plan empresarial de alta disponibilidad.',           145000.00,  50, 1),
(4, 'Módulo Antispam Avanzado',   'Filtro antispam y antiphishing gestionado.',          25000.00, 200, 1),
(5, 'Zimbra Suite Plus',          'Suite de colaboración y movilidad.',                 120000.00,  40, 1),
(6, 'Soporte Premium 24/7',       'Soporte prioritario con SLA de 4 horas.',            300000.00, 999, 1);

INSERT INTO productos_detalles (id_detalle, id_producto, atributo, valor) VALUES
(1, 1, 'Usuarios incluidos', '10'),
(2, 1, 'Almacenamiento',     '10 GB por usuario'),
(3, 2, 'Usuarios incluidos', '50'),
(4, 2, 'Almacenamiento',     '50 GB por usuario'),
(5, 3, 'Usuarios incluidos', 'Ilimitados'),
(6, 3, 'Alta disponibilidad','Sí'),
(7, 4, 'Vigencia',           '12 meses'),
(8, 5, 'Movilidad',          'Android e iOS'),
(9, 6, 'Tiempo de respuesta','4 horas');

INSERT INTO productos_categorias (id_producto, id_categoria) VALUES
(1, 1), (2, 1), (2, 3), (3, 1), (3, 3), (4, 2), (5, 3), (6, 4);

-- ------------------------------------------------------------
-- 7. Propuestas comerciales
-- ------------------------------------------------------------
INSERT INTO propuestas (id_propuesta, id_oportunidad, fecha, valor_total, estado, observaciones) VALUES
(1, 1, '2026-10-10', 21550000.00, 'enviada',   'Incluye migración y capacitación para 250 usuarios.'),
(2, 2, '2026-10-18', 13200000.00, 'enviada',   'Descuento del 8% por renovación anticipada.'),
(3, 3, '2026-09-25', 58300000.00, 'aceptada',  'Aprobada por el comité directivo del cliente.'),
(4, 5, '2026-09-10',  8700000.00, 'rechazada', 'El cliente decidió no renovar con nosotros.');

INSERT INTO propuestas_detalles (id_detalle, id_propuesta, id_producto, cantidad, precio_unitario, subtotal) VALUES
(1, 1, 2, 250,  85000.00, 21250000.00),
(2, 1, 6,   1, 300000.00,   300000.00),
(3, 2, 2, 120,  85000.00, 10200000.00),
(4, 2, 4, 120,  25000.00,  3000000.00),
(5, 3, 3, 400, 145000.00, 58000000.00),
(6, 3, 6,   1, 300000.00,   300000.00),
(7, 4, 5,  60, 120000.00,  7200000.00),
(8, 4, 4,  60,  25000.00,  1500000.00);

-- ------------------------------------------------------------
-- 8. Ventas y pagos
-- ------------------------------------------------------------
INSERT INTO ventas (id_venta, id_cliente, id_vendedor, id_propuesta, fecha, total, estado) VALUES
(1, 4, 2, 3, '2026-10-05 12:30:00', 58300000.00, 'pagada'),
(2, 1, 1, 1, '2026-10-12 09:45:00', 21550000.00, 'pendiente'),
(3, 2, 1, NULL, '2026-10-22 15:10:00', 4400000.00, 'pagada'),
(4, 6, 3, NULL, '2026-10-28 11:05:00', 1400000.00, 'pendiente');

INSERT INTO ventas_productos (id_detalle, id_venta, id_producto, cantidad, precio_unitario, subtotal) VALUES
(1, 1, 3, 400, 145000.00, 58000000.00),
(2, 1, 6,   1, 300000.00,   300000.00),
(3, 2, 2, 250,  85000.00, 21250000.00),
(4, 2, 6,   1, 300000.00,   300000.00),
(5, 3, 2,  40,  85000.00,  3400000.00),
(6, 3, 4,  40,  25000.00,  1000000.00),
(7, 4, 1,  20,  45000.00,   900000.00),
(8, 4, 4,  20,  25000.00,   500000.00);

INSERT INTO pagos (id_pago, id_venta, metodo_pago, valor, fecha, estado) VALUES
(1, 1, 'transferencia', 29150000.00, '2026-10-06 10:00:00', 'aprobado'),
(2, 1, 'transferencia', 29150000.00, '2026-10-20 10:00:00', 'aprobado'),
(3, 2, 'tarjeta',        5000000.00, '2026-10-13 09:30:00', 'pendiente'),
(4, 3, 'pse',            4400000.00, '2026-10-22 16:00:00', 'aprobado'),
(5, 4, 'efectivo',       1400000.00, '2026-10-29 11:00:00', 'pendiente');

-- ------------------------------------------------------------
-- 9. Actividad e historial
-- ------------------------------------------------------------
INSERT INTO actividad_web (id_actividad, id_usuario, id_cliente, accion, descripcion, fecha) VALUES
(1, 2, 1, 'visita',        'Visitó la página de planes empresariales.',        '2026-09-10 09:05:00'),
(2, 2, 1, 'descarga',      'Descargó el comparativo de planes.',               '2026-09-10 09:12:00'),
(3, 3, 3, 'formulario',    'Solicitó una prueba gratuita de 60 días.',         '2026-09-12 14:20:00'),
(4, 3, 3, 'visita',        'Visitó la sección de preguntas frecuentes.',       '2026-09-12 14:35:00'),
(5, 4, 6, 'descarga',      'Descargó el documento de seguridad y cifrado.',    '2026-10-02 11:50:00'),
(6, 5, 7, 'visita',        'Visitó la página de la campaña de fin de año.',    '2026-10-05 18:30:00'),
(7, 2, 2, 'correo',        'Hizo clic en el correo de renovación.',            '2026-10-18 09:10:00'),
(8, 4, 8, 'visita',        'Visitó la página de soporte premium.',             '2026-10-03 13:45:00');

INSERT INTO notificaciones (id_notificacion, id_usuario, titulo, mensaje, estado, fecha) VALUES
(1, 2, 'Nueva tarea asignada',        'Tienes una tarea pendiente: enviar contrato de migración.',   'pendiente', '2026-10-25 08:00:00'),
(2, 2, 'Oportunidad en negociación',  'La oportunidad de Tecnología Andina S.A.S. avanzó a negociación.', 'leida', '2026-10-22 11:30:00'),
(3, 3, 'Propuesta aceptada',          'La propuesta de Inversiones Pacífico S.A. fue aceptada.',    'leida', '2026-10-05 12:10:00'),
(4, 4, 'Recordatorio de demo',        'Demo de cifrado con Clínica San Rafael el 25 de noviembre.', 'pendiente', '2026-11-01 09:00:00'),
(5, 5, 'Campaña próxima a iniciar',   'La campaña de fin de año inicia el 15 de noviembre.',        'pendiente', '2026-11-02 10:00:00'),
(6, 1, 'Reporte mensual disponible',  'El reporte de ventas de octubre está listo para revisión.',  'leida', '2026-11-01 07:30:00');

-- ------------------------------------------------------------
-- 11. Eventos, calendario y recordatorios
-- ------------------------------------------------------------
INSERT INTO eventos (id_evento, id_usuario, titulo, descripcion, fecha_inicio, fecha_fin, ubicacion, tipo, estado) VALUES
(1, 2, 'Reunión de negociación - Tecnología Andina', 'Revisión final de propuesta y cronograma.',        '2026-11-15 10:00:00', '2026-11-15 11:30:00', 'Oficina del cliente', 'reunion', 'programado'),
(2, 2, 'Llamada de seguimiento - El Sol',            'Confirmar número de licencias para renovación.',   '2026-11-20 09:00:00', '2026-11-20 09:30:00', 'Virtual',             'llamada', 'programado'),
(3, 3, 'Kickoff de implementación - Inversiones Pacífico', 'Inicio formal del proyecto.',                '2026-10-08 14:00:00', '2026-10-08 16:00:00', 'Sala de juntas',      'reunion', 'realizado'),
(4, 4, 'Demo de cifrado - Clínica San Rafael',       'Demostración del módulo de seguridad.',            '2026-11-25 15:30:00', '2026-11-25 16:30:00', 'Virtual',             'cita',    'programado'),
(5, 1, 'Comité comercial mensual',                   'Revisión de indicadores y metas.',                 '2026-11-05 09:00:00', '2026-11-05 10:30:00', 'Sala principal',      'reunion', 'realizado');

-- ------------------------------------------------------------
-- 13. Correos y plantillas
-- ------------------------------------------------------------
INSERT INTO correos (id_correo, id_usuario, asunto, contenido, fecha_envio, estado) VALUES
(1, 2, 'Propuesta comercial - Migración Zimbra',      'Estimado Juan Pablo, adjuntamos la propuesta para la migración de 250 buzones...', '2026-10-10 17:00:00', 'enviado'),
(2, 2, 'Seguimiento propuesta Tecnología Andina',      'Hola Andrea, queremos conocer sus comentarios sobre la propuesta enviada...',      '2026-10-22 11:10:00', 'enviado'),
(3, 5, 'Lanzamiento Zimbra 2026',                      'Conoce las novedades de nuestra suite de colaboración...',                          '2026-10-03 08:00:00', 'enviado'),
(4, 3, 'Confirmación de kickoff',                      'Confirmamos la reunión de inicio del proyecto para el 8 de octubre...',             '2026-10-06 10:00:00', 'enviado'),
(5, 1, 'Borrador de comunicado interno',               'Equipo, comparto el borrador del comunicado de resultados del trimestre...',        NULL,                  'borrador');

INSERT INTO correos_destinatarios (id_destinatario, id_correo, correo, tipo) VALUES
(1, 1, 'juan.perez@tecandina.com',     'para'),
(2, 1, 'andrea.salazar@tecandina.com', 'cc'),
(3, 2, 'andrea.salazar@tecandina.com', 'para'),
(4, 3, 'contacto@tecandina.com',       'para'),
(5, 3, 'maria.lopez@correo.com',       'para'),
(6, 4, 'valentina.cruz@invpacifico.com','para'),
(7, 5, 'equipo@zimbra-demo.com',       'para');

-- ------------------------------------------------------------
-- 14. Reportes y auditoría
-- ------------------------------------------------------------
INSERT INTO reportes_generados (id_reporte, id_usuario, nombre, tipo, archivo, fecha_generacion) VALUES
(1, 1, 'Reporte de ventas octubre 2026',        'ventas',        '/reportes/ventas-2026-10.pdf',        '2026-11-01 07:30:00'),
(2, 1, 'Reporte de oportunidades abiertas',     'oportunidades', '/reportes/oportunidades-2026-11.xlsx', '2026-11-02 08:15:00'),
(3, 2, 'Desempeño del equipo comercial',        'vendedores',    '/reportes/equipo-2026-10.pdf',         '2026-11-02 09:00:00'),
(4, 5, 'Resultados campaña webinar',            'campanas',      '/reportes/campana-webinar.xlsx',       '2026-09-20 16:00:00');

INSERT INTO auditoria (id_auditoria, id_usuario, tabla_afectada, operacion, registro_id, descripcion, fecha) VALUES
(1, 1, 'usuarios',      'INSERT', 5, 'Se creó el usuario Sofía Torres.',                    '2026-09-01 08:00:00'),
(2, 2, 'clientes',      'INSERT', 1, 'Se registró el cliente Tecnología Andina S.A.S.',     '2026-09-05 09:15:00'),
(3, 2, 'oportunidades', 'INSERT', 1, 'Se creó la oportunidad de migración de correo.',      '2026-09-10 09:00:00'),
(4, 3, 'propuestas',    'UPDATE', 3, 'La propuesta cambió de enviada a aceptada.',          '2026-09-25 17:30:00'),
(5, 2, 'ventas',        'INSERT', 1, 'Se registró la venta a Inversiones Pacífico S.A.',    '2026-10-05 12:30:00'),
(6, 4, 'tareas',        'UPDATE', 3, 'La tarea de kickoff se marcó como completada.',       '2026-10-08 16:05:00'),
(7, 5, 'campanas_marketing', 'INSERT', 3, 'Se creó la campaña de fin de año.',              '2026-11-01 10:00:00'),
(8, 1, 'usuarios',      'UPDATE', 5, 'Se desactivó el usuario Sofía Torres.',               '2026-11-03 09:30:00');

-- ============================================================
-- PARTE 3. VERIFICACIÓN
-- Sin vistas: las tablas puente (roles_permisos, usuarios_roles)
-- se consultan directamente con JOIN.
-- ============================================================

SELECT 'usuarios' AS tabla, COUNT(*) AS registros FROM usuarios
UNION ALL SELECT 'roles', COUNT(*) FROM roles
UNION ALL SELECT 'permisos', COUNT(*) FROM permisos
UNION ALL SELECT 'clientes', COUNT(*) FROM clientes
UNION ALL SELECT 'contactos', COUNT(*) FROM contactos
UNION ALL SELECT 'vendedores', COUNT(*) FROM vendedores
UNION ALL SELECT 'oportunidades', COUNT(*) FROM oportunidades
UNION ALL SELECT 'seguimientos', COUNT(*) FROM seguimientos
UNION ALL SELECT 'tareas', COUNT(*) FROM tareas
UNION ALL SELECT 'campanas_marketing', COUNT(*) FROM campanas_marketing
UNION ALL SELECT 'productos', COUNT(*) FROM productos
UNION ALL SELECT 'propuestas', COUNT(*) FROM propuestas
UNION ALL SELECT 'ventas', COUNT(*) FROM ventas
UNION ALL SELECT 'pagos', COUNT(*) FROM pagos
UNION ALL SELECT 'eventos', COUNT(*) FROM eventos
UNION ALL SELECT 'correos', COUNT(*) FROM correos
UNION ALL SELECT 'reportes_generados', COUNT(*) FROM reportes_generados
UNION ALL SELECT 'auditoria', COUNT(*) FROM auditoria;

-- Roles con su descripción y cuántos usuarios y permisos alcanza cada uno
SELECT r.id_rol,
       r.nombre      AS rol,
       r.descripcion,
       COUNT(DISTINCT ur.id_usuario) AS usuarios,
       COUNT(DISTINCT rp.id_permiso) AS permisos
FROM roles r
LEFT JOIN usuarios_roles ur ON ur.id_rol = r.id_rol
LEFT JOIN roles_permisos rp ON rp.id_rol = r.id_rol
GROUP BY r.id_rol, r.nombre, r.descripcion
ORDER BY r.id_rol;

-- Detalle de permisos por rol
SELECT r.nombre      AS rol,
       p.nombre      AS permiso,
       p.descripcion AS que_puede_hacer
FROM roles_permisos rp
JOIN roles r    ON r.id_rol = rp.id_rol
JOIN permisos p ON p.id_permiso = rp.id_permiso
ORDER BY rp.id_rol, rp.id_permiso;

-- Usuarios y su rol
SELECT u.id_usuario, u.nombre AS usuario, u.correo, u.estado, r.nombre AS rol
FROM usuarios u
JOIN usuarios_roles ur ON ur.id_usuario = u.id_usuario
JOIN roles r           ON r.id_rol = ur.id_rol
ORDER BY u.id_usuario;

-- Matriz: qué puede hacer cada rol de un vistazo
SELECT p.nombre      AS permiso,
       p.descripcion AS que_puede_hacer,
       MAX(CASE WHEN r.nombre = 'admin'     THEN 'SI' ELSE '-' END) AS admin,
       MAX(CASE WHEN r.nombre = 'user'      THEN 'SI' ELSE '-' END) AS user,
       MAX(CASE WHEN r.nombre = 'user_demo' THEN 'SI' ELSE '-' END) AS user_demo
FROM permisos p
LEFT JOIN roles_permisos rp ON rp.id_permiso = p.id_permiso
LEFT JOIN roles r           ON r.id_rol = rp.id_rol
GROUP BY p.id_permiso, p.nombre, p.descripcion
ORDER BY p.id_permiso;






-- transacciones 




-- 2. ROLLBACK: se cancela todo lo hecho dentro de la transacción
START TRANSACTION;

-- Bajamos el stock del producto 1
UPDATE productos SET stock = stock - 50 WHERE id_producto = 1;

-- Vemos el cambio (todavía no es definitivo)
SELECT id_producto, nombre, stock FROM productos WHERE id_producto = 1;

-- Nos arrepentimos: se devuelve todo
ROLLBACK;

SELECT id_producto, nombre, stock FROM productos WHERE id_producto = 1;  -- vuelve al valor original


-- 3. SAVEPOINT: deshacer solo una parte
START TRANSACTION;

-- Venta nueva para el cliente 3
INSERT INTO ventas (id_cliente, id_vendedor, total, estado)
VALUES (3, 2, 0, 'pendiente');
SET @id_venta = LAST_INSERT_ID();

-- Primer producto
INSERT INTO ventas_productos (id_venta, id_producto, cantidad, precio_unitario, subtotal)
VALUES (@id_venta, 1, 2, 45000, 90000);

SAVEPOINT despues_producto1;

-- Segundo producto
INSERT INTO ventas_productos (id_venta, id_producto, cantidad, precio_unitario, subtotal)
VALUES (@id_venta, 4, 2, 25000, 50000);

-- El cliente no quiere el segundo producto: solo se deshace ese
ROLLBACK TO despues_producto1;

-- Total final con lo que quedó
UPDATE ventas SET total = 90000 WHERE id_venta = @id_venta;

COMMIT;

SELECT * FROM ventas_productos WHERE id_venta = @id_venta;   -- solo el producto 1


-- 4. PROCEDIMIENTO con transacción (como procesar_pago de TravelNow)
DELIMITER //
CREATE PROCEDURE procesar_pago_venta(
    IN p_id_venta INT,
    IN p_metodo VARCHAR(50)
)
BEGIN
    DECLARE v_total DECIMAL(12,2);

    -- Si algo falla, se deshace todo y se muestra el error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Consultamos el total de la venta
    SELECT total INTO v_total
    FROM ventas
    WHERE id_venta = p_id_venta AND estado = 'pendiente';

    -- Si no existe o ya está pagada, cancelamos
    IF v_total IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La venta no existe o no esta pendiente';
    END IF;

    -- Registramos el pago
    INSERT INTO pagos (id_venta, metodo_pago, valor, estado)
    VALUES (p_id_venta, p_metodo, v_total, 'aprobado');

    -- Actualizamos el estado de la venta
    UPDATE ventas SET estado = 'pagada' WHERE id_venta = p_id_venta;

    COMMIT;
END //
DELIMITER ;

-- Ejecutamos el proceso (venta 2: Tecnología Andina)
CALL procesar_pago_venta(2, 'transferencia');

SELECT * FROM ventas WHERE id_venta = 2;

-- Esta falla a propósito (la venta 2 ya está pagada) y hace ROLLBACK
-- CALL procesar_pago_venta(2, 'transferencia');


-- ============================================================
-- PARTE 5. TRIGGERS, EVENTO Y CLASIFICACIÓN DE CLIENTES
-- 5.1  Puntaje de cada acción (función)
-- 5.2  Triggers que registran la actividad del cliente en actividad_web
-- 5.3  Procedimiento y EVENTO que clasifican a los clientes potenciales
-- 5.4  Auditoría automática de las tablas comerciales
--
-- Van al final a propósito: así no se disparan durante los datos de prueba.
-- ============================================================

DELIMITER //

-- ------------------------------------------------------------
-- 5.1 Puntaje de cada acción
-- ------------------------------------------------------------

-- Puntos que aporta cada acción. Si cambian los pesos, se cambian solo aquí.
CREATE FUNCTION fn_puntos_accion(p_accion VARCHAR(100))
RETURNS INT
DETERMINISTIC
RETURN CASE LOWER(TRIM(COALESCE(p_accion, '')))
    WHEN 'visita'             THEN 1
    WHEN 'correo'             THEN 2
    WHEN 'descarga'           THEN 3
    WHEN 'llamada'            THEN 3
    WHEN 'reunion'            THEN 5
    WHEN 'seguimiento'        THEN 3
    WHEN 'webinar'            THEN 5
    WHEN 'propuesta'          THEN 8
    WHEN 'pago'               THEN 8
    WHEN 'formulario'         THEN 10
    WHEN 'demo'               THEN 10
    WHEN 'prueba'             THEN 10
    WHEN 'propuesta_aceptada' THEN 10
    WHEN 'compra'             THEN 20
    ELSE 1
END //

-- ------------------------------------------------------------
-- 5.2 Actividad del cliente
-- Cada trigger traduce un hecho del CRM a una fila de actividad_web.
-- Solo se registra en INSERT (o en un cambio de estado concreto), así
-- que un mismo hecho nunca genera dos filas.
-- ------------------------------------------------------------

-- Respuesta del cliente a una campaña (formulario, correo, webinar...)
CREATE TRIGGER trg_campanas_interacciones_actividad
AFTER INSERT ON campanas_interacciones
FOR EACH ROW
INSERT INTO actividad_web (id_cliente, accion, descripcion)
VALUES (
    NEW.id_cliente,
    COALESCE(NEW.tipo, 'campana'),
    CONCAT('Campaña #', NEW.id_campana, ': ',
           COALESCE(NEW.resultado, 'interacción registrada'))
) //

-- Seguimiento comercial sobre una oportunidad del cliente
CREATE TRIGGER trg_seguimientos_actividad
AFTER INSERT ON seguimientos
FOR EACH ROW
INSERT INTO actividad_web (id_cliente, accion, descripcion)
SELECT o.id_cliente,
       COALESCE(NEW.tipo, 'seguimiento'),
       CONCAT('Seguimiento #', NEW.id_seguimiento, ': ',
              COALESCE(NEW.descripcion, 'contacto con el cliente'))
FROM oportunidades o
WHERE o.id_oportunidad = NEW.id_oportunidad //

-- Propuesta que nace ya enviada o aceptada (si es borrador no cuenta)
CREATE TRIGGER trg_propuestas_actividad
AFTER INSERT ON propuestas
FOR EACH ROW
INSERT INTO actividad_web (id_cliente, accion, descripcion)
SELECT o.id_cliente,
       'propuesta',
       CONCAT('Propuesta #', NEW.id_propuesta, ' registrada (', NEW.estado, ')')
FROM oportunidades o
WHERE o.id_oportunidad = NEW.id_oportunidad
  AND NEW.estado <> 'borrador' //

-- Propuesta que pasa a enviada o aceptada. Solo se registra el cambio
-- de estado, no cada actualización de la fila.
CREATE TRIGGER trg_propuestas_estado_actividad
AFTER UPDATE ON propuestas
FOR EACH ROW
INSERT INTO actividad_web (id_cliente, accion, descripcion)
SELECT o.id_cliente,
       IF(NEW.estado = 'aceptada', 'propuesta_aceptada', 'propuesta'),
       CONCAT('Propuesta #', NEW.id_propuesta, ' -> ', NEW.estado)
FROM oportunidades o
WHERE o.id_oportunidad = NEW.id_oportunidad
  AND NEW.estado IN ('enviada', 'aceptada')
  AND NEW.estado <> OLD.estado //

-- Venta registrada a nombre del cliente
CREATE TRIGGER trg_ventas_actividad
AFTER INSERT ON ventas
FOR EACH ROW
INSERT INTO actividad_web (id_cliente, accion, descripcion)
VALUES (NEW.id_cliente, 'compra',
        CONCAT('Venta #', NEW.id_venta, ' por ', FORMAT(NEW.total, 2))) //

-- Pago registrado sobre una venta del cliente
CREATE TRIGGER trg_pagos_actividad
AFTER INSERT ON pagos
FOR EACH ROW
INSERT INTO actividad_web (id_cliente, accion, descripcion)
SELECT v.id_cliente,
       'pago',
       CONCAT('Pago #', NEW.id_pago, ' de la venta #', NEW.id_venta,
              ' (', NEW.estado, ')')
FROM ventas v
WHERE v.id_venta = NEW.id_venta //

-- ------------------------------------------------------------
-- 5.3 Clasificación de clientes potenciales
-- Un cliente es potencial si en los últimos 30 días cumple las tres
-- condiciones: uso frecuente (días distintos), varias interacciones y
-- actividad acumulada suficiente. Quien ya es Cliente activo o VIP
-- (categorías 2 y 3) no se vuelve a marcar como prospecto.
-- ------------------------------------------------------------
CREATE PROCEDURE actualizar_clientes_potenciales()
BEGIN
    DECLARE v_interacciones_minimas INT DEFAULT 5;
    DECLARE v_dias_activos_minimos  INT DEFAULT 3;
    DECLARE v_puntaje_minimo        INT DEFAULT 15;

    -- La clasificación se recalcula completa: primero se retira la marca
    -- anterior y luego se vuelve a asignar según el comportamiento real.
    DELETE FROM clientes_categorias WHERE id_categoria = 1;

    INSERT IGNORE INTO clientes_categorias (id_cliente, id_categoria)
    SELECT a.id_cliente, 1
    FROM actividad_web a
    WHERE a.id_cliente IS NOT NULL
      AND a.fecha >= NOW() - INTERVAL 30 DAY
      AND NOT EXISTS (
          SELECT 1 FROM clientes_categorias cc
          WHERE cc.id_cliente = a.id_cliente
            AND cc.id_categoria IN (2, 3)
      )
    GROUP BY a.id_cliente
    HAVING COUNT(*)                        >= v_interacciones_minimas
       AND COUNT(DISTINCT DATE(a.fecha))   >= v_dias_activos_minimos
       AND SUM(fn_puntos_accion(a.accion)) >= v_puntaje_minimo;

    -- Aviso único al vendedor asignado de cada nuevo cliente potencial.
    -- El mensaje es la clave: si ya existe, no se vuelve a notificar.
    INSERT INTO notificaciones (id_usuario, titulo, mensaje)
    SELECT v.id_usuario,
           'Cliente potencial detectado',
           CONCAT('Cliente potencial: ', c.nombre)
    FROM clientes_categorias cc
    JOIN clientes c ON c.id_cliente = cc.id_cliente
    JOIN asignaciones_clientes ac ON ac.id_asignacion = (
        SELECT ac2.id_asignacion
        FROM asignaciones_clientes ac2
        WHERE ac2.id_cliente = cc.id_cliente
        ORDER BY ac2.fecha_asignacion DESC, ac2.id_asignacion DESC
        LIMIT 1
    )
    JOIN vendedores v ON v.id_vendedor = ac.id_vendedor
    WHERE cc.id_categoria = 1
      AND NOT EXISTS (
          SELECT 1 FROM notificaciones n
          WHERE n.id_usuario = v.id_usuario
            AND n.mensaje = CONCAT('Cliente potencial: ', c.nombre)
      );
END //

-- El paso del tiempo lo controla el EVENT SCHEDULER, no un trigger.
CREATE EVENT ev_clasificar_clientes_potenciales
ON SCHEDULE EVERY 6 HOUR
STARTS CURRENT_TIMESTAMP + INTERVAL 6 HOUR
ON COMPLETION PRESERVE
DO
BEGIN
    CALL actualizar_clientes_potenciales();
END //

-- ------------------------------------------------------------
-- 5.4 Auditoría automática
-- El backend puede hacer  SET @usuario_actual = <id>;  antes de operar.
-- Si no lo hace (o el id no existe) se guarda NULL, sin romper nada.
-- ------------------------------------------------------------
CREATE PROCEDURE registrar_auditoria(
    IN p_tabla VARCHAR(100),
    IN p_operacion VARCHAR(10),
    IN p_registro_id INT,
    IN p_descripcion TEXT
)
BEGIN
    INSERT INTO auditoria (id_usuario, tabla_afectada, operacion, registro_id, descripcion)
    VALUES (
        (SELECT u.id_usuario FROM usuarios u WHERE u.id_usuario = @usuario_actual),
        p_tabla, p_operacion, p_registro_id, p_descripcion
    );
END //

-- clientes
CREATE TRIGGER trg_clientes_auditar_insert AFTER INSERT ON clientes FOR EACH ROW
CALL registrar_auditoria('clientes', 'INSERT', NEW.id_cliente, CONCAT('Cliente creado: ', NEW.nombre)) //
CREATE TRIGGER trg_clientes_auditar_update AFTER UPDATE ON clientes FOR EACH ROW
CALL registrar_auditoria('clientes', 'UPDATE', NEW.id_cliente, CONCAT('Cliente actualizado: ', NEW.nombre)) //
CREATE TRIGGER trg_clientes_auditar_delete AFTER DELETE ON clientes FOR EACH ROW
CALL registrar_auditoria('clientes', 'DELETE', OLD.id_cliente, CONCAT('Cliente eliminado: ', OLD.nombre)) //

-- oportunidades
CREATE TRIGGER trg_oportunidades_auditar_insert AFTER INSERT ON oportunidades FOR EACH ROW
CALL registrar_auditoria('oportunidades', 'INSERT', NEW.id_oportunidad, CONCAT('Oportunidad creada: ', NEW.titulo)) //
CREATE TRIGGER trg_oportunidades_auditar_update AFTER UPDATE ON oportunidades FOR EACH ROW
CALL registrar_auditoria('oportunidades', 'UPDATE', NEW.id_oportunidad, CONCAT('Oportunidad actualizada: ', NEW.titulo, ' (', NEW.estado, ')')) //
CREATE TRIGGER trg_oportunidades_auditar_delete AFTER DELETE ON oportunidades FOR EACH ROW
CALL registrar_auditoria('oportunidades', 'DELETE', OLD.id_oportunidad, CONCAT('Oportunidad eliminada: ', OLD.titulo)) //

-- propuestas
CREATE TRIGGER trg_propuestas_auditar_insert AFTER INSERT ON propuestas FOR EACH ROW
CALL registrar_auditoria('propuestas', 'INSERT', NEW.id_propuesta, CONCAT('Propuesta creada por ', NEW.valor_total)) //
CREATE TRIGGER trg_propuestas_auditar_update AFTER UPDATE ON propuestas FOR EACH ROW
CALL registrar_auditoria('propuestas', 'UPDATE', NEW.id_propuesta, CONCAT('Propuesta actualizada: ', NEW.estado)) //
CREATE TRIGGER trg_propuestas_auditar_delete AFTER DELETE ON propuestas FOR EACH ROW
CALL registrar_auditoria('propuestas', 'DELETE', OLD.id_propuesta, CONCAT('Propuesta eliminada: ', OLD.valor_total)) //

-- ventas
CREATE TRIGGER trg_ventas_auditar_insert AFTER INSERT ON ventas FOR EACH ROW
CALL registrar_auditoria('ventas', 'INSERT', NEW.id_venta, CONCAT('Venta registrada por ', NEW.total)) //
CREATE TRIGGER trg_ventas_auditar_update AFTER UPDATE ON ventas FOR EACH ROW
CALL registrar_auditoria('ventas', 'UPDATE', NEW.id_venta, CONCAT('Venta actualizada: ', NEW.estado, ' / total ', NEW.total)) //
CREATE TRIGGER trg_ventas_auditar_delete AFTER DELETE ON ventas FOR EACH ROW
CALL registrar_auditoria('ventas', 'DELETE', OLD.id_venta, CONCAT('Venta eliminada por ', OLD.total)) //

-- pagos
CREATE TRIGGER trg_pagos_auditar_insert AFTER INSERT ON pagos FOR EACH ROW
CALL registrar_auditoria('pagos', 'INSERT', NEW.id_pago, CONCAT('Pago registrado: ', NEW.valor, ' (', NEW.estado, ')')) //
CREATE TRIGGER trg_pagos_auditar_update AFTER UPDATE ON pagos FOR EACH ROW
CALL registrar_auditoria('pagos', 'UPDATE', NEW.id_pago, CONCAT('Pago actualizado: ', NEW.estado)) //
CREATE TRIGGER trg_pagos_auditar_delete AFTER DELETE ON pagos FOR EACH ROW
CALL registrar_auditoria('pagos', 'DELETE', OLD.id_pago, CONCAT('Pago eliminado: ', OLD.valor)) //

DELIMITER ;

-- El programador de eventos viene apagado por defecto en MySQL.
-- Requiere privilegio de administrador.
SET GLOBAL event_scheduler = ON;

-- ============================================================
-- PARTE 6. PRUEBAS DE LOS TRIGGERS Y DEL EVENTO
-- Todo ocurre dentro de una transacción y termina con ROLLBACK,
-- así que el CRM queda sin datos de prueba.
-- ============================================================

SET @actividades_antes = (SELECT COUNT(*) FROM actividad_web);

START TRANSACTION;

-- 1. Interacción de campaña -> actividad_web
INSERT INTO campanas_interacciones (id_campana, id_cliente, tipo, resultado)
VALUES (3, 5, 'formulario', 'Prueba: solicitó una demo.');

SELECT '1. Campaña' AS prueba, id_cliente, accion, descripcion
FROM actividad_web
WHERE id_cliente = 5
ORDER BY id_actividad DESC
LIMIT 1;

-- 2. Seguimiento -> actividad_web (el cliente sale de la oportunidad)
INSERT INTO seguimientos (id_oportunidad, id_usuario, tipo, descripcion)
VALUES (4, 2, 'llamada', 'Prueba: llamada de seguimiento.');

SELECT '2. Seguimiento' AS prueba, id_cliente, accion, descripcion
FROM actividad_web
WHERE id_cliente = 6
ORDER BY id_actividad DESC
LIMIT 1;

-- 3. Propuesta en borrador: no debe generar actividad
INSERT INTO propuestas (id_oportunidad, fecha, valor_total, estado)
VALUES (4, CURDATE(), 1000000, 'borrador');
SET @id_propuesta_prueba = LAST_INSERT_ID();

SELECT '3. Borrador sin actividad' AS prueba, COUNT(*) AS filas
FROM actividad_web
WHERE id_cliente = 6 AND accion = 'propuesta';
-- Esperado: 0

-- 4. Propuesta enviada: se registra una sola vez
UPDATE propuestas SET estado = 'enviada'
WHERE id_propuesta = @id_propuesta_prueba;

UPDATE propuestas SET observaciones = 'Prueba: sin cambio de estado'
WHERE id_propuesta = @id_propuesta_prueba;

SELECT '4. Sin duplicados' AS prueba, COUNT(*) AS filas
FROM actividad_web
WHERE id_cliente = 6 AND accion = 'propuesta';
-- Esperado: 1

-- 5. Venta -> actividad 'compra'
INSERT INTO ventas (id_cliente, id_vendedor, total, estado)
VALUES (5, 3, 450000, 'pendiente');
SET @id_venta_prueba = LAST_INSERT_ID();

-- 6. Pago -> actividad 'pago'
INSERT INTO pagos (id_venta, metodo_pago, valor, estado)
VALUES (@id_venta_prueba, 'efectivo', 450000, 'aprobado');

SELECT '5-6. Venta y pago' AS prueba, id_cliente, accion, descripcion
FROM actividad_web
WHERE id_cliente = 5 AND accion IN ('compra', 'pago')
ORDER BY id_actividad;

-- 7. Clasificación: se completan 5 interacciones en 3 días distintos
INSERT INTO actividad_web (id_cliente, accion, descripcion, fecha) VALUES
(5, 'visita',   'Prueba: visita de hace 2 días',  NOW() - INTERVAL 2 DAY),
(5, 'descarga', 'Prueba: descarga de hace 1 día', NOW() - INTERVAL 1 DAY);

CALL actualizar_clientes_potenciales();

SELECT c.nombre AS cliente,
       COUNT(a.id_actividad)          AS interacciones,
       COUNT(DISTINCT DATE(a.fecha))  AS dias_activos,
       COALESCE(SUM(IF(a.id_actividad IS NULL, 0,
                       fn_puntos_accion(a.accion))), 0) AS puntaje,
       IF(EXISTS (SELECT 1 FROM clientes_categorias cc
                  WHERE cc.id_cliente = c.id_cliente
                    AND cc.id_categoria = 1),
          'Potencial', 'No potencial') AS clasificacion
FROM clientes c
LEFT JOIN actividad_web a
       ON a.id_cliente = c.id_cliente
      AND a.fecha >= NOW() - INTERVAL 30 DAY
GROUP BY c.id_cliente, c.nombre
ORDER BY puntaje DESC;

-- 8. Aviso al vendedor (una sola vez por cliente)
SELECT '8. Notificación' AS prueba, id_usuario, titulo, mensaje
FROM notificaciones
WHERE titulo = 'Cliente potencial detectado';

-- 9. El evento queda programado
SELECT '9. Evento' AS prueba, EVENT_NAME, STATUS, INTERVAL_VALUE, INTERVAL_FIELD
FROM information_schema.EVENTS
WHERE EVENT_SCHEMA = DATABASE();

-- 10. Se deshacen las pruebas
ROLLBACK;

SELECT '10. Rollback' AS prueba,
       (SELECT COUNT(*) FROM actividad_web) - @actividades_antes AS actividades_nuevas;
-- Esperado: 0
