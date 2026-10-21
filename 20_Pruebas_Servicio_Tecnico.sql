-- Ejecutar después del 19 en la base de desarrollo, sin escrituras concurrentes.
-- Cada caso crea sus propios datos y hace ROLLBACK. No usa órdenes reales.
-- Las identidades pueden dejar huecos. No equivale a una prueba de concurrencia.
USE [TechCare];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 51790, N'Ejecutá estas pruebas sin una transacción abierta.', 1;
IF OBJECT_ID(N'dbo.spFinalizarReparacionOrden', N'P') IS NULL
    THROW 51790, N'Ejecutá primero 19_Servicio_Tecnico_Procedimientos.sql.', 1;
DECLARE @Admin int = (SELECT TOP (1) UsuarioID FROM dbo.Usuario WHERE dbo.fnTieneRol(UsuarioID, 'ADMIN') = 1 ORDER BY UsuarioID);
DECLARE @Modelo int = (SELECT TOP (1) ModeloEquipoID FROM dbo.ModeloEquipo ORDER BY ModeloEquipoID);
DECLARE @Tipo int = (SELECT TOP (1) TipoClienteID FROM dbo.TipoCliente ORDER BY TipoClienteID);
IF @Admin IS NULL OR @Modelo IS NULL OR @Tipo IS NULL
    THROW 51790, N'Las pruebas requieren un ADMIN activo y catálogos de cliente y equipo.', 1;

DECLARE @Casos TABLE (ID int PRIMARY KEY, Caso nvarchar(200), ErrorEsperado int);
INSERT @Casos VALUES
(1, N'Iniciar revisión registra DIAGNOSTICO y el técnico de la sesión', 0),
(2, N'Técnico ajeno no inicia diagnóstico', 51702),
(3, N'ADMIN sin asignación no sustituye al técnico', 51704),
(4, N'RECEPCION no realiza el trabajo técnico', 51704),
(5, N'No se inicia dos veces el diagnóstico', 51703),
(6, N'Diagnóstico Unicode, costo cero y espera de autorización', 0),
(7, N'Diagnóstico obligatorio', 51700),
(8, N'Diagnóstico largo no se trunca', 51700),
(9, N'Costo negativo rechazado', 51700),
(10, N'Costo con tres decimales rechazado', 51700),
(11, N'Un solo diagnóstico por orden', 51703),
(12, N'Técnico ajeno no registra diagnóstico', 51702),
(13, N'No se repara sin diagnóstico', 51703),
(14, N'No se repara sin autorización documentada', 51700),
(15, N'Inicio conserva trabajo, costo y autorización Unicode', 0),
(16, N'Una sola reparación por orden', 51703),
(17, N'Actividad conserva observación Unicode', 0),
(18, N'Una actividad no se duplica', 51703),
(19, N'Actividad inactiva rechazada', 51701),
(20, N'No se agregan actividades antes de reparar', 51703),
(21, N'Consumo genera salida, saldo y precio histórico', 0),
(22, N'Stock insuficiente rechaza la transacción', 51019),
(23, N'Cantidad cero rechazada', 51700),
(24, N'Precio desactualizado exige volver a confirmar', 51703),
(25, N'Repuesto inactivo rechazado', 51701),
(26, N'Cierre termina reparación y deja LISTO', 0),
(27, N'No se finaliza dos veces', 51703),
(28, N'No se agregan actividades después del cierre', 51703),
(29, N'No se consumen repuestos después del cierre', 51703),
(30, N'Se permite reparar únicamente con mano de obra', 0),
(31, N'Orden cancelada no admite diagnóstico', 51703),
(32, N'Cambiar catálogo no reescribe el precio consumido', 0),
(33, N'Técnico ajeno no consume repuestos', 51702),
(34, N'Técnico ajeno no consulta repuestos usados', 51702),
(35, N'Costo por encima del límite rechazado', 51700),
(36, N'Técnico con cuenta inactiva rechazado', 51704),
(37, N'Reasignación retira permiso al técnico anterior', 51702),
(38, N'Observación larga de actividad rechazada', 51700),
(39, N'Trabajo autorizado largo rechazado', 51700),
(40, N'Diagnóstico histórico no se modifica', 51140);

