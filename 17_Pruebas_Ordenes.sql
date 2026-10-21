-- Pruebas opcionales. Ejecutar después del 16, sin transacciones abiertas.
-- Cada caso revierte todos sus datos. Identidades y secuencias pueden dejar huecos.
USE [TechCare];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 51990, N'Ejecutá estas pruebas sin una transacción abierta.', 1;
IF OBJECT_ID(N'dbo.spRegistrarOrden', N'P') IS NULL
    THROW 51990, N'Ejecutá primero 16_Ordenes_Procedimientos.sql.', 1;
DECLARE @Admin int = (SELECT TOP (1) UsuarioID FROM dbo.Usuario WHERE dbo.fnTieneRol(UsuarioID, 'ADMIN') = 1 ORDER BY UsuarioID);
DECLARE @Modelo int = (SELECT TOP (1) ModeloEquipoID FROM dbo.ModeloEquipo ORDER BY ModeloEquipoID);
DECLARE @Tipo int = (SELECT TOP (1) TipoClienteID FROM dbo.TipoCliente ORDER BY TipoClienteID);
IF @Admin IS NULL OR @Modelo IS NULL OR @Tipo IS NULL
    THROW 51990, N'Las pruebas requieren un ADMIN activo y catálogos de clientes y equipos.', 1;

DECLARE @Ordenes bigint = (SELECT COUNT_BIG(*) FROM dbo.OrdenServicio),
        @Historial bigint = (SELECT COUNT_BIG(*) FROM dbo.HistorialEstadoOrden),
        @Asignaciones bigint = (SELECT COUNT_BIG(*) FROM dbo.AsignacionOrden),
        @Clientes bigint = (SELECT COUNT_BIG(*) FROM dbo.Cliente),
        @Equipos bigint = (SELECT COUNT_BIG(*) FROM dbo.Equipo),
        @Usuarios bigint = (SELECT COUNT_BIG(*) FROM dbo.Usuario),
        @Empleados bigint = (SELECT COUNT_BIG(*) FROM dbo.Empleado),
        @Roles bigint = (SELECT COUNT_BIG(*) FROM dbo.UsuarioRol),
        @Diagnosticos bigint = (SELECT COUNT_BIG(*) FROM dbo.Diagnostico);
