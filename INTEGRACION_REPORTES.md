# Reportes del taller

Conecta los doce reportes con SQL Server, la API y la interfaz. Parte del commit
`0dae159` (inventario y kardex con redondeo de costos corregido).

## Instalación sobre la base existente

1. Aplicar `40_Reportes_API.patch` desde la raíz del repositorio, en la terminal de IntelliJ:

   ```powershell
   git apply --check 40_Reportes_API.patch
   git apply 40_Reportes_API.patch
   ```

2. Detener el backend mientras se actualizan los objetos SQL.
3. En SSMS, ejecutar completo `38_Reportes_Procedimientos.sql` sobre TechCare.
   Requiere las actualizaciones anteriores, incluido el 33 y la corrección 36.
   Crea o actualiza dos funciones y cuatro procedimientos de consulta y validación;
   permite repetir su instalación.
4. Ejecutar `39_Pruebas_Reportes.sql` en desarrollo, sin otras escrituras concurrentes.
   Presenta **63 casos**. Cada caso crea sus propios datos, revierte la transacción,
   restaura el contexto de auditoría y compara las cantidades persistentes al terminar.
   Requiere ADMIN activo, los catálogos base y un medio de pago. Las identidades
   pueden dejar huecos. Un error al preparar los datos también se informa como FAIL.
5. Iniciar nuevamente backend y frontend. Abrir **Servicios → Reportes**.
   ADMIN dispone de los doce; los demás roles ven su catálogo permitido.

No volver a ejecutar 01 ni 02. El 38 no agrega tablas, columnas ni datos y no cambia
los procesos de recepción, consumo, facturación o pago. Conserva la configuración
local de conexión y la DLL de autenticación.

## Reportes y permisos

ADMIN puede consultar todos los reportes. Los permisos adicionales son:

| Código | Reporte | Otros roles | Filtros |
| --- | --- | --- | --- |
| R01 | Órdenes activas por estado, prioridad y técnico | RECEPCION, TECNICO | Estado, técnico, desde, hasta |
| R02 | Historial de órdenes por cliente | RECEPCION | Cliente |
| R03 | Historial técnico por número de serie | RECEPCION, TECNICO | Serie exacta |
| R04 | Diagnósticos y reparaciones por técnico | TECNICO | Técnico, desde, hasta |
| R05 | Repuestos utilizados en reparaciones | BODEGA, TECNICO | Orden, técnico, bodega |
| R06 | Inventario actual por bodega | BODEGA | Bodega, categoría, repuesto |
| R07 | Existencias en mínimo o por debajo | BODEGA | Bodega, categoría, repuesto |
| R08 | Compras por proveedor | BODEGA | Proveedor, bodega, estado, desde, hasta |
| R09 | Movimientos de inventario y origen | BODEGA | Bodega, repuesto, desde, hasta |
| R10 | Facturas pendientes y sus abonos | CAJA | Cliente |
| R11 | Ingresos facturados por mes | CAJA | Cliente, desde, hasta |
| R12 | Trazabilidad completa de órdenes | Sólo ADMIN | Orden, cliente |

Un técnico sin otro rol habilitante consulta sólo las órdenes que le corresponden.
En R04 también se exige que sea autor del proceso. No puede pedir otro técnico ni
obtener opciones de órdenes o bodegas ajenas. La reasignación de una orden retira el
acceso del técnico anterior. Los permisos de varias funciones se combinan: una cuenta
TECNICO y RECEPCION tiene el alcance de recepción en R01/R03; TECNICO y BODEGA tiene
el alcance de bodega en R05. R04 conserva el alcance propio salvo ADMIN.

El catálogo autorizado es: ADMIN 12, TECNICO 4, BODEGA 5, RECEPCION 3 y CAJA 2 reportes.
SQL valida de nuevo cuenta, empleado activo y roles actuales en cada consulta,
incluida la búsqueda de opciones; no depende sólo de los permisos cargados al ingresar.

