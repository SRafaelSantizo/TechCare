-- Pruebas opcionales del alta de usuarios. Ejecutar después del script 13.
-- Cada caso revierte sus empleados, cuentas y roles de prueba.
USE [TechCare];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 51990, N'Ejecutá estas pruebas sin una transacción abierta.', 1;
IF OBJECT_ID(N'dbo.spRegistrarUsuario', N'P') IS NULL
    THROW 51990, N'Ejecutá primero 13_Usuarios_Procedimientos.sql.', 1;

DECLARE @Admin int = (SELECT TOP (1) UsuarioID FROM dbo.Usuario
                     WHERE dbo.fnTieneRol(UsuarioID, 'ADMIN') = 1 ORDER BY UsuarioID);
IF @Admin IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Codigo = 'TECNICO')
                  OR NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Codigo = 'CAJA')
    THROW 51990, N'Las pruebas requieren un ADMIN activo y los roles TECNICO y CAJA.', 1;

DECLARE @UsuariosIniciales bigint = (SELECT COUNT_BIG(*) FROM dbo.Usuario);
DECLARE @EmpleadosIniciales bigint = (SELECT COUNT_BIG(*) FROM dbo.Empleado);
DECLARE @RolesIniciales bigint = (SELECT COUNT_BIG(*) FROM dbo.UsuarioRol);
DECLARE @Casos TABLE (ID int PRIMARY KEY, Caso nvarchar(180), ErrorEsperado int);
INSERT INTO @Casos VALUES
(1, N'Crear empleado y cuenta con Unicode y varios roles', 0),
(2, N'Crear cuenta para un empleado existente sin duplicarlo', 0),
(3, N'Rechazar actor sin rol ADMIN', 51504),
(4, N'Rechazar nombre de usuario duplicado', 51503),
(5, N'Rechazar código de empleado duplicado', 51503),
(6, N'Rechazar empleado inactivo', 51501),
(7, N'Rechazar segunda cuenta para el mismo empleado', 51503),
(8, N'Rechazar rol inexistente', 51501),
(9, N'Rechazar roles repetidos', 51500),
(10, N'Rechazar contraseña en texto plano en lugar de hash', 51500),
(11, N'Usuario largo no se trunca silenciosamente', 51500),
(12, N'Nombres largos no se truncan silenciosamente', 51500),
(13, N'Exigir al menos un rol', 51500),
(14, N'Exigir empleado nuevo o existente', 51500),
(15, N'Rechazar ambas opciones de empleado al mismo tiempo', 51500),
(16, N'Código largo no se trunca silenciosamente', 51500);
DECLARE @Resultados TABLE (ID int, Caso nvarchar(180), Resultado varchar(4), Detalle nvarchar(4000));
DECLARE @Caso int = 1, @Esperado int, @NombreCaso nvarchar(180);
DECLARE @Actor int, @Empleado int, @Disponible int, @Inactivo int;
DECLARE @Codigo nvarchar(max), @CodigoDisponible varchar(20), @Nombre nvarchar(max);
DECLARE @Nombres nvarchar(max), @Apellidos nvarchar(max), @Roles nvarchar(max), @Hash nvarchar(max);
DECLARE @ClaveHash nvarchar(255) = N'$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik=';
DECLARE @Sufijo varchar(8), @Actual int, @Detalle nvarchar(4000), @Resultado varchar(4), @Nuevo int;

