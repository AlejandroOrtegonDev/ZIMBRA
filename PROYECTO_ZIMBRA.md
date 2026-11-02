# Sistema de Gestión Comercial Zimbra

## 1. Descripción del proyecto

Aplicación web académica inspirada en el caso de estudio de Zimbra y su
proceso de generación y gestión de prospectos comerciales.

El sistema permitirá registrar visitantes y prospectos, administrar
pruebas gratuitas de 60 días, registrar actividad web, calificar
prospectos, asignarlos a vendedores, realizar seguimientos comerciales,
gestionar campañas de marketing y registrar ventas.

> Este proyecto es una implementación académica inspirada en el caso. No
> pretende replicar el software original de Zimbra ni afirmar que
> reproduce su arquitectura interna.

## 2. Objetivo general

Desarrollar una aplicación web de gestión comercial con arquitectura
cliente-servidor, utilizando React en el frontend, Node.js y Express en
el backend, y MySQL como sistema gestor de base de datos.

## 3. Tecnologías

### Frontend

-   React
-   Vite
-   JavaScript
-   ESLint
-   Fetch API o Axios para consumir el backend

### Backend

-   Node.js
-   Express
-   CORS
-   dotenv
-   mysql2
-   Nodemon para desarrollo

### Base de datos

-   MySQL
-   MySQL Workbench para administración y modelado

### Herramientas

-   Visual Studio Code
-   Git
-   Cursor como asistente de programación

## 4. Estado inicial del entorno

Sistema operativo: Windows 11.

Herramientas instaladas: - Visual Studio Code - Node.js LTS - npm -
MySQL Server - MySQL Workbench - Git

Carpeta principal del proyecto: `sistema-zimbra`.

Configuración elegida para Vite: - Framework: React - Variante:
JavaScript - Linter: ESLint

## 5. Arquitectura propuesta

``` text
sistema-zimbra/
├── frontend/                 # Aplicación React + Vite
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── services/
│   │   ├── context/
│   │   ├── App.jsx
│   │   └── main.jsx
│   └── package.json
│
├── backend/                  # API REST con Node.js + Express
│   ├── src/
│   │   ├── config/
│   │   ├── controllers/
│   │   ├── middlewares/
│   │   ├── routes/
│   │   ├── services/
│   │   └── app.js
│   ├── .env
│   ├── .env.example
│   └── package.json
│
├── database/
│   └── schema.sql
│
├── docs/
│   ├── requerimientos.md
│   ├── procesos.md
│   └── modelo-datos.md
│
├── .gitignore
└── README.md
```

La estructura puede evolucionar durante el desarrollo. No crear carpetas
vacías o capas innecesarias antes de necesitarlas.

## 6. Módulos funcionales

1.  **Usuarios y autenticación:** registro, inicio de sesión, roles y
    administración de usuarios.
2.  **Prospectos:** creación, consulta, actualización y clasificación de
    clientes potenciales.
3.  **Actividad web:** registro de páginas visitadas, descargas e
    interacciones relevantes.
4.  **Pruebas gratuitas:** registrar inicio y fin de pruebas de 60 días
    y su estado.
5.  **Vendedores:** administrar los usuarios del equipo comercial.
6.  **Asignación de prospectos:** asignar prospectos a vendedores y
    consultar responsables.
7.  **Seguimiento comercial:** registrar llamadas, correos, reuniones,
    resultados y próximos contactos.
8.  **Marketing:** administrar campañas y registrar comunicaciones
    enviadas.
9.  **Ventas:** registrar cierres comerciales y relacionarlos con
    prospectos y vendedores.
10. **Informes:** consultar indicadores de visitantes, prospectos,
    seguimientos y ventas.

## 7. Modelo de datos inicial propuesto

Diseñar una base de datos relacional que incluya, como mínimo, las
siguientes entidades:

-   `usuarios`
-   `roles`
-   `prospectos`
-   `vendedores`
-   `actividad_web`
-   `pruebas`
-   `asignaciones`
-   `seguimiento_comercial`
-   `campañas`
-   `correos_marketing`
-   `ventas`

