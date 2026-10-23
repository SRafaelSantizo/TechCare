-- Ejecutar después del 33 en DESARROLLO, sin otras escrituras concurrentes.
-- Datos propios por caso, ROLLBACK y verificación de cantidades antes/después.
-- Las identidades pueden dejar huecos. No es prueba entre sesiones concurrentes.
USE [TechCare];
GO
SET NOCOUNT ON; SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 52090,N'Ejecutá sin una transacción abierta.',1;
IF OBJECT_ID(N'dbo.spListarInventarioApi',N'P') IS NULL
    THROW 52090,N'Ejecutá primero 33_Inventario_Procedimientos.sql.',1;
DECLARE @Admin int=(SELECT TOP (1) UsuarioID FROM dbo.Usuario WHERE dbo.fnTieneRol(UsuarioID,'ADMIN')=1 ORDER BY UsuarioID);
DECLARE @Modelo int=(SELECT TOP (1) ModeloEquipoID FROM dbo.ModeloEquipo ORDER BY ModeloEquipoID);
DECLARE @Tipo int=(SELECT TOP (1) TipoClienteID FROM dbo.TipoCliente ORDER BY TipoClienteID);
IF @Admin IS NULL OR @Modelo IS NULL OR @Tipo IS NULL THROW 52090,N'Se requiere ADMIN activo y catálogos base.',1;
DECLARE @ContextoInicial sql_variant=SESSION_CONTEXT(N'UsuarioID');
DECLARE @Casos TABLE(ID int PRIMARY KEY,Caso nvarchar(200),ErrorEsperado int);
INSERT @Casos VALUES
(1,N'Inventario incluye pares con stock y asociaciones vacías',0),
(2,N'Nombres Unicode se conservan en inventario',0),
(3,N'Búsqueda Unicode encuentra el repuesto',0),
(4,N'Porcentaje se busca como texto literal',0),
(5,N'Guion bajo se busca como texto literal',0),
(6,N'Filtro de categoría separa sus pares',0),
(7,N'Filtro de bodega devuelve sólo su ubicación',0),
(8,N'Stock cero y mínimo cero se muestra sin existencias',0),
(9,N'Existencia igual al mínimo genera alerta sin faltante',0),
(10,N'Existencia inferior al mínimo calcula el faltante',0),
(11,N'Resumen suma todos los resultados del filtro',0),
(12,N'Repuesto inactivo conserva stock e historia visible',0),
(13,N'Filtro activo excluye repuestos inactivos',0),
(14,N'Filtro inactivo incluye bodegas inactivas',0),
(15,N'Consultar no crea asociaciones de inventario',0),
(16,N'Paginación estable conserva resumen completo',0),
(17,N'Página cero rechazada',52200),
(18,N'Tamaño mayor de cien rechazado',52200),
(19,N'ID negativo rechazado',52200),
(20,N'Estado de stock desconocido rechazado',52200),
(21,N'Búsqueda larga rechazada sin truncar',52200),
(22,N'Técnico no consulta inventario general',52004),
(23,N'Recepción no consulta kardex',52004),
(24,N'Caja no consulta resumen',52004),
(25,N'Cuenta de bodega inactiva rechazada',52004),
(26,N'ADMIN consulta inventario y kardex',0),
(27,N'Entrada conserva compra, línea, costo y responsable',0),
(28,N'Nueva entrada conserva el promedio del primer movimiento',0),
(29,N'Salida conserva orden, técnico y costo histórico',0),
(30,N'Kardex completo cuadra entradas, salidas y saldo',0),
(31,N'Rango por día conserva saldo anterior al período',0),
(32,N'Filtro de entradas no elimina salidas del resumen',0),
(33,N'Filtro de salidas no elimina entradas del resumen',0),
(34,N'Período anterior al primer movimiento devuelve ceros',0),
(35,N'Período futuro conserva saldo sin inventar movimientos',0),
(36,N'Bodega sin movimientos devuelve kardex vacío y saldo cero',0),
(37,N'Páginas del kardex conservan orden por MovimientoID',0),
(38,N'Cambiar catálogo no reescribe costos del kardex',0),
(39,N'Pareja no asociada devuelve error controlado',52202),
(40,N'Rango de fechas invertido rechazado',52200),
(41,N'Tipo de movimiento inválido rechazado',52200),
(42,N'Catálogos inactivos no ocultan movimientos históricos',0),
(43,N'Consultas conservan stock, costo y contexto de auditoría',0),
(44,N'Recepción sin cargo presenta costo y valoración cero',0),
(45,N'Importe grande conserva centavos y seis decimales',0),
(46,N'Consultar repetidamente no duplica movimientos',0),
(47,N'Recepción conserva nombre histórico al renombrar empleado',0),
(48,N'Valoración y saldo posterior corresponden al movimiento',0),
(49,N'Filtro sin coincidencias devuelve resumen cero',0),
(50,N'Último día del año 9999 no desborda el filtro',0),
(51,N'Promedio periódico redondea hacia arriba a seis decimales',0),
(52,N'Promedio periódico redondea hacia abajo a seis decimales',0),
(53,N'Exactamente media millonésima redondea hacia arriba',0),
(54,N'Stock bigint y costo máximos no desbordan el promedio',0);
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
-- Las vistas tienen JOIN; los IDs de estas tablas temporales no son IDENTITY.
SELECT TOP (0) * INTO #I FROM dbo.vInventarioApi;
SELECT TOP (0) * INTO #K FROM dbo.vKardexApi;
SELECT TOP (0) * INTO #CompraApi FROM dbo.vCompraApi;
CREATE TABLE #RI(Total bigint,SinExistencia bigint,StockBajo bigint,ValorTotal decimal(38,6));
CREATE TABLE #RK(SaldoInicial bigint,Entradas bigint,Salidas bigint,SaldoFinal bigint,Total bigint);
DECLARE @Resultados TABLE(ID int,Caso nvarchar(200),Resultado varchar(4),Detalle nvarchar(4000));
DECLARE @Caso int=1,@Esperado int,@Nombre nvarchar(200),@Resultado varchar(4),@Detalle nvarchar(4000),@Preparado bit;
DECLARE @Sufijo varchar(8),@Codigo varchar(30),@Usuario varchar(50),@Nit varchar(20),@Serie varchar(80),@Texto nvarchar(max);
DECLARE @Cliente int,@Equipo int,@Empleado int,@Tec1 int,@Tec2 int,@Recepcion int,@Orden int,@Categoria int,@Repuesto int,@Bodega int,@Proveedor int,@Compra int,@Actividad int;
DECLARE @Bodeguero int,@Caja int,@Extra int,@ExtraCodigo varchar(30),@Bodega2 int,@CompraNueva int,@Revision nvarchar(64),@Mov1 bigint;
DECLARE @Movimientos bigint,@Inventarios bigint,@Auditorias bigint,@Promedio decimal(18,6),@Stock bigint;
DECLARE @Lineas dbo.TipoDetalleCompra;
DECLARE @Hoy date=CONVERT(date,SYSUTCDATETIME()),@Ayer date,@AntesDeTodo date,@Manana date;
SET @Ayer=DATEADD(day,-1,@Hoy);SET @AntesDeTodo=DATEADD(day,-2,@Hoy);SET @Manana=DATEADD(day,1,@Hoy);
DECLARE @Solicitud nvarchar(36),@Json nvarchar(max),@NumeroCompra nvarchar(30);
DECLARE @Hash varchar(255)='$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik=';
WHILE @Caso<=54
BEGIN
    SELECT @Nombre=Caso,@Esperado=ErrorEsperado FROM @Casos WHERE ID=@Caso;
    SET @Resultado='PASS';SET @Detalle=NULL;SET @Preparado=0;
    SET @Sufijo=LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),8);
    DELETE #ResultadoOrden;DELETE #I;DELETE #K;DELETE #RI;DELETE #RK;DELETE #CompraApi;DELETE @Lineas;
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
        EXEC dbo.spRegistrarCompra @Codigo, @Proveedor, @Admin, @Lineas, @Compra OUTPUT,@Fecha=@Ayer;
        EXEC dbo.spRecibirCompra @Compra, @Admin,@Fecha=@Ayer;
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
        SET @Codigo='B2-'+@Sufijo;
        INSERT dbo.Bodega(Codigo,Nombre,Activo) VALUES(@Codigo,N'Segunda bodega',1);SET @Bodega2=CONVERT(int,SCOPE_IDENTITY());
        INSERT dbo.Inventario(BodegaID,RepuestoID,StockMinimo) VALUES(@Bodega2,@Repuesto,0);
        SELECT @Mov1=MovimientoID FROM dbo.MovimientoInventario WHERE CompraID=@Compra;
        EXEC sys.sp_set_session_context @key=N'UsuarioID',@value=@Admin;
        IF @Caso IN(28,29,30,31,32,33,35,37,38,42,43,46,47,48)
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spRegistrarDiagnosticoOrden @Tec1,@Orden,N'Diagnóstico ñ',0;
            INSERT #ResultadoOrden EXEC dbo.spIniciarReparacionOrden @Tec1,@Orden,N'Cambiar pieza',0,N'Autorizado ñ';
            INSERT #ResultadoOrden EXEC dbo.spUsarRepuestoOrden @Tec1,@Orden,@Bodega,@Repuesto,2,25.50;
            SET @Solicitud=CONVERT(nvarchar(36),NEWID());SET @NumeroCompra=N'KI-'+@Sufijo;
            SET @Json=(SELECT @Bodega AS bodegaId,@Repuesto AS repuestoId,6 AS cantidad,20.00 AS costoUnitario FOR JSON PATH);
            INSERT #CompraApi EXEC dbo.spRegistrarCompraApi @Bodeguero,@Solicitud,@NumeroCompra,@Proveedor,N'Compra ñ',@Json;
            SELECT @CompraNueva=CompraID,@Revision=Revision FROM #CompraApi;
            DELETE #CompraApi;
            INSERT #CompraApi EXEC dbo.spRecibirCompraApi @Bodeguero,@CompraNueva,@Revision;
        END;
        SELECT @Movimientos=COUNT_BIG(*) FROM dbo.MovimientoInventario;
        SELECT @Inventarios=COUNT_BIG(*) FROM dbo.Inventario;
        SELECT @Promedio=CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto;
        SET @Stock=dbo.fnExistencia(@Bodega,@Repuesto);
        SET @Preparado=1;

        IF @Caso IN(1,2,6,11,12,13,14,15,16,26)
        BEGIN
            IF @Caso IN(12,13) UPDATE dbo.Repuesto SET Activo=0 WHERE RepuestoID=@Repuesto;
            IF @Caso=14 UPDATE dbo.Bodega SET Activo=0 WHERE BodegaID=@Bodega;
            IF @Caso NOT IN(13,14) INSERT #I EXEC dbo.spListarInventarioApi @Admin,@CategoriaID=@Categoria;
            IF @Caso=13 INSERT #I EXEC dbo.spListarInventarioApi @Admin,@CategoriaID=@Categoria,@Activo=1;
            IF @Caso=14 INSERT #I EXEC dbo.spListarInventarioApi @Admin,@CategoriaID=@Categoria,@Activo=0;
            IF @Caso IN(1,6,12,26) AND (SELECT COUNT(*) FROM #I)<>2 THROW 52292,N'Faltan pares del inventario.',1;
            IF @Caso=1 AND NOT EXISTS(SELECT 1 FROM #I WHERE BodegaID=@Bodega AND Existencia=10 AND CostoPromedio=12.25) THROW 52292,N'Existencia o promedio incorrecto.',1;
            IF @Caso=2 AND NOT EXISTS(SELECT 1 FROM #I WHERE Repuesto=N'Fuente de prueba ñ' AND Bodega=N'Bodega técnica de prueba') THROW 52292,N'Se perdió Unicode.',1;
            IF @Caso=11
            BEGIN
                INSERT #RI EXEC dbo.spResumenInventarioApi @Admin,@CategoriaID=@Categoria;
                IF NOT EXISTS(SELECT 1 FROM #RI WHERE Total=2 AND SinExistencia=1 AND StockBajo=0 AND ValorTotal=122.500000) THROW 52292,N'Resumen incorrecto.',1;
            END;
            IF @Caso=12 AND EXISTS(SELECT 1 FROM #I WHERE RepuestoActivo<>0) THROW 52292,N'Se perdió el estado inactivo.',1;
            IF @Caso=13 AND EXISTS(SELECT 1 FROM #I) THROW 52292,N'El filtro activo incluyó inactivos.',1;
            IF @Caso=14 AND ((SELECT COUNT(*) FROM #I)<>1 OR NOT EXISTS(SELECT 1 FROM #I WHERE BodegaID=@Bodega AND BodegaActiva=0)) THROW 52292,N'Filtro inactivo incorrecto.',1;
            IF @Caso=15 AND EXISTS(SELECT 1 FROM #I WHERE RepuestoID=@Extra) THROW 52292,N'Se creó una asociación inexistente.',1;
            IF @Caso=16
            BEGIN
                DELETE #I;INSERT #I EXEC dbo.spListarInventarioApi @Admin,@CategoriaID=@Categoria,@Pagina=1,@Tamano=1;
                IF NOT EXISTS(SELECT 1 FROM #I WHERE BodegaID=@Bodega) THROW 52292,N'Primera página incorrecta.',1;
                DELETE #I;INSERT #I EXEC dbo.spListarInventarioApi @Admin,@CategoriaID=@Categoria,@Pagina=2,@Tamano=1;
                INSERT #RI EXEC dbo.spResumenInventarioApi @Admin,@CategoriaID=@Categoria;
                IF NOT EXISTS(SELECT 1 FROM #I WHERE BodegaID=@Bodega2) OR NOT EXISTS(SELECT 1 FROM #RI WHERE Total=2 AND ValorTotal=122.5) THROW 52292,N'La página alteró el resumen.',1;
            END;
        END;
        IF @Caso=3
        BEGIN
            INSERT #I EXEC dbo.spListarInventarioApi @Bodeguero,@Buscar=N'Fuente de prueba ñ',@CategoriaID=@Categoria;
            IF (SELECT COUNT(*) FROM #I)<>2 THROW 52292,N'La búsqueda Unicode no encontró los pares.',1;
        END;
        IF @Caso=4
        BEGIN
            INSERT #I EXEC dbo.spListarInventarioApi @Admin,@Buscar=N'%',@CategoriaID=@Categoria;
            IF EXISTS(SELECT 1 FROM #I) THROW 52292,N'Porcentaje actuó como comodín.',1;
        END;
        IF @Caso=5
        BEGIN
            UPDATE dbo.Repuesto SET Nombre=N'Fuente_ñ' WHERE RepuestoID=@Repuesto;
            INSERT #I EXEC dbo.spListarInventarioApi @Admin,@Buscar=N'_',@CategoriaID=@Categoria;
            IF (SELECT COUNT(*) FROM #I)<>2 THROW 52292,N'Guion bajo perdió la coincidencia literal.',1;
            DELETE #I;INSERT #I EXEC dbo.spListarInventarioApi @Admin,@Buscar=N'FuenteZñ',@CategoriaID=@Categoria;
            IF EXISTS(SELECT 1 FROM #I) THROW 52292,N'Búsqueda literal incorrecta.',1;
        END;
        IF @Caso=7
        BEGIN
            INSERT #I EXEC dbo.spListarInventarioApi @Admin,@BodegaID=@Bodega;
            IF (SELECT COUNT(*) FROM #I)<>1 OR EXISTS(SELECT 1 FROM #I WHERE BodegaID<>@Bodega) THROW 52292,N'Se mezclaron bodegas.',1;
        END;
        IF @Caso IN(8,9,10)
        BEGIN
            IF @Caso IN(9,10) UPDATE dbo.Inventario SET StockMinimo=CASE @Caso WHEN 9 THEN 10 ELSE 12 END WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto;
            INSERT #I EXEC dbo.spListarInventarioApi @Admin,@CategoriaID=@Categoria;
            IF @Caso=8 AND NOT EXISTS(SELECT 1 FROM #I WHERE BodegaID=@Bodega2 AND EstadoStock='SIN_EXISTENCIA' AND Faltante=0 AND CostoPromedio=0 AND ValorExistencia=0) THROW 52292,N'El par vacío no se presentó correctamente.',1;
            IF @Caso=9 AND NOT EXISTS(SELECT 1 FROM #I WHERE BodegaID=@Bodega AND EstadoStock='BAJO' AND Faltante=0) THROW 52292,N'La igualdad con mínimo perdió la alerta.',1;
            IF @Caso=10 AND NOT EXISTS(SELECT 1 FROM #I WHERE BodegaID=@Bodega AND EstadoStock='BAJO' AND Faltante=2) THROW 52292,N'Faltante incorrecto.',1;
        END;
        IF @Caso=17 EXEC dbo.spListarInventarioApi @Admin,@Pagina=0;
        IF @Caso=18 EXEC dbo.spListarInventarioApi @Admin,@Tamano=101;
        IF @Caso=19 EXEC dbo.spListarInventarioApi @Admin,@BodegaID=-1;
        IF @Caso=20 EXEC dbo.spListarInventarioApi @Admin,@EstadoStock=N'INVALIDO';
        IF @Caso=21 BEGIN SET @Texto=REPLICATE(N'a',151);EXEC dbo.spListarInventarioApi @Admin,@Buscar=@Texto;END;
        IF @Caso=22 EXEC dbo.spListarInventarioApi @Tec1;
        IF @Caso=23 EXEC dbo.spListarKardexApi @Recepcion,@Bodega,@Repuesto;
        IF @Caso=24 EXEC dbo.spResumenInventarioApi @Caja;
        IF @Caso=25 BEGIN UPDATE dbo.Usuario SET Activo=0 WHERE UsuarioID=@Bodeguero;EXEC dbo.spListarInventarioApi @Bodeguero;END;
        IF @Caso=26 BEGIN INSERT #K EXEC dbo.spListarKardexApi @Admin,@Bodega,@Repuesto;IF (SELECT COUNT(*) FROM #K)<>1 THROW 52292,N'ADMIN no obtuvo el kardex.',1;END;
        IF @Caso IN(27,28,29,30,31,32,33,34,35,36,37,38,42,46,47,48,50)
        BEGIN
            IF @Caso=38 UPDATE dbo.Repuesto SET CostoReferencia=CostoReferencia,PrecioVenta=99,Nombre=N'Nombre cambiado' WHERE RepuestoID=@Repuesto;
            IF @Caso=42 BEGIN UPDATE dbo.Bodega SET Activo=0 WHERE BodegaID=@Bodega;UPDATE dbo.Repuesto SET Activo=0 WHERE RepuestoID=@Repuesto;END;
            IF @Caso=47 UPDATE dbo.Empleado SET Nombres=N'Nombre posterior' WHERE EmpleadoID=(SELECT EmpleadoID FROM dbo.Usuario WHERE UsuarioID=@Bodeguero);
            IF @Caso IN(27,28,29,30,37,38,42,46,47,48) INSERT #K EXEC dbo.spListarKardexApi @Admin,@Bodega,@Repuesto;
            IF @Caso=27 AND NOT EXISTS(SELECT 1 FROM #K WHERE CompraID=@Compra AND LineaCompra=1 AND CostoUnitario=12.25 AND Cantidad=10 AND Responsable IS NOT NULL AND ExistenciaAnterior=0 AND ExistenciaResultante=10) THROW 52292,N'Origen o entrada incorrectos.',1;
            IF @Caso=28 AND NOT EXISTS(SELECT 1 FROM #K WHERE MovimientoID=@Mov1 AND CostoAnterior=0 AND CostoPosterior=12.250000) THROW 52292,N'Se reescribió el promedio histórico.',1;
            IF @Caso=29 AND NOT EXISTS(SELECT 1 FROM #K WHERE Tipo='S' AND OrdenID=@Orden AND UsuarioID=@Tec1 AND CostoUnitario=12.25 AND ExistenciaAnterior=10 AND ExistenciaResultante=8) THROW 52292,N'La salida perdió su origen.',1;
            IF @Caso=30 BEGIN INSERT #RK EXEC dbo.spResumenKardexApi @Admin,@Bodega,@Repuesto;IF NOT EXISTS(SELECT 1 FROM #RK WHERE SaldoInicial=0 AND Entradas=16 AND Salidas=2 AND SaldoFinal=14 AND Total=3) THROW 52292,N'El kardex completo no cuadra.',1;END;
            IF @Caso IN(31,32,33)
            BEGIN
                DECLARE @TipoMovimiento nvarchar(1)=CASE @Caso WHEN 32 THEN N'E' WHEN 33 THEN N'S' ELSE NULL END;
                INSERT #RK EXEC dbo.spResumenKardexApi @Admin,@Bodega,@Repuesto,@Hoy,@Hoy,@TipoMovimiento;
                INSERT #K EXEC dbo.spListarKardexApi @Admin,@Bodega,@Repuesto,@Hoy,@Hoy,@TipoMovimiento;
                IF NOT EXISTS(SELECT 1 FROM #RK WHERE SaldoInicial=10 AND Entradas=6 AND Salidas=2 AND SaldoFinal=14 AND Total=CASE @Caso WHEN 31 THEN 2 ELSE 1 END) THROW 52292,N'El filtro alteró saldos del período.',1;
                IF @Caso IN(32,33) AND EXISTS(SELECT 1 FROM #K WHERE Tipo<>@TipoMovimiento) THROW 52292,N'Se devolvió otro tipo de movimiento.',1;
            END;
            IF @Caso=34 BEGIN INSERT #RK EXEC dbo.spResumenKardexApi @Admin,@Bodega,@Repuesto,NULL,@AntesDeTodo;IF NOT EXISTS(SELECT 1 FROM #RK WHERE SaldoInicial=0 AND Entradas=0 AND Salidas=0 AND SaldoFinal=0 AND Total=0) THROW 52292,N'El período anterior contiene movimientos.',1;END;
            IF @Caso=35 BEGIN INSERT #RK EXEC dbo.spResumenKardexApi @Admin,@Bodega,@Repuesto,@Manana,NULL;IF NOT EXISTS(SELECT 1 FROM #RK WHERE SaldoInicial=14 AND Entradas=0 AND Salidas=0 AND SaldoFinal=14 AND Total=0) THROW 52292,N'Período sin movimientos perdió saldo.',1;END;
            IF @Caso=36
            BEGIN
                INSERT #RK EXEC dbo.spResumenKardexApi @Admin,@Bodega2,@Repuesto;
                INSERT #K EXEC dbo.spListarKardexApi @Admin,@Bodega2,@Repuesto;
                IF EXISTS(SELECT 1 FROM #K) OR NOT EXISTS(SELECT 1 FROM #RK WHERE SaldoInicial=0 AND Entradas=0 AND Salidas=0 AND SaldoFinal=0 AND Total=0) THROW 52292,N'El par vacío inventó movimientos.',1;
            END;
            IF @Caso=37
            BEGIN
                DELETE #K;INSERT #K EXEC dbo.spListarKardexApi @Admin,@Bodega,@Repuesto,@Pagina=1,@Tamano=1;
                IF (SELECT COUNT(*) FROM #K)<>1 OR NOT EXISTS(SELECT 1 FROM #K WHERE MovimientoID=@Mov1) THROW 52292,N'Primera página del kardex incorrecta.',1;
                DELETE #K;INSERT #K EXEC dbo.spListarKardexApi @Admin,@Bodega,@Repuesto,@Pagina=2,@Tamano=1;
                IF (SELECT COUNT(*) FROM #K)<>1 OR NOT EXISTS(SELECT 1 FROM #K WHERE Tipo='S') THROW 52292,N'Segunda página del kardex incorrecta.',1;
            END;
            IF @Caso=38 AND (EXISTS(SELECT 1 FROM #K WHERE CostoUnitario=99) OR NOT EXISTS(SELECT 1 FROM #K WHERE MovimientoID=@Mov1 AND CostoUnitario=12.25)) THROW 52292,N'El catálogo reescribió el kardex.',1;
            IF @Caso=42 AND (SELECT COUNT(*) FROM #K)<>3 THROW 52292,N'Los inactivos perdieron historia.',1;
            IF @Caso=46 BEGIN INSERT #K EXEC dbo.spListarKardexApi @Admin,@Bodega,@Repuesto;IF (SELECT COUNT(*) FROM #K)<>6 OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos THROW 52292,N'La consulta duplicó movimientos.',1;END;
            IF @Caso=47 AND NOT EXISTS(SELECT 1 FROM #K WHERE CompraID=@CompraNueva AND Responsable=N'Bodega Prueba' AND NombreHistorico=1) THROW 52292,N'Se perdió el nombre conservado en recepción.',1;
            IF @Caso=48 AND NOT EXISTS(SELECT 1 FROM #K WHERE CompraID=@CompraNueva AND ExistenciaAnterior=8 AND ExistenciaResultante=14 AND CostoAnterior=12.25 AND CostoPosterior=15.571429 AND ValorExistencia=218.000006 AND EsMigracion=0)
            BEGIN
                SET @Texto=N'No se encontró el movimiento de la nueva compra.';
                SELECT @Texto=CONCAT(N'Valoración histórica incorrecta. Stock anterior=',ExistenciaAnterior,
                    N'; posterior=',ExistenciaResultante,N'; promedio anterior=',CostoAnterior,
                    N'; posterior=',CostoPosterior,N'; valor=',ValorExistencia,N'; migración=',EsMigracion,
                    N'. Esperado: 8; 14; 12.250000; 15.571429; 218.000006; 0.')
                FROM #K WHERE CompraID=@CompraNueva;
                THROW 52292,@Texto,1;
            END;
            IF @Caso=50 BEGIN INSERT #RK EXEC dbo.spResumenKardexApi @Admin,@Bodega,@Repuesto,NULL,'99991231';IF NOT EXISTS(SELECT 1 FROM #RK WHERE SaldoFinal=10) THROW 52292,N'El límite superior perdió el movimiento.',1;END;
        END;
        IF @Caso=39 EXEC dbo.spListarKardexApi @Admin,@Bodega,@Extra;
        IF @Caso=40 EXEC dbo.spResumenKardexApi @Admin,@Bodega,@Repuesto,@Hoy,@Ayer;
        IF @Caso=41 EXEC dbo.spListarKardexApi @Admin,@Bodega,@Repuesto,@Tipo=N'ENTRADA';
        IF @Caso=43
        BEGIN
            INSERT #I EXEC dbo.spListarInventarioApi @Admin,@CategoriaID=@Categoria;
            INSERT #K EXEC dbo.spListarKardexApi @Admin,@Bodega,@Repuesto;
            INSERT #RI EXEC dbo.spResumenInventarioApi @Admin,@CategoriaID=@Categoria;
            INSERT #RK EXEC dbo.spResumenKardexApi @Admin,@Bodega,@Repuesto;
            IF (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos OR (SELECT COUNT_BIG(*) FROM dbo.Inventario)<>@Inventarios
               OR dbo.fnExistencia(@Bodega,@Repuesto)<>@Stock OR (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>@Promedio
               OR TRY_CONVERT(int,SESSION_CONTEXT(N'UsuarioID'))<>@Admin THROW 52292,N'Las consultas alteraron datos o contexto.',1;
        END;
        IF @Caso IN(44,45)
        BEGIN
            DELETE @Lineas;
            INSERT @Lineas VALUES(1,@Bodega2,@Repuesto,CASE @Caso WHEN 45 THEN 2147483647 ELSE 5 END,CASE @Caso WHEN 45 THEN CONVERT(decimal(12,2),9999999999.99) ELSE CONVERT(decimal(12,2),0) END);
            SET @Codigo='VAL-'+@Sufijo;EXEC dbo.spRegistrarCompra @Codigo,@Proveedor,@Admin,@Lineas,@CompraNueva OUTPUT;
            EXEC dbo.spRecibirCompra @CompraNueva,@Admin;
            INSERT #I EXEC dbo.spListarInventarioApi @Admin,@BodegaID=@Bodega2;
            IF @Caso=44 AND NOT EXISTS(SELECT 1 FROM #I WHERE Existencia=5 AND CostoPromedio=0 AND ValorExistencia=0) THROW 52292,N'La recepción gratis no conserva ceros.',1;
            IF @Caso=45 AND NOT EXISTS(SELECT 1 FROM #I WHERE Existencia=2147483647 AND CostoPromedio=9999999999.990000 AND ValorExistencia=21474836469978525163.530000) THROW 52292,N'Se perdieron centavos en importe grande.',1;
        END;
        IF @Caso=49
        BEGIN
            INSERT #RI EXEC dbo.spResumenInventarioApi @Admin,@Buscar=N'NO-EXISTE-',@CategoriaID=@Categoria;
            IF NOT EXISTS(SELECT 1 FROM #RI WHERE Total=0 AND SinExistencia=0 AND StockBajo=0 AND ValorTotal=0) THROW 52292,N'El resumen vacío no es cero.',1;
        END;
        IF @Caso=51 AND (dbo.fnPromedioEntrada(8,12.25,6,20) IS NULL OR dbo.fnPromedioEntrada(8,12.25,6,20)<>15.571429)
            THROW 52292,N'El promedio 218/14 debe redondearse a 15.571429.',1;
        IF @Caso=52 AND (dbo.fnPromedioEntrada(2,1,1,2) IS NULL OR dbo.fnPromedioEntrada(2,1,1,2)<>1.333333)
            THROW 52292,N'El promedio 4/3 debe redondearse a 1.333333.',1;
        IF @Caso=53 AND (dbo.fnPromedioEntrada(1,0.000001,1,0) IS NULL OR dbo.fnPromedioEntrada(1,0.000001,1,0)<>0.000001)
            THROW 52292,N'Media millonésima debe redondearse hacia arriba.',1;
        IF @Caso=54 AND (dbo.fnPromedioEntrada(9223372036854775807,999999999999.999999,2147483647,0) IS NULL
                     OR dbo.fnPromedioEntrada(9223372036854775807,999999999999.999999,2147483647,0)<>999999999767.169356)
            THROW 52292,N'El promedio de valores máximos perdió precisión o desbordó.',1;
        IF @Esperado<>0 BEGIN SET @Resultado='FAIL';SET @Detalle=N'La operación inválida fue aceptada.';END;
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Detalle=ERROR_MESSAGE();
        IF @Preparado=0 OR @Esperado=0 OR ERROR_NUMBER()<>@Esperado SET @Resultado='FAIL';
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    END CATCH;
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
DROP TABLE #ResultadoOrden;DROP TABLE #I;DROP TABLE #K;DROP TABLE #RI;DROP TABLE #RK;DROP TABLE #CompraApi;
SELECT ID,Caso,Resultado,Detalle FROM @Resultados ORDER BY ID;
IF EXISTS(SELECT 1 FROM @Resultados WHERE Resultado='FAIL') THROW 52292,N'Una o más pruebas de inventario fallaron. Revisá los resultados.',1;
GO
