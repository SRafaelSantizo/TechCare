-- Continuación del servicio técnico. Ejecutar completo después del 19.
-- Conserva las tablas, precios históricos y procedimientos del maestro.
USE [TechCare];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.spFinalizarReparacionOrden', N'P') IS NULL
   OR OBJECT_ID(N'dbo.spGenerarFactura', N'P') IS NULL
    THROW 51890, N'Ejecutá primero 19_Servicio_Tecnico_Procedimientos.sql.', 1;
GO
IF OBJECT_ID(N'dbo.SeqFacturaApi', N'SO') IS NULL
    EXEC(N'CREATE SEQUENCE dbo.SeqFacturaApi AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;');
-- La secuencia nunca se reinicia al volver a ejecutar este script.
IF OBJECT_ID(N'dbo.SolicitudPagoApi', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SolicitudPagoApi (
        SolicitudID uniqueidentifier NOT NULL CONSTRAINT PK_SolicitudPagoApi PRIMARY KEY,
        PagoID bigint NOT NULL CONSTRAINT UQ_SolicitudPagoApi_Pago UNIQUE,
        CONSTRAINT FK_SolicitudPagoApi_Pago FOREIGN KEY (PagoID) REFERENCES dbo.Pago(PagoID)
    );
END;
GO
-- SUM(decimal) amplía a precisión 38. Se acota antes de operar para conservar
-- los centavos al sumar impuesto y restar varios abonos; no se reescriben datos.
CREATE OR ALTER VIEW dbo.vFacturaSaldo AS
WITH lineas AS (
    SELECT FacturaID,
       CONVERT(decimal(18,2),SUM(CONVERT(decimal(18,2),Cantidad*PrecioUnitario))) AS Subtotal,
       CONVERT(decimal(18,2),SUM(CASE WHEN TipoConcepto='MO' THEN CONVERT(decimal(18,2),Cantidad*PrecioUnitario) ELSE 0 END)) AS ManoObra,
       CONVERT(decimal(18,2),SUM(CASE WHEN TipoConcepto='REP' THEN CONVERT(decimal(18,2),Cantidad*PrecioUnitario) ELSE 0 END)) AS Repuestos
    FROM dbo.FacturaDetalle GROUP BY FacturaID
), pagos AS (
    SELECT FacturaID,CONVERT(decimal(18,2),SUM(CONVERT(decimal(18,2),Monto))) AS Pagado FROM dbo.Pago GROUP BY FacturaID
), base AS (
    SELECT f.FacturaID,f.NumeroFactura,f.OrdenID,f.Fecha,f.Estado,f.TasaImpuesto,
       COALESCE(l.Subtotal,0) AS Subtotal,COALESCE(l.ManoObra,0) AS ManoObra,COALESCE(l.Repuestos,0) AS Repuestos,
       CONVERT(decimal(18,2),ROUND(COALESCE(l.Subtotal,0)*f.TasaImpuesto,2)) AS Impuesto,COALESCE(p.Pagado,0) AS Pagado
    FROM dbo.Factura f LEFT JOIN lineas l ON l.FacturaID=f.FacturaID LEFT JOIN pagos p ON p.FacturaID=f.FacturaID
)
SELECT FacturaID,NumeroFactura,OrdenID,Fecha,Estado,TasaImpuesto,Subtotal,ManoObra,Repuestos,Impuesto,
       CONVERT(decimal(18,2),Subtotal+Impuesto) AS Total,Pagado,
       CONVERT(decimal(18,2),Subtotal+Impuesto-Pagado) AS Saldo,
       CASE WHEN Estado='ANULADA' THEN 'ANULADA' WHEN Subtotal+Impuesto=Pagado THEN 'PAGADA'
            WHEN Pagado=0 THEN 'PENDIENTE' ELSE 'PARCIAL' END AS EstadoPago
FROM base;
GO
CREATE OR ALTER TRIGGER dbo.trSolicitudPagoApiInmutable ON dbo.SolicitudPagoApi
AFTER UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted) THROW 51803, N'El identificador de un pago registrado es histórico.', 1;
END;
GO
CREATE OR ALTER VIEW dbo.vDetallePreFacturaApi AS
SELECT d.OrdenID, CONVERT(bigint, 1) AS Linea, CONVERT(varchar(3), 'MO') AS TipoConcepto,
       CONVERT(nvarchar(200), N'Mano de obra del servicio') AS Concepto, 1 AS Cantidad,
       r.CostoManoObra AS PrecioUnitario, CONVERT(decimal(18,2), r.CostoManoObra) AS Importe
