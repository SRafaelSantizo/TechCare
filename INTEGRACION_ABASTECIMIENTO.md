# Repuestos, proveedores y bodegas

Continuación del commit `8adff57`, que contiene facturación, pagos, entrega y PDF.
Esta entrega conecta la gestión de catálogos de abastecimiento: crear, editar,
activar/desactivar, asociar repuestos y revisar cambios de precios.

## Aplicar en IntelliJ y SSMS

1. Guardar `28_Abastecimiento_API.patch` en la raíz de TechCare, junto a `backend`
   y `frontend`. Ejecutar en la terminal de IntelliJ:

   ```bash
   git apply --check 28_Abastecimiento_API.patch
   git apply 28_Abastecimiento_API.patch
   ```

   El patch se aplica una sola vez sobre el bloque de facturación ya instalado.
   Si la comprobación informa conflicto, revisar la salida antes de aplicar.
2. En SSMS ejecutar completo `26_Abastecimiento_Procedimientos.sql` en la base
   TechCare habitual. Requiere el 23; es repetible y conserva datos. No volver
   a ejecutar 01, 02 ni los scripts anteriores que ya están instalados.
3. En DESARROLLO, sin transacciones abiertas ni otras escrituras concurrentes,
   ejecutar `27_Pruebas_Abastecimiento.sql`. Incluye 59 casos con datos propios,
   ROLLBACK y comprobación de cantidades antes/después. Las identidades pueden
   dejar huecos; no se conservan registros de prueba.
4. Reiniciar el backend y el frontend como de costumbre. Este bloque no agrega
   dependencias de Maven/npm ni modifica credenciales o configuración local.

## Recorrido desde la aplicación

Entrar con BODEGA o ADMIN. En **Servicios**, dentro de **Inventario y compras**,
aparecen Repuestos, Proveedores y la nueva opción Bodegas. Recepción, técnicos
y caja mantienen sus módulos propios; el técnico consume desde su expediente.

### Repuestos y categorías

1. Abrir **Repuestos → Categorías**. Crear o renombrar categorías; las relaciones
   de los repuestos se conservan al cambiar un nombre.
2. Usar **Nuevo repuesto**. Elegir categoría, código único, nombre, descripción,
   costo de referencia, precio de venta y estado. Se permiten precios en cero.
3. Usar **Editar** para corregir los datos o activar/desactivar. Los cambios de
   costo y precio quedan en **Historial de precios**, con valores anteriores,
   nuevos, fecha y responsable. Los registros previos sin usuario de aplicación
   aparecen identificados como tales; no se inventa un responsable histórico.
4. Buscar por código, nombre o descripción, filtrar categoría/estado y paginar.

Crear el repuesto no crea stock ni movimientos. El catálogo puede existir antes
de que se compre la primera unidad. Los códigos admiten letras/números sin tildes,
puntos, guiones, guiones bajos y barras, sin espacios; los nombres y descripciones
conservan Unicode.

### Proveedores y catálogo ofrecido

1. Abrir **Proveedores → Nuevo proveedor**. Registrar NIT único, nombre o razón
   social, correo, teléfono, dirección y estado. Los datos de contacto son opcionales.
2. En la fila del proveedor usar **Catálogo ofrecido**. Elegir un repuesto activo
   y, opcionalmente, el código que utiliza el proveedor para identificarlo.
3. Usar **Editar código** para cambiar esa referencia. La asociación es única
   por proveedor y repuesto.
4. **Retirar** pide confirmar qué asociación se quitará. Una compra pendiente
   de ese proveedor y repuesto impide retirarla. Las compras ya recibidas y sus
   costos históricos se conservan al retirar una oferta del catálogo actual.
5. Para dejar de utilizar un proveedor, editarlo y desmarcar **Proveedor activo**.

### Bodegas y mínimos

1. Abrir **Bodegas → Nueva bodega**. Registrar código único, nombre, dirección
   opcional y estado.
2. En **Repuestos y mínimos**, elegir repuesto y definir el stock mínimo local.
   Puede ser cero. La misma pieza puede tener mínimos distintos por bodega.
3. Al asociar una pieza nueva se muestra existencia cero. Si la bodega ya tiene
   movimientos del repuesto, se conserva su existencia calculada.
4. **Editar mínimo** cambia únicamente el nivel de reposición. La existencia es
   de consulta: aumenta al recibir compras y disminuye al consumir en reparaciones.
5. Se puede desactivar/reactivar una bodega; los registros y movimientos se conservan.

El registro y recepción de compras es el siguiente bloque. Esta entrega prepara
proveedor/repuesto y bodega/repuesto, que son requisitos del detalle de compra.
La pantalla general de inventario y el kardex también siguen pendientes.

## Reglas y compatibilidad

- API y SQL exigen BODEGA o ADMIN activos. Cada operación usa el UsuarioID de
  la sesión, nunca un actor enviado por el formulario. POST/PUT requieren CSRF.
- Los tres catálogos principales se desactivan; no se borran sus registros.
  Retirar una oferta elimina solo la relación actual ProveedorRepuesto, con el
  control de compras pendientes. No elimina compras, detalles, consumos o pagos.
