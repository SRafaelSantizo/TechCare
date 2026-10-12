-- Actualiza únicamente los triggers de una base TechCare ya creada.
-- Después de ejecutarlo, corra 04_Pruebas_Integridad.sql.
-- Las tablas, sus registros y los demás objetos se conservan.
USE [TechCare];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'TechCare' OR OBJECT_ID(N'dbo.OrdenServicio', N'U') IS NULL
    THROW 51950, N'Este script requiere la base TechCare ya creada.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    DROP TRIGGER IF EXISTS dbo.trCompraSinBorrado;
    DROP TRIGGER IF EXISTS dbo.trDetalleCompraInmutable;
    DROP TRIGGER IF EXISTS dbo.trDiagnosticoInmutable;
    DROP TRIGGER IF EXISTS dbo.trEntregaInmutable;
    DROP TRIGGER IF EXISTS dbo.trFacturaDetalleInmutable;
    DROP TRIGGER IF EXISTS dbo.trFacturaSinBorrado;
    DROP TRIGGER IF EXISTS dbo.trMovimientoInventarioInmutable;
    DROP TRIGGER IF EXISTS dbo.trOrdenServicioSinBorrado;
    DROP TRIGGER IF EXISTS dbo.trPagoInmutable;
    DROP TRIGGER IF EXISTS dbo.trReparacionActividadInmutable;
    DROP TRIGGER IF EXISTS dbo.trReparacionRepuestoInmutable;
    DROP TRIGGER IF EXISTS dbo.trReparacionSinBorrado;

    -- trOrdenEstado: OrdenServicio
    EXEC sys.sp_executesql N'-- Valida el ingreso y los estados; guarda el historial y protege la orden contra borrado.
