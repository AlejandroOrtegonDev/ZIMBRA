-- ============================================================
-- Sistema de Gestión Comercial Zimbra
-- Script SQL final del Taller Grupal (Sesiones 1 a 4)
--
-- Ejecutar completo (MySQL 8.0.16 o superior):
--   mysql -u root -p --default-character-set=utf8mb4 < zimbra.sql
-- o abrirlo en MySQL Workbench y ejecutarlo todo (rayo).
--
-- ADVERTENCIA: este script borra la base 'zimbra' si ya existe
-- y recrea los usuarios MySQL 'zimbra_app', 'zimbra_analista' y
-- 'zimbra_auditor' (PARTE 8).
--
-- Contraseñas de la aplicación (tabla usuarios):
--   ana.rodriguez@zimbra-demo.com  -> admin123
--   resto de usuarios              -> 123456
--
-- Contenido:
--   PARTE 1. Esquema, llaves y restricciones ............ Sesión 1
--   PARTE 2. Datos de prueba (30+ registros por tabla) .. Sesión 2
--   PARTE 3. Funciones UDF .............................. Sesión 3
--   PARTE 4. Triggers, procedimientos y evento .......... Sesión 3
--   PARTE 5. Transacciones ACID y simulación de errores . Sesión 2
--   PARTE 6. Índices y EXPLAIN .......................... Sesión 4
--   PARTE 7. Vistas para reportes ....................... Sesión 4
--   PARTE 8. Roles y permisos de MySQL .................. Sesión 4
--   PARTE 9. Pruebas automáticas y verificación final
--
-- La simulación de concurrencia y bloqueos (Sesión 4) necesita dos
-- conexiones simultáneas: ver database/concurrencia.sql y
-- backend/scripts/simular_concurrencia.mjs
-- ============================================================

-- Workbench activa "safe updates" por defecto; el script lo desactiva
-- solo para esta sesión.
SET SQL_SAFE_UPDATES = 0;

DROP DATABASE IF EXISTS zimbra;
CREATE DATABASE zimbra
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE zimbra;

-- ============================================================
-- PARTE 1. ESQUEMA (Sesión 1)
-- Reglas usadas en las llaves foráneas:
--   ON DELETE CASCADE  -> filas que no tienen sentido sin su padre
--                         (detalles, tablas puente, contactos).
--   ON DELETE SET NULL -> historial que debe sobrevivir (auditoría).
--   Sin acción (RESTRICT) -> datos comerciales: no se puede borrar
--                         un cliente con ventas, una venta con pagos...
-- ============================================================

-- 1. USUARIOS, ROLES Y PERMISOS

CREATE TABLE usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    estado TINYINT NOT NULL DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_usuarios_estado CHECK (estado IN (0, 1)),
    CONSTRAINT chk_usuarios_correo CHECK (correo LIKE '%_@_%._%')
);

-- Solo se permiten 3 niveles de acceso: user_demo, user y admin
CREATE TABLE roles (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    nombre ENUM('user_demo', 'user', 'admin') NOT NULL,
    descripcion TEXT,
    UNIQUE KEY uk_roles_nombre (nombre)
);

CREATE TABLE permisos (
    id_permiso INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    UNIQUE KEY uk_permisos_nombre (nombre)
);

CREATE TABLE usuarios_roles (
    id_usuario INT NOT NULL,
    id_rol INT NOT NULL,
    PRIMARY KEY (id_usuario, id_rol),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    FOREIGN KEY (id_rol) REFERENCES roles(id_rol) ON DELETE CASCADE
);

CREATE TABLE roles_permisos (
    id_rol INT NOT NULL,
    id_permiso INT NOT NULL,
    PRIMARY KEY (id_rol, id_permiso),
    FOREIGN KEY (id_rol) REFERENCES roles(id_rol) ON DELETE CASCADE,
    FOREIGN KEY (id_permiso) REFERENCES permisos(id_permiso) ON DELETE CASCADE
);

-- 2. CLIENTES Y CONTACTOS

CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    tipo_cliente ENUM('persona', 'empresa') NOT NULL DEFAULT 'persona',
    nombre VARCHAR(150) NOT NULL,
    apellido VARCHAR(150),
    documento VARCHAR(50),
    correo VARCHAR(150),
    telefono VARCHAR(30),
    direccion VARCHAR(255),
    estado TINYINT NOT NULL DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_documento (documento),
    CONSTRAINT chk_clientes_estado CHECK (estado IN (0, 1)),
    CONSTRAINT chk_clientes_correo CHECK (correo IS NULL OR correo LIKE '%_@_%._%')
);

CREATE TABLE contactos (
    id_contacto INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    apellido VARCHAR(150),
    correo VARCHAR(150),
    telefono VARCHAR(30),
    cargo VARCHAR(100),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE
);

-- Categoría 1 'Prospecto' la asigna el registro de prospectos.
-- Categoría 5 'Potencial' la calcula el procedimiento
-- actualizar_clientes_potenciales(); son marcas independientes.
CREATE TABLE categorias_clientes (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    UNIQUE KEY uk_categorias_clientes_nombre (nombre)
);

CREATE TABLE clientes_categorias (
    id_cliente INT NOT NULL,
    id_categoria INT NOT NULL,
    PRIMARY KEY (id_cliente, id_categoria),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    FOREIGN KEY (id_categoria) REFERENCES categorias_clientes(id_categoria) ON DELETE CASCADE
);

-- 3. VENDEDORES

CREATE TABLE vendedores (
    id_vendedor INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    codigo VARCHAR(50) NOT NULL,
    especialidad VARCHAR(150),
    estado TINYINT NOT NULL DEFAULT 1,
    UNIQUE KEY uk_vendedores_codigo (codigo),
    UNIQUE KEY uk_vendedores_usuario (id_usuario),
    CONSTRAINT chk_vendedores_estado CHECK (estado IN (0, 1)),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

CREATE TABLE asignaciones_clientes (
    id_asignacion INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_vendedor INT NOT NULL,
    fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_vendedor) REFERENCES vendedores(id_vendedor)
);

-- 4. OPORTUNIDADES Y SEGUIMIENTOS

CREATE TABLE etapas_ventas (
    id_etapa INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    orden INT NOT NULL DEFAULT 1,
    UNIQUE KEY uk_etapas_nombre (nombre),
    CONSTRAINT chk_etapas_orden CHECK (orden > 0)
);

CREATE TABLE oportunidades (
    id_oportunidad INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_vendedor INT,
    id_etapa INT,
    titulo VARCHAR(200) NOT NULL,
    descripcion TEXT,
    valor_estimado DECIMAL(12,2) NOT NULL DEFAULT 0,
    estado ENUM('abierta', 'ganada', 'perdida') NOT NULL DEFAULT 'abierta',
    fecha_cierre DATE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_oportunidades_valor CHECK (valor_estimado >= 0),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_vendedor) REFERENCES vendedores(id_vendedor),
    FOREIGN KEY (id_etapa) REFERENCES etapas_ventas(id_etapa)
);

CREATE TABLE oportunidades_detalle (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_oportunidad INT NOT NULL,
    descripcion TEXT NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_oportunidad) REFERENCES oportunidades(id_oportunidad) ON DELETE CASCADE
);

CREATE TABLE seguimientos (
    id_seguimiento INT AUTO_INCREMENT PRIMARY KEY,
    id_oportunidad INT NOT NULL,
    id_usuario INT NOT NULL,
    tipo VARCHAR(50),
    descripcion TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_oportunidad) REFERENCES oportunidades(id_oportunidad),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

CREATE TABLE tareas (
    id_tarea INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    id_cliente INT,
    id_oportunidad INT,
    titulo VARCHAR(200) NOT NULL,
    descripcion TEXT,
    fecha_limite DATETIME,
    estado ENUM('pendiente', 'en_proceso', 'completada', 'cancelada') NOT NULL DEFAULT 'pendiente',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_oportunidad) REFERENCES oportunidades(id_oportunidad)
);

-- 5. CAMPAÑAS DE MARKETING