DECLARE @Casos TABLE (ID int PRIMARY KEY, Caso nvarchar(200), ErrorEsperado int, MensajeEsperado nvarchar(500));
INSERT @Casos VALUES
(1, N'Crear orden con Unicode, número propio e historial inicial único', 0, NULL),
(2, N'Problema obligatorio', 51600, N'El problema es obligatorio y admite hasta 1000 caracteres.'),
(3, N'Problema largo no se trunca silenciosamente', 51600, N'El problema es obligatorio y admite hasta 1000 caracteres.'),
(4, N'Observaciones largas no se truncan', 51600, N'Las observaciones admiten hasta 1000 caracteres.'),
(5, N'Prioridad inexistente', 51601, N'Elegí una prioridad válida.'),
(6, N'Equipo inactivo', 51601, N'El equipo o su cliente no existe o está inactivo.'),
(7, N'Cliente inactivo', 51601, N'El equipo o su cliente no existe o está inactivo.'),
(8, N'Fecha estimada anterior al ingreso', 51600, N'La fecha estimada no puede ser anterior al ingreso.'),
(9, N'BODEGA no puede crear órdenes', 51604, N'Tu usuario no tiene permiso para esta operación de órdenes.'),
(10, N'BODEGA no puede listar órdenes', 51604, N'Tu usuario no tiene permiso para esta operación de órdenes.'),
(11, N'Asignar técnico y limitar consulta a su usuario', 0, NULL),
(12, N'Reasignar conserva los eventos y retira el acceso anterior', 0, NULL),
(13, N'Rechazar responsable sin rol TECNICO', 51601, N'Elegí un usuario y empleado activos con rol TECNICO.'),
(14, N'Rechazar técnico con cuenta inactiva', 51601, N'Elegí un usuario y empleado activos con rol TECNICO.'),
(15, N'Rechazar técnico con empleado inactivo', 51601, N'Elegí un usuario y empleado activos con rol TECNICO.'),
(16, N'Rechazar asignación desde una pantalla desactualizada', 51603, N'La asignación cambió. Actualizá la orden y volvé a intentar.'),
(17, N'No duplicar la misma asignación', 51603, N'El técnico ya está asignado a esta orden.'),
(18, N'TECNICO no puede asignarse una orden', 51604, N'Tu usuario no tiene permiso para esta operación de órdenes.'),
(19, N'Técnico ajeno no puede consultar la orden por ID', 51602, N'La orden no existe o no está disponible para tu usuario.'),
(20, N'Técnico ajeno no puede consultar el historial por ID', 51602, N'La orden no existe o no está disponible para tu usuario.'),
(21, N'CAJA puede consultar órdenes sin estar asignada', 0, NULL),
(22, N'Cancelar conserva la orden y registra el motivo Unicode', 0, NULL),
(23, N'Cancelación exige motivo', 51600, N'El motivo es obligatorio y admite hasta 500 caracteres.'),
(24, N'No se cancela dos veces', 51603, N'El estado actual no permite cancelar esta orden.'),
(25, N'No se asigna una orden cancelada', 51603, N'Solo se asigna o reasigna antes de registrar el diagnóstico.'),
(26, N'No se reescribe el responsable de un diagnóstico histórico', 51603, N'Solo se asigna o reasigna antes de registrar el diagnóstico.'),
(27, N'Buscar porcentajes y guiones bajos como texto literal', 0, NULL),
(28, N'Historial de Equipos respeta las órdenes del técnico', 0, NULL),
(29, N'Orden con ID no positivo', 51600, N'El ID de orden debe ser mayor que cero.'),
(30, N'Historial de asignaciones inmutable', 51603, N'El historial de asignaciones no se modifica ni se elimina.');

SELECT TOP (0) * INTO #OrdenResultado FROM dbo.vOrdenAcceso;
SELECT TOP (0) * INTO #HistorialEquipo FROM dbo.vHistorialEquipo;
DECLARE @Resultados TABLE (ID int, Caso nvarchar(200), Resultado varchar(4), Detalle nvarchar(4000));
DECLARE @Caso int = 1, @Nombre nvarchar(200), @Esperado int, @Mensaje nvarchar(500), @Detalle nvarchar(4000), @Resultado varchar(4);
DECLARE @ClienteID int, @EquipoID int, @Emp1 int, @Emp2 int, @Emp3 int, @Tec1 int, @Tec2 int, @Otro int, @OrdenID int, @D int;
DECLARE @Sufijo varchar(8), @Codigo varchar(20), @Usuario varchar(50), @Nit varchar(20), @Serie varchar(80), @NombreCliente nvarchar(150);
DECLARE @Problema nvarchar(max), @Observacion nvarchar(max), @Prioridad nvarchar(max), @Fecha datetime2(0), @Actor int, @Destino int;
DECLARE @Hash varchar(255) = '$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik=';

