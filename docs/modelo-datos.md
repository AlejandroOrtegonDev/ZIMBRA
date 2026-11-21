# Modelo de datos (DMR) y justificación

Entregable de la **Sesión 1**. El diagrama se dibuja con Mermaid: GitHub y VS Code (extensión *Markdown Preview Mermaid Support*) lo muestran directamente. Para exportarlo como imagen se puede pegar en <https://mermaid.live>. MySQL Workbench también puede generarlo desde la base cargada: *Database → Reverse Engineer*.

## 1. Núcleo comercial (clientes, propuestas, ventas, marketing, reportes)

```mermaid
erDiagram
    clientes ||--o{ contactos : tiene
    clientes ||--o{ clientes_categorias : "se clasifica en"
    categorias_clientes ||--o{ clientes_categorias : agrupa
    clientes ||--o{ asignaciones_clientes : "es asignado"
    vendedores ||--o{ asignaciones_clientes : atiende
    usuarios ||--|| vendedores : "es perfil de"

    clientes ||--o{ oportunidades : genera
    vendedores ||--o{ oportunidades : gestiona
    etapas_ventas ||--o{ oportunidades : "ubica en"
    oportunidades ||--o{ seguimientos : registra
    oportunidades ||--o{ propuestas : "se cotiza en"
    propuestas ||--|{ propuestas_detalles : contiene
    productos ||--o{ propuestas_detalles : "se ofrece en"

    propuestas |o--o| ventas : "se convierte en"
    clientes ||--o{ ventas : compra
    vendedores ||--o{ ventas : cierra
    ventas ||--|{ ventas_productos : contiene
    productos ||--o{ ventas_productos : "se vende en"
    ventas ||--o{ pagos : "se cobra con"

    campanas_marketing ||--o{ campanas_clientes : impacta
    clientes ||--o{ campanas_clientes : recibe
    campanas_marketing ||--o{ campanas_interacciones : produce
    clientes ||--o{ actividad_web : realiza

    usuarios ||--o{ reportes_generados : genera
    usuarios ||--o{ auditoria : "es autor de"

    clientes {
        int id_cliente PK
        enum tipo_cliente
        varchar nombre
        varchar documento UK
        varchar correo "CHECK formato"
        tinyint estado "CHECK 0/1"
    }
    oportunidades {
        int id_oportunidad PK
        int id_cliente FK
        int id_vendedor FK
        int id_etapa FK
        decimal valor_estimado "CHECK >= 0"
        enum estado "abierta/ganada/perdida"
    }
    propuestas {
        int id_propuesta PK
        int id_oportunidad FK
        decimal valor_total "trigger = suma de líneas"
        enum estado "borrador/enviada/aceptada/rechazada"
    }
    propuestas_detalles {
        int id_detalle PK
        int id_propuesta FK
        int id_producto FK
        int cantidad "CHECK > 0"
        decimal subtotal "CHECK = cantidad x precio"
    }
    ventas {
        int id_venta PK
        int id_cliente FK
        int id_vendedor FK
        int id_propuesta "FK, UNIQUE"
        decimal total "trigger = suma de productos"
        enum estado "pendiente/pagada/cancelada"
    }
    pagos {
        int id_pago PK
        int id_venta FK
        decimal valor "CHECK > 0"
        enum estado "pendiente/aprobado/rechazado"
    }
    productos {
        int id_producto PK
        decimal precio "CHECK >= 0"
        int stock "CHECK >= 0"
    }
    campanas_marketing {
        int id_campana PK
        date fecha_inicio
        date fecha_fin "CHECK >= inicio"
        decimal presupuesto "CHECK >= 0"
    }
```

## 2. Seguridad, seguimiento y soporte

```mermaid
erDiagram
    usuarios ||--o{ usuarios_roles : tiene
    roles ||--o{ usuarios_roles : asigna
    roles ||--o{ roles_permisos : concede
    permisos ||--o{ roles_permisos : "forma parte de"
    usuarios ||--|| configuracion_usuario : configura
    usuarios ||--o{ notificaciones : recibe
    usuarios ||--o{ tareas : responsable
    usuarios ||--o{ eventos : agenda
    clientes |o--o{ eventos : "es objeto de"
    clientes |o--o{ tareas : "es objeto de"
    oportunidades ||--o{ oportunidades_detalle : documenta
    contactos ||--o{ contactos_etiquetas : lleva
    etiquetas ||--o{ contactos_etiquetas : marca
    productos ||--o{ productos_detalles : describe
    productos ||--o{ productos_categorias : clasifica
    categorias_productos ||--o{ productos_categorias : agrupa
    usuarios ||--o{ correos : envia
    correos ||--|{ correos_destinatarios : "se envía a"
```

`info_companie` es una tabla de configuración independiente (una fila: la empresa dueña del sistema).

## 3. Justificación del diseño

**Normalización (3FN).** Cada hecho se guarda una sola vez. El vendedor actual de un cliente no se copia en `clientes`: se obtiene de la última fila de `asignaciones_clientes` (vista `vw_cliente_vendedor_actual`), lo que además conserva el historial de reasignaciones. Las relaciones muchos-a-muchos (cliente–categoría, producto–categoría, contacto–etiqueta, campaña–cliente, usuario–rol, rol–permiso) usan tablas puente con llave primaria compuesta, que impide duplicados.

**Separación propuesta / venta.** Una oportunidad puede tener varias propuestas (versiones), pero cada propuesta genera como máximo una venta (`UNIQUE (id_propuesta)` en `ventas`). Las ventas directas, sin propuesta, también son válidas (`id_propuesta` admite NULL). Los detalles guardan `precio_unitario` porque el precio del catálogo cambia con el tiempo y la venta debe conservar el precio pactado.

**Valores derivados controlados.** `propuestas.valor_total` y `ventas.total` se podrían calcular siempre con `SUM`, pero se guardan por rendimiento en listados y reportes. Para que nunca se desincronicen, solo los escriben los triggers de las líneas, y una restricción `CHECK (subtotal = cantidad * precio_unitario)` asegura cada línea.

**Políticas de borrado.**
- `ON DELETE CASCADE` en filas que no existen sin su padre: detalles de propuestas y ventas, contactos, tablas puente y destinatarios de correo.
- `ON DELETE SET NULL` en historial que debe sobrevivir: la auditoría y la actividad web cuando se borra un usuario, y los eventos cuando se borra un cliente.
- `RESTRICT` (por defecto) en los datos comerciales: no se puede borrar un cliente con ventas ni una venta con pagos. La aplicación **desactiva** (`estado = 0`) en lugar de borrar.

**Restricciones de dominio.** `ENUM` para los estados (no se admiten valores fuera del ciclo de vida) y `CHECK` para montos no negativos, cantidades positivas, rangos de fechas válidos, formato básico de correo y banderas 0/1.

**Estados como máquina de estados.** Las transiciones válidas (por ejemplo, una propuesta aceptada no vuelve a borrador; un pago aprobado no cambia) se hacen cumplir en la base de datos con triggers `BEFORE UPDATE`, no solo en la interfaz, para que ninguna aplicación cliente pueda saltárselas.

**Tipos de datos.** `DECIMAL(12,2)` para dinero (sin errores de redondeo de coma flotante), `utf8mb4` para nombres con tildes y eñes, `TIMESTAMP` para fechas de registro y `DATE` para fechas de negocio.