DECLARE @Antes TABLE (Nombre sysname PRIMARY KEY, Cantidad bigint);
INSERT @Antes
SELECT 'OrdenServicio', COUNT_BIG(*) FROM dbo.OrdenServicio UNION ALL
SELECT 'Diagnostico', COUNT_BIG(*) FROM dbo.Diagnostico UNION ALL
SELECT 'Reparacion', COUNT_BIG(*) FROM dbo.Reparacion UNION ALL
SELECT 'ReparacionActividad', COUNT_BIG(*) FROM dbo.ReparacionActividad UNION ALL
SELECT 'ReparacionRepuesto', COUNT_BIG(*) FROM dbo.ReparacionRepuesto UNION ALL
SELECT 'MovimientoInventario', COUNT_BIG(*) FROM dbo.MovimientoInventario UNION ALL
SELECT 'HistorialEstadoOrden', COUNT_BIG(*) FROM dbo.HistorialEstadoOrden UNION ALL
SELECT 'AsignacionOrden', COUNT_BIG(*) FROM dbo.AsignacionOrden UNION ALL
SELECT 'Cliente', COUNT_BIG(*) FROM dbo.Cliente UNION ALL
SELECT 'Equipo', COUNT_BIG(*) FROM dbo.Equipo UNION ALL
SELECT 'Usuario', COUNT_BIG(*) FROM dbo.Usuario UNION ALL
SELECT 'Empleado', COUNT_BIG(*) FROM dbo.Empleado UNION ALL
SELECT 'UsuarioRol', COUNT_BIG(*) FROM dbo.UsuarioRol UNION ALL
SELECT 'CategoriaRepuesto', COUNT_BIG(*) FROM dbo.CategoriaRepuesto UNION ALL
SELECT 'Repuesto', COUNT_BIG(*) FROM dbo.Repuesto UNION ALL
SELECT 'Bodega', COUNT_BIG(*) FROM dbo.Bodega UNION ALL
SELECT 'Inventario', COUNT_BIG(*) FROM dbo.Inventario UNION ALL
SELECT 'Proveedor', COUNT_BIG(*) FROM dbo.Proveedor UNION ALL
SELECT 'ProveedorRepuesto', COUNT_BIG(*) FROM dbo.ProveedorRepuesto UNION ALL
SELECT 'Compra', COUNT_BIG(*) FROM dbo.Compra UNION ALL
SELECT 'DetalleCompra', COUNT_BIG(*) FROM dbo.DetalleCompra UNION ALL
SELECT 'Actividad', COUNT_BIG(*) FROM dbo.Actividad UNION ALL
SELECT 'AuditoriaPrecioRepuesto', COUNT_BIG(*) FROM dbo.AuditoriaPrecioRepuesto;

SELECT TOP (0) * INTO #ResultadoOrden FROM dbo.vOrdenAcceso;
DECLARE @Resultados TABLE (ID int, Caso nvarchar(200), Resultado varchar(4), Detalle nvarchar(4000));
DECLARE @Caso int = 1, @Esperado int, @Nombre nvarchar(200), @Resultado varchar(4), @Detalle nvarchar(4000), @Preparado bit;
DECLARE @Sufijo varchar(8), @Codigo varchar(30), @Usuario varchar(50), @Nit varchar(20), @Serie varchar(80), @Texto nvarchar(max);
DECLARE @Cliente int, @Equipo int, @Empleado int, @Tec1 int, @Tec2 int, @Recepcion int, @Orden int,
        @Categoria int, @Repuesto int, @Bodega int, @Proveedor int, @Compra int, @Actividad int, @Reparacion int;
