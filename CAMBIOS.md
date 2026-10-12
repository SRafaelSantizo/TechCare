# Cambios en los triggers

Fecha: 11 de octubre de 2026 (Guatemala).

La versión inicial tenía 28 triggers. Esta versión tiene 16, con una protección
por tabla. Se agrupan validación y protección histórica en el mismo objeto.
Se mantienen 35 tablas, 7 vistas, 4 funciones, 14 procedimientos y 17 índices
explícitos. El diagrama y la normalización siguen describiendo el mismo modelo.

## Objetos fusionados

| Tabla | Trigger actual | Trigger que se integra | Protección integrada |
|---|---|---|---|
| OrdenServicio | `trOrdenEstado` | `trOrdenServicioSinBorrado` | DELETE |
| Diagnostico | `trDiagnosticoValido` | `trDiagnosticoInmutable` | UPDATE y DELETE |
| Reparacion | `trReparacionValida` | `trReparacionSinBorrado` | DELETE |
| ReparacionActividad | `trActividadValida` | `trReparacionActividadInmutable` | UPDATE y DELETE |
| ReparacionRepuesto | `trConsumoValido` | `trReparacionRepuestoInmutable` | UPDATE y DELETE |
| Compra | `trCompraCiclo` | `trCompraSinBorrado` | DELETE |
| DetalleCompra | `trDetalleCompraValido` | `trDetalleCompraInmutable` | UPDATE y DELETE |
| MovimientoInventario | `trMovimientoIntegridad` | `trMovimientoInventarioInmutable` | UPDATE y DELETE |
| Factura | `trFacturaValida` | `trFacturaSinBorrado` | DELETE |
| FacturaDetalle | `trFacturaDetalleValido` | `trFacturaDetalleInmutable` | UPDATE y DELETE |
| Pago | `trPagoSaldo` | `trPagoInmutable` | UPDATE y DELETE |
| Entrega | `trEntregaValida` | `trEntregaInmutable` | UPDATE y DELETE |

## Qué significa el cambio

Las ocho tablas con historia inmutable ahora validan INSERT y rechazan UPDATE y
DELETE desde un mismo trigger AFTER. Las cuatro tablas de encabezados mantienen
sus cambios de estado autorizados y añaden la protección contra DELETE al trigger
de validación existente.

HistorialEstadoOrden y AuditoriaPrecioRepuesto conservan sus dos triggers
INSTEAD OF: cada una necesita su propia protección y no tenía un segundo trigger
que agrupar. Equipo y Repuesto conservan sus validaciones/auditoría originales.

Las FK y CHECK se evalúan antes de los triggers AFTER. Un DELETE rechazado por
una FK, o un UPDATE rechazado por un CHECK, puede devolver otro número de error;
la operación sigue rechazada. Las instrucciones que afectan cero filas tampoco
alteran historia y algunos mensajes pueden variar frente al trigger INSTEAD OF.

## Aplicación

Base nueva: scripts 01, 02, 03 y 04.

Base existente con la versión inicial: script 05 y después script 04.

## Validación

Se revisa estructura y correspondencia con el modelo; se conserva la lógica
original de validación y se agregan pruebas SQL de los controles agrupados.
Ejecutar los scripts en SQL Server y conservar sus resultados sigue pendiente.
