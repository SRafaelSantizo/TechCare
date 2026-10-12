# Triggers de TechCare, desde cero

Un trigger es código que SQL Server ejecuta automáticamente cuando una instrucción
inserta, modifica o elimina datos en una tabla. Se escribe una vez y actúa cada vez
que ocurre el evento definido, también cuando el cambio se intenta desde SSMS.

Ejemplo de este proyecto: al cambiar el precio de un repuesto, SQL Server guarda
el precio anterior y el nuevo en AuditoriaPrecioRepuesto. La aplicación realiza
el UPDATE; el trigger realiza la auditoría dentro de esa misma transacción.

## Lo que conviene aprender primero

| Elemento | Significado |
|---|---|
| `ON dbo.Repuesto` | Tabla que activa ese trigger. |
| `AFTER UPDATE` | Se ejecuta después de una modificación que supera las restricciones. |
| `INSERT`, `UPDATE`, `DELETE` | Insertar, modificar y eliminar filas. |
| `inserted` | Tabla temporal lógica con las filas nuevas. |
| `deleted` | Tabla temporal lógica con las filas anteriores. |
| `IF EXISTS (...)` | Comprueba si existe al menos una fila que cumple una condición. |
| `THROW` | Genera un error cuando se viola una regla. En estos triggers revierte la operación inválida. |
| `SET NOCOUNT ON` | Evita mensajes adicionales de filas afectadas; no cambia las validaciones. |

`inserted` y `deleted` son nombres especiales disponibles dentro del trigger.
SQL Server las prepara automáticamente. No son tablas que ustedes deban crear.

| Operación | `inserted` | `deleted` |
|---|---|---|
| INSERT | Filas que se insertan | Vacía |
| UPDATE | Valores nuevos | Valores anteriores |
| DELETE | Vacía | Filas que se eliminan |

Una sola instrucción puede afectar varias filas. Por eso el proyecto usa JOIN,
EXISTS e INSERT ... SELECT sobre esas tablas, en lugar de asumir una única fila.

## Procedimiento y trigger dentro del mismo proceso

El backend llama explícitamente a `spRegistrarPago`. Ese procedimiento comprueba
el rol y el saldo, e intenta insertar el pago. Al insertar, SQL Server activa
automáticamente `trPagoSaldo`, que vuelve a proteger el saldo y la historia.

Un procedimiento se llama con EXEC. Un trigger se activa por el cambio de su
tabla. Las FK, UNIQUE y CHECK siguen encargándose de sus propias restricciones.

## Qué simplificamos

La versión anterior tenía 28 triggers. Esta tiene 16: se unieron doce pares que
actuaban sobre la misma tabla. Cada tabla protegida tiene un único trigger.

Ejemplo: Pago tenía un trigger para validar el abono y otro para impedir cambiar
o borrar pagos anteriores. Ahora `trPagoSaldo` realiza ambas funciones.

Su estructura es:

```sql
-- Esquema explicativo; el maestro contiene la definición completa.
-- CREATE TRIGGER ... ON dbo.Pago AFTER INSERT, UPDATE, DELETE
-- 1. Si deleted contiene filas: rechazar cambios o borrados de pagos históricos.
-- 2. Para un pago nuevo: validar usuario, factura, fecha y saldo.
```

Mantener 16 permite conservar reglas sobre varias tablas y controles de SQL
directo. El mínimo de dos del enunciado es una cantidad mínima, no una cantidad
que obligue a reducir todas las protecciones a dos objetos.

## Los 16 triggers y su función