Definir claves primarias, claves foráneas, restricciones, índices y
tipos de datos apropiados. Evitar duplicar información que pueda
obtenerse mediante relaciones.

El modelo definitivo debe documentarse antes de implementar todas las
operaciones. La tabla `vendedores` puede implementarse como perfil
asociado a un usuario si el diseño lo justifica.

## 8. Reglas de negocio iniciales

-   Una prueba gratuita tiene una duración prevista de 60 días.
-   Un prospecto puede tener un estado, por ejemplo: nuevo, calificado,
    asignado, en seguimiento, convertido o descartado.
-   La asignación de un prospecto debe quedar registrada con fecha y
    vendedor responsable.
-   Cada interacción comercial debe conservar fecha, tipo, resultado y
    observaciones.
-   Una venta debe relacionarse con el prospecto correspondiente y,
    cuando aplique, con el vendedor responsable.
-   Los cambios importantes deben poder auditarse.
-   No asumir que una puntuación automática o una integración real con
    Salesforce existe hasta que se implemente explícitamente.

## 9. Requisitos de calidad y seguridad

-   Validar los datos tanto en frontend como en backend.
-   Utilizar consultas parametrizadas para evitar inyección SQL.
-   No guardar contraseñas en texto plano; utilizar un algoritmo de hash
    apropiado.
-   Mantener credenciales y secretos en variables de entorno.
-   No subir `.env` al repositorio.
-   Manejar errores sin exponer contraseñas, tokens ni detalles
    internos.
-   Aplicar autorización según roles en las rutas protegidas.
-   Usar nombres claros y consistentes para archivos, funciones,
    variables y tablas.
-   Mantener separadas las responsabilidades de interfaz, rutas,
    controladores, servicios y acceso a datos.
-   Documentar cómo instalar, ejecutar y probar el proyecto.

Los objetivos numéricos de rendimiento y disponibilidad deben definirse
y medirse; no presentarlos como capacidades ya logradas.

## 10. Orden de desarrollo

1.  Verificar instalación y estructura del proyecto.
2.  Crear y probar la API básica de Express.
3.  Crear la base de datos y el esquema inicial de MySQL.
4.  Configurar la conexión de Node.js con MySQL.
5.  Implementar autenticación y roles.
6.  Implementar CRUD de prospectos.
7.  Implementar vendedores y asignaciones.
8.  Implementar actividad web y pruebas gratuitas.
9.  Implementar seguimiento comercial.
10. Implementar campañas y comunicaciones.
11. Implementar ventas e informes.
12. Conectar todas las pantallas de React con la API.
13. Probar, documentar y preparar la presentación académica.

## 11. Comandos de referencia

Crear el frontend (si aún no existe):

``` bash
npm create vite@latest frontend -- --template react
cd frontend
npm install
npm run dev
```

Crear el backend (desde la carpeta raíz):

``` bash
mkdir backend
cd backend
npm init -y
npm install express cors dotenv mysql2
npm install -D nodemon
```

Ejecutar el backend después de configurar el script `dev`:

``` bash
npm run dev
```

Puertos locales sugeridos: - React/Vite: `http://localhost:5173` - API
Express: `http://localhost:3000` - MySQL: `localhost:3306`

## 12. Prompt principal para Cursor

Copia el siguiente texto en Cursor, preferiblemente en el modo Agent,
con la carpeta raíz `sistema-zimbra` abierta:

------------------------------------------------------------------------

Actúa como un desarrollador senior y mentor técnico especializado en
React, Node.js, Express y MySQL. Estoy aprendiendo programación desde
cero y necesito que me guíes para construir un proyecto académico
llamado **Sistema de Gestión Comercial Zimbra**, inspirado en un caso de
estudio sobre captación, calificación y seguimiento de prospectos
comerciales.

### Contexto técnico

-   Sistema operativo: Windows 11.
-   Frontend: React con Vite, JavaScript y ESLint.
-   Backend: Node.js con Express.
-   Base de datos: MySQL.
-   Herramientas: VS Code/Cursor, npm, MySQL Workbench y Git.
-   El proyecto se debe ejecutar localmente durante el desarrollo.

