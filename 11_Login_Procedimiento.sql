-- Ejecutar una vez en la base TechCare existente. Puede repetirse.
-- Agrega la consulta de acceso; no modifica usuarios, contraseñas, roles ni tablas.
USE [TechCare];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.spConsultarAcceso
    @NombreUsuario nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET @NombreUsuario=NULLIF(LTRIM(RTRIM(@NombreUsuario)),N'');
    IF @NombreUsuario IS NULL OR DATALENGTH(CONVERT(varchar(max),@NombreUsuario))>50
        THROW 51400,N'El usuario es obligatorio y admite hasta 50 caracteres.',1;

    -- Solo el backend consume el hash. Nunca debe enviarlo en una respuesta HTTP.
    -- LEFT JOIN conserva usuarios sin roles para rechazarlos de manera uniforme.
    SELECT u.UsuarioID, u.EmpleadoID, u.NombreUsuario, u.PasswordHash, u.AlgoritmoHash,
           u.Activo AS UsuarioActivo, e.Activo AS EmpleadoActivo,
           e.Codigo AS EmpleadoCodigo, e.Nombres, e.Apellidos, ur.RolCodigo
    FROM dbo.Usuario u
    INNER JOIN dbo.Empleado e ON e.EmpleadoID=u.EmpleadoID
    LEFT JOIN dbo.UsuarioRol ur ON ur.UsuarioID=u.UsuarioID
    WHERE u.NombreUsuario=@NombreUsuario
    ORDER BY ur.RolCodigo;
END;
GO
GRANT EXECUTE ON OBJECT::dbo.spConsultarAcceso TO techcare_app;
GO
