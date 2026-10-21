# Compras, recepción y costo promedio por bodega

Continuación del commit `1f02354` (repuestos, proveedores y bodegas).
El patch conecta compras pendientes, recepción completa, anulación y consulta de
costos por bodega. El costo de inventario deja de ser un dato editable del catálogo.

## Instalación en la base existente

1. Detener el backend durante la actualización SQL. Guardar
   `32_Compras_Recepcion_API.patch` en la raíz de TechCare y ejecutar en la
   terminal de IntelliJ:

   ```bash
   git apply --check 32_Compras_Recepcion_API.patch
   git apply 32_Compras_Recepcion_API.patch
   ```

2. En SSMS ejecutar completo el **26 actualizado** y después
   `30_Compras_Procedimientos.sql`. No volver a ejecutar 01 ni 02.
   El 30 es repetible: no reinicia compras, identidades, stock ni costos ya valorados.
3. En desarrollo, sin otras escrituras ni una transacción abierta, ejecutar
   `31_Pruebas_Compras.sql`: 60 casos con datos propios y ROLLBACK por caso.
   Comprueba también las cantidades persistentes de las tres tablas nuevas.
   Pueden quedar huecos en identidades y secuencias.
4. Reiniciar backend y frontend. No se agregan dependencias ni se modifican
   credenciales, DLL o configuración local.

El 27 incluido también se actualizó: los casos 16, 54 y 55 cambian el precio
de venta conservando el costo legado. Sus 59 escenarios continúan siendo útiles.
Para regresión adicional ejecutar 20, 24 y 27 después del 30; sus consumos de
prueba reciben previamente compras a Q12.25 y deben conservar ese costo.

## Uso en la aplicación

Entrar con BODEGA o ADMIN en **Servicios → Compras**.

1. **Nueva compra**: ingresar número único, proveedor activo y observaciones
   opcionales. Agregar una o varias líneas de repuesto, bodega, cantidad entera
   y costo unitario pagado al proveedor. Se permite costo cero.
2. El selector ofrece únicamente los repuestos del catálogo de ese proveedor
   que tienen una bodega asociada y activa. Si no hay opciones, configurarlos
   desde **Proveedores → Catálogo ofrecido** y **Bodegas → Repuestos y mínimos**.
   Un mismo repuesto puede comprarse a proveedores distintos.
3. Usar **Revisar compra** y revisar cantidades, destinos, costos y total.
   **Registrar compra pendiente** conserva el documento; todavía no genera entradas.
4. En el expediente, **Recibir compra** exige confirmar que llegaron todas las
   unidades. **Confirmar recepción** registra las entradas y el responsable,
   calcula cada promedio y deja la compra RECIBIDA en una sola transacción.
5. Una compra PENDIENTE puede anularse con motivo obligatorio. Conserva sus
   observaciones originales y registra quién anuló, cuándo y por qué. Recibidas
   y anuladas ya no admiten recepción ni anulación desde esta pantalla.

No se editan líneas ya registradas. Si una compra pendiente tiene un error,
anularla con su motivo y registrar otra con un número distinto. No se incorporan
recepciones parciales, devoluciones ni edición de costos históricos.

El listado permite filtrar por texto literal, estado, proveedor y fechas.
Los intervalos de fechas de registro son inclusivos y usan la fecha UTC de la BD;
la presentación de horas continúa usando la configuración es-GT existente.

La respuesta de un registro puede perderse después de guardarlo. El formulario
mantiene la misma solicitud al usar **Reintentar registro**. Una repetición con
los mismos datos y actor devuelve la compra ya creada; cambiar sus datos o actor
con ese identificador se rechaza. El número único da una segunda protección.

## Costo promedio móvil

En **Repuestos → Costos por bodega** y **Bodegas → Repuestos y mínimos** se
consultan existencia y promedio. No hay un campo editable de costo en el formulario
del repuesto. El precio de venta sigue siendo administrable y auditado.

Al recibir una entrada:

```text
nuevo promedio =
  (existencia anterior × promedio anterior + unidades recibidas × costo unitario)
  / (existencia anterior + unidades recibidas)
```

Por ejemplo, 10 unidades a Q45 y otras 10 recibidas a Q55 dejan 20 unidades
con promedio Q50. Se calcula por bodega, independientemente del proveedor.
Una salida parcial conserva el promedio. Al agotar las unidades queda en cero;
la siguiente entrada determina el nuevo promedio sin arrastrar unidades agotadas.

- `Inventario.CostoPromedio` conserva seis decimales. El stock sigue derivado
  de `vMovimientoInventario` y no se agrega un contador editable de existencias.
- Cada movimiento tiene una fila inmutable en `ValoracionInventario`, con
  promedio anterior, posterior y una marca de migración.
- El trigger de valoración toma el mismo bloqueo de Inventario que las entradas
  y salidas. La recepción original bloquea parejas en orden bodega/repuesto y la
  compra pendiente se bloquea antes de recibir. Dos intentos sobre la misma compra
  no pueden confirmar dos veces ni multiplicar stock o costo.
