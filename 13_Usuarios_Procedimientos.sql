-- Ejecutar una vez sobre la base TechCare existente. Puede repetirse.
-- Agrega el alta de cuentas para ADMIN; conserva las tablas y los datos actuales.
USE [TechCare];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.spListarUsuarios
    @UsuarioActorID int,
    @UsuarioID int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF ISNULL(dbo.fnTieneRol(@UsuarioActorID, 'ADMIN'), 0) <> 1
        THROW 51504, N'La operación requiere un administrador activo.', 1;
    IF @UsuarioID IS NOT NULL AND @UsuarioID <= 0
        THROW 51500, N'El identificador de usuario debe ser positivo.', 1;
    IF @UsuarioID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioID = @UsuarioID)
        THROW 51502, N'El usuario no existe.', 1;

    SELECT u.UsuarioID, u.EmpleadoID, e.Codigo AS EmpleadoCodigo,
           e.Nombres, e.Apellidos, u.NombreUsuario,
           u.Activo AS UsuarioActivo, e.Activo AS EmpleadoActivo, u.FechaCreacion,
           ISNULL((SELECT STRING_AGG(CONVERT(varchar(max), ur.RolCodigo), ',')
                          WITHIN GROUP (ORDER BY ur.RolCodigo)
                   FROM dbo.UsuarioRol ur WHERE ur.UsuarioID = u.UsuarioID), '') AS Roles
    FROM dbo.Usuario u
    INNER JOIN dbo.Empleado e ON e.EmpleadoID = u.EmpleadoID
    WHERE @UsuarioID IS NULL OR u.UsuarioID = @UsuarioID
    ORDER BY u.NombreUsuario, u.UsuarioID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spListarRolesAcceso
    @UsuarioActorID int
AS
BEGIN
    SET NOCOUNT ON;
    IF ISNULL(dbo.fnTieneRol(@UsuarioActorID, 'ADMIN'), 0) <> 1
        THROW 51504, N'La operación requiere un administrador activo.', 1;
    SELECT Codigo, Nombre FROM dbo.Rol ORDER BY Nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spListarEmpleadosDisponibles
    @UsuarioActorID int
AS
BEGIN
    SET NOCOUNT ON;
    IF ISNULL(dbo.fnTieneRol(@UsuarioActorID, 'ADMIN'), 0) <> 1
        THROW 51504, N'La operación requiere un administrador activo.', 1;
    SELECT e.EmpleadoID, e.Codigo, e.Nombres, e.Apellidos
    FROM dbo.Empleado e
    WHERE e.Activo = 1
      AND NOT EXISTS (SELECT 1 FROM dbo.Usuario u WHERE u.EmpleadoID = e.EmpleadoID)
    ORDER BY e.Nombres, e.Apellidos, e.Codigo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spRegistrarUsuario
    @UsuarioActorID int,
    @EmpleadoID int,
    @CodigoEmpleado nvarchar(max),
    @Nombres nvarchar(max),
    @Apellidos nvarchar(max),
    @NombreUsuario nvarchar(max),
    @PasswordHash nvarchar(max),
    @Roles nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NombreUsuario = NULLIF(LTRIM(RTRIM(@NombreUsuario)), N'');
    SET @CodigoEmpleado = NULLIF(LTRIM(RTRIM(@CodigoEmpleado)), N'');
    SET @Nombres = NULLIF(LTRIM(RTRIM(@Nombres)), N'');
    SET @Apellidos = NULLIF(LTRIM(RTRIM(@Apellidos)), N'');

    IF ISNULL(dbo.fnTieneRol(@UsuarioActorID, 'ADMIN'), 0) <> 1
        THROW 51504, N'La operación requiere un administrador activo.', 1;
    IF @NombreUsuario IS NULL OR LEN(@NombreUsuario) NOT BETWEEN 3 AND 50
       OR @NombreUsuario COLLATE Latin1_General_100_BIN2 LIKE N'%[^-A-Za-z0-9._]%'
        THROW 51500, N'El usuario admite de 3 a 50 letras sin tildes, números, puntos, guiones o guiones bajos.', 1;
    IF @EmpleadoID IS NULL AND
       (@CodigoEmpleado IS NULL OR LEN(@CodigoEmpleado) > 20
        OR @CodigoEmpleado COLLATE Latin1_General_100_BIN2 LIKE N'%[^-A-Za-z0-9._]%'
        OR @Nombres IS NULL OR DATALENGTH(@Nombres) > 160
        OR @Apellidos IS NULL OR DATALENGTH(@Apellidos) > 160)
        THROW 51500, N'Completá código, nombres y apellidos del empleado dentro de sus límites.', 1;
    IF @EmpleadoID IS NOT NULL AND
       (@EmpleadoID <= 0 OR @CodigoEmpleado IS NOT NULL OR @Nombres IS NOT NULL OR @Apellidos IS NOT NULL)
        THROW 51500, N'Elegí un empleado existente o ingresá uno nuevo, usando una sola opción.', 1;

    -- Java genera este hash con una sal aleatoria. SQL nunca recibe la contraseña.
    IF @PasswordHash IS NULL OR DATALENGTH(@PasswordHash) <> 182
       OR LEFT(@PasswordHash, 22) COLLATE Latin1_General_100_BIN2 <> N'$pbkdf2-sha256$600000$'
       OR SUBSTRING(@PasswordHash, 45, 3) <> N'==$'
       OR RIGHT(@PasswordHash, 1) <> N'='
       OR SUBSTRING(@PasswordHash, 23, 22) COLLATE Latin1_General_100_BIN2 LIKE N'%[^A-Za-z0-9+/]%'
       OR SUBSTRING(@PasswordHash, 48, 43) COLLATE Latin1_General_100_BIN2 LIKE N'%[^A-Za-z0-9+/]%'
        THROW 51500, N'El formato del hash de contraseña no es válido.', 1;

