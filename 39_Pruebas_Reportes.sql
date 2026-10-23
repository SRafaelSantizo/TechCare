-- Ejecutar después del 38 en DESARROLLO, sin otras escrituras concurrentes.
-- Datos propios por caso, ROLLBACK y verificación de cantidades antes/después.
-- Las identidades pueden dejar huecos. No es prueba entre sesiones concurrentes.
USE [TechCare];
GO
SET NOCOUNT ON; SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 52090,N'Ejecutá sin una transacción abierta.',1;
IF OBJECT_ID(N'dbo.spConsultarReporteApi',N'P') IS NULL
    THROW 52090,N'Ejecutá primero 38_Reportes_Procedimientos.sql.',1;
DECLARE @Admin int=(SELECT TOP (1) UsuarioID FROM dbo.Usuario WHERE dbo.fnTieneRol(UsuarioID,'ADMIN')=1 ORDER BY UsuarioID);
DECLARE @Modelo int=(SELECT TOP (1) ModeloEquipoID FROM dbo.ModeloEquipo ORDER BY ModeloEquipoID);
DECLARE @Tipo int=(SELECT TOP (1) TipoClienteID FROM dbo.TipoCliente ORDER BY TipoClienteID);
IF @Admin IS NULL OR @Modelo IS NULL OR @Tipo IS NULL THROW 52090,N'Se requiere ADMIN activo y catálogos base.',1;
DECLARE @ContextoInicial sql_variant=SESSION_CONTEXT(N'UsuarioID');
DECLARE @Casos TABLE(ID int PRIMARY KEY,Caso nvarchar(200),ErrorEsperado int);
INSERT @Casos VALUES
(1,N'R01 muestra al técnico asignado antes del diagnóstico',0),
(2,N'R02 conserva cliente sin equipos ni órdenes',0),
(3,N'R03 conserva equipo sin servicio',0),
(4,N'R04 devuelve diagnóstico y reparación como procesos distintos',0),
(5,N'R05 usa costos y precios históricos por consumo',0),
(6,N'R06 usa promedio por bodega y stock del kardex',0),
(7,N'R07 incluye asociación vacía con mínimo cero',0),
(8,N'R08 incluye pendientes sin convertirlas en entradas',0),
(9,N'R09 presenta tres movimientos con sus saldos históricos',0),
(10,N'R10 presenta los dos abonos de una sola factura',0),
(11,N'R11 factura una vez sin multiplicar por abonos o repuestos',0),
(12,N'R12 conserva listas independientes de estados, repuestos y pagos',0),
(13,N'Resumen R10 cuenta factura y saldo una vez',0),
(14,N'R12 conserva orden sin diagnóstico ni factura',0),
(15,N'R02 conserva equipos sin órdenes junto a los atendidos',0),
(16,N'Técnico consulta únicamente su historial en R03',0),
(17,N'Técnico consulta únicamente sus órdenes en R01',0),
(18,N'Técnico no pide el reporte de otro técnico',52304),
(19,N'R04 de técnico conserva sólo sus procesos',0),
(20,N'R05 de técnico conserva sólo sus consumos',0),
(21,N'Reasignación retira la orden del reporte del técnico anterior',0),
(22,N'Recepción no consulta saldos de caja',52304),
(23,N'Bodega no consulta ingresos facturados',52304),
(24,N'Caja no consulta costos de inventario',52304),
(25,N'Técnico no consulta trazabilidad administrativa',52304),
(26,N'Recepción consulta historial de cliente',0),
(27,N'Bodega consulta compras de su proveedor',0),
(28,N'Caja consulta facturas pendientes',0),
(29,N'Cuenta inactiva no obtiene catálogo',52304),
(30,N'Empleado inactivo no obtiene catálogo',52304),
(31,N'ADMIN obtiene doce reportes',0),
(32,N'Técnico obtiene cuatro reportes',0),
(33,N'Bodega obtiene cinco reportes',0),
(34,N'Recepción obtiene tres reportes',0),
(35,N'Caja obtiene dos reportes',0),
(36,N'Código de reporte inexistente rechazado',52302),
(37,N'ID negativo rechazado',52300),
(38,N'Filtro ajeno al reporte rechazado',52300),
(39,N'Fechas invertidas rechazadas',52300),
(40,N'Serie larga rechazada sin truncar',52300),
(41,N'Página cero rechazada',52300),
(42,N'Tamaño superior a cien rechazado',52300),
(43,N'Estado de compra inválido rechazado',52300),
(44,N'Opciones de técnico no revelan otros técnicos',0),
(45,N'Porcentaje en búsqueda de opciones es literal',0),
(46,N'Guion bajo en búsqueda de opciones es literal',0),
(47,N'Búsqueda larga de opciones rechazada',52300),
(48,N'Factura pagada deja de aparecer como pendiente',0),
(49,N'Ingreso mensual excluye facturas anuladas',0),
(50,N'Día UTC de factura está incluido en el rango',0),
(51,N'Rango sin facturas devuelve cero filas',0),
(52,N'Paginación no altera el resumen de consumos',0),
(53,N'Categoría negativa rechazada',52300),
(54,N'Retirar rol revoca acceso al reporte',52304),
(55,N'Proveedor inactivo conserva compras y opción histórica',0),
(56,N'Bodega inactiva conserva inventario',0),
(57,N'Cambiar cliente y precios no reescribe la factura ni consumo',0),
(58,N'Consultas no alteran stock, promedio ni contexto',0),
(59,N'Último día del año 9999 no desborda',0),
(60,N'JSON conserva importes e IDs como texto y fechas UTC',0),
(61,N'R12 conserva reparación sólo con mano de obra y sin factura',0),
(62,N'R12 conserva factura sin abonos con listas vacías',0),
(63,N'R12 combina órdenes completas e incompletas sin perder filas',0);
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
SELECT TOP(0) * INTO #ResultadoOrden FROM dbo.vOrdenAcceso;
CREATE TABLE #R01([OrdenID] int NULL,[NumeroOrden] nvarchar(max) NULL,[FechaIngreso] datetime2(0) NULL,[Estado] nvarchar(max) NULL,[Prioridad] nvarchar(max) NULL,[Cliente] nvarchar(max) NULL,[NumeroSerie] nvarchar(max) NULL,[Tecnico] nvarchar(max) NULL,[ReparacionID] int NULL);
CREATE TABLE #R02([ClienteID] int NULL,[NIT] nvarchar(max) NULL,[Cliente] nvarchar(max) NULL,[NumeroSerie] nvarchar(max) NULL,[OrdenID] int NULL,[NumeroOrden] nvarchar(max) NULL,[FechaIngreso] datetime2(0) NULL,[EstadoCodigo] nvarchar(max) NULL,[Diagnostico] nvarchar(max) NULL,[DescripcionTrabajo] nvarchar(max) NULL,[NumeroFactura] nvarchar(max) NULL,[Total] decimal(38,2) NULL,[Saldo] decimal(38,2) NULL,[FechaEntrega] datetime2(0) NULL);
CREATE TABLE #R03([EquipoID] int NULL,[NumeroSerie] nvarchar(max) NULL,[Cliente] nvarchar(max) NULL,[Tipo] nvarchar(max) NULL,[Marca] nvarchar(max) NULL,[Modelo] nvarchar(max) NULL,[OrdenID] int NULL,[NumeroOrden] nvarchar(max) NULL,[EstadoCodigo] nvarchar(max) NULL,[FechaDiagnostico] datetime2(0) NULL,[Diagnostico] nvarchar(max) NULL,[FechaInicio] datetime2(0) NULL,[FechaFin] datetime2(0) NULL,[DescripcionTrabajo] nvarchar(max) NULL,[Tecnico] nvarchar(max) NULL);
CREATE TABLE #R04([Proceso] nvarchar(max) NULL,[RegistroID] int NULL,[Fecha] datetime2(0) NULL,[OrdenID] int NULL,[NumeroOrden] nvarchar(max) NULL,[NumeroSerie] nvarchar(max) NULL,[Cliente] nvarchar(max) NULL,[UsuarioID] int NULL,[Tecnico] nvarchar(max) NULL,[Trabajo] nvarchar(max) NULL,[ManoObra] decimal(38,2) NULL);
CREATE TABLE #R05([OrdenID] int NULL,[NumeroOrden] nvarchar(max) NULL,[Tecnico] nvarchar(max) NULL,[Bodega] nvarchar(max) NULL,[Codigo] nvarchar(max) NULL,[Repuesto] nvarchar(max) NULL,[Cantidad] int NULL,[CostoUnitario] decimal(38,2) NULL,[PrecioUnitario] decimal(38,2) NULL,[CostoHistorico] decimal(38,2) NULL,[VentaHistorica] decimal(38,2) NULL,[MovimientoID] bigint NULL,[Fecha] datetime2(0) NULL);
CREATE TABLE #R06([BodegaID] int NULL,[Bodega] nvarchar(max) NULL,[Categoria] nvarchar(max) NULL,[Codigo] nvarchar(max) NULL,[Repuesto] nvarchar(max) NULL,[Existencia] bigint NULL,[StockMinimo] int NULL,[Faltante] bigint NULL,[EstadoStock] nvarchar(max) NULL,[CostoPromedio] decimal(18,6) NULL,[ValorExistencia] decimal(38,6) NULL,[BodegaActiva] bit NULL,[RepuestoActivo] bit NULL);
CREATE TABLE #R07([BodegaID] int NULL,[Bodega] nvarchar(max) NULL,[Categoria] nvarchar(max) NULL,[Codigo] nvarchar(max) NULL,[Repuesto] nvarchar(max) NULL,[Existencia] bigint NULL,[StockMinimo] int NULL,[Faltante] bigint NULL,[EstadoStock] nvarchar(max) NULL,[CostoPromedio] decimal(18,6) NULL,[ValorExistencia] decimal(38,6) NULL,[BodegaActiva] bit NULL,[RepuestoActivo] bit NULL);
CREATE TABLE #R08([CompraID] int NULL,[Proveedor] nvarchar(max) NULL,[NumeroCompra] nvarchar(max) NULL,[Fecha] datetime2(0) NULL,[Estado] nvarchar(max) NULL,[Linea] smallint NULL,[Codigo] nvarchar(max) NULL,[Repuesto] nvarchar(max) NULL,[Destino] nvarchar(max) NULL,[Cantidad] int NULL,[CostoUnitario] decimal(38,2) NULL,[CostoLinea] decimal(38,2) NULL,[RegistradoPor] nvarchar(max) NULL);
CREATE TABLE #R09([MovimientoID] bigint NULL,[Fecha] datetime2(0) NULL,[Tipo] nvarchar(max) NULL,[Bodega] nvarchar(max) NULL,[Codigo] nvarchar(max) NULL,[Repuesto] nvarchar(max) NULL,[Cantidad] int NULL,[CantidadFirmada] bigint NULL,[ExistenciaResultante] bigint NULL,[DocumentoOrigen] nvarchar(max) NULL,[Proveedor] nvarchar(max) NULL,[Responsable] nvarchar(max) NULL,[CostoUnitario] decimal(38,2) NULL,[CostoPosterior] decimal(18,6) NULL);
CREATE TABLE #R10([FacturaID] int NULL,[NumeroFactura] nvarchar(max) NULL,[Cliente] nvarchar(max) NULL,[NumeroOrden] nvarchar(max) NULL,[Subtotal] decimal(38,2) NULL,[Impuesto] decimal(38,2) NULL,[Total] decimal(38,2) NULL,[Pagado] decimal(38,2) NULL,[Saldo] decimal(38,2) NULL,[PagoID] bigint NULL,[FechaPago] datetime2(0) NULL,[Monto] decimal(38,2) NULL,[Metodo] nvarchar(max) NULL,[Cajero] nvarchar(max) NULL);
CREATE TABLE #R11([Mes] date NULL,[CantidadFacturas] bigint NULL,[ManoObra] decimal(38,2) NULL,[Repuestos] decimal(38,2) NULL,[Impuesto] decimal(38,2) NULL,[TotalFacturado] decimal(38,2) NULL);
CREATE TABLE #R12([OrdenID] int NULL,[NumeroOrden] nvarchar(max) NULL,[FechaIngreso] datetime2(0) NULL,[EstadoCodigo] nvarchar(max) NULL,[ProblemaReportado] nvarchar(max) NULL,[NIT] nvarchar(max) NULL,[Cliente] nvarchar(max) NULL,[NumeroSerie] nvarchar(max) NULL,[Recepcion] nvarchar(max) NULL,[TecnicoDiagnostico] nvarchar(max) NULL,[FechaDiagnostico] datetime2(0) NULL,[Diagnostico] nvarchar(max) NULL,[DescripcionTrabajo] nvarchar(max) NULL,[FechaInicio] datetime2(0) NULL,[FechaFin] datetime2(0) NULL,[TecnicoReparacion] nvarchar(max) NULL,[NumeroFactura] nvarchar(max) NULL,[EstadoFactura] nvarchar(max) NULL,[NombreFacturacion] nvarchar(max) NULL,[Subtotal] decimal(38,2) NULL,[Impuesto] decimal(38,2) NULL,[Total] decimal(38,2) NULL,[Pagado] decimal(38,2) NULL,[Saldo] decimal(38,2) NULL,[NombreRecibe] nvarchar(max) NULL,[FechaEntrega] datetime2(0) NULL,[HistorialEstados] nvarchar(max) NULL,[RepuestosYMovimientos] nvarchar(max) NULL,[Pagos] nvarchar(max) NULL);
CREATE TABLE #S05(Total bigint,CostoHistoricoTotal decimal(38,2),VentaHistoricaTotal decimal(38,2));
CREATE TABLE #S10(Total bigint,Facturas bigint,TotalFacturado decimal(38,2),PagadoTotal decimal(38,2),SaldoTotal decimal(38,2));
CREATE TABLE #Cat(Codigo nvarchar(3));
CREATE TABLE #Opciones(Valor nvarchar(30),Etiqueta nvarchar(max));
DECLARE @Resultados TABLE(ID int,Caso nvarchar(200),Resultado varchar(4),Detalle nvarchar(4000));
DECLARE @Caso int=1,@Esperado int,@Nombre nvarchar(200),@Resultado varchar(4),@Detalle nvarchar(4000),@Preparado bit;
DECLARE @Sufijo varchar(8),@Codigo varchar(30),@Usuario varchar(50),@Nit varchar(20),@Serie varchar(80),@Texto nvarchar(max),@Json nvarchar(max);
DECLARE @Cliente int,@Equipo int,@Empleado int,@Tec1 int,@Tec2 int,@Recepcion int,@Orden int,@Categoria int,@Repuesto int,@Bodega int,@Proveedor int,@Compra int,@Actividad int;
DECLARE @Bodeguero int,@Caja int,@Extra int,@ExtraCodigo varchar(30),@Bodega2 int,@CompraNueva int;
DECLARE @ClienteVacio int,@EquipoVacio int,@Orden2 int,@Reparacion int,@Factura int,@Factura2 int,@Metodo tinyint;
DECLARE @Movimientos bigint,@Stock bigint,@Promedio decimal(18,6),@Lineas dbo.TipoDetalleCompra;
DECLARE @Hoy date,@Ayer date,@Manana date,@SerieVacia varchar(80),@CodigoReporte nvarchar(3),@Actor int;
DECLARE @Hash varchar(255)='$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik=';
SELECT TOP(1) @Metodo=MetodoPagoID FROM dbo.MetodoPago ORDER BY MetodoPagoID;
IF @Metodo IS NULL THROW 52390,N'Se requiere un medio de pago.',1;
WHILE @Caso<=(SELECT MAX(ID) FROM @Casos)
BEGIN
 SELECT @Nombre=Caso,@Esperado=ErrorEsperado FROM @Casos WHERE ID=@Caso;
 SET @Resultado='PASS';SET @Detalle=NULL;SET @Preparado=0;
 SET @Hoy=CONVERT(date,SYSUTCDATETIME());SET @Ayer=DATEADD(day,-1,@Hoy);SET @Manana=DATEADD(day,1,@Hoy);
 SET @Sufijo=LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),8);
 DELETE #ResultadoOrden;DELETE #Cat;DELETE #Opciones;DELETE #S05;DELETE #S10;DELETE @Lineas;