### Objetivo funcional

Construir una aplicación web para: 1. Registrar usuarios y prospectos.
2. Administrar pruebas gratuitas de 60 días. 3. Registrar actividad e
intereses de visitantes. 4. Calificar y clasificar prospectos. 5.
Administrar vendedores y asignarles prospectos. 6. Registrar llamadas,
correos y seguimientos. 7. Administrar campañas de marketing. 8.
Registrar ventas. 9. Consultar informes comerciales.

### Forma de trabajo obligatoria

1.  Primero inspecciona los archivos y carpetas existentes. No
    sobrescribas ni elimines trabajo existente.
2.  Explícame brevemente qué está creado y qué falta.
3.  Trabaja en etapas pequeñas y verificables. No intentes construir
    toda la aplicación de una sola vez.
4.  Antes de modificar archivos, indica qué archivos vas a crear o
    cambiar y para qué.
5.  Escribe código claro, organizado y adecuado para una persona
    principiante.
6.  Después de cada etapa, proporciona los comandos exactos para Windows
    PowerShell, indicando desde qué carpeta ejecutarlos.
7.  Explica cómo comprobar que cada parte funciona y qué resultado
    debería observar.
8.  No avances a la siguiente etapa hasta que yo confirme que la actual
    funciona o te comparta el error.
9.  Si encuentras errores, ayúdame a diagnosticarlos paso a paso y evita
    hacer cambios innecesarios.
10. No inventes resultados de ejecución ni afirmes que probaste algo si
    no lo ejecutaste.
11. No uses tecnologías adicionales sin explicar por qué son necesarias.
12. Mantén consistencia entre nombres de tablas, endpoints, archivos y
    componentes.
13. Actualiza el README y la documentación cuando corresponda.

### Reglas técnicas

-   Utiliza componentes funcionales y hooks de React.
-   Usa Express para crear una API REST.
-   Usa `mysql2` con consultas parametrizadas.
-   Separa rutas, controladores, servicios y configuración cuando aporte
    claridad.
-   Usa variables de entorno para credenciales.
-   Crea `.env.example` sin secretos reales y agrega `.env` a
    `.gitignore`.
-   Nunca guardes contraseñas en texto plano; utiliza hash seguro.
-   Valida las entradas en el servidor y maneja errores de manera
    consistente.
-   No expongas secretos ni datos sensibles en respuestas o registros.
-   No simules una integración con Salesforce como si fuera real. Si se
    necesita, primero plantea una integración de demostración claramente
    identificada.
-   No afirmes que la arquitectura interna de Zimbra era esta; es una
    arquitectura propuesta para nuestro proyecto académico.

### Primera tarea

Por ahora, NO construyas todos los módulos. Inspecciona el proyecto
actual y ayúdame a completar únicamente la configuración inicial: -
verificar frontend React/Vite; - verificar backend Node.js/Express; -
comprobar que ambos pueden ejecutarse; - comprobar que React puede
consultar un endpoint de Express; - revisar la estructura de carpetas; -
identificar cualquier problema de configuración.

Al terminar, resume los archivos creados o modificados, los comandos que
debo ejecutar y las pruebas que debo realizar. Espera mi confirmación
antes de continuar con el diseño y conexión de MySQL.

Recuerda: soy principiante. Enséñame y explícame, no te limites a
generar código.

------------------------------------------------------------------------

## 13. Cómo utilizar este documento

1.  Abre Cursor y selecciona la carpeta `sistema-zimbra`.
2.  Guarda este documento como `PROYECTO_ZIMBRA.md` en la raíz del
    proyecto.
3.  Abre el chat de Cursor en modo Agent.
4.  Copia el prompt de la sección 12.
5.  Permite que Cursor inspeccione el proyecto y revisa sus propuestas
    antes de aceptar cambios.
6.  Sigue las instrucciones y prueba cada etapa antes de continuar.
