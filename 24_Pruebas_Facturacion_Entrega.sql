-- Ejecutar después del 23 en DESARROLLO, sin escrituras concurrentes.
-- Cada caso crea sus datos y hace ROLLBACK; no utiliza órdenes reales.
-- Identidades y secuencia pueden dejar huecos. No es prueba entre sesiones concurrentes.
USE [TechCare];
GO
SET NOCOUNT ON; SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 51890, N'Ejecutá sin una transacción abierta.', 1;
IF OBJECT_ID(N'dbo.spAbonarFacturaOrden', N'P') IS NULL
    THROW 51890, N'Ejecutá primero 23_Facturacion_Entrega_Procedimientos.sql.', 1;
DECLARE @Admin int = (SELECT TOP (1) UsuarioID FROM dbo.Usuario WHERE dbo.fnTieneRol(UsuarioID,'ADMIN') = 1 ORDER BY UsuarioID);
DECLARE @Modelo int = (SELECT TOP (1) ModeloEquipoID FROM dbo.ModeloEquipo ORDER BY ModeloEquipoID);
DECLARE @Tipo int = (SELECT TOP (1) TipoClienteID FROM dbo.TipoCliente ORDER BY TipoClienteID);
DECLARE @Metodo int = (SELECT TOP (1) MetodoPagoID FROM dbo.MetodoPago ORDER BY MetodoPagoID);
IF @Admin IS NULL OR @Modelo IS NULL OR @Tipo IS NULL OR @Metodo IS NULL
    THROW 51890, N'Se requiere ADMIN activo y catálogos de cliente, equipo y pago.', 1;