DELETE #R01; DELETE #R02; DELETE #R03; DELETE #R04; DELETE #R05; DELETE #R06; DELETE #R07; DELETE #R08; DELETE #R09; DELETE #R10; DELETE #R11; DELETE #R12;
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
 EXEC sys.sp_set_session_context @key=N'UsuarioID',@value=@Admin;
 SET @Nit='VAC-'+@Sufijo;INSERT dbo.Cliente(TipoClienteID,NIT,Nombre,Activo) VALUES(@Tipo,@Nit,N'Cliente sin órdenes ñ',1);SET @ClienteVacio=CONVERT(int,SCOPE_IDENTITY());
 SET @SerieVacia='VAC-'+@Sufijo;
 INSERT dbo.Equipo(ClienteID,ModeloEquipoID,NumeroSerie,Descripcion,Activo) VALUES(@Cliente,@Modelo,@SerieVacia,N'Sin servicio',1);SET @EquipoVacio=CONVERT(int,SCOPE_IDENTITY());
 SET @Codigo='OTRA-'+@Sufijo;EXEC dbo.spCrearOrden @Codigo,@Equipo,@Admin,N'Otra orden',@Orden2 OUTPUT;
 INSERT #ResultadoOrden EXEC dbo.spAsignarTecnicoOrden @Admin,@Orden2,@Tec2;
 INSERT #ResultadoOrden EXEC dbo.spRegistrarDiagnosticoOrden @Tec1,@Orden,N'Diagnóstico ñ 漢字',0;
 INSERT #ResultadoOrden EXEC dbo.spIniciarReparacionOrden @Tec1,@Orden,N'Trabajo ñ 漢字',20,N'Autorización ñ';
 INSERT #ResultadoOrden EXEC dbo.spUsarRepuestoOrden @Tec1,@Orden,@Bodega,@Repuesto,1,25.50;
 INSERT #ResultadoOrden EXEC dbo.spUsarRepuestoOrden @Tec1,@Orden,@Bodega,@Repuesto,1,25.50;
 SELECT @Reparacion=ReparacionID FROM dbo.vOrdenAcceso WHERE OrdenID=@Orden;
 EXEC dbo.spCerrarReparacion @Reparacion,@Tec1;
 SET @Codigo='FAC-'+@Sufijo;EXEC dbo.spGenerarFactura @Orden,@Codigo,@Caja,@Factura OUTPUT,0.12;
 EXEC dbo.spRegistrarPago @Factura,@Metodo,20,@Caja,N'Abono uno ñ';
 EXEC dbo.spRegistrarPago @Factura,@Metodo,10,@Caja,N'Abono dos ñ';
 DELETE @Lineas;INSERT @Lineas VALUES(1,@Bodega,@Repuesto,2,20);
 SET @Codigo='PEND-'+@Sufijo;EXEC dbo.spRegistrarCompra @Codigo,@Proveedor,@Bodeguero,@Lineas,@CompraNueva OUTPUT;
 SELECT @Movimientos=COUNT_BIG(*) FROM dbo.MovimientoInventario;
 SET @Stock=dbo.fnExistencia(@Bodega,@Repuesto);SELECT @Promedio=CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto;
 SET @Preparado=1;
 IF @Caso=1
 BEGIN
  INSERT #R01 EXEC dbo.spConsultarReporteApi @Admin,N'R01',@TecnicoID=@Tec2;
  IF (SELECT COUNT(*) FROM #R01)<>1 OR NOT EXISTS(SELECT 1 FROM #R01 WHERE OrdenID=@Orden2 AND Tecnico=N'Técnico Dos' AND ReparacionID IS NULL) THROW 52392,N'Falta el técnico asignado antes del diagnóstico.',1;
 END;
 IF @Caso=2 BEGIN INSERT #R02 EXEC dbo.spConsultarReporteApi @Admin,N'R02',@ClienteID=@ClienteVacio;IF (SELECT COUNT(*) FROM #R02)<>1 OR EXISTS(SELECT 1 FROM #R02 WHERE OrdenID IS NOT NULL) THROW 52392,N'Se perdió el cliente sin órdenes.',1;END;
 IF @Caso=3 BEGIN INSERT #R03 EXEC dbo.spConsultarReporteApi @Admin,N'R03',@Serie=@SerieVacia;IF (SELECT COUNT(*) FROM #R03)<>1 OR EXISTS(SELECT 1 FROM #R03 WHERE OrdenID IS NOT NULL) THROW 52392,N'Se perdió el equipo sin servicio.',1;END;
 IF @Caso=4 BEGIN INSERT #R04 EXEC dbo.spConsultarReporteApi @Admin,N'R04',@TecnicoID=@Tec1;IF (SELECT COUNT(*) FROM #R04)<>2 OR NOT EXISTS(SELECT 1 FROM #R04 WHERE Proceso='DIAGNOSTICO' AND Trabajo=N'Diagnóstico ñ 漢字') OR NOT EXISTS(SELECT 1 FROM #R04 WHERE Proceso='REPARACION' AND ManoObra=20) THROW 52392,N'Procesos técnicos incorrectos.',1;END;
 IF @Caso=5 BEGIN INSERT #R05 EXEC dbo.spConsultarReporteApi @Admin,N'R05',@OrdenID=@Orden;IF (SELECT COUNT(*) FROM #R05)<>2 OR EXISTS(SELECT 1 FROM #R05 WHERE Cantidad<>1 OR CostoUnitario<>12.25 OR PrecioUnitario<>25.50) THROW 52392,N'El consumo perdió sus valores históricos.',1;END;
 IF @Caso=6 BEGIN INSERT #R06 EXEC dbo.spConsultarReporteApi @Admin,N'R06',@BodegaID=@Bodega;IF NOT EXISTS(SELECT 1 FROM #R06 WHERE Existencia=8 AND CostoPromedio=12.25 AND ValorExistencia=98) THROW 52392,N'Inventario o valoración incorrecta.',1;END;
 IF @Caso=7 BEGIN INSERT #R07 EXEC dbo.spConsultarReporteApi @Admin,N'R07',@BodegaID=@Bodega2;IF NOT EXISTS(SELECT 1 FROM #R07 WHERE Existencia=0 AND StockMinimo=0 AND Faltante=0) THROW 52392,N'Falta asociación vacía en alerta.',1;END;
 IF @Caso=8 BEGIN INSERT #R08 EXEC dbo.spConsultarReporteApi @Admin,N'R08',@ProveedorID=@Proveedor;IF (SELECT COUNT(*) FROM #R08)<>2 OR NOT EXISTS(SELECT 1 FROM #R08 WHERE Estado='PENDIENTE') OR dbo.fnExistencia(@Bodega,@Repuesto)<>8 THROW 52392,N'Compras pendientes o stock incorrectos.',1;END;
 IF @Caso=9 BEGIN INSERT #R09 EXEC dbo.spConsultarReporteApi @Admin,N'R09',@RepuestoID=@Repuesto;IF (SELECT COUNT(*) FROM #R09)<>3 OR NOT EXISTS(SELECT 1 FROM #R09 WHERE Tipo='S' AND ExistenciaResultante=8 AND CostoUnitario=12.25) THROW 52392,N'Kardex incorrecto.',1;END;
 IF @Caso IN(10,28)
 BEGIN
  INSERT #R10 EXEC dbo.spConsultarReporteApi @Caja,N'R10',@ClienteID=@Cliente;
  IF (SELECT COUNT(*) FROM #R10)<>2 OR EXISTS(SELECT 1 FROM #R10 WHERE Total<>79.52 OR Saldo<>49.52) THROW 52392,N'Abonos o saldo incorrectos.',1;
 END;
 IF @Caso IN(11,50,59)
 BEGIN
  SELECT @Hoy=CONVERT(date,Fecha) FROM dbo.Factura WHERE FacturaID=@Factura;
  IF @Caso=59 INSERT #R11 EXEC dbo.spConsultarReporteApi @Caja,N'R11',@ClienteID=@Cliente,@Hasta='99991231';
  ELSE INSERT #R11 EXEC dbo.spConsultarReporteApi @Caja,N'R11',@ClienteID=@Cliente,@Desde=@Hoy,@Hasta=@Hoy;
  IF (SELECT COUNT(*) FROM #R11)<>1 OR NOT EXISTS(SELECT 1 FROM #R11 WHERE CantidadFacturas=1 AND ManoObra=20 AND Repuestos=51 AND Impuesto=8.52 AND TotalFacturado=79.52) THROW 52392,N'El ingreso mensual se duplicó o perdió importes.',1;
 END;
 IF @Caso IN(12,60)
 BEGIN
  INSERT #R12 EXEC dbo.spConsultarReporteApi @Admin,N'R12',@OrdenID=@Orden;
  IF (SELECT COUNT(*) FROM #R12)<>1 THROW 52392,N'R12 multiplicó las órdenes.',1;
  SELECT @Json=RepuestosYMovimientos FROM #R12;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>2 THROW 52392,N'R12 multiplicó repuestos por pagos.',1;
  IF @Caso=60 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$[0]') WHERE [key]='CostoUnitario' AND [type]=1) THROW 52392,N'El costo JSON no es texto exacto.',1;
  IF @Caso=60 AND RIGHT(JSON_VALUE(@Json,'$[0].Fecha'),1)<>'Z' THROW 52392,N'La fecha JSON perdió UTC.',1;
  SELECT @Json=Pagos FROM #R12;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>2 THROW 52392,N'R12 multiplicó pagos por repuestos.',1;
  IF @Caso=60 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$[0]') WHERE [key]='Monto' AND [type]=1) THROW 52392,N'El monto JSON no es texto exacto.',1;
 END;
 IF @Caso=13
 BEGIN
  INSERT #S10 EXEC dbo.spConsultarReporteApi @Caja,N'R10',@ClienteID=@Cliente,@SoloResumen=1;
  IF NOT EXISTS(SELECT 1 FROM #S10 WHERE Total=2 AND Facturas=1 AND TotalFacturado=79.52 AND PagadoTotal=30 AND SaldoTotal=49.52) THROW 52392,N'El resumen financiero duplicó factura o saldo.',1;
 END;
 IF @Caso=14
 BEGIN
  INSERT #R12 EXEC dbo.spConsultarReporteApi @Admin,N'R12',@OrdenID=@Orden2;
  IF (SELECT COUNT(*) FROM #R12)<>1 OR NOT EXISTS(SELECT 1 FROM #R12 WHERE OrdenID=@Orden2)
   THROW 52392,N'R12 no conservó una fila para la orden incompleta solicitada.',1;
  IF EXISTS(SELECT 1 FROM #R12 WHERE Diagnostico IS NOT NULL OR FechaDiagnostico IS NOT NULL OR DescripcionTrabajo IS NOT NULL OR NumeroFactura IS NOT NULL OR Total IS NOT NULL)
   THROW 52392,N'La orden incompleta presenta datos de una etapa inexistente.',1;
  IF EXISTS(SELECT 1 FROM #R12 WHERE ISNULL(RepuestosYMovimientos,N'<NULL>')<>N'[]')
   THROW 52392,N'Una orden sin reparación debe devolver repuestos como [] y no NULL.',1;
  IF EXISTS(SELECT 1 FROM #R12 WHERE ISNULL(Pagos,N'<NULL>')<>N'[]')
   THROW 52392,N'Una orden sin factura debe devolver pagos como [] y no NULL.',1;
  IF EXISTS(SELECT 1 FROM #R12 WHERE ISNULL(ISJSON(HistorialEstados),0)<>1 OR HistorialEstados=N'[]')
   THROW 52392,N'La orden incompleta perdió su historial de ingreso y asignación.',1;
 END;
 IF @Caso IN(15,26) BEGIN INSERT #R02 EXEC dbo.spConsultarReporteApi @Recepcion,N'R02',@ClienteID=@Cliente;IF (SELECT COUNT(*) FROM #R02)<>3 OR NOT EXISTS(SELECT 1 FROM #R02 WHERE OrdenID IS NULL AND NumeroSerie=@SerieVacia) THROW 52392,N'El historial de cliente omitió equipos sin órdenes.',1;END;
 IF @Caso=16 BEGIN INSERT #R03 EXEC dbo.spConsultarReporteApi @Tec1,N'R03',@Serie=@Serie;IF (SELECT COUNT(*) FROM #R03)<>1 OR EXISTS(SELECT 1 FROM #R03 WHERE OrdenID<>@Orden) THROW 52392,N'R03 reveló otra orden al técnico.',1;END;
 IF @Caso=17 BEGIN INSERT #R01 EXEC dbo.spConsultarReporteApi @Tec1,N'R01';IF (SELECT COUNT(*) FROM #R01)<>1 OR EXISTS(SELECT 1 FROM #R01 WHERE OrdenID<>@Orden) THROW 52392,N'R01 reveló trabajo ajeno.',1;END;
 IF @Caso=18 EXEC dbo.spConsultarReporteApi @Tec1,N'R04',@TecnicoID=@Tec2;
 IF @Caso=19 BEGIN INSERT #R04 EXEC dbo.spConsultarReporteApi @Tec1,N'R04';IF (SELECT COUNT(*) FROM #R04)<>2 OR EXISTS(SELECT 1 FROM #R04 WHERE OrdenID<>@Orden) THROW 52392,N'R04 reveló trabajo ajeno.',1;END;
 IF @Caso=20 BEGIN INSERT #R05 EXEC dbo.spConsultarReporteApi @Tec1,N'R05';IF (SELECT COUNT(*) FROM #R05)<>2 OR EXISTS(SELECT 1 FROM #R05 WHERE OrdenID<>@Orden) THROW 52392,N'R05 reveló consumos ajenos.',1;END;
 IF @Caso=21 BEGIN INSERT #ResultadoOrden EXEC dbo.spAsignarTecnicoOrden @Admin,@Orden2,@Tec1,@Tec2;INSERT #R01 EXEC dbo.spConsultarReporteApi @Tec2,N'R01';IF EXISTS(SELECT 1 FROM #R01) THROW 52392,N'La reasignación no retiró el acceso.',1;END;
 IF @Caso=22 EXEC dbo.spConsultarReporteApi @Recepcion,N'R10';
 IF @Caso=23 EXEC dbo.spConsultarReporteApi @Bodeguero,N'R11';
 IF @Caso=24 EXEC dbo.spConsultarReporteApi @Caja,N'R06';
 IF @Caso=25 EXEC dbo.spConsultarReporteApi @Tec1,N'R12';
 IF @Caso=27 BEGIN INSERT #R08 EXEC dbo.spConsultarReporteApi @Bodeguero,N'R08',@ProveedorID=@Proveedor;IF (SELECT COUNT(*) FROM #R08)<>2 THROW 52392,N'Bodega no obtuvo compras.',1;END;
 IF @Caso=29 BEGIN UPDATE dbo.Usuario SET Activo=0 WHERE UsuarioID=@Bodeguero;EXEC dbo.spCatalogoReportesApi @Bodeguero;END;
 IF @Caso=30 BEGIN UPDATE dbo.Empleado SET Activo=0 WHERE EmpleadoID=(SELECT EmpleadoID FROM dbo.Usuario WHERE UsuarioID=@Tec1);EXEC dbo.spCatalogoReportesApi @Tec1;END;
 IF @Caso BETWEEN 31 AND 35
 BEGIN
  SET @Actor=CASE @Caso WHEN 31 THEN @Admin WHEN 32 THEN @Tec1 WHEN 33 THEN @Bodeguero WHEN 34 THEN @Recepcion ELSE @Caja END;
  INSERT #Cat EXEC dbo.spCatalogoReportesApi @Actor;
  IF (SELECT COUNT(*) FROM #Cat)<>CASE @Caso WHEN 31 THEN 12 WHEN 32 THEN 4 WHEN 33 THEN 5 WHEN 34 THEN 3 ELSE 2 END THROW 52392,N'Catálogo de reportes no corresponde al rol.',1;
 END;
 IF @Caso=36 EXEC dbo.spConsultarReporteApi @Admin,N'R99';
 IF @Caso=37 EXEC dbo.spConsultarReporteApi @Admin,N'R01',@TecnicoID=-1;
 IF @Caso=38 EXEC dbo.spConsultarReporteApi @Admin,N'R11',@BodegaID=@Bodega;
 IF @Caso=39 EXEC dbo.spConsultarReporteApi @Admin,N'R01',@Desde=@Hoy,@Hasta=@Ayer;
 IF @Caso=40 BEGIN SET @Texto=REPLICATE(N'a',81);EXEC dbo.spConsultarReporteApi @Admin,N'R03',@Serie=@Texto;END;
 IF @Caso=41 EXEC dbo.spConsultarReporteApi @Admin,N'R01',@Pagina=0;
 IF @Caso=42 EXEC dbo.spConsultarReporteApi @Admin,N'R01',@Tamano=101;
 IF @Caso=43 EXEC dbo.spConsultarReporteApi @Admin,N'R08',@Estado=N'INVALIDO';
 IF @Caso=44 BEGIN INSERT #Opciones EXEC dbo.spOpcionesReporteApi @Tec1,N'R04',N'tecnicoId';IF (SELECT COUNT(*) FROM #Opciones)<>1 OR EXISTS(SELECT 1 FROM #Opciones WHERE Valor<>CONVERT(nvarchar(20),@Tec1)) THROW 52392,N'Las opciones revelaron otro técnico.',1;END;
 IF @Caso IN(45,46)
 BEGIN
  SET @Texto=CONCAT(N'Bus',CASE @Caso WHEN 45 THEN N'%' ELSE N'_' END,@Sufijo);
  UPDATE dbo.Proveedor SET Nombre=@Texto WHERE ProveedorID=@Proveedor;
  SET @Nit='P2-'+@Sufijo;INSERT dbo.Proveedor(NIT,Nombre,Activo) VALUES(@Nit,CONCAT(N'BusZ',@Sufijo),1);
  INSERT #Opciones EXEC dbo.spOpcionesReporteApi @Bodeguero,N'R08',N'proveedorId',@Texto;
  IF (SELECT COUNT(*) FROM #Opciones)<>1 OR NOT EXISTS(SELECT 1 FROM #Opciones WHERE Valor=CONVERT(nvarchar(20),@Proveedor)) THROW 52392,N'La búsqueda trató caracteres como comodines.',1;
 END;
 IF @Caso=47 BEGIN SET @Texto=REPLICATE(N'a',151);EXEC dbo.spOpcionesReporteApi @Admin,N'R08',N'proveedorId',@Texto;END;
 IF @Caso=48 BEGIN EXEC dbo.spRegistrarPago @Factura,@Metodo,49.52,@Caja;INSERT #R10 EXEC dbo.spConsultarReporteApi @Caja,N'R10',@ClienteID=@Cliente;IF EXISTS(SELECT 1 FROM #R10) THROW 52392,N'Factura pagada sigue pendiente.',1;END;
 IF @Caso=49
 BEGIN
  INSERT #ResultadoOrden EXEC dbo.spRegistrarDiagnosticoOrden @Tec2,@Orden2,N'Otro diagnóstico',0;
  INSERT #ResultadoOrden EXEC dbo.spIniciarReparacionOrden @Tec2,@Orden2,N'Otro trabajo',10,N'Autorizado';
  SELECT @Reparacion=ReparacionID FROM dbo.vOrdenAcceso WHERE OrdenID=@Orden2;EXEC dbo.spCerrarReparacion @Reparacion,@Tec2;
  SET @Codigo='ANU-'+@Sufijo;EXEC dbo.spGenerarFactura @Orden2,@Codigo,@Caja,@Factura2 OUTPUT,0.12;
  UPDATE dbo.Factura SET Estado='ANULADA' WHERE FacturaID=@Factura2;
  INSERT #R11 EXEC dbo.spConsultarReporteApi @Caja,N'R11',@ClienteID=@Cliente;
  IF NOT EXISTS(SELECT 1 FROM #R11 WHERE CantidadFacturas=1 AND TotalFacturado=79.52) THROW 52392,N'El ingreso incluyó factura anulada.',1;
 END;
 IF @Caso=51 BEGIN INSERT #R11 EXEC dbo.spConsultarReporteApi @Caja,N'R11',@ClienteID=@Cliente,@Desde=@Manana;IF EXISTS(SELECT 1 FROM #R11) THROW 52392,N'El rango vacío devolvió facturas.',1;END;
 IF @Caso=52 BEGIN INSERT #R05 EXEC dbo.spConsultarReporteApi @Admin,N'R05',@OrdenID=@Orden,@Pagina=2,@Tamano=1;INSERT #S05 EXEC dbo.spConsultarReporteApi @Admin,N'R05',@OrdenID=@Orden,@SoloResumen=1;IF (SELECT COUNT(*) FROM #R05)<>1 OR NOT EXISTS(SELECT 1 FROM #S05 WHERE Total=2 AND CostoHistoricoTotal=24.50 AND VentaHistoricaTotal=51) THROW 52392,N'La página alteró los totales.',1;END;
 IF @Caso=53 EXEC dbo.spConsultarReporteApi @Admin,N'R06',@CategoriaID=-1;
 IF @Caso=54 BEGIN DELETE dbo.UsuarioRol WHERE UsuarioID=@Tec1 AND RolCodigo='TECNICO';EXEC dbo.spConsultarReporteApi @Tec1,N'R01';END;
 IF @Caso=55
 BEGIN
  UPDATE dbo.Proveedor SET Activo=0 WHERE ProveedorID=@Proveedor;
  INSERT #R08 EXEC dbo.spConsultarReporteApi @Bodeguero,N'R08',@ProveedorID=@Proveedor;
  IF (SELECT COUNT(*) FROM #R08)<>2 THROW 52392,N'Se perdió historia de proveedor inactivo.',1;
  SET @Texto=CONCAT(N'TCAB-P-',@Sufijo);
  INSERT #Opciones EXEC dbo.spOpcionesReporteApi @Bodeguero,N'R08',N'proveedorId',@Texto;
  IF NOT EXISTS(SELECT 1 FROM #Opciones WHERE Valor=CONVERT(nvarchar(20),@Proveedor) AND Etiqueta LIKE N'%inactivo%') THROW 52392,N'Falta la opción del proveedor inactivo.',1;
 END;
 IF @Caso=56 BEGIN UPDATE dbo.Bodega SET Activo=0 WHERE BodegaID=@Bodega;INSERT #R06 EXEC dbo.spConsultarReporteApi @Bodeguero,N'R06',@BodegaID=@Bodega;IF NOT EXISTS(SELECT 1 FROM #R06 WHERE BodegaActiva=0 AND Existencia=8) THROW 52392,N'Se perdió inventario de bodega inactiva.',1;END;
 IF @Caso=57
 BEGIN
  UPDATE dbo.Cliente SET Nombre=N'Cliente posterior' WHERE ClienteID=@Cliente;
  UPDATE dbo.Repuesto SET PrecioVenta=99 WHERE RepuestoID=@Repuesto;
  INSERT #R05 EXEC dbo.spConsultarReporteApi @Admin,N'R05',@OrdenID=@Orden;
  INSERT #R12 EXEC dbo.spConsultarReporteApi @Admin,N'R12',@OrdenID=@Orden;
  IF EXISTS(SELECT 1 FROM #R05 WHERE PrecioUnitario<>25.50) OR NOT EXISTS(SELECT 1 FROM #R12 WHERE Total=79.52 AND NombreFacturacion=N'Cliente de prueba técnica') THROW 52392,N'Se reescribió historia financiera.',1;
 END;
 IF @Caso=58
 BEGIN
  INSERT #R06 EXEC dbo.spConsultarReporteApi @Admin,N'R06',@BodegaID=@Bodega;
  INSERT #R12 EXEC dbo.spConsultarReporteApi @Admin,N'R12',@OrdenID=@Orden;
  INSERT #S10 EXEC dbo.spConsultarReporteApi @Caja,N'R10',@ClienteID=@Cliente,@SoloResumen=1;
  IF dbo.fnExistencia(@Bodega,@Repuesto)<>@Stock OR (SELECT CostoPromedio FROM dbo.Inventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto)<>@Promedio
   OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos OR TRY_CONVERT(int,SESSION_CONTEXT(N'UsuarioID'))<>@Admin THROW 52392,N'La consulta modificó datos o contexto.',1;
 END;
 IF @Caso IN(61,62)
 BEGIN
  INSERT #ResultadoOrden EXEC dbo.spRegistrarDiagnosticoOrden @Tec2,@Orden2,N'Diagnóstico sin repuestos ñ',0;
  INSERT #ResultadoOrden EXEC dbo.spIniciarReparacionOrden @Tec2,@Orden2,N'Sólo mano de obra ñ',10,N'Autorizado';
  SELECT @Reparacion=ReparacionID FROM dbo.vOrdenAcceso WHERE OrdenID=@Orden2;
  EXEC dbo.spCerrarReparacion @Reparacion,@Tec2;
  IF @Caso=62
  BEGIN
   SET @Codigo='SINP-'+@Sufijo;
   EXEC dbo.spGenerarFactura @Orden2,@Codigo,@Caja,@Factura2 OUTPUT,0.12;
  END;
  INSERT #R12 EXEC dbo.spConsultarReporteApi @Admin,N'R12',@OrdenID=@Orden2;
  IF (SELECT COUNT(*) FROM #R12)<>1 OR NOT EXISTS(SELECT 1 FROM #R12 WHERE OrdenID=@Orden2 AND Diagnostico=N'Diagnóstico sin repuestos ñ' AND DescripcionTrabajo=N'Sólo mano de obra ñ' AND FechaFin IS NOT NULL)
   THROW 52392,N'Se perdió la reparación sin repuestos.',1;
  IF EXISTS(SELECT 1 FROM #R12 WHERE ISNULL(RepuestosYMovimientos,N'<NULL>')<>N'[]' OR ISNULL(Pagos,N'<NULL>')<>N'[]')
   THROW 52392,N'Las colecciones sin registros deben ser [] incluso si existe su etapa.',1;
  IF @Caso=61 AND EXISTS(SELECT 1 FROM #R12 WHERE NumeroFactura IS NOT NULL OR Total IS NOT NULL)
   THROW 52392,N'La orden sin factura inventó importes fiscales.',1;
  IF @Caso=62 AND NOT EXISTS(SELECT 1 FROM #R12 WHERE NumeroFactura=@Codigo AND Total=11.20 AND Pagado=0 AND Saldo=11.20)
   THROW 52392,N'La factura sin abonos perdió su total o saldo.',1;
 END;
 IF @Caso=63
 BEGIN
  INSERT #R12 EXEC dbo.spConsultarReporteApi @Admin,N'R12',@ClienteID=@Cliente;
  IF (SELECT COUNT(*) FROM #R12)<>2 OR (SELECT COUNT(DISTINCT OrdenID) FROM #R12)<>2
   THROW 52392,N'La consulta mixta perdió o duplicó órdenes.',1;
  IF NOT EXISTS(SELECT 1 FROM #R12 WHERE OrdenID=@Orden2 AND Diagnostico IS NULL AND NumeroFactura IS NULL AND Pagos=N'[]' AND RepuestosYMovimientos=N'[]')
   THROW 52392,N'La orden incompleta no conservó las colecciones vacías junto a otra completa.',1;
  SELECT @Json=RepuestosYMovimientos FROM #R12 WHERE OrdenID=@Orden;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>2 THROW 52392,N'La consulta mixta alteró los consumos de la orden completa.',1;
  SELECT @Json=Pagos FROM #R12 WHERE OrdenID=@Orden;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>2 THROW 52392,N'La consulta mixta alteró los abonos de la orden completa.',1;
 END;
 IF @Esperado<>0 BEGIN SET @Resultado='FAIL';SET @Detalle=N'La operación inválida fue aceptada.';END;
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 END TRY
 BEGIN CATCH
  SET @Detalle=ERROR_MESSAGE();IF @Preparado=0 OR @Esperado=0 OR ERROR_NUMBER()<>@Esperado SET @Resultado='FAIL';
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
DROP TABLE #ResultadoOrden;DROP TABLE #Cat;DROP TABLE #Opciones;DROP TABLE #S05;DROP TABLE #S10;
DROP TABLE #R01; DROP TABLE #R02; DROP TABLE #R03; DROP TABLE #R04; DROP TABLE #R05; DROP TABLE #R06; DROP TABLE #R07; DROP TABLE #R08; DROP TABLE #R09; DROP TABLE #R10; DROP TABLE #R11; DROP TABLE #R12;
SELECT ID,Caso,Resultado,Detalle FROM @Resultados ORDER BY ID;
IF EXISTS(SELECT 1 FROM @Resultados WHERE Resultado='FAIL') THROW 52392,N'Una o más pruebas de reportes fallaron. Revisá los resultados.',1;
GO