CREATE OR ALTER TRIGGER dbo.trOrdenEstado
ON dbo.OrdenServicio
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En DELETE hay filas anteriores y no hay filas nuevas.
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 51141, N''No se permite borrar físicamente OrdenServicio.'', 1;

    -- INSERT y UPDATE conservan las reglas originales del proceso.
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        LEFT JOIN deleted AS d ON d.OrdenID=i.OrdenID 
        WHERE d.OrdenID IS NULL 
            AND (i.EstadoCodigo<>''RECIBIDO'' 
            OR dbo.fnTieneRol(i.UsuarioRecepcionID,''RECEPCION'')=0))
        THROW 51101,N''Ingreso inválido o usuario sin rol de recepción.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.Equipo AS e ON e.EquipoID=i.EquipoID 
        INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID 
        WHERE e.Activo=0 
            OR c.Activo=0)
        THROW 51102,N''Equipo/cliente inactivo.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN deleted AS d ON d.OrdenID=i.OrdenID 
        WHERE i.EquipoID<>d.EquipoID 
            OR i.UsuarioRecepcionID<>d.UsuarioRecepcionID 
            OR i.FechaIngreso<>d.FechaIngreso 
            OR i.NumeroOrden<>d.NumeroOrden)
        THROW 51103,N''No se puede cambiar la identidad del ingreso.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN deleted AS d ON d.OrdenID=i.OrdenID 
        WHERE i.EstadoCodigo<>d.EstadoCodigo 
            AND (i.FechaCambio<d.FechaCambio 
            OR NOT EXISTS(SELECT 1 
        FROM dbo.TransicionEstadoOrden AS t 
        WHERE t.EstadoOrigen=d.EstadoCodigo 
            AND t.EstadoDestino=i.EstadoCodigo)))
        THROW 51104,N''Transición/fecha no permitida.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN deleted AS d ON d.OrdenID=i.OrdenID 
        WHERE i.EstadoCodigo<>d.EstadoCodigo 
            AND
 ((i.EstadoCodigo IN (''DIAGNOSTICO'',''ESPERANDO_AUTORIZACION'',''REPARACION'',''LISTO'') 
            AND dbo.fnTieneRol(i.UsuarioCambioID,''TECNICO'')=0) 
            OR (i.EstadoCodigo IN (''CANCELADO'',''ENTREGADO'') 
            AND dbo.fnTieneRol(i.UsuarioCambioID,''RECEPCION'')=0)))
        THROW 51105,N''Usuario no autorizado para el cambio.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        WHERE i.EstadoCodigo=''ESPERANDO_AUTORIZACION'' 
            AND NOT EXISTS(SELECT 1 
        FROM dbo.Diagnostico 
        WHERE OrdenID=i.OrdenID))
        THROW 51106,N''Requiere diagnóstico.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        WHERE i.EstadoCodigo IN (''REPARACION'',''LISTO'') 
            AND NOT EXISTS(SELECT 1 
        FROM dbo.Diagnostico AS d 
        INNER JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID 
        WHERE d.OrdenID=i.OrdenID 
            AND ((i.EstadoCodigo=''REPARACION'' 
            AND r.Estado=''EN_PROCESO'') 
            OR (i.EstadoCodigo=''LISTO'' 
            AND r.Estado=''TERMINADA''))))
        THROW 51107,N''Estado incompatible con la reparación.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        WHERE i.EstadoCodigo=''ENTREGADO'' 
            AND (NOT EXISTS(SELECT 1 
        FROM dbo.Entrega 
        WHERE OrdenID=i.OrdenID) 
            OR NOT EXISTS(SELECT 1 
        FROM dbo.vFacturaSaldo 
        WHERE OrdenID=i.OrdenID 
            AND Estado=''EMITIDA'' 
            AND Saldo=0)))
        THROW 51108,N''Entrega requiere registro y factura pagada.'',1;
 INSERT dbo.HistorialEstadoOrden (OrdenID,EstadoAnterior,EstadoNuevo,Fecha,UsuarioID,Observacion)
 SELECT i.OrdenID,d.EstadoCodigo,i.EstadoCodigo,i.FechaCambio,i.UsuarioCambioID,i.ObservacionCambio
 
        FROM inserted AS i 
        LEFT JOIN deleted AS d ON d.OrdenID=i.OrdenID 
        WHERE d.OrdenID IS NULL 
            OR i.EstadoCodigo<>d.EstadoCodigo;
END;';

    -- trEquipoPropietario: Equipo
    EXEC sys.sp_executesql N'-- Protege la identidad y el propietario de equipos que ya tienen historial.
CREATE OR ALTER TRIGGER dbo.trEquipoPropietario
ON dbo.Equipo
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN deleted AS d ON d.EquipoID=i.EquipoID 
        INNER JOIN dbo.OrdenServicio AS o ON o.EquipoID=i.EquipoID 
        WHERE i.ClienteID<>d.ClienteID 
            OR i.NumeroSerie<>d.NumeroSerie 
            OR i.ModeloEquipoID<>d.ModeloEquipoID)
        THROW 51109,N''Equipo con historial: propietario, serie y modelo no se cambian.'',1;
END;';

    -- trDiagnosticoValido: Diagnostico
    EXEC sys.sp_executesql N'-- Valida técnico, estado y fecha; conserva el diagnóstico como historia.
CREATE OR ALTER TRIGGER dbo.trDiagnosticoValido
ON dbo.Diagnostico
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N''Historia inmutable: no se permite modificar o borrar Diagnostico.'', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=i.OrdenID 
        WHERE dbo.fnTieneRol(i.UsuarioTecnicoID,''TECNICO'')=0 
            OR o.EstadoCodigo<>''DIAGNOSTICO'' 
            OR i.Fecha<o.FechaIngreso)
        THROW 51110,N''Diagnóstico no autorizado, estado/fecha inválido.'',1;
END;';

    -- trReparacionValida: Reparacion
    EXEC sys.sp_executesql N'-- Valida el inicio y cierre; protege los datos originales y evita borrar la reparación.
