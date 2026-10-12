USE [TechCare];
GO
SET NOCOUNT ON; SET XACT_ABORT ON;
GO
-- Ejecutar después de 02. Aserciones sobre el fixture y pruebas reversibles.
-- No deshabilita restricciones. Si una aserción falla, THROW detiene ese bloque.
IF (SELECT COUNT_BIG(1) FROM dbo.Usuario)<10 OR (SELECT COUNT_BIG(1) FROM dbo.Cliente)<30
 OR (SELECT COUNT_BIG(1) FROM dbo.Equipo)<45 OR (SELECT COUNT_BIG(1) FROM dbo.OrdenServicio)<60
 OR (SELECT COUNT_BIG(1) FROM dbo.Diagnostico)<45 OR (SELECT COUNT_BIG(1) FROM dbo.Reparacion)<35
 OR (SELECT COUNT_BIG(1) FROM dbo.Repuesto)<30 OR (SELECT COUNT_BIG(1) FROM dbo.Bodega)<3
 OR (SELECT COUNT_BIG(1) FROM dbo.Inventario)<60 OR (SELECT COUNT_BIG(1) FROM dbo.Proveedor)<8
 OR (SELECT COUNT_BIG(1) FROM dbo.Compra)<20 OR (SELECT COUNT_BIG(1) FROM dbo.MovimientoInventario)<100
 OR (SELECT COUNT_BIG(1) FROM dbo.Factura)<30 OR (SELECT COUNT_BIG(1) FROM dbo.Pago)<40
 THROW 51901,N'No se alcanzaron las cantidades mínimas.',1;