FROM dbo.Diagnostico d JOIN dbo.Reparacion r ON r.DiagnosticoID = d.DiagnosticoID
UNION ALL
SELECT d.OrdenID, ROW_NUMBER() OVER (PARTITION BY d.OrdenID ORDER BY rr.Linea) + 1, 'REP',
       p.Nombre, rr.Cantidad, rr.PrecioUnitario, CONVERT(decimal(18,2), rr.Cantidad * rr.PrecioUnitario)
FROM dbo.Diagnostico d JOIN dbo.Reparacion r ON r.DiagnosticoID = d.DiagnosticoID
JOIN dbo.ReparacionRepuesto rr ON rr.ReparacionID = r.ReparacionID
JOIN dbo.Repuesto p ON p.RepuestoID = rr.RepuestoID;
GO
CREATE OR ALTER VIEW dbo.vPreFacturaApi AS
SELECT o.OrdenID, o.NumeroOrden, o.EstadoCodigo, r.Estado AS EstadoReparacion,
       c.NIT AS NITFacturacion, c.Nombre AS NombreFacturacion, c.Direccion AS DireccionFacturacion,
       x.Subtotal,
       HASHBYTES('SHA2_256', CONCAT(CONVERT(nvarchar(max), o.OrdenID), N'|',
         DATALENGTH(c.NIT), N':', c.NIT, N'|', DATALENGTH(c.Nombre), N':', c.Nombre, N'|',
         COALESCE(DATALENGTH(c.Direccion), -1), N':', c.Direccion, N'|', x.Firma)) AS RevisionBase
FROM dbo.OrdenServicio o JOIN dbo.Equipo e ON e.EquipoID = o.EquipoID
JOIN dbo.Cliente c ON c.ClienteID = e.ClienteID
JOIN dbo.Diagnostico d ON d.OrdenID = o.OrdenID
JOIN dbo.Reparacion r ON r.DiagnosticoID = d.DiagnosticoID
CROSS APPLY (
    SELECT CONVERT(decimal(18,2), SUM(l.Importe)) AS Subtotal,
       STRING_AGG(CONVERT(nvarchar(max), CONCAT(l.Linea, N'|', l.TipoConcepto, N'|',
          DATALENGTH(l.Concepto), N':', l.Concepto, N'|', l.Cantidad, N'|', l.PrecioUnitario)), N';')
          WITHIN GROUP (ORDER BY l.Linea) AS Firma
    FROM dbo.vDetallePreFacturaApi l WHERE l.OrdenID = o.OrdenID
) x;
GO
CREATE OR ALTER VIEW dbo.vFacturaApi AS
SELECT f.FacturaID, f.NumeroFactura, f.OrdenID, o.NumeroOrden, f.Fecha, f.Estado,
       f.NITFacturacion, f.NombreFacturacion, f.DireccionFacturacion, f.TasaImpuesto,
       s.Subtotal, s.ManoObra, s.Repuestos, s.Impuesto, s.Total, s.Pagado, s.Saldo, s.EstadoPago,
       e.NumeroSerie, e.Descripcion AS EquipoDescripcion, ma.Nombre AS Marca, mo.Nombre AS Modelo,
       r.DescripcionTrabajo, em.Nombres + N' ' + em.Apellidos AS EmitidaPor,
       et.Nombres + N' ' + et.Apellidos AS Tecnico,
       er.Nombres + N' ' + er.Apellidos AS Recepcionista