CREATE OR ALTER TRIGGER dbo.trReparacionValida
ON dbo.Reparacion
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En DELETE hay filas anteriores y no hay filas nuevas.
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 51141, N''No se permite borrar físicamente Reparacion.'', 1;

    -- INSERT y UPDATE conservan las reglas originales del proceso.
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.Diagnostico AS dg ON dg.DiagnosticoID=i.DiagnosticoID 
        INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=dg.OrdenID 
        LEFT JOIN deleted AS d ON d.ReparacionID=i.ReparacionID
 
        WHERE dbo.fnTieneRol(i.UsuarioTecnicoID,''TECNICO'')=0 
            OR i.FechaInicio<dg.Fecha 
            OR (d.ReparacionID IS NULL 
            AND (i.Estado<>''EN_PROCESO'' 
            OR o.EstadoCodigo<>''ESPERANDO_AUTORIZACION''))
 
            OR (d.ReparacionID IS NOT NULL 
            AND (d.Estado<>''EN_PROCESO'' 
            OR i.Estado<>''TERMINADA'' 
            OR o.EstadoCodigo<>''REPARACION'')))
        THROW 51111,N''Reparación no autorizada o ciclo inválido.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN deleted AS d ON d.ReparacionID=i.ReparacionID 
        WHERE i.DiagnosticoID<>d.DiagnosticoID 
            OR i.UsuarioTecnicoID<>d.UsuarioTecnicoID 
            OR i.FechaInicio<>d.FechaInicio 
            OR i.CostoManoObra<>d.CostoManoObra 
            OR i.DescripcionTrabajo<>d.DescripcionTrabajo)
        THROW 51112,N''No se pueden reescribir datos históricos de reparación.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.ReparacionRepuesto AS rr ON rr.ReparacionID=i.ReparacionID 
        LEFT JOIN dbo.MovimientoInventario AS m ON m.ReparacionID=rr.ReparacionID 
            AND m.LineaReparacion=rr.Linea 
        WHERE i.Estado=''TERMINADA'' 
            AND m.MovimientoID IS NULL)
        THROW 51113,N''Consumo sin movimiento de salida.'',1;
END;';

    -- trActividadValida: ReparacionActividad
    EXEC sys.sp_executesql N'-- Valida una tarea de reparación y conserva la tarea registrada.
CREATE OR ALTER TRIGGER dbo.trActividadValida
ON dbo.ReparacionActividad
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N''Historia inmutable: no se permite modificar o borrar ReparacionActividad.'', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.Reparacion AS r ON r.ReparacionID=i.ReparacionID 
        INNER JOIN dbo.Actividad AS a ON a.ActividadID=i.ActividadID 
        WHERE r.Estado<>''EN_PROCESO'' 
            OR a.Activo=0 
            OR i.Fecha<r.FechaInicio)
        THROW 51114,N''Actividad/fecha inválida para la reparación.'',1;
END;';

    -- trConsumoValido: ReparacionRepuesto
    EXEC sys.sp_executesql N'-- Valida el consumo de repuestos y conserva sus cantidades y precios históricos.
CREATE OR ALTER TRIGGER dbo.trConsumoValido
ON dbo.ReparacionRepuesto
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N''Historia inmutable: no se permite modificar o borrar ReparacionRepuesto.'', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.Reparacion AS r ON r.ReparacionID=i.ReparacionID 
        INNER JOIN dbo.Diagnostico AS d ON d.DiagnosticoID=r.DiagnosticoID 
        INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=d.OrdenID 
        INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=i.RepuestoID 
        INNER JOIN dbo.Bodega AS b ON b.BodegaID=i.BodegaID
 
        WHERE r.Estado<>''EN_PROCESO'' 
            OR o.EstadoCodigo<>''REPARACION'' 
            OR p.Activo=0 
            OR b.Activo=0)
        THROW 51115,N''Consumo requiere reparación, repuesto y bodega activos.'',1;
