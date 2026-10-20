-- Ejecutar después del script 06, con un usuario de pruebas autorizado (p. ej. dbo).
-- No ejecutar dentro de otra transacción. Solo se eliminan los dos clientes de prueba.
USE [TechCare];
GO
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0
    THROW 51290, N'Ejecute estas pruebas en una sesión sin transacción abierta.', 1;

DECLARE @NIT1 varchar(20) = 'TC' + LEFT(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''), 18);
DECLARE @NIT2 varchar(20) = 'TC' + LEFT(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''), 18);
DECLARE @ID1 int, @ID2 int;
DECLARE @Cliente TABLE (
    ClienteID int, TipoClienteID tinyint, NIT varchar(20), Nombre nvarchar(150),
    Email nvarchar(254), Telefono varchar(25), Direccion nvarchar(250), Activo bit
);
DECLARE @Resultados TABLE (Caso nvarchar(150), Resultado varchar(4));

BEGIN TRY
    INSERT @Cliente EXEC dbo.spRegistrarCliente
        1, @NIT1, N'Prueba integración ñ', NULL, NULL, N'Mixco', 1;
    SELECT @ID1 = ClienteID FROM @Cliente;
    IF @ID1 IS NULL OR NOT EXISTS (
        SELECT 1 FROM @Cliente WHERE Nombre = N'Prueba integración ñ' AND Activo = 1)
        THROW 51290, N'No se devolvió el cliente creado con sus datos correctos.', 1;
    INSERT @Resultados VALUES (N'Crear devuelve ID y conserva Unicode', 'PASS');

    DELETE FROM @Cliente;
    INSERT @Cliente EXEC dbo.spRegistrarCliente
        2, @NIT2, N'Segundo cliente de prueba', NULL, NULL, NULL, 1;
    SELECT @ID2 = ClienteID FROM @Cliente;

    DELETE FROM @Cliente;
    INSERT @Cliente EXEC dbo.spActualizarCliente
        @ID1, 1, @NIT1, N'Prueba actualizada', NULL, NULL, N'Dirección actualizada', 0;
    IF NOT EXISTS (SELECT 1 FROM @Cliente
        WHERE ClienteID = @ID1 AND Direccion = N'Dirección actualizada' AND Activo = 0)
        THROW 51290, N'Actualizar no devolvió la fila modificada.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente
        WHERE ClienteID = @ID1 AND Direccion = N'Dirección actualizada' AND Activo = 0)
        THROW 51290, N'Actualizar no persistió los cambios.', 1;
    INSERT @Resultados VALUES (N'Actualizar y desactivar conservando el mismo NIT', 'PASS');

    DELETE FROM @Cliente;
    INSERT @Cliente EXEC dbo.spConsultarCliente @ID1;
    IF NOT EXISTS (SELECT 1 FROM @Cliente WHERE ClienteID = @ID1 AND Activo = 0)
        THROW 51290, N'Consultar no devolvió el cliente actualizado.', 1;
    INSERT @Resultados VALUES (N'Consultar incluye el cliente inactivo', 'PASS');

    DECLARE @Casos TABLE (Numero int PRIMARY KEY, Caso nvarchar(150), Comando nvarchar(max), ErrorEsperado int);
    INSERT @Casos VALUES
    (1, N'NIT duplicado al crear',
        N'EXEC dbo.spRegistrarCliente 1, @NIT, N''Duplicado'', NULL, NULL, NULL, 1;', 51203),
    (2, N'Actualizar cliente inexistente',
        N'EXEC dbo.spActualizarCliente 2147483647, 1, @NIT, N''Prueba'', NULL, NULL, NULL, 1;', 51202),
    (3, N'Tipo de cliente inexistente',
        N'EXEC dbo.spActualizarCliente @ID, 999, @NIT, N''Prueba'', NULL, NULL, NULL, 1;', 51201),
    (4, N'Nombre obligatorio en la BD',
        N'EXEC dbo.spActualizarCliente @ID, 1, @NIT, N''   '', NULL, NULL, NULL, 1;', 51200),
    (5, N'NIT largo no se trunca silenciosamente',
        N'DECLARE @L nvarchar(max) = REPLICATE(N''9'', 21); EXEC dbo.spRegistrarCliente 1, @L, N''Prueba'', NULL, NULL, NULL, 1;', 51200),
    (6, N'Nombre largo no se trunca silenciosamente',
        N'DECLARE @L nvarchar(max) = REPLICATE(N''x'', 151); EXEC dbo.spActualizarCliente @ID, 1, @NIT, @L, NULL, NULL, NULL, 1;', 51200),
    (7, N'NIT de otro cliente al actualizar',
        N'EXEC dbo.spActualizarCliente @OtroID, 1, @NIT, N''Duplicado'', NULL, NULL, NULL, 1;', 51203),
    (8, N'Correo inválido rechazado desde SQL',
        N'EXEC dbo.spActualizarCliente @ID, 1, @NIT, N''Prueba'', N''sin-arroba'', NULL, NULL, 1;', 51200),
    (9, N'Activo obligatorio en la BD',
        N'EXEC dbo.spActualizarCliente @ID, 1, @NIT, N''Prueba'', NULL, NULL, NULL, NULL;', 51200),
    (10, N'Consultar cliente inexistente',
        N'EXEC dbo.spConsultarCliente 2147483647;', 51202),
    (11, N'Consultar ID no positivo',
        N'EXEC dbo.spConsultarCliente 0;', 51200);

    DECLARE @Numero int = 1, @Caso nvarchar(150), @Comando nvarchar(max), @Esperado int, @Recibido int;
    WHILE @Numero <= (SELECT MAX(Numero) FROM @Casos)
    BEGIN
        SELECT @Caso = Caso, @Comando = Comando, @Esperado = ErrorEsperado
        FROM @Casos WHERE Numero = @Numero;
        SET @Recibido = NULL;
        BEGIN TRY
            EXEC sys.sp_executesql @Comando,
                N'@NIT nvarchar(20), @ID int, @OtroID int', @NIT1, @ID1, @ID2;
        END TRY
        BEGIN CATCH
            SET @Recibido = ERROR_NUMBER();
        END CATCH;
        IF @Recibido IS NULL OR @Recibido <> @Esperado
            THROW 51290, @Caso, 1;
        IF @@TRANCOUNT <> 0 OR XACT_STATE() <> 0
            THROW 51290, N'Una operación fallida dejó una transacción abierta.', 1;
        INSERT @Resultados VALUES (@Caso, 'PASS');
        SET @Numero += 1;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteID = @ID1
        AND NIT = @NIT1 AND Nombre = N'Prueba actualizada'
        AND Direccion = N'Dirección actualizada' AND Activo = 0)
       OR NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteID = @ID2 AND NIT = @NIT2)
       OR (SELECT COUNT(*) FROM dbo.Cliente WHERE NIT IN (@NIT1, @NIT2)) <> 2
        THROW 51290, N'Las operaciones rechazadas dejaron cambios parciales.', 1;
    INSERT @Resultados VALUES (N'Errores sin cambios parciales ni clientes adicionales', 'PASS');

    DELETE FROM dbo.Cliente WHERE ClienteID IN (@ID1, @ID2) AND NIT IN (@NIT1, @NIT2);
    SELECT Caso, Resultado FROM @Resultados;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    DELETE FROM dbo.Cliente WHERE ClienteID IN (@ID1, @ID2) AND NIT IN (@NIT1, @NIT2);
    THROW;
END CATCH;
GO