CREATE TABLE campanas_marketing (
    id_campana INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    fecha_inicio DATE,
    fecha_fin DATE,
    presupuesto DECIMAL(12,2) NOT NULL DEFAULT 0,
    estado ENUM('planificada', 'activa', 'finalizada', 'cancelada') NOT NULL DEFAULT 'planificada',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_campanas_presupuesto CHECK (presupuesto >= 0),
    CONSTRAINT chk_campanas_fechas CHECK (fecha_inicio IS NULL OR fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

CREATE TABLE campanas_clientes (
    id_campana INT NOT NULL,
    id_cliente INT NOT NULL,
    fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_campana, id_cliente),
    FOREIGN KEY (id_campana) REFERENCES campanas_marketing(id_campana) ON DELETE CASCADE,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE
);

CREATE TABLE campanas_interacciones (
    id_interaccion INT AUTO_INCREMENT PRIMARY KEY,
    id_campana INT NOT NULL,
    id_cliente INT NOT NULL,
    tipo VARCHAR(50),
    resultado TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_campana) REFERENCES campanas_marketing(id_campana),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

-- 6. PRODUCTOS Y CATEGORIAS

CREATE TABLE categorias_productos (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    UNIQUE KEY uk_categorias_productos_nombre (nombre)
);

CREATE TABLE productos (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(12,2) NOT NULL DEFAULT 0,
    stock INT NOT NULL DEFAULT 0,
    estado TINYINT NOT NULL DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_productos_precio CHECK (precio >= 0),
    CONSTRAINT chk_productos_stock CHECK (stock >= 0),
    CONSTRAINT chk_productos_estado CHECK (estado IN (0, 1))
);

CREATE TABLE productos_detalles (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    atributo VARCHAR(100),
    valor TEXT,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
);

CREATE TABLE productos_categorias (
    id_producto INT NOT NULL,
    id_categoria INT NOT NULL,
    PRIMARY KEY (id_producto, id_categoria),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE,
    FOREIGN KEY (id_categoria) REFERENCES categorias_productos(id_categoria) ON DELETE CASCADE
);

-- 7. PROPUESTAS COMERCIALES
-- valor_total lo mantiene el trigger de propuestas_detalles.

CREATE TABLE propuestas (
    id_propuesta INT AUTO_INCREMENT PRIMARY KEY,
    id_oportunidad INT NOT NULL,
    fecha DATE,
    valor_total DECIMAL(12,2) NOT NULL DEFAULT 0,
    estado ENUM('borrador', 'enviada', 'aceptada', 'rechazada') NOT NULL DEFAULT 'borrador',
    observaciones TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_propuestas_valor CHECK (valor_total >= 0),
    FOREIGN KEY (id_oportunidad) REFERENCES oportunidades(id_oportunidad)
);

CREATE TABLE propuestas_detalles (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_propuesta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    CONSTRAINT chk_prop_det_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_prop_det_precio CHECK (precio_unitario >= 0),
    CONSTRAINT chk_prop_det_subtotal CHECK (subtotal = cantidad * precio_unitario),
    FOREIGN KEY (id_propuesta) REFERENCES propuestas(id_propuesta) ON DELETE CASCADE,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

-- 8. VENTAS Y PAGOS
-- Reglas (las aplican los triggers de la PARTE 4):
--   * total = suma de ventas_productos.
--   * estado 'pagada' cuando los pagos aprobados cubren el total.
--   * la suma de pagos aprobados + pendientes nunca supera el total.

CREATE TABLE ventas (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_vendedor INT,
    id_propuesta INT,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(12,2) NOT NULL DEFAULT 0,
    estado ENUM('pendiente', 'pagada', 'cancelada') NOT NULL DEFAULT 'pendiente',
    CONSTRAINT chk_ventas_total CHECK (total >= 0),
    -- Una propuesta solo puede convertirse en una venta
    UNIQUE KEY uk_ventas_propuesta (id_propuesta),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_vendedor) REFERENCES vendedores(id_vendedor),
    FOREIGN KEY (id_propuesta) REFERENCES propuestas(id_propuesta)
);

CREATE TABLE ventas_productos (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    CONSTRAINT chk_venta_prod_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_venta_prod_precio CHECK (precio_unitario >= 0),
    CONSTRAINT chk_venta_prod_subtotal CHECK (subtotal = cantidad * precio_unitario),
    FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE CASCADE,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

CREATE TABLE pagos (
    id_pago INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT NOT NULL,
    metodo_pago VARCHAR(50),
    valor DECIMAL(12,2) NOT NULL,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('pendiente', 'aprobado', 'rechazado') NOT NULL DEFAULT 'pendiente',
    CONSTRAINT chk_pagos_valor CHECK (valor > 0),
    FOREIGN KEY (id_venta) REFERENCES ventas(id_venta)
);

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
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE
);

CREATE TABLE notificaciones (
    id_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    titulo VARCHAR(200),
    mensaje TEXT,
    estado ENUM('pendiente', 'leida') NOT NULL DEFAULT 'pendiente',
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);

-- 10. INFORMACION DE LA COMPAÑIA

CREATE TABLE info_companie (
    id_compania INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    nit VARCHAR(50),
    direccion VARCHAR(255),
    telefono VARCHAR(30),
    correo VARCHAR(150),
    logo VARCHAR(255)
);

-- 11. EVENTOS, CALENDARIO Y RECORDATORIOS
-- id_cliente (opcional) liga la llamada/reunión con el cliente o
-- prospecto; lo usa la pantalla de seguimiento comercial.

CREATE TABLE eventos (
    id_evento INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    id_cliente INT NULL,
    titulo VARCHAR(200) NOT NULL,
    descripcion TEXT,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    ubicacion VARCHAR(255),
    tipo ENUM('reunion', 'llamada', 'cita', 'otro') NOT NULL DEFAULT 'otro',
    estado ENUM('programado', 'realizado', 'cancelado') NOT NULL DEFAULT 'programado',
    CONSTRAINT chk_eventos_fechas CHECK (fecha_fin > fecha_inicio),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE SET NULL
);

-- 12. CONTACTOS Y ETIQUETAS

CREATE TABLE etiquetas (
    id_etiqueta INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    color VARCHAR(20),
    UNIQUE KEY uk_etiquetas_nombre (nombre)
);

CREATE TABLE contactos_etiquetas (
    id_contacto INT NOT NULL,
    id_etiqueta INT NOT NULL,
    PRIMARY KEY (id_contacto, id_etiqueta),
    FOREIGN KEY (id_contacto) REFERENCES contactos(id_contacto) ON DELETE CASCADE,
    FOREIGN KEY (id_etiqueta) REFERENCES etiquetas(id_etiqueta) ON DELETE CASCADE
);

-- 13. CORREOS Y PLANTILLAS

CREATE TABLE correos (
    id_correo INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    asunto VARCHAR(255),
    contenido LONGTEXT,
    fecha_envio DATETIME,
    estado ENUM('borrador', 'enviado', 'recibido') NOT NULL DEFAULT 'borrador',
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

CREATE TABLE correos_destinatarios (
    id_destinatario INT AUTO_INCREMENT PRIMARY KEY,
    id_correo INT NOT NULL,
    correo VARCHAR(150) NOT NULL,
    tipo ENUM('para', 'cc', 'cco') NOT NULL DEFAULT 'para',
    FOREIGN KEY (id_correo) REFERENCES correos(id_correo) ON DELETE CASCADE
);

-- 14. REPORTES Y AUDITORIA

CREATE TABLE reportes_generados (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    nombre VARCHAR(150),
    tipo VARCHAR(100),
    archivo VARCHAR(255),
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

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
);

-- 15. CONFIGURACION DE USUARIOS

CREATE TABLE configuracion_usuario (
    id_configuracion INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL UNIQUE,
    zona_horaria VARCHAR(100) NOT NULL DEFAULT 'America/Bogota',
    idioma VARCHAR(10) NOT NULL DEFAULT 'es',
    notificaciones TINYINT NOT NULL DEFAULT 1,
    CONSTRAINT chk_config_notificaciones CHECK (notificaciones IN (0, 1)),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 10. Información de la compañía
-- ------------------------------------------------------------
-- Tabla de configuración: una sola fila por diseño (la empresa que usa el sistema)
INSERT INTO info_companie (id_compania, nombre, nit, direccion, telefono, correo, logo) VALUES
(1, 'Zimbra Demo S.A.S.', '901555888-1', 'Calle 93 # 15-20, Bogotá D.C.', '+57 601 555 0000', 'contacto@zimbra-demo.com', '/img/logo-zimbra-demo.png');

-- ------------------------------------------------------------
-- 1. Usuarios, roles y permisos
-- ------------------------------------------------------------
INSERT INTO usuarios (id_usuario, nombre, correo, password, estado, fecha_creacion) VALUES
(1, 'Ana María Rodríguez', 'ana.rodriguez@zimbra-demo.com', '$2y$10$lhjAjW4ZIF3N4FrMVYtxzu5/bWIAox9Fu.ZBTZ0E2DIK8BpLwwi.S', 1, '2025-01-16 09:00:00'),
(2, 'Carlos Gómez', 'carlos.gomez@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-01-22 09:00:00'),
(3, 'Laura Martínez', 'laura.martinez@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-01-28 09:00:00'),
(4, 'Diego Herrera', 'diego.herrera@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-02-03 09:00:00'),
(5, 'Sofía Torres', 'sofia.torres@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 0, '2025-02-09 09:00:00'),
(6, 'Santiago Muñoz', 'santiago.munoz@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-02-15 09:00:00'),
(7, 'Carolina Mejía', 'carolina.mejia@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-02-21 09:00:00'),
(8, 'Gabriel Patiño', 'gabriel.patino@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-02-27 09:00:00'),
(9, 'Sara Castro', 'sara.castro@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-03-05 09:00:00'),
(10, 'Julián Quintero', 'julian.quintero@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-03-11 09:00:00'),
(11, 'Liliana Rodríguez', 'liliana.rodriguez@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-03-17 09:00:00'),
(12, 'Juan Camilo Suárez', 'juan.camilo.suarez@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-03-23 09:00:00'),
(13, 'Juliana Arango', 'juliana.arango@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-03-29 09:00:00'),
(14, 'Tomás Moreno', 'tomas.moreno@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-04-04 09:00:00'),
(15, 'Verónica Ruiz', 'veronica.ruiz@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-04-10 09:00:00'),
(16, 'Mauricio Mendoza', 'mauricio.mendoza@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-04-16 09:00:00'),
(17, 'Gloria Rojas', 'gloria.rojas@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-04-22 09:00:00'),
(18, 'Felipe Restrepo', 'felipe.restrepo@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-04-28 09:00:00'),
(19, 'Mariana Salazar', 'mariana.salazar@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-05-04 09:00:00'),
(20, 'David Vargas', 'david.vargas@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-05-10 09:00:00'),
(21, 'Lina María Peña', 'lina.maria.pena@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-05-16 09:00:00'),
(22, 'Fabián López', 'fabian.lopez@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-05-22 09:00:00'),
(23, 'Paula Romero', 'paula.romero@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-05-28 09:00:00'),
(24, 'Sebastián Zapata', 'sebastian.zapata@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-06-03 09:00:00'),
(25, 'Isabella Jiménez', 'isabella.jimenez@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-06-09 09:00:00'),
(26, 'Esteban Cárdenas', 'esteban.cardenas@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-06-15 09:00:00'),
(27, 'Adriana Bermúdez', 'adriana.bermudez@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-06-21 09:00:00'),
(28, 'Germán Díaz', 'german.diaz@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-06-27 09:00:00'),
(29, 'Valeria Gutiérrez', 'valeria.gutierrez@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-07-03 09:00:00'),
(30, 'Mateo García', 'mateo.garcia@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-07-09 09:00:00'),
(31, 'Manuela Ortiz', 'manuela.ortiz@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-07-15 09:00:00'),
(32, 'Miguel Ángel Cortés', 'miguel.angel.cortes@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-07-21 09:00:00'),
(33, 'Paola Hernández', 'paola.hernandez@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-07-27 09:00:00'),
(34, 'Iván Álvarez', 'ivan.alvarez@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-08-02 09:00:00'),
(35, 'Natalia Valencia', 'natalia.valencia@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-08-08 09:00:00'),
(36, 'Alejandro Muñoz', 'alejandro.munoz@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-08-14 09:00:00'),
(37, 'Luisa Fernanda Mejía', 'luisa.fernanda.mejia@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-08-20 09:00:00'),
(38, 'Óscar Patiño', 'oscar.patino@zimbra-demo.com', '$2y$10$lhjAjW4ZIF3N4FrMVYtxzu5/bWIAox9Fu.ZBTZ0E2DIK8BpLwwi.S', 1, '2025-08-26 09:00:00'),
(39, 'Claudia Castro', 'claudia.castro@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-09-01 09:00:00'),
(40, 'Usuario Demo', 'demo@zimbra-demo.com', '$2y$10$1OWXhYXT6d1hxZ1UBe6UQukeMhB7ZWFEpoFScww.RDrmjEblsLrry', 1, '2025-09-07 09:00:00');

-- Catálogo cerrado: el ENUM solo admite 3 niveles de acceso (decisión de diseño)
INSERT INTO roles (id_rol, nombre, descripcion) VALUES
(1, 'admin', 'Acceso total: gestiona usuarios, configuración, auditoría y reportes'),
(2, 'user', 'Operación comercial: clientes, oportunidades, propuestas, ventas, pagos y reportes'),
(3, 'user_demo', 'Solo lectura: consulta información y reportes, no puede modificar nada');

INSERT INTO permisos (id_permiso, nombre, descripcion) VALUES
(1, 'usuarios.gestionar', 'Crear, editar, activar y desactivar usuarios'),
(2, 'clientes.ver', 'Consultar la lista y el detalle de los clientes'),
(3, 'clientes.crear', 'Registrar clientes nuevos'),
(4, 'clientes.editar', 'Modificar los datos de un cliente'),
(5, 'oportunidades.gestionar', 'Crear oportunidades y moverlas de etapa'),
(6, 'campanas.gestionar', 'Crear y administrar campañas de marketing'),
(7, 'ventas.registrar', 'Registrar ventas y sus pagos'),
(8, 'reportes.ver', 'Consultar reportes comerciales'),
(9, 'auditoria.ver', 'Revisar el historial de auditoría'),
(10, 'configuracion.editar', 'Cambiar la configuración del sistema'),
(11, 'clientes.desactivar', 'Desactivar clientes sin borrar su historial'),
(12, 'prospectos.ver', 'Consultar prospectos y su seguimiento'),
(13, 'prospectos.crear', 'Registrar prospectos y asignar vendedor'),
(14, 'oportunidades.ver', 'Consultar oportunidades comerciales'),
(15, 'propuestas.ver', 'Consultar propuestas comerciales'),
(16, 'propuestas.crear', 'Crear propuestas con su detalle de productos'),
(17, 'propuestas.aprobar', 'Cambiar el estado de una propuesta (enviar, aceptar, rechazar)'),
(18, 'ventas.ver', 'Consultar ventas y su saldo'),
(19, 'pagos.registrar', 'Registrar y aprobar pagos'),
(20, 'pagos.ver', 'Consultar pagos'),
(21, 'vendedores.ver', 'Consultar vendedores y su desempeño'),
(22, 'vendedores.gestionar', 'Crear vendedores y reasignar clientes'),
(23, 'campanas.ver', 'Consultar campañas de marketing'),
(24, 'productos.ver', 'Consultar el catálogo de productos'),
(25, 'productos.gestionar', 'Crear productos y actualizar precios'),
(26, 'seguimientos.registrar', 'Registrar tareas, llamadas y reuniones'),
(27, 'eventos.gestionar', 'Administrar el calendario comercial'),
(28, 'tareas.gestionar', 'Crear y cerrar tareas'),
(29, 'correos.enviar', 'Enviar correos a clientes'),
(30, 'reportes.exportar', 'Generar y descargar reportes');

INSERT INTO usuarios_roles (id_usuario, id_rol) VALUES
(1, 1),
(2, 2),
(3, 2),
(4, 2),
(5, 3),
(6, 2),
(7, 2),
(8, 2),
(9, 2),
(10, 2),
(11, 2),
(12, 2),
(13, 2),
(14, 2),
(15, 2),
(16, 2),
(17, 2),
(18, 2),
(19, 2),
(20, 2),
(21, 2),
(22, 2),
(23, 2),
(24, 2),
(25, 2),
(26, 2),
(27, 2),
(28, 2),
(29, 2),
(30, 2),
(31, 2),
(32, 2),
(33, 2),
(34, 2),
(35, 2),
(36, 2),
(37, 2),
(38, 1),
(39, 3),
(40, 3);

INSERT INTO roles_permisos (id_rol, id_permiso) VALUES
(1, 1),
(1, 2),
(1, 3),
(1, 4),
(1, 5),
(1, 6),
(1, 7),
(1, 8),
(1, 9),
(1, 10),
(1, 11),
(1, 12),
(1, 13),
(1, 14),
(1, 15),
(1, 16),
(1, 17),
(1, 18),
(1, 19),
(1, 20),
(1, 21),
(1, 22),
(1, 23),
(1, 24),
(1, 25),
(1, 26),
(1, 27),
(1, 28),
(1, 29),
(1, 30),
(2, 2),
(2, 3),
(2, 4),
(2, 5),
(2, 6),
(2, 7),
(2, 8),
(2, 11),
(2, 12),
(2, 13),
(2, 14),
(2, 15),
(2, 16),
(2, 17),
(2, 18),
(2, 19),
(2, 20),
(2, 21),
(2, 23),
(2, 24),
(2, 26),
(2, 27),
(2, 28),
(2, 29),
(2, 30),
(3, 2),
(3, 8),
(3, 12),
(3, 14),
(3, 15),
(3, 18),
(3, 20),
(3, 21),
(3, 23),
(3, 24);

INSERT INTO configuracion_usuario (id_configuracion, id_usuario, zona_horaria, idioma, notificaciones) VALUES
(1, 1, 'America/Bogota', 'es', 1),
(2, 2, 'America/Bogota', 'es', 1),
(3, 3, 'America/Bogota', 'es', 1),
(4, 4, 'America/Bogota', 'es', 0),
(5, 5, 'America/Bogota', 'es', 1),
(6, 6, 'America/Bogota', 'es', 1),
(7, 7, 'America/Bogota', 'es', 1),
(8, 8, 'America/Bogota', 'es', 0),
(9, 9, 'America/Bogota', 'en', 1),
(10, 10, 'America/Bogota', 'es', 1),
(11, 11, 'America/Bogota', 'es', 1),
(12, 12, 'America/Bogota', 'es', 0),
(13, 13, 'America/Bogota', 'es', 1),
(14, 14, 'America/Bogota', 'es', 1),
(15, 15, 'America/Bogota', 'es', 1),
(16, 16, 'America/Bogota', 'es', 0),
(17, 17, 'America/Bogota', 'es', 1),
(18, 18, 'America/Bogota', 'en', 1),
(19, 19, 'America/Bogota', 'es', 1),
(20, 20, 'America/Bogota', 'es', 0),
(21, 21, 'America/Bogota', 'es', 1),
(22, 22, 'America/Bogota', 'es', 1),
(23, 23, 'America/Bogota', 'es', 1),
(24, 24, 'America/Bogota', 'es', 0),
(25, 25, 'America/Bogota', 'es', 1),
(26, 26, 'America/Bogota', 'es', 1),
(27, 27, 'America/Bogota', 'en', 1),
(28, 28, 'America/Bogota', 'es', 0),
(29, 29, 'America/Bogota', 'es', 1),
(30, 30, 'America/Bogota', 'es', 1),
(31, 31, 'America/Bogota', 'es', 1),
(32, 32, 'America/Bogota', 'es', 0),
(33, 33, 'America/Bogota', 'es', 1),
(34, 34, 'America/Bogota', 'es', 1),
(35, 35, 'America/Bogota', 'es', 1),
(36, 36, 'America/Bogota', 'en', 0),
(37, 37, 'America/Bogota', 'es', 1),
(38, 38, 'America/Bogota', 'es', 1),
(39, 39, 'America/Bogota', 'es', 1),
(40, 40, 'America/Bogota', 'es', 0);

-- ------------------------------------------------------------
-- 3. Vendedores
-- ------------------------------------------------------------
INSERT INTO vendedores (id_vendedor, id_usuario, codigo, especialidad, estado) VALUES
(1, 2, 'VEN-001', 'Correo corporativo y cuentas empresariales', 1),
(2, 3, 'VEN-002', 'Soluciones de colaboración y seguridad', 1),
(3, 4, 'VEN-003', 'Sector salud y logística', 1),
(4, 6, 'VEN-004', 'Sector público', 1),
(5, 7, 'VEN-005', 'Pymes y comercio', 1),
(6, 8, 'VEN-006', 'Sector financiero', 1),
(7, 9, 'VEN-007', 'Migraciones y despliegues', 1),
(8, 10, 'VEN-008', 'Grandes cuentas', 1),
(9, 11, 'VEN-009', 'Canal de distribuidores', 1),
(10, 12, 'VEN-010', 'Correo corporativo y cuentas empresariales', 1),
(11, 13, 'VEN-011', 'Soluciones de colaboración y seguridad', 1),
(12, 14, 'VEN-012', 'Sector salud y logística', 1),
(13, 15, 'VEN-013', 'Sector educativo', 1),
(14, 16, 'VEN-014', 'Sector público', 1),
(15, 17, 'VEN-015', 'Pymes y comercio', 1),
(16, 18, 'VEN-016', 'Sector financiero', 1),
(17, 19, 'VEN-017', 'Migraciones y despliegues', 1),
(18, 20, 'VEN-018', 'Grandes cuentas', 1),
(19, 21, 'VEN-019', 'Canal de distribuidores', 1),
(20, 22, 'VEN-020', 'Correo corporativo y cuentas empresariales', 1),
(21, 23, 'VEN-021', 'Soluciones de colaboración y seguridad', 1),
(22, 24, 'VEN-022', 'Sector salud y logística', 1),
(23, 25, 'VEN-023', 'Sector educativo', 1),
(24, 26, 'VEN-024', 'Sector público', 1),
(25, 27, 'VEN-025', 'Pymes y comercio', 1),
(26, 28, 'VEN-026', 'Sector financiero', 1),
(27, 29, 'VEN-027', 'Migraciones y despliegues', 1),
(28, 30, 'VEN-028', 'Grandes cuentas', 1),
(29, 31, 'VEN-029', 'Canal de distribuidores', 1),
(30, 32, 'VEN-030', 'Correo corporativo y cuentas empresariales', 0);

-- ------------------------------------------------------------
-- 2. Clientes, contactos, categorías y etiquetas
-- ------------------------------------------------------------
-- Catálogo de segmentos: 5 valores fijos por diseño
INSERT INTO categorias_clientes (id_categoria, nombre, descripcion) VALUES
(1, 'Prospecto', 'Cliente potencial aún no convertido'),
(2, 'Cliente activo', 'Cliente con compras o contrato vigente'),
(3, 'Cliente VIP', 'Cliente estratégico de alto valor'),
(4, 'Inactivo', 'Cliente sin actividad reciente'),
(5, 'Potencial', 'Prospecto con alto nivel de interacción reciente (lo calcula actualizar_clientes_potenciales)');

INSERT INTO clientes (id_cliente, tipo_cliente, nombre, apellido, documento, correo, telefono, direccion, estado, fecha_creacion) VALUES
(1, 'empresa', 'Tecnología Andina S.A.S.', NULL, '900123456-7', 'contacto@tecandina.com', '+57 601 555 0101', 'Carrera 11 # 93-45, Bogotá D.C.', 1, '2026-09-05 09:15:00'),
(2, 'empresa', 'Comercializadora El Sol Ltda.', NULL, '900987654-1', 'gerencia@elsol.com.co', '+57 604 555 0202', 'Calle 10 # 40-12, Medellín', 1, '2026-09-08 10:30:00'),
(3, 'persona', 'María Fernanda', 'López', '1020304050', 'maria.lopez@correo.com', '+57 310 555 0303', 'Calle 45 # 12-30, Bogotá D.C.', 1, '2026-09-12 14:00:00'),
(4, 'empresa', 'Inversiones Pacífico S.A.', NULL, '890456123-9', 'info@invpacifico.com', '+57 602 555 0404', 'Avenida 6N # 23-10, Cali', 1, '2026-08-20 08:45:00'),
(5, 'persona', 'Jorge Enrique', 'Ramírez', '79456123', 'jorge.ramirez@correo.com', '+57 315 555 0505', 'Carrera 7 # 72-15, Bogotá D.C.', 1, '2026-09-20 11:20:00'),
(6, 'empresa', 'Clínica San Rafael', NULL, '860012345-4', 'administracion@clinicasr.com', '+57 601 555 0606', 'Calle 100 # 20-55, Bogotá D.C.', 1, '2026-09-25 16:10:00'),
(7, 'persona', 'Camila Andrea', 'Vargas', '1015987654', 'camila.vargas@correo.com', '+57 300 555 0707', 'Carrera 53 # 79-20, Barranquilla', 1, '2026-10-01 09:00:00'),
(8, 'empresa', 'Logística del Norte S.A.S.', NULL, '901234567-8', 'operaciones@logisnorte.com', '+57 607 555 0808', 'Calle 15 # 30-40, Bucaramanga', 1, '2026-08-25 13:40:00'),
(9, 'empresa', 'Constructora Horizonte S.A.S.', NULL, '851556922-9', 'contacto@constructorahorizo.com.co', '+57 607 622 7514', 'Carrera 42 # 92-15, Cúcuta', 1, '2025-09-12 16:15:00'),
(10, 'empresa', 'Agroindustrias del Valle S.A.', NULL, '884296220-0', 'contacto@agroindustriasdelv.com.co', '+57 606 278 7430', 'Carrera 138 # 95-10, Pereira', 1, '2025-12-02 16:00:00'),
(11, 'empresa', 'Universidad Tecnológica del Caribe', NULL, '825107567-9', 'contacto@universidadtecnolo.com.co', '+57 601 250 5683', 'Carrera 146 # 59-63, Bogotá D.C.', 1, '2025-10-24 15:00:00'),
(12, 'persona', 'Germán', 'García', '1074921498', 'german.garcia12@correo.com', '+57 317 134 5091', 'Avenida 129 # 1-46, Pereira', 1, '2025-11-14 10:30:00'),
(13, 'empresa', 'Transportes Rápidos del Sur Ltda.', NULL, '893284044-2', 'contacto@transportesrapidos.com.co', '+57 604 758 9809', 'Transversal 132 # 87-7, Medellín', 1, '2025-09-19 14:15:00'),
(14, 'empresa', 'Hotel Mirador Andino', NULL, '839886798-5', 'contacto@hotelmiradorandino.com.co', '+57 608 686 8596', 'Calle 12 # 84-4, Villavicencio', 1, '2025-10-05 15:45:00'),
(15, 'empresa', 'Laboratorios Biogénesis S.A.S.', NULL, '803919847-6', 'contacto@laboratoriosbiogen.com.co', '+57 608 677 9530', 'Calle 5 # 41-52, Ibagué', 1, '2025-11-22 09:00:00'),
(16, 'persona', 'Sebastián', 'Quintero', '1072977253', 'sebastian.quintero16@correo.com', '+57 300 692 7289', 'Avenida 94 # 56-40, Bogotá D.C.', 1, '2026-02-23 09:30:00'),
(17, 'empresa', 'Distribuidora La Montaña S.A.', NULL, '805218287-3', 'contacto@distribuidoralamon.com.co', '+57 605 393 1537', 'Carrera 98 # 38-10, Barranquilla', 1, '2025-09-25 10:45:00'),
(18, 'empresa', 'Colegio Nuevo Horizonte', NULL, '814637010-1', 'contacto@colegionuevohorizo.com.co', '+57 605 271 7811', 'Diagonal 13 # 79-25, Cartagena', 1, '2026-01-16 12:15:00'),
(19, 'empresa', 'Fundación Manos Unidas', NULL, '826005553-2', 'contacto@fundacionmanosunid.com.co', '+57 602 427 2393', 'Diagonal 93 # 7-1, Cali', 1, '2025-10-08 08:45:00'),
(20, 'persona', 'David', 'Vargas', '1025301695', 'david.vargas20@correo.com', '+57 320 347 4954', 'Calle 76 # 48-26, Neiva', 1, '2025-11-09 11:45:00'),
(21, 'empresa', 'Seguros Confianza Plus S.A.', NULL, '898222671-6', 'contacto@segurosconfianzapl.com.co', '+57 608 267 8743', 'Avenida 23 # 82-96, Neiva', 1, '2026-01-02 11:30:00'),
(22, 'empresa', 'Textiles Antioquia S.A.S.', NULL, '892938379-6', 'contacto@textilesantioquia.com.co', '+57 605 631 9678', 'Calle 71 # 45-25, Barranquilla', 1, '2025-12-03 14:45:00'),
(23, 'empresa', 'Alcaldía Municipal de Chía', NULL, '900967559-5', 'contacto@alcaldiamunicipald.com.co', '+57 601 336 9035', 'Diagonal 49 # 48-55, Bogotá D.C.', 1, '2026-02-03 09:15:00'),
(24, 'persona', 'Mauricio', 'García', '1032068527', 'mauricio.garcia24@correo.com', '+57 312 259 9955', 'Avenida 42 # 6-47, Ibagué', 1, '2025-09-20 14:30:00'),
(25, 'empresa', 'Ferretería El Constructor', NULL, '809065712-8', 'contacto@ferreteriaelconstr.com.co', '+57 607 494 2673', 'Avenida 92 # 98-20, Bucaramanga', 1, '2026-01-11 10:30:00'),
(26, 'empresa', 'Energía Verde Colombia S.A.S.', NULL, '816756127-8', 'contacto@energiaverdecolomb.com.co', '+57 602 625 5303', 'Avenida 45 # 97-37, Pasto', 1, '2025-11-05 08:45:00'),
(27, 'empresa', 'Cooperativa Cafetera del Huila', NULL, '823951828-7', 'contacto@cooperativacafeter.com.co', '+57 605 643 1044', 'Calle 22 # 93-5, Barranquilla', 1, '2025-11-22 15:00:00'),
(28, 'persona', 'Juan Camilo', 'Quintero', '1074935697', 'juan.camilo.quintero28@correo.com', '+57 329 362 6541', 'Diagonal 113 # 90-53, Medellín', 1, '2026-02-02 13:45:00'),
(29, 'empresa', 'Clínica Los Andes', NULL, '856128312-9', 'contacto@clinicalosandes.com.co', '+57 606 462 3282', 'Transversal 66 # 42-19, Manizales', 1, '2026-02-01 16:45:00'),
(30, 'empresa', 'Software Factory Bogotá S.A.S.', NULL, '867066044-7', 'contacto@softwarefactorybog.com.co', '+57 605 587 1317', 'Carrera 127 # 46-36, Cartagena', 1, '2025-11-03 08:30:00'),
(31, 'empresa', 'Inmobiliaria Altos del Prado', NULL, '826664603-4', 'contacto@inmobiliariaaltosd.com.co', '+57 606 711 3919', 'Avenida 111 # 60-25, Armenia', 1, '2025-10-15 12:00:00'),
(32, 'persona', 'Gabriel', 'Vargas', '1070072235', 'gabriel.vargas32@correo.com', '+57 321 430 3512', 'Calle 8 # 88-85, Villavicencio', 1, '2026-01-18 11:45:00'),
(33, 'empresa', 'Restaurantes Sabor Criollo S.A.S.', NULL, '827103189-0', 'contacto@restaurantessaborc.com.co', '+57 606 507 9286', 'Transversal 119 # 68-10, Pereira', 1, '2025-09-11 12:15:00'),
(34, 'empresa', 'Notaría Quinta de Medellín', NULL, '898484037-8', 'contacto@notariaquintademed.com.co', '+57 602 691 6230', 'Transversal 98 # 1-64, Pasto', 1, '2026-08-14 08:15:00'),
(35, 'empresa', 'Editorial Páginas Abiertas', NULL, '815729401-3', 'contacto@editorialpaginasab.com.co', '+57 606 723 1174', 'Transversal 5 # 12-5, Manizales', 1, '2026-05-22 09:15:00'),
(36, 'persona', 'Hernán', 'García', '1099024096', 'hernan.garcia36@correo.com', '+57 320 603 4323', 'Carrera 56 # 78-42, Armenia', 1, '2026-05-16 14:15:00'),
(37, 'empresa', 'Minería Responsable S.A.', NULL, '886735319-3', 'contacto@mineriaresponsable.com.co', '+57 605 208 1071', 'Calle 21 # 90-64, Barranquilla', 1, '2026-09-23 08:15:00'),
(38, 'empresa', 'Centro Médico Santa Lucía', NULL, '901773847-4', 'contacto@centromedicosantal.com.co', '+57 604 634 3928', 'Avenida 104 # 80-45, Medellín', 1, '2026-04-19 14:15:00'),
(39, 'empresa', 'Aerolínea Regional Express', NULL, '880064368-1', 'contacto@aerolinearegionale.com.co', '+57 605 542 8120', 'Diagonal 137 # 30-34, Santa Marta', 1, '2026-03-23 08:45:00'),
(40, 'persona', 'Andrés', 'Quintero', '1010861716', 'andres.quintero40@correo.com', '+57 303 904 8102', 'Transversal 91 # 30-69, Cartagena', 1, '2026-10-10 08:00:00'),
(41, 'empresa', 'Banco Cooperativo Solidario', NULL, '826972931-8', 'contacto@bancocooperativoso.com.co', '+57 606 707 5839', 'Diagonal 145 # 40-28, Manizales', 1, '2026-04-12 16:00:00'),
(42, 'empresa', 'Grupo Logístico Atlántico', NULL, '825364840-0', 'contacto@grupologisticoatla.com.co', '+57 601 593 5190', 'Calle 124 # 86-17, Bogotá D.C.', 1, '2026-06-25 17:00:00'),
(43, 'empresa', 'Farmacias Bienestar S.A.S.', NULL, '816849892-5', 'contacto@farmaciasbienestar.com.co', '+57 608 478 4779', 'Diagonal 28 # 86-60, Villavicencio', 1, '2026-07-05 17:00:00'),
(44, 'persona', 'Alejandro', 'Vargas', '1040064308', 'alejandro.vargas44@correo.com', '+57 321 640 6563', 'Avenida 91 # 95-15, Bucaramanga', 1, '2026-08-31 13:30:00'),
(45, 'empresa', 'Instituto de Idiomas Global', NULL, '871982135-1', 'contacto@institutodeidiomas.com.co', '+57 605 411 9571', 'Transversal 97 # 87-78, Santa Marta', 1, '2026-09-18 14:45:00'),
(46, 'empresa', 'Consultores Asociados JR', NULL, '871160518-5', 'contacto@consultoresasociad.com.co', '+57 605 269 2852', 'Avenida 12 # 17-35, Cartagena', 1, '2026-08-17 13:30:00'),
(47, 'empresa', 'Pinturas Arcoíris S.A.', NULL, '881041943-7', 'contacto@pinturasarcoiris.com.co', '+57 608 756 8399', 'Diagonal 119 # 75-12, Neiva', 1, '2026-08-06 17:00:00'),
(48, 'persona', 'Miguel Ángel', 'García', '1045545518', 'miguel.angel.garcia48@correo.com', '+57 322 717 9782', 'Diagonal 92 # 32-72, Ibagué', 1, '2026-04-23 14:45:00'),
(49, 'empresa', 'Agencia de Viajes Destinos', NULL, '848335004-7', 'contacto@agenciadeviajesdes.com.co', '+57 606 403 9506', 'Transversal 58 # 36-25, Armenia', 1, '2026-06-15 17:00:00'),
(50, 'empresa', 'Lácteos La Pradera S.A.', NULL, '852484740-9', 'contacto@lacteoslapradera.com.co', '+57 608 636 9389', 'Diagonal 133 # 22-16, Ibagué', 1, '2026-04-28 09:15:00'),
(51, 'empresa', 'Estudio Jurídico Mendoza & Asociados', NULL, '852566535-7', 'contacto@estudiojuridicomen.com.co', '+57 601 778 6933', 'Carrera 25 # 15-67, Bogotá D.C.', 1, '2026-04-18 12:00:00'),
(52, 'persona', 'Germán', 'Quintero', '1008024852', 'german.quintero52@correo.com', '+57 329 235 4134', 'Calle 80 # 22-70, Bogotá D.C.', 1, '2026-07-20 09:00:00'),
(53, 'empresa', 'Cámara de Comercio Regional', NULL, '812898786-4', 'contacto@camaradecomerciore.com.co', '+57 606 643 9891', 'Diagonal 130 # 91-32, Manizales', 1, '2026-07-09 08:15:00'),
(54, 'empresa', 'Tienda Virtual Compra Fácil', NULL, '824488491-1', 'contacto@tiendavirtualcompr.com.co', '+57 602 468 9738', 'Carrera 142 # 99-99, Pasto', 1, '2026-08-09 11:00:00'),
(55, 'empresa', 'Clínica Veterinaria Huellitas', NULL, '890059909-4', 'contacto@clinicaveterinaria.com.co', '+57 602 581 9561', 'Carrera 6 # 30-4, Cali', 1, '2026-06-10 12:00:00'),
(56, 'persona', 'Sebastián', 'Vargas', '1082284264', 'sebastian.vargas56@correo.com', '+57 303 504 5436', 'Diagonal 39 # 38-11, Santa Marta', 0, '2026-04-13 10:00:00'),
(57, 'empresa', 'Productora Audiovisual Enfoque', NULL, '827005750-3', 'contacto@productoraaudiovis.com.co', '+57 607 456 4605', 'Calle 60 # 5-46, Bucaramanga', 0, '2026-09-27 14:00:00'),
(58, 'empresa', 'Gimnasio Vida Activa', NULL, '819714936-9', 'contacto@gimnasiovidaactiva.com.co', '+57 601 239 9428', 'Avenida 90 # 32-91, Bogotá D.C.', 0, '2026-05-14 12:15:00'),
(59, 'empresa', 'Panadería Industrial Trigal', NULL, '853110531-1', 'contacto@panaderiaindustria.com.co', '+57 607 433 8015', 'Carrera 99 # 53-70, Cúcuta', 0, '2026-07-03 16:30:00'),
(60, 'persona', 'David', 'García', '1066413876', 'david.garcia60@correo.com', '+57 306 373 5514', 'Diagonal 114 # 29-2, Cali', 0, '2026-03-03 10:15:00');

INSERT INTO contactos (id_contacto, id_cliente, nombre, apellido, correo, telefono, cargo) VALUES
(1, 1, 'Juan Pablo', 'Pérez', 'juan.perez@tecandina.com', '+57 601 555 0111', 'Gerente de TI'),
(2, 1, 'Andrea', 'Salazar', 'andrea.salazar@tecandina.com', '+57 601 555 0112', 'Jefa de Compras'),
(3, 2, 'Ricardo', 'Molina', 'ricardo.molina@elsol.com.co', '+57 604 555 0211', 'Gerente General'),
(4, 3, 'María Fernanda', 'López', 'maria.lopez@correo.com', '+57 310 555 0303', 'Independiente'),
(5, 4, 'Valentina', 'Cruz', 'valentina.cruz@invpacifico.com', '+57 602 555 0411', 'Directora Administrativa'),
(6, 5, 'Jorge Enrique', 'Ramírez', 'jorge.ramirez@correo.com', '+57 315 555 0505', 'Consultor'),
(7, 6, 'Felipe', 'Ospina', 'felipe.ospina@clinicasr.com', '+57 601 555 0611', 'Director Médico'),
(8, 8, 'Sandra Milena', 'Ríos', 'sandra.rios@logisnorte.com', '+57 607 555 0811', 'Jefa de Operaciones'),
(9, 7, 'Camila Andrea', 'Vargas', 'camila.vargas@correo.com', '+57 300 555 0707', 'Independiente'),
(10, 9, 'Verónica', 'Rodríguez', 'veronica.rodriguez@constructorahorizo.com.co', '+57 306 925 1504', 'Jefe de Infraestructura'),
(11, 10, 'Valeria', 'Mejía', 'valeria.mejia@agroindustriasdelv.com.co', '+57 324 378 3156', 'Director Administrativo'),
(12, 10, 'Claudia', 'Suárez', 'claudia.suarez@agroindustriasdelv.com.co', '+57 300 370 2422', 'Jefe de Compras'),
(13, 11, 'Catalina', 'Valencia', 'catalina.valencia@universidadtecnolo.com.co', '+57 321 448 6620', 'Gerente General'),
(14, 12, 'Germán', 'García', 'german.garcia12@correo.com', '+57 317 134 5091', 'Independiente'),
(15, 13, 'Claudia', 'López', 'claudia.lopez@transportesrapidos.com.co', '+57 318 731 3729', 'Coordinador de Sistemas'),
(16, 14, 'Gabriel', 'García', 'gabriel.garcia@hotelmiradorandino.com.co', '+57 322 203 5717', 'Analista de Seguridad'),
(17, 14, 'Liliana', 'Cárdenas', 'liliana.cardenas@hotelmiradorandino.com.co', '+57 308 707 2261', 'Director Financiero'),
(18, 15, 'Sebastián', 'López', 'sebastian.lopez@laboratoriosbiogen.com.co', '+57 327 487 7828', 'Director Financiero'),
(19, 16, 'Sebastián', 'Quintero', 'sebastian.quintero16@correo.com', '+57 300 692 7289', 'Independiente'),
(20, 17, 'Julián', 'Castro', 'julian.castro@distribuidoralamon.com.co', '+57 320 921 8284', 'Asistente de Gerencia'),
(21, 18, 'Sara', 'Ortiz', 'sara.ortiz@colegionuevohorizo.com.co', '+57 316 302 7368', 'Gerente General'),
(22, 18, 'Lina María', 'Rodríguez', 'lina.rodriguez@colegionuevohorizo.com.co', '+57 327 232 8887', 'Gerente de TI'),
(23, 19, 'Germán', 'López', 'german.lopez@fundacionmanosunid.com.co', '+57 323 467 5409', 'Analista de Seguridad'),
(24, 20, 'David', 'Vargas', 'david.vargas20@correo.com', '+57 320 347 4954', 'Independiente'),
(25, 21, 'Paola', 'Castro', 'paola.castro@segurosconfianzapl.com.co', '+57 300 908 1180', 'Director de Operaciones'),
(26, 22, 'Daniela', 'Vargas', 'daniela.vargas@textilesantioquia.com.co', '+57 322 425 1408', 'Asistente de Gerencia'),
(27, 22, 'Mateo', 'Cortés', 'mateo.cortes@textilesantioquia.com.co', '+57 321 822 9590', 'Director Financiero'),
(28, 23, 'Iván', 'Patiño', 'ivan.patino@alcaldiamunicipald.com.co', '+57 329 167 7901', 'Director Administrativo'),
(29, 24, 'Mauricio', 'García', 'mauricio.garcia24@correo.com', '+57 312 259 9955', 'Independiente'),
(30, 25, 'Verónica', 'Valencia', 'veronica.valencia@ferreteriaelconstr.com.co', '+57 329 266 3311', 'Director de Operaciones'),
(31, 26, 'Felipe', 'Arango', 'felipe.arango@energiaverdecolomb.com.co', '+57 322 933 7637', 'Director Financiero'),
(32, 26, 'Mariana', 'Patiño', 'mariana.patino@energiaverdecolomb.com.co', '+57 302 245 9549', 'Director de Operaciones'),
(33, 27, 'Alejandro', 'Quintero', 'alejandro.quintero@cooperativacafeter.com.co', '+57 320 755 9549', 'Asistente de Gerencia'),
(34, 28, 'Juan Camilo', 'Quintero', 'juan.camilo.quintero28@correo.com', '+57 329 362 6541', 'Independiente'),
(35, 29, 'Mateo', 'Mejía', 'mateo.mejia@clinicalosandes.com.co', '+57 319 243 6412', 'Director de Operaciones'),
(36, 30, 'Paula', 'Vargas', 'paula.vargas@softwarefactorybog.com.co', '+57 309 413 7749', 'Analista de Seguridad'),
(37, 30, 'Alejandro', 'Bermúdez', 'alejandro.bermudez@softwarefactorybog.com.co', '+57 303 342 5581', 'Analista de Seguridad'),
(38, 31, 'Tomás', 'Romero', 'tomas.romero@inmobiliariaaltosd.com.co', '+57 322 954 8444', 'Coordinador de Sistemas'),
(39, 32, 'Gabriel', 'Vargas', 'gabriel.vargas32@correo.com', '+57 321 430 3512', 'Independiente'),
(40, 33, 'Tomás', 'Peña', 'tomas.pena@restaurantessaborc.com.co', '+57 319 183 9504', 'Director Financiero'),
(41, 34, 'Mateo', 'Bermúdez', 'mateo.bermudez@notariaquintademed.com.co', '+57 302 939 6770', 'Jefe de Infraestructura'),
(42, 34, 'Felipe', 'Castro', 'felipe.castro@notariaquintademed.com.co', '+57 323 877 9209', 'Director Financiero'),
(43, 35, 'Miguel Ángel', 'Ortiz', 'miguel.ortiz@editorialpaginasab.com.co', '+57 315 575 9370', 'Director Administrativo'),
(44, 36, 'Hernán', 'García', 'hernan.garcia36@correo.com', '+57 320 603 4323', 'Independiente'),
(45, 37, 'Isabella', 'Castro', 'isabella.castro@mineriaresponsable.com.co', '+57 326 336 3335', 'Jefe de Infraestructura'),
(46, 38, 'Lina María', 'Mejía', 'lina.mejia@centromedicosantal.com.co', '+57 315 209 5268', 'Director de Operaciones'),
(47, 38, 'Óscar', 'Patiño', 'oscar.patino@centromedicosantal.com.co', '+57 325 300 9972', 'Director Financiero'),
(48, 39, 'Adriana', 'Valencia', 'adriana.valencia@aerolinearegionale.com.co', '+57 312 262 4651', 'Jefe de Compras'),
(49, 40, 'Andrés', 'Quintero', 'andres.quintero40@correo.com', '+57 303 904 8102', 'Independiente'),
(50, 41, 'Andrés', 'Romero', 'andres.romero@bancocooperativoso.com.co', '+57 319 344 2470', 'Jefe de Compras'),
(51, 42, 'Nicolás', 'Moreno', 'nicolas.moreno@grupologisticoatla.com.co', '+57 326 266 9944', 'Jefe de Compras'),
(52, 42, 'Tomás', 'Castro', 'tomas.castro@grupologisticoatla.com.co', '+57 317 579 9671', 'Jefe de Compras'),
(53, 43, 'Gloria', 'Ruiz', 'gloria.ruiz@farmaciasbienestar.com.co', '+57 306 305 4373', 'Jefe de Compras'),
(54, 44, 'Alejandro', 'Vargas', 'alejandro.vargas44@correo.com', '+57 321 640 6563', 'Independiente'),
(55, 45, 'Mateo', 'Suárez', 'mateo.suarez@institutodeidiomas.com.co', '+57 321 797 1544', 'Gerente de TI'),
(56, 46, 'Julián', 'Zapata', 'julian.zapata@consultoresasociad.com.co', '+57 323 756 7602', 'Jefe de Compras'),
(57, 46, 'Julián', 'Rojas', 'julian.rojas@consultoresasociad.com.co', '+57 305 856 6093', 'Analista de Seguridad'),
(58, 47, 'Andrés', 'Cortés', 'andres.cortes@pinturasarcoiris.com.co', '+57 316 425 6528', 'Gerente de TI'),
(59, 48, 'Miguel Ángel', 'García', 'miguel.angel.garcia48@correo.com', '+57 322 717 9782', 'Independiente'),
(60, 49, 'Alejandro', 'Bermúdez', 'alejandro.bermudez@agenciadeviajesdes.com.co', '+57 304 771 8875', 'Gerente de TI'),
(61, 50, 'Mariana', 'Gutiérrez', 'mariana.gutierrez@lacteoslapradera.com.co', '+57 307 495 8945', 'Analista de Seguridad'),
(62, 50, 'Carolina', 'Quintero', 'carolina.quintero@lacteoslapradera.com.co', '+57 328 609 2039', 'Jefe de Infraestructura'),
(63, 51, 'Valeria', 'Hernández', 'valeria.hernandez@estudiojuridicomen.com.co', '+57 300 685 7820', 'Gerente General'),
(64, 52, 'Germán', 'Quintero', 'german.quintero52@correo.com', '+57 329 235 4134', 'Independiente'),
(65, 53, 'David', 'Moreno', 'david.moreno@camaradecomerciore.com.co', '+57 313 252 6490', 'Director Administrativo'),
(66, 54, 'Manuela', 'Patiño', 'manuela.patino@tiendavirtualcompr.com.co', '+57 311 688 5419', 'Director de Operaciones'),
(67, 54, 'Gloria', 'Romero', 'gloria.romero@tiendavirtualcompr.com.co', '+57 307 891 8245', 'Analista de Seguridad'),
(68, 55, 'Hernán', 'Mendoza', 'hernan.mendoza@clinicaveterinaria.com.co', '+57 317 929 8178', 'Director Administrativo'),
(69, 56, 'Sebastián', 'Vargas', 'sebastian.vargas56@correo.com', '+57 303 504 5436', 'Independiente'),
(70, 57, 'David', 'Cortés', 'david.cortes@productoraaudiovis.com.co', '+57 326 367 1064', 'Jefe de Compras'),
(71, 58, 'Julián', 'Suárez', 'julian.suarez@gimnasiovidaactiva.com.co', '+57 324 290 8627', 'Asistente de Gerencia'),
(72, 58, 'Julián', 'Bermúdez', 'julian.bermudez@gimnasiovidaactiva.com.co', '+57 329 291 2552', 'Analista de Seguridad'),
(73, 59, 'Fabián', 'Ruiz', 'fabian.ruiz@panaderiaindustria.com.co', '+57 321 126 1078', 'Director Administrativo'),
(74, 60, 'David', 'García', 'david.garcia60@correo.com', '+57 306 373 5514', 'Independiente');

INSERT INTO clientes_categorias (id_cliente, id_categoria) VALUES
(1, 2),
(1, 3),
(2, 2),
(4, 2),
(4, 3),
(6, 2),
(8, 2),
(9, 2),
(9, 3),
(10, 2),
(11, 2),
(12, 2),
(13, 2),
(14, 2),
(14, 3),
(15, 2),
(16, 2),
(17, 2),
(18, 2),
(19, 2),
(19, 3),
(20, 2),
(21, 2),
(22, 2),
(23, 2),
(24, 2),
(24, 3),
(25, 2),
(26, 2),
(27, 2),
(28, 2),
(29, 2),
(29, 3),
(30, 2),
(31, 2),
(32, 2),
(33, 2),
(3, 1),
(5, 1),
(7, 1),
(34, 1),
(35, 1),
(36, 1),
(37, 1),
(38, 1),
(39, 1),
(40, 1),
(41, 1),
(42, 1),
(43, 1),
(44, 1),
(45, 1),
(46, 1),
(47, 1),
(48, 1),
(49, 1),
(50, 1),
(51, 1),
(52, 1),
(53, 1),
(54, 1),
(55, 1),
(56, 4),
(57, 4),
(58, 4),
(59, 4),
(60, 4);

INSERT INTO etiquetas (id_etiqueta, nombre, color) VALUES
(1, 'Cliente potencial', '#3498db'),
(2, 'Interesado en correo', '#2ecc71'),
(3, 'Seguimiento urgente', '#e74c3c'),
(4, 'Referido', '#9b59b6'),
(5, 'Decisor', '#1abc9c'),
(6, 'Influenciador', '#16a085'),
(7, 'Técnico', '#27ae60'),
(8, 'Financiero', '#2980b9'),
(9, 'Compras', '#8e44ad'),
(10, 'Renovación próxima', '#f39c12'),
(11, 'Sector salud', '#d35400'),
(12, 'Sector educación', '#c0392b'),
(13, 'Sector público', '#7f8c8d'),
(14, 'Pyme', '#34495e'),
(15, 'Gran cuenta', '#e67e22'),
(16, 'Interesado en seguridad', '#e84393'),
(17, 'Interesado en migración', '#00b894'),
(18, 'Prueba gratuita activa', '#00cec9'),
(19, 'Asistió a webinar', '#0984e3'),
(20, 'Solicitó demo', '#6c5ce7'),
(21, 'Sin respuesta', '#b2bec3'),
(22, 'Promotor', '#55efc4'),
(23, 'Detractor', '#ff7675'),
(24, 'Newsletter', '#74b9ff'),
(25, 'Evento presencial', '#a29bfe'),
(26, 'Contacto principal', '#fdcb6e'),
(27, 'Facturación', '#e17055'),
(28, 'Soporte', '#636e72'),
(29, 'Alta prioridad', '#d63031'),
(30, 'Baja prioridad', '#81ecec');

INSERT INTO contactos_etiquetas (id_contacto, id_etiqueta) VALUES
(1, 2),
(2, 1),
(3, 2),
(4, 1),
(5, 3),
(6, 4),
(7, 2),
(8, 1),
(9, 22),
(9, 23),
(10, 8),
(11, 30),
(11, 1),
(12, 13),
(13, 21),
(13, 22),
(14, 26),
(15, 4),
(16, 11),
(17, 18),
(18, 22),
(19, 8),
(19, 9),
(20, 9),
(21, 1),
(21, 2),
(22, 10),
(23, 16),
(24, 26),
(25, 25),
(25, 26),
(26, 21),
(27, 9),
(27, 10),
(28, 10),
(29, 9),
(30, 13),
(30, 14),
(31, 6),
(31, 7),
(32, 21),
(32, 22),
(33, 2),
(34, 5),
(34, 6),
(35, 12),
(35, 13),
(36, 16),
(36, 17),
(37, 28),
(38, 4),
(39, 27),
(40, 9),
(41, 30),
(41, 1),
(42, 20),
(42, 21),
(43, 26),
(44, 14),
(44, 15),
(45, 27),
(46, 14),
(46, 15),
(47, 19),
(47, 20),
(48, 18),
(49, 29),
(49, 30),
(50, 28),
(51, 8),
(52, 30),
(52, 1),
(53, 14),
(54, 6),
(55, 3),
(55, 4),
(56, 26),
(57, 4),
(57, 5),
(58, 29),
(58, 30),
(59, 8),
(59, 9),
(60, 30),
(61, 14),
(61, 15),
(62, 5),
(62, 6),
(63, 11),
(63, 12),
(64, 5),
(65, 30),
(66, 6),
(67, 24),
(68, 12),
(69, 16),
(70, 10),
(71, 22),
(71, 23),
(72, 25),
(73, 3),
(73, 4),
(74, 5),
(74, 6);

INSERT INTO asignaciones_clientes (id_asignacion, id_cliente, id_vendedor, fecha_asignacion) VALUES
(1, 1, 1, '2026-09-05 09:15:00'),
(2, 2, 1, '2026-09-08 10:30:00'),
(3, 3, 2, '2026-09-12 14:00:00'),
(4, 4, 2, '2026-08-20 08:45:00'),
(5, 5, 3, '2026-09-20 11:20:00'),
(6, 6, 3, '2026-09-25 16:10:00'),
(7, 7, 3, '2026-10-01 09:00:00'),
(8, 8, 2, '2026-08-25 13:40:00'),
(9, 9, 6, '2025-09-13 16:15:00'),
(10, 10, 30, '2025-12-03 16:00:00'),
(11, 10, 13, '2025-12-22 16:00:00'),
(12, 11, 20, '2025-10-25 15:00:00'),
(13, 12, 27, '2025-11-15 10:30:00'),
(14, 13, 5, '2025-09-20 14:15:00'),
(15, 14, 12, '2025-10-06 15:45:00'),
(16, 15, 17, '2025-11-23 09:00:00'),
(17, 15, 19, '2025-12-12 09:00:00'),
(18, 16, 26, '2026-02-24 09:30:00'),
(19, 17, 4, '2025-09-26 10:45:00'),
(20, 18, 11, '2026-01-17 12:15:00'),
(21, 19, 18, '2025-10-09 08:45:00'),
(22, 20, 30, '2025-11-10 11:45:00'),
(23, 20, 25, '2025-11-29 11:45:00'),
(24, 21, 3, '2026-01-03 11:30:00'),
(25, 22, 10, '2025-12-04 14:45:00'),
(26, 23, 17, '2026-02-04 09:15:00'),
(27, 24, 24, '2025-09-21 14:30:00'),
(28, 25, 18, '2026-01-12 10:30:00'),
(29, 25, 2, '2026-01-31 10:30:00'),
(30, 26, 9, '2025-11-06 08:45:00'),
(31, 27, 16, '2025-11-23 15:00:00'),
(32, 28, 23, '2026-02-03 13:45:00'),
(33, 29, 1, '2026-02-02 16:45:00'),
(34, 30, 30, '2025-11-04 08:30:00'),
(35, 30, 8, '2025-11-23 08:30:00'),
(36, 31, 15, '2025-10-16 12:00:00'),
(37, 32, 22, '2026-01-19 11:45:00'),
(38, 33, 29, '2025-09-12 12:15:00'),
(39, 34, 7, '2026-08-15 08:15:00'),
(40, 35, 19, '2026-05-23 09:15:00'),
(41, 35, 14, '2026-06-11 09:15:00'),
(42, 36, 21, '2026-05-17 14:15:00'),
(43, 37, 28, '2026-09-24 08:15:00'),
(44, 38, 6, '2026-04-20 14:15:00'),
(45, 39, 13, '2026-03-24 08:45:00'),
(46, 40, 30, '2026-10-11 08:00:00'),
(47, 40, 20, '2026-10-30 08:00:00'),
(48, 41, 27, '2026-04-13 16:00:00'),
(49, 42, 5, '2026-06-26 17:00:00'),
(50, 43, 12, '2026-07-06 17:00:00'),
(51, 44, 19, '2026-09-01 13:30:00'),
(52, 45, 20, '2026-09-19 14:45:00'),
(53, 45, 26, '2026-10-08 14:45:00'),
(54, 46, 4, '2026-08-18 13:30:00'),
(55, 47, 11, '2026-08-07 17:00:00'),
(56, 48, 18, '2026-04-24 14:45:00'),
(57, 49, 25, '2026-06-16 17:00:00'),
(58, 50, 30, '2026-04-29 09:15:00'),
(59, 50, 3, '2026-05-18 09:15:00'),
(60, 51, 10, '2026-04-19 12:00:00'),
(61, 52, 17, '2026-07-21 09:00:00'),
(62, 53, 24, '2026-07-10 08:15:00'),
(63, 54, 2, '2026-08-10 11:00:00'),
(64, 55, 21, '2026-06-11 12:00:00'),
(65, 55, 9, '2026-06-30 12:00:00'),
(66, 56, 16, '2026-04-14 10:00:00'),
(67, 57, 23, '2026-09-28 14:00:00'),
(68, 58, 1, '2026-05-15 12:15:00'),
(69, 59, 8, '2026-07-04 16:30:00'),
(70, 60, 30, '2026-03-04 10:15:00'),
(71, 60, 15, '2026-03-23 10:15:00');

-- ------------------------------------------------------------
-- 6. Productos y categorías
-- ------------------------------------------------------------
INSERT INTO categorias_productos (id_categoria, nombre, descripcion) VALUES
(1, 'Correo corporativo', 'Productos y servicios de correo corporativo'),
(2, 'Seguridad', 'Productos y servicios de seguridad'),
(3, 'Colaboración', 'Productos y servicios de colaboración'),
(4, 'Soporte', 'Productos y servicios de soporte'),
(5, 'Migración', 'Productos y servicios de migración'),
(6, 'Almacenamiento', 'Productos y servicios de almacenamiento'),
(7, 'Movilidad', 'Productos y servicios de movilidad'),
(8, 'Respaldo', 'Productos y servicios de respaldo'),
(9, 'Archivado', 'Productos y servicios de archivado'),
(10, 'Antispam', 'Productos y servicios de antispam'),
(11, 'Cifrado', 'Productos y servicios de cifrado'),
(12, 'Capacitación', 'Productos y servicios de capacitación'),
(13, 'Consultoría', 'Productos y servicios de consultoría'),
(14, 'Licenciamiento', 'Productos y servicios de licenciamiento'),
(15, 'Integraciones', 'Productos y servicios de integraciones'),
(16, 'Videoconferencia', 'Productos y servicios de videoconferencia'),
(17, 'Mensajería instantánea', 'Productos y servicios de mensajería instantánea'),
(18, 'Documentos', 'Productos y servicios de documentos'),
(19, 'Cumplimiento normativo', 'Productos y servicios de cumplimiento normativo'),
(20, 'Alta disponibilidad', 'Productos y servicios de alta disponibilidad'),
(21, 'Nube pública', 'Productos y servicios de nube pública'),
(22, 'Nube privada', 'Productos y servicios de nube privada'),
(23, 'On-premise', 'Productos y servicios de on-premise'),
(24, 'Sector salud', 'Productos y servicios de sector salud'),
(25, 'Sector educación', 'Productos y servicios de sector educación'),
(26, 'Monitoreo', 'Productos y servicios de monitoreo'),
(27, 'Productividad', 'Productos y servicios de productividad'),
(28, 'Pymes', 'Productos y servicios de pymes'),
(29, 'Grandes empresas', 'Productos y servicios de grandes empresas'),
(30, 'Servicios profesionales', 'Productos y servicios de servicios profesionales');

INSERT INTO productos (id_producto, nombre, descripcion, precio, stock, estado) VALUES
(1, 'Zimbra Starter', 'Plan básico de correo para pequeños equipos.', 45000.00, 5000, 1),
(2, 'Zimbra Professional', 'Plan profesional con calendario y colaboración.', 85000.00, 4000, 1),
(3, 'Zimbra Enterprise', 'Plan empresarial de alta disponibilidad.', 145000.00, 3000, 1),
(4, 'Módulo Antispam Avanzado', 'Filtro antispam y antiphishing gestionado.', 25000.00, 8000, 1),
(5, 'Zimbra Suite Plus', 'Suite de colaboración y movilidad.', 120000.00, 2500, 1),
(6, 'Soporte Premium 24/7', 'Soporte prioritario con SLA de 4 horas.', 300000.00, 999, 1),
(7, 'Zimbra Basic Cloud', 'Correo en la nube para microempresas.', 30000.00, 6000, 0),
(8, 'Migración de buzones', 'Migración asistida desde otro proveedor (por buzón).', 40000.00, 9000, 1),
(9, 'Capacitación virtual', 'Sesión de capacitación en línea para usuarios finales.', 450000.00, 500, 1),
(10, 'Capacitación presencial', 'Jornada de capacitación en sitio (por día).', 1800000.00, 200, 1),
(11, 'Módulo de Cifrado S/MIME', 'Firma y cifrado de correos.', 35000.00, 5000, 1),
(12, 'Archivado y eDiscovery', 'Retención legal y búsqueda de correos.', 55000.00, 4000, 1),
(13, 'Backup en la nube', 'Respaldo diario de buzones (por usuario).', 20000.00, 9000, 1),
(14, 'Almacenamiento adicional 50 GB', 'Ampliación de cuota por usuario.', 15000.00, 9000, 1),
(15, 'Zimbra Connect', 'Videoconferencia integrada (por usuario).', 60000.00, 4000, 1),
(16, 'Zimbra Talk', 'Chat corporativo (por usuario).', 25000.00, 6000, 1),
(17, 'Zimbra Docs', 'Edición colaborativa de documentos (por usuario).', 30000.00, 6000, 1),
(18, 'Conector Outlook', 'Sincronización con Microsoft Outlook (por usuario).', 18000.00, 7000, 1),
(19, 'Sincronización móvil ActiveSync', 'Correo y calendario en el móvil (por usuario).', 22000.00, 7000, 1),
(20, 'Consultoría de arquitectura', 'Hora de consultoría especializada.', 250000.00, 2000, 1),
(21, 'Implementación on-premise', 'Despliegue en servidores del cliente.', 8500000.00, 100, 1),
(22, 'Implementación en nube privada', 'Despliegue en nube privada administrada.', 6500000.00, 100, 1),
(23, 'Licencia de alta disponibilidad', 'Clúster activo-pasivo.', 2500000.00, 300, 1),
(24, 'Auditoría de seguridad de correo', 'Revisión de configuración y riesgos.', 4200000.00, 150, 1),
(25, 'Soporte Estándar 8x5', 'Soporte en horario laboral (por mes).', 120000.00, 2000, 1),
(26, 'Paquete educación', 'Licencia académica (por usuario).', 12000.00, 20000, 1),
(27, 'Paquete salud con cumplimiento', 'Correo con controles para datos clínicos (por usuario).', 95000.00, 3000, 1),
(28, 'Integración API con CRM', 'Conexión del correo con el CRM del cliente.', 3800000.00, 150, 1),
(29, 'Monitoreo y alertas 24/7', 'Monitoreo de la plataforma (por mes).', 900000.00, 500, 1),
(30, 'Filtro DLP', 'Prevención de fuga de información (por usuario).', 28000.00, 6000, 1);

INSERT INTO productos_detalles (id_detalle, id_producto, atributo, valor) VALUES
(1, 1, 'Usuarios incluidos', '10'),
(2, 1, 'Almacenamiento', '10 GB por usuario'),
(3, 2, 'Usuarios incluidos', '50'),
(4, 2, 'Almacenamiento', '50 GB por usuario'),
(5, 3, 'Usuarios incluidos', 'Ilimitados'),
(6, 3, 'Alta disponibilidad', 'Sí'),
(7, 4, 'Vigencia', '12 meses'),
(8, 5, 'Movilidad', 'Android e iOS'),
(9, 6, 'Tiempo de respuesta', '4 horas'),
(10, 4, 'Modalidad', 'Por usuario'),
(11, 5, 'Vigencia', '12 meses'),
(12, 6, 'Vigencia', '12 meses'),
(13, 7, 'Modalidad', 'Por usuario'),
(14, 7, 'Vigencia', '12 meses'),
(15, 8, 'Modalidad', 'Por usuario'),
(16, 8, 'Vigencia', '12 meses'),
(17, 9, 'Modalidad', 'Por servicio'),
(18, 9, 'Vigencia', '12 meses'),
(19, 10, 'Modalidad', 'Por servicio'),
(20, 10, 'Vigencia', 'Única vez'),
(21, 11, 'Modalidad', 'Por usuario'),
(22, 11, 'Vigencia', '12 meses'),
(23, 12, 'Modalidad', 'Por usuario'),
(24, 12, 'Vigencia', '12 meses'),
(25, 13, 'Modalidad', 'Por usuario'),
(26, 13, 'Vigencia', '12 meses'),
(27, 14, 'Modalidad', 'Por usuario'),
(28, 14, 'Vigencia', '12 meses'),
(29, 15, 'Modalidad', 'Por usuario'),
(30, 15, 'Vigencia', '12 meses'),
(31, 16, 'Modalidad', 'Por usuario'),
(32, 16, 'Vigencia', '12 meses'),
(33, 17, 'Modalidad', 'Por usuario'),
(34, 17, 'Vigencia', '12 meses'),
(35, 18, 'Modalidad', 'Por usuario'),
(36, 18, 'Vigencia', '12 meses'),
(37, 19, 'Modalidad', 'Por usuario'),
(38, 19, 'Vigencia', '12 meses'),
(39, 20, 'Modalidad', 'Por servicio'),
(40, 20, 'Vigencia', '1 mes'),
(41, 21, 'Modalidad', 'Por servicio'),
(42, 21, 'Vigencia', '12 meses'),
(43, 22, 'Modalidad', 'Por servicio'),
(44, 22, 'Vigencia', 'Única vez'),
(45, 23, 'Modalidad', 'Por servicio'),
(46, 23, 'Vigencia', '12 meses'),
(47, 24, 'Modalidad', 'Por servicio'),
(48, 24, 'Vigencia', 'Única vez'),
(49, 25, 'Modalidad', 'Por servicio'),
(50, 25, 'Vigencia', '1 mes'),
(51, 26, 'Modalidad', 'Por usuario'),
(52, 26, 'Vigencia', '12 meses'),
(53, 27, 'Modalidad', 'Por usuario'),
(54, 27, 'Vigencia', '12 meses'),
(55, 28, 'Modalidad', 'Por servicio'),
(56, 28, 'Vigencia', '12 meses'),
(57, 29, 'Modalidad', 'Por servicio'),
(58, 29, 'Vigencia', '12 meses'),
(59, 30, 'Modalidad', 'Por usuario'),
(60, 30, 'Vigencia', '12 meses');

INSERT INTO productos_categorias (id_producto, id_categoria) VALUES
(1, 1),
(2, 1),
(2, 3),
(3, 1),
(3, 3),
(4, 2),
(5, 3),
(6, 4),
(1, 28),
(3, 29),
(4, 10),
(5, 7),
(6, 26),
(7, 1),
(7, 21),
(8, 5),
(8, 30),
(9, 12),
(9, 30),
(10, 12),
(10, 30),
(11, 2),
(11, 11),
(12, 9),
(12, 19),
(13, 8),
(13, 6),
(14, 6),
(14, 21),
(15, 16),
(15, 27),
(16, 17),
(16, 27),
(17, 18),
(17, 3),
(18, 15),
(18, 27),
(19, 7),
(19, 15),
(20, 13),
(20, 30),
(21, 23),
(21, 30),
(22, 22),
(22, 30),
(23, 20),
(23, 29),
(24, 2),
(24, 19),
(25, 4),
(25, 14),
(26, 25),
(26, 14),
(27, 24),
(27, 19),
(28, 15),
(28, 13),
(29, 26),
(29, 4),
(30, 2),
(30, 19);

-- ------------------------------------------------------------
-- 4. Oportunidades y seguimientos
-- ------------------------------------------------------------
-- Catálogo del embudo de ventas: 6 etapas fijas por diseño
INSERT INTO etapas_ventas (id_etapa, nombre, orden) VALUES
(1, 'Prospecto', 1),
(2, 'Contacto realizado', 2),
(3, 'Propuesta enviada', 3),
(4, 'Negociación', 4),
(5, 'Cierre ganado', 5),
(6, 'Cierre perdido', 6);

INSERT INTO oportunidades (id_oportunidad, id_cliente, id_vendedor, id_etapa, titulo, descripcion, valor_estimado, estado, fecha_cierre, fecha_creacion) VALUES
(1, 1, 1, 5, 'Migración a correo corporativo Zimbra', 'Migración de 250 buzones a Zimbra Collaboration Professional con soporte anual.', 21550000.00, 'ganada', '2026-10-12', '2026-09-10 09:00:00'),
(2, 2, 1, 3, 'Licencias Zimbra Collaboration Professional', 'Renovación de 120 licencias y módulo antispam avanzado.', 13200000.00, 'abierta', '2026-11-30', '2026-09-18 10:15:00'),
(3, 4, 2, 5, 'Implementación suite colaborativa', 'Implementación de Zimbra Enterprise para 400 usuarios con migración incluida.', 58300000.00, 'ganada', '2026-10-05', '2026-08-25 08:30:00'),
(4, 6, 3, 2, 'Correo seguro para personal médico', 'Solución de correo con cifrado y cumplimiento para 90 usuarios de la clínica.', 12800000.00, 'abierta', '2027-01-31', '2026-10-02 11:45:00'),
(5, 8, 2, 6, 'Renovación plataforma logística', 'Renovación de la plataforma de correo y colaboración para operaciones.', 8700000.00, 'perdida', '2026-09-30', '2026-08-30 15:20:00'),
(6, 8, 2, 5, 'Suite colaborativa Paquete educación', 'Oportunidad cerrada con venta.', 8352000.00, 'ganada', '2026-01-06', '2025-12-08 17:15:00'),
(7, 9, 6, 5, 'Suite colaborativa Zimbra Enterprise', 'Oportunidad cerrada con venta.', 54420000.00, 'ganada', '2026-02-11', '2026-01-03 16:45:00'),
(8, 10, 13, 5, 'Correo corporativo Zimbra Enterprise para 214 usuarios', 'Oportunidad cerrada con venta.', 31030000.00, 'ganada', '2026-03-08', '2026-02-11 11:00:00'),
(9, 11, 20, 5, 'Renovación de licencias Zimbra Starter', 'Oportunidad cerrada con venta.', 14370000.00, 'ganada', '2026-04-25', '2026-03-18 12:15:00'),
(10, 12, 27, 5, 'Correo corporativo Paquete educación para 655 usuarios', 'Oportunidad cerrada con venta.', 16360000.00, 'ganada', '2026-05-24', '2026-05-03 09:15:00'),
(11, 13, 5, 5, 'Renovación de licencias Zimbra Suite Plus', 'Oportunidad cerrada con venta.', 14530000.00, 'ganada', '2026-06-13', '2026-05-16 13:15:00'),
(12, 14, 12, 5, 'Implementación Paquete educación con soporte', 'Oportunidad cerrada con venta.', 22828000.00, 'ganada', '2026-07-15', '2026-06-24 12:00:00'),
(13, 15, 19, 5, 'Renovación de licencias Paquete salud con cumplimiento', 'Oportunidad cerrada con venta.', 21470000.00, 'ganada', '2026-08-03', '2026-07-01 17:45:00'),
(14, 16, 26, 5, 'Implementación Zimbra Enterprise con soporte', 'Oportunidad cerrada con venta.', 18100000.00, 'ganada', '2026-09-07', '2026-08-08 17:30:00'),
(15, 17, 4, 5, 'Correo corporativo Paquete educación para 316 usuarios', 'Oportunidad cerrada con venta.', 4092000.00, 'ganada', '2026-10-12', '2026-09-11 14:30:00'),
(16, 18, 11, 5, 'Suite colaborativa Zimbra Starter', 'Oportunidad cerrada con venta.', 21195000.00, 'ganada', '2026-11-11', '2026-10-08 14:45:00'),
(17, 19, 18, 5, 'Migración a Zimbra Starter', 'Oportunidad cerrada con venta.', 18855000.00, 'ganada', '2026-01-02', '2025-11-28 08:30:00'),
(18, 20, 25, 5, 'Implementación Zimbra Professional con soporte', 'Oportunidad cerrada con venta.', 31047000.00, 'ganada', '2026-02-15', '2026-01-11 16:30:00'),
(19, 21, 3, 5, 'Correo corporativo Paquete salud con cumplimiento para 269 usuarios', 'Oportunidad cerrada con venta.', 32280000.00, 'ganada', '2026-03-23', '2026-02-18 16:45:00'),
(20, 22, 10, 5, 'Migración a Zimbra Suite Plus', 'Oportunidad cerrada con venta.', 45880000.00, 'ganada', '2026-04-04', '2026-03-06 08:30:00'),
(21, 23, 17, 5, 'Suite colaborativa Paquete salud con cumplimiento', 'Oportunidad cerrada con venta.', 15274000.00, 'ganada', '2026-05-18', '2026-04-09 13:45:00'),
(22, 24, 24, 5, 'Implementación Paquete salud con cumplimiento con soporte', 'Oportunidad cerrada con venta.', 30720000.00, 'ganada', '2026-06-20', '2026-05-11 15:00:00'),
(23, 25, 2, 5, 'Migración a Zimbra Professional', 'Oportunidad cerrada con venta.', 30130000.00, 'ganada', '2026-07-07', '2026-06-05 11:30:00'),
(24, 26, 9, 5, 'Renovación de licencias Zimbra Suite Plus', 'Oportunidad cerrada con venta.', 33240000.00, 'ganada', '2026-08-24', '2026-08-02 10:00:00'),
(25, 27, 16, 5, 'Migración a Paquete salud con cumplimiento', 'Oportunidad cerrada con venta.', 40507000.00, 'ganada', '2026-09-09', '2026-07-28 14:15:00'),
(26, 28, 23, 5, 'Suite colaborativa Zimbra Suite Plus', 'Oportunidad cerrada con venta.', 21120000.00, 'ganada', '2026-10-07', '2026-08-27 14:45:00'),
(27, 29, 1, 5, 'Migración a Paquete salud con cumplimiento', 'Oportunidad cerrada con venta.', 20515000.00, 'ganada', '2026-11-09', '2026-10-04 08:30:00'),
(28, 30, 8, 5, 'Renovación de licencias Zimbra Suite Plus', 'Oportunidad cerrada con venta.', 6690000.00, 'ganada', '2026-01-27', '2025-12-26 13:45:00'),
(29, 31, 15, 5, 'Implementación Zimbra Enterprise con soporte', 'Oportunidad cerrada con venta.', 41325000.00, 'ganada', '2026-02-18', '2026-01-29 11:45:00'),
(30, 32, 22, 5, 'Renovación de licencias Zimbra Suite Plus', 'Oportunidad cerrada con venta.', 52100000.00, 'ganada', '2026-03-26', '2026-02-11 10:45:00'),
(31, 33, 29, 5, 'Correo corporativo Zimbra Suite Plus para 261 usuarios', 'Oportunidad cerrada con venta.', 31320000.00, 'ganada', '2026-04-05', '2026-02-22 10:30:00'),
(32, 10, 13, 6, 'Suite colaborativa Zimbra Starter', 'Oportunidad cerrada sin venta.', 24965000.00, 'perdida', '2026-09-04', '2026-07-30 16:15:00'),
(33, 14, 12, 6, 'Renovación de licencias Zimbra Professional', 'Oportunidad cerrada sin venta.', 9180000.00, 'perdida', '2026-04-26', '2026-03-16 13:15:00'),
(34, 19, 18, 6, 'Renovación de licencias Zimbra Starter', 'Oportunidad cerrada sin venta.', 2700000.00, 'perdida', '2026-03-20', '2026-02-26 15:00:00'),
(35, 46, 4, 6, 'Renovación de licencias Zimbra Starter', 'Oportunidad cerrada sin venta.', 4815000.00, 'perdida', '2026-07-21', '2026-06-12 16:15:00'),
(36, 47, 11, 6, 'Renovación de licencias Zimbra Professional', 'Oportunidad cerrada sin venta.', 13600000.00, 'perdida', '2026-08-23', '2026-07-25 11:15:00'),
(37, 48, 18, 6, 'Suite colaborativa Paquete salud con cumplimiento', 'Oportunidad cerrada sin venta.', 15375000.00, 'perdida', '2026-02-03', '2026-01-06 15:30:00'),
(38, 49, 25, 6, 'Migración a Zimbra Enterprise', 'Oportunidad cerrada sin venta.', 6525000.00, 'perdida', '2026-03-02', '2026-02-06 09:45:00'),
(39, 34, 7, 1, 'Migración a Zimbra Suite Plus', 'Oportunidad en curso.', 14550000.00, 'abierta', '2027-01-24', '2026-08-19 13:15:00'),
(40, 35, 14, 2, 'Suite colaborativa Zimbra Suite Plus', 'Oportunidad en curso.', 17280000.00, 'abierta', '2027-02-26', '2026-09-20 11:30:00'),
(41, 36, 21, 3, 'Migración a Zimbra Professional', 'Oportunidad en curso.', 5459000.00, 'abierta', '2027-01-06', '2026-08-28 16:45:00'),
(42, 37, 28, 4, 'Renovación de licencias Paquete educación', 'Oportunidad en curso.', 6636000.00, 'abierta', '2027-01-18', '2026-09-13 14:30:00'),
(43, 38, 6, 1, 'Renovación de licencias Zimbra Suite Plus', 'Oportunidad en curso.', 10800000.00, 'abierta', '2027-02-18', '2026-09-04 13:15:00'),
(44, 39, 13, 2, 'Correo corporativo Zimbra Enterprise para 145 usuarios', 'Oportunidad en curso.', 28450000.00, 'abierta', '2027-01-18', '2026-10-25 12:15:00'),
(45, 40, 20, 3, 'Migración a Paquete salud con cumplimiento', 'Oportunidad en curso.', 6490000.00, 'abierta', '2027-02-05', '2026-10-06 11:15:00'),
(46, 41, 27, 4, 'Migración a Zimbra Professional', 'Oportunidad en curso.', 18440000.00, 'abierta', '2027-01-02', '2026-11-04 09:15:00'),
(47, 42, 5, 1, 'Renovación de licencias Zimbra Starter', 'Oportunidad en curso.', 15685000.00, 'abierta', '2027-01-07', '2026-09-14 13:15:00'),
(48, 43, 12, 2, 'Renovación de licencias Zimbra Professional', 'Oportunidad en curso.', 11770000.00, 'abierta', '2026-12-26', '2026-08-28 13:45:00'),
(49, 44, 19, 3, 'Correo corporativo Zimbra Professional para 258 usuarios', 'Oportunidad en curso.', 43860000.00, 'abierta', '2027-01-13', '2026-08-23 11:15:00'),
(50, 45, 26, 4, 'Migración a Zimbra Professional', 'Oportunidad en curso.', 26680000.00, 'abierta', '2027-02-03', '2026-09-19 12:15:00');

INSERT INTO oportunidades_detalle (id_detalle, id_oportunidad, descripcion, fecha) VALUES
(1, 1, 'Reunión inicial con el área de TI. Se identificaron 250 buzones.', '2026-09-12 10:00:00'),
(2, 1, 'Se envió propuesta económica y plan de migración por fases.', '2026-10-10 16:30:00'),
(3, 2, 'Cliente solicita descuento por renovación anticipada.', '2026-10-18 09:20:00'),
(4, 3, 'Propuesta aceptada. Inicia implementación el 5 de octubre.', '2026-10-05 12:00:00'),
(5, 4, 'Primera llamada con el director médico. Interés en cifrado.', '2026-10-08 15:00:00'),
(6, 5, 'El cliente decidió continuar con su proveedor actual.', '2026-09-30 17:10:00'),
(7, 1, 'Propuesta aceptada por gerencia. Se firma el contrato.', '2026-10-12 09:30:00'),
(8, 6, 'Levantamiento de necesidades con el cliente.', '2025-12-10 17:15:00'),
(9, 6, 'Propuesta aceptada; se registra la venta.', '2026-01-06 17:15:00'),
(10, 7, 'Levantamiento de necesidades con el cliente.', '2026-01-05 16:45:00'),
(11, 7, 'Propuesta aceptada; se registra la venta.', '2026-02-11 16:45:00'),
(12, 8, 'Levantamiento de necesidades con el cliente.', '2026-02-13 11:00:00'),
(13, 8, 'Propuesta aceptada; se registra la venta.', '2026-03-08 11:00:00'),
(14, 9, 'Levantamiento de necesidades con el cliente.', '2026-03-20 12:15:00'),
(15, 9, 'Propuesta aceptada; se registra la venta.', '2026-04-25 12:15:00'),
(16, 10, 'Levantamiento de necesidades con el cliente.', '2026-05-05 09:15:00'),
(17, 10, 'Propuesta aceptada; se registra la venta.', '2026-05-24 09:15:00'),
(18, 11, 'Levantamiento de necesidades con el cliente.', '2026-05-18 13:15:00'),
(19, 11, 'Propuesta aceptada; se registra la venta.', '2026-06-13 13:15:00'),
(20, 12, 'Levantamiento de necesidades con el cliente.', '2026-06-26 12:00:00'),
(21, 12, 'Propuesta aceptada; se registra la venta.', '2026-07-15 12:00:00'),
(22, 13, 'Levantamiento de necesidades con el cliente.', '2026-07-03 17:45:00'),
(23, 13, 'Propuesta aceptada; se registra la venta.', '2026-08-03 17:45:00'),
(24, 14, 'Levantamiento de necesidades con el cliente.', '2026-08-10 17:30:00'),
(25, 14, 'Propuesta aceptada; se registra la venta.', '2026-09-07 17:30:00'),
(26, 15, 'Levantamiento de necesidades con el cliente.', '2026-09-13 14:30:00'),
(27, 15, 'Propuesta aceptada; se registra la venta.', '2026-10-12 14:30:00'),
(28, 16, 'Levantamiento de necesidades con el cliente.', '2026-10-10 14:45:00'),
(29, 16, 'Propuesta aceptada; se registra la venta.', '2026-11-11 14:45:00'),
(30, 17, 'Levantamiento de necesidades con el cliente.', '2025-11-30 08:30:00'),
(31, 17, 'Propuesta aceptada; se registra la venta.', '2026-01-02 08:30:00'),
(32, 18, 'Levantamiento de necesidades con el cliente.', '2026-01-13 16:30:00'),
(33, 18, 'Propuesta aceptada; se registra la venta.', '2026-02-15 16:30:00'),
(34, 19, 'Levantamiento de necesidades con el cliente.', '2026-02-20 16:45:00'),
(35, 19, 'Propuesta aceptada; se registra la venta.', '2026-03-23 16:45:00'),
(36, 20, 'Levantamiento de necesidades con el cliente.', '2026-03-08 08:30:00'),
(37, 20, 'Propuesta aceptada; se registra la venta.', '2026-04-04 08:30:00'),
(38, 21, 'Levantamiento de necesidades con el cliente.', '2026-04-11 13:45:00'),
(39, 21, 'Propuesta aceptada; se registra la venta.', '2026-05-18 13:45:00'),
(40, 22, 'Levantamiento de necesidades con el cliente.', '2026-05-13 15:00:00'),
(41, 22, 'Propuesta aceptada; se registra la venta.', '2026-06-20 15:00:00'),
(42, 23, 'Levantamiento de necesidades con el cliente.', '2026-06-07 11:30:00'),
(43, 23, 'Propuesta aceptada; se registra la venta.', '2026-07-07 11:30:00'),
(44, 24, 'Levantamiento de necesidades con el cliente.', '2026-08-04 10:00:00'),
(45, 24, 'Propuesta aceptada; se registra la venta.', '2026-08-24 10:00:00'),
(46, 25, 'Levantamiento de necesidades con el cliente.', '2026-07-30 14:15:00'),
(47, 25, 'Propuesta aceptada; se registra la venta.', '2026-09-09 14:15:00'),
(48, 26, 'Levantamiento de necesidades con el cliente.', '2026-08-29 14:45:00'),
(49, 26, 'Propuesta aceptada; se registra la venta.', '2026-10-07 14:45:00'),
(50, 27, 'Levantamiento de necesidades con el cliente.', '2026-10-06 08:30:00'),
(51, 27, 'Propuesta aceptada; se registra la venta.', '2026-11-09 08:30:00'),
(52, 28, 'Levantamiento de necesidades con el cliente.', '2025-12-28 13:45:00'),
(53, 28, 'Propuesta aceptada; se registra la venta.', '2026-01-27 13:45:00'),
(54, 29, 'Levantamiento de necesidades con el cliente.', '2026-01-31 11:45:00'),
(55, 29, 'Propuesta aceptada; se registra la venta.', '2026-02-18 11:45:00'),
(56, 30, 'Levantamiento de necesidades con el cliente.', '2026-02-13 10:45:00'),
(57, 30, 'Propuesta aceptada; se registra la venta.', '2026-03-26 10:45:00'),
(58, 31, 'Levantamiento de necesidades con el cliente.', '2026-02-24 10:30:00'),
(59, 31, 'Propuesta aceptada; se registra la venta.', '2026-04-05 10:30:00'),
(60, 32, 'El proyecto fue cancelado por el cliente.', '2026-09-04 16:15:00'),
(61, 33, 'El cliente eligió otro proveedor.', '2026-04-26 13:15:00'),
(62, 34, 'El cliente eligió otro proveedor.', '2026-03-20 15:00:00'),
(63, 35, 'El cliente eligió otro proveedor.', '2026-07-21 16:15:00'),
(64, 36, 'El proyecto fue cancelado por el cliente.', '2026-08-23 11:15:00'),
(65, 37, 'El cliente eligió otro proveedor.', '2026-02-03 15:30:00'),
(66, 38, 'El cliente eligió otro proveedor.', '2026-03-02 09:45:00'),
(67, 39, 'El prospecto pidió una demo.', '2026-08-20 13:15:00'),
(68, 40, 'Se solicitó información de precios.', '2026-09-21 11:30:00'),
(69, 41, 'Se solicitó información de precios.', '2026-08-29 16:45:00'),
(70, 42, 'El prospecto pidió una demo.', '2026-09-14 14:30:00'),
(71, 43, 'El prospecto pidió una demo.', '2026-09-05 13:15:00'),
(72, 44, 'Primer contacto por formulario web.', '2026-10-26 12:15:00'),
(73, 45, 'Se solicitó información de precios.', '2026-10-07 11:15:00'),
(74, 46, 'Llamada de calificación realizada.', '2026-11-05 09:15:00'),
(75, 47, 'El prospecto pidió una demo.', '2026-09-15 13:15:00'),
(76, 48, 'Primer contacto por formulario web.', '2026-08-29 13:45:00'),
(77, 49, 'Primer contacto por formulario web.', '2026-08-24 11:15:00'),
(78, 50, 'Primer contacto por formulario web.', '2026-09-20 12:15:00');

INSERT INTO seguimientos (id_seguimiento, id_oportunidad, id_usuario, tipo, descripcion, fecha) VALUES
(1, 1, 2, 'reunion', 'Reunión de levantamiento de requerimientos con TI.', '2026-09-12 10:00:00'),
(2, 1, 2, 'correo', 'Envío de propuesta técnica y comercial.', '2026-10-10 16:30:00'),
(3, 1, 2, 'llamada', 'Llamada de cierre: gerencia aprueba la propuesta.', '2026-10-11 11:00:00'),
(4, 2, 2, 'llamada', 'Negociación de descuento por renovación anticipada.', '2026-10-18 09:20:00'),
(5, 3, 3, 'reunion', 'Cierre de negociación y firma de acta de inicio.', '2026-10-05 12:00:00'),
(6, 4, 4, 'correo', 'Envío de brochure de seguridad y cumplimiento.', '2026-10-09 08:40:00'),
(7, 5, 3, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-09-04 10:00:00'),
(8, 6, 3, 'reunion', 'Reunión de revisión de alcance.', '2025-12-21 11:30:00'),
(9, 6, 3, 'visita', 'Visita a las instalaciones del cliente.', '2025-12-11 16:45:00'),
(10, 7, 8, 'reunion', 'Reunión de revisión de alcance.', '2026-01-27 17:30:00'),
(11, 8, 15, 'demo', 'Demostración del producto.', '2026-02-22 11:15:00'),
(12, 9, 22, 'correo', 'Correo con información solicitada.', '2026-04-20 14:45:00'),
(13, 9, 22, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-03-21 16:30:00'),
(14, 10, 29, 'demo', 'Demostración del producto.', '2026-05-10 08:30:00'),
(15, 11, 7, 'visita', 'Visita a las instalaciones del cliente.', '2026-06-08 10:15:00'),
(16, 12, 14, 'demo', 'Demostración del producto.', '2026-06-30 11:15:00'),
(17, 12, 14, 'visita', 'Visita a las instalaciones del cliente.', '2026-06-25 16:15:00'),
(18, 13, 21, 'visita', 'Visita a las instalaciones del cliente.', '2026-07-19 09:30:00'),
(19, 14, 28, 'correo', 'Correo con información solicitada.', '2026-08-29 10:30:00'),
(20, 15, 6, 'demo', 'Demostración del producto.', '2026-09-26 12:45:00'),
(21, 15, 6, 'demo', 'Demostración del producto.', '2026-10-01 08:00:00'),
(22, 16, 13, 'correo', 'Correo con información solicitada.', '2026-11-08 08:00:00'),
(23, 17, 20, 'correo', 'Correo con información solicitada.', '2025-12-05 13:00:00'),
(24, 18, 27, 'demo', 'Demostración del producto.', '2026-02-01 12:45:00'),
(25, 18, 27, 'reunion', 'Reunión de revisión de alcance.', '2026-01-26 10:45:00'),
(26, 19, 4, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-02-26 13:15:00'),
(27, 20, 12, 'reunion', 'Reunión de revisión de alcance.', '2026-04-01 08:45:00'),
(28, 21, 19, 'visita', 'Visita a las instalaciones del cliente.', '2026-05-16 13:15:00'),
(29, 21, 19, 'demo', 'Demostración del producto.', '2026-05-07 15:30:00'),
(30, 22, 26, 'demo', 'Demostración del producto.', '2026-06-18 11:15:00'),
(31, 23, 3, 'correo', 'Correo con información solicitada.', '2026-06-15 13:45:00'),
(32, 24, 11, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-08-12 08:15:00'),
(33, 24, 11, 'visita', 'Visita a las instalaciones del cliente.', '2026-08-19 17:15:00'),
(34, 25, 18, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-08-17 14:30:00'),
(35, 26, 25, 'correo', 'Correo con información solicitada.', '2026-09-17 10:15:00'),
(36, 27, 2, 'reunion', 'Reunión de revisión de alcance.', '2026-10-18 12:45:00'),
(37, 27, 2, 'visita', 'Visita a las instalaciones del cliente.', '2026-11-08 16:45:00'),
(38, 28, 10, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-01-23 13:15:00'),
(39, 29, 17, 'correo', 'Correo con información solicitada.', '2026-02-08 09:45:00'),
(40, 30, 24, 'reunion', 'Reunión de revisión de alcance.', '2026-03-02 15:00:00'),
(41, 30, 24, 'demo', 'Demostración del producto.', '2026-03-04 09:15:00'),
(42, 31, 31, 'correo', 'Correo con información solicitada.', '2026-03-25 17:00:00'),
(43, 32, 15, 'visita', 'Visita a las instalaciones del cliente.', '2026-08-25 17:15:00'),
(44, 33, 14, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-04-14 15:45:00'),
(45, 33, 14, 'reunion', 'Reunión de revisión de alcance.', '2026-03-21 12:45:00'),
(46, 34, 20, 'correo', 'Correo con información solicitada.', '2026-03-18 15:00:00'),
(47, 35, 6, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-07-13 14:00:00'),
(48, 36, 13, 'demo', 'Demostración del producto.', '2026-08-22 13:00:00'),
(49, 36, 13, 'correo', 'Correo con información solicitada.', '2026-08-08 10:15:00'),
(50, 37, 20, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-01-16 11:00:00'),
(51, 38, 27, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-02-10 08:00:00'),
(52, 39, 9, 'demo', 'Demostración del producto.', '2026-09-18 13:15:00'),
(53, 39, 9, 'visita', 'Visita a las instalaciones del cliente.', '2026-09-06 15:30:00'),
(54, 40, 16, 'visita', 'Visita a las instalaciones del cliente.', '2026-11-16 11:15:00'),
(55, 41, 23, 'visita', 'Visita a las instalaciones del cliente.', '2026-10-08 09:30:00'),
(56, 42, 30, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-10-08 14:15:00'),
(57, 42, 30, 'visita', 'Visita a las instalaciones del cliente.', '2026-10-21 09:15:00'),
(58, 43, 8, 'visita', 'Visita a las instalaciones del cliente.', '2026-10-25 17:00:00'),
(59, 44, 15, 'correo', 'Correo con información solicitada.', '2026-11-04 15:45:00'),
(60, 45, 22, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-11-12 11:45:00'),
(61, 45, 22, 'visita', 'Visita a las instalaciones del cliente.', '2026-11-17 14:00:00'),
(62, 46, 29, 'visita', 'Visita a las instalaciones del cliente.', '2026-11-17 09:00:00'),
(63, 47, 7, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-11-13 08:00:00'),
(64, 48, 14, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-10-22 10:15:00'),
(65, 48, 14, 'correo', 'Correo con información solicitada.', '2026-10-05 08:00:00'),
(66, 49, 21, 'llamada', 'Llamada de seguimiento con el cliente.', '2026-09-08 15:45:00'),
(67, 50, 28, 'visita', 'Visita a las instalaciones del cliente.', '2026-10-19 11:30:00');

INSERT INTO tareas (id_tarea, id_usuario, id_cliente, id_oportunidad, titulo, descripcion, fecha_limite, estado) VALUES
(1, 2, 1, 1, 'Enviar contrato de migración', 'Preparar contrato con alcance y cronograma.', '2026-11-15 17:00:00', 'completada'),
(2, 2, 2, 2, 'Confirmar número de licencias', 'Validar inventario de buzones del cliente.', '2026-11-20 12:00:00', 'pendiente'),
(3, 3, 4, 3, 'Programar kickoff de implementación', 'Coordinar reunión de inicio con el cliente.', '2026-10-08 10:00:00', 'completada'),
(4, 4, 6, 4, 'Agendar demo de cifrado', 'Demostración del módulo de seguridad al cliente.', '2026-11-25 15:30:00', 'pendiente'),
(5, 1, NULL, NULL, 'Revisar reporte mensual de ventas', 'Consolidar indicadores de octubre.', '2026-11-05 09:00:00', 'completada'),
(6, 5, NULL, NULL, 'Preparar campaña de fin de año', 'Diseñar piezas y segmentar base de clientes.', '2026-11-30 18:00:00', 'en_proceso'),
(7, 9, 34, 39, 'Enviar caso de éxito', 'Tarea de seguimiento comercial.', '2026-12-26 12:00:00', 'pendiente'),
(8, 9, 34, 39, 'Enviar cotización actualizada', 'Tarea de seguimiento comercial.', '2026-10-31 17:45:00', 'cancelada'),
(9, 16, 35, 40, 'Hacer seguimiento a la propuesta', 'Tarea de seguimiento comercial.', '2026-11-27 11:00:00', 'pendiente'),
(10, 16, 35, 40, 'Enviar caso de éxito', 'Tarea de seguimiento comercial.', '2026-12-08 17:00:00', 'en_proceso'),
(11, 23, 36, 41, 'Confirmar decisor de compra', 'Tarea de seguimiento comercial.', '2026-12-16 11:30:00', 'pendiente'),
(12, 23, 36, 41, 'Hacer seguimiento a la propuesta', 'Tarea de seguimiento comercial.', '2026-11-15 09:00:00', 'cancelada'),
(13, 30, 37, 42, 'Agendar demo', 'Tarea de seguimiento comercial.', '2026-12-02 10:30:00', 'en_proceso'),
(14, 30, 37, 42, 'Hacer seguimiento a la propuesta', 'Tarea de seguimiento comercial.', '2026-12-27 14:00:00', 'en_proceso'),
(15, 8, 38, 43, 'Confirmar decisor de compra', 'Tarea de seguimiento comercial.', '2026-12-17 17:30:00', 'en_proceso'),
(16, 8, 38, 43, 'Enviar caso de éxito', 'Tarea de seguimiento comercial.', '2026-11-02 16:30:00', 'cancelada'),
(17, 15, 39, 44, 'Confirmar decisor de compra', 'Tarea de seguimiento comercial.', '2026-12-26 13:00:00', 'pendiente'),
(18, 15, 39, 44, 'Agendar demo', 'Tarea de seguimiento comercial.', '2026-12-16 13:30:00', 'en_proceso'),
(19, 22, 40, 45, 'Hacer seguimiento a la propuesta', 'Tarea de seguimiento comercial.', '2026-11-02 10:15:00', 'completada'),
(20, 22, 40, 45, 'Hacer seguimiento a la propuesta', 'Tarea de seguimiento comercial.', '2026-12-04 15:15:00', 'en_proceso'),
(21, 29, 41, 46, 'Confirmar decisor de compra', 'Tarea de seguimiento comercial.', '2026-11-06 13:15:00', 'cancelada'),
(22, 29, 41, 46, 'Enviar cotización actualizada', 'Tarea de seguimiento comercial.', '2026-12-04 08:00:00', 'pendiente'),
(23, 7, 42, 47, 'Agendar demo', 'Tarea de seguimiento comercial.', '2026-12-13 09:45:00', 'en_proceso'),
(24, 7, 42, 47, 'Preparar propuesta técnica', 'Tarea de seguimiento comercial.', '2026-11-03 14:30:00', 'completada'),
(25, 14, 43, 48, 'Llamar al prospecto', 'Tarea de seguimiento comercial.', '2026-11-28 17:30:00', 'pendiente'),
(26, 14, 43, 48, 'Enviar caso de éxito', 'Tarea de seguimiento comercial.', '2026-12-09 11:45:00', 'en_proceso'),
(27, 21, 44, 49, 'Preparar propuesta técnica', 'Tarea de seguimiento comercial.', '2026-12-09 17:30:00', 'en_proceso'),
(28, 21, 44, 49, 'Preparar propuesta técnica', 'Tarea de seguimiento comercial.', '2026-11-27 09:45:00', 'pendiente'),
(29, 28, 45, 50, 'Enviar caso de éxito', 'Tarea de seguimiento comercial.', '2026-12-10 17:00:00', 'en_proceso'),
(30, 28, 45, 50, 'Enviar caso de éxito', 'Tarea de seguimiento comercial.', '2026-11-26 09:45:00', 'pendiente'),
(31, 3, 3, NULL, 'Contactar al prospecto', 'Primer contacto para calificar interés.', '2026-11-27 09:30:00', 'pendiente'),
(32, 4, 5, NULL, 'Contactar al prospecto', 'Primer contacto para calificar interés.', '2026-12-12 08:45:00', 'pendiente'),
(33, 4, 7, NULL, 'Contactar al prospecto', 'Primer contacto para calificar interés.', '2026-11-11 14:45:00', 'completada'),
(34, 6, 46, NULL, 'Contactar al prospecto', 'Primer contacto para calificar interés.', '2026-11-14 16:45:00', 'completada'),
(35, 4, 50, NULL, 'Contactar al prospecto', 'Primer contacto para calificar interés.', '2026-11-17 08:15:00', 'completada'),
(36, 12, 51, NULL, 'Contactar al prospecto', 'Primer contacto para calificar interés.', '2026-12-13 13:00:00', 'pendiente'),
(37, 19, 52, NULL, 'Contactar al prospecto', 'Primer contacto para calificar interés.', '2026-12-07 14:30:00', 'pendiente'),
(38, 26, 53, NULL, 'Contactar al prospecto', 'Primer contacto para calificar interés.', '2026-11-17 16:45:00', 'completada'),
(39, 3, 54, NULL, 'Contactar al prospecto', 'Primer contacto para calificar interés.', '2026-11-21 08:30:00', 'pendiente'),
(40, 11, 55, NULL, 'Contactar al prospecto', 'Primer contacto para calificar interés.', '2026-11-25 10:15:00', 'pendiente');

-- ------------------------------------------------------------
-- 7. Propuestas comerciales
-- ------------------------------------------------------------
INSERT INTO propuestas (id_propuesta, id_oportunidad, fecha, valor_total, estado, observaciones) VALUES
(1, 1, '2026-10-10', 21550000.00, 'aceptada', 'Incluye migración y capacitación para 250 usuarios.'),
(2, 2, '2026-10-18', 13200000.00, 'enviada', 'Descuento del 8% por renovación anticipada.'),
(3, 3, '2026-09-25', 58300000.00, 'aceptada', 'Aprobada por el comité directivo del cliente.'),
(4, 5, '2026-09-10', 8700000.00, 'rechazada', 'El cliente decidió no renovar con nosotros.'),
(5, 6, '2025-12-30', 8352000.00, 'aceptada', 'Precio sostenido por 12 meses.'),
(6, 7, '2026-02-02', 54420000.00, 'aceptada', 'Aprobada por gerencia.'),
(7, 8, '2026-02-27', 31030000.00, 'aceptada', 'Incluye capacitación inicial.'),
(8, 9, '2026-04-21', 14370000.00, 'aceptada', 'Incluye capacitación inicial.'),
(9, 10, '2026-05-16', 16360000.00, 'aceptada', 'Precio sostenido por 12 meses.'),
(10, 11, '2026-06-05', 14530000.00, 'aceptada', 'Incluye capacitación inicial.'),
(11, 12, '2026-07-07', 22828000.00, 'aceptada', 'Incluye capacitación inicial.'),
(12, 13, '2026-07-30', 21470000.00, 'aceptada', 'Aprobada por gerencia.'),
(13, 14, '2026-08-31', 18100000.00, 'aceptada', 'Incluye capacitación inicial.'),
(14, 15, '2026-10-07', 4092000.00, 'aceptada', 'Incluye capacitación inicial.'),
(15, 16, '2026-11-02', 21195000.00, 'aceptada', 'Incluye capacitación inicial.'),
(16, 17, '2025-12-28', 18855000.00, 'aceptada', 'Precio sostenido por 12 meses.'),
(17, 18, '2026-02-07', 31047000.00, 'aceptada', 'Aprobada por gerencia.'),
(18, 19, '2026-03-11', 32280000.00, 'aceptada', 'Precio sostenido por 12 meses.'),
(19, 20, '2026-03-29', 45880000.00, 'aceptada', 'Aprobada por gerencia.'),
(20, 21, '2026-05-07', 15274000.00, 'aceptada', 'Precio sostenido por 12 meses.'),
(21, 22, '2026-06-14', 30720000.00, 'aceptada', 'Incluye capacitación inicial.'),
(22, 23, '2026-06-27', 30130000.00, 'aceptada', 'Precio sostenido por 12 meses.'),
(23, 24, '2026-08-16', 33240000.00, 'aceptada', 'Aceptada tras ajuste de alcance.'),
(24, 25, '2026-08-30', 40507000.00, 'aceptada', 'Incluye capacitación inicial.'),
(25, 26, '2026-10-01', 21120000.00, 'aceptada', 'Aprobada por gerencia.'),
(26, 27, '2026-11-06', 20515000.00, 'aceptada', 'Aprobada por gerencia.'),
(27, 28, '2026-01-20', 6690000.00, 'aceptada', 'Precio sostenido por 12 meses.'),
(28, 29, '2026-02-09', 41325000.00, 'aceptada', 'Incluye capacitación inicial.'),
(29, 30, '2026-03-15', 52100000.00, 'aceptada', 'Aceptada tras ajuste de alcance.'),
(30, 31, '2026-03-27', 31320000.00, 'aceptada', 'Aceptada tras ajuste de alcance.'),
(31, 32, '2026-08-22', 24965000.00, 'rechazada', 'Rechazada por el cliente.'),
(32, 33, '2026-04-14', 9180000.00, 'rechazada', 'Rechazada por el cliente.'),
(33, 34, '2026-03-15', 2700000.00, 'rechazada', 'Rechazada por el cliente.'),
(34, 35, '2026-07-07', 4815000.00, 'rechazada', 'Rechazada por el cliente.'),
(35, 36, '2026-08-12', 13600000.00, 'rechazada', 'Rechazada por el cliente.'),
(36, 37, '2026-01-19', 15375000.00, 'rechazada', 'Rechazada por el cliente.'),
(37, 38, '2026-02-21', 6525000.00, 'rechazada', 'Rechazada por el cliente.'),
(38, 40, '2026-09-28', 17280000.00, 'borrador', 'En preparación.'),
(39, 41, '2026-09-06', 5459000.00, 'enviada', 'Enviada, pendiente de respuesta.'),
(40, 42, '2026-09-20', 6636000.00, 'enviada', 'Enviada, pendiente de respuesta.'),
(41, 44, '2026-11-05', 28450000.00, 'borrador', 'En preparación.'),
(42, 45, '2026-10-18', 6490000.00, 'enviada', 'Enviada, pendiente de respuesta.'),
(43, 46, '2026-11-16', 18440000.00, 'enviada', 'Enviada, pendiente de respuesta.'),
(44, 48, '2026-09-09', 11770000.00, 'borrador', 'En preparación.'),
(45, 49, '2026-09-04', 43860000.00, 'enviada', 'Enviada, pendiente de respuesta.'),
(46, 50, '2026-10-01', 26680000.00, 'enviada', 'Enviada, pendiente de respuesta.');

INSERT INTO propuestas_detalles (id_detalle, id_propuesta, id_producto, cantidad, precio_unitario, subtotal) VALUES
(1, 1, 2, 250, 85000.00, 21250000.00),
(2, 1, 6, 1, 300000.00, 300000.00),
(3, 2, 2, 120, 85000.00, 10200000.00),
(4, 2, 4, 120, 25000.00, 3000000.00),
(5, 3, 3, 400, 145000.00, 58000000.00),
(6, 3, 6, 1, 300000.00, 300000.00),
(7, 4, 5, 60, 120000.00, 7200000.00),
(8, 4, 4, 60, 25000.00, 1500000.00),
(9, 5, 26, 246, 12000.00, 2952000.00),
(10, 5, 10, 3, 1800000.00, 5400000.00),
(11, 6, 3, 301, 145000.00, 43645000.00),
(12, 6, 4, 301, 25000.00, 7525000.00),
(13, 6, 20, 13, 250000.00, 3250000.00),
(14, 7, 3, 214, 145000.00, 31030000.00),
(15, 8, 1, 226, 45000.00, 10170000.00),
(16, 8, 24, 1, 4200000.00, 4200000.00),
(17, 9, 26, 655, 12000.00, 7860000.00),
(18, 9, 21, 1, 8500000.00, 8500000.00),
(19, 10, 5, 74, 120000.00, 8880000.00),
(20, 10, 4, 74, 25000.00, 1850000.00),
(21, 10, 28, 1, 3800000.00, 3800000.00),
(22, 11, 26, 439, 12000.00, 5268000.00),
(23, 11, 8, 439, 40000.00, 17560000.00),
(24, 12, 27, 226, 95000.00, 21470000.00),
(25, 13, 3, 78, 145000.00, 11310000.00),
(26, 13, 12, 78, 55000.00, 4290000.00),
(27, 13, 23, 1, 2500000.00, 2500000.00),
(28, 14, 26, 316, 12000.00, 3792000.00),
(29, 14, 6, 1, 300000.00, 300000.00),
(30, 15, 1, 281, 45000.00, 12645000.00),
(31, 15, 20, 19, 250000.00, 4750000.00),
(32, 15, 28, 1, 3800000.00, 3800000.00),
(33, 16, 1, 179, 45000.00, 8055000.00),
(34, 16, 29, 12, 900000.00, 10800000.00),
(35, 17, 2, 249, 85000.00, 21165000.00),
(36, 17, 18, 249, 18000.00, 4482000.00),
(37, 17, 10, 3, 1800000.00, 5400000.00),
(38, 18, 27, 269, 95000.00, 25555000.00),
(39, 18, 16, 269, 25000.00, 6725000.00),
(40, 19, 5, 310, 120000.00, 37200000.00),
(41, 19, 30, 310, 28000.00, 8680000.00),
(42, 20, 27, 98, 95000.00, 9310000.00),
(43, 20, 18, 98, 18000.00, 1764000.00),
(44, 20, 24, 1, 4200000.00, 4200000.00),
(45, 21, 27, 256, 95000.00, 24320000.00),
(46, 21, 16, 256, 25000.00, 6400000.00),
(47, 22, 2, 262, 85000.00, 22270000.00),
(48, 22, 17, 262, 30000.00, 7860000.00),
(49, 23, 5, 277, 120000.00, 33240000.00),
(50, 24, 27, 309, 95000.00, 29355000.00),
(51, 24, 30, 309, 28000.00, 8652000.00),
(52, 24, 23, 1, 2500000.00, 2500000.00),
(53, 25, 5, 176, 120000.00, 21120000.00),
(54, 26, 27, 197, 95000.00, 18715000.00),
(55, 26, 9, 4, 450000.00, 1800000.00),
(56, 27, 5, 52, 120000.00, 6240000.00),
(57, 27, 9, 1, 450000.00, 450000.00),
(58, 28, 3, 285, 145000.00, 41325000.00),
(59, 29, 5, 320, 120000.00, 38400000.00),
(60, 29, 8, 320, 40000.00, 12800000.00),
(61, 29, 9, 2, 450000.00, 900000.00),
(62, 30, 5, 261, 120000.00, 31320000.00),
(63, 31, 1, 209, 45000.00, 9405000.00),
(64, 31, 8, 209, 40000.00, 8360000.00),
(65, 31, 29, 8, 900000.00, 7200000.00),
(66, 32, 2, 108, 85000.00, 9180000.00),
(67, 33, 1, 60, 45000.00, 2700000.00),
(68, 34, 1, 107, 45000.00, 4815000.00),
(69, 35, 2, 160, 85000.00, 13600000.00),
(70, 36, 27, 75, 95000.00, 7125000.00),
(71, 36, 17, 75, 30000.00, 2250000.00),
(72, 36, 20, 24, 250000.00, 6000000.00),
(73, 37, 3, 45, 145000.00, 6525000.00),
(74, 38, 5, 144, 120000.00, 17280000.00),
(75, 39, 2, 53, 85000.00, 4505000.00),
(76, 39, 18, 53, 18000.00, 954000.00),
(77, 40, 26, 553, 12000.00, 6636000.00),
(78, 41, 3, 145, 145000.00, 21025000.00),
(79, 41, 4, 145, 25000.00, 3625000.00),
(80, 41, 28, 1, 3800000.00, 3800000.00),
(81, 42, 27, 42, 95000.00, 3990000.00),
(82, 42, 23, 1, 2500000.00, 2500000.00),
(83, 43, 2, 200, 85000.00, 17000000.00),
(84, 43, 25, 12, 120000.00, 1440000.00),
(85, 44, 2, 110, 85000.00, 9350000.00),
(86, 44, 19, 110, 22000.00, 2420000.00),
(87, 45, 2, 258, 85000.00, 21930000.00),
(88, 45, 16, 258, 25000.00, 6450000.00),
(89, 45, 15, 258, 60000.00, 15480000.00),
(90, 46, 2, 208, 85000.00, 17680000.00),
(91, 46, 29, 10, 900000.00, 9000000.00);

-- ------------------------------------------------------------
-- 8. Ventas y pagos
-- ------------------------------------------------------------
INSERT INTO ventas (id_venta, id_cliente, id_vendedor, id_propuesta, fecha, total, estado) VALUES
(1, 4, 2, 3, '2026-10-05 12:30:00', 58300000.00, 'pagada'),
(2, 1, 1, 1, '2026-10-12 09:45:00', 21550000.00, 'pendiente'),
(3, 2, 1, NULL, '2026-10-22 15:10:00', 4400000.00, 'pagada'),
(4, 6, 3, NULL, '2026-10-28 11:05:00', 1400000.00, 'pendiente'),
(5, 8, 2, 5, '2026-01-06 17:15:00', 8352000.00, 'pagada'),
(6, 9, 6, 6, '2026-02-11 16:45:00', 54420000.00, 'pagada'),
(7, 10, 13, 7, '2026-03-08 11:00:00', 31030000.00, 'pagada'),
(8, 11, 20, 8, '2026-04-25 12:15:00', 14370000.00, 'pagada'),
(9, 12, 27, 9, '2026-05-24 09:15:00', 16360000.00, 'pendiente'),
(10, 13, 5, 10, '2026-06-13 13:15:00', 14530000.00, 'pagada'),
(11, 14, 12, 11, '2026-07-15 12:00:00', 22828000.00, 'pagada'),
(12, 15, 19, 12, '2026-08-03 17:45:00', 21470000.00, 'pagada'),
(13, 16, 26, 13, '2026-09-07 17:30:00', 18100000.00, 'pagada'),
(14, 17, 4, 14, '2026-10-12 14:30:00', 4092000.00, 'pendiente'),
(15, 18, 11, 15, '2026-11-11 14:45:00', 21195000.00, 'pendiente'),
(16, 19, 18, 16, '2026-01-02 08:30:00', 18855000.00, 'pagada'),
(17, 20, 25, 17, '2026-02-15 16:30:00', 31047000.00, 'pagada'),
(18, 21, 3, 18, '2026-03-23 16:45:00', 32280000.00, 'pendiente'),
(19, 22, 10, 19, '2026-04-04 08:30:00', 45880000.00, 'pagada'),
(20, 23, 17, 20, '2026-05-18 13:45:00', 15274000.00, 'pagada'),
(21, 24, 24, 21, '2026-06-20 15:00:00', 30720000.00, 'pagada'),
(22, 25, 2, 22, '2026-07-07 11:30:00', 30130000.00, 'pagada'),
(23, 26, 9, 23, '2026-08-24 10:00:00', 33240000.00, 'pagada'),
(24, 27, 16, 24, '2026-09-09 14:15:00', 40507000.00, 'pagada'),
(25, 28, 23, 25, '2026-10-07 14:45:00', 21120000.00, 'pendiente'),
(26, 29, 1, 26, '2026-11-09 08:30:00', 20515000.00, 'pendiente'),
(27, 30, 8, 27, '2026-01-27 13:45:00', 6690000.00, 'pendiente'),
(28, 31, 15, 28, '2026-02-18 11:45:00', 41325000.00, 'pagada'),
(29, 32, 22, 29, '2026-03-26 10:45:00', 52100000.00, 'pagada'),
(30, 33, 29, 30, '2026-04-05 10:30:00', 31320000.00, 'pagada'),
(31, 11, 20, NULL, '2026-03-13 17:45:00', 2115000.00, 'pagada'),
(32, 15, 19, NULL, '2026-05-13 15:45:00', 420000.00, 'pagada'),
(33, 20, 25, NULL, '2026-07-21 09:45:00', 1060000.00, 'cancelada'),
(34, 25, 2, NULL, '2026-09-12 13:30:00', 585000.00, 'pagada'),
(35, 30, 8, NULL, '2026-10-13 14:45:00', 1700000.00, 'cancelada');

INSERT INTO ventas_productos (id_detalle, id_venta, id_producto, cantidad, precio_unitario, subtotal) VALUES
(1, 1, 3, 400, 145000.00, 58000000.00),
(2, 1, 6, 1, 300000.00, 300000.00),
(3, 2, 2, 250, 85000.00, 21250000.00),
(4, 2, 6, 1, 300000.00, 300000.00),
(5, 3, 2, 40, 85000.00, 3400000.00),
(6, 3, 4, 40, 25000.00, 1000000.00),
(7, 4, 1, 20, 45000.00, 900000.00),
(8, 4, 4, 20, 25000.00, 500000.00),
(9, 5, 26, 246, 12000.00, 2952000.00),
(10, 5, 10, 3, 1800000.00, 5400000.00),
(11, 6, 3, 301, 145000.00, 43645000.00),
(12, 6, 4, 301, 25000.00, 7525000.00),
(13, 6, 20, 13, 250000.00, 3250000.00),
(14, 7, 3, 214, 145000.00, 31030000.00),
(15, 8, 1, 226, 45000.00, 10170000.00),
(16, 8, 24, 1, 4200000.00, 4200000.00),
(17, 9, 26, 655, 12000.00, 7860000.00),
(18, 9, 21, 1, 8500000.00, 8500000.00),
(19, 10, 5, 74, 120000.00, 8880000.00),
(20, 10, 4, 74, 25000.00, 1850000.00),
(21, 10, 28, 1, 3800000.00, 3800000.00),
(22, 11, 26, 439, 12000.00, 5268000.00),
(23, 11, 8, 439, 40000.00, 17560000.00),
(24, 12, 27, 226, 95000.00, 21470000.00),
(25, 13, 3, 78, 145000.00, 11310000.00),
(26, 13, 12, 78, 55000.00, 4290000.00),
(27, 13, 23, 1, 2500000.00, 2500000.00),
(28, 14, 26, 316, 12000.00, 3792000.00),
(29, 14, 6, 1, 300000.00, 300000.00),
(30, 15, 1, 281, 45000.00, 12645000.00),
(31, 15, 20, 19, 250000.00, 4750000.00),
(32, 15, 28, 1, 3800000.00, 3800000.00),
(33, 16, 1, 179, 45000.00, 8055000.00),
(34, 16, 29, 12, 900000.00, 10800000.00),
(35, 17, 2, 249, 85000.00, 21165000.00),
(36, 17, 18, 249, 18000.00, 4482000.00),
(37, 17, 10, 3, 1800000.00, 5400000.00),
(38, 18, 27, 269, 95000.00, 25555000.00),
(39, 18, 16, 269, 25000.00, 6725000.00),
(40, 19, 5, 310, 120000.00, 37200000.00),
(41, 19, 30, 310, 28000.00, 8680000.00),
(42, 20, 27, 98, 95000.00, 9310000.00),
(43, 20, 18, 98, 18000.00, 1764000.00),
(44, 20, 24, 1, 4200000.00, 4200000.00),
(45, 21, 27, 256, 95000.00, 24320000.00),
(46, 21, 16, 256, 25000.00, 6400000.00),
(47, 22, 2, 262, 85000.00, 22270000.00),
(48, 22, 17, 262, 30000.00, 7860000.00),
(49, 23, 5, 277, 120000.00, 33240000.00),
(50, 24, 27, 309, 95000.00, 29355000.00),
(51, 24, 30, 309, 28000.00, 8652000.00),
(52, 24, 23, 1, 2500000.00, 2500000.00),
(53, 25, 5, 176, 120000.00, 21120000.00),
(54, 26, 27, 197, 95000.00, 18715000.00),
(55, 26, 9, 4, 450000.00, 1800000.00),
(56, 27, 5, 52, 120000.00, 6240000.00),
(57, 27, 9, 1, 450000.00, 450000.00),
(58, 28, 3, 285, 145000.00, 41325000.00),
(59, 29, 5, 320, 120000.00, 38400000.00),
(60, 29, 8, 320, 40000.00, 12800000.00),
(61, 29, 9, 2, 450000.00, 900000.00),
(62, 30, 5, 261, 120000.00, 31320000.00),
(63, 31, 1, 31, 45000.00, 1395000.00),
(64, 31, 25, 6, 120000.00, 720000.00),
(65, 32, 13, 21, 20000.00, 420000.00),
(66, 33, 4, 28, 25000.00, 700000.00),
(67, 33, 25, 3, 120000.00, 360000.00),
(68, 34, 1, 13, 45000.00, 585000.00),
(69, 35, 2, 20, 85000.00, 1700000.00);

INSERT INTO pagos (id_pago, id_venta, metodo_pago, valor, fecha, estado) VALUES
(1, 1, 'transferencia', 29150000.00, '2026-10-06 10:00:00', 'aprobado'),
(2, 1, 'transferencia', 29150000.00, '2026-10-20 10:00:00', 'aprobado'),
(3, 2, 'tarjeta', 5000000.00, '2026-10-13 09:30:00', 'aprobado'),
(4, 3, 'pse', 4400000.00, '2026-10-22 16:00:00', 'aprobado'),
(5, 4, 'efectivo', 1400000.00, '2026-10-29 11:00:00', 'pendiente'),
(6, 5, 'transferencia', 4176000.00, '2026-01-10 17:15:00', 'aprobado'),
(7, 5, 'transferencia', 4176000.00, '2026-01-24 17:15:00', 'aprobado'),
(8, 6, 'efectivo', 27210000.00, '2026-02-13 16:45:00', 'aprobado'),
(9, 6, 'efectivo', 27210000.00, '2026-03-03 16:45:00', 'aprobado'),
(10, 6, 'tarjeta', 54420000.00, '2026-02-11 16:45:00', 'rechazado'),
(11, 7, 'pse', 15515000.00, '2026-03-13 11:00:00', 'aprobado'),
(12, 7, 'pse', 15515000.00, '2026-03-30 11:00:00', 'aprobado'),
(13, 8, 'transferencia', 14370000.00, '2026-05-01 12:15:00', 'aprobado'),
(14, 10, 'tarjeta', 14530000.00, '2026-06-17 13:15:00', 'aprobado'),
(15, 11, 'tarjeta', 11414000.00, '2026-07-17 12:00:00', 'aprobado'),
(16, 11, 'tarjeta', 11414000.00, '2026-08-07 12:00:00', 'aprobado'),
(17, 12, 'transferencia', 10735000.00, '2026-08-04 17:45:00', 'aprobado'),
(18, 12, 'transferencia', 10735000.00, '2026-08-28 17:45:00', 'aprobado'),
(19, 12, 'tarjeta', 21470000.00, '2026-08-03 17:45:00', 'rechazado'),
(20, 13, 'tarjeta', 18100000.00, '2026-09-12 17:30:00', 'aprobado'),
(21, 14, 'tarjeta', 1636800.00, '2026-10-15 14:30:00', 'aprobado'),
(22, 16, 'efectivo', 9427500.00, '2026-01-04 08:30:00', 'aprobado'),
(23, 16, 'efectivo', 9427500.00, '2026-01-21 08:30:00', 'aprobado'),
(24, 17, 'pse', 15523500.00, '2026-02-20 16:30:00', 'aprobado'),
(25, 17, 'pse', 15523500.00, '2026-03-10 16:30:00', 'aprobado'),
(26, 19, 'pse', 22940000.00, '2026-04-09 08:30:00', 'aprobado'),
(27, 19, 'pse', 22940000.00, '2026-04-25 08:30:00', 'aprobado'),
(28, 20, 'efectivo', 7637000.00, '2026-05-23 13:45:00', 'aprobado'),
(29, 20, 'efectivo', 7637000.00, '2026-06-12 13:45:00', 'aprobado'),
(30, 21, 'pse', 15360000.00, '2026-06-24 15:00:00', 'aprobado'),
(31, 21, 'pse', 15360000.00, '2026-07-14 15:00:00', 'aprobado'),
(32, 22, 'efectivo', 15065000.00, '2026-07-10 11:30:00', 'aprobado'),
(33, 22, 'efectivo', 15065000.00, '2026-07-27 11:30:00', 'aprobado'),
(34, 23, 'transferencia', 16620000.00, '2026-08-25 10:00:00', 'aprobado'),
(35, 23, 'transferencia', 16620000.00, '2026-09-18 10:00:00', 'aprobado'),
(36, 24, 'tarjeta', 20253500.00, '2026-09-12 14:15:00', 'aprobado'),
(37, 24, 'tarjeta', 20253500.00, '2026-10-08 14:15:00', 'aprobado'),
(38, 24, 'tarjeta', 40507000.00, '2026-09-09 14:15:00', 'rechazado'),
(39, 25, 'transferencia', 8448000.00, '2026-10-08 14:45:00', 'aprobado'),
(40, 26, 'tarjeta', 8206000.00, '2026-11-11 08:30:00', 'aprobado'),
(41, 28, 'pse', 20662500.00, '2026-02-20 11:45:00', 'aprobado'),
(42, 28, 'pse', 20662500.00, '2026-03-12 11:45:00', 'aprobado'),
(43, 29, 'pse', 26050000.00, '2026-03-28 10:45:00', 'aprobado'),
(44, 29, 'pse', 26050000.00, '2026-04-10 10:45:00', 'aprobado'),
(45, 30, 'tarjeta', 15660000.00, '2026-04-10 10:30:00', 'aprobado'),
(46, 30, 'tarjeta', 15660000.00, '2026-05-01 10:30:00', 'aprobado'),
(47, 30, 'tarjeta', 31320000.00, '2026-04-05 10:30:00', 'rechazado'),
(48, 31, 'transferencia', 1057500.00, '2026-03-15 17:45:00', 'aprobado'),
(49, 31, 'transferencia', 1057500.00, '2026-03-29 17:45:00', 'aprobado'),
(50, 32, 'transferencia', 210000.00, '2026-05-16 15:45:00', 'aprobado'),
(51, 32, 'transferencia', 210000.00, '2026-06-11 15:45:00', 'aprobado'),
(52, 34, 'efectivo', 585000.00, '2026-09-14 13:30:00', 'aprobado');

-- ------------------------------------------------------------
-- 5. Campañas de marketing
-- ------------------------------------------------------------
INSERT INTO campanas_marketing (id_campana, nombre, descripcion, fecha_inicio, fecha_fin, presupuesto, estado) VALUES
(1, 'Lanzamiento Zimbra 2026', 'Campaña de posicionamiento de la nueva suite.', '2026-10-01', '2026-12-31', 5000000.00, 'activa'),
(2, 'Webinar colaboración empresarial', 'Webinar sobre productividad y correo corporativo.', '2026-08-01', '2026-09-15', 2500000.00, 'finalizada'),
(3, 'Campaña fin de año', 'Ofertas de renovación para clientes existentes.', '2026-11-15', '2026-12-31', 3500000.00, 'activa'),
(4, 'Campaña sector educación - marzo 2026', 'Campaña de marketing: campaña sector educación.', '2026-03-28', '2026-04-29', 6800000.00, 'finalizada'),
(5, 'Prueba gratuita 60 días - noviembre 2025', 'Campaña de marketing: prueba gratuita 60 días.', '2025-11-08', '2026-01-16', 3700000.00, 'finalizada'),
(6, 'Caso de éxito migración - enero 2026', 'Campaña de marketing: caso de éxito migración.', '2026-01-13', '2026-03-04', 6100000.00, 'finalizada'),
(7, 'Promoción pymes - octubre 2026', 'Campaña de marketing: promoción pymes.', '2026-10-04', '2026-12-17', 6100000.00, 'activa'),
(8, 'Evento de clientes VIP - febrero 2026', 'Campaña de marketing: evento de clientes vip.', '2026-02-28', '2026-05-05', 7800000.00, 'finalizada'),
(9, 'Remarketing en redes - diciembre 2025', 'Campaña de marketing: remarketing en redes.', '2025-12-22', '2026-02-02', 4600000.00, 'finalizada'),
(10, 'Encuesta de satisfacción - diciembre 2025', 'Campaña de marketing: encuesta de satisfacción.', '2025-12-15', '2026-01-18', 1600000.00, 'finalizada'),
(11, 'Lanzamiento Zimbra Connect - mayo 2026', 'Campaña de marketing: lanzamiento zimbra connect.', '2026-05-26', '2026-07-15', 2500000.00, 'finalizada'),
(12, 'Semana de la ciberseguridad - abril 2026', 'Campaña de marketing: semana de la ciberseguridad.', '2026-04-24', '2026-06-04', 4400000.00, 'cancelada'),
(13, 'Campaña sector público - enero 2026', 'Campaña de marketing: campaña sector público.', '2026-01-31', '2026-02-18', 3100000.00, 'finalizada'),
(14, 'Desayuno ejecutivo - agosto 2026', 'Campaña de marketing: desayuno ejecutivo.', '2026-08-22', '2026-10-13', 5100000.00, 'finalizada'),
(15, 'Webinar seguridad del correo - octubre 2026', 'Campaña de marketing: webinar seguridad del correo.', '2026-10-21', '2026-12-19', 2200000.00, 'activa'),
(16, 'Newsletter mensual - octubre 2025', 'Campaña de marketing: newsletter mensual.', '2025-10-24', '2026-01-07', 6100000.00, 'finalizada'),
(17, 'Feria tecnológica - febrero 2026', 'Campaña de marketing: feria tecnológica.', '2026-02-21', '2026-03-20', 1900000.00, 'finalizada'),
(18, 'Campaña sector salud - junio 2026', 'Campaña de marketing: campaña sector salud.', '2026-06-10', '2026-06-24', 6500000.00, 'finalizada'),
(19, 'Campaña sector educación - diciembre 2025', 'Campaña de marketing: campaña sector educación.', '2025-12-03', '2026-02-07', 8500000.00, 'finalizada'),
(20, 'Prueba gratuita 60 días - junio 2026', 'Campaña de marketing: prueba gratuita 60 días.', '2026-06-03', '2026-07-22', 5800000.00, 'finalizada'),
(21, 'Caso de éxito migración - septiembre 2026', 'Campaña de marketing: caso de éxito migración.', '2026-09-24', '2026-11-15', 7400000.00, 'finalizada'),
(22, 'Promoción pymes - julio 2025', 'Campaña de marketing: promoción pymes.', '2025-07-12', '2025-09-15', 4600000.00, 'finalizada'),
(23, 'Evento de clientes VIP - julio 2026', 'Campaña de marketing: evento de clientes vip.', '2026-07-08', '2026-08-04', 8900000.00, 'finalizada'),
(24, 'Remarketing en redes - agosto 2025', 'Campaña de marketing: remarketing en redes.', '2025-08-18', '2025-10-22', 7500000.00, 'finalizada'),
(25, 'Encuesta de satisfacción - agosto 2025', 'Campaña de marketing: encuesta de satisfacción.', '2025-08-08', '2025-09-15', 8000000.00, 'cancelada'),
(26, 'Lanzamiento Zimbra Connect - octubre 2026', 'Campaña de marketing: lanzamiento zimbra connect.', '2026-10-31', '2026-12-03', 8000000.00, 'activa'),
(27, 'Semana de la ciberseguridad - marzo 2026', 'Campaña de marketing: semana de la ciberseguridad.', '2026-03-08', '2026-04-22', 3900000.00, 'finalizada'),
(28, 'Campaña sector público - marzo 2026', 'Campaña de marketing: campaña sector público.', '2026-03-31', '2026-06-04', 8700000.00, 'finalizada'),
(29, 'Desayuno ejecutivo - mayo 2026', 'Campaña de marketing: desayuno ejecutivo.', '2026-05-11', '2026-07-11', 3700000.00, 'finalizada'),
(30, 'Webinar seguridad del correo - agosto 2026', 'Campaña de marketing: webinar seguridad del correo.', '2026-08-18', '2026-09-14', 2900000.00, 'finalizada');

INSERT INTO campanas_clientes (id_campana, id_cliente, fecha_asignacion) VALUES
(1, 1, '2026-10-01 08:00:00'),
(1, 3, '2026-10-01 08:00:00'),
(1, 7, '2026-10-02 09:30:00'),
(2, 2, '2026-08-01 10:00:00'),
(2, 5, '2026-08-01 10:00:00'),
(3, 4, '2026-11-15 08:00:00'),
(3, 6, '2026-11-15 08:00:00'),
(3, 8, '2026-11-15 08:00:00'),
(4, 48, '2026-03-28 08:00:00'),
(4, 16, '2026-03-28 08:00:00'),
(5, 22, '2025-11-08 08:00:00'),
(5, 25, '2025-11-08 08:00:00'),
(5, 26, '2025-11-08 08:00:00'),
(5, 41, '2025-11-08 08:00:00'),
(6, 44, '2026-01-13 08:00:00'),
(6, 50, '2026-01-13 08:00:00'),
(6, 25, '2026-01-13 08:00:00'),
(7, 37, '2026-10-04 08:00:00'),
(7, 43, '2026-10-04 08:00:00'),
(7, 47, '2026-10-04 08:00:00'),
(8, 45, '2026-02-28 08:00:00'),
(8, 39, '2026-02-28 08:00:00'),
(8, 21, '2026-02-28 08:00:00'),
(9, 44, '2025-12-22 08:00:00'),
(9, 3, '2025-12-22 08:00:00'),
(9, 15, '2025-12-22 08:00:00'),
(10, 46, '2025-12-15 08:00:00'),
(10, 21, '2025-12-15 08:00:00'),
(11, 26, '2026-05-26 08:00:00'),
(11, 16, '2026-05-26 08:00:00'),
(11, 45, '2026-05-26 08:00:00'),
(13, 12, '2026-01-31 08:00:00'),
(13, 42, '2026-01-31 08:00:00'),
(13, 40, '2026-01-31 08:00:00'),
(13, 10, '2026-01-31 08:00:00'),
(14, 38, '2026-08-22 08:00:00'),
(14, 19, '2026-08-22 08:00:00'),
(15, 15, '2026-10-21 08:00:00'),
(15, 41, '2026-10-21 08:00:00'),
(15, 40, '2026-10-21 08:00:00'),
(15, 7, '2026-10-21 08:00:00'),
(16, 38, '2025-10-24 08:00:00'),
(16, 19, '2025-10-24 08:00:00'),
(17, 52, '2026-02-21 08:00:00'),
(17, 31, '2026-02-21 08:00:00'),
(18, 33, '2026-06-10 08:00:00'),
(18, 11, '2026-06-10 08:00:00'),
(19, 21, '2025-12-03 08:00:00'),
(19, 7, '2025-12-03 08:00:00'),
(20, 46, '2026-06-03 08:00:00'),
(20, 6, '2026-06-03 08:00:00'),
(21, 20, '2026-09-24 08:00:00'),
(21, 37, '2026-09-24 08:00:00'),
(21, 46, '2026-09-24 08:00:00'),
(22, 1, '2025-07-12 08:00:00'),
(22, 30, '2025-07-12 08:00:00'),
(22, 26, '2025-07-12 08:00:00'),
(22, 50, '2025-07-12 08:00:00'),
(23, 13, '2026-07-08 08:00:00'),
(23, 45, '2026-07-08 08:00:00'),
(24, 15, '2025-08-18 08:00:00'),
(24, 51, '2025-08-18 08:00:00'),
(26, 54, '2026-10-31 08:00:00'),
(26, 33, '2026-10-31 08:00:00'),
(26, 24, '2026-10-31 08:00:00'),
(27, 49, '2026-03-08 08:00:00'),
(27, 5, '2026-03-08 08:00:00'),
(27, 42, '2026-03-08 08:00:00'),
(28, 39, '2026-03-31 08:00:00'),
(28, 47, '2026-03-31 08:00:00'),
(28, 55, '2026-03-31 08:00:00'),
(28, 30, '2026-03-31 08:00:00'),
(29, 14, '2026-05-11 08:00:00'),
(29, 26, '2026-05-11 08:00:00'),
(29, 16, '2026-05-11 08:00:00'),
(30, 4, '2026-08-18 08:00:00'),
(30, 47, '2026-08-18 08:00:00');

INSERT INTO campanas_interacciones (id_interaccion, id_campana, id_cliente, tipo, resultado, fecha) VALUES
(1, 1, 1, 'correo', 'Abrió el correo y solicitó información.', '2026-10-03 09:12:00'),
(2, 1, 3, 'correo', 'Sin respuesta después de dos envíos.', '2026-10-10 14:25:00'),
(3, 1, 7, 'formulario', 'Registró sus datos para una demo.', '2026-10-05 18:40:00'),
(4, 2, 2, 'webinar', 'Asistió al webinar completo.', '2026-08-20 17:00:00'),
(5, 2, 5, 'webinar', 'Asistió parcialmente y pidió grabación.', '2026-08-20 17:00:00'),
(6, 3, 4, 'llamada', 'Interesado en la oferta de renovación.', '2026-11-17 10:15:00'),
(7, 4, 48, 'descarga', 'Descargó el material de la campaña.', '2026-04-25 16:15:00'),
(8, 4, 48, 'descarga', 'Descargó el material de la campaña.', '2026-04-18 12:00:00'),
(9, 4, 16, 'visita', 'Visitó la página de la campaña.', '2026-03-30 13:45:00'),
(10, 4, 16, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-04-01 12:45:00'),
(11, 5, 22, 'visita', 'Visitó la página de la campaña.', '2025-12-08 12:45:00'),
(12, 5, 22, 'formulario', 'Completó el formulario de contacto.', '2026-01-01 13:45:00'),
(13, 5, 25, 'llamada', 'Atendió la llamada y pidió cotización.', '2025-11-22 12:30:00'),
(14, 5, 26, 'llamada', 'Atendió la llamada y pidió cotización.', '2025-12-04 11:00:00'),
(15, 5, 26, 'formulario', 'Completó el formulario de contacto.', '2025-11-17 14:00:00'),
(16, 5, 41, 'correo', 'Abrió el correo.', '2025-12-17 11:15:00'),
(17, 5, 41, 'formulario', 'Completó el formulario de contacto.', '2025-11-26 15:30:00'),
(18, 6, 44, 'correo', 'Abrió el correo.', '2026-02-21 08:00:00'),
(19, 6, 44, 'correo', 'Abrió el correo.', '2026-01-23 16:15:00'),
(20, 6, 50, 'webinar', 'Asistió al webinar.', '2026-02-10 08:45:00'),
(21, 6, 50, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-01-14 17:30:00'),
(22, 6, 25, 'visita', 'Visitó la página de la campaña.', '2026-03-02 10:15:00'),
(23, 7, 37, 'formulario', 'Completó el formulario de contacto.', '2026-11-15 10:45:00'),
(24, 7, 43, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-10-10 13:45:00'),
(25, 7, 47, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-11-15 08:30:00'),
(26, 7, 47, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-10-27 11:30:00'),
(27, 8, 45, 'formulario', 'Completó el formulario de contacto.', '2026-04-20 15:00:00'),
(28, 8, 39, 'correo', 'Abrió el correo.', '2026-04-12 15:30:00'),
(29, 8, 39, 'formulario', 'Completó el formulario de contacto.', '2026-04-05 14:00:00'),
(30, 8, 21, 'visita', 'Visitó la página de la campaña.', '2026-04-22 10:15:00'),
(31, 8, 21, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-03-23 16:15:00'),
(32, 9, 44, 'webinar', 'Asistió al webinar.', '2026-01-08 08:30:00'),
(33, 9, 44, 'correo', 'Abrió el correo.', '2026-01-09 10:45:00'),
(34, 9, 3, 'visita', 'Visitó la página de la campaña.', '2026-02-01 09:00:00'),
(35, 9, 3, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-01-04 13:30:00'),
(36, 9, 15, 'correo', 'Abrió el correo.', '2026-01-11 12:15:00'),
(37, 9, 15, 'correo', 'Hizo clic en el enlace de la oferta.', '2025-12-29 17:30:00'),
(38, 10, 46, 'formulario', 'Completó el formulario de contacto.', '2026-01-10 08:15:00'),
(39, 10, 21, 'formulario', 'Completó el formulario de contacto.', '2025-12-25 13:30:00'),
(40, 11, 26, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-06-24 10:00:00'),
(41, 11, 26, 'visita', 'Visitó la página de la campaña.', '2026-06-26 09:00:00'),
(42, 11, 16, 'descarga', 'Descargó el material de la campaña.', '2026-07-06 16:30:00'),
(43, 11, 16, 'visita', 'Visitó la página de la campaña.', '2026-07-14 11:00:00'),
(44, 11, 45, 'webinar', 'Asistió al webinar.', '2026-06-06 08:45:00'),
(45, 13, 12, 'correo', 'Abrió el correo.', '2026-02-13 14:45:00'),
(46, 13, 12, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-02-15 17:15:00'),
(47, 13, 42, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-02-14 17:45:00'),
(48, 13, 40, 'visita', 'Visitó la página de la campaña.', '2026-02-02 08:00:00'),
(49, 13, 10, 'webinar', 'Asistió al webinar.', '2026-02-11 14:15:00'),
(50, 14, 38, 'formulario', 'Completó el formulario de contacto.', '2026-10-08 15:15:00'),
(51, 14, 19, 'webinar', 'Asistió al webinar.', '2026-09-05 13:15:00'),
(52, 14, 19, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-09-28 17:00:00'),
(53, 15, 15, 'correo', 'Abrió el correo.', '2026-10-29 14:15:00'),
(54, 15, 41, 'formulario', 'Completó el formulario de contacto.', '2026-10-31 17:00:00'),
(55, 15, 40, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-11-03 11:15:00'),
(56, 15, 40, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-11-16 14:30:00'),
(57, 15, 7, 'webinar', 'Asistió al webinar.', '2026-11-04 14:15:00'),
(58, 15, 7, 'correo', 'Abrió el correo.', '2026-11-12 09:15:00'),
(59, 16, 38, 'visita', 'Visitó la página de la campaña.', '2025-11-26 10:45:00'),
(60, 16, 38, 'correo', 'Hizo clic en el enlace de la oferta.', '2025-12-07 14:45:00'),
(61, 16, 19, 'descarga', 'Descargó el material de la campaña.', '2025-11-27 13:15:00'),
(62, 16, 19, 'formulario', 'Completó el formulario de contacto.', '2025-11-04 13:30:00'),
(63, 17, 52, 'webinar', 'Asistió al webinar.', '2026-02-22 15:30:00'),
(64, 17, 52, 'formulario', 'Completó el formulario de contacto.', '2026-03-11 14:00:00'),
(65, 17, 31, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-03-02 12:15:00'),
(66, 18, 33, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-06-11 17:00:00'),
(67, 18, 11, 'formulario', 'Completó el formulario de contacto.', '2026-06-11 10:15:00'),
(68, 18, 11, 'correo', 'Abrió el correo.', '2026-06-22 09:45:00'),
(69, 19, 21, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-01-01 12:00:00'),
(70, 19, 7, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-01-01 15:30:00'),
(71, 20, 46, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-06-16 09:00:00'),
(72, 20, 6, 'formulario', 'Completó el formulario de contacto.', '2026-07-04 16:00:00'),
(73, 21, 20, 'webinar', 'Asistió al webinar.', '2026-09-28 14:30:00'),
(74, 21, 20, 'formulario', 'Completó el formulario de contacto.', '2026-11-06 17:15:00'),
(75, 21, 37, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-11-10 15:45:00'),
(76, 21, 46, 'correo', 'Abrió el correo.', '2026-11-10 16:45:00'),
(77, 22, 1, 'visita', 'Visitó la página de la campaña.', '2025-09-07 14:15:00'),
(78, 22, 30, 'correo', 'Abrió el correo.', '2025-07-28 15:45:00'),
(79, 22, 26, 'webinar', 'Asistió al webinar.', '2025-09-12 10:00:00'),
(80, 22, 26, 'correo', 'Abrió el correo.', '2025-08-10 14:00:00'),
(81, 22, 50, 'descarga', 'Descargó el material de la campaña.', '2025-08-07 08:45:00'),
(82, 23, 13, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-07-11 13:30:00'),
(83, 23, 13, 'visita', 'Visitó la página de la campaña.', '2026-07-22 14:45:00'),
(84, 23, 45, 'visita', 'Visitó la página de la campaña.', '2026-07-17 10:30:00'),
(85, 24, 15, 'correo', 'Hizo clic en el enlace de la oferta.', '2025-09-17 12:45:00'),
(86, 24, 51, 'webinar', 'Asistió al webinar.', '2025-10-20 12:45:00'),
(87, 24, 51, 'correo', 'Abrió el correo.', '2025-09-23 14:45:00'),
(88, 26, 54, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-11-03 09:30:00'),
(89, 26, 33, 'webinar', 'Asistió al webinar.', '2026-11-12 12:30:00'),
(90, 26, 24, 'visita', 'Visitó la página de la campaña.', '2026-11-07 16:30:00'),
(91, 27, 49, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-03-25 11:45:00'),
(92, 27, 49, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-04-10 12:30:00'),
(93, 27, 5, 'visita', 'Visitó la página de la campaña.', '2026-04-08 08:15:00'),
(94, 27, 42, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-03-30 15:15:00'),
(95, 27, 42, 'formulario', 'Completó el formulario de contacto.', '2026-04-20 14:00:00'),
(96, 28, 39, 'descarga', 'Descargó el material de la campaña.', '2026-05-25 17:45:00'),
(97, 28, 47, 'webinar', 'Asistió al webinar.', '2026-04-30 15:45:00'),
(98, 28, 47, 'correo', 'Abrió el correo.', '2026-04-04 15:00:00'),
(99, 28, 55, 'correo', 'Abrió el correo.', '2026-05-26 08:15:00'),
(100, 28, 30, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-06-04 09:00:00'),
(101, 28, 30, 'correo', 'Hizo clic en el enlace de la oferta.', '2026-04-05 09:30:00'),
(102, 29, 14, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-06-28 17:15:00'),
(103, 29, 14, 'correo', 'Abrió el correo.', '2026-06-11 11:15:00'),
(104, 29, 26, 'visita', 'Visitó la página de la campaña.', '2026-06-02 09:30:00'),
(105, 29, 26, 'visita', 'Visitó la página de la campaña.', '2026-05-22 08:30:00'),
(106, 29, 16, 'webinar', 'Asistió al webinar.', '2026-05-26 09:00:00'),
(107, 30, 4, 'correo', 'Abrió el correo.', '2026-08-19 11:45:00'),
(108, 30, 4, 'llamada', 'Atendió la llamada y pidió cotización.', '2026-09-07 10:15:00'),
(109, 30, 47, 'correo', 'Abrió el correo.', '2026-09-01 17:30:00');

-- ------------------------------------------------------------
-- 9. Actividad e historial
-- ------------------------------------------------------------
INSERT INTO actividad_web (id_actividad, id_usuario, id_cliente, accion, descripcion, fecha) VALUES
(1, 2, 1, 'visita', 'Visitó la página de planes empresariales.', '2026-09-10 09:05:00'),
(2, 2, 1, 'descarga', 'Descargó el comparativo de planes.', '2026-09-10 09:12:00'),
(3, 3, 3, 'formulario', 'Solicitó una prueba gratuita de 60 días.', '2026-09-12 14:20:00'),
(4, 3, 3, 'visita', 'Visitó la sección de preguntas frecuentes.', '2026-09-12 14:35:00'),
(5, 4, 6, 'descarga', 'Descargó el documento de seguridad y cifrado.', '2026-10-02 11:50:00'),
(6, 5, 7, 'visita', 'Visitó la página de la campaña de fin de año.', '2026-10-05 18:30:00'),
(7, 2, 2, 'correo', 'Hizo clic en el correo de renovación.', '2026-10-18 09:10:00'),
(8, 4, 8, 'visita', 'Visitó la página de soporte premium.', '2026-10-03 13:45:00'),
(9, NULL, 39, 'visita', 'Visitó el blog de seguridad.', '2026-08-25 16:30:00'),
(10, NULL, 54, 'descarga', 'Descargó la ficha técnica.', '2026-07-17 14:30:00'),
(11, NULL, 36, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-04-09 17:00:00'),
(12, NULL, 50, 'demo', 'Solicitó una demostración.', '2026-01-11 14:15:00'),
(13, NULL, 1, 'descarga', 'Descargó la ficha técnica.', '2026-01-25 15:00:00'),
(14, NULL, 20, 'demo', 'Solicitó una demostración.', '2026-03-28 08:00:00'),
(15, NULL, 9, 'descarga', 'Descargó la ficha técnica.', '2026-10-08 11:15:00'),
(16, NULL, 35, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-07-19 08:00:00'),
(17, NULL, 12, 'formulario', 'Envió el formulario de contacto.', '2026-05-16 12:15:00'),
(18, NULL, 4, 'formulario', 'Envió el formulario de contacto.', '2026-02-14 14:30:00'),
(19, NULL, 22, 'webinar', 'Se registró a un webinar.', '2026-02-21 15:45:00'),
(20, NULL, 33, 'correo', 'Abrió el boletín mensual.', '2026-06-14 09:45:00'),
(21, NULL, 2, 'visita', 'Visitó el blog de seguridad.', '2026-09-11 11:30:00'),
(22, NULL, 16, 'formulario', 'Envió el formulario de contacto.', '2026-07-03 13:15:00'),
(23, NULL, 41, 'descarga', 'Descargó la ficha técnica.', '2026-01-31 10:15:00'),
(24, NULL, 44, 'correo', 'Abrió el boletín mensual.', '2026-01-10 12:15:00'),
(25, NULL, 20, 'visita', 'Visitó el blog de seguridad.', '2026-09-23 12:00:00'),
(26, NULL, 48, 'webinar', 'Se registró a un webinar.', '2026-02-27 13:45:00'),
(27, NULL, 50, 'visita', 'Visitó el blog de seguridad.', '2026-08-05 12:45:00'),
(28, NULL, 40, 'descarga', 'Descargó la ficha técnica.', '2026-01-10 09:45:00'),
(29, NULL, 44, 'demo', 'Solicitó una demostración.', '2026-09-08 10:45:00'),
(30, NULL, 23, 'visita', 'Visitó el blog de seguridad.', '2026-03-14 08:15:00'),
(31, NULL, 38, 'descarga', 'Descargó la ficha técnica.', '2026-02-20 15:30:00'),
(32, NULL, 42, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-04-15 12:00:00'),
(33, NULL, 27, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-03-24 12:45:00'),
(34, NULL, 35, 'correo', 'Abrió el boletín mensual.', '2026-08-01 17:30:00'),
(35, NULL, 5, 'webinar', 'Se registró a un webinar.', '2026-04-26 08:30:00'),
(36, NULL, 43, 'visita', 'Visitó el blog de seguridad.', '2026-01-11 08:00:00'),
(37, NULL, 10, 'visita', 'Visitó el blog de seguridad.', '2026-06-27 15:30:00'),
(38, NULL, 46, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-04-12 12:00:00'),
(39, NULL, 35, 'demo', 'Solicitó una demostración.', '2026-10-07 17:45:00'),
(40, NULL, 6, 'demo', 'Solicitó una demostración.', '2026-06-16 14:30:00'),
(41, NULL, 42, 'descarga', 'Descargó la ficha técnica.', '2026-07-16 09:30:00'),
(42, NULL, 49, 'demo', 'Solicitó una demostración.', '2026-05-01 09:45:00'),
(43, NULL, 17, 'descarga', 'Descargó la ficha técnica.', '2026-01-08 14:30:00'),
(44, NULL, 22, 'webinar', 'Se registró a un webinar.', '2026-01-06 16:00:00'),
(45, NULL, 20, 'demo', 'Solicitó una demostración.', '2026-04-28 13:00:00'),
(46, NULL, 27, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-07-27 13:00:00'),
(47, NULL, 56, 'webinar', 'Se registró a un webinar.', '2026-05-08 10:30:00'),
(48, NULL, 19, 'webinar', 'Se registró a un webinar.', '2026-07-30 11:45:00'),
(49, NULL, 29, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-04-07 09:15:00'),
(50, NULL, 25, 'visita', 'Visitó el blog de seguridad.', '2026-04-05 11:30:00'),
(51, NULL, 58, 'webinar', 'Se registró a un webinar.', '2026-09-20 09:15:00'),
(52, NULL, 26, 'formulario', 'Envió el formulario de contacto.', '2026-09-04 14:45:00'),
(53, NULL, 37, 'formulario', 'Envió el formulario de contacto.', '2026-02-16 17:15:00'),
(54, NULL, 33, 'formulario', 'Envió el formulario de contacto.', '2026-01-10 11:45:00'),
(55, NULL, 33, 'webinar', 'Se registró a un webinar.', '2026-08-08 10:00:00'),
(56, NULL, 4, 'formulario', 'Envió el formulario de contacto.', '2026-02-28 09:30:00'),
(57, NULL, 53, 'descarga', 'Descargó la ficha técnica.', '2026-02-03 17:30:00'),
(58, NULL, 36, 'formulario', 'Envió el formulario de contacto.', '2026-06-25 13:00:00'),
(59, NULL, 35, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-06-29 08:45:00'),
(60, NULL, 59, 'correo', 'Abrió el boletín mensual.', '2026-05-31 16:45:00'),
(61, NULL, 47, 'correo', 'Abrió el boletín mensual.', '2026-09-29 15:15:00'),
(62, NULL, 28, 'demo', 'Solicitó una demostración.', '2026-05-17 15:00:00'),
(63, NULL, 23, 'descarga', 'Descargó la ficha técnica.', '2026-01-24 08:15:00'),
(64, NULL, 42, 'formulario', 'Envió el formulario de contacto.', '2026-04-01 11:00:00'),
(65, NULL, 45, 'visita', 'Visitó el blog de seguridad.', '2026-04-05 12:45:00'),
(66, NULL, 29, 'descarga', 'Descargó la ficha técnica.', '2026-02-28 10:45:00'),
(67, NULL, 15, 'demo', 'Solicitó una demostración.', '2026-01-22 17:15:00'),
(68, NULL, 21, 'webinar', 'Se registró a un webinar.', '2026-05-19 13:30:00'),
(69, NULL, 45, 'formulario', 'Envió el formulario de contacto.', '2026-03-19 16:45:00'),
(70, NULL, 6, 'webinar', 'Se registró a un webinar.', '2026-07-23 08:15:00'),
(71, NULL, 25, 'descarga', 'Descargó la ficha técnica.', '2026-02-01 16:30:00'),
(72, NULL, 55, 'descarga', 'Descargó la ficha técnica.', '2026-03-12 15:45:00'),
(73, NULL, 33, 'descarga', 'Descargó la ficha técnica.', '2026-09-06 15:45:00'),
(74, NULL, 7, 'correo', 'Abrió el boletín mensual.', '2026-08-15 15:00:00'),
(75, NULL, 31, 'visita', 'Visitó el blog de seguridad.', '2026-06-24 13:15:00'),
(76, NULL, 14, 'demo', 'Solicitó una demostración.', '2026-04-01 15:00:00'),
(77, NULL, 55, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-07-07 09:45:00'),
(78, NULL, 36, 'webinar', 'Se registró a un webinar.', '2026-02-08 08:45:00'),
(79, NULL, 38, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-01-08 13:30:00'),
(80, NULL, 18, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-07-26 13:15:00'),
(81, NULL, 25, 'descarga', 'Descargó la ficha técnica.', '2026-03-21 16:00:00'),
(82, NULL, 34, 'formulario', 'Envió el formulario de contacto.', '2026-10-10 09:30:00'),
(83, NULL, 57, 'demo', 'Solicitó una demostración.', '2026-04-28 12:30:00'),
(84, NULL, 3, 'webinar', 'Se registró a un webinar.', '2026-04-03 15:45:00'),
(85, NULL, 29, 'visita', 'Visitó el blog de seguridad.', '2026-03-25 13:30:00'),
(86, NULL, 23, 'visita', 'Visitó la página de precios.', '2026-05-30 11:15:00'),
(87, NULL, 28, 'descarga', 'Descargó la ficha técnica.', '2026-09-27 08:00:00'),
(88, NULL, 45, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-07-27 16:15:00'),
(89, NULL, 6, 'visita', 'Visitó la página de precios.', '2026-08-26 16:15:00'),
(90, NULL, 51, 'formulario', 'Envió el formulario de contacto.', '2026-06-23 13:30:00'),
(91, NULL, 10, 'descarga', 'Descargó la ficha técnica.', '2026-05-21 12:45:00'),
(92, NULL, 54, 'descarga', 'Descargó la ficha técnica.', '2026-05-08 12:30:00'),
(93, NULL, 37, 'prueba', 'Activó la prueba gratuita de 60 días.', '2026-04-06 13:15:00'),
(94, NULL, 8, 'correo', 'Abrió el boletín mensual.', '2026-03-09 15:15:00'),
(95, NULL, 19, 'correo', 'Abrió el boletín mensual.', '2026-09-30 16:30:00'),
(96, NULL, 3, 'correo', 'Abrió el boletín mensual.', '2026-08-15 13:00:00'),
(97, NULL, 58, 'visita', 'Visitó la página de precios.', '2026-03-10 16:45:00'),
(98, NULL, 49, 'visita', 'Visitó el blog de seguridad.', '2026-07-21 16:15:00'),
(99, NULL, 10, 'visita', 'Visitó el blog de seguridad.', '2026-09-01 16:30:00'),
(100, NULL, 31, 'correo', 'Abrió el boletín mensual.', '2026-05-14 09:45:00'),
(101, NULL, 34, 'visita', 'Actividad reciente: visita.', NOW() - INTERVAL 13 DAY),
(102, NULL, 34, 'descarga', 'Actividad reciente: descarga.', NOW() - INTERVAL 10 DAY),
(103, NULL, 34, 'webinar', 'Actividad reciente: webinar.', NOW() - INTERVAL 10 DAY),
(104, NULL, 34, 'formulario', 'Actividad reciente: formulario.', NOW() - INTERVAL 6 DAY),
(105, NULL, 34, 'visita', 'Actividad reciente: visita.', NOW() - INTERVAL 3 DAY),
(106, NULL, 34, 'demo', 'Actividad reciente: demo.', NOW() - INTERVAL 2 DAY),
(107, NULL, 35, 'visita', 'Actividad reciente: visita.', NOW() - INTERVAL 14 DAY),
(108, NULL, 35, 'descarga', 'Actividad reciente: descarga.', NOW() - INTERVAL 11 DAY),
(109, NULL, 35, 'webinar', 'Actividad reciente: webinar.', NOW() - INTERVAL 11 DAY),
(110, NULL, 35, 'formulario', 'Actividad reciente: formulario.', NOW() - INTERVAL 7 DAY),
(111, NULL, 35, 'visita', 'Actividad reciente: visita.', NOW() - INTERVAL 4 DAY),
(112, NULL, 35, 'demo', 'Actividad reciente: demo.', NOW() - INTERVAL 3 DAY),
(113, NULL, 36, 'visita', 'Actividad reciente: visita.', NOW() - INTERVAL 12 DAY),
(114, NULL, 36, 'descarga', 'Actividad reciente: descarga.', NOW() - INTERVAL 9 DAY),
(115, NULL, 36, 'webinar', 'Actividad reciente: webinar.', NOW() - INTERVAL 9 DAY),
(116, NULL, 36, 'formulario', 'Actividad reciente: formulario.', NOW() - INTERVAL 5 DAY),
(117, NULL, 36, 'visita', 'Actividad reciente: visita.', NOW() - INTERVAL 2 DAY),
(118, NULL, 36, 'demo', 'Actividad reciente: demo.', NOW() - INTERVAL 1 DAY),
(119, NULL, 37, 'visita', 'Actividad reciente: visita.', NOW() - INTERVAL 13 DAY),
(120, NULL, 37, 'descarga', 'Actividad reciente: descarga.', NOW() - INTERVAL 10 DAY),
(121, NULL, 37, 'webinar', 'Actividad reciente: webinar.', NOW() - INTERVAL 10 DAY),
(122, NULL, 37, 'formulario', 'Actividad reciente: formulario.', NOW() - INTERVAL 6 DAY),
(123, NULL, 37, 'visita', 'Actividad reciente: visita.', NOW() - INTERVAL 3 DAY),
(124, NULL, 37, 'demo', 'Actividad reciente: demo.', NOW() - INTERVAL 2 DAY);

INSERT INTO notificaciones (id_notificacion, id_usuario, titulo, mensaje, estado, fecha) VALUES
(1, 2, 'Nueva tarea asignada', 'Tienes una tarea pendiente: enviar contrato de migración.', 'leida', '2026-10-25 08:00:00'),
(2, 2, 'Propuesta aceptada', 'Tecnología Andina S.A.S. aceptó la propuesta de migración.', 'leida', '2026-10-12 11:30:00'),
(3, 3, 'Propuesta aceptada', 'La propuesta de Inversiones Pacífico S.A. fue aceptada.', 'leida', '2026-10-05 12:10:00'),
(4, 4, 'Recordatorio de demo', 'Demo de cifrado con Clínica San Rafael el 25 de noviembre.', 'pendiente', '2026-11-01 09:00:00'),
(5, 5, 'Campaña próxima a iniciar', 'La campaña de fin de año inicia el 15 de noviembre.', 'leida', '2026-11-02 10:00:00'),
(6, 1, 'Reporte mensual disponible', 'El reporte de ventas de octubre está listo para revisión.', 'leida', '2026-11-01 07:30:00'),
(7, 9, 'Nueva tarea asignada', 'Tienes una tarea: enviar caso de éxito.', 'leida', '2026-12-23 12:00:00'),
(8, 9, 'Nueva tarea asignada', 'Tienes una tarea: enviar cotización actualizada.', 'leida', '2026-10-28 17:45:00'),
(9, 16, 'Nueva tarea asignada', 'Tienes una tarea: hacer seguimiento a la propuesta.', 'leida', '2026-11-24 11:00:00'),
(10, 16, 'Nueva tarea asignada', 'Tienes una tarea: enviar caso de éxito.', 'leida', '2026-12-05 17:00:00'),
(11, 23, 'Nueva tarea asignada', 'Tienes una tarea: confirmar decisor de compra.', 'leida', '2026-12-13 11:30:00'),
(12, 23, 'Nueva tarea asignada', 'Tienes una tarea: hacer seguimiento a la propuesta.', 'leida', '2026-11-12 09:00:00'),
(13, 30, 'Nueva tarea asignada', 'Tienes una tarea: agendar demo.', 'leida', '2026-11-29 10:30:00'),
(14, 30, 'Nueva tarea asignada', 'Tienes una tarea: hacer seguimiento a la propuesta.', 'pendiente', '2026-12-24 14:00:00'),
(15, 8, 'Nueva tarea asignada', 'Tienes una tarea: confirmar decisor de compra.', 'leida', '2026-12-14 17:30:00'),
(16, 8, 'Nueva tarea asignada', 'Tienes una tarea: enviar caso de éxito.', 'pendiente', '2026-10-30 16:30:00'),
(17, 15, 'Nueva tarea asignada', 'Tienes una tarea: confirmar decisor de compra.', 'leida', '2026-12-23 13:00:00'),
(18, 15, 'Nueva tarea asignada', 'Tienes una tarea: agendar demo.', 'pendiente', '2026-12-13 13:30:00'),
(19, 22, 'Nueva tarea asignada', 'Tienes una tarea: hacer seguimiento a la propuesta.', 'pendiente', '2026-10-30 10:15:00'),
(20, 22, 'Nueva tarea asignada', 'Tienes una tarea: hacer seguimiento a la propuesta.', 'pendiente', '2026-12-01 15:15:00'),
(21, 29, 'Nueva tarea asignada', 'Tienes una tarea: confirmar decisor de compra.', 'pendiente', '2026-11-03 13:15:00'),
(22, 29, 'Nueva tarea asignada', 'Tienes una tarea: enviar cotización actualizada.', 'leida', '2026-12-01 08:00:00'),
(23, 7, 'Nueva tarea asignada', 'Tienes una tarea: agendar demo.', 'pendiente', '2026-12-10 09:45:00'),
(24, 7, 'Nueva tarea asignada', 'Tienes una tarea: preparar propuesta técnica.', 'pendiente', '2026-10-31 14:30:00'),
(25, 14, 'Nueva tarea asignada', 'Tienes una tarea: llamar al prospecto.', 'pendiente', '2026-11-25 17:30:00'),
(26, 14, 'Nueva tarea asignada', 'Tienes una tarea: enviar caso de éxito.', 'leida', '2026-12-06 11:45:00'),
(27, 21, 'Nueva tarea asignada', 'Tienes una tarea: preparar propuesta técnica.', 'leida', '2026-12-06 17:30:00'),
(28, 21, 'Nueva tarea asignada', 'Tienes una tarea: preparar propuesta técnica.', 'leida', '2026-11-24 09:45:00'),
(29, 28, 'Nueva tarea asignada', 'Tienes una tarea: enviar caso de éxito.', 'pendiente', '2026-12-07 17:00:00'),
(30, 28, 'Nueva tarea asignada', 'Tienes una tarea: enviar caso de éxito.', 'pendiente', '2026-11-23 09:45:00'),
(31, 3, 'Nueva tarea asignada', 'Tienes una tarea: contactar al prospecto.', 'leida', '2026-11-24 09:30:00'),
(32, 4, 'Nueva tarea asignada', 'Tienes una tarea: contactar al prospecto.', 'pendiente', '2026-12-09 08:45:00'),
(33, 4, 'Nueva tarea asignada', 'Tienes una tarea: contactar al prospecto.', 'pendiente', '2026-11-08 14:45:00'),
(34, 6, 'Nueva tarea asignada', 'Tienes una tarea: contactar al prospecto.', 'pendiente', '2026-11-11 16:45:00'),
(35, 4, 'Nueva tarea asignada', 'Tienes una tarea: contactar al prospecto.', 'leida', '2026-11-14 08:15:00'),
(36, 12, 'Nueva tarea asignada', 'Tienes una tarea: contactar al prospecto.', 'pendiente', '2026-12-10 13:00:00'),
(37, 19, 'Nueva tarea asignada', 'Tienes una tarea: contactar al prospecto.', 'leida', '2026-12-04 14:30:00'),
(38, 26, 'Nueva tarea asignada', 'Tienes una tarea: contactar al prospecto.', 'pendiente', '2026-11-14 16:45:00'),
(39, 3, 'Nueva tarea asignada', 'Tienes una tarea: contactar al prospecto.', 'pendiente', '2026-11-18 08:30:00'),
(40, 11, 'Nueva tarea asignada', 'Tienes una tarea: contactar al prospecto.', 'leida', '2026-11-22 10:15:00');

-- ------------------------------------------------------------
-- 11. Eventos, calendario y recordatorios
-- ------------------------------------------------------------
INSERT INTO eventos (id_evento, id_usuario, id_cliente, titulo, descripcion, fecha_inicio, fecha_fin, ubicacion, tipo, estado) VALUES
(1, 2, 1, 'Reunión de cierre - Tecnología Andina', 'Firma del contrato de migración.', '2026-10-12 10:00:00', '2026-10-12 11:30:00', 'Oficina del cliente', 'reunion', 'realizado'),
(2, 2, 2, 'Llamada de seguimiento - El Sol', 'Confirmar número de licencias para renovación.', '2026-11-20 09:00:00', '2026-11-20 09:30:00', 'Virtual', 'llamada', 'programado'),
(3, 3, 4, 'Kickoff de implementación - Inversiones Pacífico', 'Inicio formal del proyecto.', '2026-10-08 14:00:00', '2026-10-08 16:00:00', 'Sala de juntas', 'reunion', 'realizado'),
(4, 4, 6, 'Demo de cifrado - Clínica San Rafael', 'Demostración del módulo de seguridad.', '2026-11-25 15:30:00', '2026-11-25 16:30:00', 'Virtual', 'cita', 'programado'),
(5, 1, NULL, 'Comité comercial mensual', 'Revisión de indicadores y metas.', '2026-11-05 09:00:00', '2026-11-05 10:30:00', 'Sala principal', 'reunion', 'realizado'),
(6, 3, 3, 'Llamada de seguimiento - María Fernanda', 'Actividad del calendario comercial.', '2026-09-15 15:30:00', '2026-09-15 16:00:00', 'Virtual', 'llamada', 'realizado'),
(7, 4, 5, 'Llamada de seguimiento - Jorge Enrique', 'Actividad del calendario comercial.', '2026-09-28 17:15:00', '2026-09-28 17:45:00', 'Virtual', 'llamada', 'realizado'),
(8, 4, 7, 'Demostración del producto - Camila Andrea', 'Actividad del calendario comercial.', '2026-10-24 11:00:00', '2026-10-24 12:00:00', 'Virtual', 'cita', 'realizado'),
(9, 9, 34, 'Demostración del producto - Notaría Quinta de Medellín', 'Actividad del calendario comercial.', '2026-09-05 14:45:00', '2026-09-05 15:45:00', 'Virtual', 'cita', 'realizado'),
(10, 16, 35, 'Visita técnica - Editorial Páginas Abiertas', 'Actividad del calendario comercial.', '2026-10-14 13:30:00', '2026-10-14 15:30:00', 'Instalaciones del cliente', 'otro', 'realizado'),
(11, 23, 36, 'Llamada de seguimiento - Hernán', 'Actividad del calendario comercial.', '2026-09-05 16:45:00', '2026-09-05 17:15:00', 'Virtual', 'llamada', 'cancelado'),
(12, 30, 37, 'Llamada de seguimiento - Minería Responsable S.A.', 'Actividad del calendario comercial.', '2026-10-20 17:45:00', '2026-10-20 18:15:00', 'Virtual', 'llamada', 'realizado'),
(13, 8, 38, 'Llamada de seguimiento - Centro Médico Santa Lucía', 'Actividad del calendario comercial.', '2026-09-30 17:00:00', '2026-09-30 17:30:00', 'Virtual', 'llamada', 'realizado'),
(14, 15, 39, 'Reunión comercial - Aerolínea Regional Express', 'Actividad del calendario comercial.', '2026-10-18 11:45:00', '2026-10-18 13:15:00', 'Oficina del cliente', 'reunion', 'realizado'),
(15, 22, 40, 'Reunión comercial - Andrés', 'Actividad del calendario comercial.', '2026-09-18 08:45:00', '2026-09-18 10:15:00', 'Oficina del cliente', 'reunion', 'realizado'),
(16, 29, 41, 'Visita técnica - Banco Cooperativo Solidario', 'Actividad del calendario comercial.', '2026-10-16 13:15:00', '2026-10-16 15:15:00', 'Instalaciones del cliente', 'otro', 'realizado'),
(17, 7, 42, 'Demostración del producto - Grupo Logístico Atlántico', 'Actividad del calendario comercial.', '2026-12-04 16:30:00', '2026-12-04 17:30:00', 'Virtual', 'cita', 'programado'),
(18, 14, 43, 'Demostración del producto - Farmacias Bienestar S.A.S.', 'Actividad del calendario comercial.', '2026-12-07 09:00:00', '2026-12-07 10:00:00', 'Virtual', 'cita', 'programado'),
(19, 21, 44, 'Visita técnica - Alejandro', 'Actividad del calendario comercial.', '2026-09-08 09:15:00', '2026-09-08 11:15:00', 'Instalaciones del cliente', 'otro', 'realizado'),
(20, 28, 45, 'Reunión comercial - Instituto de Idiomas Global', 'Actividad del calendario comercial.', '2026-12-07 08:15:00', '2026-12-07 09:45:00', 'Oficina del cliente', 'reunion', 'programado'),
(21, 6, 46, 'Visita técnica - Consultores Asociados JR', 'Actividad del calendario comercial.', '2026-11-30 14:30:00', '2026-11-30 16:30:00', 'Instalaciones del cliente', 'otro', 'programado'),
(22, 13, 47, 'Reunión comercial - Pinturas Arcoíris S.A.', 'Actividad del calendario comercial.', '2026-11-09 10:00:00', '2026-11-09 11:30:00', 'Oficina del cliente', 'reunion', 'realizado'),
(23, 20, 48, 'Reunión comercial - Miguel Ángel', 'Actividad del calendario comercial.', '2026-11-17 17:00:00', '2026-11-17 18:30:00', 'Oficina del cliente', 'reunion', 'realizado'),
(24, 27, 49, 'Reunión comercial - Agencia de Viajes Destinos', 'Actividad del calendario comercial.', '2026-09-20 12:15:00', '2026-09-20 13:45:00', 'Oficina del cliente', 'reunion', 'realizado'),
(25, 4, 50, 'Reunión comercial - Lácteos La Pradera S.A.', 'Actividad del calendario comercial.', '2026-11-09 16:00:00', '2026-11-09 17:30:00', 'Oficina del cliente', 'reunion', 'realizado'),
(26, 26, 24, 'Visita técnica - Mauricio', 'Actividad del calendario comercial.', '2026-11-16 14:00:00', '2026-11-16 16:00:00', 'Instalaciones del cliente', 'otro', 'realizado'),
(27, 3, 25, 'Demostración del producto - Ferretería El Constructor', 'Actividad del calendario comercial.', '2026-11-12 17:30:00', '2026-11-12 18:30:00', 'Virtual', 'cita', 'realizado'),
(28, 11, 26, 'Visita técnica - Energía Verde Colombia S.A.S.', 'Actividad del calendario comercial.', '2026-10-25 08:15:00', '2026-10-25 10:15:00', 'Instalaciones del cliente', 'otro', 'cancelado'),
(29, 18, 27, 'Reunión comercial - Cooperativa Cafetera del Huila', 'Actividad del calendario comercial.', '2026-11-18 15:30:00', '2026-11-18 17:00:00', 'Oficina del cliente', 'reunion', 'realizado'),
(30, 25, 28, 'Reunión comercial - Juan Camilo', 'Actividad del calendario comercial.', '2026-11-27 16:15:00', '2026-11-27 17:45:00', 'Oficina del cliente', 'reunion', 'programado'),
(31, 2, 29, 'Demostración del producto - Clínica Los Andes', 'Actividad del calendario comercial.', '2026-10-01 16:45:00', '2026-10-01 17:45:00', 'Virtual', 'cita', 'realizado'),
(32, 10, 30, 'Visita técnica - Software Factory Bogotá S.A.S.', 'Actividad del calendario comercial.', '2026-11-08 12:00:00', '2026-11-08 14:00:00', 'Instalaciones del cliente', 'otro', 'realizado'),
(33, 17, 31, 'Demostración del producto - Inmobiliaria Altos del Prado', 'Actividad del calendario comercial.', '2026-09-25 13:00:00', '2026-09-25 14:00:00', 'Virtual', 'cita', 'realizado'),
(34, 24, 32, 'Visita técnica - Gabriel', 'Actividad del calendario comercial.', '2026-09-13 09:30:00', '2026-09-13 11:30:00', 'Instalaciones del cliente', 'otro', 'realizado'),
(35, 31, 33, 'Reunión comercial - Restaurantes Sabor Criollo S.A.S.', 'Actividad del calendario comercial.', '2026-12-04 13:15:00', '2026-12-04 14:45:00', 'Oficina del cliente', 'reunion', 'programado'),
(36, 2, 1, 'Visita técnica - Tecnología Andina S.A.S.', 'Actividad del calendario comercial.', '2026-11-03 17:45:00', '2026-11-03 19:45:00', 'Instalaciones del cliente', 'otro', 'realizado'),
(37, 2, 2, 'Visita técnica - Comercializadora El Sol Ltda.', 'Actividad del calendario comercial.', '2026-10-16 10:45:00', '2026-10-16 12:45:00', 'Instalaciones del cliente', 'otro', 'realizado'),
(38, 3, 4, 'Reunión comercial - Inversiones Pacífico S.A.', 'Actividad del calendario comercial.', '2026-10-09 17:30:00', '2026-10-09 19:00:00', 'Oficina del cliente', 'reunion', 'realizado'),
(39, 4, 6, 'Reunión comercial - Clínica San Rafael', 'Actividad del calendario comercial.', '2026-11-01 14:00:00', '2026-11-01 15:30:00', 'Oficina del cliente', 'reunion', 'realizado'),
(40, 3, 8, 'Llamada de seguimiento - Logística del Norte S.A.S.', 'Actividad del calendario comercial.', '2026-09-18 13:30:00', '2026-09-18 14:00:00', 'Virtual', 'llamada', 'realizado');

-- ------------------------------------------------------------
-- 13. Correos y plantillas
-- ------------------------------------------------------------
INSERT INTO correos (id_correo, id_usuario, asunto, contenido, fecha_envio, estado) VALUES
(1, 2, 'Propuesta comercial - Migración Zimbra', 'Estimado Juan Pablo, adjuntamos la propuesta para la migración de 250 buzones...', '2026-10-10 17:00:00', 'enviado'),
(2, 2, 'Seguimiento propuesta Tecnología Andina', 'Hola Andrea, queremos conocer sus comentarios sobre la propuesta enviada...', '2026-10-11 11:10:00', 'enviado'),
(3, 5, 'Lanzamiento Zimbra 2026', 'Conoce las novedades de nuestra suite de colaboración...', '2026-10-03 08:00:00', 'enviado'),
(4, 3, 'Confirmación de kickoff', 'Confirmamos la reunión de inicio del proyecto para el 8 de octubre...', '2026-10-06 10:00:00', 'enviado'),
(5, 1, 'Borrador de comunicado interno', 'Equipo, comparto el borrador del comunicado de resultados del trimestre...', NULL, 'borrador'),
(6, 8, 'Propuesta comercial - Constructora Horizonte S.A.S.', 'Hola Verónica, le escribimos en relación con propuesta comercial - constructora horizonte s.a.s....', '2026-10-25 12:30:00', 'enviado'),
(7, 22, 'Seguimiento a nuestra reunión - Universidad Tecnológica del Caribe', 'Hola Catalina, le escribimos en relación con seguimiento a nuestra reunión - universidad tecnológica del caribe...', '2026-03-05 15:00:00', 'enviado'),
(8, 14, 'Información de planes Zimbra - Hotel Mirador Andino', 'Hola Gabriel, le escribimos en relación con información de planes zimbra - hotel mirador andino...', '2026-05-04 09:30:00', 'enviado'),
(9, 28, 'Invitación a demostración - Sebastián', 'Hola Sebastián, le escribimos en relación con invitación a demostración - sebastián...', '2026-06-06 09:30:00', 'enviado'),
(10, 13, 'Confirmación de pago - Colegio Nuevo Horizonte', 'Hola Lina María, le escribimos en relación con confirmación de pago - colegio nuevo horizonte...', '2026-07-24 17:00:00', 'enviado'),
(11, 4, 'Bienvenida como cliente - Seguros Confianza Plus S.A.', 'Hola Paola, le escribimos en relación con bienvenida como cliente - seguros confianza plus s.a....', '2026-03-11 09:30:00', 'enviado'),
(12, 19, 'Propuesta comercial - Alcaldía Municipal de Chía', 'Hola Iván, le escribimos en relación con propuesta comercial - alcaldía municipal de chía...', '2026-03-02 16:00:00', 'enviado'),
(13, 11, 'Seguimiento a nuestra reunión - Energía Verde Colombia S.A.S.', 'Hola Felipe, le escribimos en relación con seguimiento a nuestra reunión - energía verde colombia s.a.s....', NULL, 'borrador'),
(14, 25, 'Información de planes Zimbra - Juan Camilo', 'Hola Juan Camilo, le escribimos en relación con información de planes zimbra - juan camilo...', '2026-05-16 17:00:00', 'enviado'),
(15, 10, 'Invitación a demostración - Software Factory Bogotá S.A.S.', 'Hola Alejandro, le escribimos en relación con invitación a demostración - software factory bogotá s.a.s....', '2026-10-15 10:30:00', 'enviado'),
(16, 31, 'Confirmación de pago - Restaurantes Sabor Criollo S.A.S.', 'Hola Tomás, le escribimos en relación con confirmación de pago - restaurantes sabor criollo s.a.s....', '2026-06-03 11:30:00', 'enviado'),
(17, 16, 'Bienvenida como cliente - Editorial Páginas Abiertas', 'Hola Miguel Ángel, le escribimos en relación con bienvenida como cliente - editorial páginas abiertas...', '2026-08-14 14:45:00', 'enviado'),
(18, 8, 'Propuesta comercial - Centro Médico Santa Lucía', 'Hola Lina María, le escribimos en relación con propuesta comercial - centro médico santa lucía...', '2026-07-01 11:30:00', 'enviado'),
(19, 22, 'Seguimiento a nuestra reunión - Andrés', 'Hola Andrés, le escribimos en relación con seguimiento a nuestra reunión - andrés...', '2026-03-31 12:45:00', 'enviado'),
(20, 7, 'Información de planes Zimbra - Grupo Logístico Atlántico', 'Hola Tomás, le escribimos en relación con información de planes zimbra - grupo logístico atlántico...', '2026-06-28 08:00:00', 'enviado'),
(21, 28, 'Invitación a demostración - Instituto de Idiomas Global', 'Hola Mateo, le escribimos en relación con invitación a demostración - instituto de idiomas global...', NULL, 'borrador'),
(22, 13, 'Confirmación de pago - Pinturas Arcoíris S.A.', 'Hola Andrés, le escribimos en relación con confirmación de pago - pinturas arcoíris s.a....', '2026-03-14 10:30:00', 'enviado'),
(23, 4, 'Bienvenida como cliente - Lácteos La Pradera S.A.', 'Hola Mariana, le escribimos en relación con bienvenida como cliente - lácteos la pradera s.a....', '2026-05-21 10:30:00', 'enviado'),
(24, 19, 'Propuesta comercial - Germán', 'Hola Germán, le escribimos en relación con propuesta comercial - germán...', '2026-04-27 15:00:00', 'enviado'),
(25, 3, 'Seguimiento a nuestra reunión - Tienda Virtual Compra Fácil', 'Hola Gloria, le escribimos en relación con seguimiento a nuestra reunión - tienda virtual compra fácil...', '2026-11-01 11:45:00', 'enviado'),
(26, 25, 'Información de planes Zimbra - Productora Audiovisual Enfoque', 'Hola David, le escribimos en relación con información de planes zimbra - productora audiovisual enfoque...', '2026-05-23 13:30:00', 'enviado'),
(27, 10, 'Invitación a demostración - Panadería Industrial Trigal', 'Hola Fabián, le escribimos en relación con invitación a demostración - panadería industrial trigal...', '2026-09-16 08:00:00', 'enviado'),
(28, 2, 'Confirmación de pago - Tecnología Andina S.A.S.', 'Hola Andrea, le escribimos en relación con confirmación de pago - tecnología andina s.a.s....', '2026-10-04 14:45:00', 'enviado'),
(29, 3, 'Bienvenida como cliente - Inversiones Pacífico S.A.', 'Hola Valentina, le escribimos en relación con bienvenida como cliente - inversiones pacífico s.a....', NULL, 'borrador'),
(30, 3, 'Propuesta comercial - Logística del Norte S.A.S.', 'Hola Sandra Milena, le escribimos en relación con propuesta comercial - logística del norte s.a.s....', '2026-04-14 13:15:00', 'enviado');

INSERT INTO correos_destinatarios (id_destinatario, id_correo, correo, tipo) VALUES
(1, 1, 'juan.perez@tecandina.com', 'para'),
(2, 1, 'andrea.salazar@tecandina.com', 'cc'),
(3, 2, 'andrea.salazar@tecandina.com', 'para'),
(4, 3, 'contacto@tecandina.com', 'para'),
(5, 3, 'maria.lopez@correo.com', 'para'),
(6, 4, 'valentina.cruz@invpacifico.com', 'para'),
(7, 5, 'equipo@zimbra-demo.com', 'para'),
(8, 6, 'veronica.rodriguez@constructorahorizo.com.co', 'para'),
(9, 6, 'ventas@zimbra-demo.com', 'cco'),
(10, 7, 'catalina.valencia@universidadtecnolo.com.co', 'para'),
(11, 8, 'gabriel.garcia@hotelmiradorandino.com.co', 'para'),
(12, 8, 'ventas@zimbra-demo.com', 'cco'),
(13, 9, 'sebastian.quintero16@correo.com', 'para'),
(14, 10, 'lina.rodriguez@colegionuevohorizo.com.co', 'para'),
(15, 10, 'ventas@zimbra-demo.com', 'cco'),
(16, 11, 'paola.castro@segurosconfianzapl.com.co', 'para'),
(17, 12, 'ivan.patino@alcaldiamunicipald.com.co', 'para'),
(18, 12, 'ventas@zimbra-demo.com', 'cco'),
(19, 13, 'felipe.arango@energiaverdecolomb.com.co', 'para'),
(20, 14, 'juan.camilo.quintero28@correo.com', 'para'),
(21, 14, 'ventas@zimbra-demo.com', 'cco'),
(22, 15, 'alejandro.bermudez@softwarefactorybog.com.co', 'para'),
(23, 16, 'tomas.pena@restaurantessaborc.com.co', 'para'),
(24, 16, 'ventas@zimbra-demo.com', 'cco'),
(25, 17, 'miguel.ortiz@editorialpaginasab.com.co', 'para'),
(26, 18, 'lina.mejia@centromedicosantal.com.co', 'para'),
(27, 18, 'ventas@zimbra-demo.com', 'cco'),
(28, 19, 'andres.quintero40@correo.com', 'para'),
(29, 20, 'tomas.castro@grupologisticoatla.com.co', 'para'),
(30, 20, 'ventas@zimbra-demo.com', 'cco'),
(31, 21, 'mateo.suarez@institutodeidiomas.com.co', 'para'),
(32, 22, 'andres.cortes@pinturasarcoiris.com.co', 'para'),
(33, 22, 'ventas@zimbra-demo.com', 'cco'),
(34, 23, 'mariana.gutierrez@lacteoslapradera.com.co', 'para'),
(35, 24, 'german.quintero52@correo.com', 'para'),
(36, 24, 'ventas@zimbra-demo.com', 'cco'),
(37, 25, 'gloria.romero@tiendavirtualcompr.com.co', 'para'),
(38, 26, 'david.cortes@productoraaudiovis.com.co', 'para'),
(39, 26, 'ventas@zimbra-demo.com', 'cco'),
(40, 27, 'fabian.ruiz@panaderiaindustria.com.co', 'para'),
(41, 28, 'andrea.salazar@tecandina.com', 'para'),
(42, 28, 'ventas@zimbra-demo.com', 'cco'),
(43, 29, 'valentina.cruz@invpacifico.com', 'para'),
(44, 30, 'sandra.rios@logisnorte.com', 'para'),
(45, 30, 'ventas@zimbra-demo.com', 'cco');

-- ------------------------------------------------------------
-- 14. Reportes y auditoría
-- ------------------------------------------------------------
INSERT INTO reportes_generados (id_reporte, id_usuario, nombre, tipo, archivo, fecha_generacion) VALUES
(1, 1, 'Reporte de ventas octubre 2026', 'ventas', '/reportes/ventas-2026-10.pdf', '2026-11-01 07:30:00'),
(2, 1, 'Reporte de oportunidades abiertas', 'oportunidades', '/reportes/oportunidades-2026-11.xlsx', '2026-11-02 08:15:00'),
(3, 2, 'Desempeño del equipo comercial', 'vendedores', '/reportes/equipo-2026-10.pdf', '2026-11-02 09:00:00'),
(4, 5, 'Resultados campaña webinar', 'campanas', '/reportes/campana-webinar.xlsx', '2026-09-20 16:00:00'),
(5, 1, 'Reporte de ventas enero 2026', 'ventas', '/reportes/ventas-2026-01.pdf', '2026-02-01 07:30:00'),
(6, 1, 'Reporte de ventas febrero 2026', 'ventas', '/reportes/ventas-2026-02.pdf', '2026-03-01 07:30:00'),
(7, 1, 'Reporte de ventas marzo 2026', 'ventas', '/reportes/ventas-2026-03.pdf', '2026-04-01 07:30:00'),
(8, 1, 'Reporte de ventas abril 2026', 'ventas', '/reportes/ventas-2026-04.pdf', '2026-05-01 07:30:00'),
(9, 1, 'Reporte de ventas mayo 2026', 'ventas', '/reportes/ventas-2026-05.pdf', '2026-06-01 07:30:00'),
(10, 1, 'Reporte de ventas junio 2026', 'ventas', '/reportes/ventas-2026-06.pdf', '2026-07-01 07:30:00'),
(11, 1, 'Reporte de ventas julio 2026', 'ventas', '/reportes/ventas-2026-07.pdf', '2026-08-01 07:30:00'),
(12, 1, 'Reporte de ventas agosto 2026', 'ventas', '/reportes/ventas-2026-08.pdf', '2026-09-01 07:30:00'),
(13, 1, 'Reporte de ventas septiembre 2026', 'ventas', '/reportes/ventas-2026-09.pdf', '2026-10-01 07:30:00'),
(14, 38, 'Desempeño de vendedores enero 2026', 'vendedores', '/reportes/vendedores-2026-01.pdf', '2026-02-02 08:00:00'),
(15, 38, 'Desempeño de vendedores febrero 2026', 'vendedores', '/reportes/vendedores-2026-02.pdf', '2026-03-02 08:00:00'),
(16, 38, 'Desempeño de vendedores marzo 2026', 'vendedores', '/reportes/vendedores-2026-03.pdf', '2026-04-02 08:00:00'),
(17, 38, 'Desempeño de vendedores abril 2026', 'vendedores', '/reportes/vendedores-2026-04.pdf', '2026-05-02 08:00:00'),
(18, 38, 'Desempeño de vendedores mayo 2026', 'vendedores', '/reportes/vendedores-2026-05.pdf', '2026-06-02 08:00:00'),
(19, 38, 'Desempeño de vendedores junio 2026', 'vendedores', '/reportes/vendedores-2026-06.pdf', '2026-07-02 08:00:00'),
(20, 38, 'Desempeño de vendedores julio 2026', 'vendedores', '/reportes/vendedores-2026-07.pdf', '2026-08-02 08:00:00'),
(21, 38, 'Desempeño de vendedores agosto 2026', 'vendedores', '/reportes/vendedores-2026-08.pdf', '2026-09-02 08:00:00'),
(22, 38, 'Desempeño de vendedores septiembre 2026', 'vendedores', '/reportes/vendedores-2026-09.pdf', '2026-10-02 08:00:00'),
(23, 38, 'Desempeño de vendedores octubre 2026', 'vendedores', '/reportes/vendedores-2026-10.pdf', '2026-11-02 08:00:00'),
(24, 33, 'Resultados de campañas (corte 1)', 'campanas', '/reportes/campanas-corte-1.xlsx', '2026-03-15 16:00:00'),
(25, 34, 'Resultados de campañas (corte 2)', 'campanas', '/reportes/campanas-corte-2.xlsx', '2026-04-15 16:00:00'),
(26, 35, 'Resultados de campañas (corte 3)', 'campanas', '/reportes/campanas-corte-3.xlsx', '2026-05-15 16:00:00'),
(27, 36, 'Resultados de campañas (corte 4)', 'campanas', '/reportes/campanas-corte-4.xlsx', '2026-06-15 16:00:00'),
(28, 37, 'Resultados de campañas (corte 5)', 'campanas', '/reportes/campanas-corte-5.xlsx', '2026-07-15 16:00:00'),
(29, 33, 'Resultados de campañas (corte 6)', 'campanas', '/reportes/campanas-corte-6.xlsx', '2026-08-15 16:00:00'),
(30, 34, 'Resultados de campañas (corte 7)', 'campanas', '/reportes/campanas-corte-7.xlsx', '2026-09-15 16:00:00');

INSERT INTO auditoria (id_auditoria, id_usuario, tabla_afectada, operacion, registro_id, descripcion, fecha) VALUES
(1, 1, 'usuarios', 'INSERT', 5, 'Se creó el usuario Sofía Torres.', '2026-09-01 08:00:00'),
(2, 2, 'clientes', 'INSERT', 1, 'Se registró el cliente Tecnología Andina S.A.S.', '2026-09-05 09:15:00'),
(3, 2, 'oportunidades', 'INSERT', 1, 'Se creó la oportunidad de migración de correo.', '2026-09-10 09:00:00'),
(4, 3, 'propuestas', 'UPDATE', 3, 'La propuesta cambió de enviada a aceptada.', '2026-09-25 17:30:00'),
(5, 2, 'ventas', 'INSERT', 1, 'Se registró la venta a Inversiones Pacífico S.A.', '2026-10-05 12:30:00'),
(6, 4, 'tareas', 'UPDATE', 3, 'La tarea de kickoff se marcó como completada.', '2026-10-08 16:05:00'),
(7, 5, 'campanas_marketing', 'INSERT', 3, 'Se creó la campaña de fin de año.', '2026-11-01 10:00:00'),
(8, 1, 'usuarios', 'UPDATE', 5, 'Se desactivó el usuario Sofía Torres.', '2026-11-03 09:30:00'),
(9, 3, 'ventas', 'INSERT', 5, 'Se registró la venta #5 por 8352000.', '2026-01-06 17:15:00'),
(10, 8, 'ventas', 'INSERT', 6, 'Se registró la venta #6 por 54420000.', '2026-02-11 16:45:00'),
(11, 15, 'ventas', 'INSERT', 7, 'Se registró la venta #7 por 31030000.', '2026-03-08 11:00:00'),
(12, 22, 'ventas', 'INSERT', 8, 'Se registró la venta #8 por 14370000.', '2026-04-25 12:15:00'),
(13, 29, 'ventas', 'INSERT', 9, 'Se registró la venta #9 por 16360000.', '2026-05-24 09:15:00'),
(14, 7, 'ventas', 'INSERT', 10, 'Se registró la venta #10 por 14530000.', '2026-06-13 13:15:00'),
(15, 14, 'ventas', 'INSERT', 11, 'Se registró la venta #11 por 22828000.', '2026-07-15 12:00:00'),
(16, 21, 'ventas', 'INSERT', 12, 'Se registró la venta #12 por 21470000.', '2026-08-03 17:45:00'),
(17, 28, 'ventas', 'INSERT', 13, 'Se registró la venta #13 por 18100000.', '2026-09-07 17:30:00'),
(18, 6, 'ventas', 'INSERT', 14, 'Se registró la venta #14 por 4092000.', '2026-10-12 14:30:00'),
(19, 13, 'ventas', 'INSERT', 15, 'Se registró la venta #15 por 21195000.', '2026-11-11 14:45:00'),
(20, 20, 'ventas', 'INSERT', 16, 'Se registró la venta #16 por 18855000.', '2026-01-02 08:30:00'),
(21, 27, 'ventas', 'INSERT', 17, 'Se registró la venta #17 por 31047000.', '2026-02-15 16:30:00'),
(22, 4, 'ventas', 'INSERT', 18, 'Se registró la venta #18 por 32280000.', '2026-03-23 16:45:00'),
(23, 12, 'ventas', 'INSERT', 19, 'Se registró la venta #19 por 45880000.', '2026-04-04 08:30:00'),
(24, 19, 'ventas', 'INSERT', 20, 'Se registró la venta #20 por 15274000.', '2026-05-18 13:45:00'),
(25, 26, 'ventas', 'INSERT', 21, 'Se registró la venta #21 por 30720000.', '2026-06-20 15:00:00'),
(26, 3, 'ventas', 'INSERT', 22, 'Se registró la venta #22 por 30130000.', '2026-07-07 11:30:00'),
(27, 11, 'ventas', 'INSERT', 23, 'Se registró la venta #23 por 33240000.', '2026-08-24 10:00:00'),
(28, 18, 'ventas', 'INSERT', 24, 'Se registró la venta #24 por 40507000.', '2026-09-09 14:15:00'),
(29, 25, 'ventas', 'INSERT', 25, 'Se registró la venta #25 por 21120000.', '2026-10-07 14:45:00'),
(30, 2, 'ventas', 'INSERT', 26, 'Se registró la venta #26 por 20515000.', '2026-11-09 08:30:00');



-- ============================================================
-- PARTE 3. FUNCIONES UDF (Sesión 3)
-- Van después de los datos de prueba a propósito: así los triggers
-- de la PARTE 4 no se disparan durante la carga inicial.
--
-- Todas declaran DETERMINISTIC / NO SQL / READS SQL DATA: con el
-- registro binario activo (lo normal en MySQL 8) es obligatorio.
-- ============================================================

DELIMITER //

-- Puntos que aporta cada acción del cliente. Si cambian los pesos,
-- se cambian solo aquí.
CREATE FUNCTION fn_puntos_accion(p_accion VARCHAR(100))
RETURNS INT
DETERMINISTIC
NO SQL
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

-- Puntaje de interés de un cliente en los últimos 30 días
CREATE FUNCTION fn_puntaje_cliente(p_id_cliente INT)
RETURNS INT
READS SQL DATA
RETURN (
    SELECT COALESCE(SUM(fn_puntos_accion(a.accion)), 0)
    FROM actividad_web a
    WHERE a.id_cliente = p_id_cliente
      AND a.fecha >= NOW() - INTERVAL 30 DAY
) //

-- Valor de una propuesta = suma de sus líneas
CREATE FUNCTION fn_total_propuesta(p_id_propuesta INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
RETURN (
    SELECT COALESCE(SUM(d.subtotal), 0)
    FROM propuestas_detalles d
    WHERE d.id_propuesta = p_id_propuesta
) //

-- Total de una venta = suma de sus productos
CREATE FUNCTION fn_total_venta(p_id_venta INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
RETURN (
    SELECT COALESCE(SUM(vp.subtotal), 0)
    FROM ventas_productos vp
    WHERE vp.id_venta = p_id_venta
) //

-- Dinero efectivamente recibido (solo pagos aprobados)
CREATE FUNCTION fn_total_pagado(p_id_venta INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
RETURN (
    SELECT COALESCE(SUM(p.valor), 0)
    FROM pagos p
    WHERE p.id_venta = p_id_venta
      AND p.estado = 'aprobado'
) //

-- Saldo que todavía se puede cobrar: total menos pagos aprobados y
-- pendientes de aprobación. Una venta cancelada no tiene saldo.
-- NULL si la venta no existe.
CREATE FUNCTION fn_saldo_venta(p_id_venta INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
RETURN (
    SELECT IF(v.estado = 'cancelada', 0, v.total - COALESCE((
        SELECT SUM(p.valor)
        FROM pagos p
        WHERE p.id_venta = v.id_venta
          AND p.estado IN ('aprobado', 'pendiente')
    ), 0))
    FROM ventas v
    WHERE v.id_venta = p_id_venta
) //

-- Comisión del vendedor en un mes: 5 % de sus ventas pagadas
CREATE FUNCTION fn_comision_vendedor(p_id_vendedor INT, p_anio INT, p_mes INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
RETURN ROUND(0.05 * (
    SELECT COALESCE(SUM(v.total), 0)
    FROM ventas v
    WHERE v.id_vendedor = p_id_vendedor
      AND v.estado = 'pagada'
      AND v.fecha >= MAKEDATE(p_anio, 1) + INTERVAL (p_mes - 1) MONTH
      AND v.fecha <  MAKEDATE(p_anio, 1) + INTERVAL p_mes MONTH
), 2) //

-- Tasa de conversión del vendedor: % de oportunidades cerradas que ganó
CREATE FUNCTION fn_tasa_conversion(p_id_vendedor INT)
RETURNS DECIMAL(5,2)
READS SQL DATA
RETURN (
    SELECT COALESCE(ROUND(100 * SUM(o.estado = 'ganada') / NULLIF(COUNT(*), 0), 2), 0)
    FROM oportunidades o
    WHERE o.id_vendedor = p_id_vendedor
      AND o.estado IN ('ganada', 'perdida')
) //

DELIMITER ;

-- ============================================================
-- PARTE 4. TRIGGERS, PROCEDIMIENTOS ALMACENADOS Y EVENTO (Sesión 3)
--  4.1 Procedimientos de apoyo
--  4.2 Triggers de reglas de negocio (estado de propuestas, stock,
--      totales, pagos, conversión de prospectos)
--  4.3 Triggers de actividad del cliente
--  4.4 Auditoría automática
--  4.5 Procedimientos transaccionales y de reportes
--  4.6 Clasificación de clientes potenciales + EVENTO
-- ============================================================

DELIMITER //

-- ------------------------------------------------------------
-- 4.1 Procedimientos de apoyo
-- ------------------------------------------------------------

-- El backend puede hacer  SET @usuario_actual = <id>;  antes de operar.
-- Si no lo hace (o el id no existe) se guarda NULL, sin romper nada.
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

-- Una venta (no cancelada) está pagada cuando los pagos aprobados
-- cubren su total; si no, queda pendiente.
CREATE PROCEDURE sp_recalcular_estado_venta(IN p_id_venta INT)
BEGIN
    UPDATE ventas
    SET estado = IF(total > 0 AND fn_total_pagado(id_venta) >= total, 'pagada', 'pendiente')
    WHERE id_venta = p_id_venta
      AND estado <> 'cancelada';
END //

-- ------------------------------------------------------------
-- 4.2 Triggers de reglas de negocio
-- ------------------------------------------------------------

-- PROPUESTAS: transiciones válidas de estado
--   borrador -> enviada -> aceptada | rechazada  (aceptada y rechazada son finales)
CREATE TRIGGER trg_propuestas_validar_estado
BEFORE UPDATE ON propuestas
FOR EACH ROW
BEGIN
    IF NEW.estado <> OLD.estado THEN
        IF OLD.estado IN ('aceptada', 'rechazada') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La propuesta ya está cerrada (aceptada o rechazada) y no puede cambiar de estado';
        END IF;
        IF NEW.estado IN ('enviada', 'aceptada') AND NEW.valor_total <= 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No se puede enviar ni aceptar una propuesta sin productos';
        END IF;
    END IF;
END //

-- PROPUESTAS: el estado de la propuesta mueve la oportunidad
--   enviada   -> la oportunidad pasa al menos a 'Propuesta enviada'
--   aceptada  -> oportunidad ganada (etapa 'Cierre ganado')
--   rechazada -> oportunidad perdida, si no le quedan otras propuestas abiertas
-- y el valor de la propuesta se copia como valor estimado.
CREATE TRIGGER trg_propuestas_actualizar_oportunidad
AFTER UPDATE ON propuestas
FOR EACH ROW
BEGIN
    IF NEW.valor_total <> OLD.valor_total THEN
        UPDATE oportunidades
        SET valor_estimado = NEW.valor_total
        WHERE id_oportunidad = NEW.id_oportunidad
          AND estado = 'abierta';
    END IF;

    IF NEW.estado <> OLD.estado THEN
        IF NEW.estado = 'enviada' THEN
            UPDATE oportunidades
            SET id_etapa = 3
            WHERE id_oportunidad = NEW.id_oportunidad
              AND estado = 'abierta'
              AND COALESCE(id_etapa, 1) < 3;
        ELSEIF NEW.estado = 'aceptada' THEN
            UPDATE oportunidades
            SET estado = 'ganada',
                id_etapa = 5,
                valor_estimado = NEW.valor_total,
                fecha_cierre = CURDATE()
            WHERE id_oportunidad = NEW.id_oportunidad
              AND estado <> 'ganada';
        ELSEIF NEW.estado = 'rechazada' THEN
            UPDATE oportunidades
            SET estado = 'perdida',
                id_etapa = 6,
                fecha_cierre = CURDATE()
            WHERE id_oportunidad = NEW.id_oportunidad
              AND estado = 'abierta'
              AND NOT EXISTS (
                  SELECT 1 FROM propuestas p
                  WHERE p.id_oportunidad = NEW.id_oportunidad
                    AND p.id_propuesta <> NEW.id_propuesta
                    AND p.estado IN ('borrador', 'enviada', 'aceptada')
              );
        END IF;
    END IF;
END //

-- DETALLE DE PROPUESTAS: el subtotal se calcula solo y no se pueden
-- tocar las líneas de una propuesta cerrada.
CREATE TRIGGER trg_propuestas_detalles_validar
BEFORE INSERT ON propuestas_detalles
FOR EACH ROW
BEGIN
    IF (SELECT estado FROM propuestas WHERE id_propuesta = NEW.id_propuesta) IN ('aceptada', 'rechazada') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se pueden agregar productos a una propuesta cerrada';
    END IF;
    IF (SELECT estado FROM productos WHERE id_producto = NEW.id_producto) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El producto está inactivo y no se puede ofrecer';
    END IF;
    SET NEW.subtotal = NEW.cantidad * NEW.precio_unitario;
END //

CREATE TRIGGER trg_propuestas_detalles_validar_upd
BEFORE UPDATE ON propuestas_detalles
FOR EACH ROW
SET NEW.subtotal = NEW.cantidad * NEW.precio_unitario //

-- DETALLE DE PROPUESTAS: valor_total siempre = suma de las líneas
CREATE TRIGGER trg_propuestas_detalles_total_ins
AFTER INSERT ON propuestas_detalles
FOR EACH ROW
UPDATE propuestas SET valor_total = fn_total_propuesta(NEW.id_propuesta)
WHERE id_propuesta = NEW.id_propuesta //

CREATE TRIGGER trg_propuestas_detalles_total_upd
AFTER UPDATE ON propuestas_detalles
FOR EACH ROW
UPDATE propuestas SET valor_total = fn_total_propuesta(NEW.id_propuesta)
WHERE id_propuesta = NEW.id_propuesta //

CREATE TRIGGER trg_propuestas_detalles_total_del
AFTER DELETE ON propuestas_detalles
FOR EACH ROW
UPDATE propuestas SET valor_total = fn_total_propuesta(OLD.id_propuesta)
WHERE id_propuesta = OLD.id_propuesta //

-- VENTAS: una venta con propuesta solo se acepta si la propuesta está
-- enviada o aceptada y es del mismo cliente.
CREATE TRIGGER trg_ventas_validar_propuesta
BEFORE INSERT ON ventas
FOR EACH ROW
BEGIN
    IF NEW.id_propuesta IS NOT NULL THEN
        IF (SELECT estado FROM propuestas WHERE id_propuesta = NEW.id_propuesta) NOT IN ('enviada', 'aceptada') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Solo se puede vender una propuesta enviada o aceptada (no borradores ni rechazadas)';
        END IF;
        IF (SELECT o.id_cliente
            FROM propuestas p
            JOIN oportunidades o ON o.id_oportunidad = p.id_oportunidad
            WHERE p.id_propuesta = NEW.id_propuesta) <> NEW.id_cliente THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El cliente de la venta no coincide con el de la propuesta';
        END IF;
    END IF;
END //

-- VENTAS: al vender una propuesta, la propuesta queda ACEPTADA (y por
-- el trigger anterior la oportunidad queda GANADA). Además el prospecto
-- se convierte en 'Cliente activo'.
CREATE TRIGGER trg_ventas_aceptar_propuesta
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    IF NEW.id_propuesta IS NOT NULL THEN
        UPDATE propuestas
        SET estado = 'aceptada'
        WHERE id_propuesta = NEW.id_propuesta
          AND estado <> 'aceptada';
    END IF;

    INSERT IGNORE INTO clientes_categorias (id_cliente, id_categoria)
    SELECT NEW.id_cliente, id_categoria
    FROM categorias_clientes
    WHERE nombre = 'Cliente activo';

    DELETE cc FROM clientes_categorias cc
    JOIN categorias_clientes cat ON cat.id_categoria = cc.id_categoria
    WHERE cc.id_cliente = NEW.id_cliente
      AND cat.nombre IN ('Prospecto', 'Potencial', 'Inactivo');
END //

-- VENTAS: una venta cancelada no se reactiva, y no se cancela si ya
-- recibió pagos aprobados.
CREATE TRIGGER trg_ventas_validar_estado
BEFORE UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF OLD.estado = 'cancelada' AND NEW.estado <> 'cancelada' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Una venta cancelada no se puede reactivar';
    END IF;
    IF NEW.estado = 'cancelada' AND OLD.estado <> 'cancelada'
       AND fn_total_pagado(NEW.id_venta) > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cancelar una venta con pagos aprobados';
    END IF;
END //

-- VENTAS: al cancelar, el stock vuelve al inventario
CREATE TRIGGER trg_ventas_devolver_stock
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'cancelada' AND OLD.estado <> 'cancelada' THEN
        UPDATE productos p
        JOIN ventas_productos vp ON vp.id_producto = p.id_producto
        SET p.stock = p.stock + vp.cantidad
        WHERE vp.id_venta = NEW.id_venta;
    END IF;
END //

-- PRODUCTOS VENDIDOS: valida stock y calcula el subtotal
CREATE TRIGGER trg_ventas_productos_validar
BEFORE INSERT ON ventas_productos
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    DECLARE v_msg VARCHAR(255);

    IF (SELECT estado FROM ventas WHERE id_venta = NEW.id_venta) <> 'pendiente' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se pueden agregar productos a una venta pendiente';
    END IF;

    SET v_stock = (SELECT stock FROM productos WHERE id_producto = NEW.id_producto);
    IF v_stock < NEW.cantidad THEN
        SET v_msg = CONCAT('Stock insuficiente para el producto #', NEW.id_producto,
                           ': disponible ', v_stock, ', solicitado ', NEW.cantidad);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SET NEW.subtotal = NEW.cantidad * NEW.precio_unitario;
END //

-- PRODUCTOS VENDIDOS: descuenta stock y recalcula el total de la venta
CREATE TRIGGER trg_ventas_productos_despues_ins
AFTER INSERT ON ventas_productos
FOR EACH ROW
BEGIN
    UPDATE productos SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.id_producto;

    UPDATE ventas SET total = fn_total_venta(NEW.id_venta)
    WHERE id_venta = NEW.id_venta;
END //

CREATE TRIGGER trg_ventas_productos_despues_del
AFTER DELETE ON ventas_productos
FOR EACH ROW
BEGIN
    UPDATE productos SET stock = stock + OLD.cantidad
    WHERE id_producto = OLD.id_producto;

    UPDATE ventas SET total = fn_total_venta(OLD.id_venta)
    WHERE id_venta = OLD.id_venta;
END //

-- PAGOS: no se paga una venta cancelada ni se supera el saldo
CREATE TRIGGER trg_pagos_validar
BEFORE INSERT ON pagos
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(255);

    IF (SELECT estado FROM ventas WHERE id_venta = NEW.id_venta) = 'cancelada' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se pueden registrar pagos en una venta cancelada';
    END IF;

    IF NEW.estado <> 'rechazado' AND NEW.valor > fn_saldo_venta(NEW.id_venta) THEN
        SET v_msg = CONCAT('El pago de ', NEW.valor, ' supera el saldo pendiente de ',
                           fn_saldo_venta(NEW.id_venta));
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END //

-- PAGOS: un pago aprobado o rechazado ya no cambia de estado
CREATE TRIGGER trg_pagos_validar_estado
BEFORE UPDATE ON pagos
FOR EACH ROW
BEGIN
    IF NEW.estado <> OLD.estado AND OLD.estado IN ('aprobado', 'rechazado') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pago ya fue procesado (aprobado o rechazado) y no puede cambiar';
    END IF;
END //

-- PAGOS: cada pago nuevo o aprobado recalcula el estado de la venta
CREATE TRIGGER trg_pagos_estado_venta_ins
AFTER INSERT ON pagos
FOR EACH ROW
CALL sp_recalcular_estado_venta(NEW.id_venta) //

CREATE TRIGGER trg_pagos_estado_venta_upd
AFTER UPDATE ON pagos
FOR EACH ROW
CALL sp_recalcular_estado_venta(NEW.id_venta) //

-- ------------------------------------------------------------
-- 4.3 Actividad del cliente
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
VALUES (NEW.id_cliente, 'compra', CONCAT('Venta #', NEW.id_venta, ' registrada')) //

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
-- 4.4 Auditoría automática de las tablas comerciales
-- ------------------------------------------------------------

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

-- propuestas (UPDATE solo cuando cambia el estado o el valor)
CREATE TRIGGER trg_propuestas_auditar_insert AFTER INSERT ON propuestas FOR EACH ROW
CALL registrar_auditoria('propuestas', 'INSERT', NEW.id_propuesta, CONCAT('Propuesta creada (', NEW.estado, ')')) //
CREATE TRIGGER trg_propuestas_auditar_update AFTER UPDATE ON propuestas FOR EACH ROW
BEGIN
    IF NEW.estado <> OLD.estado THEN
        CALL registrar_auditoria('propuestas', 'UPDATE', NEW.id_propuesta, CONCAT('Propuesta: ', OLD.estado, ' -> ', NEW.estado));
    ELSEIF NEW.valor_total <> OLD.valor_total THEN
        CALL registrar_auditoria('propuestas', 'UPDATE', NEW.id_propuesta, CONCAT('Propuesta: valor ', OLD.valor_total, ' -> ', NEW.valor_total));
    END IF;
END //
CREATE TRIGGER trg_propuestas_auditar_delete AFTER DELETE ON propuestas FOR EACH ROW
CALL registrar_auditoria('propuestas', 'DELETE', OLD.id_propuesta, CONCAT('Propuesta eliminada: ', OLD.valor_total)) //

-- ventas (UPDATE solo cuando cambia el estado)
CREATE TRIGGER trg_ventas_auditar_insert AFTER INSERT ON ventas FOR EACH ROW
CALL registrar_auditoria('ventas', 'INSERT', NEW.id_venta, CONCAT('Venta registrada para el cliente #', NEW.id_cliente)) //
CREATE TRIGGER trg_ventas_auditar_update AFTER UPDATE ON ventas FOR EACH ROW
BEGIN
    IF NEW.estado <> OLD.estado THEN
        CALL registrar_auditoria('ventas', 'UPDATE', NEW.id_venta, CONCAT('Venta: ', OLD.estado, ' -> ', NEW.estado, ' / total ', NEW.total));
    END IF;
END //
CREATE TRIGGER trg_ventas_auditar_delete AFTER DELETE ON ventas FOR EACH ROW
CALL registrar_auditoria('ventas', 'DELETE', OLD.id_venta, CONCAT('Venta eliminada por ', OLD.total)) //

-- pagos
CREATE TRIGGER trg_pagos_auditar_insert AFTER INSERT ON pagos FOR EACH ROW
CALL registrar_auditoria('pagos', 'INSERT', NEW.id_pago, CONCAT('Pago registrado: ', NEW.valor, ' (', NEW.estado, ')')) //
CREATE TRIGGER trg_pagos_auditar_update AFTER UPDATE ON pagos FOR EACH ROW
CALL registrar_auditoria('pagos', 'UPDATE', NEW.id_pago, CONCAT('Pago actualizado: ', OLD.estado, ' -> ', NEW.estado)) //
CREATE TRIGGER trg_pagos_auditar_delete AFTER DELETE ON pagos FOR EACH ROW
CALL registrar_auditoria('pagos', 'DELETE', OLD.id_pago, CONCAT('Pago eliminado: ', OLD.valor)) //

-- ------------------------------------------------------------
-- 4.5 Procedimientos transaccionales y de reportes
-- ------------------------------------------------------------

-- Registra un pago aprobado sobre una venta pendiente.
--   p_valor NULL -> paga todo el saldo.
-- SELECT ... FOR UPDATE bloquea la venta: si dos cajeros pagan la
-- misma venta a la vez, el segundo espera y luego ve el saldo real.
-- Nota: START TRANSACTION confirma cualquier transacción abierta del
-- llamador; llámelo fuera de una transacción.
CREATE PROCEDURE procesar_pago_venta(
    IN p_id_venta INT,
    IN p_metodo VARCHAR(50),
    IN p_valor DECIMAL(12,2)
)
BEGIN
    DECLARE v_estado VARCHAR(20) DEFAULT NULL;
    DECLARE v_saldo DECIMAL(12,2);
    DECLARE v_valor DECIMAL(12,2);
    DECLARE v_id_pago INT;
    DECLARE v_msg VARCHAR(255);

    -- Si algo falla, se deshace todo y el error llega al llamador
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT estado INTO v_estado
    FROM ventas
    WHERE id_venta = p_id_venta
    FOR UPDATE;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta no existe';
    END IF;

    IF v_estado <> 'pendiente' THEN
        SET v_msg = CONCAT('La venta no está pendiente (estado: ', v_estado, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SET v_saldo = fn_saldo_venta(p_id_venta);

    IF v_saldo <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La venta no tiene saldo por cobrar (hay pagos pendientes de aprobación)';
    END IF;

    SET v_valor = COALESCE(p_valor, v_saldo);

    IF v_valor <= 0 OR v_valor > v_saldo THEN
        SET v_msg = CONCAT('El valor debe ser mayor que 0 y no superar el saldo de ', v_saldo);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    INSERT INTO pagos (id_venta, metodo_pago, valor, estado)
    VALUES (p_id_venta, COALESCE(NULLIF(TRIM(p_metodo), ''), 'transferencia'), v_valor, 'aprobado');
    SET v_id_pago = LAST_INSERT_ID();

    COMMIT;

    SELECT v_id_pago AS id_pago,
           v.id_venta,
           v.total,
           fn_total_pagado(v.id_venta) AS pagado,
           fn_saldo_venta(v.id_venta)  AS saldo,
           v.estado
    FROM ventas v
    WHERE v.id_venta = p_id_venta;
END //

-- Convierte una propuesta (enviada o aceptada) en venta, copiando sus
-- productos. Todo o nada: si falta stock de un producto, no queda ni
-- la venta ni sus líneas. El FOR UPDATE sobre la propuesta y la llave
-- única uk_ventas_propuesta impiden venderla dos veces.
CREATE PROCEDURE sp_registrar_venta_desde_propuesta(IN p_id_propuesta INT)
BEGIN
    DECLARE v_estado VARCHAR(20) DEFAULT NULL;
    DECLARE v_cliente INT;
    DECLARE v_vendedor INT;
    DECLARE v_id_venta INT;
    DECLARE v_msg VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT p.estado, o.id_cliente, o.id_vendedor
      INTO v_estado, v_cliente, v_vendedor
    FROM propuestas p
    JOIN oportunidades o ON o.id_oportunidad = p.id_oportunidad
    WHERE p.id_propuesta = p_id_propuesta
    FOR UPDATE;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La propuesta no existe';
    END IF;

    SET v_id_venta = (SELECT id_venta FROM ventas WHERE id_propuesta = p_id_propuesta);
    IF v_id_venta IS NOT NULL THEN
        SET v_msg = CONCAT('La propuesta ya se convirtió en la venta #', v_id_venta);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    INSERT INTO ventas (id_cliente, id_vendedor, id_propuesta, fecha, total, estado)
    VALUES (v_cliente, v_vendedor, p_id_propuesta, NOW(), 0, 'pendiente');
    SET v_id_venta = LAST_INSERT_ID();

    INSERT INTO ventas_productos (id_venta, id_producto, cantidad, precio_unitario, subtotal)
    SELECT v_id_venta, d.id_producto, d.cantidad, d.precio_unitario, d.subtotal
    FROM propuestas_detalles d
    WHERE d.id_propuesta = p_id_propuesta;

    COMMIT;

    SELECT v.id_venta, v.id_cliente, v.id_vendedor, v.id_propuesta, v.fecha,
           v.total, v.estado, fn_saldo_venta(v.id_venta) AS saldo
    FROM ventas v
    WHERE v.id_venta = v_id_venta;
END //

-- Reporte mensual de ventas. Devuelve 3 resultados:
--   1) resumen del mes y variación frente al mes anterior
--   2) desempeño por vendedor (comisión y conversión con UDF)
--   3) los 5 productos más vendidos
-- Si se envía p_id_usuario, deja constancia en reportes_generados.
CREATE PROCEDURE sp_reporte_ventas_mensual(
    IN p_anio INT,
    IN p_mes INT,
    IN p_id_usuario INT
)
BEGIN
    DECLARE v_desde DATE;
    DECLARE v_hasta DATE;
    DECLARE v_mes_nombre VARCHAR(20);
    DECLARE v_total_anterior DECIMAL(14,2);

    IF p_mes IS NULL OR p_mes NOT BETWEEN 1 AND 12 OR p_anio IS NULL OR p_anio NOT BETWEEN 2000 AND 2100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Año o mes inválido';
    END IF;

    SET v_desde = MAKEDATE(p_anio, 1) + INTERVAL (p_mes - 1) MONTH;
    SET v_hasta = v_desde + INTERVAL 1 MONTH;
    SET v_mes_nombre = ELT(p_mes, 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
                           'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre');

    SET v_total_anterior = (
        SELECT COALESCE(SUM(total), 0) FROM ventas
        WHERE estado <> 'cancelada'
          AND fecha >= v_desde - INTERVAL 1 MONTH AND fecha < v_desde
    );

    -- 1) Resumen
    SELECT p_anio AS anio,
           p_mes AS mes,
           v_mes_nombre AS mes_nombre,
           COUNT(*) AS ventas,
           SUM(v.estado = 'pagada') AS pagadas,
           SUM(v.estado = 'pendiente') AS pendientes,
           SUM(v.estado = 'cancelada') AS canceladas,
           COALESCE(SUM(IF(v.estado <> 'cancelada', v.total, 0)), 0) AS total_vendido,
           COALESCE(SUM(IF(v.estado <> 'cancelada', fn_total_pagado(v.id_venta), 0)), 0) AS total_recaudado,
           COALESCE(SUM(IF(v.estado = 'pendiente', v.total - fn_total_pagado(v.id_venta), 0)), 0) AS cartera_pendiente,
           COALESCE(ROUND(AVG(IF(v.estado <> 'cancelada', v.total, NULL)), 2), 0) AS ticket_promedio,
           v_total_anterior AS total_mes_anterior,
           IF(v_total_anterior = 0, NULL,
              ROUND(100 * (COALESCE(SUM(IF(v.estado <> 'cancelada', v.total, 0)), 0) - v_total_anterior) / v_total_anterior, 2)
           ) AS variacion_pct
    FROM ventas v
    WHERE v.fecha >= v_desde AND v.fecha < v_hasta;

    -- 2) Por vendedor
    SELECT ve.id_vendedor,
           ve.codigo,
           u.nombre AS vendedor,
           COUNT(v.id_venta) AS ventas,
           COALESCE(SUM(v.total), 0) AS total_vendido,
           fn_comision_vendedor(ve.id_vendedor, p_anio, p_mes) AS comision,
           fn_tasa_conversion(ve.id_vendedor) AS tasa_conversion
    FROM ventas v
    JOIN vendedores ve ON ve.id_vendedor = v.id_vendedor
    JOIN usuarios u ON u.id_usuario = ve.id_usuario
    WHERE v.fecha >= v_desde AND v.fecha < v_hasta
      AND v.estado <> 'cancelada'
    GROUP BY ve.id_vendedor, ve.codigo, u.nombre
    ORDER BY total_vendido DESC;

    -- 3) Productos más vendidos
    SELECT p.id_producto,
           p.nombre AS producto,
           SUM(vp.cantidad) AS unidades,
           SUM(vp.subtotal) AS total
    FROM ventas v
    JOIN ventas_productos vp ON vp.id_venta = v.id_venta
    JOIN productos p ON p.id_producto = vp.id_producto
    WHERE v.fecha >= v_desde AND v.fecha < v_hasta
      AND v.estado <> 'cancelada'
    GROUP BY p.id_producto, p.nombre
    ORDER BY total DESC
    LIMIT 5;

    IF p_id_usuario IS NOT NULL AND EXISTS (SELECT 1 FROM usuarios WHERE id_usuario = p_id_usuario) THEN
        INSERT INTO reportes_generados (id_usuario, nombre, tipo, archivo)
        VALUES (p_id_usuario,
                CONCAT('Reporte de ventas ', v_mes_nombre, ' ', p_anio),
                'ventas',
                CONCAT('/api/reportes/mensual?anio=', p_anio, '&mes=', p_mes));
    END IF;
END //

-- Simulación de errores y recuperación (Sesión 2).
-- Abre una transacción, hace un cambio válido y luego provoca a
-- propósito el error pedido. El manejador captura el error con
-- GET DIAGNOSTICS, hace ROLLBACK y demuestra que la base quedó igual.
-- Tipos: llave_foranea, duplicado, restriccion, stock, sobrepago,
--        propuesta_rechazada
CREATE PROCEDURE sp_simular_error(IN p_tipo VARCHAR(30))
BEGIN
    DECLARE v_msg TEXT DEFAULT NULL;
    DECLARE v_errno INT DEFAULT NULL;
    DECLARE v_clientes_antes INT;
    DECLARE v_ventas_antes INT;
    DECLARE v_pagos_antes INT;
    DECLARE v_auditoria_antes INT;
    DECLARE v_clientes_despues INT;
    DECLARE v_ventas_despues INT;
    DECLARE v_pagos_despues INT;
    DECLARE v_auditoria_despues INT;

    SET v_clientes_antes  = (SELECT COUNT(*) FROM clientes);
    SET v_ventas_antes    = (SELECT COUNT(*) FROM ventas);
    SET v_pagos_antes     = (SELECT COUNT(*) FROM pagos);
    SET v_auditoria_antes = (SELECT COUNT(*) FROM auditoria);

    bloque: BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT, v_errno = MYSQL_ERRNO;
            ROLLBACK;
        END;

        START TRANSACTION;

        -- Paso 1 (válido): se registra un cliente. Debe desaparecer con el ROLLBACK.
        INSERT INTO clientes (tipo_cliente, nombre, documento)
        VALUES ('persona', 'Cliente temporal de la simulación', CONCAT('SIM-', UUID_SHORT()));

        -- Paso 2 (falla a propósito)
        CASE p_tipo
            WHEN 'llave_foranea' THEN
                INSERT INTO ventas (id_cliente, total) VALUES (999999, 0);
            WHEN 'duplicado' THEN
                INSERT INTO clientes (tipo_cliente, nombre, documento)
                VALUES ('empresa', 'Documento repetido', '900123456-7');
            WHEN 'restriccion' THEN
                UPDATE productos SET precio = -1 WHERE id_producto = 1;
            WHEN 'stock' THEN
                INSERT INTO ventas (id_cliente, id_vendedor, total) VALUES (1, 1, 0);
                INSERT INTO ventas_productos (id_venta, id_producto, cantidad, precio_unitario, subtotal)
                VALUES (LAST_INSERT_ID(), 21, 1000000, 8500000, 8500000000);
            WHEN 'sobrepago' THEN
                INSERT INTO pagos (id_venta, metodo_pago, valor, estado)
                SELECT id_venta, 'efectivo', 1000, 'aprobado'
                FROM ventas WHERE estado = 'pagada' ORDER BY id_venta LIMIT 1;
            WHEN 'propuesta_rechazada' THEN
                INSERT INTO ventas (id_cliente, id_vendedor, id_propuesta, total)
                SELECT o.id_cliente, o.id_vendedor, p.id_propuesta, 0
                FROM propuestas p
                JOIN oportunidades o ON o.id_oportunidad = p.id_oportunidad
                WHERE p.estado = 'rechazada'
                ORDER BY p.id_propuesta LIMIT 1;
            ELSE
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Tipo no válido. Use: llave_foranea, duplicado, restriccion, stock, sobrepago, propuesta_rechazada';
        END CASE;

        COMMIT; -- no se alcanza: el paso 2 siempre falla
    END bloque;

    SET v_clientes_despues  = (SELECT COUNT(*) FROM clientes);
    SET v_ventas_despues    = (SELECT COUNT(*) FROM ventas);
    SET v_pagos_despues     = (SELECT COUNT(*) FROM pagos);
    SET v_auditoria_despues = (SELECT COUNT(*) FROM auditoria);

    SELECT p_tipo AS simulacion,
           v_errno AS codigo_error,
           v_msg AS error_capturado,
           v_clientes_antes AS clientes_antes,
           v_clientes_despues AS clientes_despues,
           v_ventas_antes AS ventas_antes,
           v_ventas_despues AS ventas_despues,
           v_pagos_antes AS pagos_antes,
           v_pagos_despues AS pagos_despues,
           IF(v_msg IS NOT NULL
              AND v_clientes_antes = v_clientes_despues
              AND v_ventas_antes = v_ventas_despues
              AND v_pagos_antes = v_pagos_despues
              AND v_auditoria_antes = v_auditoria_despues,
              'ROLLBACK correcto: la base de datos quedó exactamente igual',
              'ATENCIÓN: la base de datos cambió') AS resultado;
END //

-- ------------------------------------------------------------
-- 4.6 Clasificación de clientes potenciales
-- Un PROSPECTO es 'Potencial' si en los últimos 30 días cumple las tres
-- condiciones: uso frecuente (días distintos), varias interacciones y
-- puntaje suficiente. Solo se recalcula la marca 'Potencial': la
-- categoría 'Prospecto' (la del formulario de registro) no se toca.
-- ------------------------------------------------------------
CREATE PROCEDURE actualizar_clientes_potenciales()
BEGIN
    DECLARE v_interacciones_minimas INT DEFAULT 5;
    DECLARE v_dias_activos_minimos  INT DEFAULT 3;
    DECLARE v_puntaje_minimo        INT DEFAULT 15;
    DECLARE v_cat_prospecto INT;
    DECLARE v_cat_potencial INT;

    SET v_cat_prospecto = (SELECT id_categoria FROM categorias_clientes WHERE nombre = 'Prospecto');
    SET v_cat_potencial = (SELECT id_categoria FROM categorias_clientes WHERE nombre = 'Potencial');

    -- Se recalcula completa: se retira la marca anterior y se vuelve a
    -- asignar según el comportamiento real.
    DELETE FROM clientes_categorias WHERE id_categoria = v_cat_potencial;

    INSERT INTO clientes_categorias (id_cliente, id_categoria)
    SELECT a.id_cliente, v_cat_potencial
    FROM actividad_web a
    JOIN clientes c ON c.id_cliente = a.id_cliente AND c.estado = 1
    WHERE a.fecha >= NOW() - INTERVAL 30 DAY
      AND EXISTS (
          SELECT 1 FROM clientes_categorias cc
          WHERE cc.id_cliente = a.id_cliente
            AND cc.id_categoria = v_cat_prospecto
      )
    GROUP BY a.id_cliente
    HAVING COUNT(*)                        >= v_interacciones_minimas
       AND COUNT(DISTINCT DATE(a.fecha))   >= v_dias_activos_minimos
       AND SUM(fn_puntos_accion(a.accion)) >= v_puntaje_minimo;

    -- Aviso único al vendedor asignado de cada cliente potencial.
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
    WHERE cc.id_categoria = v_cat_potencial
      AND NOT EXISTS (
          SELECT 1 FROM notificaciones n
          WHERE n.id_usuario = v.id_usuario
            AND n.mensaje = CONCAT('Cliente potencial: ', c.nombre)
      );

    SELECT c.id_cliente, c.nombre, fn_puntaje_cliente(c.id_cliente) AS puntaje
    FROM clientes_categorias cc
    JOIN clientes c ON c.id_cliente = cc.id_cliente
    WHERE cc.id_categoria = v_cat_potencial
    ORDER BY puntaje DESC;
END //

-- El paso del tiempo lo controla el EVENT SCHEDULER, no un trigger.
-- (Un evento no puede devolver resultados; los SELECT se descartan.)
CREATE EVENT ev_clasificar_clientes_potenciales
ON SCHEDULE EVERY 6 HOUR
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MINUTE
ON COMPLETION PRESERVE
DO
    CALL actualizar_clientes_potenciales() //

-- Activa el programador de eventos si el usuario tiene privilegio
-- (SYSTEM_VARIABLES_ADMIN o SUPER). Si no lo tiene, avisa y el script
-- continúa en lugar de detenerse.
CREATE PROCEDURE sp_activar_event_scheduler()
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        SELECT 'AVISO: no tiene privilegio para activar el programador de eventos. Un administrador debe ejecutar: SET GLOBAL event_scheduler = ON;' AS aviso;

    SET GLOBAL event_scheduler = ON;

    SELECT @@GLOBAL.event_scheduler AS event_scheduler;
END //

DELIMITER ;

CALL sp_activar_event_scheduler();
DROP PROCEDURE sp_activar_event_scheduler;

-- Clasificación inicial (sin esperar al evento)
CALL actualizar_clientes_potenciales();


-- ============================================================
-- PARTE 5. TRANSACCIONES ACID Y SIMULACIÓN DE ERRORES (Sesión 2)
--
--   Atomicidad  -> 5.1 y 5.5: todo o nada (COMMIT / ROLLBACK).
--   Consistencia-> llaves, CHECK y triggers rechazan datos inválidos.
--   Aislamiento -> 5.6 y la simulación de concurrencia (Sesión 4).
--   Durabilidad -> tras el COMMIT el cambio sobrevive a un reinicio
--                  (InnoDB escribe el redo log antes de confirmar).
--
-- En MySQL "BEGIN TRANSACTION" se escribe START TRANSACTION (o BEGIN).
-- ============================================================

-- ------------------------------------------------------------
-- 5.1 COMMIT: alta comercial completa como una sola unidad
--     cliente + categoría + vendedor + oportunidad
-- ------------------------------------------------------------
START TRANSACTION;

INSERT INTO clientes (tipo_cliente, nombre, documento, correo, telefono, direccion)
VALUES ('empresa', 'Distribuidora Andina de Alimentos S.A.S.', '901777333-2',
        'compras@andinaalimentos.com.co', '+57 601 555 7733', 'Calle 80 # 68-20, Bogotá D.C.');
SET @id_cliente_demo = LAST_INSERT_ID();

INSERT INTO clientes_categorias (id_cliente, id_categoria)
SELECT @id_cliente_demo, id_categoria FROM categorias_clientes WHERE nombre = 'Prospecto';

INSERT INTO asignaciones_clientes (id_cliente, id_vendedor) VALUES (@id_cliente_demo, 1);

INSERT INTO oportunidades (id_cliente, id_vendedor, id_etapa, titulo, descripcion, valor_estimado)
VALUES (@id_cliente_demo, 1, 1, 'Correo corporativo para 80 usuarios',
        'Prospecto captado en la feria tecnológica.', 6800000);

COMMIT;

SELECT '5.1 COMMIT' AS prueba, c.id_cliente, c.nombre, o.titulo, o.valor_estimado
FROM clientes c
JOIN oportunidades o ON o.id_cliente = c.id_cliente
WHERE c.id_cliente = @id_cliente_demo;

-- ------------------------------------------------------------
-- 5.2 ROLLBACK: se cancela todo lo hecho dentro de la transacción
-- ------------------------------------------------------------
SET @precio_antes = (SELECT precio FROM productos WHERE id_producto = 1);

START TRANSACTION;

-- Subimos todos los precios un 10 %...
UPDATE productos SET precio = ROUND(precio * 1.10, 2) WHERE id_producto > 0;

-- ...vemos el cambio (todavía no es definitivo)...
SELECT '5.2 dentro de la transacción' AS prueba, id_producto, nombre, precio
FROM productos WHERE id_producto = 1;

-- ...y nos arrepentimos: se devuelve todo
ROLLBACK;

SELECT '5.2 después del ROLLBACK' AS prueba, id_producto, nombre, precio,
       IF(precio = @precio_antes, 'precio original intacto', 'ERROR') AS verificacion
FROM productos WHERE id_producto = 1;

-- ------------------------------------------------------------
-- 5.3 SAVEPOINT: deshacer solo una parte
-- Venta directa al cliente 2; los triggers calculan el total y
-- descuentan el stock de cada producto.
-- ------------------------------------------------------------
START TRANSACTION;

INSERT INTO ventas (id_cliente, id_vendedor, total, estado)
VALUES (2, 1, 0, 'pendiente');
SET @id_venta_demo = LAST_INSERT_ID();

-- Primer producto
INSERT INTO ventas_productos (id_venta, id_producto, cantidad, precio_unitario, subtotal)
VALUES (@id_venta_demo, 1, 2, 45000, 90000);

SAVEPOINT despues_producto1;

-- Segundo producto
INSERT INTO ventas_productos (id_venta, id_producto, cantidad, precio_unitario, subtotal)
VALUES (@id_venta_demo, 4, 2, 25000, 50000);

SELECT '5.3 antes de volver al savepoint' AS prueba, total FROM ventas WHERE id_venta = @id_venta_demo;

-- El cliente no quiere el segundo producto: solo se deshace ese
-- (también se deshace el stock descontado y el total recalculado)
ROLLBACK TO SAVEPOINT despues_producto1;

COMMIT;

SELECT '5.3 SAVEPOINT' AS prueba, v.id_venta, v.total, COUNT(vp.id_detalle) AS productos
FROM ventas v
JOIN ventas_productos vp ON vp.id_venta = v.id_venta
WHERE v.id_venta = @id_venta_demo
GROUP BY v.id_venta, v.total;
-- Esperado: total 90000 con 1 producto

-- ------------------------------------------------------------
-- 5.4 Procedimiento transaccional con bloqueo de fila
-- La venta 2 (Tecnología Andina) tiene un abono de 5.000.000; el
-- procedimiento cobra el saldo restante y la venta queda pagada.
-- ------------------------------------------------------------
CALL procesar_pago_venta(2, 'transferencia', NULL);

-- ------------------------------------------------------------
-- 5.5 Simulación de errores y recuperación
-- Cada llamada abre una transacción, inserta un cliente (cambio válido)
-- y provoca un error distinto. El manejador lo captura, hace ROLLBACK
-- y compara los conteos antes/después: el cliente temporal desaparece.
-- (Los AUTO_INCREMENT consumidos no se devuelven: es normal en InnoDB.)
-- ------------------------------------------------------------
CALL sp_simular_error('llave_foranea');        -- 1452: cliente inexistente
CALL sp_simular_error('duplicado');            -- 1062: documento repetido
CALL sp_simular_error('restriccion');          -- 3819: CHECK precio >= 0
CALL sp_simular_error('stock');                -- 1644: trigger de stock
CALL sp_simular_error('sobrepago');            -- 1644: trigger de pagos
CALL sp_simular_error('propuesta_rechazada');  -- 1644: trigger de ventas

-- Errores que el propio procedimiento de pagos detecta (descomentar
-- para probar; cada uno hace ROLLBACK y devuelve el mensaje):
-- CALL procesar_pago_venta(2, 'efectivo', NULL);   -- la venta ya está pagada
-- CALL procesar_pago_venta(999, 'efectivo', NULL); -- la venta no existe

-- ------------------------------------------------------------
-- 5.6 Nivel de aislamiento
-- InnoDB usa REPEATABLE READ por defecto: dentro de una transacción
-- una consulta repetida devuelve siempre la misma foto de los datos.
-- La demostración con dos sesiones está en database/concurrencia.sql
-- ------------------------------------------------------------
SELECT '5.6 aislamiento' AS prueba, @@transaction_isolation AS nivel_actual, @@autocommit AS autocommit;


-- ============================================================
-- PARTE 6. ÍNDICES Y EXPLAIN (Sesión 4)
-- Las PK, UNIQUE y FK ya crean índices. Estos cubren los filtros
-- y ordenamientos que más usan reportes, triggers y la API.
-- ============================================================

-- Reportes mensuales y vista de ventas: filtran por fecha y estado
CREATE INDEX idx_ventas_fecha_estado      ON ventas (fecha, estado);
-- Desempeño por vendedor en un rango de fechas
CREATE INDEX idx_ventas_vendedor_fecha    ON ventas (id_vendedor, fecha);
-- fn_total_pagado / fn_saldo_venta: índice "cubriente" (no lee la tabla)
CREATE INDEX idx_pagos_venta_estado_valor ON pagos (id_venta, estado, valor);
-- Clasificación de potenciales y puntaje: actividad reciente por cliente
CREATE INDEX idx_actividad_cliente_fecha  ON actividad_web (id_cliente, fecha);
CREATE INDEX idx_actividad_fecha          ON actividad_web (fecha);
-- Embudo de ventas y oportunidades abiertas
CREATE INDEX idx_oportunidades_estado_etapa ON oportunidades (estado, id_etapa);
-- Listado de propuestas por estado
CREATE INDEX idx_propuestas_estado_fecha  ON propuestas (estado, fecha);
-- Buscador de clientes por nombre
CREATE INDEX idx_clientes_nombre          ON clientes (nombre);
-- Tareas pendientes de cada vendedor
CREATE INDEX idx_tareas_usuario_estado    ON tareas (id_usuario, estado);
-- Historial de seguimiento del prospecto
CREATE INDEX idx_eventos_cliente_inicio   ON eventos (id_cliente, fecha_inicio);
-- Consultas de auditoría por tabla y fecha
CREATE INDEX idx_auditoria_tabla_fecha    ON auditoria (tabla_afectada, fecha);
-- Bandeja de notificaciones del usuario
CREATE INDEX idx_notificaciones_usuario_estado ON notificaciones (id_usuario, estado);
-- Campañas activas
CREATE INDEX idx_campanas_estado_inicio   ON campanas_marketing (estado, fecha_inicio);

ANALYZE TABLE ventas, pagos, actividad_web, oportunidades, propuestas, clientes;

-- Comparación con EXPLAIN: la misma consulta sin y con el índice.
-- Columnas para leer: type (ALL = recorre toda la tabla; range/ref =
-- usa índice), key (índice elegido), rows (filas que estima revisar).

-- 6.1 Ventas pagadas de octubre
EXPLAIN SELECT id_venta, total
FROM ventas IGNORE INDEX (idx_ventas_fecha_estado, idx_ventas_vendedor_fecha)
WHERE fecha >= '2026-10-01' AND fecha < '2026-11-01' AND estado = 'pagada';

EXPLAIN SELECT id_venta, total
FROM ventas
WHERE fecha >= '2026-10-01' AND fecha < '2026-11-01' AND estado = 'pagada';

-- 6.2 Saldo de una venta (lo calcula fn_saldo_venta en cada fila)
EXPLAIN SELECT SUM(valor)
FROM pagos IGNORE INDEX (idx_pagos_venta_estado_valor)
WHERE id_venta = 2 AND estado IN ('aprobado', 'pendiente');

EXPLAIN SELECT SUM(valor)
FROM pagos
WHERE id_venta = 2 AND estado IN ('aprobado', 'pendiente');
-- Con el índice aparece "Using index": se responde sin leer la tabla.

-- 6.3 Actividad de los últimos 30 días (clasificación de potenciales)
EXPLAIN SELECT id_cliente, COUNT(*)
FROM actividad_web IGNORE INDEX (idx_actividad_fecha, idx_actividad_cliente_fecha)
WHERE fecha >= NOW() - INTERVAL 30 DAY
GROUP BY id_cliente;

EXPLAIN SELECT id_cliente, COUNT(*)
FROM actividad_web
WHERE fecha >= NOW() - INTERVAL 30 DAY
GROUP BY id_cliente;

-- 6.4 Buscador de clientes por nombre (prefijo)
EXPLAIN SELECT id_cliente, nombre FROM clientes IGNORE INDEX (idx_clientes_nombre)
WHERE nombre LIKE 'Clínica%';

EXPLAIN SELECT id_cliente, nombre FROM clientes
WHERE nombre LIKE 'Clínica%';

-- Nota: con pocas filas MySQL a veces prefiere recorrer la tabla
-- completa porque le sale más barato; la ventaja del índice crece con
-- el volumen. EXPLAIN ANALYZE muestra los tiempos reales:
EXPLAIN ANALYZE SELECT id_venta, total
FROM ventas
WHERE fecha >= '2026-10-01' AND fecha < '2026-11-01' AND estado = 'pagada';

-- ============================================================
-- PARTE 7. VISTAS PARA REPORTES (Sesión 4)
-- El frontend (dashboard y reportes) y la API las consultan
-- directamente. Al usuario de reportes solo se le da permiso sobre
-- ellas, no sobre las tablas (PARTE 8).
-- ============================================================

-- Ventas por mes: facturado, recaudado y cartera
CREATE VIEW vw_ventas_mensuales AS
SELECT YEAR(v.fecha)                                   AS anio,
       MONTH(v.fecha)                                  AS mes,
       DATE_FORMAT(v.fecha, '%Y-%m')                   AS periodo,
       COUNT(*)                                        AS ventas,
       SUM(v.estado = 'pagada')                        AS pagadas,
       SUM(v.estado = 'pendiente')                     AS pendientes,
       SUM(v.estado = 'cancelada')                     AS canceladas,
       SUM(IF(v.estado <> 'cancelada', v.total, 0))    AS total_vendido,
       SUM(IF(v.estado <> 'cancelada', fn_total_pagado(v.id_venta), 0)) AS total_recaudado,
       SUM(IF(v.estado = 'pendiente', v.total - fn_total_pagado(v.id_venta), 0)) AS cartera_pendiente
FROM ventas v
GROUP BY YEAR(v.fecha), MONTH(v.fecha), DATE_FORMAT(v.fecha, '%Y-%m');

-- Embudo de ventas: cuántas oportunidades y cuánto valor hay en cada etapa
CREATE VIEW vw_embudo_oportunidades AS
SELECT e.id_etapa,
       e.orden,
       e.nombre                            AS etapa,
       COUNT(o.id_oportunidad)             AS oportunidades,
       COALESCE(SUM(o.valor_estimado), 0)  AS valor_total
FROM etapas_ventas e
LEFT JOIN oportunidades o ON o.id_etapa = e.id_etapa
GROUP BY e.id_etapa, e.orden, e.nombre;

-- Vendedor actual de cada cliente (última asignación)
CREATE VIEW vw_cliente_vendedor_actual AS
SELECT ac.id_cliente, ac.id_vendedor, ac.fecha_asignacion
FROM asignaciones_clientes ac
WHERE ac.id_asignacion = (
    SELECT MAX(ac2.id_asignacion)
    FROM asignaciones_clientes ac2
    WHERE ac2.id_cliente = ac.id_cliente
);

-- Desempeño de cada vendedor
CREATE VIEW vw_desempeno_vendedores AS
SELECT ve.id_vendedor,
       ve.codigo,
       u.nombre                                      AS vendedor,
       u.correo,
       ve.especialidad,
       ve.estado,
       (SELECT COUNT(*) FROM vw_cliente_vendedor_actual cva
         WHERE cva.id_vendedor = ve.id_vendedor)     AS clientes_asignados,
       (SELECT COUNT(*) FROM oportunidades o
         WHERE o.id_vendedor = ve.id_vendedor AND o.estado = 'abierta') AS oportunidades_abiertas,
       (SELECT COUNT(*) FROM oportunidades o
         WHERE o.id_vendedor = ve.id_vendedor AND o.estado = 'ganada')  AS oportunidades_ganadas,
       (SELECT COUNT(*) FROM oportunidades o
         WHERE o.id_vendedor = ve.id_vendedor AND o.estado = 'perdida') AS oportunidades_perdidas,
       fn_tasa_conversion(ve.id_vendedor)            AS tasa_conversion,
       (SELECT COALESCE(SUM(v.total), 0) FROM ventas v
         WHERE v.id_vendedor = ve.id_vendedor AND v.estado <> 'cancelada') AS total_vendido,
       (SELECT COALESCE(SUM(fn_total_pagado(v.id_venta)), 0) FROM ventas v
         WHERE v.id_vendedor = ve.id_vendedor AND v.estado <> 'cancelada') AS total_recaudado
FROM vendedores ve
JOIN usuarios u ON u.id_usuario = ve.id_usuario;

-- Efectividad de las campañas de marketing
CREATE VIEW vw_efectividad_campanas AS
SELECT c.id_campana,
       c.nombre,
       c.estado,
       c.fecha_inicio,
       c.fecha_fin,
       c.presupuesto,
       (SELECT COUNT(*) FROM campanas_clientes cc WHERE cc.id_campana = c.id_campana)        AS clientes_impactados,
       (SELECT COUNT(*) FROM campanas_interacciones ci WHERE ci.id_campana = c.id_campana)   AS interacciones,
       (SELECT COUNT(DISTINCT cc.id_cliente)
          FROM campanas_clientes cc
          JOIN ventas v ON v.id_cliente = cc.id_cliente
                       AND v.estado <> 'cancelada'
                       AND v.fecha >= c.fecha_inicio
         WHERE cc.id_campana = c.id_campana)                                                AS clientes_con_compra,
       ROUND(c.presupuesto / NULLIF((SELECT COUNT(*) FROM campanas_interacciones ci
                                     WHERE ci.id_campana = c.id_campana), 0), 2)            AS costo_por_interaccion
FROM campanas_marketing c;

-- Cartera: ventas pendientes con lo pagado y lo que falta
CREATE VIEW vw_cartera_pendiente AS
SELECT v.id_venta,
       v.fecha,
       c.id_cliente,
       TRIM(CONCAT(c.nombre, ' ', COALESCE(c.apellido, ''))) AS cliente,
       u.nombre                                              AS vendedor,
       v.total,
       fn_total_pagado(v.id_venta)                           AS pagado,
       fn_saldo_venta(v.id_venta)                            AS saldo,
       v.total - fn_total_pagado(v.id_venta)                 AS por_recaudar,
       DATEDIFF(CURDATE(), DATE(v.fecha))                    AS dias_desde_venta
FROM ventas v
JOIN clientes c ON c.id_cliente = v.id_cliente
LEFT JOIN vendedores ve ON ve.id_vendedor = v.id_vendedor
LEFT JOIN usuarios u ON u.id_usuario = ve.id_usuario
WHERE v.estado = 'pendiente';

-- Listado de ventas con cliente, vendedor, pagado y saldo
CREATE VIEW vw_ventas_detalle AS
SELECT v.id_venta,
       v.fecha,
       v.estado,
       v.total,
       fn_total_pagado(v.id_venta)                           AS pagado,
       fn_saldo_venta(v.id_venta)                            AS saldo,
       v.id_propuesta,
       c.id_cliente,
       TRIM(CONCAT(c.nombre, ' ', COALESCE(c.apellido, ''))) AS cliente,
       v.id_vendedor,
       u.nombre                                              AS vendedor,
       (SELECT COUNT(*) FROM ventas_productos vp WHERE vp.id_venta = v.id_venta) AS productos
FROM ventas v
JOIN clientes c ON c.id_cliente = v.id_cliente
LEFT JOIN vendedores ve ON ve.id_vendedor = v.id_vendedor
LEFT JOIN usuarios u ON u.id_usuario = ve.id_usuario;

-- Listado de propuestas con oportunidad, cliente y vendedor
CREATE VIEW vw_propuestas_resumen AS
SELECT p.id_propuesta,
       p.fecha,
       p.estado,
       p.valor_total,
       p.observaciones,
       o.id_oportunidad,
       o.titulo                                              AS oportunidad,
       o.estado                                              AS estado_oportunidad,
       c.id_cliente,
       TRIM(CONCAT(c.nombre, ' ', COALESCE(c.apellido, ''))) AS cliente,
       o.id_vendedor,
       u.nombre                                              AS vendedor,
       (SELECT COUNT(*) FROM propuestas_detalles d WHERE d.id_propuesta = p.id_propuesta) AS productos,
       (SELECT v.id_venta FROM ventas v WHERE v.id_propuesta = p.id_propuesta)            AS id_venta
FROM propuestas p
JOIN oportunidades o ON o.id_oportunidad = p.id_oportunidad
JOIN clientes c ON c.id_cliente = o.id_cliente
LEFT JOIN vendedores ve ON ve.id_vendedor = o.id_vendedor
LEFT JOIN usuarios u ON u.id_usuario = ve.id_usuario;

-- Prospectos con su vendedor actual, puntaje y marca de potencial
CREATE VIEW vw_prospectos AS
SELECT c.id_cliente,
       c.tipo_cliente,
       c.nombre,
       c.apellido,
       c.documento,
       c.correo,
       c.telefono,
       c.direccion,
       c.estado,
       c.fecha_creacion,
       ve.id_vendedor,
       u.nombre                         AS vendedor_nombre,
       fn_puntaje_cliente(c.id_cliente) AS puntaje,
       EXISTS (
           SELECT 1 FROM clientes_categorias cc2
           JOIN categorias_clientes cat2 ON cat2.id_categoria = cc2.id_categoria
           WHERE cc2.id_cliente = c.id_cliente AND cat2.nombre = 'Potencial'
       )                                AS es_potencial
FROM clientes c
JOIN clientes_categorias cc ON cc.id_cliente = c.id_cliente
JOIN categorias_clientes cat ON cat.id_categoria = cc.id_categoria AND cat.nombre = 'Prospecto'
LEFT JOIN vw_cliente_vendedor_actual cva ON cva.id_cliente = c.id_cliente
LEFT JOIN vendedores ve ON ve.id_vendedor = cva.id_vendedor
LEFT JOIN usuarios u ON u.id_usuario = ve.id_usuario;

-- Indicadores generales para el tablero principal
CREATE VIEW vw_indicadores_generales AS
SELECT
    (SELECT COUNT(*) FROM clientes WHERE estado = 1)                                    AS clientes_activos,
    (SELECT COUNT(DISTINCT cc.id_cliente) FROM clientes_categorias cc
       JOIN categorias_clientes cat ON cat.id_categoria = cc.id_categoria
      WHERE cat.nombre = 'Prospecto')                                                   AS prospectos,
    (SELECT COUNT(DISTINCT cc.id_cliente) FROM clientes_categorias cc
       JOIN categorias_clientes cat ON cat.id_categoria = cc.id_categoria
      WHERE cat.nombre = 'Potencial')                                                   AS potenciales,
    (SELECT COUNT(*) FROM oportunidades WHERE estado = 'abierta')                       AS oportunidades_abiertas,
    (SELECT COALESCE(SUM(valor_estimado), 0) FROM oportunidades WHERE estado = 'abierta') AS valor_en_embudo,
    (SELECT COUNT(*) FROM propuestas WHERE estado IN ('borrador', 'enviada'))           AS propuestas_abiertas,
    (SELECT COALESCE(SUM(total), 0) FROM ventas WHERE estado <> 'cancelada')            AS total_vendido,
    (SELECT COALESCE(SUM(valor), 0) FROM pagos WHERE estado = 'aprobado')               AS total_recaudado,
    (SELECT COALESCE(SUM(por_recaudar), 0) FROM vw_cartera_pendiente)                   AS cartera_pendiente,
    (SELECT ROUND(100 * SUM(estado = 'ganada') / NULLIF(COUNT(*), 0), 2)
       FROM oportunidades WHERE estado IN ('ganada', 'perdida'))                        AS tasa_conversion;

SELECT 'Vistas creadas' AS info, COUNT(*) AS total
FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'zimbra';


-- ============================================================
-- PARTE 8. ROLES Y PERMISOS DE MYSQL (Sesión 4)
--
-- Las tablas roles/permisos controlan qué ve cada persona dentro de
-- la aplicación. Esta parte controla qué puede hacer cada CONEXIÓN a
-- la base de datos (principio de mínimo privilegio):
--
--   Rol MySQL              Usuario MySQL     Uso
--   rol_zimbra_aplicacion  zimbra_app        Backend Express (.env)
--   rol_zimbra_reportes    zimbra_analista   Analistas / BI: solo vistas
--   rol_zimbra_auditoria   zimbra_auditor    Control interno: solo lectura
--                                            de auditoría (sin contraseñas)
--
-- Requiere privilegios CREATE USER / CREATE ROLE (root los tiene).
-- Las contraseñas son de laboratorio: cámbielas fuera del aula.
-- ============================================================

DROP USER IF EXISTS 'zimbra_app'@'localhost', 'zimbra_analista'@'localhost', 'zimbra_auditor'@'localhost';
DROP ROLE IF EXISTS 'rol_zimbra_aplicacion', 'rol_zimbra_reportes', 'rol_zimbra_auditoria';

CREATE ROLE 'rol_zimbra_aplicacion', 'rol_zimbra_reportes', 'rol_zimbra_auditoria';

-- ------------------------------------------------------------
-- 8.1 Rol de la aplicación
-- Lee todo el esquema y ejecuta procedimientos/funciones, pero solo
-- escribe en las tablas que la operación necesita. No puede borrar
-- ventas, pagos ni clientes, ni tocar la auditoría (la escriben los
-- triggers con los permisos de su DEFINER), ni cambiar el esquema.
-- ------------------------------------------------------------
GRANT SELECT, EXECUTE ON zimbra.* TO 'rol_zimbra_aplicacion';
-- Las lecturas con bloqueo (SELECT ... FOR UPDATE) exigen, además de
-- SELECT, UPDATE o LOCK TABLES sobre la tabla bloqueada.
GRANT LOCK TABLES ON zimbra.* TO 'rol_zimbra_aplicacion';

GRANT INSERT, UPDATE ON zimbra.clientes               TO 'rol_zimbra_aplicacion';
GRANT INSERT, UPDATE ON zimbra.contactos              TO 'rol_zimbra_aplicacion';
GRANT INSERT, DELETE ON zimbra.clientes_categorias    TO 'rol_zimbra_aplicacion';
GRANT INSERT         ON zimbra.asignaciones_clientes  TO 'rol_zimbra_aplicacion';
GRANT INSERT, UPDATE ON zimbra.oportunidades          TO 'rol_zimbra_aplicacion';
GRANT INSERT         ON zimbra.oportunidades_detalle  TO 'rol_zimbra_aplicacion';
GRANT INSERT         ON zimbra.seguimientos           TO 'rol_zimbra_aplicacion';
GRANT INSERT, UPDATE ON zimbra.tareas                 TO 'rol_zimbra_aplicacion';
GRANT INSERT, UPDATE ON zimbra.eventos                TO 'rol_zimbra_aplicacion';
GRANT INSERT, UPDATE ON zimbra.propuestas             TO 'rol_zimbra_aplicacion';
GRANT INSERT, UPDATE, DELETE ON zimbra.propuestas_detalles TO 'rol_zimbra_aplicacion';
GRANT INSERT, UPDATE ON zimbra.ventas                 TO 'rol_zimbra_aplicacion';
GRANT INSERT         ON zimbra.ventas_productos       TO 'rol_zimbra_aplicacion';
GRANT INSERT, UPDATE ON zimbra.pagos                  TO 'rol_zimbra_aplicacion';
GRANT INSERT         ON zimbra.campanas_interacciones TO 'rol_zimbra_aplicacion';
GRANT INSERT         ON zimbra.actividad_web          TO 'rol_zimbra_aplicacion';
GRANT INSERT, UPDATE ON zimbra.notificaciones         TO 'rol_zimbra_aplicacion';
GRANT INSERT         ON zimbra.reportes_generados     TO 'rol_zimbra_aplicacion';
-- Registro de usuarios desde el formulario /register
GRANT INSERT, UPDATE ON zimbra.usuarios               TO 'rol_zimbra_aplicacion';
GRANT INSERT         ON zimbra.usuarios_roles         TO 'rol_zimbra_aplicacion';
GRANT INSERT, UPDATE ON zimbra.configuracion_usuario  TO 'rol_zimbra_aplicacion';

-- ------------------------------------------------------------
-- 8.2 Rol de reportes: solo las vistas y el reporte mensual.
-- Las vistas se ejecutan con los permisos de su DEFINER, así que el
-- analista ve los indicadores sin acceso directo a las tablas.
-- ------------------------------------------------------------
GRANT SELECT ON zimbra.vw_ventas_mensuales       TO 'rol_zimbra_reportes';
GRANT SELECT ON zimbra.vw_embudo_oportunidades   TO 'rol_zimbra_reportes';
GRANT SELECT ON zimbra.vw_desempeno_vendedores   TO 'rol_zimbra_reportes';
GRANT SELECT ON zimbra.vw_efectividad_campanas   TO 'rol_zimbra_reportes';
GRANT SELECT ON zimbra.vw_cartera_pendiente      TO 'rol_zimbra_reportes';
GRANT SELECT ON zimbra.vw_ventas_detalle         TO 'rol_zimbra_reportes';
GRANT SELECT ON zimbra.vw_propuestas_resumen     TO 'rol_zimbra_reportes';
GRANT SELECT ON zimbra.vw_indicadores_generales  TO 'rol_zimbra_reportes';
GRANT EXECUTE ON PROCEDURE zimbra.sp_reporte_ventas_mensual TO 'rol_zimbra_reportes';

-- ------------------------------------------------------------
-- 8.3 Rol de auditoría: lectura de auditoría y actividad.
-- Permiso por COLUMNA en usuarios: puede ver quién hizo qué, pero
-- nunca la columna password.
-- ------------------------------------------------------------
GRANT SELECT ON zimbra.auditoria     TO 'rol_zimbra_auditoria';
GRANT SELECT ON zimbra.actividad_web TO 'rol_zimbra_auditoria';
GRANT SELECT (id_usuario, nombre, correo, estado, fecha_creacion) ON zimbra.usuarios TO 'rol_zimbra_auditoria';

-- ------------------------------------------------------------
-- 8.4 Usuarios de conexión
-- ------------------------------------------------------------
CREATE USER 'zimbra_app'@'localhost'      IDENTIFIED BY 'ZimbraApp#2026'      PASSWORD EXPIRE NEVER;
CREATE USER 'zimbra_analista'@'localhost' IDENTIFIED BY 'ZimbraAnalista#2026' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER 'zimbra_auditor'@'localhost'  IDENTIFIED BY 'ZimbraAuditor#2026'  PASSWORD EXPIRE INTERVAL 90 DAY;

GRANT 'rol_zimbra_aplicacion' TO 'zimbra_app'@'localhost';
GRANT 'rol_zimbra_reportes'   TO 'zimbra_analista'@'localhost';
GRANT 'rol_zimbra_reportes', 'rol_zimbra_auditoria' TO 'zimbra_auditor'@'localhost';

-- Sin esto el rol existe pero no se activa al conectarse
SET DEFAULT ROLE ALL TO 'zimbra_app'@'localhost', 'zimbra_analista'@'localhost', 'zimbra_auditor'@'localhost';

-- Límite de conexiones simultáneas por usuario (protege el servidor)
ALTER USER 'zimbra_analista'@'localhost' WITH MAX_USER_CONNECTIONS 5;
ALTER USER 'zimbra_auditor'@'localhost'  WITH MAX_USER_CONNECTIONS 2;

-- Comprobación de lo concedido
SHOW GRANTS FOR 'zimbra_app'@'localhost' USING 'rol_zimbra_aplicacion';
SHOW GRANTS FOR 'zimbra_analista'@'localhost' USING 'rol_zimbra_reportes';
SHOW GRANTS FOR 'zimbra_auditor'@'localhost' USING 'rol_zimbra_reportes', 'rol_zimbra_auditoria';

-- Para comprobar el bloqueo, conéctese como analista y ejecute:
--   mysql -u zimbra_analista -p zimbra
--   SELECT * FROM vw_indicadores_generales;   -- permitido
--   SELECT * FROM clientes;                   -- ERROR 1142: SELECT command denied
--   DELETE FROM vw_cartera_pendiente;         -- ERROR 1142: DELETE command denied


-- ============================================================
-- PARTE 9. PRUEBAS AUTOMÁTICAS Y VERIFICACIÓN FINAL
-- Las pruebas de triggers ocurren dentro de una transacción que
-- termina con ROLLBACK: el CRM queda sin datos de prueba.
-- ============================================================

SET @actividades_antes = (SELECT COUNT(*) FROM actividad_web);

START TRANSACTION;

-- 1. Interacción de campaña -> actividad_web
INSERT INTO campanas_interacciones (id_campana, id_cliente, tipo, resultado)
VALUES (1, 5, 'formulario', 'Prueba: solicitó una demo.');

SELECT '9.1 Campaña -> actividad' AS prueba, id_cliente, accion, descripcion
FROM actividad_web WHERE id_cliente = 5
ORDER BY id_actividad DESC LIMIT 1;

-- 2. Seguimiento -> actividad_web (el cliente sale de la oportunidad)
INSERT INTO seguimientos (id_oportunidad, id_usuario, tipo, descripcion)
VALUES (4, 4, 'llamada', 'Prueba: llamada de seguimiento.');

SELECT '9.2 Seguimiento -> actividad' AS prueba, id_cliente, accion, descripcion
FROM actividad_web WHERE id_cliente = 6
ORDER BY id_actividad DESC LIMIT 1;

-- 3. Propuesta en borrador: no genera actividad; el total lo calcula el trigger
INSERT INTO propuestas (id_oportunidad, fecha, estado) VALUES (4, CURDATE(), 'borrador');
SET @id_propuesta_prueba = LAST_INSERT_ID();
INSERT INTO propuestas_detalles (id_propuesta, id_producto, cantidad, precio_unitario, subtotal)
VALUES (@id_propuesta_prueba, 27, 90, 95000, 0), (@id_propuesta_prueba, 11, 90, 35000, 0);

SELECT '9.3 Total automático (11.700.000)' AS prueba, valor_total,
       (SELECT valor_estimado FROM oportunidades WHERE id_oportunidad = 4) AS valor_oportunidad,
       (SELECT COUNT(*) FROM actividad_web WHERE id_cliente = 6 AND accion = 'propuesta') AS actividades_propuesta
FROM propuestas WHERE id_propuesta = @id_propuesta_prueba;
-- Esperado: 11700000, 11700000, 0

-- 4. Propuesta enviada: se registra una sola vez y la oportunidad avanza
UPDATE propuestas SET estado = 'enviada' WHERE id_propuesta = @id_propuesta_prueba;
UPDATE propuestas SET observaciones = 'Prueba: sin cambio de estado' WHERE id_propuesta = @id_propuesta_prueba;

SELECT '9.4 Sin duplicados y etapa 3' AS prueba,
       (SELECT COUNT(*) FROM actividad_web WHERE id_cliente = 6 AND accion = 'propuesta') AS actividades_propuesta,
       (SELECT id_etapa FROM oportunidades WHERE id_oportunidad = 4) AS etapa;
-- Esperado: 1, 3

-- 5. Venta de la propuesta -> propuesta aceptada, oportunidad ganada,
--    stock descontado y actividad 'compra'
SET @stock_antes = (SELECT stock FROM productos WHERE id_producto = 27);
INSERT INTO ventas (id_cliente, id_vendedor, id_propuesta, total) VALUES (6, 3, @id_propuesta_prueba, 0);
SET @id_venta_prueba = LAST_INSERT_ID();
INSERT INTO ventas_productos (id_venta, id_producto, cantidad, precio_unitario, subtotal)
SELECT @id_venta_prueba, id_producto, cantidad, precio_unitario, subtotal
FROM propuestas_detalles WHERE id_propuesta = @id_propuesta_prueba;

SELECT '9.5 Propuesta -> venta' AS prueba, p.estado AS propuesta, o.estado AS oportunidad,
       o.id_etapa AS etapa, v.total, @stock_antes - pr.stock AS stock_descontado
FROM propuestas p
JOIN oportunidades o ON o.id_oportunidad = p.id_oportunidad
JOIN ventas v ON v.id_propuesta = p.id_propuesta
JOIN productos pr ON pr.id_producto = 27
WHERE p.id_propuesta = @id_propuesta_prueba;
-- Esperado: aceptada, ganada, 5, 11700000, 90

-- 6. Pagos: abono + saldo -> la venta queda pagada
INSERT INTO pagos (id_venta, metodo_pago, valor, estado) VALUES (@id_venta_prueba, 'pse', 5000000, 'aprobado');
INSERT INTO pagos (id_venta, metodo_pago, valor, estado) VALUES (@id_venta_prueba, 'pse', 6700000, 'aprobado');

SELECT '9.6 Pagos -> venta pagada' AS prueba, estado, fn_total_pagado(id_venta) AS pagado, fn_saldo_venta(id_venta) AS saldo
FROM ventas WHERE id_venta = @id_venta_prueba;
-- Esperado: pagada, 11700000, 0

-- 7. Clasificación: el cliente 5 (prospecto) completa 5 interacciones en 3 días
INSERT INTO actividad_web (id_cliente, accion, descripcion, fecha) VALUES
(5, 'visita',   'Prueba: visita de hace 3 días',  NOW() - INTERVAL 3 DAY),
(5, 'descarga', 'Prueba: descarga de hace 2 días', NOW() - INTERVAL 2 DAY),
(5, 'demo',     'Prueba: demo de hace 1 día',     NOW() - INTERVAL 1 DAY),
(5, 'webinar',  'Prueba: webinar de hoy',         NOW());

CALL actualizar_clientes_potenciales();

SELECT '9.7 Prospectos intactos' AS prueba,
       (SELECT COUNT(*) FROM vw_prospectos) AS prospectos,
       (SELECT es_potencial FROM vw_prospectos WHERE id_cliente = 5) AS cliente5_potencial;
-- Esperado: 26 prospectos (25 + el de la demo 5.1), cliente5_potencial = 1

-- 8. Aviso al vendedor (una sola vez por cliente)
SELECT '9.8 Notificación' AS prueba, id_usuario, titulo, mensaje
FROM notificaciones
WHERE titulo = 'Cliente potencial detectado'
ORDER BY id_notificacion DESC LIMIT 1;

-- 9. Se deshacen las pruebas
ROLLBACK;

SELECT '9.9 Rollback' AS prueba,
       (SELECT COUNT(*) FROM actividad_web) - @actividades_antes AS actividades_nuevas;
-- Esperado: 0

-- ------------------------------------------------------------
-- Verificación final: registros por tabla y objetos creados
-- ------------------------------------------------------------
SELECT 'usuarios' AS tabla, COUNT(*) AS registros FROM usuarios
UNION ALL SELECT 'roles (catálogo: 3 por diseño)', COUNT(*) FROM roles
UNION ALL SELECT 'permisos', COUNT(*) FROM permisos
UNION ALL SELECT 'usuarios_roles', COUNT(*) FROM usuarios_roles
UNION ALL SELECT 'roles_permisos', COUNT(*) FROM roles_permisos
UNION ALL SELECT 'configuracion_usuario', COUNT(*) FROM configuracion_usuario
UNION ALL SELECT 'clientes', COUNT(*) FROM clientes
UNION ALL SELECT 'contactos', COUNT(*) FROM contactos
UNION ALL SELECT 'categorias_clientes (catálogo: 5)', COUNT(*) FROM categorias_clientes
UNION ALL SELECT 'clientes_categorias', COUNT(*) FROM clientes_categorias
UNION ALL SELECT 'etiquetas', COUNT(*) FROM etiquetas
UNION ALL SELECT 'contactos_etiquetas', COUNT(*) FROM contactos_etiquetas
UNION ALL SELECT 'vendedores', COUNT(*) FROM vendedores
UNION ALL SELECT 'asignaciones_clientes', COUNT(*) FROM asignaciones_clientes
UNION ALL SELECT 'etapas_ventas (catálogo: 6)', COUNT(*) FROM etapas_ventas
UNION ALL SELECT 'oportunidades', COUNT(*) FROM oportunidades
UNION ALL SELECT 'oportunidades_detalle', COUNT(*) FROM oportunidades_detalle
UNION ALL SELECT 'seguimientos', COUNT(*) FROM seguimientos
UNION ALL SELECT 'tareas', COUNT(*) FROM tareas
UNION ALL SELECT 'campanas_marketing', COUNT(*) FROM campanas_marketing
UNION ALL SELECT 'campanas_clientes', COUNT(*) FROM campanas_clientes
UNION ALL SELECT 'campanas_interacciones', COUNT(*) FROM campanas_interacciones
UNION ALL SELECT 'categorias_productos', COUNT(*) FROM categorias_productos
UNION ALL SELECT 'productos', COUNT(*) FROM productos
UNION ALL SELECT 'productos_detalles', COUNT(*) FROM productos_detalles
UNION ALL SELECT 'productos_categorias', COUNT(*) FROM productos_categorias
UNION ALL SELECT 'propuestas', COUNT(*) FROM propuestas
UNION ALL SELECT 'propuestas_detalles', COUNT(*) FROM propuestas_detalles
UNION ALL SELECT 'ventas', COUNT(*) FROM ventas
UNION ALL SELECT 'ventas_productos', COUNT(*) FROM ventas_productos
UNION ALL SELECT 'pagos', COUNT(*) FROM pagos
UNION ALL SELECT 'actividad_web', COUNT(*) FROM actividad_web
UNION ALL SELECT 'notificaciones', COUNT(*) FROM notificaciones
UNION ALL SELECT 'info_companie (1 fila por diseño)', COUNT(*) FROM info_companie
UNION ALL SELECT 'eventos', COUNT(*) FROM eventos
UNION ALL SELECT 'correos', COUNT(*) FROM correos
UNION ALL SELECT 'correos_destinatarios', COUNT(*) FROM correos_destinatarios
UNION ALL SELECT 'reportes_generados', COUNT(*) FROM reportes_generados
UNION ALL SELECT 'auditoria', COUNT(*) FROM auditoria;

SELECT 'Tablas' AS objeto, COUNT(*) AS total FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'zimbra' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL SELECT 'Vistas', COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'zimbra'
UNION ALL SELECT 'Triggers', COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = 'zimbra'
UNION ALL SELECT 'Procedimientos', COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = 'zimbra' AND ROUTINE_TYPE = 'PROCEDURE'
UNION ALL SELECT 'Funciones', COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = 'zimbra' AND ROUTINE_TYPE = 'FUNCTION'
UNION ALL SELECT 'Eventos', COUNT(*) FROM information_schema.EVENTS WHERE EVENT_SCHEMA = 'zimbra'
UNION ALL SELECT 'Restricciones CHECK', COUNT(*) FROM information_schema.CHECK_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = 'zimbra'
UNION ALL SELECT 'Llaves foráneas', COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = 'zimbra'
UNION ALL SELECT 'Índices secundarios (idx_)', COUNT(DISTINCT TABLE_NAME, INDEX_NAME) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = 'zimbra' AND INDEX_NAME LIKE 'idx\_%'
UNION ALL SELECT 'Roles MySQL', COUNT(*) FROM mysql.user WHERE User LIKE 'rol\_zimbra\_%'
UNION ALL SELECT 'Usuarios MySQL', COUNT(*) FROM mysql.user WHERE User LIKE 'zimbra\_%';
