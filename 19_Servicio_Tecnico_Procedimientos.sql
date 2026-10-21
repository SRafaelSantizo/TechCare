-- Continuación de Órdenes: diagnóstico, reparación, actividades y consumos.
-- Ejecutar completo en SSMS después del 16. No borra ni reinserta datos.
USE [TechCare];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.vOrdenAcceso', N'V') IS NULL
   OR OBJECT_ID(N'dbo.spAsignarTecnicoOrden', N'P') IS NULL
   OR OBJECT_ID(N'dbo.spConsumirRepuesto', N'P') IS NULL
    THROW 51790, N'Primero instalá TechCare y ejecutá 16_Ordenes_Procedimientos.sql.', 1;
GO

-- Los procedimientos de escritura llaman este control DENTRO de su transacción.
-- Primero se bloquea OrdenServicio, igual que al asignar/cancelar en el script 16.
-- Aunque ADMIN pueda consultar todo, el trabajo técnico pertenece al asignado.
CREATE OR ALTER PROCEDURE dbo.spValidarTecnicoAsignado
    @UsuarioActorID int, @OrdenID int
AS
BEGIN
    SET NOCOUNT ON;
    IF @OrdenID IS NULL OR @OrdenID <= 0
        THROW 51700, N'El ID de orden debe ser mayor que cero.', 1;
    IF dbo.fnTieneRol(@UsuarioActorID, 'TECNICO') = 0
        THROW 51704, N'Se requiere un técnico activo para realizar esta operación.', 1;
    DECLARE @Estado varchar(30);
    SELECT @Estado = EstadoCodigo FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
    WHERE OrdenID = @OrdenID;
    IF @Estado IS NULL OR dbo.fnPuedeConsultarOrden(@UsuarioActorID, @OrdenID) = 0
        THROW 51702, N'La orden no existe o no está disponible para tu usuario.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.vOrdenAcceso
                   WHERE OrdenID = @OrdenID AND UsuarioTecnicoID = @UsuarioActorID)
        THROW 51704, N'Solo el técnico asignado puede trabajar esta orden.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spIniciarDiagnosticoOrden
    @UsuarioActorID int, @OrdenID int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIInicioDiagnostico;
        EXEC dbo.spValidarTecnicoAsignado @UsuarioActorID, @OrdenID;
        IF NOT EXISTS (SELECT 1 FROM dbo.OrdenServicio WHERE OrdenID = @OrdenID AND EstadoCodigo = 'RECIBIDO')
            THROW 51703, N'El diagnóstico solo se inicia en una orden recibida.', 1;
        EXEC dbo.spCambiarEstadoOrden @OrdenID, 'DIAGNOSTICO', @UsuarioActorID, N'El técnico inició la revisión del equipo';
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APIInicioDiagnostico;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spRegistrarDiagnosticoOrden
    @UsuarioActorID int, @OrdenID int, @Descripcion nvarchar(max), @CostoEstimado decimal(19,4)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @DiagnosticoID int;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIDiagnostico;
        EXEC dbo.spValidarTecnicoAsignado @UsuarioActorID, @OrdenID;
        SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');
        IF @Descripcion IS NULL OR DATALENGTH(@Descripcion) > 4000
            THROW 51700, N'El diagnóstico es obligatorio y admite hasta 2000 caracteres.', 1;
        IF @CostoEstimado IS NULL OR @CostoEstimado < 0 OR @CostoEstimado > 9999999999.99
           OR ROUND(@CostoEstimado, 2) <> @CostoEstimado
            THROW 51700, N'Ingresá una mano de obra estimada válida, con hasta dos decimales.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.OrdenServicio WHERE OrdenID = @OrdenID AND EstadoCodigo IN ('RECIBIDO', 'DIAGNOSTICO'))
           OR EXISTS (SELECT 1 FROM dbo.Diagnostico WHERE OrdenID = @OrdenID)
            THROW 51703, N'La orden ya tiene diagnóstico o su estado cambió. Actualizá el expediente.', 1;
        EXEC dbo.spRegistrarDiagnostico @OrdenID, @UsuarioActorID, @Descripcion,
            @CostoEstimado, @DiagnosticoID OUTPUT;
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APIDiagnostico;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spIniciarReparacionOrden
    @UsuarioActorID int, @OrdenID int, @DescripcionTrabajo nvarchar(max),
    @CostoManoObra decimal(19,4), @Autorizacion nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @DiagnosticoID int, @ReparacionID int;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIInicioReparacion;
        EXEC dbo.spValidarTecnicoAsignado @UsuarioActorID, @OrdenID;
        SET @DescripcionTrabajo = NULLIF(LTRIM(RTRIM(@DescripcionTrabajo)), N'');
        SET @Autorizacion = NULLIF(LTRIM(RTRIM(@Autorizacion)), N'');
        IF @DescripcionTrabajo IS NULL OR DATALENGTH(@DescripcionTrabajo) > 4000
            THROW 51700, N'El trabajo autorizado es obligatorio y admite hasta 2000 caracteres.', 1;
        IF @Autorizacion IS NULL OR DATALENGTH(@Autorizacion) > 1000
            THROW 51700, N'Documentá la autorización del cliente, hasta 500 caracteres.', 1;
        IF @CostoManoObra IS NULL OR @CostoManoObra < 0 OR @CostoManoObra > 9999999999.99
           OR ROUND(@CostoManoObra, 2) <> @CostoManoObra
            THROW 51700, N'Ingresá una mano de obra válida, con hasta dos decimales.', 1;
        SELECT @DiagnosticoID = d.DiagnosticoID FROM dbo.Diagnostico d
        JOIN dbo.OrdenServicio o ON o.OrdenID = d.OrdenID
        WHERE d.OrdenID = @OrdenID AND o.EstadoCodigo = 'ESPERANDO_AUTORIZACION';
        IF @DiagnosticoID IS NULL OR EXISTS (SELECT 1 FROM dbo.Reparacion WHERE DiagnosticoID = @DiagnosticoID)
            THROW 51703, N'La reparación requiere diagnóstico y una orden esperando autorización.', 1;
        EXEC dbo.spIniciarReparacion @DiagnosticoID, @UsuarioActorID, @DescripcionTrabajo,
            @CostoManoObra, @ReparacionID OUTPUT, @Autorizacion;
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APIInicioReparacion;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spAgregarActividadOrden
    @UsuarioActorID int, @OrdenID int, @ActividadID int, @Observacion nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @ReparacionID int;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIActividad;
        EXEC dbo.spValidarTecnicoAsignado @UsuarioActorID, @OrdenID;
        SET @Observacion = NULLIF(LTRIM(RTRIM(@Observacion)), N'');
        IF DATALENGTH(@Observacion) > 1000
            THROW 51700, N'La observación admite hasta 500 caracteres.', 1;
        SELECT @ReparacionID = r.ReparacionID FROM dbo.Reparacion r WITH (UPDLOCK, HOLDLOCK)
        JOIN dbo.Diagnostico d ON d.DiagnosticoID = r.DiagnosticoID
        JOIN dbo.OrdenServicio o ON o.OrdenID = d.OrdenID
        WHERE d.OrdenID = @OrdenID AND o.EstadoCodigo = 'REPARACION' AND r.Estado = 'EN_PROCESO';
        IF @ReparacionID IS NULL THROW 51703, N'La reparación no está en proceso.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Actividad WITH (HOLDLOCK) WHERE ActividadID = @ActividadID AND Activo = 1)
            THROW 51701, N'Elegí una actividad activa del catálogo.', 1;
        IF EXISTS (SELECT 1 FROM dbo.ReparacionActividad WHERE ReparacionID = @ReparacionID AND ActividadID = @ActividadID)
            THROW 51703, N'Esta actividad ya está registrada en la reparación.', 1;
        EXEC dbo.spRegistrarActividad @ReparacionID, @ActividadID, @UsuarioActorID, @Observacion;
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APIActividad;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spUsarRepuestoOrden
    @UsuarioActorID int, @OrdenID int, @BodegaID int, @RepuestoID int, @Cantidad int,
    @PrecioUnitarioEsperado decimal(19,4)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @ReparacionID int, @Precio decimal(12,2), @Inventario int;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIRepuesto;
        EXEC dbo.spValidarTecnicoAsignado @UsuarioActorID, @OrdenID;
        IF @Cantidad IS NULL OR @Cantidad <= 0
            THROW 51700, N'La cantidad debe ser un entero mayor que cero.', 1;
        IF @PrecioUnitarioEsperado IS NULL OR @PrecioUnitarioEsperado < 0
           OR @PrecioUnitarioEsperado > 9999999999.99 OR ROUND(@PrecioUnitarioEsperado, 2) <> @PrecioUnitarioEsperado
            THROW 51700, N'El precio mostrado no es válido. Actualizá el catálogo.', 1;
        SELECT @ReparacionID = r.ReparacionID FROM dbo.Reparacion r WITH (UPDLOCK, HOLDLOCK)
        JOIN dbo.Diagnostico d ON d.DiagnosticoID = r.DiagnosticoID
        JOIN dbo.OrdenServicio o ON o.OrdenID = d.OrdenID
        WHERE d.OrdenID = @OrdenID AND o.EstadoCodigo = 'REPARACION' AND r.Estado = 'EN_PROCESO';
        IF @ReparacionID IS NULL THROW 51703, N'La reparación no está en proceso.', 1;
        -- Orden de bloqueo del procedimiento original: reparación, inventario, repuesto.
        SELECT @Inventario = RepuestoID FROM dbo.Inventario WITH (UPDLOCK, HOLDLOCK)
        WHERE BodegaID = @BodegaID AND RepuestoID = @RepuestoID;
        IF @Inventario IS NULL THROW 51701, N'El repuesto no está registrado en esa bodega.', 1;
        SELECT @Precio = PrecioVenta FROM dbo.Repuesto WITH (HOLDLOCK) WHERE RepuestoID = @RepuestoID AND Activo = 1;
        IF @Precio IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Bodega WITH (HOLDLOCK) WHERE BodegaID = @BodegaID AND Activo = 1)
            THROW 51701, N'El repuesto o la bodega están inactivos.', 1;
        IF @Precio <> @PrecioUnitarioEsperado
            THROW 51703, N'El precio cambió. Actualizá el catálogo y revisá el importe antes de confirmar.', 1;
        EXEC dbo.spConsumirRepuesto @ReparacionID, @BodegaID, @RepuestoID, @Cantidad, @UsuarioActorID;
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APIRepuesto;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spFinalizarReparacionOrden
    @UsuarioActorID int, @OrdenID int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @ReparacionID int;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APICierreReparacion;
        EXEC dbo.spValidarTecnicoAsignado @UsuarioActorID, @OrdenID;
        SELECT @ReparacionID = r.ReparacionID FROM dbo.Reparacion r WITH (UPDLOCK, HOLDLOCK)
        JOIN dbo.Diagnostico d ON d.DiagnosticoID = r.DiagnosticoID
        JOIN dbo.OrdenServicio o ON o.OrdenID = d.OrdenID
        WHERE d.OrdenID = @OrdenID AND o.EstadoCodigo = 'REPARACION' AND r.Estado = 'EN_PROCESO';
        IF @ReparacionID IS NULL THROW 51703, N'La reparación no está en proceso o ya fue finalizada.', 1;
        EXEC dbo.spCerrarReparacion @ReparacionID, @UsuarioActorID;
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APICierreReparacion;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spActividadesOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarActorOrden @UsuarioActorID;
    IF @OrdenID IS NULL OR @OrdenID <= 0 THROW 51700, N'El ID de orden debe ser mayor que cero.', 1;
    IF dbo.fnPuedeConsultarOrden(@UsuarioActorID, @OrdenID) = 0
        THROW 51702, N'La orden no existe o no está disponible para tu usuario.', 1;
    SELECT a.ActividadID, a.Nombre, ra.Fecha, ra.Observacion
    FROM dbo.ReparacionActividad ra JOIN dbo.Actividad a ON a.ActividadID = ra.ActividadID
    JOIN dbo.Reparacion r ON r.ReparacionID = ra.ReparacionID JOIN dbo.Diagnostico d ON d.DiagnosticoID = r.DiagnosticoID
    WHERE d.OrdenID = @OrdenID AND dbo.fnPuedeConsultarOrden(@UsuarioActorID, d.OrdenID) = 1
    ORDER BY ra.Fecha, a.ActividadID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spRepuestosOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarActorOrden @UsuarioActorID;
    IF @OrdenID IS NULL OR @OrdenID <= 0 THROW 51700, N'El ID de orden debe ser mayor que cero.', 1;
    IF dbo.fnPuedeConsultarOrden(@UsuarioActorID, @OrdenID) = 0
        THROW 51702, N'La orden no existe o no está disponible para tu usuario.', 1;
    SELECT rr.Linea, rr.RepuestoID, p.Codigo, p.Nombre, rr.BodegaID, b.Nombre AS Bodega,
           rr.Cantidad, rr.PrecioUnitario,
           CONVERT(decimal(22,2), CONVERT(decimal(22,2), rr.Cantidad) * rr.PrecioUnitario) AS Importe,
           m.MovimientoID, m.Fecha
    FROM dbo.ReparacionRepuesto rr JOIN dbo.Repuesto p ON p.RepuestoID = rr.RepuestoID
    JOIN dbo.Bodega b ON b.BodegaID = rr.BodegaID JOIN dbo.Reparacion r ON r.ReparacionID = rr.ReparacionID
    JOIN dbo.Diagnostico d ON d.DiagnosticoID = r.DiagnosticoID
    LEFT JOIN dbo.MovimientoInventario m ON m.ReparacionID = rr.ReparacionID AND m.LineaReparacion = rr.Linea
    WHERE d.OrdenID = @OrdenID AND dbo.fnPuedeConsultarOrden(@UsuarioActorID, d.OrdenID) = 1
    ORDER BY rr.Linea;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spCatalogoActividadesOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarActorOrden @UsuarioActorID;
    IF @OrdenID IS NULL OR @OrdenID <= 0 THROW 51700, N'El ID de orden debe ser mayor que cero.', 1;
    IF dbo.fnPuedeConsultarOrden(@UsuarioActorID, @OrdenID) = 0
        THROW 51702, N'La orden no existe o no está disponible para tu usuario.', 1;
    SELECT ActividadID, Nombre FROM dbo.Actividad WHERE Activo = 1 ORDER BY Nombre, ActividadID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spCatalogoRepuestosOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    -- Consulta acotada a una orden propia; no habilita el módulo general de Bodega.
    IF @OrdenID IS NULL OR @OrdenID <= 0 THROW 51700, N'El ID de orden debe ser mayor que cero.', 1;
    IF dbo.fnTieneRol(@UsuarioActorID, 'TECNICO') = 0
        THROW 51704, N'Se requiere un técnico activo para consultar repuestos disponibles.', 1;
    IF dbo.fnPuedeConsultarOrden(@UsuarioActorID, @OrdenID) = 0
        THROW 51702, N'La orden no existe o no está disponible para tu usuario.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID AND UsuarioTecnicoID = @UsuarioActorID)
        THROW 51704, N'Solo el técnico asignado puede consultar repuestos para esta orden.', 1;
    SELECT i.BodegaID, b.Nombre AS Bodega, i.RepuestoID, p.Codigo, p.Nombre, i.Existencia, p.PrecioVenta AS PrecioUnitario
    FROM dbo.vInventario i JOIN dbo.Bodega b ON b.BodegaID = i.BodegaID
    JOIN dbo.Repuesto p ON p.RepuestoID = i.RepuestoID
    WHERE b.Activo = 1 AND p.Activo = 1
      AND EXISTS (SELECT 1 FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID AND UsuarioTecnicoID = @UsuarioActorID)
    ORDER BY p.Nombre, b.Nombre, i.BodegaID, i.RepuestoID;
END;
GO

GRANT EXECUTE ON dbo.spIniciarDiagnosticoOrden TO techcare_app;
GRANT EXECUTE ON dbo.spRegistrarDiagnosticoOrden TO techcare_app;
GRANT EXECUTE ON dbo.spIniciarReparacionOrden TO techcare_app;
GRANT EXECUTE ON dbo.spAgregarActividadOrden TO techcare_app;
GRANT EXECUTE ON dbo.spUsarRepuestoOrden TO techcare_app;
GRANT EXECUTE ON dbo.spFinalizarReparacionOrden TO techcare_app;
GRANT EXECUTE ON dbo.spActividadesOrden TO techcare_app;
GRANT EXECUTE ON dbo.spRepuestosOrden TO techcare_app;
GRANT EXECUTE ON dbo.spCatalogoActividadesOrden TO techcare_app;
GRANT EXECUTE ON dbo.spCatalogoRepuestosOrden TO techcare_app;
GO