DECLARE @Casos TABLE (ID int PRIMARY KEY, Caso nvarchar(200), ErrorEsperado int);
INSERT @Casos VALUES
(1, N'Orden no terminada no se factura', 51803),
(2, N'Vista previa detalla cantidades, precio e impuesto', 0),
(3, N'Tasa mayor que uno rechazada', 51800),
(4, N'Tasa con cinco decimales rechazada', 51800),
(5, N'Técnico no emite factura', 51804),
(6, N'Recepción no emite factura', 51804),
(7, N'Datos fiscales cambiados exigen revisar otra vez', 51803),
(8, N'Emisión conserva responsables y no vuelve a consumir stock', 0),
(9, N'Una sola factura por orden', 51803),
(10, N'Servicio sin cargo permite entregar sin pago ficticio', 0),
(11, N'Abono parcial actualiza pagado y saldo', 0),
(12, N'Reintentar la misma solicitud no duplica el abono', 0),
(13, N'Reutilizar solicitud con otro importe se rechaza', 51803),
(14, N'Sobrepago rechazado', 51803),
(15, N'Monto cero rechazado', 51800),
(16, N'Monto negativo rechazado', 51800),
(17, N'Monto con tres decimales rechazado', 51800),
(18, N'Medio de pago inexistente rechazado', 51800),
(19, N'Saldo desactualizado exige nueva confirmación', 51803),
(20, N'Técnico no cobra', 51804),
(21, N'Recepción no cobra', 51804),
(22, N'Dos abonos cancelan la factura sin multiplicar los detalles', 0),
(23, N'Sin factura no se entrega', 51041),
(24, N'Factura pendiente impide entregar', 51041),
(25, N'Caja no sustituye a recepción en la entrega', 51804),
(26, N'Entrega conserva receptor Unicode, responsable e historial', 0),
(27, N'No se entrega dos veces', 51040),
(28, N'Receptor obligatorio', 51800),
(29, N'Nombre de receptor largo no se trunca', 51800),
(30, N'Observación de entrega larga no se trunca', 51800),
(31, N'Cambiar catálogo y cliente no reescribe la factura', 0),
(32, N'Pago histórico no se modifica', 51140),
(33, N'Datos fiscales históricos no se modifican', 51127),
(34, N'Técnico ajeno no consulta factura', 51802),
(35, N'Técnico asignado consulta su factura', 0),
(36, N'Usuario de caja inactivo rechazado', 51804),
(37, N'Otra persona no reutiliza la misma solicitud de pago', 51803),
(38, N'Factura pagada rechaza otro abono', 51803),
(39, N'Documento de receptor largo no se trunca', 51800),
(40, N'Referencia de pago larga no se trunca', 51800);
DECLARE @Antes TABLE (Nombre sysname PRIMARY KEY, Cantidad bigint);
INSERT @Antes
SELECT 'OrdenServicio' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.OrdenServicio UNION ALL
SELECT 'Diagnostico' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Diagnostico UNION ALL
SELECT 'Reparacion' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Reparacion UNION ALL
SELECT 'ReparacionActividad' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.ReparacionActividad UNION ALL
SELECT 'ReparacionRepuesto' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.ReparacionRepuesto UNION ALL
SELECT 'MovimientoInventario' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.MovimientoInventario UNION ALL
SELECT 'HistorialEstadoOrden' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.HistorialEstadoOrden UNION ALL
SELECT 'AsignacionOrden' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.AsignacionOrden UNION ALL
SELECT 'Cliente' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Cliente UNION ALL
SELECT 'Equipo' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Equipo UNION ALL
SELECT 'Usuario' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Usuario UNION ALL
SELECT 'Empleado' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Empleado UNION ALL
SELECT 'UsuarioRol' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.UsuarioRol UNION ALL
SELECT 'CategoriaRepuesto' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.CategoriaRepuesto UNION ALL
SELECT 'Repuesto' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Repuesto UNION ALL
SELECT 'Bodega' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Bodega UNION ALL
SELECT 'Inventario' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Inventario UNION ALL
SELECT 'Proveedor' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Proveedor UNION ALL
SELECT 'ProveedorRepuesto' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.ProveedorRepuesto UNION ALL
SELECT 'Compra' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Compra UNION ALL
SELECT 'DetalleCompra' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.DetalleCompra UNION ALL
SELECT 'Actividad' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Actividad UNION ALL
SELECT 'AuditoriaPrecioRepuesto' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.AuditoriaPrecioRepuesto UNION ALL
SELECT 'Factura' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Factura UNION ALL
SELECT 'FacturaDetalle' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.FacturaDetalle UNION ALL
SELECT 'Pago' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Pago UNION ALL
SELECT 'Entrega' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Entrega UNION ALL
SELECT 'SolicitudPagoApi' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.SolicitudPagoApi;
SELECT TOP (0) * INTO #ResultadoOrden FROM dbo.vOrdenAcceso;
SELECT TOP (0) * INTO #Factura FROM dbo.vFacturaApi;
SELECT TOP (0) v.OrdenID, v.NumeroOrden, v.NITFacturacion, v.NombreFacturacion, v.DireccionFacturacion,
    CONVERT(decimal(5,4),0) AS TasaImpuesto, v.Subtotal,
    CONVERT(decimal(18,2),0) AS Impuesto, CONVERT(decimal(18,2),0) AS Total,
    CONVERT(varchar(64),'') AS Revision, l.Linea,l.TipoConcepto,l.Concepto,l.Cantidad,l.PrecioUnitario,l.Importe
INTO #Previa FROM dbo.vPreFacturaApi v JOIN dbo.vDetallePreFacturaApi l ON l.OrdenID=v.OrdenID;
SELECT TOP (0) en.OrdenID,en.Fecha,en.NombreRecibe,en.DocumentoRecibe,en.Observaciones,
    e.Nombres+N' '+e.Apellidos AS EntregadaPor