END;';

    -- trCompraCiclo: Compra
    EXEC sys.sp_executesql N'-- Valida registro, recepción y anulación; protege la compra contra borrado.
CREATE OR ALTER TRIGGER dbo.trCompraCiclo
ON dbo.Compra
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En DELETE hay filas anteriores y no hay filas nuevas.
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 51141, N''No se permite borrar físicamente Compra.'', 1;

    -- INSERT y UPDATE conservan las reglas originales del proceso.
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        LEFT JOIN deleted AS d ON d.CompraID=i.CompraID 
        WHERE d.CompraID IS NULL 
            AND (i.Estado<>''PENDIENTE'' 
            OR dbo.fnTieneRol(i.UsuarioRegistroID,''BODEGA'')=0))
        THROW 51116,N''Compra nueva debe estar pendiente y autorizada.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN deleted AS d ON d.CompraID=i.CompraID 
        WHERE d.Estado<>''PENDIENTE'' 
            OR i.Estado NOT IN (''RECIBIDA'',''ANULADA'') 
            OR i.ProveedorID<>d.ProveedorID 
            OR i.UsuarioRegistroID<>d.UsuarioRegistroID 
            OR i.NumeroCompra<>d.NumeroCompra 
            OR i.Fecha<>d.Fecha)
        THROW 51117,N''No se puede reabrir o reescribir una compra.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        WHERE i.Estado=''RECIBIDA'' 
            AND (NOT EXISTS(SELECT 1 
        FROM dbo.DetalleCompra 
        WHERE CompraID=i.CompraID) 
            OR EXISTS(SELECT 1 
        FROM dbo.DetalleCompra AS dc 
        LEFT JOIN dbo.MovimientoInventario AS m ON m.CompraID=dc.CompraID 
            AND m.LineaCompra=dc.Linea 
        WHERE dc.CompraID=i.CompraID 
            AND m.MovimientoID IS NULL)))
        THROW 51118,N''Compra recibida requiere todas sus entradas.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.MovimientoInventario AS m ON m.CompraID=i.CompraID 
        WHERE i.Estado=''ANULADA'')
        THROW 51119,N''No se puede anular una compra con entradas.'',1;
END;';

    -- trDetalleCompraValido: DetalleCompra
    EXEC sys.sp_executesql N'-- Valida proveedor, repuesto y bodega; conserva las líneas de compra.
CREATE OR ALTER TRIGGER dbo.trDetalleCompraValido
ON dbo.DetalleCompra
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N''Historia inmutable: no se permite modificar o borrar DetalleCompra.'', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.Compra AS c ON c.CompraID=i.CompraID 
        INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=i.RepuestoID 
        INNER JOIN dbo.Bodega AS b ON b.BodegaID=i.BodegaID 
        WHERE c.Estado<>''PENDIENTE'' 
            OR p.Activo=0 
            OR b.Activo=0 
            OR EXISTS(SELECT 1 
        FROM dbo.MovimientoInventario 
        WHERE CompraID=i.CompraID) 
            OR NOT EXISTS(SELECT 1 
        FROM dbo.ProveedorRepuesto AS pr 
        WHERE pr.ProveedorID=c.ProveedorID 
            AND pr.RepuestoID=i.RepuestoID))
        THROW 51120,N''Detalle fuera de catálogo, destino inactivo o compra ya recibida/en recepción.'',1;
END;';

    -- trMovimientoIntegridad: MovimientoInventario
    EXEC sys.sp_executesql N'-- Valida origen, fecha y stock; conserva los movimientos del kardex.
CREATE OR ALTER TRIGGER dbo.trMovimientoIntegridad
ON dbo.MovimientoInventario
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N''Historia inmutable: no se permite modificar o borrar MovimientoInventario.'', 1;

    -- Para INSERT, continúa la validación original.