- Las ediciones envían una revisión del registro. SQL bloquea, compara y rechaza
  una versión desactualizada con 409. El formulario conserva lo escrito y permite
  cargar los datos actuales para revisarlos antes de guardar.
- Los mínimos comparan `stockMinimoEsperado`; un alta envía null. Se rechazan
  asociaciones duplicadas y actualizaciones que omitan el mínimo anterior.
- Se validan longitudes antes de convertir a varchar/nvarchar de las tablas.
  Precios: decimal(12,2), de cero a 9999999999.99. Mínimos: enteros de cero a
  2147483647. No se redondea un precio de tres decimales ni se trunca un mínimo.
- `trAuditoriaPrecio` se reutiliza. Al editar un repuesto, el procedimiento fija
  el usuario de aplicación durante el UPDATE y restaura el contexto anterior,
  tanto al completar como al fallar. La conexión no conserva al último editor.
- Consumos, precios facturados y costos de compras permanecen históricos.
  El costo de referencia sigue siendo el criterio del modelo existente; no se
  incorpora PEPS ni promedio ponderado.
- El rol SQL `techcare_app` recibe DENY de DML directo sobre los seis catálogos
  administrados aquí; los procedimientos dbo escriben mediante cadena de propiedad.
  Los procedimientos transaccionales anteriores siguen funcionando con esa cadena.
- No se añaden tablas ni columnas al modelo. El 26 agrega vistas y procedimientos
  de gestión. La API devuelve DTO con campos explícitos; no expone LoginSQL,
  contraseñas ni hashes al consultar la auditoría o los catálogos.

## Rutas

| Método | Ruta | Uso |
|---|---|---|
| GET / POST | `/api/repuestos` | Buscar o registrar |
| GET / PUT | `/api/repuestos/{id}` | Consultar o editar |
| GET | `/api/repuestos/{id}/precios` | Auditoría de costos y precios |
| GET / POST | `/api/repuestos/categorias` | Consultar o crear categorías |
| PUT | `/api/repuestos/categorias/{id}` | Renombrar categoría |
| GET / POST | `/api/proveedores` | Buscar o registrar |
| GET / PUT | `/api/proveedores/{id}` | Consultar o editar |
| GET | `/api/proveedores/{id}/repuestos` | Consultar catálogo ofrecido |
| PUT | `/api/proveedores/{id}/repuestos/{repuestoId}` | Asociar, editar referencia o retirar |
| GET / POST | `/api/bodegas` | Buscar o registrar |
| GET / PUT | `/api/bodegas/{id}` | Consultar o editar |
| GET | `/api/bodegas/{id}/repuestos` | Consultar piezas, mínimos y existencias |
| PUT | `/api/bodegas/{id}/repuestos/{repuestoId}` | Asociar o actualizar mínimo |

Listados con `buscar?`, `activo?` y, para repuestos, `categoriaId?`. La búsqueda se
aplica en SQL mediante parámetros y texto literal. Se pagina en el navegador
sobre el conjunto completo devuelto por esos filtros.

## Validación entregada

- Backend: 195 pruebas sin fallos, incluidas 35 nuevas de abastecimiento. Las
  pruebas HTTP simulan JDBC para comprobar permisos, actor, DTO, validaciones,
  revisiones, importes exactos y parámetros enviados a cada procedimiento.
- Frontend: comprobación de TypeScript y compilación de producción.
- Navegador con API simulada: categorías, alta/edición de repuestos y proveedores,
  rechazo de duplicados, edición desactualizada y recuperación, auditoría,
  activación/desactivación, oferta y retiro, protección por compra pendiente,
  bodegas, mínimos cero, conflicto de mínimos, roles y formulario móvil.
- Los scripts 26 y 27 se analizaron con el dialecto T-SQL. El 27 reutiliza la
  preparación corregida del 20, incluida la relación ProveedorRepuesto antes
  de registrar la compra del escenario.
- La corrección incremental 29 cambia el 26 y el 27: el guion literal se ubica
  al inicio de los conjuntos de caracteres permitidos, y las tablas temporales
  de categorías, proveedores y bodegas no heredan IDENTITY. El resultado del
  procedimiento se recibe completo, incluido el ID. Los casos 7 y 27 cubren
  punto, guion, guion bajo y barra; los cuatro nuevos comprueban códigos en su
  longitud máxima y el rechazo de caracteres no permitidos.
- Para una instalación que ya tiene el patch 28, aplicar solamente el 29;
  ejecutar de nuevo el 26 completo y después el 27 completo. No se necesita
  reiniciar Java/Vite para esta corrección SQL.
- SQL Server no está disponible aquí. Los 59 casos del 27 se ejecutan en su
  instancia; no se declaran aprobados aquí. Las pruebas entre dos sesiones
  concurrentes permanecen dentro de la validación final del proyecto.

Referencia de contexto de auditoría:
https://learn.microsoft.com/sql/relational-databases/system-stored-procedures/sp-set-session-context-transact-sql

Referencias de la corrección SQL:
https://learn.microsoft.com/sql/t-sql/language-elements/like-transact-sql
https://learn.microsoft.com/sql/t-sql/queries/select-into-clause-transact-sql