INTO #Entrega FROM dbo.Entrega en JOIN dbo.Usuario u ON u.UsuarioID=en.UsuarioEntregaID JOIN dbo.Empleado e ON e.EmpleadoID=u.EmpleadoID;
DECLARE @Resultados TABLE (ID int, Caso nvarchar(200), Resultado varchar(4), Detalle nvarchar(4000));
DECLARE @Caso int=1,@Esperado int,@Nombre nvarchar(200),@Resultado varchar(4),@Detalle nvarchar(4000),@Preparado bit;
DECLARE @Sufijo varchar(8),@Codigo varchar(30),@Usuario varchar(50),@Nit varchar(20),@Serie varchar(80),@Texto nvarchar(max);
DECLARE @Cliente int,@Equipo int,@Empleado int,@Tec1 int,@Tec2 int,@Recepcion int,@Caja int,@Orden int,
    @Categoria int,@Repuesto int,@Bodega int,@Proveedor int,@Compra int,@Actividad int,@Reparacion int,@FacturaID int;
DECLARE @Revision varchar(64),@Solicitud uniqueidentifier,@MO decimal(12,2),@Movimientos bigint;
DECLARE @Lineas dbo.TipoDetalleCompra;
DECLARE @Hash varchar(255)='$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik=';
WHILE @Caso<=40
BEGIN
    SELECT @Nombre=Caso,@Esperado=ErrorEsperado FROM @Casos WHERE ID=@Caso;
    SET @Resultado='PASS'; SET @Detalle=NULL; SET @Preparado=0;
    SET @Sufijo=LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),8);
    SET @Solicitud=NEWID(); SET @FacturaID=NULL; SET @Revision=REPLICATE('A',64);
    DELETE FROM #ResultadoOrden; DELETE FROM #Factura; DELETE FROM #Previa; DELETE FROM #Entrega; DELETE FROM @Lineas;
    BEGIN TRY
        BEGIN TRANSACTION;
        SET @Nit = 'TCF-C-' + @Sufijo; SET @Serie = 'TCF-E-' + @Sufijo;
        INSERT dbo.Cliente(TipoClienteID, NIT, Nombre, Activo) VALUES (@Tipo, @Nit, N'Cliente de prueba de caja', 1);
        SET @Cliente = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Equipo(ClienteID, ModeloEquipoID, NumeroSerie, Descripcion, Activo)
            VALUES (@Cliente, @Modelo, @Serie, N'Equipo de prueba de caja', 1);
        SET @Equipo = CONVERT(int, SCOPE_IDENTITY());

        SET @Codigo = 'TCFT1-' + @Sufijo; SET @Usuario = 'tcst1_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Técnico', N'Uno', 1);
        SET @Empleado = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Empleado, @Usuario, @Hash, 1);
        SET @Tec1 = CONVERT(int, SCOPE_IDENTITY());
        SET @Codigo = 'TCFT2-' + @Sufijo; SET @Usuario = 'tcst2_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Técnico', N'Dos', 1);
        SET @Empleado = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Empleado, @Usuario, @Hash, 1);
        SET @Tec2 = CONVERT(int, SCOPE_IDENTITY());
        SET @Codigo = 'TCFR-' + @Sufijo; SET @Usuario = 'tcsr_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Recepción', N'Prueba', 1);
        SET @Empleado = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Empleado, @Usuario, @Hash, 1);
        SET @Recepcion = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.UsuarioRol VALUES (@Tec1, 'TECNICO'), (@Tec2, 'TECNICO'), (@Recepcion, 'RECEPCION');

        SET @Codigo = 'TCF-' + @Sufijo;
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
        SET @Nit = 'TCF-P-' + @Sufijo;
        INSERT dbo.Proveedor(NIT, Nombre, Activo) VALUES (@Nit, N'Proveedor de prueba de caja', 1);
        SET @Proveedor = CONVERT(int, SCOPE_IDENTITY());
        -- El detalle de compra exige que el proveedor ofrezca este repuesto.
        INSERT dbo.ProveedorRepuesto(ProveedorID, RepuestoID) VALUES (@Proveedor, @Repuesto);
        INSERT @Lineas VALUES (1, @Bodega, @Repuesto, 10, 12.25);
        EXEC dbo.spRegistrarCompra @Codigo, @Proveedor, @Admin, @Lineas, @Compra OUTPUT;
        EXEC dbo.spRecibirCompra @Compra, @Admin;
        SET @Texto = N'Prueba con carga ' + @Sufijo;
        INSERT dbo.Actividad(Nombre, Activo) VALUES (@Texto, 1);
        SET @Actividad = CONVERT(int, SCOPE_IDENTITY());
        SET @Codigo='TCFC-'+@Sufijo; SET @Usuario='tcfc_'+@Sufijo;
        INSERT dbo.Empleado(Codigo,Nombres,Apellidos,Activo) VALUES (@Codigo,N'Caja',N'Prueba',1);
        SET @Empleado=CONVERT(int,SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID,NombreUsuario,PasswordHash,Activo) VALUES (@Empleado,@Usuario,@Hash,1);
        SET @Caja=CONVERT(int,SCOPE_IDENTITY());
        INSERT dbo.UsuarioRol VALUES (@Caja,'CAJA');
        IF @Caso<>1
        BEGIN
            SET @MO=CASE WHEN @Caso=10 THEN 0 ELSE 100 END;
            INSERT #ResultadoOrden EXEC dbo.spRegistrarDiagnosticoOrden @Tec1,@Orden,N'Revisión de alimentación ñ',@MO;
            INSERT #ResultadoOrden EXEC dbo.spIniciarReparacionOrden @Tec1,@Orden,N'Reemplazar fuente y verificar encendido',@MO,N'María autorizó por teléfono';
            IF @Caso<>10 INSERT #ResultadoOrden EXEC dbo.spUsarRepuestoOrden @Tec1,@Orden,@Bodega,@Repuesto,2,25.50;
            INSERT #ResultadoOrden EXEC dbo.spFinalizarReparacionOrden @Tec1,@Orden;
            INSERT #Previa EXEC dbo.spPreviaFacturaOrden @Caja,@Orden,0.12;
            SELECT TOP (1) @Revision=Revision FROM #Previa;
        END;
        SELECT @Movimientos=COUNT_BIG(*) FROM dbo.MovimientoInventario;
        IF @Caso NOT IN (1,2,3,4,5,6,7,8,23)
        BEGIN
            INSERT #Factura EXEC dbo.spEmitirFacturaOrden @Caja,@Orden,0.12,@Revision;
            SELECT @FacturaID=FacturaID FROM #Factura;
        END;
        IF @Caso IN (25,26,27,38)
            INSERT #Factura EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,169.12,169.12,N'Cancelación total';
        SET @Preparado=1;

        IF @Caso=1 EXEC dbo.spEmitirFacturaOrden @Caja,@Orden,0.12,@Revision;
        IF @Caso=2
        BEGIN
            IF (SELECT COUNT(*) FROM #Previa)<>2
               OR NOT EXISTS (SELECT 1 FROM #Previa WHERE TipoConcepto='REP' AND Cantidad=2 AND PrecioUnitario=25.50 AND Importe=51.00)
               OR NOT EXISTS (SELECT 1 FROM #Previa WHERE Subtotal=151.00 AND Impuesto=18.12 AND Total=169.12)
                THROW 51891,N'La vista previa no coincide con los conceptos y el impuesto.',1;
        END;
        IF @Caso=3 EXEC dbo.spPreviaFacturaOrden @Caja,@Orden,1.1;
        IF @Caso=4 EXEC dbo.spPreviaFacturaOrden @Caja,@Orden,0.12345;
        IF @Caso=5 EXEC dbo.spEmitirFacturaOrden @Tec1,@Orden,0.12,@Revision;
        IF @Caso=6 EXEC dbo.spEmitirFacturaOrden @Recepcion,@Orden,0.12,@Revision;
        IF @Caso=7
        BEGIN
            UPDATE dbo.Cliente SET Nombre=N'Cliente modificado' WHERE ClienteID=@Cliente;
            EXEC dbo.spEmitirFacturaOrden @Caja,@Orden,0.12,@Revision;
        END;
        IF @Caso=8
        BEGIN
            INSERT #Factura EXEC dbo.spEmitirFacturaOrden @Caja,@Orden,0.12,@Revision;
            IF NOT EXISTS (SELECT 1 FROM #Factura WHERE Total=169.12 AND Tecnico=N'Técnico Uno' AND Recepcionista IS NOT NULL AND EmitidaPor=N'Caja Prueba')
               OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos
                THROW 51891,N'La factura no conservó responsables/importes o alteró el inventario.',1;
        END;
        IF @Caso=9 EXEC dbo.spEmitirFacturaOrden @Caja,@Orden,0.12,@Revision;
        IF @Caso=10
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM #Factura WHERE Total=0 AND Saldo=0 AND EstadoPago='PAGADA')
                THROW 51891,N'El servicio sin cargo debe quedar pagado con saldo cero.',1;
            INSERT #Entrega EXEC dbo.spRegistrarEntregaOrden @Recepcion,@Orden,N'María José ñ',N'1234-5',N'Servicio sin cargo';
            IF EXISTS (SELECT 1 FROM dbo.Pago WHERE FacturaID=@FacturaID)
                THROW 51891,N'Se creó un pago ficticio para una factura en cero.',1;
        END;
        IF @Caso=11
        BEGIN
            INSERT #Factura EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,25.50,169.12,N'Abono ñ';
            IF NOT EXISTS (SELECT 1 FROM dbo.vFacturaSaldo WHERE FacturaID=@FacturaID AND Pagado=25.50 AND Saldo=143.62 AND EstadoPago='PARCIAL')
                THROW 51891,N'El abono parcial no actualizó el saldo.',1;
        END;
        IF @Caso IN (12,13,37)
        BEGIN
            INSERT #Factura EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,25.50,169.12,N'Abono ñ';
            IF @Caso=12
            BEGIN
                INSERT #Factura EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,25.50,169.12,N'Abono ñ';
                IF (SELECT COUNT(*) FROM dbo.Pago WHERE FacturaID=@FacturaID)<>1
                   OR (SELECT COUNT(*) FROM dbo.SolicitudPagoApi WHERE SolicitudID=@Solicitud)<>1
                   OR dbo.fnSaldoFactura(@FacturaID)<>143.62
                    THROW 51891,N'El reintento duplicó el pago o su solicitud.',1;
            END;
            IF @Caso=13 EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,26.50,169.12,N'Abono ñ';
            IF @Caso=37 EXEC dbo.spAbonarFacturaOrden @Admin,@Orden,@Solicitud,@Metodo,25.50,169.12,N'Abono ñ';
        END;
        IF @Caso=14 EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,170,169.12;
        IF @Caso=15 EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,0,169.12;
        IF @Caso=16 EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,-1,169.12;
        IF @Caso=17 EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,1.234,169.12;
        IF @Caso=18 EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,-1,1,169.12;
        IF @Caso=19 EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,1,160;
        IF @Caso=20 EXEC dbo.spAbonarFacturaOrden @Tec1,@Orden,@Solicitud,@Metodo,1,169.12;
        IF @Caso=21 EXEC dbo.spAbonarFacturaOrden @Recepcion,@Orden,@Solicitud,@Metodo,1,169.12;
        IF @Caso=22
        BEGIN
            INSERT #Factura EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,25.50,169.12;
            SET @Solicitud=NEWID();
            INSERT #Factura EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,143.62,143.62;
            IF NOT EXISTS (SELECT 1 FROM dbo.vFacturaSaldo WHERE FacturaID=@FacturaID AND Total=169.12 AND Pagado=169.12 AND Saldo=0 AND EstadoPago='PAGADA')
                THROW 51891,N'Los dos pagos no cancelaron la factura correctamente.',1;
        END;
        IF @Caso IN (23,24) EXEC dbo.spRegistrarEntregaOrden @Recepcion,@Orden,N'María José ñ';
        IF @Caso=25 EXEC dbo.spRegistrarEntregaOrden @Caja,@Orden,N'María José ñ';
        IF @Caso IN (26,27)
        BEGIN
            INSERT #Entrega EXEC dbo.spRegistrarEntregaOrden @Recepcion,@Orden,N'María José ñ',N'1234-5',N'Probado y recibido ñ';
            IF NOT EXISTS (SELECT 1 FROM dbo.OrdenServicio WHERE OrdenID=@Orden AND EstadoCodigo='ENTREGADO')
               OR NOT EXISTS (SELECT 1 FROM dbo.Entrega WHERE OrdenID=@Orden AND NombreRecibe=N'María José ñ' AND UsuarioEntregaID=@Recepcion)
               OR NOT EXISTS (SELECT 1 FROM dbo.HistorialEstadoOrden WHERE OrdenID=@Orden AND EstadoNuevo='ENTREGADO' AND UsuarioID=@Recepcion)
                THROW 51891,N'La entrega no conservó receptor, responsable e historial.',1;
            IF @Caso=27 EXEC dbo.spRegistrarEntregaOrden @Recepcion,@Orden,N'Segundo receptor';
        END;
        IF @Caso=28 EXEC dbo.spRegistrarEntregaOrden @Recepcion,@Orden,N'  ';
        IF @Caso=29
        BEGIN
            SET @Texto=REPLICATE(N'a',151);
            EXEC dbo.spRegistrarEntregaOrden @Recepcion,@Orden,@Texto;
        END;
        IF @Caso=30
        BEGIN
            SET @Texto=REPLICATE(N'a',1001);
            EXEC dbo.spRegistrarEntregaOrden @Recepcion,@Orden,N'María',NULL,@Texto;
        END;
        IF @Caso=31
        BEGIN
            UPDATE dbo.Repuesto SET PrecioVenta=99.99,Nombre=N'Otro nombre' WHERE RepuestoID=@Repuesto;
            UPDATE dbo.Cliente SET Nombre=N'Otro cliente',NIT='OTRO-'+@Sufijo WHERE ClienteID=@Cliente;
            IF NOT EXISTS (SELECT 1 FROM dbo.FacturaDetalle WHERE FacturaID=@FacturaID AND TipoConcepto='REP' AND PrecioUnitario=25.50 AND Concepto=N'Fuente de prueba ñ')
               OR NOT EXISTS (SELECT 1 FROM dbo.Factura WHERE FacturaID=@FacturaID AND NombreFacturacion=N'Cliente de prueba de caja')
                THROW 51891,N'El catálogo o cliente cambiaron la factura histórica.',1;
        END;
        IF @Caso=32
        BEGIN
            INSERT #Factura EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,1,169.12;
            UPDATE dbo.Pago SET Monto=2 WHERE FacturaID=@FacturaID;
        END;
        IF @Caso=33 UPDATE dbo.Factura SET NITFacturacion='OTRO' WHERE FacturaID=@FacturaID;
        IF @Caso=34 EXEC dbo.spConsultarFacturaOrden @Tec2,@Orden;
        IF @Caso=35
        BEGIN
            DELETE FROM #Factura;
            INSERT #Factura EXEC dbo.spConsultarFacturaOrden @Tec1,@Orden;
            IF NOT EXISTS (SELECT 1 FROM #Factura WHERE FacturaID=@FacturaID) THROW 51891,N'El técnico asignado no pudo consultar su factura.',1;
        END;
        IF @Caso=36
        BEGIN
            UPDATE dbo.Usuario SET Activo=0 WHERE UsuarioID=@Caja;
            EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,1,169.12;
        END;
        IF @Caso=38
        BEGIN
            SET @Solicitud=NEWID();
            EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,1,0;
        END;
        IF @Caso=39
        BEGIN
            SET @Texto=REPLICATE(N'1',31);
            EXEC dbo.spRegistrarEntregaOrden @Recepcion,@Orden,N'María',@Texto;
        END;
        IF @Caso=40
        BEGIN
            SET @Texto=REPLICATE(N'a',101);
            EXEC dbo.spAbonarFacturaOrden @Caja,@Orden,@Solicitud,@Metodo,1,169.12,@Texto;
        END;
        IF @Esperado<>0 THROW 51891,N'La operación debía rechazarse y fue aceptada.',1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Detalle=ERROR_MESSAGE();
        IF @Preparado=0 OR @Esperado=0 OR ERROR_NUMBER()<>@Esperado SET @Resultado='FAIL';
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    END CATCH;
    ;WITH Despues AS (
SELECT 'OrdenServicio' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.OrdenServicio UNION ALL
SELECT 'Diagnostico' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Diagnostico UNION ALL
SELECT 'Reparacion' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Reparacion UNION ALL
SELECT 'ReparacionActividad' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.ReparacionActividad UNION ALL
SELECT 'ReparacionRepuesto' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.ReparacionRepuesto UNION ALL
SELECT 'MovimientoInventario' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.MovimientoInventario UNION ALL
SELECT 'HistorialEstadoOrden' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.HistorialEstadoOrden UNION ALL
SELECT 'AsignacionOrden' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.AsignacionOrden UNION ALL
SELECT 'Cliente' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Cliente UNION ALL
SELECT 'Equipo' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Equipo UNION ALL
SELECT 'Usuario' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Usuario UNION ALL
SELECT 'Empleado' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Empleado UNION ALL
SELECT 'UsuarioRol' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.UsuarioRol UNION ALL
SELECT 'CategoriaRepuesto' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.CategoriaRepuesto UNION ALL
SELECT 'Repuesto' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Repuesto UNION ALL
SELECT 'Bodega' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Bodega UNION ALL
SELECT 'Inventario' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Inventario UNION ALL
SELECT 'Proveedor' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Proveedor UNION ALL
SELECT 'ProveedorRepuesto' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.ProveedorRepuesto UNION ALL
SELECT 'Compra' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Compra UNION ALL
SELECT 'DetalleCompra' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.DetalleCompra UNION ALL
SELECT 'Actividad' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Actividad UNION ALL
SELECT 'AuditoriaPrecioRepuesto' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.AuditoriaPrecioRepuesto UNION ALL
SELECT 'Factura' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Factura UNION ALL
SELECT 'FacturaDetalle' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.FacturaDetalle UNION ALL
SELECT 'Pago' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Pago UNION ALL
SELECT 'Entrega' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.Entrega UNION ALL
SELECT 'SolicitudPagoApi' AS Nombre, COUNT_BIG(*) AS Cantidad FROM dbo.SolicitudPagoApi
    )
    SELECT @Resultado=CASE WHEN EXISTS (SELECT 1 FROM Despues d JOIN @Antes a ON a.Nombre=d.Nombre WHERE a.Cantidad<>d.Cantidad)
        THEN 'FAIL' ELSE @Resultado END;
    IF @Resultado='FAIL' AND @Detalle IS NULL SET @Detalle=N'La prueba dejó cantidades persistentes distintas de las iniciales.';
    INSERT @Resultados VALUES (@Caso,@Nombre,@Resultado,@Detalle);
    SET @Caso+=1;
END;
DROP TABLE #ResultadoOrden; DROP TABLE #Factura; DROP TABLE #Previa; DROP TABLE #Entrega;
SELECT ID,Caso,Resultado,Detalle FROM @Resultados ORDER BY ID;
IF EXISTS (SELECT 1 FROM @Resultados WHERE Resultado='FAIL')
    THROW 51892,N'Una o más pruebas de facturación y entrega fallaron. Revisá los resultados.',1;
GO
