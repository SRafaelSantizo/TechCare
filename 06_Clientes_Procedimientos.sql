-- Ejecutar una vez sobre la base existente desde SQL Server Management Studio.
-- Es repetible: crea o actualiza los procedimientos sin borrar tablas ni registros.
USE [TechCare];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- API de Clientes. Cada procedimiento resuelve una sola operación.
CREATE OR ALTER PROCEDURE dbo.spListarClientes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ClienteID, TipoClienteID, NIT, Nombre, Email, Telefono, Direccion, Activo
    FROM dbo.Cliente
    ORDER BY ClienteID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spConsultarCliente
    @ClienteID int
AS
BEGIN
    SET NOCOUNT ON;
    IF @ClienteID IS NULL OR @ClienteID <= 0
        THROW 51200, N'El ID debe ser mayor que cero.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteID = @ClienteID)
        THROW 51202, N'El cliente no existe.', 1;
    SELECT ClienteID, TipoClienteID, NIT, Nombre, Email, Telefono, Direccion, Activo
    FROM dbo.Cliente
    WHERE ClienteID = @ClienteID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spRegistrarCliente
    @TipoClienteID int,
    @NIT nvarchar(max),
    @Nombre nvarchar(max),
    @Email nvarchar(max),
    @Telefono nvarchar(max),
    @Direccion nvarchar(max),
    @Activo bit
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @Resultado TABLE (
        ClienteID int, TipoClienteID tinyint, NIT varchar(20), Nombre nvarchar(150),
        Email nvarchar(254), Telefono varchar(25), Direccion nvarchar(250), Activo bit
    );
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION;
        ELSE SAVE TRANSACTION spRegistrarCliente;

        SET @NIT = NULLIF(LTRIM(RTRIM(@NIT)), N'');
        SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
        SET @Email = NULLIF(LTRIM(RTRIM(@Email)), N'');
        SET @Telefono = NULLIF(LTRIM(RTRIM(@Telefono)), N'');
        SET @Direccion = NULLIF(LTRIM(RTRIM(@Direccion)), N'');

        -- Se reciben textos amplios para rechazar excesos antes de que SQL los trunque.
        IF @NIT IS NULL OR DATALENGTH(CONVERT(varchar(max), @NIT)) > 20
            THROW 51200, N'El NIT es obligatorio y admite hasta 20 caracteres.', 1;
        IF @Nombre IS NULL OR DATALENGTH(@Nombre) > 300
            THROW 51200, N'El nombre es obligatorio y admite hasta 150 caracteres.', 1;
        IF DATALENGTH(@Email) > 508 OR
           (@Email IS NOT NULL AND (@Email NOT LIKE N'%_@_%' OR @Email LIKE N'% %'))
            THROW 51200, N'El correo no es válido o supera los 254 caracteres.', 1;
        IF DATALENGTH(CONVERT(varchar(max), @Telefono)) > 25
            THROW 51200, N'El teléfono admite hasta 25 caracteres.', 1;
        IF DATALENGTH(@Direccion) > 500
            THROW 51200, N'La dirección admite hasta 250 caracteres.', 1;
        IF @Activo IS NULL
            THROW 51200, N'Activo es obligatorio.', 1;
        IF @TipoClienteID IS NULL OR NOT EXISTS (
            SELECT 1 FROM dbo.TipoCliente WHERE TipoClienteID = @TipoClienteID)
            THROW 51201, N'El tipo de cliente no existe.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Cliente WHERE NIT = @NIT)
            THROW 51203, N'El NIT ya está registrado en otro cliente.', 1;

        INSERT dbo.Cliente (TipoClienteID, NIT, Nombre, Email, Telefono, Direccion, Activo)
        OUTPUT inserted.ClienteID, inserted.TipoClienteID, inserted.NIT, inserted.Nombre,
               inserted.Email, inserted.Telefono, inserted.Direccion, inserted.Activo
        INTO @Resultado
        VALUES (@TipoClienteID, @NIT, @Nombre, @Email, @Telefono, @Direccion, @Activo);

        IF @Propia = 1 COMMIT TRANSACTION;
        -- Se devuelve la fila de esta operación después de confirmar los cambios.
        SELECT ClienteID, TipoClienteID, NIT, Nombre, Email, Telefono, Direccion, Activo
        FROM @Resultado;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION spRegistrarCliente;
        -- La restricción UNIQUE también protege dos solicitudes concurrentes.
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 51203, N'El NIT ya está registrado en otro cliente.', 1;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spActualizarCliente
    @ClienteID int,
    @TipoClienteID int,
    @NIT nvarchar(max),
    @Nombre nvarchar(max),
    @Email nvarchar(max),
    @Telefono nvarchar(max),
    @Direccion nvarchar(max),
    @Activo bit
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @Resultado TABLE (
        ClienteID int, TipoClienteID tinyint, NIT varchar(20), Nombre nvarchar(150),
        Email nvarchar(254), Telefono varchar(25), Direccion nvarchar(250), Activo bit
    );
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION;
        ELSE SAVE TRANSACTION spActualizarCliente;

        SET @NIT = NULLIF(LTRIM(RTRIM(@NIT)), N'');
        SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
        SET @Email = NULLIF(LTRIM(RTRIM(@Email)), N'');
        SET @Telefono = NULLIF(LTRIM(RTRIM(@Telefono)), N'');
        SET @Direccion = NULLIF(LTRIM(RTRIM(@Direccion)), N'');

        -- Se reciben textos amplios para rechazar excesos antes de que SQL los trunque.
        IF @NIT IS NULL OR DATALENGTH(CONVERT(varchar(max), @NIT)) > 20
            THROW 51200, N'El NIT es obligatorio y admite hasta 20 caracteres.', 1;
        IF @Nombre IS NULL OR DATALENGTH(@Nombre) > 300
            THROW 51200, N'El nombre es obligatorio y admite hasta 150 caracteres.', 1;
        IF DATALENGTH(@Email) > 508 OR
           (@Email IS NOT NULL AND (@Email NOT LIKE N'%_@_%' OR @Email LIKE N'% %'))
            THROW 51200, N'El correo no es válido o supera los 254 caracteres.', 1;
        IF DATALENGTH(CONVERT(varchar(max), @Telefono)) > 25
            THROW 51200, N'El teléfono admite hasta 25 caracteres.', 1;
        IF DATALENGTH(@Direccion) > 500
            THROW 51200, N'La dirección admite hasta 250 caracteres.', 1;
        IF @Activo IS NULL
            THROW 51200, N'Activo es obligatorio.', 1;
        IF @TipoClienteID IS NULL OR NOT EXISTS (
            SELECT 1 FROM dbo.TipoCliente WHERE TipoClienteID = @TipoClienteID)
            THROW 51201, N'El tipo de cliente no existe.', 1;

        IF @ClienteID IS NULL OR @ClienteID <= 0
            THROW 51200, N'El ID debe ser mayor que cero.', 1;
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Cliente WITH (UPDLOCK, HOLDLOCK) WHERE ClienteID = @ClienteID)
            THROW 51202, N'El cliente no existe.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Cliente WHERE NIT = @NIT AND ClienteID <> @ClienteID)
            THROW 51203, N'El NIT ya está registrado en otro cliente.', 1;

        UPDATE dbo.Cliente
        SET TipoClienteID = @TipoClienteID, NIT = @NIT, Nombre = @Nombre,
            Email = @Email, Telefono = @Telefono, Direccion = @Direccion, Activo = @Activo
        OUTPUT inserted.ClienteID, inserted.TipoClienteID, inserted.NIT, inserted.Nombre,
               inserted.Email, inserted.Telefono, inserted.Direccion, inserted.Activo
        INTO @Resultado
        WHERE ClienteID = @ClienteID;
        IF @@ROWCOUNT = 0
            THROW 51202, N'El cliente no existe.', 1;

        IF @Propia = 1 COMMIT TRANSACTION;
        -- Se devuelve la fila de esta operación después de confirmar los cambios.
        SELECT ClienteID, TipoClienteID, NIT, Nombre, Email, Telefono, Direccion, Activo
        FROM @Resultado;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION spActualizarCliente;
        -- La restricción UNIQUE también protege dos solicitudes concurrentes.
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 51203, N'El NIT ya está registrado en otro cliente.', 1;
        THROW;
    END CATCH;
END;
GO

-- La API puede ejecutar los SP, pero no escribir directamente en Cliente.
DENY INSERT, UPDATE, DELETE ON OBJECT::dbo.Cliente TO techcare_app;
GO
GRANT EXECUTE ON OBJECT::dbo.spListarClientes TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spConsultarCliente TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spRegistrarCliente TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spActualizarCliente TO techcare_app;
GO
