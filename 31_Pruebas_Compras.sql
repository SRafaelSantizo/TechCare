-- Ejecutar después del 30 en DESARROLLO, sin otras escrituras concurrentes.
-- Datos propios por caso, ROLLBACK y verificación de cantidades antes/después.
-- Las identidades pueden dejar huecos. No es prueba entre sesiones concurrentes.
USE [TechCare];
GO
SET NOCOUNT ON; SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 52090,N'Ejecutá sin una transacción abierta.',1;
IF OBJECT_ID(N'dbo.spRegistrarCompraApi',N'P') IS NULL
    THROW 52090,N'Ejecutá primero 30_Compras_Procedimientos.sql.',1;
DECLARE @Admin int=(SELECT TOP (1) UsuarioID FROM dbo.Usuario WHERE dbo.fnTieneRol(UsuarioID,'ADMIN')=1 ORDER BY UsuarioID);
DECLARE @Modelo int=(SELECT TOP (1) ModeloEquipoID FROM dbo.ModeloEquipo ORDER BY ModeloEquipoID);
DECLARE @Tipo int=(SELECT TOP (1) TipoClienteID FROM dbo.TipoCliente ORDER BY TipoClienteID);
IF @Admin IS NULL OR @Modelo IS NULL OR @Tipo IS NULL THROW 52090,N'Se requiere ADMIN activo y catálogos base.',1;
DECLARE @ContextoInicial sql_variant=SESSION_CONTEXT(N'UsuarioID');
DECLARE @Casos TABLE (ID int PRIMARY KEY,Caso nvarchar(200),ErrorEsperado int);
INSERT @Casos VALUES
(1,N'Registrar compra no cambia existencia ni promedio',0),
(2,N'Compra conserva observaciones Unicode y costos exactos',0),
(3,N'Reintentar solicitud no duplica compra ni detalle',0),
(4,N'Reutilizar solicitud con otro costo se rechaza',52103),
(5,N'Otra persona no reutiliza la solicitud',52103),
(6,N'Número de compra repetido se rechaza',2627),
(7,N'Cantidad negativa rechazada',52100),
(8,N'Cantidad cero rechazada',52100),
(9,N'Cantidad fraccionaria rechazada',52100),
(10,N'Costo negativo rechazado',52100),
(11,N'Costo con tres decimales rechazado',52100),
(12,N'Costo fuera de límite rechazado',52100),
(13,N'Detalle vacío rechazado',52100),
(14,N'Par repuesto y bodega repetido rechazado',52100),
(15,N'Proveedor inexistente rechazado',52101),
(16,N'Repuesto no ofrecido rechazado',52101),
(17,N'Destino no asociado rechazado',52101),
(18,N'Proveedor inactivo no registra compra',52101),
(19,N'Repuesto inactivo no registra compra',52101),
(20,N'Bodega inactiva no registra compra',52101),
(21,N'Técnico no recibe compras',52004),
(22,N'Recepción no consulta compras',52004),
(23,N'Caja no anula compras',52004),
(24,N'Usuario de bodega inactivo rechazado',52004),
(25,N'ADMIN consulta compras',0),
(26,N'Recepción genera stock, promedio y responsable',0),
(27,N'Una compra no se recibe dos veces',52103),
(28,N'Anulación conserva observaciones y no mueve stock',0),
(29,N'Una compra recibida no se anula',52103),
(30,N'Una compra anulada no se recibe',52103),
(31,N'Recepción desactualizada rechazada',52103),
(32,N'Anulación desactualizada rechazada',52103),
(33,N'Motivo de anulación obligatorio',52100),
(34,N'Motivo largo rechazado sin truncar',52100),
(35,N'Costo de catálogo deja de ser editable',52000),
(36,N'Nuevo repuesto no recibe un costo manual',52000),
(37,N'Un repuesto conserva promedios distintos por bodega',0),
(38,N'Consumo utiliza el promedio de su bodega',0),
(39,N'Salida parcial conserva promedio y valoración histórica',0),
(40,N'Agotar existencias deja promedio en cero',0),
(41,N'Reponer después de agotar usa el nuevo costo',0),
(42,N'Nueva compra no reescribe consumo ni factura',0),
(43,N'Promedio usa existencia remanente y no total comprado',0),
(44,N'Dos proveedores abastecen el mismo repuesto',0),
(45,N'Compra sin cargo actualiza promedio correctamente',0),
(46,N'Valoración histórica no se modifica',52105),
(47,N'Solicitud histórica no se borra',52105),
(48,N'Responsables históricos no se modifican',52105),
(49,N'Recepción de varias bodegas revierte completa ante error',51030),
(50,N'Consulta de costos conserva seis decimales',0),
(51,N'Destino nuevo sin entradas tiene costo cero',0),
(52,N'JSON inválido rechazado',52100),
(53,N'Número de compra largo rechazado sin truncar',52100),
(54,N'Solicitud inválida rechazada',52100),
(55,N'Observaciones largas rechazadas sin truncar',52100),
(56,N'Recepción no altera precio de venta',0),
(57,N'Detalle histórico de compra no se modifica',51140),
(58,N'Consulta inexistente devuelve error controlado',52102),
(59,N'Rango de fechas invertido rechazado',52100),
(60,N'Costo máximo conserva centavos en compra y promedio',0);
DECLARE @Antes TABLE (Nombre sysname PRIMARY KEY,Cantidad bigint);
INSERT @Antes
SELECT 'OrdenServicio' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.OrdenServicio UNION ALL
SELECT 'Diagnostico' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Diagnostico UNION ALL
SELECT 'Reparacion' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Reparacion UNION ALL
SELECT 'ReparacionActividad' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.ReparacionActividad UNION ALL
SELECT 'ReparacionRepuesto' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.ReparacionRepuesto UNION ALL
SELECT 'MovimientoInventario' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.MovimientoInventario UNION ALL
SELECT 'HistorialEstadoOrden' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.HistorialEstadoOrden UNION ALL
SELECT 'AsignacionOrden' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.AsignacionOrden UNION ALL
SELECT 'Cliente' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Cliente UNION ALL
SELECT 'Equipo' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Equipo UNION ALL
SELECT 'Usuario' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Usuario UNION ALL
SELECT 'Empleado' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Empleado UNION ALL
SELECT 'UsuarioRol' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.UsuarioRol UNION ALL
SELECT 'CategoriaRepuesto' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.CategoriaRepuesto UNION ALL
SELECT 'Repuesto' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Repuesto UNION ALL
SELECT 'Bodega' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Bodega UNION ALL
SELECT 'Inventario' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Inventario UNION ALL
SELECT 'Proveedor' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Proveedor UNION ALL
SELECT 'ProveedorRepuesto' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.ProveedorRepuesto UNION ALL
SELECT 'Compra' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Compra UNION ALL
SELECT 'DetalleCompra' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.DetalleCompra UNION ALL
SELECT 'Actividad' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Actividad UNION ALL
SELECT 'AuditoriaPrecioRepuesto' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.AuditoriaPrecioRepuesto UNION ALL
SELECT 'Factura' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Factura UNION ALL
SELECT 'FacturaDetalle' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.FacturaDetalle UNION ALL
SELECT 'Pago' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Pago UNION ALL
SELECT 'Entrega' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Entrega UNION ALL
SELECT 'SolicitudPagoApi' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.SolicitudPagoApi UNION ALL
SELECT 'ValoracionInventario',COUNT_BIG(*) FROM dbo.ValoracionInventario UNION ALL
SELECT 'SolicitudCompraApi',COUNT_BIG(*) FROM dbo.SolicitudCompraApi UNION ALL
SELECT 'EventoCompraApi',COUNT_BIG(*) FROM dbo.EventoCompraApi;
SELECT TOP (0) * INTO #ResultadoOrden FROM dbo.vOrdenAcceso;
SELECT TOP (0) * INTO #Repuestos FROM dbo.vRepuestoGestion;
-- La expresión +0 conserva el valor/tipo del ID sin copiar IDENTITY.
-- INSERT ... EXEC debe recibir también el ID devuelto por el procedimiento.
SELECT TOP (0) CategoriaID+0 AS CategoriaID,Nombre,Revision INTO #Categorias FROM dbo.vCategoriaRepuestoGestion;
SELECT TOP (0) ProveedorID+0 AS ProveedorID,NIT,Nombre,Email,Telefono,Direccion,Activo,Revision INTO #Proveedores FROM dbo.vProveedorGestion;
SELECT TOP (0) BodegaID+0 AS BodegaID,Codigo,Nombre,Direccion,Activo,Revision INTO #Bodegas FROM dbo.vBodegaGestion;
SELECT TOP (0) * INTO #Ofertas FROM dbo.vOfertaProveedorGestion;
SELECT TOP (0) * INTO #Minimos FROM dbo.vRepuestoBodegaGestion;
DECLARE @Resultados TABLE (ID int,Caso nvarchar(200),Resultado varchar(4),Detalle nvarchar(4000));
DECLARE @Caso int=1,@Esperado int,@Nombre nvarchar(200),@Resultado varchar(4),@Detalle nvarchar(4000),@Preparado bit;
DECLARE @Sufijo varchar(8),@Codigo varchar(30),@Usuario varchar(50),@Nit varchar(20),@Serie varchar(80),@Texto nvarchar(max);
DECLARE @Cliente int,@Equipo int,@Empleado int,@Tec1 int,@Tec2 int,@Recepcion int,@Orden int,@Categoria int,@Repuesto int,@Bodega int,@Proveedor int,@Compra int,@Actividad int,@Reparacion int;
DECLARE @Bodeguero int,@Caja int,@Extra int,@CompraPendiente int,@Factura int;
DECLARE @RevR varchar(64),@RevP varchar(64),@RevB varchar(64),@RevC varchar(64),@RevO varchar(64),@CodigoR varchar(30),@CodigoB varchar(20),@NitP varchar(20),@CategoriaNombre nvarchar(80),@ExtraCodigo varchar(30);
DECLARE @Movimientos bigint,@Inventarios bigint,@Auditorias bigint;
DECLARE @Lineas dbo.TipoDetalleCompra;
SELECT TOP (0) * INTO #Compras FROM dbo.vCompraApi;
DECLARE @Solicitud nvarchar(36),@OtraSolicitud nvarchar(36),@NumeroCompra nvarchar(max),@NumeroNuevo nvarchar(max),@Json nvarchar(max),@CompraNueva int,@RevisionNueva varchar(64),@Bodega2 int,@Proveedor2 int,@Consumo bigint;
DECLARE @Hash varchar(255)='$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik=';
WHILE @Caso<=60
BEGIN
    SELECT @Nombre=Caso,@Esperado=ErrorEsperado FROM @Casos WHERE ID=@Caso;
    SET @Resultado='PASS';SET @Detalle=NULL;SET @Preparado=0;
    SET @Sufijo=LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),8);
    DELETE FROM #Compras;DELETE FROM #ResultadoOrden;DELETE FROM #Repuestos;DELETE FROM #Categorias;DELETE FROM #Proveedores;
    DELETE FROM #Bodegas;DELETE FROM #Ofertas;DELETE FROM #Minimos;DELETE FROM @Lineas;
    BEGIN TRY
        BEGIN TRANSACTION;
        SET @Nit = 'TCAB-C-' + @Sufijo; SET @Serie = 'TCAB-E-' + @Sufijo;
        INSERT dbo.Cliente(TipoClienteID, NIT, Nombre, Activo) VALUES (@Tipo, @Nit, N'Cliente de prueba técnica', 1);
        SET @Cliente = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Equipo(ClienteID, ModeloEquipoID, NumeroSerie, Descripcion, Activo)
            VALUES (@Cliente, @Modelo, @Serie, N'Equipo de prueba técnica', 1);
        SET @Equipo = CONVERT(int, SCOPE_IDENTITY());

        SET @Codigo = 'TCABT1-' + @Sufijo; SET @Usuario = 'tcst1_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Técnico', N'Uno', 1);
        SET @Empleado = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Empleado, @Usuario, @Hash, 1);
        SET @Tec1 = CONVERT(int, SCOPE_IDENTITY());
        SET @Codigo = 'TCABT2-' + @Sufijo; SET @Usuario = 'tcst2_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Técnico', N'Dos', 1);
        SET @Empleado = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Empleado, @Usuario, @Hash, 1);
        SET @Tec2 = CONVERT(int, SCOPE_IDENTITY());
        SET @Codigo = 'TCABR-' + @Sufijo; SET @Usuario = 'tcsr_' + @Sufijo;
        INSERT dbo.Empleado(Codigo, Nombres, Apellidos, Activo) VALUES (@Codigo, N'Recepción', N'Prueba', 1);
        SET @Empleado = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID, NombreUsuario, PasswordHash, Activo) VALUES (@Empleado, @Usuario, @Hash, 1);
        SET @Recepcion = CONVERT(int, SCOPE_IDENTITY());
        INSERT dbo.UsuarioRol VALUES (@Tec1, 'TECNICO'), (@Tec2, 'TECNICO'), (@Recepcion, 'RECEPCION');

        SET @Codigo = 'TCAB-' + @Sufijo;
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
        SET @Nit = 'TCAB-P-' + @Sufijo;
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
        SET @Codigo='TCABG-'+@Sufijo;SET @Usuario='tcabg_'+@Sufijo;
        INSERT dbo.Empleado(Codigo,Nombres,Apellidos,Activo) VALUES (@Codigo,N'Bodega',N'Prueba',1);
        SET @Empleado=CONVERT(int,SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID,NombreUsuario,PasswordHash,Activo) VALUES (@Empleado,@Usuario,@Hash,1);
        SET @Bodeguero=CONVERT(int,SCOPE_IDENTITY());INSERT dbo.UsuarioRol VALUES (@Bodeguero,'BODEGA');
        SET @Codigo='TCABC-'+@Sufijo;SET @Usuario='tcabc_'+@Sufijo;
        INSERT dbo.Empleado(Codigo,Nombres,Apellidos,Activo) VALUES (@Codigo,N'Caja',N'Prueba',1);
        SET @Empleado=CONVERT(int,SCOPE_IDENTITY());
        INSERT dbo.Usuario(EmpleadoID,NombreUsuario,PasswordHash,Activo) VALUES (@Empleado,@Usuario,@Hash,1);
        SET @Caja=CONVERT(int,SCOPE_IDENTITY());INSERT dbo.UsuarioRol VALUES (@Caja,'CAJA');
        SET @ExtraCodigo='EXTRA-'+@Sufijo;
        INSERT dbo.Repuesto(CategoriaID,Codigo,Nombre,CostoReferencia,PrecioVenta,Activo) VALUES (@Categoria,@ExtraCodigo,N'Repuesto adicional',0,0,1);
        SET @Extra=CONVERT(int,SCOPE_IDENTITY());
        SELECT @RevR=Revision,@CodigoR=Codigo FROM dbo.vRepuestoGestion WHERE RepuestoID=@Repuesto;
        SELECT @RevP=Revision,@NitP=NIT FROM dbo.vProveedorGestion WHERE ProveedorID=@Proveedor;
        SELECT @RevB=Revision,@CodigoB=Codigo FROM dbo.vBodegaGestion WHERE BodegaID=@Bodega;
        SELECT @RevC=Revision,@CategoriaNombre=Nombre FROM dbo.vCategoriaRepuestoGestion WHERE CategoriaID=@Categoria;
        SELECT @RevO=Revision FROM dbo.vOfertaProveedorGestion WHERE ProveedorID=@Proveedor AND RepuestoID=@Repuesto;
        SELECT @Movimientos=COUNT_BIG(*) FROM dbo.MovimientoInventario;
        SELECT @Inventarios=COUNT_BIG(*) FROM dbo.Inventario;
        SELECT @Auditorias=COUNT_BIG(*) FROM dbo.AuditoriaPrecioRepuesto;
        EXEC sys.sp_set_session_context @key=N'UsuarioID',@value=@Admin;
        SET @Preparado=1;

        SET @Preparado=0;
        SET @Codigo='B2-'+@Sufijo;
        INSERT dbo.Bodega(Codigo,Nombre,Activo) VALUES(@Codigo,N'Segunda bodega',1);SET @Bodega2=CONVERT(int,SCOPE_IDENTITY());
        INSERT dbo.Inventario(BodegaID,RepuestoID,StockMinimo) VALUES(@Bodega2,@Repuesto,0);
        SET @Solicitud=CONVERT(nvarchar(36),NEWID());SET @OtraSolicitud=CONVERT(nvarchar(36),NEWID());
        SET @NumeroCompra=N'CP-'+@Sufijo;SET @NumeroNuevo=N'NUEVA-'+@Sufijo;
        SET @Json=CONCAT(N'[{"bodegaId":',@Bodega,N',"repuestoId":',@Repuesto,N',"cantidad":10,"costoUnitario":20.00}]');
        INSERT #Compras EXEC dbo.spRegistrarCompraApi @Bodeguero,@Solicitud,@NumeroCompra,@Proveedor,N'Garantía ñ 漢字',@Json;
        SELECT @CompraNueva=CompraID,@RevisionNueva=Revision FROM #Compras;
        SET @Preparado=1;

        IF @Caso=1
        BEGIN
          IF dbo.fnExistencia(@Bodega,@Repuesto)<>10 OR (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>12.25
             OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos THROW 52192,N'El registro movió stock o promedio.',1;
        END;
        IF @Caso=2 AND NOT EXISTS(SELECT 1 FROM #Compras WHERE Observaciones=N'Garantía ñ 漢字' AND Total=200 AND Estado='PENDIENTE') THROW 52192,N'La compra perdió sus datos.',1;
        IF @Caso=3
        BEGIN
          INSERT #Compras EXEC dbo.spRegistrarCompraApi @Bodeguero,@Solicitud,@NumeroCompra,@Proveedor,N'Garantía ñ 漢字',@Json;
          IF (SELECT COUNT(*) FROM dbo.Compra WHERE NumeroCompra=@NumeroCompra)<>1 OR (SELECT COUNT(*) FROM dbo.DetalleCompra WHERE CompraID=@CompraNueva)<>1
             OR EXISTS(SELECT 1 FROM #Compras WHERE CompraID<>@CompraNueva) THROW 52192,N'Se duplicó la compra.',1;
        END;
        IF @Caso=4 BEGIN SET @Json=REPLACE(@Json,N'20.00',N'21.00');EXEC dbo.spRegistrarCompraApi @Bodeguero,@Solicitud,@NumeroCompra,@Proveedor,N'Garantía ñ 漢字',@Json;END;
        IF @Caso=5 EXEC dbo.spRegistrarCompraApi @Admin,@Solicitud,@NumeroCompra,@Proveedor,N'Garantía ñ 漢字',@Json;
        IF @Caso=6 EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroCompra,@Proveedor,N'Garantía ñ 漢字',@Json;
        IF @Caso BETWEEN 7 AND 12
        BEGIN
          SET @Json=CASE @Caso WHEN 7 THEN REPLACE(@Json,N'"cantidad":10',N'"cantidad":-1') WHEN 8 THEN REPLACE(@Json,N'"cantidad":10',N'"cantidad":0')
            WHEN 9 THEN REPLACE(@Json,N'"cantidad":10',N'"cantidad":1.5') WHEN 10 THEN REPLACE(@Json,N'20.00',N'-1')
            WHEN 11 THEN REPLACE(@Json,N'20.00',N'1.234') ELSE REPLACE(@Json,N'20.00',N'10000000000') END;
          EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,NULL,@Json;
        END;
        IF @Caso=13 EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,NULL,N'[]';
        IF @Caso=14 BEGIN SET @Json=LEFT(@Json,LEN(@Json)-1)+N','+SUBSTRING(@Json,2,LEN(@Json));EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,NULL,@Json;END;
        IF @Caso=15 EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,2147483647,NULL,@Json;
        IF @Caso IN(16,17)
        BEGIN
          IF @Caso=17 INSERT dbo.ProveedorRepuesto(ProveedorID,RepuestoID) VALUES(@Proveedor,@Extra);
          SET @Json=(SELECT @Bodega2 AS bodegaId,@Extra AS repuestoId,1 AS cantidad,1 AS costoUnitario FOR JSON PATH);
          EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,NULL,@Json;
        END;
        IF @Caso=18 BEGIN UPDATE dbo.Proveedor SET Activo=0 WHERE ProveedorID=@Proveedor;EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,NULL,@Json;END;
        IF @Caso=19 BEGIN UPDATE dbo.Repuesto SET Activo=0 WHERE RepuestoID=@Repuesto;EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,NULL,@Json;END;
        IF @Caso=20 BEGIN UPDATE dbo.Bodega SET Activo=0 WHERE BodegaID=@Bodega;EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,NULL,@Json;END;
        IF @Caso=21 EXEC dbo.spRecibirCompraApi @Tec1,@CompraNueva,@RevisionNueva;
        IF @Caso=22 EXEC dbo.spListarComprasApi @Recepcion;
        IF @Caso=23 EXEC dbo.spAnularCompraApi @Caja,@CompraNueva,@RevisionNueva,N'No autorizado';
        IF @Caso=24 BEGIN UPDATE dbo.Usuario SET Activo=0 WHERE UsuarioID=@Bodeguero;EXEC dbo.spRecibirCompraApi @Bodeguero,@CompraNueva,@RevisionNueva;END;
        IF @Caso=25 BEGIN DELETE #Compras;INSERT #Compras EXEC dbo.spListarComprasApi @Admin,@NumeroCompra;IF NOT EXISTS(SELECT 1 FROM #Compras WHERE CompraID=@CompraNueva) THROW 52192,N'ADMIN no pudo consultar.',1;END;
        IF @Caso IN(26,27,29,37,38,39,40,41,42,43,44,46,50,56)
        BEGIN
          INSERT #Compras EXEC dbo.spRecibirCompraApi @Bodeguero,@CompraNueva,@RevisionNueva;
          IF dbo.fnExistencia(@Bodega,@Repuesto)<>20 OR (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>16.125
             OR NOT EXISTS(SELECT 1 FROM dbo.EventoCompraApi WHERE CompraID=@CompraNueva AND Tipo='RECEPCION' AND UsuarioID=@Bodeguero)
             OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos+1 THROW 52192,N'La recepción perdió stock, promedio o actor.',1;
        END;
        IF @Caso=27 EXEC dbo.spRecibirCompraApi @Bodeguero,@CompraNueva,@RevisionNueva;
        IF @Caso IN(28,30)
        BEGIN
          INSERT #Compras EXEC dbo.spAnularCompraApi @Bodeguero,@CompraNueva,@RevisionNueva,N'Cancelación ñ 漢字';
          IF dbo.fnExistencia(@Bodega,@Repuesto)<>10 OR (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>12.25
             OR NOT EXISTS(SELECT 1 FROM dbo.EventoCompraApi WHERE CompraID=@CompraNueva AND Observacion=N'Cancelación ñ 漢字' AND Tipo='ANULACION')
             OR NOT EXISTS(SELECT 1 FROM dbo.Compra WHERE CompraID=@CompraNueva AND Observaciones=N'Garantía ñ 漢字') THROW 52192,N'La anulación alteró stock u observaciones.',1;
        END;
        IF @Caso=29 EXEC dbo.spAnularCompraApi @Bodeguero,@CompraNueva,@RevisionNueva,N'No permitido';
        IF @Caso=30 EXEC dbo.spRecibirCompraApi @Bodeguero,@CompraNueva,@RevisionNueva;
        IF @Caso=31 EXEC dbo.spRecibirCompraApi @Bodeguero,@CompraNueva,N'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF';
        IF @Caso=32 EXEC dbo.spAnularCompraApi @Bodeguero,@CompraNueva,N'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',N'Fuera de fecha';
        IF @Caso=33 EXEC dbo.spAnularCompraApi @Bodeguero,@CompraNueva,@RevisionNueva,N' ';
        IF @Caso=34 BEGIN SET @Texto=REPLICATE(N'a',1001);EXEC dbo.spAnularCompraApi @Bodeguero,@CompraNueva,@RevisionNueva,@Texto;END;
        IF @Caso=35 EXEC dbo.spGuardarRepuestoGestion @Bodeguero,@Repuesto,@Categoria,@CodigoR,N'Fuente',NULL,99,25.50,1,@RevR;
        IF @Caso=36 EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,N'NO-COSTO',N'Fuente',NULL,99,25.50,1;
        IF @Caso=37
        BEGIN
          DELETE #Compras;SET @Json=(SELECT @Bodega2 AS bodegaId,@Repuesto AS repuestoId,10 AS cantidad,30 AS costoUnitario FOR JSON PATH);
          INSERT #Compras EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,NULL,@Json;
          SELECT @Extra=CompraID,@RevO=Revision FROM #Compras;
          INSERT #Compras EXEC dbo.spRecibirCompraApi @Bodeguero,@Extra,@RevO;
          IF (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega2 AND RepuestoID=@Repuesto)<>30
             OR (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>16.125 THROW 52192,N'Se mezclaron costos entre bodegas.',1;
        END;
        IF @Caso IN(38,39,40,41,42,43)
        BEGIN
          INSERT #ResultadoOrden EXEC dbo.spRegistrarDiagnosticoOrden @Tec1,@Orden,N'Diagnóstico',0;
          INSERT #ResultadoOrden EXEC dbo.spIniciarReparacionOrden @Tec1,@Orden,N'Cambiar pieza',0,N'Autorizado';
          SET @Extra=CASE WHEN @Caso IN(40,41) THEN 20 WHEN @Caso=43 THEN 15 ELSE 1 END;
          INSERT #ResultadoOrden EXEC dbo.spUsarRepuestoOrden @Tec1,@Orden,@Bodega,@Repuesto,@Extra,25.50;
          SELECT @Reparacion=ReparacionID FROM dbo.vOrdenAcceso WHERE OrdenID=@Orden;
          IF NOT EXISTS(SELECT 1 FROM dbo.ReparacionRepuesto WHERE ReparacionID=@Reparacion AND CostoUnitario=16.13)
             THROW 52192,N'El consumo no congeló el promedio redondeado a centavos.',1;
        END;
        IF @Caso=39 AND (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>16.125 THROW 52192,N'La salida parcial cambió el promedio.',1;
        IF @Caso IN(40,41) AND (dbo.fnExistencia(@Bodega,@Repuesto)<>0 OR (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>0) THROW 52192,N'El inventario agotado conservó un promedio.',1;
        IF @Caso=42
        BEGIN
          INSERT #ResultadoOrden EXEC dbo.spFinalizarReparacionOrden @Tec1,@Orden;
          SET @Codigo='F-'+@Sufijo;EXEC dbo.spGenerarFactura @Orden,@Codigo,@Admin,@Factura OUTPUT;
        END;
        IF @Caso IN(41,42,43,44,45,60)
        BEGIN
          IF @Caso=44
          BEGIN
            SET @Nit='PR2-'+@Sufijo;INSERT dbo.Proveedor(NIT,Nombre,Activo) VALUES(@Nit,N'Segundo proveedor',1);SET @Proveedor2=CONVERT(int,SCOPE_IDENTITY());
            INSERT dbo.ProveedorRepuesto(ProveedorID,RepuestoID) VALUES(@Proveedor2,@Repuesto);
          END ELSE SET @Proveedor2=@Proveedor;
          SET @Json=(SELECT @Bodega AS bodegaId,@Repuesto AS repuestoId,10 AS cantidad,
            CONVERT(decimal(12,2),CASE WHEN @Caso=45 THEN 0 WHEN @Caso=60 THEN 9999999999.99 ELSE 30 END) AS costoUnitario FOR JSON PATH);
          DELETE #Compras;INSERT #Compras EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor2,NULL,@Json;
          SELECT @Extra=CompraID,@RevO=Revision FROM #Compras;
          INSERT #Compras EXEC dbo.spRecibirCompraApi @Bodeguero,@Extra,@RevO;
          IF @Caso=41 AND (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>30 THROW 52192,N'La reposición no tomó su costo nuevo.',1;
          IF @Caso=42 AND (NOT EXISTS(SELECT 1 FROM dbo.ReparacionRepuesto WHERE ReparacionID=@Reparacion AND CostoUnitario=16.13)
            OR NOT EXISTS(SELECT 1 FROM dbo.FacturaDetalle WHERE FacturaID=@Factura AND TipoConcepto='REP' AND PrecioUnitario=25.50)) THROW 52192,N'Se reescribió historia.',1;
          IF @Caso=43 AND (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>25.375 THROW 52192,N'El promedio usó unidades ya consumidas.',1;
          IF @Caso=44 AND (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>20.75 THROW 52192,N'Se separó indebidamente el costo por proveedor.',1;
          IF @Caso=45 AND (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>6.125 THROW 52192,N'La entrada sin cargo perdió el promedio.',1;
          IF @Caso=60 AND (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>5000000006.12 THROW 52192,N'El costo máximo perdió centavos.',1;
        END;
        IF @Caso=46 UPDATE dbo.ValoracionInventario SET CostoPosterior=0 WHERE MovimientoID=(SELECT TOP(1) MovimientoID FROM dbo.MovimientoInventario WHERE CompraID=@CompraNueva);
        IF @Caso=47 DELETE dbo.SolicitudCompraApi WHERE CompraID=@CompraNueva;
        IF @Caso=48 UPDATE dbo.EventoCompraApi SET Responsable=N'Otra persona' WHERE CompraID=@CompraNueva;
        IF @Caso=49
        BEGIN
          SET @Json=(SELECT BodegaID AS bodegaId,@Repuesto AS repuestoId,1 AS cantidad,30 AS costoUnitario FROM dbo.Bodega WHERE BodegaID IN(@Bodega,@Bodega2) FOR JSON PATH);
          DELETE #Compras;INSERT #Compras EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,NULL,@Json;
          SELECT @Extra=CompraID,@RevO=Revision FROM #Compras;
          UPDATE dbo.Bodega SET Activo=0 WHERE BodegaID=@Bodega2;
          EXEC dbo.spRecibirCompraApi @Bodeguero,@Extra,@RevO;
        END;
        IF @Caso=50 AND NOT EXISTS(SELECT 1 FROM dbo.ValoracionInventario v JOIN dbo.MovimientoInventario m ON m.MovimientoID=v.MovimientoID WHERE m.CompraID=@CompraNueva AND v.CostoAnterior=12.25 AND v.CostoPosterior=16.125 AND v.EsMigracion=0) THROW 52192,N'La valoración no conservó precisión.',1;
        IF @Caso=51 AND (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega2 AND RepuestoID=@Repuesto)<>0 THROW 52192,N'Un destino nuevo heredó un costo ficticio.',1;
        IF @Caso=52 EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,NULL,N'no-json';
        IF @Caso=53 BEGIN SET @Texto=REPLICATE(N'A',31);EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@Texto,@Proveedor,NULL,@Json;END;
        IF @Caso=54 EXEC dbo.spRegistrarCompraApi @Bodeguero,N'invalido',@NumeroNuevo,@Proveedor,NULL,@Json;
        IF @Caso=55 BEGIN SET @Texto=REPLICATE(N'a',1001);EXEC dbo.spRegistrarCompraApi @Bodeguero,@OtraSolicitud,@NumeroNuevo,@Proveedor,@Texto,@Json;END;
        IF @Caso=56 AND NOT EXISTS(SELECT 1 FROM dbo.Repuesto WHERE RepuestoID=@Repuesto AND PrecioVenta=25.50) THROW 52192,N'La recepción alteró precio de venta.',1;
        IF @Caso=57 UPDATE dbo.DetalleCompra SET CostoUnitario=99 WHERE CompraID=@CompraNueva;
        IF @Caso=58 EXEC dbo.spConsultarCompraApi @Bodeguero,2147483647;
        IF @Caso=59 EXEC dbo.spListarComprasApi @Bodeguero,@Desde='2026-10-21',@Hasta='2026-10-01';
        IF @Esperado<>0 THROW 52091,N'La operación debía rechazarse y fue aceptada.',1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Detalle=ERROR_MESSAGE();
        IF @Preparado=0 OR @Esperado=0 OR ERROR_NUMBER()<>@Esperado SET @Resultado='FAIL';
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    END CATCH;
    IF @Preparado=1 AND (TRY_CONVERT(int,SESSION_CONTEXT(N'UsuarioID')) IS NULL OR TRY_CONVERT(int,SESSION_CONTEXT(N'UsuarioID'))<>@Admin)
    BEGIN SET @Resultado='FAIL';SET @Detalle=COALESCE(@Detalle+N' | ',N'')+N'El contexto de auditoría no fue restaurado.';END;
    EXEC sys.sp_set_session_context @key=N'UsuarioID',@value=@ContextoInicial;
    ;WITH Despues AS (
SELECT 'OrdenServicio' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.OrdenServicio UNION ALL
SELECT 'Diagnostico' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Diagnostico UNION ALL
SELECT 'Reparacion' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Reparacion UNION ALL
SELECT 'ReparacionActividad' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.ReparacionActividad UNION ALL
SELECT 'ReparacionRepuesto' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.ReparacionRepuesto UNION ALL
SELECT 'MovimientoInventario' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.MovimientoInventario UNION ALL
SELECT 'HistorialEstadoOrden' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.HistorialEstadoOrden UNION ALL
SELECT 'AsignacionOrden' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.AsignacionOrden UNION ALL
SELECT 'Cliente' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Cliente UNION ALL
SELECT 'Equipo' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Equipo UNION ALL
SELECT 'Usuario' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Usuario UNION ALL
SELECT 'Empleado' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Empleado UNION ALL
SELECT 'UsuarioRol' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.UsuarioRol UNION ALL
SELECT 'CategoriaRepuesto' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.CategoriaRepuesto UNION ALL
SELECT 'Repuesto' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Repuesto UNION ALL
SELECT 'Bodega' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Bodega UNION ALL
SELECT 'Inventario' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Inventario UNION ALL
SELECT 'Proveedor' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Proveedor UNION ALL
SELECT 'ProveedorRepuesto' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.ProveedorRepuesto UNION ALL
SELECT 'Compra' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Compra UNION ALL
SELECT 'DetalleCompra' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.DetalleCompra UNION ALL
SELECT 'Actividad' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Actividad UNION ALL
SELECT 'AuditoriaPrecioRepuesto' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.AuditoriaPrecioRepuesto UNION ALL
SELECT 'Factura' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Factura UNION ALL
SELECT 'FacturaDetalle' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.FacturaDetalle UNION ALL
SELECT 'Pago' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Pago UNION ALL
SELECT 'Entrega' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.Entrega UNION ALL
SELECT 'SolicitudPagoApi' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.SolicitudPagoApi UNION ALL
SELECT 'ValoracionInventario',COUNT_BIG(*) FROM dbo.ValoracionInventario UNION ALL
SELECT 'SolicitudCompraApi',COUNT_BIG(*) FROM dbo.SolicitudCompraApi UNION ALL
SELECT 'EventoCompraApi',COUNT_BIG(*) FROM dbo.EventoCompraApi
    )
    SELECT @Resultado=CASE WHEN EXISTS(SELECT 1 FROM Despues d JOIN @Antes a ON a.Nombre=d.Nombre WHERE a.Cantidad<>d.Cantidad) THEN 'FAIL' ELSE @Resultado END;
    IF @Resultado='FAIL' AND @Detalle IS NULL SET @Detalle=N'La prueba dejó cantidades persistentes diferentes.';
    INSERT @Resultados VALUES(@Caso,@Nombre,@Resultado,@Detalle);SET @Caso+=1;
END;
DROP TABLE #Compras;DROP TABLE #ResultadoOrden;DROP TABLE #Repuestos;DROP TABLE #Categorias;DROP TABLE #Proveedores;DROP TABLE #Bodegas;DROP TABLE #Ofertas;DROP TABLE #Minimos;
SELECT ID,Caso,Resultado,Detalle FROM @Resultados ORDER BY ID;
IF EXISTS(SELECT 1 FROM @Resultados WHERE Resultado='FAIL') THROW 52092,N'Una o más pruebas de compras fallaron. Revisá los resultados.',1;
GO
