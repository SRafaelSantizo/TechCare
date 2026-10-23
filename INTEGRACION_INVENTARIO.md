# Inventario y kardex

Este bloque conecta las consultas de inventario con la API y la interfaz. Parte del
commit `70caaf2`, que integra compras, recepción y promedio móvil por bodega.
Mantiene las credenciales, la DLL, los datos y los procesos de recepción y consumo.

## Instalación sobre la base existente

1. Conservar el commit de compras. Aplicar `35_Inventario_Kardex_API.patch` desde
   la raíz del repositorio, en la terminal de IntelliJ:

   ```powershell
   git apply --check 35_Inventario_Kardex_API.patch
   git apply 35_Inventario_Kardex_API.patch
   ```

2. Detener el backend mientras se actualizan los objetos SQL.
3. En SSMS, ejecutar completo `33_Inventario_Procedimientos.sql` sobre TechCare.
   Requiere el 30 ya instalado. El 33 crea o actualiza dos vistas, una función de
   filtrado y seis procedimientos de consulta/validación; se puede volver a ejecutar.
4. Ejecutar `34_Pruebas_Inventario.sql` en desarrollo, sin escrituras concurrentes.
   Presenta 54 resultados. Cada caso crea sus datos y revierte su transacción;
   comprueba las cantidades persistentes al terminar. Las identidades pueden dejar
   huecos. Requiere ADMIN activo y los catálogos base existentes.
5. Iniciar backend y frontend. Entrar con BODEGA o ADMIN y abrir Servicios → Inventario.

No volver a ejecutar 01 ni 02. El 33 no agrega columnas, modifica datos ni cambia
los triggers o procedimientos que registran compras y consumos.

## Inventario por bodega

- Una fila representa un repuesto asociado a una bodega. Conserva asociaciones sin
  movimientos, con existencia y costo cero. Un repuesto sin ninguna asociación no
  aparece: se agrega desde Bodegas.
- Filtros de búsqueda literal, bodega, categoría, estado de existencias y actividad
  de los catálogos. `%` y `_` se buscan como texto. Por defecto incluye inactivos.
- `activo=true`: bodega y repuesto activos. `activo=false`: cualquiera de los dos
  está inactivo. No es un permiso para mover stock de catálogos inactivos.
- Sin existencias: stock cero, incluso con mínimo cero. Alerta de mínimo: stock
  positivo menor o igual al mínimo. Disponible: stock mayor que el mínimo.
- Faltante: máximo entre mínimo menos existencia y cero. Igualar el mínimo genera
  alerta con faltante cero; no significa una cantidad sugerida de compra.
- El costo promedio mantiene seis decimales. El valor de existencias es cantidad
  por promedio, también con seis decimales. No es precio de venta ni valor fiscal.
- Las tarjetas resumen todos los resultados del filtro, no sólo la página visible.
  Se cuentan pares bodega/repuesto; no se suman unidades de repuestos distintos.
- Paginación en SQL, por defecto 25 filas, hasta 100 por solicitud. Las URL conservan
  filtros y página al recargar o usar atrás/adelante del navegador. Una página que
  quedó fuera de rango se ajusta a la última disponible en la respuesta.

## Kardex por repuesto y bodega

Abrir **Ver kardex** desde una fila. Muestra la existencia y el promedio actuales
separados de los saldos y promedios históricos del período consultado.

- Orden ascendente por MovimientoID, el mismo orden de integridad del kardex.
- Desde y hasta son días UTC incluidos. Las horas de las filas se presentan en la
  zona horaria del navegador. Un día local puede abarcar dos días UTC.
- Saldo inicial: movimientos anteriores a Desde; cero si no se indica Desde.
- Entradas y salidas: cantidades de ambos tipos dentro de las fechas seleccionadas.
- Saldo final: movimientos hasta el día Hasta, o todos si no se indica Hasta.
- Siempre se cumple inicial + entradas − salidas = final. Filtrar sólo entradas o
  sólo salidas cambia las filas y su cantidad, conservando el resumen de ambos tipos.
  Los totales tampoco dependen de la página. Un período sin movimientos puede tener
  saldo inicial y final distintos de cero.
- Cada fila conserva el origen real: compra/línea o reparación/línea y orden, ID del
  responsable, costo unitario del documento y saldo anterior/posterior del movimiento.
- El detalle presenta el importe, promedio anterior/posterior y valoración del saldo
  posterior; no sustituye esos promedios por el costo actual del repuesto.
- Los promedios reconstruidos durante la instalación del 30 se identifican como
  migrados. Si falta una valoración, se presenta como no disponible, nunca se inventa.
- Las recepciones nuevas por API usan el nombre conservado en EventoCompraApi. Las
  salidas y movimientos antiguos muestran el nombre actual del empleado junto a su
  ID histórico. El detalle explica esa diferencia. Proveedor y nombres de catálogos
  son los actuales, no fotografías fiscales del documento.
- BODEGA puede abrir el documento de compra. El enlace a una orden se ofrece a ADMIN;
  BODEGA ve su número como referencia, porque no tiene acceso al expediente técnico.

## API y seguridad

| Método | Ruta | Parámetros opcionales |
| --- | --- | --- |
| GET | `/api/inventario` | buscar, bodegaId, categoriaId, estadoStock, activo, pagina, tamano |
| GET | `/api/inventario/{bodegaId}/{repuestoId}/kardex` | desde, hasta, tipo, pagina, tamano |