WHILE @Caso <= 30
BEGIN
    SELECT @Nombre = Caso, @Esperado = ErrorEsperado, @Mensaje = MensajeEsperado FROM @Casos WHERE ID = @Caso;
    SET @Detalle = NULL; SET @Resultado = 'PASS';
    SET @OrdenID = NULL;
    SET @Sufijo = LEFT(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''), 8);
    DELETE FROM #OrdenResultado; DELETE FROM #HistorialEquipo;
    BEGIN TRY
        BEGIN TRANSACTION;
        SET @Nit = 'TCO-' + @Sufijo; SET @Serie = 'TCO-E-' + @Sufijo;
        SET @NombreCliente = N'Cliente 100%_ María José ' + @Sufijo;
        INSERT dbo.Cliente(TipoClienteID, NIT, Nombre, Activo) VALUES (@Tipo, @Nit, @NombreCliente, 1);
        SET @ClienteID = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Equipo(ClienteID, ModeloEquipoID, NumeroSerie, Descripcion, Activo)
            VALUES (@ClienteID, @Modelo, @Serie, N'Portátil de prueba ñ 漢字', 1);
        SET @EquipoID = CONVERT(int, SCOPE_IDENTITY());
        SET @Codigo = 'TCOT1-' + @Sufijo; SET @Usuario = 'tcot1_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Técnico', N'Uno', 1);
        SET @Emp1 = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Emp1, @Usuario, @Hash, 1);
        SET @Tec1 = CONVERT(int, SCOPE_IDENTITY());
        SET @Codigo = 'TCOT2-' + @Sufijo; SET @Usuario = 'tcot2_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Técnico', N'Dos', 1);
        SET @Emp2 = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Emp2, @Usuario, @Hash, 1);
        SET @Tec2 = CONVERT(int, SCOPE_IDENTITY());
        SET @Codigo = 'TCOB-' + @Sufijo; SET @Usuario = 'tcob_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Bodega', N'Prueba', 1);
        SET @Emp3 = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Emp3, @Usuario, @Hash, 1);
        SET @Otro = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.UsuarioRol VALUES (@Tec1, 'TECNICO'), (@Tec2, 'TECNICO'), (@Otro, 'BODEGA');
        INSERT #OrdenResultado EXEC dbo.spRegistrarOrden @Admin, @EquipoID, N'No enciende: revisión ñ 漢字', N'NORMAL', NULL, N'Entregado por María José';
        SELECT @OrdenID = OrdenID FROM #OrdenResultado;
        IF @OrdenID IS NULL THROW 51991, N'La preparación no devolvió una orden.', 1;
        IF @Caso = 1
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM #OrdenResultado WHERE EstadoCodigo = 'RECIBIDO' AND NumeroOrden LIKE 'TC-%'
                AND ProblemaReportado = N'No enciende: revisión ñ 漢字' AND ClienteID = @ClienteID AND UsuarioRecepcionID = @Admin)
                THROW 51991, N'La orden no conservó el ingreso, el cliente o Unicode.', 1;
            IF (SELECT COUNT(*) FROM dbo.HistorialEstadoOrden WHERE OrdenID = @OrdenID AND EstadoAnterior IS NULL AND EstadoNuevo = 'RECIBIDO') <> 1
                THROW 51991, N'El historial inicial debe tener un evento.', 1;
        END;
        DELETE FROM #OrdenResultado;
        IF @Caso BETWEEN 2 AND 9
        BEGIN
            SET @Problema = N'Otra falla'; SET @Observacion = NULL; SET @Prioridad = N'NORMAL'; SET @Fecha = NULL; SET @Actor = @Admin;
            IF @Caso = 2 SET @Problema = N'   ';
            IF @Caso = 3 SET @Problema = REPLICATE(N'a', 1001);
            IF @Caso = 4 SET @Observacion = REPLICATE(N'a', 1001);
            IF @Caso = 5 SET @Prioridad = N'NO_EXISTE';
            IF @Caso = 6 UPDATE dbo.Equipo SET Activo = 0 WHERE EquipoID = @EquipoID;
            IF @Caso = 7 UPDATE dbo.Cliente SET Activo = 0 WHERE ClienteID = @ClienteID;
            IF @Caso = 8 SET @Fecha = DATEADD(day, -1, SYSUTCDATETIME());
            IF @Caso = 9 SET @Actor = @Otro;
            EXEC dbo.spRegistrarOrden @Actor, @EquipoID, @Problema, @Prioridad, @Fecha, @Observacion;
        END;
        IF @Caso = 10 EXEC dbo.spListarOrdenes @Otro;
        IF @Caso IN (11,12,16,17,19,20,26,28,30)
            INSERT #OrdenResultado EXEC dbo.spAsignarTecnicoOrden @Admin, @OrdenID, @Tec1, NULL, N'Asignación inicial';
        IF @Caso = 11
        BEGIN
            IF dbo.fnPuedeConsultarOrden(@Tec1, @OrdenID) <> 1 OR dbo.fnPuedeConsultarOrden(@Tec2, @OrdenID) <> 0
                THROW 51991, N'La asignación no limitó la consulta al técnico correcto.', 1;
            DELETE #OrdenResultado;
            INSERT #OrdenResultado EXEC dbo.spListarOrdenes @Tec1, @Nit;
            IF (SELECT COUNT(*) FROM #OrdenResultado WHERE OrdenID = @OrdenID) <> 1
                THROW 51991, N'El técnico no pudo listar su orden.', 1;
            DELETE #OrdenResultado;
            INSERT #OrdenResultado EXEC dbo.spListarOrdenes @Tec2, @Nit;
            IF EXISTS (SELECT 1 FROM #OrdenResultado) THROW 51991, N'El listado expuso una orden ajena.', 1;
        END;
        IF @Caso = 12
        BEGIN
            DELETE #OrdenResultado;
            INSERT #OrdenResultado EXEC dbo.spAsignarTecnicoOrden @Admin, @OrdenID, @Tec2, @Tec1, N'Reasignación ñ';
            IF dbo.fnPuedeConsultarOrden(@Tec1, @OrdenID) <> 0 OR dbo.fnPuedeConsultarOrden(@Tec2, @OrdenID) <> 1
                THROW 51991, N'La reasignación no cambió los permisos de consulta.', 1;
            IF (SELECT COUNT(*) FROM dbo.AsignacionOrden WHERE OrdenID = @OrdenID) <> 2
                THROW 51991, N'La reasignación no conservó ambos eventos.', 1;
        END;
        IF @Caso BETWEEN 13 AND 15
        BEGIN
            SET @Destino = @Tec1;
            IF @Caso = 13 SET @Destino = @Otro;
            IF @Caso = 14 UPDATE dbo.Usuario SET Activo = 0 WHERE UsuarioID = @Tec1;
            IF @Caso = 15 UPDATE dbo.Empleado SET Activo = 0 WHERE EmpleadoID = @Emp1;
            EXEC dbo.spAsignarTecnicoOrden @Admin, @OrdenID, @Destino;
        END;
        IF @Caso = 16 EXEC dbo.spAsignarTecnicoOrden @Admin, @OrdenID, @Tec2, NULL;
        IF @Caso = 17 EXEC dbo.spAsignarTecnicoOrden @Admin, @OrdenID, @Tec1, @Tec1;
        IF @Caso = 18 EXEC dbo.spAsignarTecnicoOrden @Tec1, @OrdenID, @Tec1;
        IF @Caso = 19 EXEC dbo.spConsultarOrden @Tec2, @OrdenID;
        IF @Caso = 20 EXEC dbo.spHistorialOrden @Tec2, @OrdenID;
        IF @Caso = 21
        BEGIN
            INSERT dbo.UsuarioRol VALUES (@Otro, 'CAJA');
            INSERT #OrdenResultado EXEC dbo.spConsultarOrden @Otro, @OrdenID;
            IF NOT EXISTS (SELECT 1 FROM #OrdenResultado WHERE OrdenID = @OrdenID) THROW 51991, N'CAJA no pudo consultar la orden.', 1;
        END;
        IF @Caso IN (22,24,25)
        BEGIN
            DELETE #OrdenResultado;
            INSERT #OrdenResultado EXEC dbo.spCancelarOrden @Admin, @OrdenID, N'Cliente José solicita cancelación ñ 漢字';
        END;
        IF @Caso = 22
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.OrdenServicio WHERE OrdenID = @OrdenID AND EstadoCodigo = 'CANCELADO')
                OR (SELECT COUNT(*) FROM dbo.HistorialEstadoOrden WHERE OrdenID = @OrdenID) <> 2
                OR NOT EXISTS (SELECT 1 FROM dbo.HistorialEstadoOrden WHERE OrdenID = @OrdenID AND EstadoNuevo = 'CANCELADO'
                               AND Observacion = N'Cliente José solicita cancelación ñ 漢字')
                THROW 51991, N'La cancelación perdió la orden, el historial o su motivo.', 1;
        END;
        IF @Caso = 23 EXEC dbo.spCancelarOrden @Admin, @OrdenID, N'  ';
        IF @Caso = 24 EXEC dbo.spCancelarOrden @Admin, @OrdenID, N'Otra vez';
        IF @Caso = 25 EXEC dbo.spAsignarTecnicoOrden @Admin, @OrdenID, @Tec1;
        IF @Caso = 26
        BEGIN
            EXEC dbo.spRegistrarDiagnostico @OrdenID, @Tec1, N'Diagnóstico de prueba', 1, @D OUTPUT;
            EXEC dbo.spAsignarTecnicoOrden @Admin, @OrdenID, @Tec2, @Tec1;
        END;
        IF @Caso = 27
        BEGIN
            INSERT #OrdenResultado EXEC dbo.spListarOrdenes @Admin, @NombreCliente;
            IF (SELECT COUNT(*) FROM #OrdenResultado) <> 1 OR NOT EXISTS (SELECT 1 FROM #OrdenResultado WHERE OrdenID = @OrdenID)
                THROW 51991, N'La búsqueda no trató el porcentaje y el guion bajo como texto literal.', 1;
        END;
        IF @Caso = 28
        BEGIN
            INSERT #HistorialEquipo EXEC dbo.spHistorialEquipoAcceso @Tec2, @EquipoID;
            IF EXISTS (SELECT 1 FROM #HistorialEquipo) THROW 51991, N'Equipos expuso una orden ajena.', 1;
            INSERT #HistorialEquipo EXEC dbo.spHistorialEquipoAcceso @Tec1, @EquipoID;
            IF (SELECT COUNT(*) FROM #HistorialEquipo WHERE OrdenID = @OrdenID) <> 1 THROW 51991, N'Equipos ocultó la orden del técnico asignado.', 1;
        END;
        IF @Caso = 29 EXEC dbo.spConsultarOrden @Admin, 0;
        IF @Caso = 30 UPDATE dbo.AsignacionOrden SET Observacion = N'Intento de reescritura' WHERE OrdenID = @OrdenID;
        IF @Esperado <> 0 THROW 51991, N'La operación debía rechazarse y fue aceptada.', 1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Detalle = ERROR_MESSAGE();
        IF @Esperado = 0 OR ERROR_NUMBER() <> @Esperado OR @Detalle <> @Mensaje SET @Resultado = 'FAIL';
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    END CATCH;
    IF (SELECT COUNT_BIG(*) FROM dbo.OrdenServicio) <> @Ordenes
       OR (SELECT COUNT_BIG(*) FROM dbo.HistorialEstadoOrden) <> @Historial
       OR (SELECT COUNT_BIG(*) FROM dbo.AsignacionOrden) <> @Asignaciones
       OR (SELECT COUNT_BIG(*) FROM dbo.Cliente) <> @Clientes OR (SELECT COUNT_BIG(*) FROM dbo.Equipo) <> @Equipos
       OR (SELECT COUNT_BIG(*) FROM dbo.Usuario) <> @Usuarios OR (SELECT COUNT_BIG(*) FROM dbo.Empleado) <> @Empleados
       OR (SELECT COUNT_BIG(*) FROM dbo.UsuarioRol) <> @Roles OR (SELECT COUNT_BIG(*) FROM dbo.Diagnostico) <> @Diagnosticos
    BEGIN
        SET @Resultado = 'FAIL'; SET @Detalle = N'La prueba dejó cambios persistentes. Revisá las transacciones.';
    END;
    INSERT @Resultados VALUES (@Caso, @Nombre, @Resultado, @Detalle);
    SET @Caso += 1;
END;
DROP TABLE #OrdenResultado;
DROP TABLE #HistorialEquipo;
SELECT Caso, Resultado, Detalle FROM @Resultados ORDER BY ID;
IF EXISTS (SELECT 1 FROM @Resultados WHERE Resultado = 'FAIL')
    THROW 51992, N'Una o más pruebas de Órdenes fallaron. Revisá la tabla de resultados.', 1;
GO