IF EXISTS(SELECT 1 FROM dbo.vInventario WHERE Existencia<0) THROW 51902,N'Stock negativo.',1;
IF EXISTS(SELECT 1 FROM dbo.vFacturaSaldo WHERE Saldo<0) THROW 51903,N'Sobrepago.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Cliente AS c WHERE NOT EXISTS(SELECT 1 FROM dbo.Equipo AS e INNER JOIN dbo.OrdenServicio AS o ON o.EquipoID=e.EquipoID WHERE e.ClienteID=c.ClienteID)) THROW 51904,N'Falta cliente sin órdenes.',1;
IF NOT EXISTS(SELECT EquipoID FROM dbo.OrdenServicio GROUP BY EquipoID HAVING COUNT_BIG(1)>=3) THROW 51905,N'Falta equipo con 3 órdenes.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.OrdenServicio AS o WHERE NOT EXISTS(SELECT 1 FROM dbo.Diagnostico WHERE OrdenID=o.OrdenID)) THROW 51906,N'Falta orden sin diagnóstico.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Diagnostico AS d WHERE NOT EXISTS(SELECT 1 FROM dbo.Reparacion WHERE DiagnosticoID=d.DiagnosticoID)) THROW 51907,N'Falta diagnóstico sin reparación.',1;
IF NOT EXISTS(SELECT ReparacionID FROM dbo.ReparacionRepuesto GROUP BY ReparacionID HAVING COUNT_BIG(1)>=2) THROW 51908,N'Falta reparación con varios repuestos.',1;
IF NOT EXISTS(SELECT RepuestoID FROM dbo.vInventario WHERE Existencia>0 GROUP BY RepuestoID HAVING COUNT_BIG(1)>=2) THROW 51909,N'Falta repuesto en varias bodegas.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.vInventario WHERE Existencia=0) OR NOT EXISTS(SELECT 1 FROM dbo.vInventario WHERE Existencia<StockMinimo) THROW 51910,N'Faltan stock cero o bajo mínimo.',1;
IF NOT EXISTS(SELECT FacturaID FROM dbo.Pago GROUP BY FacturaID HAVING COUNT_BIG(1)>=2) OR NOT EXISTS(SELECT 1 FROM dbo.vFacturaSaldo WHERE Saldo>0) THROW 51911,N'Faltan pagos parciales o saldo pendiente.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Compra WHERE Estado='PENDIENTE') OR NOT EXISTS(SELECT 1 FROM dbo.MovimientoInventario WHERE Tipo='E') OR NOT EXISTS(SELECT 1 FROM dbo.MovimientoInventario WHERE Tipo='S') THROW 51912,N'Faltan compras pendientes o movimientos.',1;
IF EXISTS(SELECT 1 FROM dbo.OrdenServicio AS o WHERE o.EstadoCodigo<>(SELECT TOP(1) h.EstadoNuevo FROM dbo.HistorialEstadoOrden AS h WHERE h.OrdenID=o.OrdenID ORDER BY h.HistorialID DESC)) THROW 51913,N'Estado actual distinto del historial.',1;
;WITH kardex AS (
 SELECT MovimientoID,ExistenciaResultante,SUM(CantidadFirmada) OVER(PARTITION BY BodegaID,RepuestoID ORDER BY MovimientoID ROWS UNBOUNDED PRECEDING) AS Calculada FROM dbo.vMovimientoInventario
)
SELECT MovimientoID INTO #KardexIncorrecto FROM kardex WHERE ExistenciaResultante<>Calculada;
IF EXISTS(SELECT 1 FROM #KardexIncorrecto) THROW 51914,N'Kardex inconsistente.',1;
DROP TABLE #KardexIncorrecto;
PRINT N'PASS: cantidades, escenarios, saldos, estados y kardex.';
GO

-- T04: cantidad mayor al stock; se rechaza sin crear consumo ni movimiento.
DECLARE @Rep int=(SELECT MIN(ReparacionID) FROM dbo.Reparacion WHERE Estado='EN_PROCESO'),
 @Bodega int,@Repuesto int,@Qty int,@Antes bigint=(SELECT COUNT_BIG(1) FROM dbo.MovimientoInventario),
 @Consumos bigint=(SELECT COUNT_BIG(1) FROM dbo.ReparacionRepuesto);
SELECT TOP(1) @Bodega=BodegaID,@Repuesto=RepuestoID,@Qty=CONVERT(int,Existencia+1) FROM dbo.vInventario ORDER BY BodegaID,RepuestoID;
BEGIN TRY
 EXEC dbo.spConsumirRepuesto @ReparacionID=@Rep,@BodegaID=@Bodega,@RepuestoID=@Repuesto,@Cantidad=@Qty,@UsuarioID=4;
 THROW 51920,N'FAIL T04: aceptó stock insuficiente.',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51019 THROW;
END CATCH;
IF (SELECT COUNT_BIG(1) FROM dbo.MovimientoInventario)<>@Antes OR (SELECT COUNT_BIG(1) FROM dbo.ReparacionRepuesto)<>@Consumos THROW 51921,N'FAIL T04: cambios parciales.',1;
PRINT N'PASS T04: stock insuficiente y rollback.';
GO

-- T07: la primera línea entra y la segunda falla; revierte toda la transacción.
DECLARE @Compra int,@Detalle dbo.TipoDetalleCompra,@Antes bigint=(SELECT COUNT_BIG(1) FROM dbo.MovimientoInventario),@Stock bigint=dbo.fnExistencia(1,1),@Error int=0;
INSERT @Detalle VALUES (1,1,1,3,23),(2,2,2,3,26);
BEGIN TRY
 BEGIN TRANSACTION;
 EXEC dbo.spRegistrarCompra @NumeroCompra='TEST-ROLLBACK',@ProveedorID=1,@UsuarioID=7,@Detalle=@Detalle,@CompraID=@Compra OUTPUT;
 UPDATE dbo.Bodega SET Activo=0 WHERE BodegaID=2;
 EXEC dbo.spRecibirCompra @CompraID=@Compra,@UsuarioID=7;
 THROW 51922,N'FAIL T07: no ocurrió el error esperado.',1;
END TRY BEGIN CATCH
 SET @Error=ERROR_NUMBER();
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 IF @Error<>51030 THROW;
END CATCH;
IF EXISTS(SELECT 1 FROM dbo.Compra WHERE NumeroCompra='TEST-ROLLBACK') OR (SELECT COUNT_BIG(1) FROM dbo.MovimientoInventario)<>@Antes OR dbo.fnExistencia(1,1)<>@Stock OR NOT EXISTS(SELECT 1 FROM dbo.Bodega WHERE BodegaID=2 AND Activo=1) THROW 51923,N'FAIL T07: no revirtió todo.',1;
PRINT N'PASS T07: error en segunda línea revierte entradas, encabezado y cambio de bodega.';
GO

-- T09: dos abonos válidos; la prueba completa se revierte al terminar.
DECLARE @F int=(SELECT MIN(FacturaID) FROM dbo.vFacturaSaldo WHERE EstadoPago='PARCIAL'),@Saldo decimal(18,2),@Monto decimal(12,2);
SET @Saldo=dbo.fnSaldoFactura(@F); SET @Monto=ROUND(@Saldo*0.20,2);
BEGIN TRY
 BEGIN TRANSACTION;
 EXEC dbo.spRegistrarPago @FacturaID=@F,@MetodoPagoID=1,@Monto=@Monto,@UsuarioID=9;
 EXEC dbo.spRegistrarPago @FacturaID=@F,@MetodoPagoID=3,@Monto=@Monto,@UsuarioID=9;
 IF dbo.fnSaldoFactura(@F)<>@Saldo-2*@Monto THROW 51924,N'FAIL T09: saldo incorrecto.',1;
 ROLLBACK TRANSACTION;
 PRINT N'PASS T09: dos abonos y saldo correcto.';
END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO

-- T10: sobrepago por procedimiento y por INSERT SQL directo de un administrador.
DECLARE @F int=(SELECT MIN(FacturaID) FROM dbo.vFacturaSaldo WHERE EstadoPago='PARCIAL'),@Monto decimal(12,2),@Antes bigint=(SELECT COUNT_BIG(1) FROM dbo.Pago);
SET @Monto=CONVERT(decimal(12,2),dbo.fnSaldoFactura(@F)+1);
BEGIN TRY
 EXEC dbo.spRegistrarPago @FacturaID=@F,@MetodoPagoID=1,@Monto=@Monto,@UsuarioID=9;
 THROW 51925,N'FAIL T10: aceptó sobrepago.',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51038 THROW;
END CATCH;
BEGIN TRY
 INSERT dbo.Pago (FacturaID,MetodoPagoID,UsuarioRegistroID,Monto) VALUES (@F,1,9,@Monto);
 THROW 51926,N'FAIL T10 SQL: aceptó sobrepago.',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51130 THROW;
END CATCH;
IF (SELECT COUNT_BIG(1) FROM dbo.Pago)<>@Antes THROW 51927,N'FAIL T10: dejó un pago parcial.',1;
PRINT N'PASS T10: rechaza sobrepago por procedimiento y trigger.';
GO

-- R08: no recibir dos veces una compra.
DECLARE @C int=(SELECT MIN(CompraID) FROM dbo.Compra WHERE Estado='RECIBIDA');
BEGIN TRY
 EXEC dbo.spRecibirCompra @CompraID=@C,@UsuarioID=7;
 THROW 51928,N'FAIL: compra recibida dos veces.',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51027 THROW;
END CATCH;
PRINT N'PASS: recepción duplicada rechazada.';
GO

-- R03: usuario de recepción no puede diagnosticar.
DECLARE @O int=(SELECT MIN(OrdenID) FROM dbo.OrdenServicio WHERE EstadoCodigo='RECIBIDO'),@D int;
BEGIN TRY
 EXEC dbo.spRegistrarDiagnostico @OrdenID=@O,@UsuarioTecnicoID=2,@Descripcion=N'No autorizado',@CostoEstimado=1,@DiagnosticoID=@D OUTPUT;
 THROW 51929,N'FAIL: permitió técnico sin rol.',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51007 THROW;
END CATCH;
PRINT N'PASS: diagnóstico exige rol técnico.';
GO

-- R11: una factura por orden.
DECLARE @O int=(SELECT MIN(o.OrdenID) FROM dbo.OrdenServicio AS o INNER JOIN dbo.Factura AS f ON f.OrdenID=o.OrdenID WHERE o.EstadoCodigo='LISTO'),@F int;
BEGIN TRY
 EXEC dbo.spGenerarFactura @OrdenID=@O,@NumeroFactura='TEST-DUPLICADA',@UsuarioID=9,@FacturaID=@F OUTPUT;
 THROW 51930,N'FAIL: duplicó factura.',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51033 THROW;
END CATCH;
PRINT N'PASS: factura duplicada rechazada.';
GO

-- R13/entrega: saldo pendiente impide entregar.
DECLARE @O int=(SELECT MIN(OrdenID) FROM dbo.vFacturaSaldo WHERE EstadoPago='PARCIAL');
BEGIN TRY
 EXEC dbo.spEntregarOrden @OrdenID=@O,@UsuarioID=2,@NombreRecibe=N'Test';
 THROW 51931,N'FAIL: entregó con saldo pendiente.',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51041 THROW;
END CATCH;
PRINT N'PASS: no entrega con saldo pendiente.';
GO

-- T14: cambiar precios actuales no altera compras, consumos ni facturas.
DECLARE @P int=(SELECT MIN(RepuestoID) FROM dbo.ReparacionRepuesto),@Total decimal(18,2)=(SELECT SUM(Total) FROM dbo.vFacturaSaldo),
 @Historico decimal(18,2)=(SELECT SUM(CONVERT(decimal(18,2),Cantidad*PrecioUnitario)) FROM dbo.ReparacionRepuesto),
 @Compras decimal(18,2)=(SELECT SUM(CONVERT(decimal(18,2),Cantidad*CostoUnitario)) FROM dbo.DetalleCompra),
 @Auditoria bigint=(SELECT COUNT_BIG(1) FROM dbo.AuditoriaPrecioRepuesto);
BEGIN TRY
 BEGIN TRANSACTION;
 UPDATE dbo.Repuesto SET PrecioVenta=PrecioVenta+10,CostoReferencia=CostoReferencia+5 WHERE RepuestoID=@P;
 IF (SELECT SUM(Total) FROM dbo.vFacturaSaldo)<>@Total OR (SELECT SUM(CONVERT(decimal(18,2),Cantidad*PrecioUnitario)) FROM dbo.ReparacionRepuesto)<>@Historico OR (SELECT SUM(CONVERT(decimal(18,2),Cantidad*CostoUnitario)) FROM dbo.DetalleCompra)<>@Compras THROW 51932,N'FAIL T14: se alteró un precio histórico.',1;
 IF (SELECT COUNT_BIG(1) FROM dbo.AuditoriaPrecioRepuesto)<>@Auditoria+1 THROW 51933,N'FAIL: no auditó el precio.',1;
 ROLLBACK TRANSACTION;
 PRINT N'PASS T14: historia conservada y auditoría generada.';
END TRY BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO

-- R14: no borrar pagos.
BEGIN TRY
 DELETE FROM dbo.Pago WHERE PagoID=(SELECT MIN(PagoID) FROM dbo.Pago);
 THROW 51934,N'FAIL: eliminó un pago.',1;
END TRY BEGIN CATCH
 IF ERROR_NUMBER()<>51140 THROW;
END CATCH;
PRINT N'PASS: historial financiero inmutable.';
GO
-- C01: la versión consolidada tiene un trigger por cada tabla protegida.
IF (SELECT COUNT_BIG(1) FROM sys.triggers AS tr
    INNER JOIN sys.tables AS tb ON tb.object_id=tr.parent_id
    WHERE tb.schema_id=SCHEMA_ID(N'dbo') AND tr.is_ms_shipped=0) <> 16
    THROW 51940,N'Se esperan 16 triggers. Para una base anterior, aplicar primero el script 05.',1;
IF EXISTS (SELECT parent_id FROM sys.triggers
    WHERE is_ms_shipped=0 AND parent_class=1
    GROUP BY parent_id HAVING COUNT_BIG(1)>1)
    THROW 51941,N'Hay varios triggers sobre una misma tabla; revisar la actualización.',1;
PRINT N'PASS C01: 16 triggers, uno por tabla protegida.';
GO

-- C02: los pagos históricos no se modifican.
-- Si el cambio se aceptara por error, el ROLLBACK también revierte esta prueba.
DECLARE @Error int;
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Pago SET Referencia=N'Prueba reversible de protección' WHERE PagoID=(SELECT MIN(PagoID) FROM dbo.Pago);
    ROLLBACK TRANSACTION;
    THROW 51942,N'FAIL C02: se aceptó un cambio de historia.',1;
END TRY
BEGIN CATCH
    SET @Error=ERROR_NUMBER();
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF @Error<>51140 THROW;
END CATCH;
PRINT N'PASS C02: los pagos históricos no se modifican.';
GO

-- C03: los diagnósticos históricos no se modifican, incluso en varias filas.
-- Si el cambio se aceptara por error, el ROLLBACK también revierte esta prueba.
DECLARE @Error int;
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Diagnostico SET Descripcion=N'Prueba reversible de protección';
    ROLLBACK TRANSACTION;
    THROW 51942,N'FAIL C03: se aceptó un cambio de historia.',1;
END TRY
BEGIN CATCH
    SET @Error=ERROR_NUMBER();
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF @Error<>51140 THROW;
END CATCH;
PRINT N'PASS C03: los diagnósticos históricos no se modifican, incluso en varias filas.';
GO

-- C04: los movimientos históricos no se borran.
-- Si el cambio se aceptara por error, el ROLLBACK también revierte esta prueba.
DECLARE @Error int;
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.MovimientoInventario WHERE MovimientoID=(SELECT MIN(MovimientoID) FROM dbo.MovimientoInventario);
    ROLLBACK TRANSACTION;
    THROW 51942,N'FAIL C04: se aceptó un cambio de historia.',1;
END TRY
BEGIN CATCH
    SET @Error=ERROR_NUMBER();
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF @Error<>51140 THROW;
END CATCH;
PRINT N'PASS C04: los movimientos históricos no se borran.';
GO

-- C05: los detalles de factura no se borran.
-- Si el cambio se aceptara por error, el ROLLBACK también revierte esta prueba.
DECLARE @Error int;
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.FacturaDetalle WHERE FacturaID=(SELECT MIN(FacturaID) FROM dbo.FacturaDetalle);
    ROLLBACK TRANSACTION;
    THROW 51942,N'FAIL C05: se aceptó un cambio de historia.',1;
END TRY
BEGIN CATCH
    SET @Error=ERROR_NUMBER();
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF @Error<>51140 THROW;
END CATCH;
PRINT N'PASS C05: los detalles de factura no se borran.';
GO

-- C06: los costos históricos de compras no se modifican.
-- Si el cambio se aceptara por error, el ROLLBACK también revierte esta prueba.
DECLARE @Error int;
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.DetalleCompra SET CostoUnitario=CostoUnitario+1 WHERE CompraID=(SELECT MIN(CompraID) FROM dbo.DetalleCompra);
    ROLLBACK TRANSACTION;
    THROW 51942,N'FAIL C06: se aceptó un cambio de historia.',1;
END TRY
BEGIN CATCH
    SET @Error=ERROR_NUMBER();
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF @Error<>51140 THROW;
END CATCH;
PRINT N'PASS C06: los costos históricos de compras no se modifican.';
GO

PRINT N'Pruebas terminadas. Cada PASS indica una prueba realmente ejecutada en su SQL Server.';