- `spConsumirRepuesto` ahora congela el promedio vigente de esa bodega, redondeado
  a centavos en el campo histórico existente de ReparacionRepuesto. La valoración
  conserva el promedio de seis decimales, independientemente de ese redondeo.
- Los importes de compras viajan como texto decimal en la API. El navegador
  calcula los totales de revisión con centavos enteros para evitar pérdida de
  precisión en compras grandes.
- `CostoReferencia` se conserva como dato legado por compatibilidad. El SQL
  rechaza cambiarlo desde el catálogo y crear un repuesto con costo manual distinto
  de cero. No interviene en los nuevos consumos ni equivale al promedio actual.

### Inicialización de existencias anteriores

La instalación recorre los movimientos existentes por MovimientoID y calcula
el promedio móvil de cada pareja usando los costos de las entradas recibidas.
Las salidas reducen unidades y conservan el promedio hasta agotar stock.
Esto inicializa el criterio de valoración para operaciones futuras.

No cambia cantidades, movimientos, costos guardados en consumos anteriores,
precios de venta, compras ni facturas. Las valoraciones migradas quedan marcadas.
El proceso valida que los saldos recorridos coincidan con el kardex antes de
confirmar; esquema, inicialización y nuevo trigger se instalan en una transacción.
Una repetición sin movimientos pendientes de valorar no recalcula ni modifica el
promedio existente.

## Historial, permisos y confirmaciones

- Compras, recepción, anulación y costos por bodega requieren BODEGA o ADMIN
  activos en la BD, además del control de sesión/rol HTTP. El actor sale de la sesión.
- POST exige CSRF. Cantidades e IDs fraccionarios no se convierten silenciosamente
  a enteros. Se validan longitudes y decimales antes de convertir en SQL.
- Se permiten entre 1 y 200 líneas por compra, con cantidad de 1 a 2147483647
  y costo de 0 a 9999999999.99. No se repite la pareja repuesto/bodega.
- La recepción y la anulación comparan la revisión de la compra bajo bloqueo.
  Los promedios se calculan con el inventario vigente al recibir; no se envían
  stock ni promedio desde el formulario.
- Los eventos API conservan nombre del responsable, usuario, fecha y observación.
  La anulación no sustituye las observaciones de registro. Compras anteriores
  muestran al usuario original y al receptor disponible en sus movimientos;
  no se inventan responsables ni fechas desconocidos de anulaciones antiguas.
- `SolicitudCompraApi`, `EventoCompraApi` y `ValoracionInventario` son inmutables.
  `techcare_app` no escribe directamente compras, detalles, inventario ni las tres
  tablas nuevas: los procedimientos dbo mantienen la cadena de propiedad.
- Las consultas de catálogo muestran los nombres vigentes de proveedor, bodega
  y repuesto; los costos, cantidades, movimientos y eventos conservan su historia.

## Rutas

| Método | Ruta | Uso |
|---|---|---|
| GET | `/api/compras` | Listado con buscar, estado, proveedorId, desde y hasta |
| POST | `/api/compras` | Registro con solicitudId y detalle |
| GET | `/api/compras/{id}` | Cabecera, líneas, recepción y eventos |
| POST | `/api/compras/{id}/recepcion` | Recepción completa con revision |
| POST | `/api/compras/{id}/anulacion` | Anulación con revision y motivo |
| GET | `/api/compras/catalogos/destinos?proveedorId=…` | Ofertas y destinos activos |
| GET | `/api/repuestos/{id}/costos` | Promedio y existencia por bodega |

## Validación entregada

- Backend: 230 pruebas aprobadas, incluidas 34 nuevas de compras. Las pruebas HTTP
  simulan JDBC y el gestor de transacciones; verifican roles, CSRF, actor,
  solicitudes, validaciones, precisión de importes, lecturas y errores.
- Frontend: TypeScript y compilación de producción.
- Navegador con API simulada: 10 escenarios aprobados, incluyendo líneas en dos
  bodegas, pares repetidos, respuesta perdida y reintento, revisión desactualizada,
  recepción, anulación, historia de recepción, costos de consulta, móvil y roles.
- SQL: revisión de sintaxis T-SQL del 30 y 31, también del SQL dinámico de migración
  y del trigger. Los 60 casos del 31 requieren ejecución en su instancia real.
- SQL Server no puede ejecutarse en este entorno. No se declaran aprobados aquí
  los casos SQL ni las pruebas con dos sesiones concurrentes. El 31 es secuencial;
  los bloqueos deben validarse entre sesiones antes de poner el sistema en producción.

Inventario general, kardex navegable, reportes y manuales con capturas siguen
siendo bloques posteriores. La consulta de promedio ya está disponible desde el
catálogo de Repuestos y las asociaciones de Bodegas.

Referencia del método de promedio móvil:
https://learn.microsoft.com/es-es/dynamics365/supply-chain/cost-management/moving-average
