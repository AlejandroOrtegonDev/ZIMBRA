
CREATE DATABASE zimbra; 
-- drop database zimbra; 
USE zimbra;

-- 1. USUARIOS, ROLES Y PERMISOS

CREATE TABLE usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    estado TINYINT DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ;

CREATE TABLE roles (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT
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
    id_usuario INT NOT NULL,
    id_cliente INT,
    accion VARCHAR(100),
    descripcion TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
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
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

-- 15. CONFIGURACION DE USUARIOS

CREATE TABLE configuracion_usuario (
    id_configuracion INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL UNIQUE,
    zona_horaria VARCHAR(100) DEFAULT 'America/Bogota',
    idioma VARCHAR(10) DEFAULT 'es',
    notificaciones TINYINT DEFAULT 1,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
) ;