## Uso y significado de los resultados

- Elegir un reporte no ejecuta su consulta. Seleccionar filtros y pulsar
  **Generar reporte**. Dejar un filtro vacío incluye todos los registros permitidos.
- Los filtros con catálogo presentan hasta 100 coincidencias ordenadas. Escribir
  en su búsqueda permite localizar otras opciones; `%` y `_` se buscan literalmente.
  Los catálogos inactivos se conservan para consultar su historia.
- Las fechas son días UTC incluidos, desde `0001-01-01` hasta `9999-12-31`.
  Las horas de las filas se muestran en la zona horaria del navegador.
  Los meses de R11 se muestran como mes/año sin conversión a la zona local.
- La paginación se realiza en SQL: 25 filas por defecto, hasta 100 por solicitud.
  Las tarjetas resumen todo el filtro; cambiar de página conserva los totales.
  Si una página quedó fuera de rango, la respuesta usa la última disponible.
- Las URL conservan reporte, filtros aplicados y página al recargar y usar atrás
  o adelante. Cambiar filtros deja un aviso hasta generar de nuevo. **Limpiar**
  vuelve al formulario sin consultar; **Actualizar resultados** repite los filtros aplicados.
- **Ver detalle** presenta todos los campos del registro, incluidos textos largos
  que no se muestran en la tabla. Los resultados vacíos y errores permiten volver a intentar.

Reglas de lectura de cada área:

- R01 incluye el técnico asignado aunque todavía no exista diagnóstico y excluye
  órdenes finales. LISTO sigue siendo una orden activa hasta su entrega.
- R02 conserva clientes sin equipos y equipos sin órdenes. R03 conserva equipos sin
  servicio para ADMIN/RECEPCION; un técnico sólo ve órdenes de su alcance.
- R04 presenta una fila de diagnóstico y otra de reparación. El costo estimado y
  la mano de obra de reparación corresponden a etapas distintas; no se suman como ingreso.
- R05 conserva cantidad, costo y precio históricos de cada consumo. R06 usa el
  promedio móvil actual por bodega con seis decimales. R07 incluye existencia igual
  al mínimo, también cero con mínimo cero, y calcula el faltante sin valores negativos.
- R08 presenta líneas de compras pendientes, recibidas y anuladas. Su costo total
  corresponde a las líneas seleccionadas por los filtros; una pendiente no es una entrada.
- R09 presenta el origen y saldo histórico de cada movimiento. Para los saldos
  inicial/final de un período se mantiene la pantalla de Kardex.
- R10 tiene una fila por abono, o una fila con pago vacío si la factura no tiene pagos.
  El encabezado se repite en las filas, pero las tarjetas cuentan cada factura y saldo
  una sola vez. Las facturas anuladas o sin saldo pendiente no aparecen.
- R11 agrupa facturas emitidas por su mes de emisión. Es facturación devengada,
  distinta del efectivo cobrado; excluye anuladas y no multiplica por pagos o repuestos.
- R12 conserva una fila por orden, incluso incompleta. El detalle muestra tres listas
  independientes: cambios de estado, repuestos/movimientos y pagos. Dos consumos y
  dos pagos permanecen como dos registros en cada lista, sin producto cartesiano.

Los nombres de clientes, empleados y catálogos son los actuales, salvo los campos
fiscales conservados en la factura y los responsables guardados en eventos de compra.
Renombrar un catálogo no reescribe costos, precios, pagos ni importes históricos.

`03_Reportes.sql` conserva las consultas originales de referencia. La aplicación
utiliza el 38, actualizado para asignaciones y promedio por bodega. En el 03 Hasta
era un instante exclusivo; en la API y la pantalla Hasta es un día UTC incluido.
No es necesario ejecutar el 03 para instalar este módulo.

## Contrato de API