Estados: `SIN_EXISTENCIA`, `BAJO`, `DISPONIBLE`. Tipos: `E`, `S`. Fechas ISO
`AAAA-MM-DD`. IDs positivos y tamaño entre 1 y 100. Búsqueda hasta 150 caracteres.
Filtros inexistentes devuelven un listado vacío; un kardex de una pareja no asociada
devuelve 404. Entradas inválidas devuelven 400, roles ajenos 403 y ausencia de sesión 401.

Ambas rutas requieren ADMIN/BODEGA en Spring Security. SQL vuelve a validar cuenta,
empleado activo y rol; el actor viene de la sesión autenticada. No hay endpoints de
escritura en este módulo. Las consultas JDBC usan parámetros, DTOs explícitos y
transacciones de lectura SERIALIZABLE para componer filas y resumen coherentes ante
otras operaciones. Una consulta puede esperar por una recepción o consumo en curso;
ante interbloqueo/timeout se ofrece actualizar. No se usan lecturas sucias.

Los importes decimales, saldos bigint y MovimientoID viajan como cadenas JSON para
evitar pérdidas en JavaScript. Las cantidades de cada línea y IDs int son números.
La respuesta no expone credenciales, login SQL ni campos internos de las tablas.

## Verificación funcional

1. Consultar una bodega con existencias y otra con asociaciones sin entradas.
2. Buscar un repuesto, filtrar mínimo/sin existencias y revisar las tarjetas.
3. Abrir su kardex y un movimiento; comprobar documento, responsable, costo y saldo.
4. Cambiar fechas y tipo. Verificar que los saldos del período sigan cuadrando.
5. Recibir una compra desde Compras; actualizar Inventario y Kardex. Debe aparecer
   una entrada y el nuevo promedio, sin cambiar los costos de filas anteriores.
6. Como técnico asignado, consumir un repuesto desde la orden; volver como BODEGA o
   ADMIN, actualizar y comprobar la salida. El técnico sigue usando su catálogo
   dentro de su orden, sin acceso al inventario administrativo.

La instalación no implementa ajustes manuales, traslados, devoluciones o recepciones
parciales. Esos movimientos necesitan procesos propios con origen y reglas definidos.
Los doce reportes, el resumen general del taller y los manuales finales se completan
en bloques posteriores.

El script 34 es secuencial y no demuestra concurrencia entre dos sesiones. Su ejecución
real corresponde a la instancia de SQL Server del proyecto; los tests de API usan
JDBC simulado y las verificaciones de navegador usan respuestas de prueba.

## Validación de esta entrega

- Backend: 268 pruebas, sin fallos ni omisiones, incluyendo 38 casos nuevos de
  inventario con JDBC simulado. Cubren permisos HTTP, actor de sesión, parámetros,
  transacciones de consulta, paginación, precisión y errores controlados.
- Frontend: TypeScript y compilación de producción correctos.
- Navegador con API simulada: 12 escenarios, escritorio y móvil de 390 px,
  filtros/paginación, navegación atrás, kardex, detalle, errores y roles; cero
  escrituras y cero errores de JavaScript.
- SQL 33/34: revisión estructural y sintáctica T-SQL. Los 54 casos del 34 se deben
  ejecutar en SQL Server; no se presentan como pruebas de motor ya ejecutadas.

## Corrección del redondeo del costo promedio (36 / 37)

Si ya aplicó el 35, aplicar encima `37_Correccion_Redondeo_Inventario.patch`.
Con el backend detenido, ejecutar `36_Corregir_Redondeo_Costos.sql`, después
`31_Pruebas_Compras.sql` y el `34_Pruebas_Inventario.sql` actualizado (54 casos).
Reiniciar el backend. El frontend no cambia en esta corrección.

La función fnPromedioEntrada ahora calcula con millonésimas enteras y separa
cociente y resto. Redondea una vez, hacia arriba al alcanzar media millonésima.
Así el promedio 218/14 se conserva como 15.571429; 14 unidades a ese promedio
valen 218.000006. Ese valor se mantiene como expectativa del caso 48.

La corrección no recalcula costos ya guardados ni modifica existencias,
valoraciones históricas, compras, consumos o facturas. La nueva función se usa
para las siguientes entradas. El script 30 se actualiza para instalaciones nuevas;
en la base existente sólo se ejecuta el 36, sin repetir 30 ni 33.

El 36 comprueba ocho cálculos dentro de la transacción de actualización de la
función y revierte su definición si alguno no coincide. Muestra antes/después
para el ejemplo 218/14. El 34 añade cuatro casos de redondeo y límites, y el 48
incluye valores reales en su detalle si vuelve a fallar.

Referencia del motor: [precisión y escala decimal de SQL Server](https://learn.microsoft.com/en-us/sql/t-sql/data-types/precision-scale-and-length-transact-sql).
La división que queda en la función es exacta, tras retirar el resto; no depende
de que una división fraccionaria preserve un dígito adicional para redondear.

Validación local: análisis sintáctico de SQL y contraste de la aritmética entera
contra Decimal con redondeo HALF_UP (10,008 casos, incluidos límites de tipos). La ejecución de las comprobaciones del 36,
los 60 casos del 31 y los 54 del 34 corresponde a SQL Server del proyecto.
