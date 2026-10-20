-- Actualización para una TechCare existente. Ejecutar completo en SSMS.
-- Conserva las tablas y los registros; CREATE OR ALTER permite repetir el script.
USE [TechCare];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Equipos: las consultas y escrituras se resuelven en SQL Server.
CREATE OR ALTER PROCEDURE dbo.spListarEquipos
    @ClienteID int = NULL, @Serie nvarchar(max) = NULL, @Activo bit = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @ClienteID IS NOT NULL AND @ClienteID <= 0
        THROW 51300, N'El cliente del filtro debe ser mayor que cero.', 1;
    SET @Serie=NULLIF(LTRIM(RTRIM(@Serie)), N'');
    IF DATALENGTH(@Serie)>160
        THROW 51300, N'El filtro de serie admite hasta 80 caracteres.', 1;
    SELECT e.EquipoID, e.ClienteID, c.Nombre AS Cliente, c.Activo AS ClienteActivo,
           e.ModeloEquipoID, mo.Nombre AS Modelo, ma.MarcaID, ma.Nombre AS Marca,
           t.TipoEquipoID, t.Nombre AS TipoEquipo, e.NumeroSerie, e.Descripcion, e.Activo,
           CONVERT(bit, CASE WHEN EXISTS (SELECT 1 FROM dbo.OrdenServicio o WHERE o.EquipoID=e.EquipoID)
                            THEN 1 ELSE 0 END) AS TieneOrdenes
    FROM dbo.Equipo e
    INNER JOIN dbo.Cliente c ON c.ClienteID=e.ClienteID
    INNER JOIN dbo.ModeloEquipo mo ON mo.ModeloEquipoID=e.ModeloEquipoID
    INNER JOIN dbo.Marca ma ON ma.MarcaID=mo.MarcaID
    INNER JOIN dbo.TipoEquipo t ON t.TipoEquipoID=mo.TipoEquipoID
    WHERE (@ClienteID IS NULL OR e.ClienteID=@ClienteID)
      AND (@Serie IS NULL OR CHARINDEX(@Serie, e.NumeroSerie)>0)
      AND (@Activo IS NULL OR e.Activo=@Activo)
    ORDER BY e.EquipoID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spConsultarEquipo
    @EquipoID int
AS
BEGIN
    SET NOCOUNT ON;
    IF @EquipoID IS NULL OR @EquipoID<=0
        THROW 51300, N'El ID debe ser mayor que cero.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Equipo WHERE EquipoID=@EquipoID)
        THROW 51302, N'El equipo no existe.', 1;
    SELECT e.EquipoID, e.ClienteID, c.Nombre AS Cliente, c.Activo AS ClienteActivo,
           e.ModeloEquipoID, mo.Nombre AS Modelo, ma.MarcaID, ma.Nombre AS Marca,
           t.TipoEquipoID, t.Nombre AS TipoEquipo, e.NumeroSerie, e.Descripcion, e.Activo,
           CONVERT(bit, CASE WHEN EXISTS (SELECT 1 FROM dbo.OrdenServicio o WHERE o.EquipoID=e.EquipoID)
                            THEN 1 ELSE 0 END) AS TieneOrdenes
    FROM dbo.Equipo e
    INNER JOIN dbo.Cliente c ON c.ClienteID=e.ClienteID
    INNER JOIN dbo.ModeloEquipo mo ON mo.ModeloEquipoID=e.ModeloEquipoID
    INNER JOIN dbo.Marca ma ON ma.MarcaID=mo.MarcaID
    INNER JOIN dbo.TipoEquipo t ON t.TipoEquipoID=mo.TipoEquipoID
    WHERE e.EquipoID=@EquipoID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spHistorialEquipo
    @EquipoID int