FROM dbo.Factura f JOIN dbo.vFacturaSaldo s ON s.FacturaID = f.FacturaID
JOIN dbo.OrdenServicio o ON o.OrdenID = f.OrdenID
JOIN dbo.Equipo e ON e.EquipoID = o.EquipoID
JOIN dbo.ModeloEquipo mo ON mo.ModeloEquipoID = e.ModeloEquipoID
JOIN dbo.Marca ma ON ma.MarcaID = mo.MarcaID
JOIN dbo.Diagnostico d ON d.OrdenID = o.OrdenID
JOIN dbo.Reparacion r ON r.DiagnosticoID = d.DiagnosticoID
JOIN dbo.Usuario u ON u.UsuarioID = f.UsuarioEmisionID
JOIN dbo.Empleado em ON em.EmpleadoID = u.EmpleadoID
JOIN dbo.Usuario ut ON ut.UsuarioID = r.UsuarioTecnicoID JOIN dbo.Empleado et ON et.EmpleadoID = ut.EmpleadoID
JOIN dbo.Usuario ur ON ur.UsuarioID = o.UsuarioRecepcionID JOIN dbo.Empleado er ON er.EmpleadoID = ur.EmpleadoID;
GO
CREATE OR ALTER PROCEDURE dbo.spValidarConsultaCajaOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarActorOrden @UsuarioActorID;
    IF @OrdenID IS NULL OR @OrdenID <= 0 THROW 51800, N'El ID de orden no es válido.', 1;
    IF dbo.fnPuedeConsultarOrden(@UsuarioActorID, @OrdenID) = 0
        THROW 51802, N'La orden no existe o no está disponible para tu usuario.', 1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spConsultarFacturaOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarConsultaCajaOrden @UsuarioActorID, @OrdenID;
    SELECT * FROM dbo.vFacturaApi WHERE OrdenID = @OrdenID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spDetalleFacturaOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarConsultaCajaOrden @UsuarioActorID, @OrdenID;
    SELECT d.Linea, d.TipoConcepto, d.Concepto, d.Cantidad, d.PrecioUnitario,
           CONVERT(decimal(18,2), d.Cantidad * d.PrecioUnitario) AS Importe
    FROM dbo.Factura f JOIN dbo.FacturaDetalle d ON d.FacturaID = f.FacturaID
    WHERE f.OrdenID = @OrdenID ORDER BY d.Linea;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spPagosFacturaOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarConsultaCajaOrden @UsuarioActorID, @OrdenID;
    SELECT p.PagoID, p.Fecha, p.MetodoPagoID, m.Nombre AS MetodoPago, p.Monto, p.Referencia,
           e.Nombres + N' ' + e.Apellidos AS RegistradoPor
    FROM dbo.Factura f JOIN dbo.Pago p ON p.FacturaID = f.FacturaID
    JOIN dbo.MetodoPago m ON m.MetodoPagoID = p.MetodoPagoID
    JOIN dbo.Usuario u ON u.UsuarioID = p.UsuarioRegistroID JOIN dbo.Empleado e ON e.EmpleadoID = u.EmpleadoID
    WHERE f.OrdenID = @OrdenID ORDER BY p.Fecha, p.PagoID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spConsultarEntregaOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarConsultaCajaOrden @UsuarioActorID, @OrdenID;
    SELECT en.OrdenID, en.Fecha, en.NombreRecibe, en.DocumentoRecibe, en.Observaciones,
           e.Nombres + N' ' + e.Apellidos AS EntregadaPor
    FROM dbo.Entrega en JOIN dbo.Usuario u ON u.UsuarioID = en.UsuarioEntregaID
    JOIN dbo.Empleado e ON e.EmpleadoID = u.EmpleadoID WHERE en.OrdenID = @OrdenID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spPreviaFacturaOrden
    @UsuarioActorID int, @OrdenID int, @TasaImpuesto decimal(19,8) = 0.1200
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fnTieneRol(@UsuarioActorID, 'CAJA') = 0 THROW 51804, N'Se requiere un usuario activo de caja.', 1;
    EXEC dbo.spValidarConsultaCajaOrden @UsuarioActorID, @OrdenID;
    IF @TasaImpuesto IS NULL OR @TasaImpuesto < 0 OR @TasaImpuesto > 1 OR ROUND(@TasaImpuesto, 4) <> @TasaImpuesto
        THROW 51800, N'La tasa debe estar entre cero y uno, con hasta cuatro decimales.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.vPreFacturaApi WHERE OrdenID = @OrdenID AND EstadoCodigo = 'LISTO' AND EstadoReparacion = 'TERMINADA')
       OR EXISTS (SELECT 1 FROM dbo.Factura WHERE OrdenID = @OrdenID)
        THROW 51803, N'Solo se factura una orden lista, terminada y sin factura previa.', 1;
    SELECT v.OrdenID, v.NumeroOrden, v.NITFacturacion, v.NombreFacturacion, v.DireccionFacturacion,
       CONVERT(decimal(5,4), @TasaImpuesto) AS TasaImpuesto, v.Subtotal,
       CONVERT(decimal(18,2), ROUND(v.Subtotal * @TasaImpuesto, 2)) AS Impuesto,
       CONVERT(decimal(18,2), v.Subtotal + ROUND(v.Subtotal * @TasaImpuesto, 2)) AS Total,
       CONVERT(varchar(64), HASHBYTES('SHA2_256', CONCAT(CONVERT(varchar(64), v.RevisionBase, 2), '|',
          CONVERT(varchar(20), CONVERT(decimal(5,4), @TasaImpuesto)))), 2) AS Revision,
       l.Linea, l.TipoConcepto, l.Concepto, l.Cantidad, l.PrecioUnitario, l.Importe
    FROM dbo.vPreFacturaApi v JOIN dbo.vDetallePreFacturaApi l ON l.OrdenID = v.OrdenID
    WHERE v.OrdenID = @OrdenID ORDER BY l.Linea;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spEmitirFacturaOrden
    @UsuarioActorID int, @OrdenID int, @TasaImpuesto decimal(19,8), @Revision nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIEmitirFactura;
        IF dbo.fnTieneRol(@UsuarioActorID, 'CAJA') = 0 THROW 51804, N'Se requiere un usuario activo de caja.', 1;
        EXEC dbo.spValidarConsultaCajaOrden @UsuarioActorID, @OrdenID;
        IF @TasaImpuesto IS NULL OR @TasaImpuesto < 0 OR @TasaImpuesto > 1 OR ROUND(@TasaImpuesto, 4) <> @TasaImpuesto
           OR @Revision IS NULL OR DATALENGTH(@Revision) <> 128
            THROW 51800, N'Revisá la tasa y la confirmación de la factura.', 1;
        DECLARE @Dummy int, @Actual varchar(64), @FacturaID int, @Numero varchar(30), @Secuencia bigint;
        SELECT @Dummy = OrdenID FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK) WHERE OrdenID = @OrdenID AND EstadoCodigo = 'LISTO';
        IF @Dummy IS NULL OR EXISTS (SELECT 1 FROM dbo.Factura WITH (UPDLOCK, HOLDLOCK) WHERE OrdenID = @OrdenID)
            THROW 51803, N'La orden cambió o ya tiene factura. Actualizá el expediente.', 1;
        -- HOLDLOCK mantiene estables cliente, conceptos e importes hasta emitir.
        SELECT @Actual = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONCAT(CONVERT(varchar(64), RevisionBase, 2), '|',
            CONVERT(varchar(20), CONVERT(decimal(5,4), @TasaImpuesto)))), 2)
        FROM dbo.vPreFacturaApi WITH (HOLDLOCK) WHERE OrdenID = @OrdenID AND EstadoReparacion = 'TERMINADA';
        IF @Actual IS NULL OR @Actual COLLATE Latin1_General_100_BIN2 <> @Revision COLLATE Latin1_General_100_BIN2
            THROW 51803, N'Los datos fiscales o conceptos cambiaron. Volvé a revisar la factura.', 1;
        SET @Numero = NULL;
        WHILE @Numero IS NULL
        BEGIN
            SET @Secuencia = NEXT VALUE FOR dbo.SeqFacturaApi;
            SET @Numero = 'TCF-' + CONVERT(varchar(20), @Secuencia);
            IF EXISTS (SELECT 1 FROM dbo.Factura WHERE NumeroFactura = @Numero) SET @Numero = NULL;
        END;
        EXEC dbo.spGenerarFactura @OrdenID, @Numero, @UsuarioActorID, @FacturaID OUTPUT, @TasaImpuesto;
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vFacturaApi WHERE FacturaID = @FacturaID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APIEmitirFactura;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spAbonarFacturaOrden
    @UsuarioActorID int, @OrdenID int, @SolicitudID uniqueidentifier, @MetodoPagoID int,
    @Monto decimal(19,4), @SaldoEsperado decimal(22,4), @Referencia nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIAbonarFactura;
        IF dbo.fnTieneRol(@UsuarioActorID, 'CAJA') = 0 THROW 51804, N'Se requiere un usuario activo de caja.', 1;
        EXEC dbo.spValidarConsultaCajaOrden @UsuarioActorID, @OrdenID;
        SET @Referencia = NULLIF(LTRIM(RTRIM(@Referencia)), N'');
        IF @SolicitudID IS NULL OR @Monto IS NULL OR @Monto <= 0 OR @Monto > 9999999999.99 OR ROUND(@Monto, 2) <> @Monto
           OR @SaldoEsperado IS NULL OR @SaldoEsperado < 0 OR ROUND(@SaldoEsperado, 2) <> @SaldoEsperado
           OR DATALENGTH(@Referencia) > 200
            THROW 51800, N'Revisá el identificador, monto, saldo y referencia del pago.', 1;
        IF @MetodoPagoID IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.MetodoPago WHERE MetodoPagoID = @MetodoPagoID)
            THROW 51800, N'El medio de pago no existe.', 1;
        DECLARE @Dummy int, @FacturaID int, @Saldo decimal(18,2), @PagoID bigint;
        SELECT @Dummy = OrdenID FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK) WHERE OrdenID = @OrdenID;
        SELECT @FacturaID = FacturaID FROM dbo.Factura WITH (UPDLOCK, HOLDLOCK) WHERE OrdenID = @OrdenID;
        IF @FacturaID IS NULL THROW 51803, N'Primero emití la factura de la orden.', 1;
        SELECT @PagoID = PagoID FROM dbo.SolicitudPagoApi WITH (UPDLOCK, HOLDLOCK) WHERE SolicitudID = @SolicitudID;
        IF @PagoID IS NOT NULL
        BEGIN
            -- El mismo intento devuelve su factura, incluso si ya fue entregada.
            IF NOT EXISTS (SELECT 1 FROM dbo.Pago WHERE PagoID = @PagoID AND FacturaID = @FacturaID
                AND UsuarioRegistroID = @UsuarioActorID AND MetodoPagoID = @MetodoPagoID AND Monto = @Monto
                AND ((Referencia IS NULL AND @Referencia IS NULL) OR
                    (DATALENGTH(Referencia) = DATALENGTH(@Referencia)
                     AND Referencia COLLATE Latin1_General_100_BIN2 = @Referencia COLLATE Latin1_General_100_BIN2)))
                THROW 51803, N'El identificador ya corresponde a otro pago. Revisá los abonos registrados.', 1;
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Factura WHERE FacturaID = @FacturaID AND Estado = 'EMITIDA')
                THROW 51803, N'La factura está anulada.', 1;
            SET @Saldo = dbo.fnSaldoFactura(@FacturaID);
            IF @Saldo <> @SaldoEsperado THROW 51803, N'El saldo cambió. Actualizá los pagos y confirmá nuevamente.', 1;
            IF @Monto > @Saldo THROW 51803, N'El pago excede el saldo pendiente.', 1;
            EXEC dbo.spRegistrarPago @FacturaID, @MetodoPagoID, @Monto, @UsuarioActorID, @Referencia;
            SELECT TOP (1) @PagoID = PagoID FROM dbo.Pago WHERE FacturaID = @FacturaID ORDER BY PagoID DESC;
            INSERT dbo.SolicitudPagoApi(SolicitudID, PagoID) VALUES (@SolicitudID, @PagoID);
        END;
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vFacturaApi WHERE FacturaID = @FacturaID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APIAbonarFactura;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spRegistrarEntregaOrden
    @UsuarioActorID int, @OrdenID int, @NombreRecibe nvarchar(max),
    @DocumentoRecibe nvarchar(max) = NULL, @Observaciones nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIEntregaOrden;
        IF dbo.fnTieneRol(@UsuarioActorID, 'RECEPCION') = 0 THROW 51804, N'Se requiere un usuario activo de recepción.', 1;
        EXEC dbo.spValidarConsultaCajaOrden @UsuarioActorID, @OrdenID;
        SET @NombreRecibe = NULLIF(LTRIM(RTRIM(@NombreRecibe)), N'');
        SET @DocumentoRecibe = NULLIF(LTRIM(RTRIM(@DocumentoRecibe)), N'');
        SET @Observaciones = NULLIF(LTRIM(RTRIM(@Observaciones)), N'');
        IF @NombreRecibe IS NULL OR DATALENGTH(@NombreRecibe) > 300 OR DATALENGTH(@DocumentoRecibe) > 60
           OR DATALENGTH(@Observaciones) > 2000
           OR (@DocumentoRecibe IS NOT NULL AND @DocumentoRecibe COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9A-Za-z -]%')
            THROW 51800, N'Ingresá receptor (150), documento alfanumérico (30) y observaciones (1000) válidos.', 1;
        -- El maestro bloquea primero orden y después factura y exige saldo cero.
        EXEC dbo.spEntregarOrden @OrdenID, @UsuarioActorID, @NombreRecibe, @DocumentoRecibe, @Observaciones;
        IF @Propia = 1 COMMIT TRANSACTION;
        EXEC dbo.spConsultarEntregaOrden @UsuarioActorID, @OrdenID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APIEntregaOrden;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spMetodosPagoCaja @UsuarioActorID int AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fnTieneRol(@UsuarioActorID, 'CAJA') = 0 THROW 51804, N'Se requiere un usuario activo de caja.', 1;
    SELECT MetodoPagoID, Nombre FROM dbo.MetodoPago ORDER BY MetodoPagoID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spListarCaja
    @UsuarioActorID int, @Buscar nvarchar(max) = NULL, @EstadoPago nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fnTieneRol(@UsuarioActorID, 'CAJA') = 0 THROW 51804, N'Se requiere un usuario activo de caja.', 1;
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
    SET @EstadoPago = NULLIF(LTRIM(RTRIM(@EstadoPago)), N'');
    IF DATALENGTH(@Buscar) > 300 OR (@EstadoPago IS NOT NULL
       AND @EstadoPago NOT IN ('SIN_FACTURA','PENDIENTE','PARCIAL','PAGADA','ANULADA'))
        THROW 51800, N'Los filtros de caja no son válidos.', 1;
    SELECT o.OrdenID, o.NumeroOrden, o.Cliente, o.NumeroSerie, o.EstadoCodigo,
           f.FacturaID, f.NumeroFactura, f.Fecha, f.Total, f.Pagado, f.Saldo,
           COALESCE(f.EstadoPago, 'SIN_FACTURA') AS EstadoPago
    FROM dbo.vOrdenAcceso o LEFT JOIN dbo.vFacturaSaldo f ON f.OrdenID = o.OrdenID
    WHERE (o.EstadoCodigo = 'LISTO' OR f.FacturaID IS NOT NULL)
      AND (@EstadoPago IS NULL OR COALESCE(f.EstadoPago, 'SIN_FACTURA') = @EstadoPago)
      AND (@Buscar IS NULL OR CHARINDEX(@Buscar, o.NumeroOrden) > 0 OR CHARINDEX(@Buscar, o.Cliente) > 0
           OR CHARINDEX(@Buscar, o.NumeroSerie) > 0 OR CHARINDEX(@Buscar, f.NumeroFactura) > 0)
    ORDER BY CASE WHEN o.EstadoCodigo = 'LISTO' THEN 0 ELSE 1 END, o.OrdenID DESC;
END;
GO
IF DATABASE_PRINCIPAL_ID(N'techcare_app') IS NOT NULL
BEGIN
    DENY INSERT, UPDATE, DELETE ON dbo.SolicitudPagoApi TO techcare_app;
    GRANT EXECUTE ON SCHEMA::dbo TO techcare_app;
END;
GO