| Trigger | Tabla | Función |
|---|---|---|
| `trOrdenEstado` | OrdenServicio | Valida estados, registra historial y protege contra borrado. |
| `trEquipoPropietario` | Equipo | Conserva propietario, serie y modelo de equipos con historial. |
| `trDiagnosticoValido` | Diagnostico | Valida técnico, estado y fecha; conserva el diagnóstico registrado. |
| `trReparacionValida` | Reparacion | Valida inicio y cierre; conserva datos originales y evita borrado. |
| `trActividadValida` | ReparacionActividad | Valida tareas de reparaciones activas y conserva sus registros. |
| `trConsumoValido` | ReparacionRepuesto | Valida reparación, bodega y repuesto; conserva el consumo histórico. |
| `trCompraCiclo` | Compra | Valida recepción y anulación; protege el encabezado contra borrado. |
| `trDetalleCompraValido` | DetalleCompra | Valida proveedor y destino; conserva cantidades y costos de las líneas. |
| `trMovimientoIntegridad` | MovimientoInventario | Valida origen, fechas, saldo del kardex y stock no negativo; conserva movimientos. |
| `trFacturaValida` | Factura | Valida emisión y anulación; protege datos históricos y evita borrado. |
| `trFacturaDetalleValido` | FacturaDetalle | Comprueba conceptos, cantidades y precios del servicio; conserva las líneas. |
| `trPagoSaldo` | Pago | Evita sobrepagos y conserva los abonos ya registrados. |
| `trEntregaValida` | Entrega | Exige receptor y fecha válidos, factura pagada y conserva la entrega. |
| `trAuditoriaPrecio` | Repuesto | Registra costo/precio anterior y nuevo cuando cambian. |
| `trHistorialEstadoOrdenInmutable` | HistorialEstadoOrden | Protege los eventos históricos contra UPDATE y DELETE. |
| `trAuditoriaPrecioRepuestoInmutable` | AuditoriaPrecioRepuesto | Protege los registros de auditoría contra UPDATE y DELETE. |

Los dos últimos conservan INSTEAD OF UPDATE, DELETE: interceptan esas acciones y
las rechazan. Los otros controles agrupados usan AFTER. Las FK y CHECK pueden
rechazar una operación antes de que se ejecute un AFTER; el dato sigue protegido.

## Primera práctica: ver una auditoría

Después de ejecutar el maestro y los datos de prueba, abrir una consulta en SSMS.
Este ejemplo cambia un precio dentro de una transacción y revierte todo al final.

```sql
USE TechCare;
GO
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @RepuestoID int = (SELECT MIN(RepuestoID) FROM dbo.Repuesto);

    UPDATE dbo.Repuesto
    SET PrecioVenta = PrecioVenta + 10
    WHERE RepuestoID = @RepuestoID;

    SELECT RepuestoID, PrecioAnterior, PrecioNuevo, Fecha
    FROM dbo.AuditoriaPrecioRepuesto
    WHERE RepuestoID = @RepuestoID
    ORDER BY AuditoriaID DESC;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

Qué observar: el SELECT muestra el registro que agregó el trigger automáticamente.
El ROLLBACK revierte tanto el cambio de precio como su auditoría de prueba.

## Orden de estudio y defensa

1. Entender el ejemplo de auditoría de precios.
2. Leer la tabla de inserted/deleted.
3. Leer `trPagoSaldo`: protección histórica y validación de saldo.
4. Leer `trOrdenEstado`: cambios permitidos y registro de historial.
5. Revisar los demás usando su fila en la tabla anterior.
6. Ejecutar las pruebas de integridad y conservar los resultados reales.

Para explicar cualquiera: indicar la tabla, el evento que lo activa, la regla que
revisa y qué sucede cuando la regla se viola. Por ejemplo: trPagoSaldo se activa
al insertar un abono en Pago y rechaza una suma de pagos superior al total.

## Fuentes

- Microsoft Learn: [DML triggers](https://learn.microsoft.com/sql/relational-databases/triggers/dml-triggers).
- Microsoft Learn: [Tablas inserted y deleted](https://learn.microsoft.com/en-us/sql/relational-databases/triggers/use-the-inserted-and-deleted-tables).
- Microsoft Learn: [Triggers que manejan varias filas](https://learn.microsoft.com/en-us/sql/relational-databases/triggers/create-dml-triggers-to-handle-multiple-rows-of-data).