AS
BEGIN
    SET NOCOUNT ON;
    IF @EquipoID IS NULL OR @EquipoID<=0
        THROW 51300, N'El ID debe ser mayor que cero.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Equipo WHERE EquipoID=@EquipoID)
        THROW 51302, N'El equipo no existe.', 1;
    -- La vista conserva equipos sin órdenes; el historial devuelve [] para ellos.
    SELECT EquipoID, NumeroSerie, ClienteID, Cliente, OrdenID, NumeroOrden, FechaIngreso, EstadoCodigo,
           FechaDiagnostico, Diagnostico, ReparacionID, FechaInicio, FechaFin, DescripcionTrabajo,
           FacturaID, Total, Saldo, FechaEntrega
    FROM dbo.vHistorialEquipo
    WHERE EquipoID=@EquipoID AND OrdenID IS NOT NULL
    ORDER BY FechaIngreso DESC, OrdenID DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spRegistrarEquipo
    @ClienteID int, @ModeloEquipoID int, @NumeroSerie nvarchar(max),
    @Descripcion nvarchar(max), @Activo bit
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
    DECLARE @Resultado TABLE (
        EquipoID int, ClienteID int, ModeloEquipoID int, NumeroSerie varchar(80),
        Descripcion nvarchar(500), Activo bit
    );
    BEGIN TRY
        IF @Propia=1 BEGIN TRANSACTION;
        ELSE SAVE TRANSACTION spRegistrarEquipo;
        SET @NumeroSerie=NULLIF(LTRIM(RTRIM(@NumeroSerie)), N'');
        SET @Descripcion=NULLIF(LTRIM(RTRIM(@Descripcion)), N'');
        -- Parámetros amplios para rechazar textos largos antes de convertirlos a las columnas.
        IF @NumeroSerie IS NULL OR DATALENGTH(CONVERT(varchar(max), @NumeroSerie))>80
            THROW 51300, N'La serie es obligatoria y admite hasta 80 caracteres.', 1;
        IF @Descripcion IS NULL OR DATALENGTH(@Descripcion)>1000
            THROW 51300, N'La descripción es obligatoria y admite hasta 500 caracteres.', 1;
        IF @Activo IS NULL
            THROW 51300, N'Activo es obligatorio.', 1;
        IF @ClienteID IS NULL OR NOT EXISTS (
            SELECT 1 FROM dbo.Cliente WITH (HOLDLOCK) WHERE ClienteID=@ClienteID)
            THROW 51301, N'El cliente no existe.', 1;
        IF @Activo=1 AND EXISTS (
            SELECT 1 FROM dbo.Cliente WHERE ClienteID=@ClienteID AND Activo=0)
            THROW 51301, N'Un equipo activo requiere un cliente activo.', 1;
        IF @ModeloEquipoID IS NULL OR NOT EXISTS (
            SELECT 1 FROM dbo.ModeloEquipo WITH (HOLDLOCK) WHERE ModeloEquipoID=@ModeloEquipoID)
            THROW 51301, N'El modelo de equipo no existe.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Equipo WHERE NumeroSerie=@NumeroSerie)
            THROW 51303, N'La serie ya está registrada en otro equipo.', 1;
        INSERT dbo.Equipo (ClienteID, ModeloEquipoID, NumeroSerie, Descripcion, Activo)
        OUTPUT inserted.EquipoID, inserted.ClienteID, inserted.ModeloEquipoID,
               inserted.NumeroSerie, inserted.Descripcion, inserted.Activo INTO @Resultado
        VALUES (@ClienteID, @ModeloEquipoID, @NumeroSerie, @Descripcion, @Activo);
        IF @Propia=1 COMMIT TRANSACTION;
        -- La respuesta conserva los valores de esta escritura.
    SELECT e.EquipoID, e.ClienteID, c.Nombre AS Cliente, c.Activo AS ClienteActivo,
           e.ModeloEquipoID, mo.Nombre AS Modelo, ma.MarcaID, ma.Nombre AS Marca,
           t.TipoEquipoID, t.Nombre AS TipoEquipo, e.NumeroSerie, e.Descripcion, e.Activo,
           CONVERT(bit, CASE WHEN EXISTS (SELECT 1 FROM dbo.OrdenServicio o WHERE o.EquipoID=e.EquipoID)
                            THEN 1 ELSE 0 END) AS TieneOrdenes
    FROM @Resultado e
    INNER JOIN dbo.Cliente c ON c.ClienteID=e.ClienteID
    INNER JOIN dbo.ModeloEquipo mo ON mo.ModeloEquipoID=e.ModeloEquipoID
    INNER JOIN dbo.Marca ma ON ma.MarcaID=mo.MarcaID
    INNER JOIN dbo.TipoEquipo t ON t.TipoEquipoID=mo.TipoEquipoID;
    END TRY
    BEGIN CATCH
        IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spRegistrarEquipo;
        IF ERROR_NUMBER() IN (2601,2627)
            THROW 51303, N'La serie ya está registrada en otro equipo.', 1;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spActualizarEquipo
    @EquipoID int,
    @ClienteID int, @ModeloEquipoID int, @NumeroSerie nvarchar(max),
    @Descripcion nvarchar(max), @Activo bit
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
    DECLARE @Resultado TABLE (
        EquipoID int, ClienteID int, ModeloEquipoID int, NumeroSerie varchar(80),
        Descripcion nvarchar(500), Activo bit
    );
    BEGIN TRY
        IF @Propia=1 BEGIN TRANSACTION;
        ELSE SAVE TRANSACTION spActualizarEquipo;
        IF @EquipoID IS NULL OR @EquipoID<=0
            THROW 51300, N'El ID debe ser mayor que cero.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo WITH (UPDLOCK, HOLDLOCK) WHERE EquipoID=@EquipoID)
            THROW 51302, N'El equipo no existe.', 1;
        SET @NumeroSerie=NULLIF(LTRIM(RTRIM(@NumeroSerie)), N'');
        SET @Descripcion=NULLIF(LTRIM(RTRIM(@Descripcion)), N'');
        -- Parámetros amplios para rechazar textos largos antes de convertirlos a las columnas.
        IF @NumeroSerie IS NULL OR DATALENGTH(CONVERT(varchar(max), @NumeroSerie))>80
            THROW 51300, N'La serie es obligatoria y admite hasta 80 caracteres.', 1;
        IF @Descripcion IS NULL OR DATALENGTH(@Descripcion)>1000
            THROW 51300, N'La descripción es obligatoria y admite hasta 500 caracteres.', 1;
        IF @Activo IS NULL
            THROW 51300, N'Activo es obligatorio.', 1;
        IF @ClienteID IS NULL OR NOT EXISTS (
            SELECT 1 FROM dbo.Cliente WITH (HOLDLOCK) WHERE ClienteID=@ClienteID)
            THROW 51301, N'El cliente no existe.', 1;
        IF @Activo=1 AND EXISTS (
            SELECT 1 FROM dbo.Cliente WHERE ClienteID=@ClienteID AND Activo=0)
            THROW 51301, N'Un equipo activo requiere un cliente activo.', 1;
        IF @ModeloEquipoID IS NULL OR NOT EXISTS (
            SELECT 1 FROM dbo.ModeloEquipo WITH (HOLDLOCK) WHERE ModeloEquipoID=@ModeloEquipoID)
            THROW 51301, N'El modelo de equipo no existe.', 1;
        IF EXISTS (SELECT 1 FROM dbo.OrdenServicio WITH (HOLDLOCK) WHERE EquipoID=@EquipoID)
           AND EXISTS (SELECT 1 FROM dbo.Equipo WHERE EquipoID=@EquipoID AND
               (ClienteID<>@ClienteID OR ModeloEquipoID<>@ModeloEquipoID OR NumeroSerie<>@NumeroSerie))
            THROW 51304, N'Equipo con historial: propietario, serie y modelo no se cambian.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Equipo WHERE NumeroSerie=@NumeroSerie AND EquipoID<>@EquipoID)
            THROW 51303, N'La serie ya está registrada en otro equipo.', 1;
        UPDATE dbo.Equipo
        SET ClienteID=@ClienteID, ModeloEquipoID=@ModeloEquipoID, NumeroSerie=@NumeroSerie,
            Descripcion=@Descripcion, Activo=@Activo
        OUTPUT inserted.EquipoID, inserted.ClienteID, inserted.ModeloEquipoID,
               inserted.NumeroSerie, inserted.Descripcion, inserted.Activo INTO @Resultado
        WHERE EquipoID=@EquipoID;
        IF @Propia=1 COMMIT TRANSACTION;
        -- La respuesta conserva los valores de esta escritura.
    SELECT e.EquipoID, e.ClienteID, c.Nombre AS Cliente, c.Activo AS ClienteActivo,
           e.ModeloEquipoID, mo.Nombre AS Modelo, ma.MarcaID, ma.Nombre AS Marca,
           t.TipoEquipoID, t.Nombre AS TipoEquipo, e.NumeroSerie, e.Descripcion, e.Activo,
           CONVERT(bit, CASE WHEN EXISTS (SELECT 1 FROM dbo.OrdenServicio o WHERE o.EquipoID=e.EquipoID)
                            THEN 1 ELSE 0 END) AS TieneOrdenes
    FROM @Resultado e
    INNER JOIN dbo.Cliente c ON c.ClienteID=e.ClienteID
    INNER JOIN dbo.ModeloEquipo mo ON mo.ModeloEquipoID=e.ModeloEquipoID
    INNER JOIN dbo.Marca ma ON ma.MarcaID=mo.MarcaID
    INNER JOIN dbo.TipoEquipo t ON t.TipoEquipoID=mo.TipoEquipoID;
    END TRY
    BEGIN CATCH
        IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spActualizarEquipo;
        IF ERROR_NUMBER() IN (2601,2627)
            THROW 51303, N'La serie ya está registrada en otro equipo.', 1;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spListarTiposEquipo
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TipoEquipoID, Nombre FROM dbo.TipoEquipo ORDER BY Nombre, TipoEquipoID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spListarMarcas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MarcaID, Nombre FROM dbo.Marca ORDER BY Nombre, MarcaID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spListarModelosEquipo
    @MarcaID int = NULL, @TipoEquipoID int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF (@MarcaID IS NOT NULL AND @MarcaID<=0) OR (@TipoEquipoID IS NOT NULL AND @TipoEquipoID<=0)
        THROW 51300, N'Los filtros de marca y tipo deben ser mayores que cero.', 1;
    SELECT mo.ModeloEquipoID, mo.Nombre, mo.MarcaID, ma.Nombre AS Marca,
           mo.TipoEquipoID, t.Nombre AS TipoEquipo
    FROM dbo.ModeloEquipo mo
    INNER JOIN dbo.Marca ma ON ma.MarcaID=mo.MarcaID
    INNER JOIN dbo.TipoEquipo t ON t.TipoEquipoID=mo.TipoEquipoID
    WHERE (@MarcaID IS NULL OR mo.MarcaID=@MarcaID)
      AND (@TipoEquipoID IS NULL OR mo.TipoEquipoID=@TipoEquipoID)
    ORDER BY ma.Nombre, mo.Nombre, mo.ModeloEquipoID;
END;
GO

-- Equipos se mantiene exclusivamente mediante sus procedimientos.
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Equipo TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spListarEquipos TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spConsultarEquipo TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spHistorialEquipo TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spRegistrarEquipo TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spActualizarEquipo TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spListarTiposEquipo TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spListarMarcas TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spListarModelosEquipo TO techcare_app;
GO