WHILE @Caso <= 16
BEGIN
    SELECT @Esperado = ErrorEsperado, @NombreCaso = Caso FROM @Casos WHERE ID = @Caso;
    SET @Sufijo = LEFT(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''), 8);
    SET @Actor = @Admin;
    SET @Empleado = NULL;
    SET @Codigo = N'TCUN-' + @Sufijo;
    SET @CodigoDisponible = 'TCUD-' + @Sufijo;
    SET @Nombre = N'tc_prueba_' + @Sufijo;
    SET @Nombres = N'María José'; SET @Apellidos = N'Pérez López';
    SET @Roles = N'TECNICO,CAJA'; SET @Hash = @ClaveHash;
    SET @Actual = 0; SET @Detalle = N''; SET @Resultado = 'PASS'; SET @Nuevo = NULL;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.Empleado (Codigo, Nombres, Apellidos, Activo)
        VALUES (@CodigoDisponible, N'Empleado', N'Disponible', 1);
        SET @Disponible = CONVERT(int, SCOPE_IDENTITY());
        INSERT INTO dbo.Empleado (Codigo, Nombres, Apellidos, Activo)
        VALUES ('TCUI-' + @Sufijo, N'Empleado', N'Inactivo', 0);
        SET @Inactivo = CONVERT(int, SCOPE_IDENTITY());

        IF @Caso = 2 BEGIN SET @Empleado = @Disponible; SET @Codigo = NULL; SET @Nombres = NULL; SET @Apellidos = NULL; END;
        IF @Caso = 3 SET @Actor = 0;
        IF @Caso = 4 SELECT @Nombre = NombreUsuario FROM dbo.Usuario WHERE UsuarioID = @Admin;
        IF @Caso = 5 SET @Codigo = @CodigoDisponible;
        IF @Caso = 6 BEGIN SET @Empleado = @Inactivo; SET @Codigo = NULL; SET @Nombres = NULL; SET @Apellidos = NULL; END;
        IF @Caso = 7 BEGIN
            SELECT @Empleado = EmpleadoID FROM dbo.Usuario WHERE UsuarioID = @Admin;
            SET @Codigo = NULL; SET @Nombres = NULL; SET @Apellidos = NULL;
        END;
        IF @Caso = 8 SET @Roles = N'ROL_NO_EXISTE';
        IF @Caso = 9 SET @Roles = N'TECNICO,TECNICO';
        IF @Caso = 10 SET @Hash = N'TextoPlanoNoPermitido';
        IF @Caso = 11 SET @Nombre = REPLICATE(N'x', 51);
        IF @Caso = 12 SET @Nombres = REPLICATE(N'á', 81);
        IF @Caso = 13 SET @Roles = N'';
        IF @Caso = 14 BEGIN SET @Codigo = NULL; SET @Nombres = NULL; SET @Apellidos = NULL; END;
        IF @Caso = 15 SET @Empleado = @Disponible;
        IF @Caso = 16 SET @Codigo = REPLICATE(N'x', 21);

        EXEC dbo.spRegistrarUsuario @Actor, @Empleado, @Codigo, @Nombres, @Apellidos, @Nombre, @Hash, @Roles;
        IF @Esperado <> 0 THROW 51991, N'El procedimiento aceptó una entrada que debía rechazar.', 1;

        SELECT @Nuevo = UsuarioID FROM dbo.Usuario WHERE NombreUsuario = @Nombre;
        IF @Nuevo IS NULL OR NOT EXISTS (
            SELECT 1 FROM dbo.Usuario WHERE UsuarioID = @Nuevo
            AND PasswordHash = CONVERT(varchar(255), @ClaveHash) AND AlgoritmoHash = 'PBKDF2_SHA256' AND Activo = 1)
            THROW 51991, N'La cuenta no conserva el hash y el algoritmo esperados.', 1;
        IF (SELECT COUNT(*) FROM dbo.UsuarioRol WHERE UsuarioID = @Nuevo) <> 2
            THROW 51991, N'La cuenta no conserva los dos roles.', 1;
        IF dbo.fnTieneRol(@Nuevo, 'TECNICO') <> 1 OR dbo.fnTieneRol(@Nuevo, 'ADMIN') <> 0
            THROW 51991, N'Los permisos no coinciden con los roles asignados.', 1;
        IF @Caso = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Empleado e INNER JOIN dbo.Usuario u ON u.EmpleadoID = e.EmpleadoID
                                     WHERE u.UsuarioID = @Nuevo AND e.Nombres = N'María José' AND e.Apellidos = N'Pérez López')
            THROW 51991, N'Los datos Unicode no se conservaron.', 1;
        IF @Caso = 2 AND ((SELECT EmpleadoID FROM dbo.Usuario WHERE UsuarioID = @Nuevo) <> @Disponible
                         OR (SELECT COUNT_BIG(*) FROM dbo.Empleado) <> @EmpleadosIniciales + 2)
            THROW 51991, N'Se duplicó el empleado existente.', 1;
        EXEC dbo.spListarUsuarios @Admin, @Nuevo;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Actual = ERROR_NUMBER(); SET @Detalle = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF @Actual <> @Esperado SET @Resultado = 'FAIL';
    END CATCH;

    IF (SELECT COUNT_BIG(*) FROM dbo.Usuario) <> @UsuariosIniciales
       OR (SELECT COUNT_BIG(*) FROM dbo.Empleado) <> @EmpleadosIniciales
       OR (SELECT COUNT_BIG(*) FROM dbo.UsuarioRol) <> @RolesIniciales
    BEGIN
        SET @Resultado = 'FAIL';
        SET @Detalle = N'Quedaron filas adicionales después de revertir el caso.';
    END;
    INSERT INTO @Resultados VALUES (@Caso, @NombreCaso, @Resultado, @Detalle);
    SET @Caso += 1;
END;
SELECT Caso, Resultado, NULLIF(Detalle, N'') AS Detalle FROM @Resultados ORDER BY ID;
IF EXISTS (SELECT 1 FROM @Resultados WHERE Resultado = 'FAIL')
    THROW 51992, N'Una o más pruebas no pasaron. Revisá la tabla de resultados.', 1;
GO
