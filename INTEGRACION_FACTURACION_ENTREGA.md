# Facturación, pagos, entrega y factura PDF

Continuación del commit `5a4ee3d`: una orden LISTO y su reparación TERMINADA se
facturan desde Caja. Se admiten abonos; recepción entrega únicamente con una
factura EMITIDA y saldo cero. Al confirmar la entrega se descarga la factura PDF.

## Aplicar en IntelliJ y SSMS

1. Guardar `25_Facturacion_Pagos_Entrega_API.patch` en la raíz de TechCare, junto
   a `backend` y `frontend`. En la terminal de IntelliJ ejecutar:

   ```bash
   git apply --check 25_Facturacion_Pagos_Entrega_API.patch
   git apply 25_Facturacion_Pagos_Entrega_API.patch
   ```

   Aplicar una sola vez, sobre el módulo técnico con las pruebas 20 corregidas.
   Si el primer comando informa conflicto, revisar su salida antes de continuar.

2. En SSMS ejecutar completo `23_Facturacion_Entrega_Procedimientos.sql` sobre
   la base TechCare habitual. Es repetible: conserva datos y no reinicia la
   secuencia de facturas. Requiere el 19 instalado. No volver a ejecutar 01 o 02.
3. En DESARROLLO, sin transacciones abiertas ni escrituras concurrentes, ejecutar
   `24_Pruebas_Facturacion_Entrega.sql`. Incluye 40 casos propios con ROLLBACK y
   comprobación de cantidades antes/después. Puede dejar huecos de identidad y
   numeración; es normal. No crea facturas o pagos de negocio persistentes.
4. En IntelliJ recargar Maven: se agregó Apache PDFBox 3.0.8 al POM para generar
   PDF en Java. Las fuentes y su licencia vienen incluidas. Reiniciar backend y
   frontend como de costumbre; no se necesitan cuentas ni servicios de PDF.

## Recorrido visible

1. Finalizar la reparación desde el técnico asignado: debe quedar LISTO.
2. Entrar con CAJA o ADMIN → **Facturación** → **Facturar** en la fila de la orden.
   También se puede entrar por Órdenes → expediente → **Factura y pagos**.
3. Pulsar **Revisar y emitir factura**. Revisar cliente, NIT, dirección, cada
   concepto y el impuesto (12 % inicial, configurable en la vista previa).
   Confirmar la casilla y pulsar **Emitir factura**. El número `TCF-…` lo asigna
   el servidor. Si cambiaron los datos desde la revisión, se exige revisarlos.
4. Usar **Registrar pago / abono**. Elegir medio de pago, monto recibido y
   referencia opcional. Confirmar: se actualizan pagos, pagado y saldo. Puede
   cancelarse todo o hacerse varios abonos y con distintos medios de pago.
5. Con RECEPCION o ADMIN, abrir **Entrega**. Con saldo pendiente se indica lo
   que falta; con saldo cero aparece **Registrar entrega**. Ingresar nombre de
   quien recibe, documento opcional y observaciones. Confirmar la entrega real.
6. Queda ENTREGADO con su historial, receptor y usuario que entregó. Se inicia
   la descarga del PDF. **Descargar factura PDF** queda disponible en las dos
   secciones para obtenerlo otra vez, incluso después del cierre.

Si falla únicamente la descarga, la entrega ya registrada se conserva. Usar
**Reintentar PDF**; no volver a registrar la entrega.

## Qué muestra la factura PDF

- Número y fecha de factura; orden, equipo, marca/modelo y serie.
- Datos fiscales guardados al emitir: nombre, NIT y dirección.
- Quién recibió/atendió la orden, técnico responsable y quién emitió la factura.
- Trabajo realizado; mano de obra y cada repuesto por renglón, con cantidad,
  precio unitario e importe histórico. Subtotal, tasa, impuesto y total.
- Cada abono, fecha, medio, referencia, usuario que lo registró, pagado y saldo
  al momento de descargar.