DECLARE @Pares TABLE (BodegaID int NOT NULL,RepuestoID int NOT NULL,PRIMARY KEY(BodegaID,RepuestoID));
 INSERT @Pares SELECT vm.BodegaID,vm.RepuestoID 
        FROM inserted AS i 
        INNER JOIN dbo.vMovimientoInventario AS vm ON vm.MovimientoID=i.MovimientoID 
        GROUP BY vm.BodegaID,vm.RepuestoID;
 DECLARE @Lock int;
 SELECT @Lock=iv.RepuestoID 
        FROM dbo.Inventario AS iv WITH (UPDLOCK,HOLDLOCK) 
        INNER JOIN @Pares AS p ON p.BodegaID=iv.BodegaID 
            AND p.RepuestoID=iv.RepuestoID;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.Compra AS c ON c.CompraID=i.CompraID 
        WHERE c.Estado<>''PENDIENTE'' 
            OR i.Fecha<c.Fecha 
            OR dbo.fnTieneRol(i.UsuarioID,''BODEGA'')=0)
        THROW 51121,N''Entrada no autorizada o compra/fecha inválida.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.Reparacion AS r ON r.ReparacionID=i.ReparacionID 
        WHERE r.Estado<>''EN_PROCESO'' 
            OR i.Fecha<r.FechaInicio 
            OR dbo.fnTieneRol(i.UsuarioID,''TECNICO'')=0)
        THROW 51122,N''Salida no autorizada o reparación/fecha inválida.'',1;
 IF EXISTS (SELECT 1 
        FROM dbo.vInventario AS v 
        INNER JOIN @Pares AS p ON p.BodegaID=v.BodegaID 
            AND p.RepuestoID=v.RepuestoID 
        WHERE v.Existencia<0)
        THROW 51123,N''El movimiento produciría stock negativo.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.vMovimientoInventario AS vm ON vm.MovimientoID=i.MovimientoID
 
        CROSS APPLY (SELECT SUM(a.CantidadFirmada) AS Stock 
        FROM dbo.vMovimientoInventario AS a 
        WHERE a.BodegaID=vm.BodegaID 
            AND a.RepuestoID=vm.RepuestoID 
            AND a.MovimientoID<=i.MovimientoID) AS saldo
 
        WHERE i.ExistenciaResultante<>saldo.Stock)
        THROW 51124,N''Existencia resultante no corresponde al kardex.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.vMovimientoInventario AS vm ON vm.MovimientoID=i.MovimientoID 
        INNER JOIN dbo.vMovimientoInventario AS previo ON previo.BodegaID=vm.BodegaID 
            AND previo.RepuestoID=vm.RepuestoID 
            AND previo.MovimientoID<i.MovimientoID 
        WHERE previo.Fecha>i.Fecha)
        THROW 51125,N''No se permiten movimientos retroactivos respecto del kardex.'',1;
END;';

    -- trFacturaValida: Factura
    EXEC sys.sp_executesql N'-- Valida emisión y anulación; conserva los datos fiscales y protege contra borrado.