DECLARE @Lineas dbo.TipoDetalleCompra;
DECLARE @Hash varchar(255) = '$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik=';
WHILE @Caso <= 40
BEGIN
    SELECT @Nombre = Caso, @Esperado = ErrorEsperado FROM @Casos WHERE ID = @Caso;
    SET @Resultado = 'PASS'; SET @Detalle = NULL; SET @Preparado = 0;
    SET @Sufijo = LEFT(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''), 8);
    DELETE FROM #ResultadoOrden; DELETE FROM @Lineas;
    BEGIN TRY
        BEGIN TRANSACTION;
        SET @Nit = 'TCS-C-' + @Sufijo; SET @Serie = 'TCS-E-' + @Sufijo;
        INSERT dbo.Cliente(TipoClienteID, NIT, Nombre, Activo) VALUES (@Tipo, @Nit, N'Cliente de prueba técnica', 1);
        SET @Cliente = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Equipo(ClienteID, ModeloEquipoID, NumeroSerie, Descripcion, Activo)
            VALUES (@Cliente, @Modelo, @Serie, N'Equipo de prueba técnica', 1);
        SET @Equipo = CONVERT(int, SCOPE_IDENTITY());

        SET @Codigo = 'TCST1-' + @Sufijo; SET @Usuario = 'tcst1_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Técnico', N'Uno', 1);
        SET @Empleado = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Empleado, @Usuario, @Hash, 1);
        SET @Tec1 = CONVERT(int, SCOPE_IDENTITY());
        SET @Codigo = 'TCST2-' + @Sufijo; SET @Usuario = 'tcst2_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Técnico', N'Dos', 1);
        SET @Empleado = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Empleado, @Usuario, @Hash, 1);
        SET @Tec2 = CONVERT(int, SCOPE_IDENTITY());
        SET @Codigo = 'TCSR-' + @Sufijo; SET @Usuario = 'tcsr_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Recepción', N'Prueba', 1);
        SET @Empleado = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Empleado, @Usuario, @Hash, 1);
        SET @Recepcion = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.UsuarioRol VALUES (@Tec1, 'TECNICO'), (@Tec2, 'TECNICO'), (@Recepcion, 'RECEPCION');

        SET @Codigo = 'TCS-' + @Sufijo;
        EXEC dbo.spCrearOrden @Codigo, @Equipo, @Admin, N'No enciende ñ 漢字', @Orden OUTPUT;
        INSERT #ResultadoOrden EXEC dbo.spAsignarTecnicoOrden @Admin, @Orden, @Tec1;
        DELETE FROM #ResultadoOrden;
        SET @Texto = N'Categoría de prueba ' + @Sufijo;
        INSERT dbo.CategoriaRepuesto(Nombre) VALUES (@Texto);
        SET @Categoria = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Repuesto(CategoriaID, Codigo, Nombre, CostoReferencia, PrecioVenta, Activo)
            VALUES (@Categoria, @Codigo, N'Fuente de prueba ñ', 12.25, 25.50, 1);
        SET @Repuesto = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Bodega(Codigo, Nombre, Activo) VALUES (@Codigo, N'Bodega técnica de prueba', 1);
        SET @Bodega = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Inventario(BodegaID, RepuestoID, StockMinimo) VALUES (@Bodega, @Repuesto, 2);
        SET @Nit = 'TCS-P-' + @Sufijo;
        INSERT dbo.Proveedor(NIT, Nombre, Activo) VALUES (@Nit, N'Proveedor de prueba técnica', 1);
        SET @Proveedor = CONVERT(int, SCOPE_IDENTITY());
        -- El detalle de compra exige que el proveedor ofrezca este repuesto.
        INSERT dbo.ProveedorRepuesto(ProveedorID, RepuestoID) VALUES (@Proveedor, @Repuesto);
        INSERT @Lineas VALUES (1, @Bodega, @Repuesto, 10, 12.25);
        EXEC dbo.spRegistrarCompra @Codigo, @Proveedor, @Admin, @Lineas, @Compra OUTPUT;
        EXEC dbo.spRecibirCompra @Compra, @Admin;
        SET @Texto = N'Prueba con carga ' + @Sufijo;
        INSERT dbo.Actividad(Nombre, Activo) VALUES (@Texto, 1);
        SET @Actividad = CONVERT(int, SCOPE_IDENTITY());
        SET @Preparado = 1;

        IF @Caso = 1
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spIniciarDiagnosticoOrden @Tec1, @Orden;
            IF NOT EXISTS (SELECT 1 FROM #ResultadoOrden WHERE EstadoCodigo = 'DIAGNOSTICO' AND UsuarioTecnicoID = @Tec1)
               OR NOT EXISTS (SELECT 1 FROM dbo.HistorialEstadoOrden WHERE OrdenID = @Orden AND EstadoNuevo = 'DIAGNOSTICO' AND UsuarioID = @Tec1)
                THROW 51791, N'No se registró el inicio de revisión con su técnico.', 1;
        END;
        IF @Caso = 2 EXEC dbo.spIniciarDiagnosticoOrden @Tec2, @Orden;
        IF @Caso = 3 EXEC dbo.spIniciarDiagnosticoOrden @Admin, @Orden;
        IF @Caso = 4 EXEC dbo.spIniciarDiagnosticoOrden @Recepcion, @Orden;
        IF @Caso = 5
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spIniciarDiagnosticoOrden @Tec1, @Orden;
            EXEC dbo.spIniciarDiagnosticoOrden @Tec1, @Orden;
        END;
        IF @Caso = 6
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spRegistrarDiagnosticoOrden @Tec1, @Orden, N'Falla de alimentación ñ 漢字', 0;
            IF NOT EXISTS (SELECT 1 FROM #ResultadoOrden WHERE EstadoCodigo = 'ESPERANDO_AUTORIZACION' AND CostoEstimado = 0
                           AND DescripcionDiagnostico = N'Falla de alimentación ñ 漢字' AND UsuarioTecnicoID = @Tec1)
               OR (SELECT COUNT(*) FROM dbo.HistorialEstadoOrden WHERE OrdenID = @Orden) <> 3
                THROW 51791, N'El diagnóstico no conservó sus datos o sus transiciones.', 1;
        END;
        IF @Caso = 7 EXEC dbo.spRegistrarDiagnosticoOrden @Tec1, @Orden, N'  ', 1;
        IF @Caso = 8
        BEGIN
            SET @Texto = REPLICATE(N'a', 2001);
            EXEC dbo.spRegistrarDiagnosticoOrden @Tec1, @Orden, @Texto, 1;
        END;
        IF @Caso = 9 EXEC dbo.spRegistrarDiagnosticoOrden @Tec1, @Orden, N'Diagnóstico', -1;
        IF @Caso = 10 EXEC dbo.spRegistrarDiagnosticoOrden @Tec1, @Orden, N'Diagnóstico', 1.234;
        IF @Caso = 12 EXEC dbo.spRegistrarDiagnosticoOrden @Tec2, @Orden, N'Diagnóstico ajeno', 1;
        IF @Caso = 13 EXEC dbo.spIniciarReparacionOrden @Tec1, @Orden, N'Cambiar fuente', 50, N'Autorizado';
        IF @Caso = 20 EXEC dbo.spAgregarActividadOrden @Tec1, @Orden, @Actividad;
        IF @Caso = 31
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spCancelarOrden @Admin, @Orden, N'Cliente cancela';
            EXEC dbo.spRegistrarDiagnosticoOrden @Tec1, @Orden, N'No corresponde', 1;
        END;
        IF @Caso = 35 EXEC dbo.spRegistrarDiagnosticoOrden @Tec1, @Orden, N'Diagnóstico', 10000000000;
        IF @Caso = 36
        BEGIN
            UPDATE dbo.Usuario SET Activo = 0 WHERE UsuarioID = @Tec1;
            EXEC dbo.spIniciarDiagnosticoOrden @Tec1, @Orden;
        END;
        IF @Caso = 37
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spAsignarTecnicoOrden @Admin, @Orden, @Tec2, @Tec1;
            EXEC dbo.spRegistrarDiagnosticoOrden @Tec1, @Orden, N'Usuario anterior', 1;
        END;

        IF @Caso IN (11,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,30,32,33,34,38,39,40)
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spRegistrarDiagnosticoOrden @Tec1, @Orden, N'Cambiar fuente ñ 漢字', 50.75;
            DELETE FROM #ResultadoOrden;
        END;
        IF @Caso = 11 EXEC dbo.spRegistrarDiagnosticoOrden @Tec1, @Orden, N'Otro diagnóstico', 10;
        IF @Caso = 14 EXEC dbo.spIniciarReparacionOrden @Tec1, @Orden, N'Cambiar fuente', 50.75, N'  ';
        IF @Caso = 39
        BEGIN
            SET @Texto = REPLICATE(N'a', 2001);
            EXEC dbo.spIniciarReparacionOrden @Tec1, @Orden, @Texto, 50.75, N'Autorizado';
        END;
        IF @Caso = 40 UPDATE dbo.Diagnostico SET Descripcion = N'Reescritura' WHERE OrdenID = @Orden;
        IF @Caso IN (15,16,17,18,19,21,22,23,24,25,26,27,28,29,30,32,33,34,38)
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spIniciarReparacionOrden @Tec1, @Orden, N'Cambiar fuente ñ 漢字', 50.75, N'María José autorizó por teléfono';
            SELECT @Reparacion = ReparacionID FROM #ResultadoOrden;
            IF @Caso = 15 AND (NOT EXISTS (SELECT 1 FROM #ResultadoOrden WHERE EstadoCodigo = 'REPARACION' AND CostoManoObra = 50.75
                                          AND UsuarioTecnicoID = @Tec1 AND DescripcionTrabajo = N'Cambiar fuente ñ 漢字')
                OR NOT EXISTS (SELECT 1 FROM dbo.HistorialEstadoOrden WHERE OrdenID = @Orden AND EstadoNuevo = 'REPARACION'
                               AND Observacion = N'María José autorizó por teléfono' AND UsuarioID = @Tec1))
                THROW 51791, N'El inicio perdió la autorización o los datos de la reparación.', 1;
            DELETE FROM #ResultadoOrden;
        END;
        IF @Caso = 16 EXEC dbo.spIniciarReparacionOrden @Tec1, @Orden, N'Otra reparación', 1, N'Autorizado';
        IF @Caso IN (17,18)
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spAgregarActividadOrden @Tec1, @Orden, @Actividad, N'Probado con carga ñ 漢字';
            IF NOT EXISTS (SELECT 1 FROM dbo.ReparacionActividad WHERE ReparacionID = @Reparacion AND ActividadID = @Actividad
                           AND Observacion = N'Probado con carga ñ 漢字') THROW 51791, N'La actividad perdió su observación.', 1;
        END;
        IF @Caso = 18 EXEC dbo.spAgregarActividadOrden @Tec1, @Orden, @Actividad;
        IF @Caso = 19
        BEGIN
            UPDATE dbo.Actividad SET Activo = 0 WHERE ActividadID = @Actividad;
            EXEC dbo.spAgregarActividadOrden @Tec1, @Orden, @Actividad;
        END;
        IF @Caso IN (21,26,32)
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spUsarRepuestoOrden @Tec1, @Orden, @Bodega, @Repuesto, 2, 25.50;
            IF dbo.fnExistencia(@Bodega, @Repuesto) <> 8
               OR NOT EXISTS (SELECT 1 FROM dbo.ReparacionRepuesto WHERE ReparacionID = @Reparacion AND Cantidad = 2 AND PrecioUnitario = 25.50 AND CostoUnitario = 12.25)
               OR (SELECT COUNT(*) FROM dbo.MovimientoInventario WHERE ReparacionID = @Reparacion AND UsuarioID = @Tec1 AND ExistenciaResultante = 8) <> 1
                THROW 51791, N'El consumo, su precio o su salida no son consistentes.', 1;
        END;
        IF @Caso = 22 EXEC dbo.spUsarRepuestoOrden @Tec1, @Orden, @Bodega, @Repuesto, 11, 25.50;
        IF @Caso = 23 EXEC dbo.spUsarRepuestoOrden @Tec1, @Orden, @Bodega, @Repuesto, 0, 25.50;
        IF @Caso = 24 EXEC dbo.spUsarRepuestoOrden @Tec1, @Orden, @Bodega, @Repuesto, 1, 20;
        IF @Caso = 25
        BEGIN
            UPDATE dbo.Repuesto SET Activo = 0 WHERE RepuestoID = @Repuesto;
            EXEC dbo.spUsarRepuestoOrden @Tec1, @Orden, @Bodega, @Repuesto, 1, 25.50;
        END;
        IF @Caso IN (26,27,28,29,30)
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spFinalizarReparacionOrden @Tec1, @Orden;
            IF NOT EXISTS (SELECT 1 FROM #ResultadoOrden WHERE EstadoCodigo = 'LISTO' AND EstadoReparacion = 'TERMINADA' AND FechaFinReparacion IS NOT NULL)
               OR NOT EXISTS (SELECT 1 FROM dbo.HistorialEstadoOrden WHERE OrdenID = @Orden AND EstadoNuevo = 'LISTO' AND UsuarioID = @Tec1)
                THROW 51791, N'El cierre no finalizó la reparación y la orden juntas.', 1;
            IF @Caso = 30 AND EXISTS (SELECT 1 FROM dbo.ReparacionRepuesto WHERE ReparacionID = @Reparacion)
                THROW 51791, N'La reparación de mano de obra no debe generar consumos.', 1;
        END;
        IF @Caso = 27 EXEC dbo.spFinalizarReparacionOrden @Tec1, @Orden;
        IF @Caso = 28 EXEC dbo.spAgregarActividadOrden @Tec1, @Orden, @Actividad;
        IF @Caso = 29 EXEC dbo.spUsarRepuestoOrden @Tec1, @Orden, @Bodega, @Repuesto, 1, 25.50;
        IF @Caso = 32
        BEGIN
            UPDATE dbo.Repuesto SET PrecioVenta = 99.99 WHERE RepuestoID = @Repuesto;
            IF NOT EXISTS (SELECT 1 FROM dbo.ReparacionRepuesto WHERE ReparacionID = @Reparacion AND PrecioUnitario = 25.50)
                THROW 51791, N'El precio del catálogo cambió la historia del consumo.', 1;
        END;
        IF @Caso = 33 EXEC dbo.spUsarRepuestoOrden @Tec2, @Orden, @Bodega, @Repuesto, 1, 25.50;
        IF @Caso = 34 EXEC dbo.spRepuestosOrden @Tec2, @Orden;
        IF @Caso = 38
        BEGIN
            SET @Texto = REPLICATE(N'a', 501);
            EXEC dbo.spAgregarActividadOrden @Tec1, @Orden, @Actividad, @Texto;
        END;
        IF @Esperado <> 0 THROW 51791, N'La operación debía rechazarse y fue aceptada.', 1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Detalle = ERROR_MESSAGE();
        IF @Preparado = 0 OR @Esperado = 0 OR ERROR_NUMBER() <> @Esperado SET @Resultado = 'FAIL';
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    END CATCH;
    ;WITH Despues AS (
        SELECT 'OrdenServicio' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.OrdenServicio UNION ALL
        SELECT 'Diagnostico', COUNT_BIG(*) FROM dbo.Diagnostico UNION ALL
        SELECT 'Reparacion', COUNT_BIG(*) FROM dbo.Reparacion UNION ALL
        SELECT 'ReparacionActividad', COUNT_BIG(*) FROM dbo.ReparacionActividad UNION ALL
        SELECT 'ReparacionRepuesto', COUNT_BIG(*) FROM dbo.ReparacionRepuesto UNION ALL
        SELECT 'MovimientoInventario', COUNT_BIG(*) FROM dbo.MovimientoInventario UNION ALL
        SELECT 'HistorialEstadoOrden', COUNT_BIG(*) FROM dbo.HistorialEstadoOrden UNION ALL
        SELECT 'AsignacionOrden', COUNT_BIG(*) FROM dbo.AsignacionOrden UNION ALL
        SELECT 'Cliente', COUNT_BIG(*) FROM dbo.Cliente UNION ALL
        SELECT 'Equipo', COUNT_BIG(*) FROM dbo.Equipo UNION ALL
        SELECT 'Usuario', COUNT_BIG(*) FROM dbo.Usuario UNION ALL
        SELECT 'Empleado', COUNT_BIG(*) FROM dbo.Empleado UNION ALL
        SELECT 'UsuarioRol', COUNT_BIG(*) FROM dbo.UsuarioRol UNION ALL
        SELECT 'CategoriaRepuesto', COUNT_BIG(*) FROM dbo.CategoriaRepuesto UNION ALL
        SELECT 'Repuesto', COUNT_BIG(*) FROM dbo.Repuesto UNION ALL
        SELECT 'Bodega', COUNT_BIG(*) FROM dbo.Bodega UNION ALL
        SELECT 'Inventario', COUNT_BIG(*) FROM dbo.Inventario UNION ALL
        SELECT 'Proveedor', COUNT_BIG(*) FROM dbo.Proveedor UNION ALL
        SELECT 'ProveedorRepuesto', COUNT_BIG(*) FROM dbo.ProveedorRepuesto UNION ALL
        SELECT 'Compra', COUNT_BIG(*) FROM dbo.Compra UNION ALL
        SELECT 'DetalleCompra', COUNT_BIG(*) FROM dbo.DetalleCompra UNION ALL
        SELECT 'Actividad', COUNT_BIG(*) FROM dbo.Actividad UNION ALL
        SELECT 'AuditoriaPrecioRepuesto', COUNT_BIG(*) FROM dbo.AuditoriaPrecioRepuesto
    )
    SELECT @Resultado = CASE WHEN EXISTS (SELECT 1 FROM Despues d JOIN @Antes a ON a.Nombre = d.Nombre WHERE a.Cantidad <> d.Cantidad)
                              THEN 'FAIL' ELSE @Resultado END;
    IF @Resultado = 'FAIL' AND @Detalle IS NULL SET @Detalle = N'La prueba dejó cantidades persistentes distintas de las iniciales.';
    INSERT @Resultados VALUES (@Caso, @Nombre, @Resultado, @Detalle);
    SET @Caso += 1;
END;
DROP TABLE #ResultadoOrden;
SELECT ID, Caso, Resultado, Detalle FROM @Resultados ORDER BY ID;
IF EXISTS (SELECT 1 FROM @Resultados WHERE Resultado = 'FAIL')
    THROW 51792, N'Una o más pruebas de servicio técnico fallaron. Revisá los resultados.', 1;
GO