IF @Roles IS NULL
   OR LEN(LTRIM(RTRIM(@Roles))) = 0
   OR DATALENGTH(@Roles) > 208
    THROW 51500, N'Seleccioná entre uno y cinco roles.', 1;
    IF EXISTS (SELECT 1 FROM STRING_SPLIT(@Roles, N',')
               WHERE LEN(value) NOT BETWEEN 1 AND 20
                  OR value COLLATE Latin1_General_100_BIN2 LIKE N'%[^A-Z0-9_]%')
       OR EXISTS (SELECT value FROM STRING_SPLIT(@Roles, N',') GROUP BY value HAVING COUNT(*) > 1)
        THROW 51500, N'Los roles deben ser válidos y no pueden repetirse.', 1;

    DECLARE @RolesElegidos TABLE (Codigo varchar(20) NOT NULL PRIMARY KEY);
    INSERT INTO @RolesElegidos (Codigo) SELECT CONVERT(varchar(20), value) FROM STRING_SPLIT(@Roles, N',');
    IF (SELECT COUNT(*) FROM @RolesElegidos) NOT BETWEEN 1 AND 5
        THROW 51500, N'Seleccioná entre uno y cinco roles.', 1;

    DECLARE @TransaccionPropia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @UsuarioNuevoID int;
    DECLARE @Resultado TABLE (
        UsuarioID int, EmpleadoID int, EmpleadoCodigo varchar(20),
        Nombres nvarchar(80), Apellidos nvarchar(80), NombreUsuario varchar(50),
        UsuarioActivo bit, EmpleadoActivo bit, FechaCreacion datetime2(0), Roles varchar(max)
    );

    BEGIN TRY
        IF @TransaccionPropia = 1 BEGIN TRANSACTION;
        ELSE SAVE TRANSACTION AltaUsuario;

        IF EXISTS (SELECT 1 FROM @RolesElegidos r
                   WHERE NOT EXISTS (SELECT 1 FROM dbo.Rol c WHERE c.Codigo = r.Codigo))
            THROW 51501, N'Uno de los roles seleccionados no existe.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
                   WHERE NombreUsuario = CONVERT(varchar(50), @NombreUsuario))
            THROW 51503, N'El nombre de usuario ya está registrado.', 1;

        IF @EmpleadoID IS NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Empleado WITH (UPDLOCK, HOLDLOCK)
                       WHERE Codigo = CONVERT(varchar(20), @CodigoEmpleado))
                THROW 51503, N'El código del empleado ya existe. Seleccioná el empleado existente si aún no tiene cuenta.', 1;
            INSERT INTO dbo.Empleado (Codigo, Nombres, Apellidos, Activo)
            VALUES (CONVERT(varchar(20), @CodigoEmpleado), @Nombres, @Apellidos, 1);
            SET @EmpleadoID = CONVERT(int, SCOPE_IDENTITY());
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WITH (UPDLOCK, HOLDLOCK)
                           WHERE EmpleadoID = @EmpleadoID AND Activo = 1)
                THROW 51501, N'El empleado no existe o está inactivo.', 1;
            IF EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK) WHERE EmpleadoID = @EmpleadoID)
                THROW 51503, N'El empleado ya tiene una cuenta de usuario.', 1;
        END;

        INSERT INTO dbo.Usuario (EmpleadoID, NombreUsuario, PasswordHash, AlgoritmoHash, Activo)
        VALUES (@EmpleadoID, CONVERT(varchar(50), @NombreUsuario),
                CONVERT(varchar(255), @PasswordHash), 'PBKDF2_SHA256', 1);
        SET @UsuarioNuevoID = CONVERT(int, SCOPE_IDENTITY());
        INSERT INTO dbo.UsuarioRol (UsuarioID, RolCodigo)
        SELECT @UsuarioNuevoID, Codigo FROM @RolesElegidos;

        INSERT INTO @Resultado
        SELECT u.UsuarioID, u.EmpleadoID, e.Codigo, e.Nombres, e.Apellidos,
               u.NombreUsuario, u.Activo, e.Activo, u.FechaCreacion,
               (SELECT STRING_AGG(CONVERT(varchar(max), r.Codigo), ',')
                       WITHIN GROUP (ORDER BY r.Codigo) FROM @RolesElegidos r)
        FROM dbo.Usuario u INNER JOIN dbo.Empleado e ON e.EmpleadoID = u.EmpleadoID
        WHERE u.UsuarioID = @UsuarioNuevoID;

        IF @TransaccionPropia = 1 COMMIT TRANSACTION;
        SELECT * FROM @Resultado;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 AND @TransaccionPropia = 1 ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION AltaUsuario;
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 51503, N'El usuario, el código del empleado o su cuenta ya están registrados.', 1;
        THROW;
    END CATCH;
END;
GO
GRANT EXECUTE ON OBJECT::dbo.spListarUsuarios TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spListarRolesAcceso TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spListarEmpleadosDisponibles TO techcare_app;
GRANT EXECUTE ON OBJECT::dbo.spRegistrarUsuario TO techcare_app;
GO
