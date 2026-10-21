-- Ejecutar después del 26 en DESARROLLO, sin otras escrituras concurrentes.
-- Datos propios por caso, ROLLBACK y verificación de cantidades antes/después.
-- Las identidades pueden dejar huecos. No es prueba entre sesiones concurrentes.
USE [TechCare];
GO
SET NOCOUNT ON; SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 52090,N'Ejecutá sin una transacción abierta.',1;
IF OBJECT_ID(N'dbo.spGuardarRepuestoGestion',N'P') IS NULL
    THROW 52090,N'Ejecutá primero 26_Abastecimiento_Procedimientos.sql.',1;
DECLARE @Admin int=(SELECT TOP (1) UsuarioID FROM dbo.Usuario WHERE dbo.fnTieneRol(UsuarioID,'ADMIN')=1 ORDER BY UsuarioID);
DECLARE @Modelo int=(SELECT TOP (1) ModeloEquipoID FROM dbo.ModeloEquipo ORDER BY ModeloEquipoID);
DECLARE @Tipo int=(SELECT TOP (1) TipoClienteID FROM dbo.TipoCliente ORDER BY TipoClienteID);
IF @Admin IS NULL OR @Modelo IS NULL OR @Tipo IS NULL THROW 52090,N'Se requiere ADMIN activo y catálogos base.',1;
DECLARE @ContextoInicial sql_variant=SESSION_CONTEXT(N'UsuarioID');
DECLARE @Casos TABLE (ID int PRIMARY KEY,Caso nvarchar(200),ErrorEsperado int);
INSERT @Casos VALUES
(1,N'Categoría conserva nombre Unicode',0),
(2,N'Categoría obligatoria',52000),
(3,N'Categoría larga no se trunca',52000),
(4,N'Categoría duplicada rechazada',2627),
(5,N'Renombrar categoría conserva sus repuestos',0),
(6,N'Categoría desactualizada rechazada',52003),
(7,N'Crear repuesto Unicode y precios cero no crea stock',0),
(8,N'Código de repuesto duplicado rechazado',2627),
(9,N'Categoría inexistente rechazada',52001),
(10,N'Precio negativo rechazado',52000),
(11,N'Precio con tres decimales rechazado',52000),
(12,N'Costo fuera de límite rechazado',52000),
(13,N'Nombre de repuesto largo rechazado',52000),
(14,N'Descripción de repuesto larga rechazada',52000),
(15,N'Código Unicode no se convierte a varchar',52000),
(16,N'Auditoría de precios conserva actor y contexto anterior',0),
(17,N'Cambiar solo el nombre no crea auditoría de precio',0),
(18,N'Repuesto desactualizado rechazado',52003),
(19,N'Desactivar repuesto conserva existencias e historia',0),
(20,N'Proveedor conserva nombre y dirección Unicode',0),
(21,N'NIT de proveedor duplicado rechazado',2627),
(22,N'Correo de proveedor inválido rechazado',52000),
(23,N'Teléfono largo rechazado',52000),
(24,N'Nombre de proveedor largo rechazado',52000),
(25,N'Proveedor desactualizado rechazado',52003),
(26,N'Desactivar proveedor conserva compras y asociaciones',0),
(27,N'Crear bodega no genera inventario ni movimientos',0),
(28,N'Código de bodega duplicado rechazado',2627),
(29,N'Dirección de bodega larga rechazada',52000),
(30,N'Bodega desactualizada rechazada',52003),
(31,N'Desactivar bodega conserva movimientos y existencias',0),
(32,N'Asociar oferta conserva código del proveedor',0),
(33,N'Oferta duplicada exige revisar la asociación',52003),
(34,N'Código de proveedor largo rechazado',52000),
(35,N'Proveedor inactivo no agrega ofertas',52001),
(36,N'Repuesto inactivo no agrega ofertas',52001),
(37,N'Editar referencia ofrecida conserva asociación única',0),
(38,N'Retirar oferta conserva compra ya recibida',0),
(39,N'Compra pendiente impide retirar oferta',52003),
(40,N'Asociar a bodega con mínimo cero conserva stock cero',0),
(41,N'Asociación existente exige mínimo esperado',52003),
(42,N'Actualizar mínimo no altera stock ni movimientos',0),
(43,N'Mínimo fraccionario rechazado',52000),
(44,N'Mínimo negativo rechazado',52000),
(45,N'Mínimo desactualizado rechazado',52003),
(46,N'Bodega inactiva no agrega asociaciones',52001),
(47,N'Técnico no consulta gestión de abastecimiento',52004),
(48,N'Recepción no modifica catálogos de bodega',52004),
(49,N'Caja no consulta catálogos de bodega',52004),
(50,N'Bodeguero inactivo rechazado',52004),
(51,N'ADMIN puede consultar abastecimiento',0),
(52,N'Repuesto inexistente devuelve error controlado',52002),
(53,N'Búsqueda trata porcentaje y guion bajo como texto literal',0),
(54,N'Cambiar precios no reescribe consumo ni factura histórica',0),
(55,N'Error de actualización restaura el contexto de auditoría',2627),
(56,N'Repuesto admite código de 30 caracteres',0),
(57,N'Bodega admite código de 20 caracteres',0),
(58,N'Código de repuesto con carácter no permitido rechazado',52000),
(59,N'Código de bodega con carácter no permitido rechazado',52000);
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
SELECT 'SolicitudPagoApi' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.SolicitudPagoApi;
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
DECLARE @Hash varchar(255)='$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik=';
WHILE @Caso<=59
BEGIN
    SELECT @Nombre=Caso,@Esperado=ErrorEsperado FROM @Casos WHERE ID=@Caso;
    SET @Resultado='PASS';SET @Detalle=NULL;SET @Preparado=0;
    SET @Sufijo=LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),8);
    DELETE FROM #ResultadoOrden;DELETE FROM #Repuestos;DELETE FROM #Categorias;DELETE FROM #Proveedores;
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

        IF @Caso=1
        BEGIN
            SET @Texto=N'Categoría ñ 漢字 '+@Sufijo;
            INSERT #Categorias EXEC dbo.spGuardarCategoriaRepuesto @Bodeguero,NULL,@Texto;
            IF NOT EXISTS(SELECT 1 FROM #Categorias WHERE Nombre=@Texto) THROW 52091,N'La categoría no conservó Unicode.',1;
        END;
        IF @Caso=2 EXEC dbo.spGuardarCategoriaRepuesto @Bodeguero,NULL,N' ';
        IF @Caso=3 BEGIN SET @Texto=REPLICATE(N'a',81);EXEC dbo.spGuardarCategoriaRepuesto @Bodeguero,NULL,@Texto;END;
        IF @Caso=4 EXEC dbo.spGuardarCategoriaRepuesto @Bodeguero,NULL,@CategoriaNombre;
        IF @Caso=5
        BEGIN
            SET @Texto=N'Categoría renombrada '+@Sufijo;
            INSERT #Categorias EXEC dbo.spGuardarCategoriaRepuesto @Bodeguero,@Categoria,@Texto,@RevC;
            IF NOT EXISTS(SELECT 1 FROM dbo.vRepuestoGestion WHERE RepuestoID=@Repuesto AND CategoriaID=@Categoria AND Categoria=@Texto)
                THROW 52091,N'El cambio perdió la categoría del repuesto.',1;
        END;
        IF @Caso=6
        BEGIN
            SET @Texto=N'Categoría cambiada '+@Sufijo;UPDATE dbo.CategoriaRepuesto SET Nombre=@Texto WHERE CategoriaID=@Categoria;
            EXEC dbo.spGuardarCategoriaRepuesto @Bodeguero,@Categoria,@CategoriaNombre,@RevC;
        END;
        IF @Caso=7
        BEGIN
            SET @Codigo='-R.1_2/3-'+@Sufijo+'-';
            INSERT #Repuestos EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,@Codigo,N'Fuente ñ 漢字',N'Descripción ñ 漢字',0,0,1;
            IF NOT EXISTS(SELECT 1 FROM #Repuestos WHERE Codigo=@Codigo AND Nombre=N'Fuente ñ 漢字' AND Descripcion=N'Descripción ñ 漢字' AND CostoReferencia=0 AND PrecioVenta=0)
               OR (SELECT COUNT_BIG(*) FROM dbo.Inventario)<>@Inventarios OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos
                THROW 52091,N'El alta no conservó datos o creó existencias.',1;
        END;
        IF @Caso=8 EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,@CodigoR,N'Duplicado',NULL,1,1,1;
        IF @Caso=9 EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,2147483647,N'INVALIDO',N'Prueba',NULL,1,1,1;
        IF @Caso=10 EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,N'INVALIDO',N'Prueba',NULL,1,-1,1;
        IF @Caso=11 EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,N'INVALIDO',N'Prueba',NULL,1,1.234,1;
        IF @Caso=12 EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,N'INVALIDO',N'Prueba',NULL,10000000000,1,1;
        IF @Caso=13 BEGIN SET @Texto=REPLICATE(N'a',101);EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,N'INVALIDO',@Texto,NULL,1,1,1;END;
        IF @Caso=14 BEGIN SET @Texto=REPLICATE(N'a',501);EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,N'INVALIDO',N'Prueba',@Texto,1,1,1;END;
        IF @Caso=15 EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,N'REP-漢字',N'Prueba',NULL,1,1,1;
        IF @Caso=16
        BEGIN
            INSERT #Repuestos EXEC dbo.spGuardarRepuestoGestion @Bodeguero,@Repuesto,@Categoria,@CodigoR,N'Fuente de prueba ñ',NULL,13.50,30,1,@RevR;
            IF NOT EXISTS(SELECT 1 FROM dbo.AuditoriaPrecioRepuesto WHERE RepuestoID=@Repuesto AND CostoAnterior=12.25 AND CostoNuevo=13.50
                          AND PrecioAnterior=25.50 AND PrecioNuevo=30 AND UsuarioAplicacionID=@Bodeguero)
                THROW 52091,N'La auditoría no conservó valores y usuario.',1;
        END;
        IF @Caso=17
        BEGIN
            INSERT #Repuestos EXEC dbo.spGuardarRepuestoGestion @Bodeguero,@Repuesto,@Categoria,@CodigoR,N'Nombre corregido ñ',NULL,12.25,25.50,1,@RevR;
            IF (SELECT COUNT_BIG(*) FROM dbo.AuditoriaPrecioRepuesto)<>@Auditorias THROW 52091,N'Se creó una auditoría sin cambio de precios.',1;
        END;
        IF @Caso=18
        BEGIN
            UPDATE dbo.Repuesto SET Nombre=N'Nombre cambiado' WHERE RepuestoID=@Repuesto;
            EXEC dbo.spGuardarRepuestoGestion @Bodeguero,@Repuesto,@Categoria,@CodigoR,N'Anterior',NULL,12.25,25.50,1,@RevR;
        END;
        IF @Caso=19
        BEGIN
            INSERT #Repuestos EXEC dbo.spGuardarRepuestoGestion @Bodeguero,@Repuesto,@Categoria,@CodigoR,N'Fuente de prueba ñ',NULL,12.25,25.50,0,@RevR;
            IF NOT EXISTS(SELECT 1 FROM dbo.vInventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto AND Existencia=10)
               OR NOT EXISTS(SELECT 1 FROM dbo.DetalleCompra WHERE CompraID=@Compra AND RepuestoID=@Repuesto)
                THROW 52091,N'La desactivación alteró existencias o compras.',1;
        END;
        IF @Caso=20
        BEGIN
            SET @Nit='NUEVO-'+@Sufijo;
            INSERT #Proveedores EXEC dbo.spGuardarProveedorGestion @Bodeguero,NULL,@Nit,N'Proveedor ñ 漢字',N' ',N' ',N'Dirección ñ 漢字',1;
            IF NOT EXISTS(SELECT 1 FROM #Proveedores WHERE Nombre=N'Proveedor ñ 漢字' AND Email IS NULL AND Telefono IS NULL AND Direccion=N'Dirección ñ 漢字')
                THROW 52091,N'El proveedor no conservó sus datos.',1;
        END;
        IF @Caso=21 EXEC dbo.spGuardarProveedorGestion @Bodeguero,NULL,@NitP,N'Duplicado',NULL,NULL,NULL,1;
        IF @Caso=22 EXEC dbo.spGuardarProveedorGestion @Bodeguero,NULL,N'INVALIDO',N'Prueba',N'correo-invalido',NULL,NULL,1;
        IF @Caso=23 BEGIN SET @Texto=REPLICATE(N'1',26);EXEC dbo.spGuardarProveedorGestion @Bodeguero,NULL,N'INVALIDO',N'Prueba',NULL,@Texto,NULL,1;END;
        IF @Caso=24 BEGIN SET @Texto=REPLICATE(N'a',151);EXEC dbo.spGuardarProveedorGestion @Bodeguero,NULL,N'INVALIDO',@Texto,NULL,NULL,NULL,1;END;
        IF @Caso=25
        BEGIN
            UPDATE dbo.Proveedor SET Nombre=N'Nombre cambiado' WHERE ProveedorID=@Proveedor;
            EXEC dbo.spGuardarProveedorGestion @Bodeguero,@Proveedor,@NitP,N'Anterior',NULL,NULL,NULL,1,@RevP;
        END;
        IF @Caso=26
        BEGIN
            INSERT #Proveedores EXEC dbo.spGuardarProveedorGestion @Bodeguero,@Proveedor,@NitP,N'Proveedor de prueba técnica',NULL,NULL,NULL,0,@RevP;
            IF NOT EXISTS(SELECT 1 FROM dbo.Compra WHERE CompraID=@Compra AND ProveedorID=@Proveedor)
               OR NOT EXISTS(SELECT 1 FROM dbo.ProveedorRepuesto WHERE ProveedorID=@Proveedor AND RepuestoID=@Repuesto)
                THROW 52091,N'La desactivación borró historia o asociaciones.',1;
        END;
        IF @Caso=27
        BEGIN
            SET @Codigo='-B.1_2/3-'+@Sufijo+'-';
            INSERT #Bodegas EXEC dbo.spGuardarBodegaGestion @Bodeguero,NULL,@Codigo,N'Bodega ñ 漢字',N'Dirección ñ',1;
            IF NOT EXISTS(SELECT 1 FROM #Bodegas WHERE Codigo=@Codigo AND Nombre=N'Bodega ñ 漢字') OR (SELECT COUNT_BIG(*) FROM dbo.Inventario)<>@Inventarios
               OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos THROW 52091,N'El alta de bodega alteró inventario.',1;
        END;
        IF @Caso=28 EXEC dbo.spGuardarBodegaGestion @Bodeguero,NULL,@CodigoB,N'Duplicado',NULL,1;
        IF @Caso=29 BEGIN SET @Texto=REPLICATE(N'a',251);EXEC dbo.spGuardarBodegaGestion @Bodeguero,NULL,N'INVALIDO',N'Prueba',@Texto,1;END;
        IF @Caso=30
        BEGIN
            UPDATE dbo.Bodega SET Nombre=N'Nombre cambiado' WHERE BodegaID=@Bodega;
            EXEC dbo.spGuardarBodegaGestion @Bodeguero,@Bodega,@CodigoB,N'Anterior',NULL,1,@RevB;
        END;
        IF @Caso=31
        BEGIN
            INSERT #Bodegas EXEC dbo.spGuardarBodegaGestion @Bodeguero,@Bodega,@CodigoB,N'Bodega técnica de prueba',NULL,0,@RevB;
            IF NOT EXISTS(SELECT 1 FROM dbo.vInventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto AND Existencia=10)
               OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos THROW 52091,N'La desactivación alteró el inventario.',1;
        END;
        IF @Caso=32
        BEGIN
            INSERT #Ofertas EXEC dbo.spGuardarOfertaProveedor @Bodeguero,@Proveedor,@Extra,N'REF-123',1;
            IF NOT EXISTS(SELECT 1 FROM #Ofertas WHERE RepuestoID=@Extra AND CodigoProveedor='REF-123') THROW 52091,N'La oferta no se registró.',1;
        END;
        IF @Caso=33 EXEC dbo.spGuardarOfertaProveedor @Bodeguero,@Proveedor,@Repuesto,N'DUPLICADO',1;
        IF @Caso=34 BEGIN SET @Texto=REPLICATE(N'a',51);EXEC dbo.spGuardarOfertaProveedor @Bodeguero,@Proveedor,@Extra,@Texto,1;END;
        IF @Caso=35 BEGIN UPDATE dbo.Proveedor SET Activo=0 WHERE ProveedorID=@Proveedor;EXEC dbo.spGuardarOfertaProveedor @Bodeguero,@Proveedor,@Extra,N'REF',1;END;
        IF @Caso=36 BEGIN UPDATE dbo.Repuesto SET Activo=0 WHERE RepuestoID=@Extra;EXEC dbo.spGuardarOfertaProveedor @Bodeguero,@Proveedor,@Extra,N'REF',1;END;
        IF @Caso=37
        BEGIN
            INSERT #Ofertas EXEC dbo.spGuardarOfertaProveedor @Bodeguero,@Proveedor,@Repuesto,N'NUEVA-REFERENCIA',1,@RevO;
            IF (SELECT COUNT(*) FROM dbo.ProveedorRepuesto WHERE ProveedorID=@Proveedor AND RepuestoID=@Repuesto)<>1
               OR NOT EXISTS(SELECT 1 FROM #Ofertas WHERE CodigoProveedor='NUEVA-REFERENCIA') THROW 52091,N'La edición duplicó o perdió la asociación.',1;
        END;
        IF @Caso=38
        BEGIN
            INSERT #Ofertas EXEC dbo.spGuardarOfertaProveedor @Bodeguero,@Proveedor,@Repuesto,NULL,0,@RevO;
            IF EXISTS(SELECT 1 FROM dbo.ProveedorRepuesto WHERE ProveedorID=@Proveedor AND RepuestoID=@Repuesto)
               OR NOT EXISTS(SELECT 1 FROM dbo.DetalleCompra WHERE CompraID=@Compra AND RepuestoID=@Repuesto)
                THROW 52091,N'El retiro no conservó la compra recibida.',1;
        END;
        IF @Caso=39
        BEGIN
            DELETE FROM @Lineas;INSERT @Lineas VALUES(1,@Bodega,@Repuesto,1,12.25);SET @Codigo='PEND-'+@Sufijo;
            EXEC dbo.spRegistrarCompra @Codigo,@Proveedor,@Admin,@Lineas,@CompraPendiente OUTPUT;
            EXEC dbo.spGuardarOfertaProveedor @Bodeguero,@Proveedor,@Repuesto,NULL,0,@RevO;
        END;
        IF @Caso=40
        BEGIN
            INSERT #Minimos EXEC dbo.spGuardarRepuestoBodega @Bodeguero,@Bodega,@Extra,0,NULL;
            IF NOT EXISTS(SELECT 1 FROM #Minimos WHERE RepuestoID=@Extra AND StockMinimo=0 AND Existencia=0)
               OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos THROW 52091,N'La asociación creó existencias o perdió el mínimo cero.',1;
        END;
        IF @Caso=41 EXEC dbo.spGuardarRepuestoBodega @Bodeguero,@Bodega,@Repuesto,5,NULL;
        IF @Caso=42
        BEGIN
            INSERT #Minimos EXEC dbo.spGuardarRepuestoBodega @Bodeguero,@Bodega,@Repuesto,5,2;
            IF NOT EXISTS(SELECT 1 FROM #Minimos WHERE StockMinimo=5 AND Existencia=10)
               OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos THROW 52091,N'El cambio de mínimo alteró el stock.',1;
        END;
        IF @Caso=43 EXEC dbo.spGuardarRepuestoBodega @Bodeguero,@Bodega,@Extra,1.5,NULL;
        IF @Caso=44 EXEC dbo.spGuardarRepuestoBodega @Bodeguero,@Bodega,@Extra,-1,NULL;
        IF @Caso=45 EXEC dbo.spGuardarRepuestoBodega @Bodeguero,@Bodega,@Repuesto,5,4;
        IF @Caso=46 BEGIN UPDATE dbo.Bodega SET Activo=0 WHERE BodegaID=@Bodega;EXEC dbo.spGuardarRepuestoBodega @Bodeguero,@Bodega,@Extra,1,NULL;END;
        IF @Caso=47 EXEC dbo.spListarRepuestosGestion @Tec1;
        IF @Caso=48 EXEC dbo.spGuardarCategoriaRepuesto @Recepcion,NULL,N'NO AUTORIZADA';
        IF @Caso=49 EXEC dbo.spListarProveedoresGestion @Caja;
        IF @Caso=50 BEGIN UPDATE dbo.Usuario SET Activo=0 WHERE UsuarioID=@Bodeguero;EXEC dbo.spListarBodegasGestion @Bodeguero;END;
        IF @Caso=51
        BEGIN
            INSERT #Repuestos EXEC dbo.spListarRepuestosGestion @Admin,@CodigoR;
            IF NOT EXISTS(SELECT 1 FROM #Repuestos WHERE RepuestoID=@Repuesto) THROW 52091,N'ADMIN no pudo consultar el catálogo.',1;
        END;
        IF @Caso=52 EXEC dbo.spConsultarRepuestoGestion @Bodeguero,2147483647;
        IF @Caso=53
        BEGIN
            SET @Texto=@Sufijo+N'%_';UPDATE dbo.Repuesto SET Nombre=@Texto WHERE RepuestoID=@Repuesto;
            INSERT #Repuestos EXEC dbo.spListarRepuestosGestion @Bodeguero,@Texto;
            IF (SELECT COUNT(*) FROM #Repuestos)<>1 OR NOT EXISTS(SELECT 1 FROM #Repuestos WHERE RepuestoID=@Repuesto)
                THROW 52091,N'La búsqueda no trató el texto de forma literal.',1;
        END;
        IF @Caso=54
        BEGIN
            INSERT #ResultadoOrden EXEC dbo.spRegistrarDiagnosticoOrden @Tec1,@Orden,N'Diagnóstico ñ',100;
            INSERT #ResultadoOrden EXEC dbo.spIniciarReparacionOrden @Tec1,@Orden,N'Cambiar fuente',100,N'Cliente autorizó';
            INSERT #ResultadoOrden EXEC dbo.spUsarRepuestoOrden @Tec1,@Orden,@Bodega,@Repuesto,1,25.50;
            INSERT #ResultadoOrden EXEC dbo.spFinalizarReparacionOrden @Tec1,@Orden;
            SET @Codigo='FACT-'+@Sufijo;EXEC dbo.spGenerarFactura @Orden,@Codigo,@Admin,@Factura OUTPUT;
            INSERT #Repuestos EXEC dbo.spGuardarRepuestoGestion @Bodeguero,@Repuesto,@Categoria,@CodigoR,N'Fuente de prueba ñ',NULL,13.50,30,1,@RevR;
            IF NOT EXISTS(SELECT 1 FROM dbo.ReparacionRepuesto rr JOIN dbo.Reparacion r ON r.ReparacionID=rr.ReparacionID JOIN dbo.Diagnostico d ON d.DiagnosticoID=r.DiagnosticoID
                          WHERE d.OrdenID=@Orden AND rr.CostoUnitario=12.25 AND rr.PrecioUnitario=25.50)
               OR NOT EXISTS(SELECT 1 FROM dbo.FacturaDetalle WHERE FacturaID=@Factura AND TipoConcepto='REP' AND PrecioUnitario=25.50)
               OR NOT EXISTS(SELECT 1 FROM dbo.vInventario WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto AND Existencia=9)
               OR (SELECT COUNT_BIG(*) FROM dbo.MovimientoInventario)<>@Movimientos+1
                THROW 52091,N'El cambio reescribió valores históricos.',1;
        END;
        IF @Caso=55 EXEC dbo.spGuardarRepuestoGestion @Bodeguero,@Repuesto,@Categoria,@ExtraCodigo,N'Duplicado',NULL,13.50,30,1,@RevR;
        IF @Caso=56
        BEGIN
            SET @Codigo='R-'+REPLICATE('A',19)+'-'+@Sufijo;
            INSERT #Repuestos EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,@Codigo,N'Código al límite',NULL,0,0,1;
            IF NOT EXISTS(SELECT 1 FROM #Repuestos WHERE Codigo=@Codigo AND DATALENGTH(Codigo)=30)
                THROW 52091,N'El código de 30 caracteres no se conservó.',1;
        END;
        IF @Caso=57
        BEGIN
            SET @Codigo='B-'+REPLICATE('A',9)+'-'+@Sufijo;
            INSERT #Bodegas EXEC dbo.spGuardarBodegaGestion @Bodeguero,NULL,@Codigo,N'Código al límite',NULL,1;
            IF NOT EXISTS(SELECT 1 FROM #Bodegas WHERE Codigo=@Codigo AND DATALENGTH(Codigo)=20)
                THROW 52091,N'El código de 20 caracteres no se conservó.',1;
        END;
        IF @Caso=58 EXEC dbo.spGuardarRepuestoGestion @Bodeguero,NULL,@Categoria,N'REP:INVALIDO',N'Prueba',NULL,1,1,1;
        IF @Caso=59 EXEC dbo.spGuardarBodegaGestion @Bodeguero,NULL,N'BOD:INVALIDO',N'Prueba',NULL,1;
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
SELECT 'SolicitudPagoApi' AS Nombre,COUNT_BIG(*) AS Cantidad FROM dbo.SolicitudPagoApi
    )
    SELECT @Resultado=CASE WHEN EXISTS(SELECT 1 FROM Despues d JOIN @Antes a ON a.Nombre=d.Nombre WHERE a.Cantidad<>d.Cantidad) THEN 'FAIL' ELSE @Resultado END;
    IF @Resultado='FAIL' AND @Detalle IS NULL SET @Detalle=N'La prueba dejó cantidades persistentes diferentes.';
    INSERT @Resultados VALUES(@Caso,@Nombre,@Resultado,@Detalle);SET @Caso+=1;
END;
DROP TABLE #ResultadoOrden;DROP TABLE #Repuestos;DROP TABLE #Categorias;DROP TABLE #Proveedores;DROP TABLE #Bodegas;DROP TABLE #Ofertas;DROP TABLE #Minimos;
SELECT ID,Caso,Resultado,Detalle FROM @Resultados ORDER BY ID;
IF EXISTS(SELECT 1 FROM @Resultados WHERE Resultado='FAIL') THROW 52092,N'Una o más pruebas de abastecimiento fallaron. Revisá los resultados.',1;
GO