CREATE OR ALTER TRIGGER dbo.trFacturaValida
ON dbo.Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En DELETE hay filas anteriores y no hay filas nuevas.
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 51141, N''No se permite borrar físicamente Factura.'', 1;

    -- INSERT y UPDATE conservan las reglas originales del proceso.
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        LEFT JOIN deleted AS old ON old.FacturaID=i.FacturaID 
        INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=i.OrdenID 
        LEFT JOIN dbo.Diagnostico AS d ON d.OrdenID=o.OrdenID 
        LEFT JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID 
        WHERE old.FacturaID IS NULL 
            AND (i.Estado<>''EMITIDA'' 
            OR o.EstadoCodigo<>''LISTO'' 
            OR r.ReparacionID IS NULL 
            OR r.Estado<>''TERMINADA'' 
            OR i.Fecha<r.FechaFin 
            OR dbo.fnTieneRol(i.UsuarioEmisionID,''CAJA'')=0))
        THROW 51126,N''Factura requiere servicio terminado y usuario de caja.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN deleted AS d ON d.FacturaID=i.FacturaID 
        WHERE d.Estado<>''EMITIDA'' 
            OR i.Estado<>''ANULADA'' 
            OR i.OrdenID<>d.OrdenID 
            OR i.NumeroFactura<>d.NumeroFactura 
            OR i.Fecha<>d.Fecha 
            OR i.TasaImpuesto<>d.TasaImpuesto 
            OR i.NITFacturacion<>d.NITFacturacion 
            OR i.NombreFacturacion<>d.NombreFacturacion 
            OR i.UsuarioEmisionID<>d.UsuarioEmisionID 
            OR EXISTS(SELECT 1 
        FROM dbo.Pago 
        WHERE FacturaID=i.FacturaID) 
            OR EXISTS(SELECT 1 
        FROM dbo.Entrega 
        WHERE OrdenID=i.OrdenID))
        THROW 51127,N''Factura histórica inmutable; anulación sólo sin pagos/entrega.'',1;
END;';

    -- trFacturaDetalleValido: FacturaDetalle
    EXEC sys.sp_executesql N'-- Valida conceptos y precios de la factura; conserva sus líneas.
CREATE OR ALTER TRIGGER dbo.trFacturaDetalleValido
ON dbo.FacturaDetalle
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N''Historia inmutable: no se permite modificar o borrar FacturaDetalle.'', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.Factura AS f ON f.FacturaID=i.FacturaID 
        INNER JOIN dbo.Reparacion AS r ON r.ReparacionID=i.ReparacionID 
        INNER JOIN dbo.Diagnostico AS d ON d.DiagnosticoID=r.DiagnosticoID 
        LEFT JOIN dbo.ReparacionRepuesto AS rr ON rr.ReparacionID=i.ReparacionID 
            AND rr.Linea=i.LineaReparacion
 
        WHERE f.OrdenID<>d.OrdenID 
            OR f.Estado<>''EMITIDA'' 
            OR r.Estado<>''TERMINADA'' 
            OR EXISTS(SELECT 1 
        FROM dbo.Pago 
        WHERE FacturaID=i.FacturaID)
 
            OR (i.TipoConcepto=''MO'' 
            AND i.PrecioUnitario<>r.CostoManoObra)
 
            OR (i.TipoConcepto=''REP'' 
            AND (i.Cantidad<>rr.Cantidad 
            OR i.PrecioUnitario<>rr.PrecioUnitario 
            OR NOT EXISTS(SELECT 1 
        FROM dbo.MovimientoInventario 
        WHERE ReparacionID=i.ReparacionID 
            AND LineaReparacion=i.LineaReparacion))))
        THROW 51128,N''Línea de factura incompatible con su servicio histórico.'',1;
END;';

    -- trPagoSaldo: Pago
    EXEC sys.sp_executesql N'-- Valida usuario, fecha y saldo; conserva cada pago registrado.
CREATE OR ALTER TRIGGER dbo.trPagoSaldo
ON dbo.Pago
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N''Historia inmutable: no se permite modificar o borrar Pago.'', 1;

    -- Para INSERT, continúa la validación original.
DECLARE @Lock int;
 SELECT @Lock=f.FacturaID 
        FROM dbo.Factura AS f WITH (UPDLOCK,HOLDLOCK) 
        INNER JOIN inserted AS i ON i.FacturaID=f.FacturaID;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.Factura AS f ON f.FacturaID=i.FacturaID 
        WHERE f.Estado<>''EMITIDA'' 
            OR i.Fecha<f.Fecha 
            OR dbo.fnTieneRol(i.UsuarioRegistroID,''CAJA'')=0 
            OR NOT EXISTS(SELECT 1 
        FROM dbo.FacturaDetalle 
        WHERE FacturaID=f.FacturaID))
        THROW 51129,N''Pago no autorizado o factura/fecha inválida.'',1;
 IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.vFacturaSaldo AS f ON f.FacturaID=i.FacturaID 
        WHERE f.Saldo<0)
        THROW 51130,N''La suma de pagos excede el total de la factura.'',1;
