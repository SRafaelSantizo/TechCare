-- Actualización de Órdenes para una base TechCare existente. No borra datos.
-- Ejecutar completo una vez en SSMS. Puede repetirse sin reiniciar la numeración.
USE [TechCare];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.OrdenServicio', N'U') IS NULL
   OR OBJECT_ID(N'dbo.spCrearOrden', N'P') IS NULL
   OR DATABASE_PRINCIPAL_ID(N'techcare_app') IS NULL
    THROW 51690, N'Primero instalá la base TechCare y sus procedimientos originales.', 1;
GO

IF OBJECT_ID(N'dbo.SecuenciaOrden', N'SO') IS NULL
    EXEC(N'CREATE SEQUENCE dbo.SecuenciaOrden AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;');
GO

-- Cada asignación es un evento. La última determina el responsable antes del diagnóstico.
IF OBJECT_ID(N'dbo.AsignacionOrden', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AsignacionOrden (
        AsignacionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AsignacionOrden PRIMARY KEY,
        OrdenID int NOT NULL CONSTRAINT FK_AsignacionOrden_Orden REFERENCES dbo.OrdenServicio(OrdenID),
        UsuarioTecnicoID int NOT NULL CONSTRAINT FK_AsignacionOrden_Tecnico REFERENCES dbo.Usuario(UsuarioID),
        UsuarioAsignaID int NOT NULL CONSTRAINT FK_AsignacionOrden_Actor REFERENCES dbo.Usuario(UsuarioID),
        Fecha datetime2(0) NOT NULL CONSTRAINT DF_AsignacionOrden_Fecha DEFAULT SYSUTCDATETIME(),
        Observacion nvarchar(500) NULL
    );
    CREATE INDEX IX_AsignacionOrden_Ultima ON dbo.AsignacionOrden(OrdenID, AsignacionID DESC)
        INCLUDE(UsuarioTecnicoID);
END;
GO

CREATE OR ALTER TRIGGER dbo.trAsignacionOrdenInmutable ON dbo.AsignacionOrden
AFTER UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51603, N'El historial de asignaciones no se modifica ni se elimina.', 1;
END;
GO

-- También presenta órdenes anteriores a esta actualización, usando su técnico histórico.
CREATE OR ALTER VIEW dbo.vOrdenAcceso AS
SELECT o.OrdenID, o.NumeroOrden, o.EquipoID, e.NumeroSerie, e.Descripcion AS EquipoDescripcion,
       mo.Nombre AS Modelo, ma.Nombre AS Marca, c.ClienteID, c.Nombre AS Cliente, c.NIT,
       o.UsuarioRecepcionID, er.Nombres + N' ' + er.Apellidos AS Recepcionista,
       o.FechaIngreso, o.ProblemaReportado, o.PrioridadCodigo, p.Nombre AS Prioridad,
       o.EstadoCodigo, es.Nombre AS Estado, es.EsFinal, o.FechaEstimada, o.Observaciones,
       COALESCE(r.UsuarioTecnicoID, d.UsuarioTecnicoID, a.UsuarioTecnicoID) AS UsuarioTecnicoID,
       et.Nombres + N' ' + et.Apellidos AS Tecnico,
       d.DiagnosticoID, d.Fecha AS FechaDiagnostico, d.Descripcion AS DescripcionDiagnostico,
       d.CostoManoObraEstimado AS CostoEstimado,
       r.ReparacionID, r.FechaInicio AS FechaInicioReparacion, r.FechaFin AS FechaFinReparacion,
       r.DescripcionTrabajo, r.CostoManoObra, r.Estado AS EstadoReparacion
FROM dbo.OrdenServicio o
JOIN dbo.Equipo e ON e.EquipoID = o.EquipoID
JOIN dbo.Cliente c ON c.ClienteID = e.ClienteID
JOIN dbo.ModeloEquipo mo ON mo.ModeloEquipoID = e.ModeloEquipoID
JOIN dbo.Marca ma ON ma.MarcaID = mo.MarcaID
JOIN dbo.Usuario ur ON ur.UsuarioID = o.UsuarioRecepcionID
JOIN dbo.Empleado er ON er.EmpleadoID = ur.EmpleadoID
JOIN dbo.Prioridad p ON p.Codigo = o.PrioridadCodigo
JOIN dbo.EstadoOrden es ON es.Codigo = o.EstadoCodigo
LEFT JOIN dbo.Diagnostico d ON d.OrdenID = o.OrdenID
LEFT JOIN dbo.Reparacion r ON r.DiagnosticoID = d.DiagnosticoID
OUTER APPLY (SELECT TOP (1) ax.UsuarioTecnicoID FROM dbo.AsignacionOrden ax
             WHERE ax.OrdenID = o.OrdenID ORDER BY ax.AsignacionID DESC) a
LEFT JOIN dbo.Usuario ut ON ut.UsuarioID = COALESCE(r.UsuarioTecnicoID, d.UsuarioTecnicoID, a.UsuarioTecnicoID)
LEFT JOIN dbo.Empleado et ON et.EmpleadoID = ut.EmpleadoID;
GO

CREATE OR ALTER FUNCTION dbo.fnPuedeConsultarOrden(@UsuarioID int, @OrdenID int)
RETURNS bit AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM dbo.vOrdenAcceso o WHERE o.OrdenID = @OrdenID AND (
        dbo.fnTieneRol(@UsuarioID, 'RECEPCION') = 1 OR dbo.fnTieneRol(@UsuarioID, 'CAJA') = 1
        OR (dbo.fnTieneRol(@UsuarioID, 'TECNICO') = 1 AND o.UsuarioTecnicoID = @UsuarioID)))
        THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spValidarActorOrden @UsuarioActorID int, @Escritura bit = 0 AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fnTieneRol(@UsuarioActorID, 'RECEPCION') = 1 RETURN;
    IF @Escritura = 0 AND (dbo.fnTieneRol(@UsuarioActorID, 'TECNICO') = 1
                          OR dbo.fnTieneRol(@UsuarioActorID, 'CAJA') = 1) RETURN;
    THROW 51604, N'Tu usuario no tiene permiso para esta operación de órdenes.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spListarOrdenes
    @UsuarioActorID int, @Buscar nvarchar(max) = NULL, @Estado nvarchar(max) = NULL,
    @Prioridad nvarchar(max) = NULL, @TecnicoID int = NULL,
    @Desde datetime2(0) = NULL, @HastaExclusiva datetime2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarActorOrden @UsuarioActorID;
    SET @Buscar = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
    SET @Estado = NULLIF(LTRIM(RTRIM(@Estado)), N'');
    SET @Prioridad = NULLIF(LTRIM(RTRIM(@Prioridad)), N'');
    IF DATALENGTH(@Buscar) > 300 OR @TecnicoID < 0
       OR (@Desde IS NOT NULL AND @HastaExclusiva IS NOT NULL AND @Desde >= @HastaExclusiva)
        THROW 51600, N'Revisá los filtros de búsqueda y las fechas.', 1;
    IF @Estado IS NOT NULL AND (DATALENGTH(@Estado) > 60
       OR NOT EXISTS (SELECT 1 FROM dbo.EstadoOrden WHERE Codigo = @Estado))
        THROW 51600, N'El estado del filtro no existe.', 1;
    IF @Prioridad IS NOT NULL AND (DATALENGTH(@Prioridad) > 20
       OR NOT EXISTS (SELECT 1 FROM dbo.Prioridad WHERE Codigo = @Prioridad))
        THROW 51600, N'La prioridad del filtro no existe.', 1;
    SELECT * FROM dbo.vOrdenAcceso o
    WHERE dbo.fnPuedeConsultarOrden(@UsuarioActorID, o.OrdenID) = 1
      AND (@Buscar IS NULL OR CHARINDEX(@Buscar, o.NumeroOrden) > 0
           OR CHARINDEX(@Buscar, o.Cliente) > 0 OR CHARINDEX(@Buscar, o.NIT) > 0
           OR CHARINDEX(@Buscar, o.NumeroSerie) > 0)
      AND (@Estado IS NULL OR o.EstadoCodigo = @Estado)
      AND (@Prioridad IS NULL OR o.PrioridadCodigo = @Prioridad)
      AND (@TecnicoID IS NULL OR (@TecnicoID = 0 AND o.UsuarioTecnicoID IS NULL) OR o.UsuarioTecnicoID = @TecnicoID)
      AND (@Desde IS NULL OR o.FechaIngreso >= @Desde)
      AND (@HastaExclusiva IS NULL OR o.FechaIngreso < @HastaExclusiva)
    ORDER BY o.FechaIngreso DESC, o.OrdenID DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spConsultarOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarActorOrden @UsuarioActorID;
    IF @OrdenID IS NULL OR @OrdenID <= 0 THROW 51600, N'El ID de orden debe ser mayor que cero.', 1;
    -- Una orden ajena y una inexistente tienen la misma respuesta.
    IF dbo.fnPuedeConsultarOrden(@UsuarioActorID, @OrdenID) = 0
        THROW 51602, N'La orden no existe o no está disponible para tu usuario.', 1;
    SELECT * FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID
      AND dbo.fnPuedeConsultarOrden(@UsuarioActorID, OrdenID) = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spRegistrarOrden
    @UsuarioActorID int, @EquipoID int, @Problema nvarchar(max), @Prioridad nvarchar(max),
    @FechaEstimada datetime2(0) = NULL, @Observaciones nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @OrdenID int, @Numero varchar(30), @Fecha datetime2(0) = SYSUTCDATETIME(), @Lock int;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIRegistrarOrden;
        EXEC dbo.spValidarActorOrden @UsuarioActorID, 1;
        SET @Problema = NULLIF(LTRIM(RTRIM(@Problema)), N'');
        SET @Prioridad = NULLIF(LTRIM(RTRIM(@Prioridad)), N'');
        SET @Observaciones = NULLIF(LTRIM(RTRIM(@Observaciones)), N'');
        IF @Problema IS NULL OR DATALENGTH(@Problema) > 2000
            THROW 51600, N'El problema es obligatorio y admite hasta 1000 caracteres.', 1;
        IF DATALENGTH(@Observaciones) > 2000
            THROW 51600, N'Las observaciones admiten hasta 1000 caracteres.', 1;
        IF @Prioridad IS NULL OR DATALENGTH(@Prioridad) > 20
           OR NOT EXISTS (SELECT 1 FROM dbo.Prioridad WHERE Codigo = @Prioridad)
            THROW 51601, N'Elegí una prioridad válida.', 1;
        IF @FechaEstimada < @Fecha
            THROW 51600, N'La fecha estimada no puede ser anterior al ingreso.', 1;
        SELECT @Lock = e.EquipoID FROM dbo.Equipo e WITH (HOLDLOCK)
        JOIN dbo.Cliente c WITH (HOLDLOCK) ON c.ClienteID = e.ClienteID
        WHERE e.EquipoID = @EquipoID AND e.Activo = 1 AND c.Activo = 1;
        IF @Lock IS NULL THROW 51601, N'El equipo o su cliente no existe o está inactivo.', 1;
        -- La secuencia no se reinicia al repetir este script. Sus huecos son normales.
        WHILE 1 = 1
        BEGIN
            SET @Numero = 'TC-' + CONVERT(varchar(20), NEXT VALUE FOR dbo.SecuenciaOrden);
            IF NOT EXISTS (SELECT 1 FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK) WHERE NumeroOrden = @Numero) BREAK;
        END;
        EXEC dbo.spCrearOrden @NumeroOrden = @Numero, @EquipoID = @EquipoID,
            @UsuarioID = @UsuarioActorID, @Problema = @Problema, @OrdenID = @OrdenID OUTPUT,
            @Prioridad = @Prioridad, @Fecha = @Fecha, @FechaEstimada = @FechaEstimada,
            @Observaciones = @Observaciones;
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APIRegistrarOrden;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spAsignarTecnicoOrden
    @UsuarioActorID int, @OrdenID int, @UsuarioTecnicoID int,
    @TecnicoAnteriorID int = NULL, @Observacion nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @Estado varchar(30), @Actual int;
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIAsignarTecnico;
        EXEC dbo.spValidarActorOrden @UsuarioActorID, 1;
        IF @OrdenID IS NULL OR @OrdenID <= 0 THROW 51600, N'El ID de orden debe ser mayor que cero.', 1;
        SET @Observacion = NULLIF(LTRIM(RTRIM(@Observacion)), N'');
        IF DATALENGTH(@Observacion) > 1000 THROW 51600, N'La observación admite hasta 500 caracteres.', 1;
        SELECT @Estado = EstadoCodigo FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK) WHERE OrdenID = @OrdenID;
        IF @Estado IS NULL THROW 51602, N'La orden no existe o no está disponible para tu usuario.', 1;
        IF @Estado NOT IN ('RECIBIDO', 'DIAGNOSTICO')
           OR EXISTS (SELECT 1 FROM dbo.Diagnostico WHERE OrdenID = @OrdenID)
            THROW 51603, N'Solo se asigna o reasigna antes de registrar el diagnóstico.', 1;
        SELECT @Actual = UsuarioTecnicoID FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID;
        IF ISNULL(@Actual, 0) <> ISNULL(@TecnicoAnteriorID, 0)
            THROW 51603, N'La asignación cambió. Actualizá la orden y volvé a intentar.', 1;
        IF @Actual = @UsuarioTecnicoID THROW 51603, N'El técnico ya está asignado a esta orden.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario u WITH (HOLDLOCK)
            JOIN dbo.Empleado e WITH (HOLDLOCK) ON e.EmpleadoID = u.EmpleadoID
            JOIN dbo.UsuarioRol ur WITH (HOLDLOCK) ON ur.UsuarioID = u.UsuarioID AND ur.RolCodigo = 'TECNICO'
            WHERE u.UsuarioID = @UsuarioTecnicoID AND u.Activo = 1 AND e.Activo = 1)
            THROW 51601, N'Elegí un usuario y empleado activos con rol TECNICO.', 1;
        INSERT dbo.AsignacionOrden(OrdenID, UsuarioTecnicoID, UsuarioAsignaID, Observacion)
            VALUES (@OrdenID, @UsuarioTecnicoID, @UsuarioActorID, @Observacion);
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APIAsignarTecnico;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spCancelarOrden
    @UsuarioActorID int, @OrdenID int, @Motivo nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @Estado varchar(30);
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APICancelarOrden;
        EXEC dbo.spValidarActorOrden @UsuarioActorID, 1;
        IF @OrdenID IS NULL OR @OrdenID <= 0 THROW 51600, N'El ID de orden debe ser mayor que cero.', 1;
        SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), N'');
        IF @Motivo IS NULL OR DATALENGTH(@Motivo) > 1000
            THROW 51600, N'El motivo es obligatorio y admite hasta 500 caracteres.', 1;
        SELECT @Estado = EstadoCodigo FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK) WHERE OrdenID = @OrdenID;
        IF @Estado IS NULL THROW 51602, N'La orden no existe o no está disponible para tu usuario.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.TransicionEstadoOrden WHERE EstadoOrigen = @Estado AND EstadoDestino = 'CANCELADO')
            THROW 51603, N'El estado actual no permite cancelar esta orden.', 1;
        EXEC dbo.spCambiarEstadoOrden @OrdenID, 'CANCELADO', @UsuarioActorID, @Motivo;
        IF @Propia = 1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vOrdenAcceso WHERE OrdenID = @OrdenID;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION APICancelarOrden;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spHistorialOrden @UsuarioActorID int, @OrdenID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarActorOrden @UsuarioActorID;
    IF @OrdenID IS NULL OR @OrdenID <= 0 THROW 51600, N'El ID de orden debe ser mayor que cero.', 1;
    IF dbo.fnPuedeConsultarOrden(@UsuarioActorID, @OrdenID) = 0
        THROW 51602, N'La orden no existe o no está disponible para tu usuario.', 1;
    -- El relleno conserva el orden numérico de los eventos que comparten segundo.
    SELECT 'E-' + RIGHT(REPLICATE('0', 20) + CONVERT(varchar(20), h.HistorialID), 20) AS EventoID, 'ESTADO' AS Tipo,
           h.Fecha, u.NombreUsuario AS Usuario, e.Nombres + N' ' + e.Apellidos AS NombreUsuario,
           h.EstadoAnterior, h.EstadoNuevo, CAST(NULL AS nvarchar(161)) AS Tecnico, h.Observacion
    FROM dbo.HistorialEstadoOrden h
    JOIN dbo.Usuario u ON u.UsuarioID = h.UsuarioID JOIN dbo.Empleado e ON e.EmpleadoID = u.EmpleadoID
    WHERE h.OrdenID = @OrdenID AND dbo.fnPuedeConsultarOrden(@UsuarioActorID, h.OrdenID) = 1
    UNION ALL
    SELECT 'A-' + RIGHT(REPLICATE('0', 20) + CONVERT(varchar(20), a.AsignacionID), 20), 'ASIGNACION', a.Fecha,
           u.NombreUsuario, e.Nombres + N' ' + e.Apellidos, NULL, NULL,
           et.Nombres + N' ' + et.Apellidos, a.Observacion
    FROM dbo.AsignacionOrden a
    JOIN dbo.Usuario u ON u.UsuarioID = a.UsuarioAsignaID JOIN dbo.Empleado e ON e.EmpleadoID = u.EmpleadoID
    JOIN dbo.Usuario ut ON ut.UsuarioID = a.UsuarioTecnicoID JOIN dbo.Empleado et ON et.EmpleadoID = ut.EmpleadoID
    WHERE a.OrdenID = @OrdenID AND dbo.fnPuedeConsultarOrden(@UsuarioActorID, a.OrdenID) = 1
    ORDER BY Fecha, Tipo DESC, EventoID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spCatalogosOrden @UsuarioActorID int, @Catalogo varchar(15) AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarActorOrden @UsuarioActorID;
    IF @Catalogo = 'estados' SELECT Codigo, Nombre, EsFinal FROM dbo.EstadoOrden ORDER BY Codigo;
    ELSE IF @Catalogo = 'prioridades' SELECT Codigo, Nombre, Nivel FROM dbo.Prioridad ORDER BY Nivel;
    ELSE IF @Catalogo = 'tecnicos'
    BEGIN
        EXEC dbo.spValidarActorOrden @UsuarioActorID, 1;
        SELECT u.UsuarioID, e.Codigo AS EmpleadoCodigo, e.Nombres + N' ' + e.Apellidos AS Nombre
        FROM dbo.Usuario u JOIN dbo.Empleado e ON e.EmpleadoID = u.EmpleadoID
        WHERE u.Activo = 1 AND e.Activo = 1
          AND EXISTS (SELECT 1 FROM dbo.UsuarioRol ur WHERE ur.UsuarioID = u.UsuarioID AND ur.RolCodigo = 'TECNICO')
        ORDER BY e.Nombres, e.Apellidos, u.UsuarioID;
    END
    ELSE THROW 51600, N'El catálogo solicitado no existe.', 1;