- Después de entregar: receptor, documento, fecha, observaciones y quién entregó.
- Encabezados y páginas numeradas; una factura anulada se identifica en cada
  página. Los PDF se generan en el backend, con sesión y control de acceso.

Los conceptos, precios y datos fiscales se leen de la factura guardada. Cambiar
el catálogo o al cliente después no los reescribe. Los nombres de empleados y
datos descriptivos del equipo se consultan por los responsables/equipo originales;
si se corrigen esos datos maestros, una nueva descarga muestra la corrección.
Se incluyen fuentes para español y alfabetos cubiertos por DejaVu Sans; un glifo
no cubierto se representa con un cuadro. Las fechas se muestran en Guatemala.
El PDF corresponde a la factura interna del sistema; este bloque no integra FEL.

## Cambios y reglas de base

El 23 reutiliza `spGenerarFactura`, `spRegistrarPago` y `spEntregarOrden` del
maestro mediante procedimientos de API que validan sesión, rol, estado, límites
de texto y decimales antes de convertir a los tipos de las tablas.

Se agrega `SeqFacturaApi`, la tabla auxiliar normalizada `SolicitudPagoApi`
(identificador de intento → PagoID único) y su protección histórica. El mismo
intento de pago con idéntico actor, factura, método, monto y referencia devuelve
la factura sin insertar otro abono. Cambiar sus datos se rechaza. La interfaz
conserva el intento en esa sesión del navegador ante un fallo de red o del
servidor, incluso al recargar, y permite verificarlo con el mismo identificador.
Antes de intentar un pago nuevo desde otro navegador, revisar los pagos existentes.

Se exige `saldoEsperado` al crear un abono: si otra caja cobró mientras se
revisaba, devuelve 409 y se actualiza para confirmar otra vez. Orden y factura
se bloquean durante la escritura; el maestro vuelve a validar el saldo dentro
de esa transacción. No se aceptan sobrepagos ni montos con tres decimales.

`vFacturaSaldo` acota los agregados a `decimal(18,2)` antes de sumar impuesto y
restar pagos; conserva los centavos y evita multiplicar conceptos al unir abonos.
Las facturas en cero quedan PAGADA sin exigir un pago ficticio. La previsualización
calcula importes en SQL y devuelve una revisión que se comprueba al emitir.

Facturar y entregar no vuelven a consumir inventario. La salida ocurrió cuando
el técnico confirmó el repuesto en Reparación. Solo CAJA/ADMIN emiten y cobran;
solo RECEPCION/ADMIN entregan. El técnico asignado puede consultar y descargar,
con el mismo filtro de asignación del expediente. BODEGA no accede a estas rutas.
La lectura de los datos para PDF es una transacción serializable corta; termina
antes de componer el documento. No se envía correo ni se solicita dato de tarjeta.

La anulación de facturas desde la interfaz continúa pendiente. Tampoco se añade
modificación de importes históricos ni eliminación de pagos o entregas.

## Validación

- `bash mvnw test` en `backend`: 160 pruebas, sin fallos (30 nuevas de caja/PDF).
  Las pruebas de API simulan JDBC; no sustituyen la ejecución de procedimientos.
- `npm --prefix frontend run build`: comprobación de TypeScript y producción.
- Navegador con API simulada: emisión, PDF real, abono parcial y total, respuesta
  perdida seguida de recarga/reintento sin duplicar, saldo concurrente, permisos,
  entrega con descarga automática, servicio gratuito y fallo recuperable del PDF.
- Se renderizaron los PDF de ejemplo y de varias páginas para revisar texto,
  columnas, responsables, últimos conceptos/pagos y pies de página.
- El 24 reutiliza el montaje corregido del 20, incluido `ProveedorRepuesto`.
  SQL Server no está disponible en este entorno: sus 40 casos se ejecutan en su
  instancia. No se declara que hayan pasado aquí ni que se hayan probado dos
  sesiones de SQL Server a la vez.

Referencia de la dependencia: https://pdfbox.apache.org/3.0/getting-started.html