END;';

    -- trEntregaValida: Entrega
    EXEC sys.sp_executesql N'-- Valida receptor, fecha y factura pagada; conserva la entrega.
CREATE OR ALTER TRIGGER dbo.trEntregaValida
ON dbo.Entrega
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N''Historia inmutable: no se permite modificar o borrar Entrega.'', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1 
        FROM inserted AS i 
        INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=i.OrdenID 
        LEFT JOIN dbo.vFacturaSaldo AS f ON f.OrdenID=i.OrdenID 
        WHERE o.EstadoCodigo<>''LISTO'' 
            OR f.FacturaID IS NULL 
            OR f.Estado<>''EMITIDA'' 
            OR f.Saldo<>0 
            OR i.Fecha<f.Fecha 
            OR dbo.fnTieneRol(i.UsuarioEntregaID,''RECEPCION'')=0 
            OR NULLIF(LTRIM(RTRIM(i.NombreRecibe)),N'''') IS NULL 
            OR EXISTS(SELECT 1 
        FROM dbo.Pago AS p 
        WHERE p.FacturaID=f.FacturaID 
            AND p.Fecha>i.Fecha))
        THROW 51131,N''Entrega requiere factura pagada, fecha y receptor válidos.'',1;
END;';

    -- trAuditoriaPrecio: Repuesto
    EXEC sys.sp_executesql N'-- Guarda automáticamente el precio y costo anterior y nuevo del catálogo.
CREATE OR ALTER TRIGGER dbo.trAuditoriaPrecio
ON dbo.Repuesto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
INSERT dbo.AuditoriaPrecioRepuesto (RepuestoID,CostoAnterior,CostoNuevo,PrecioAnterior,PrecioNuevo,LoginSQL,UsuarioAplicacionID)
 SELECT i.RepuestoID,d.CostoReferencia,i.CostoReferencia,d.PrecioVenta,i.PrecioVenta,ORIGINAL_LOGIN(),
 CASE WHEN EXISTS (SELECT 1 
        FROM dbo.Usuario 
        WHERE UsuarioID=TRY_CONVERT(int,SESSION_CONTEXT(N''UsuarioID''))) THEN TRY_CONVERT(int,SESSION_CONTEXT(N''UsuarioID'')) ELSE NULL END
 
        FROM inserted AS i 
        INNER JOIN deleted AS d ON d.RepuestoID=i.RepuestoID
 
        WHERE i.CostoReferencia<>d.CostoReferencia 
            OR i.PrecioVenta<>d.PrecioVenta;
END;';

    -- trHistorialEstadoOrdenInmutable: HistorialEstadoOrden
    EXEC sys.sp_executesql N'-- Protege los cambios de estado ya registrados.
CREATE OR ALTER TRIGGER dbo.trHistorialEstadoOrdenInmutable
ON dbo.HistorialEstadoOrden
INSTEAD OF UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
THROW 51140,N''Historia inmutable: no se permite UPDATE/DELETE en HistorialEstadoOrden.'',1;
END;';

    -- trAuditoriaPrecioRepuestoInmutable: AuditoriaPrecioRepuesto
    EXEC sys.sp_executesql N'-- Protege los registros de auditoría de precios.
CREATE OR ALTER TRIGGER dbo.trAuditoriaPrecioRepuestoInmutable
ON dbo.AuditoriaPrecioRepuesto
INSTEAD OF UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
THROW 51140,N''Historia inmutable: no se permite UPDATE/DELETE en AuditoriaPrecioRepuesto.'',1;
END;';
    COMMIT TRANSACTION;
    PRINT N'Actualización terminada: 16 triggers. Ejecute las pruebas de integridad.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