END;
GO

-- Impide que el historial de Equipos eluda los permisos de consulta de Órdenes.
CREATE OR ALTER PROCEDURE dbo.spHistorialEquipoAcceso @UsuarioActorID int, @EquipoID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarActorOrden @UsuarioActorID;
    IF @EquipoID IS NULL OR @EquipoID <= 0 THROW 51300, N'El ID debe ser mayor que cero.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Equipo WHERE EquipoID = @EquipoID) THROW 51302, N'El equipo no existe.', 1;
    SELECT h.* FROM dbo.vHistorialEquipo h
    WHERE h.EquipoID = @EquipoID AND h.OrdenID IS NOT NULL
      AND dbo.fnPuedeConsultarOrden(@UsuarioActorID, h.OrdenID) = 1
    ORDER BY h.FechaIngreso DESC, h.OrdenID DESC;
END;
GO

DENY INSERT, UPDATE, DELETE ON dbo.AsignacionOrden TO techcare_app;
GRANT SELECT ON dbo.vOrdenAcceso TO techcare_app;
GRANT EXECUTE ON dbo.spListarOrdenes TO techcare_app;
GRANT EXECUTE ON dbo.spConsultarOrden TO techcare_app;
GRANT EXECUTE ON dbo.spRegistrarOrden TO techcare_app;
GRANT EXECUTE ON dbo.spAsignarTecnicoOrden TO techcare_app;
GRANT EXECUTE ON dbo.spCancelarOrden TO techcare_app;
GRANT EXECUTE ON dbo.spHistorialOrden TO techcare_app;
GRANT EXECUTE ON dbo.spCatalogosOrden TO techcare_app;
GRANT EXECUTE ON dbo.spHistorialEquipoAcceso TO techcare_app;
GO