| Método | Ruta | Uso |
| --- | --- | --- |
| GET | `/api/reportes` | Catálogo de reportes permitido para la sesión |
| GET | `/api/reportes/{codigo}` | Filas, indicadores, total, página y total de páginas |
| GET | `/api/reportes/{codigo}/opciones?tipo=...&buscar=...` | Buscar opciones de un filtro permitido |

Los parámetros de consulta usan `clienteId`, `tecnicoId`, `bodegaId`, `proveedorId`,
`ordenId`, `categoriaId`, `repuestoId`, `estado`, `serie`, `desde`, `hasta`, `pagina`
y `tamano`, sólo donde la tabla anterior los permite. IDs y página deben ser enteros
positivos; serie hasta 80 caracteres; búsqueda de opciones hasta 150. Se rechazan
parámetros duplicados, desconocidos y filtros ajenos al reporte.

El usuario actor procede de la sesión, nunca de un parámetro del navegador. Sin
sesión devuelve 401; acceso ajeno 403; código desconocido 404; filtros inválidos 400.
Una espera o interbloqueo ofrece actualizar con respuesta 409. Otros errores de
base de datos se presentan como 503 sin revelar detalles internos.

Las columnas del reporte son un contrato explícito: clave, título, tipo y visibilidad.
Las filas transportan escalares como texto o null para conservar bigint, importes y
seis decimales. El total y la paginación son números. Las fechas y horas llevan UTC.
En R12 las listas son cadenas JSON independientes; sus bigint e importes también son
cadenas exactas. El frontend no calcula totales financieros desde las filas.

Las consultas usan parámetros JDBC y SQL estático, con una transacción SERIALIZABLE
de lectura para que resumen y página correspondan al mismo estado. Pueden esperar
por una operación en curso. No se utilizan lecturas sucias ni se cambian existencias.

## Verificación de esta entrega

- Backend: **315 pruebas correctas**, incluidas 47 nuevas de reportes. Usan JDBC
  simulado y cubren los doce contratos, sesión, actor, validación, precisión,
  paginación, transacción de lectura y errores controlados.
- Frontend: TypeScript y compilación de producción correctos.
- Navegador con API simulada: **13 escenarios correctos**, los doce reportes,
  escritorio/móvil de 390 px, filtros, fechas, historial del navegador, precisión,
  detalle y permisos. Sin errores JavaScript ni solicitudes de escritura.
- SQL 38 y 39: análisis sintáctico T-SQL completo. El 39 incluye 63 casos de roles,
  historial incompleto, Unicode, importes, saldos, filtros y rollback.
  **Su ejecución real en SQL Server está pendiente en la instancia del proyecto**;
  las pruebas con JDBC simulado no sustituyen esa verificación.

Después de aplicar: ejecutar el 39, generar reportes con las cinco cuentas demo de
distintos roles y comprobar una compra recibida, un consumo y una factura con varios
abonos. El script es secuencial; no demuestra concurrencia entre sesiones reales.

El siguiente bloque previsto es conectar el resumen general del taller con datos
reales; después corresponde la validación integral y la documentación final.

## Corrección de colecciones vacías de R12

`41_Correccion_Reportes_R12.patch` se aplica sobre el bloque 40 ya instalado.
Actualiza el 38 para devolver `[]` en las listas sin registros, también cuando
no existe reparación o factura. Mantiene null en los campos de esas etapas y
conserva los registros presentes. Cambia la consulta SQL real, además de las pruebas.

Después de aplicar el 41, detener el backend, ejecutar nuevamente el **38** y
luego el **39** completo. El 39 tiene ahora **63 casos**: conserva los 60 originales,
distingue la causa del caso 14 y agrega reparación sin repuestos, factura sin abonos
y consulta conjunta de una orden completa y otra incompleta. Cada caso revierte
sus propios datos como antes. Reiniciar el backend; este ajuste no requiere
cambios ni compilación de Java o React.

Las verificaciones locales de esta corrección cubren sintaxis T-SQL y aplicación
del patch. La confirmación de los 63 casos corresponde a SQL Server del proyecto.
