-- Compras, recepción y promedio móvil por bodega. Ejecutar después del 26.
-- Detener el backend mientras se instala. No reiniciar la base ni los datos.
USE [TechCare];
GO
SET NOCOUNT ON; SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.spGuardarRepuestoGestion',N'P') IS NULL
    THROW 52190,N'Ejecutá primero 26_Abastecimiento_Procedimientos.sql.',1;
GO
CREATE OR ALTER FUNCTION dbo.fnPromedioEntrada
(@Stock bigint,@Costo decimal(18,6),@Cantidad int,@CostoEntrada decimal(12,2))
RETURNS decimal(18,6) AS
BEGIN
    -- Los productos caben en decimal(37,6); su suma conserva seis decimales.
    RETURN CONVERT(decimal(18,6),
       (CONVERT(decimal(37,6),CONVERT(decimal(19,0),@Stock)*@Costo)
       +CONVERT(decimal(37,6),CONVERT(decimal(19,0),@Cantidad)*@CostoEntrada))
       /NULLIF(CONVERT(decimal(19,0),@Stock)+@Cantidad,0));
END;
GO
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Bloqueo bigint;
    SELECT @Bloqueo=COUNT_BIG(*) FROM dbo.Inventario WITH(TABLOCKX,HOLDLOCK);
    SELECT @Bloqueo=COUNT_BIG(*) FROM dbo.MovimientoInventario WITH(TABLOCKX,HOLDLOCK);
    IF COL_LENGTH(N'dbo.Inventario',N'CostoPromedio') IS NULL
        EXEC(N'ALTER TABLE dbo.Inventario ADD CostoPromedio decimal(18,6) NOT NULL CONSTRAINT DF_Inventario_CostoPromedio DEFAULT 0;');
    IF OBJECT_ID(N'dbo.ValoracionInventario',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.ValoracionInventario(
            MovimientoID bigint NOT NULL CONSTRAINT PK_ValoracionInventario PRIMARY KEY,
            CostoAnterior decimal(18,6) NOT NULL,CostoPosterior decimal(18,6) NOT NULL,
            EsMigracion bit NOT NULL,
            CONSTRAINT FK_ValoracionInventario_Movimiento FOREIGN KEY(MovimientoID) REFERENCES dbo.MovimientoInventario(MovimientoID),
            CONSTRAINT CK_ValoracionInventario_Costos CHECK(CostoAnterior>=0 AND CostoPosterior>=0));
    END;
    IF OBJECT_ID(N'dbo.SolicitudCompraApi',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.SolicitudCompraApi(
            SolicitudID uniqueidentifier NOT NULL CONSTRAINT PK_SolicitudCompraApi PRIMARY KEY,
            CompraID int NOT NULL CONSTRAINT UQ_SolicitudCompraApi_Compra UNIQUE,
            UsuarioID int NOT NULL,Firma binary(32) NOT NULL,
            CONSTRAINT FK_SolicitudCompraApi_Compra FOREIGN KEY(CompraID) REFERENCES dbo.Compra(CompraID),
            CONSTRAINT FK_SolicitudCompraApi_Usuario FOREIGN KEY(UsuarioID) REFERENCES dbo.Usuario(UsuarioID));
    END;
    IF OBJECT_ID(N'dbo.EventoCompraApi',N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.EventoCompraApi(
            CompraID int NOT NULL,Tipo varchar(12) NOT NULL,UsuarioID int NOT NULL,
            Responsable nvarchar(161) NOT NULL,Fecha datetime2(0) NOT NULL,
            Observacion nvarchar(1000) NULL,
            CONSTRAINT PK_EventoCompraApi PRIMARY KEY(CompraID,Tipo),
            CONSTRAINT FK_EventoCompraApi_Compra FOREIGN KEY(CompraID) REFERENCES dbo.Compra(CompraID),
            CONSTRAINT FK_EventoCompraApi_Usuario FOREIGN KEY(UsuarioID) REFERENCES dbo.Usuario(UsuarioID),
            CONSTRAINT CK_EventoCompraApi_Tipo CHECK(Tipo IN('REGISTRO','RECEPCION','ANULACION')));
    END;
    -- Se recorre el orden real del kardex, no el precio editable del catálogo.
    -- Las salidas históricas mantienen sus importes; sólo se inicializa el promedio futuro.
    IF EXISTS(SELECT 1 FROM dbo.MovimientoInventario m LEFT JOIN dbo.ValoracionInventario v ON v.MovimientoID=m.MovimientoID WHERE v.MovimientoID IS NULL)
        EXEC sys.sp_executesql N'
        CREATE TABLE #CostoInicial(BodegaID int,RepuestoID int,Stock bigint,Costo decimal(18,6),PRIMARY KEY(BodegaID,RepuestoID));
        INSERT #CostoInicial SELECT BodegaID,RepuestoID,0,0 FROM dbo.Inventario;
        DECLARE @M bigint,@B int,@R int,@Tipo char(1),@Cantidad int,@Entrada decimal(12,2),@Stock bigint,@Costo decimal(18,6),@Nuevo decimal(18,6),@Resultado bigint;
        DECLARE movimientos CURSOR LOCAL FAST_FORWARD FOR
          SELECT m.MovimientoID,m.BodegaID,m.RepuestoID,m.Tipo,m.Cantidad,d.CostoUnitario,m.ExistenciaResultante
          FROM dbo.vMovimientoInventario m LEFT JOIN dbo.DetalleCompra d ON d.CompraID=m.CompraID AND d.Linea=m.LineaCompra ORDER BY m.MovimientoID;
        OPEN movimientos;FETCH NEXT FROM movimientos INTO @M,@B,@R,@Tipo,@Cantidad,@Entrada,@Resultado;
        WHILE @@FETCH_STATUS=0
        BEGIN
          SET @Stock=NULL;SET @Costo=NULL;
          SELECT @Stock=Stock,@Costo=Costo FROM #CostoInicial WHERE BodegaID=@B AND RepuestoID=@R;
          IF @Stock IS NULL THROW 52191,N''Hay movimientos sin asociación de inventario. Revisá el kardex.'',1;
          SET @Nuevo=CASE WHEN @Tipo=''E'' THEN dbo.fnPromedioEntrada(@Stock,@Costo,@Cantidad,@Entrada) WHEN @Stock=@Cantidad THEN 0 ELSE @Costo END;
          SET @Stock=@Stock+CASE WHEN @Tipo=''E'' THEN CONVERT(bigint,@Cantidad) ELSE -CONVERT(bigint,@Cantidad) END;
          IF @Stock<>@Resultado OR @Stock<0 THROW 52191,N''El kardex requiere revisión antes de migrar los costos.'',1;
          IF NOT EXISTS(SELECT 1 FROM dbo.ValoracionInventario WHERE MovimientoID=@M)
             INSERT dbo.ValoracionInventario VALUES(@M,@Costo,@Nuevo,1);
          UPDATE #CostoInicial SET Stock=@Stock,Costo=@Nuevo WHERE BodegaID=@B AND RepuestoID=@R;
          FETCH NEXT FROM movimientos INTO @M,@B,@R,@Tipo,@Cantidad,@Entrada,@Resultado;
        END;
        CLOSE movimientos;DEALLOCATE movimientos;
        UPDATE i SET CostoPromedio=c.Costo FROM dbo.Inventario i JOIN #CostoInicial c ON c.BodegaID=i.BodegaID AND c.RepuestoID=i.RepuestoID;
        DROP TABLE #CostoInicial;';
    -- Se instala dentro de la misma transacción que inicializa la valoración.
    EXEC sys.sp_executesql N'
    CREATE OR ALTER TRIGGER dbo.trValorarMovimientoInventario ON dbo.MovimientoInventario AFTER INSERT AS
    BEGIN
      SET NOCOUNT ON;
      DECLARE @M bigint,@B int,@R int,@Tipo char(1),@Cantidad int,@Entrada decimal(12,2),@Stock bigint,@Costo decimal(18,6),@Nuevo decimal(18,6),@Salida decimal(12,2);
      DECLARE nuevos CURSOR LOCAL FAST_FORWARD FOR
        SELECT m.MovimientoID,m.BodegaID,m.RepuestoID,m.Tipo,m.Cantidad,d.CostoUnitario,
               m.ExistenciaResultante-m.CantidadFirmada,r.CostoUnitario
        FROM inserted n JOIN dbo.vMovimientoInventario m ON m.MovimientoID=n.MovimientoID
        LEFT JOIN dbo.DetalleCompra d ON d.CompraID=m.CompraID AND d.Linea=m.LineaCompra
        LEFT JOIN dbo.ReparacionRepuesto r ON r.ReparacionID=m.ReparacionID AND r.Linea=m.LineaReparacion ORDER BY m.MovimientoID;
      OPEN nuevos;FETCH NEXT FROM nuevos INTO @M,@B,@R,@Tipo,@Cantidad,@Entrada,@Stock,@Salida;
      WHILE @@FETCH_STATUS=0
      BEGIN
        SET @Costo=NULL;
        SELECT @Costo=CostoPromedio FROM dbo.Inventario WITH(UPDLOCK,HOLDLOCK) WHERE BodegaID=@B AND RepuestoID=@R;
        IF @Costo IS NULL OR @Stock<0 THROW 52101,N''Inventario sin valoración válida.'',1;
        IF @Tipo=''S'' AND @Salida<>CONVERT(decimal(12,2),@Costo)
           THROW 52103,N''El costo del consumo debe corresponder al promedio vigente de la bodega.'',1;
        SET @Nuevo=CASE WHEN @Tipo=''E'' THEN dbo.fnPromedioEntrada(@Stock,@Costo,@Cantidad,@Entrada) WHEN @Stock=@Cantidad THEN 0 ELSE @Costo END;
        UPDATE dbo.Inventario SET CostoPromedio=@Nuevo WHERE BodegaID=@B AND RepuestoID=@R;
        INSERT dbo.ValoracionInventario VALUES(@M,@Costo,@Nuevo,0);
        FETCH NEXT FROM nuevos INTO @M,@B,@R,@Tipo,@Cantidad,@Entrada,@Stock,@Salida;
      END;
      CLOSE nuevos;DEALLOCATE nuevos;
    END;';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
CREATE OR ALTER TRIGGER dbo.trValoracionInventarioInmutable ON dbo.ValoracionInventario AFTER UPDATE,DELETE AS
BEGIN SET NOCOUNT ON;IF EXISTS(SELECT 1 FROM deleted) THROW 52105,N'La valoración histórica no se modifica ni se borra.',1;END;
GO
CREATE OR ALTER TRIGGER dbo.trSolicitudCompraApiInmutable ON dbo.SolicitudCompraApi AFTER UPDATE,DELETE AS
BEGIN SET NOCOUNT ON;IF EXISTS(SELECT 1 FROM deleted) THROW 52105,N'La solicitud de una compra registrada es histórica.',1;END;
GO
CREATE OR ALTER TRIGGER dbo.trEventoCompraApiInmutable ON dbo.EventoCompraApi AFTER UPDATE,DELETE AS
BEGIN SET NOCOUNT ON;IF EXISTS(SELECT 1 FROM deleted) THROW 52105,N'Los responsables y eventos de compra son históricos.',1;END;
GO
CREATE OR ALTER VIEW dbo.vCompraApi AS
SELECT c.CompraID,c.NumeroCompra,c.ProveedorID,p.NIT,p.Nombre AS Proveedor,c.Fecha,c.Estado,c.FechaRecepcion,c.Observaciones,
       c.UsuarioRegistroID,COALESCE(er.Responsable,e.Nombres+N' '+e.Apellidos) AS RegistradaPor,
       ec.Responsable AS RecibidaPor,ea.Responsable AS AnuladaPor,ea.Fecha AS FechaAnulacion,ea.Observacion AS MotivoAnulacion,
       x.Lineas,x.Total,
       CONVERT(varchar(64),HASHBYTES('SHA2_256',CONCAT(CONVERT(nvarchar(max),c.CompraID),N'|',c.Estado,N'|',
         COALESCE(DATALENGTH(c.Observaciones),-1),N':',c.Observaciones,N'|',x.Firma)),2) AS Revision
FROM dbo.Compra c JOIN dbo.Proveedor p ON p.ProveedorID=c.ProveedorID
JOIN dbo.Usuario u ON u.UsuarioID=c.UsuarioRegistroID JOIN dbo.Empleado e ON e.EmpleadoID=u.EmpleadoID
LEFT JOIN dbo.EventoCompraApi er ON er.CompraID=c.CompraID AND er.Tipo='REGISTRO'
LEFT JOIN dbo.EventoCompraApi ec ON ec.CompraID=c.CompraID AND ec.Tipo='RECEPCION'
LEFT JOIN dbo.EventoCompraApi ea ON ea.CompraID=c.CompraID AND ea.Tipo='ANULACION'
CROSS APPLY(SELECT COUNT(*) AS Lineas,COALESCE(SUM(CONVERT(decimal(28,2),CONVERT(decimal(19,0),d.Cantidad)*d.CostoUnitario)),0) AS Total,
  STRING_AGG(CONVERT(nvarchar(max),CONCAT(d.Linea,N'|',d.BodegaID,N'|',d.RepuestoID,N'|',d.Cantidad,N'|',d.CostoUnitario)),N';') WITHIN GROUP(ORDER BY d.Linea) AS Firma
  FROM dbo.DetalleCompra d WHERE d.CompraID=c.CompraID)x;
GO
CREATE OR ALTER VIEW dbo.vRepuestoBodegaGestion AS
SELECT i.BodegaID,i.RepuestoID,r.Codigo,r.Nombre,r.Activo,i.StockMinimo,i.Existencia,iv.CostoPromedio
FROM dbo.vInventario i JOIN dbo.Repuesto r ON r.RepuestoID=i.RepuestoID JOIN dbo.Inventario iv ON iv.BodegaID=i.BodegaID AND iv.RepuestoID=i.RepuestoID;
GO
CREATE OR ALTER PROCEDURE dbo.spListarComprasApi
 @UsuarioActorID int,@Buscar nvarchar(max)=NULL,@Estado nvarchar(max)=NULL,@ProveedorID int=NULL,@Desde date=NULL,@Hasta date=NULL AS
BEGIN
 SET NOCOUNT ON;EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
 SET @Buscar=NULLIF(LTRIM(RTRIM(@Buscar)),N'');SET @Estado=NULLIF(@Estado,N'');
 IF DATALENGTH(@Buscar)>300 OR @ProveedorID<=0 OR (@Estado IS NOT NULL AND @Estado NOT IN('PENDIENTE','RECIBIDA','ANULADA')) OR @Desde>@Hasta
    THROW 52100,N'Revisá búsqueda, estado, proveedor y rango de fechas.',1;
 SELECT * FROM dbo.vCompraApi WHERE(@ProveedorID IS NULL OR ProveedorID=@ProveedorID) AND(@Estado IS NULL OR Estado=@Estado)
   AND(@Desde IS NULL OR CONVERT(date,Fecha)>=@Desde) AND(@Hasta IS NULL OR CONVERT(date,Fecha)<=@Hasta)
   AND(@Buscar IS NULL OR CHARINDEX(@Buscar,NumeroCompra)>0 OR CHARINDEX(@Buscar,Proveedor)>0 OR CHARINDEX(@Buscar,NIT)>0)
 ORDER BY Fecha DESC,CompraID DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spConsultarCompraApi @UsuarioActorID int,@CompraID int AS
BEGIN
 SET NOCOUNT ON;EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
 IF @CompraID IS NULL OR @CompraID<=0 THROW 52100,N'El ID de compra no es válido.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Compra WHERE CompraID=@CompraID) THROW 52102,N'La compra no existe.',1;
 SELECT * FROM dbo.vCompraApi WHERE CompraID=@CompraID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spDetalleCompraApi @UsuarioActorID int,@CompraID int AS
BEGIN
 SET NOCOUNT ON;EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
 IF NOT EXISTS(SELECT 1 FROM dbo.Compra WHERE CompraID=@CompraID) THROW 52102,N'La compra no existe.',1;
 SELECT d.Linea,d.BodegaID,b.Nombre AS Bodega,d.RepuestoID,r.Codigo,r.Nombre AS Repuesto,d.Cantidad,d.CostoUnitario,
   CONVERT(decimal(28,2),CONVERT(decimal(19,0),d.Cantidad)*d.CostoUnitario) AS Importe,
   i.Existencia,iv.CostoPromedio,m.MovimientoID,m.ExistenciaResultante,
   v.CostoAnterior,v.CostoPosterior,em.Nombres+N' '+em.Apellidos AS RecibidaPor
 FROM dbo.DetalleCompra d JOIN dbo.Bodega b ON b.BodegaID=d.BodegaID JOIN dbo.Repuesto r ON r.RepuestoID=d.RepuestoID
 JOIN dbo.vInventario i ON i.BodegaID=d.BodegaID AND i.RepuestoID=d.RepuestoID
 JOIN dbo.Inventario iv ON iv.BodegaID=d.BodegaID AND iv.RepuestoID=d.RepuestoID
 LEFT JOIN dbo.MovimientoInventario m ON m.CompraID=d.CompraID AND m.LineaCompra=d.Linea
 LEFT JOIN dbo.ValoracionInventario v ON v.MovimientoID=m.MovimientoID
 LEFT JOIN dbo.Usuario u ON u.UsuarioID=m.UsuarioID LEFT JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
 WHERE d.CompraID=@CompraID ORDER BY d.Linea;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spEventosCompraApi @UsuarioActorID int,@CompraID int AS
BEGIN
 SET NOCOUNT ON;EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
 IF NOT EXISTS(SELECT 1 FROM dbo.Compra WHERE CompraID=@CompraID) THROW 52102,N'La compra no existe.',1;
 SELECT Tipo,Responsable,Fecha,Observacion FROM dbo.EventoCompraApi WHERE CompraID=@CompraID ORDER BY Fecha,Tipo;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spDestinosCompraApi @UsuarioActorID int,@ProveedorID int AS
BEGIN
 SET NOCOUNT ON;EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
 IF NOT EXISTS(SELECT 1 FROM dbo.Proveedor WHERE ProveedorID=@ProveedorID AND Activo=1) THROW 52101,N'El proveedor debe estar activo.',1;
 SELECT r.RepuestoID,r.Codigo,r.Nombre AS Repuesto,b.BodegaID,b.Nombre AS Bodega,pr.CodigoProveedor,i.Existencia,i.StockMinimo,iv.CostoPromedio
 FROM dbo.ProveedorRepuesto pr JOIN dbo.Repuesto r ON r.RepuestoID=pr.RepuestoID
 JOIN dbo.vInventario i ON i.RepuestoID=r.RepuestoID JOIN dbo.Bodega b ON b.BodegaID=i.BodegaID
 JOIN dbo.Inventario iv ON iv.BodegaID=i.BodegaID AND iv.RepuestoID=i.RepuestoID
 WHERE pr.ProveedorID=@ProveedorID AND r.Activo=1 AND b.Activo=1 ORDER BY r.Nombre,r.RepuestoID,b.Nombre,b.BodegaID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spCostosRepuestoApi @UsuarioActorID int,@RepuestoID int AS
BEGIN
 SET NOCOUNT ON;EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
 IF NOT EXISTS(SELECT 1 FROM dbo.Repuesto WHERE RepuestoID=@RepuestoID) THROW 52102,N'El repuesto no existe.',1;
 SELECT b.BodegaID,b.Codigo,b.Nombre AS Bodega,b.Activo,i.Existencia,i.StockMinimo,iv.CostoPromedio
 FROM dbo.vInventario i JOIN dbo.Inventario iv ON iv.BodegaID=i.BodegaID AND iv.RepuestoID=i.RepuestoID JOIN dbo.Bodega b ON b.BodegaID=i.BodegaID
 WHERE i.RepuestoID=@RepuestoID ORDER BY b.Nombre,b.BodegaID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spRegistrarCompraApi
 @UsuarioActorID int,@SolicitudID nvarchar(max),@NumeroCompra nvarchar(max),@ProveedorID int,@Observaciones nvarchar(max),@Detalle nvarchar(max) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
 BEGIN TRY
  IF @Propia=1 BEGIN TRANSACTION;ELSE SAVE TRANSACTION APICompraRegistro;
  EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
  SET @NumeroCompra=NULLIF(LTRIM(RTRIM(@NumeroCompra)),N'');SET @Observaciones=NULLIF(LTRIM(RTRIM(@Observaciones)),N'');
  DECLARE @Solicitud uniqueidentifier=TRY_CONVERT(uniqueidentifier,@SolicitudID);
  IF @Solicitud IS NULL OR DATALENGTH(@SolicitudID)<>72 OR @NumeroCompra IS NULL OR DATALENGTH(@NumeroCompra)>60
    OR @NumeroCompra COLLATE Latin1_General_100_BIN2 LIKE N'%[^-0-9A-Za-z._/]%' OR @ProveedorID IS NULL OR @ProveedorID<=0
    OR DATALENGTH(@Observaciones)>2000 OR DATALENGTH(@Detalle)>200000 OR ISJSON(@Detalle)<>1 OR @Detalle IS NULL OR LEFT(LTRIM(@Detalle),1)<>N'['
    THROW 52100,N'Revisá solicitud, número de compra (30), proveedor, observaciones (1000) y detalle.',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Detalle)) NOT BETWEEN 1 AND 200 OR EXISTS(SELECT 1 FROM OPENJSON(@Detalle) WHERE type<>5)
    THROW 52100,N'La compra requiere entre 1 y 200 líneas válidas.',1;
  DECLARE @Crudo TABLE(Linea int,Bodega nvarchar(max),Repuesto nvarchar(max),Cantidad nvarchar(max),Costo nvarchar(max));
  INSERT @Crudo SELECT CONVERT(int,j.[key])+1,x.Bodega,x.Repuesto,x.Cantidad,x.Costo FROM OPENJSON(@Detalle)j
    CROSS APPLY OPENJSON(j.value) WITH(Bodega nvarchar(max) '$.bodegaId',Repuesto nvarchar(max) '$.repuestoId',Cantidad nvarchar(max) '$.cantidad',Costo nvarchar(max) '$.costoUnitario')x;
  IF EXISTS(SELECT 1 FROM @Crudo WHERE Bodega IS NULL OR Repuesto IS NULL OR Cantidad IS NULL OR Costo IS NULL OR LEN(Costo)=0
    OR Bodega COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%' OR Repuesto COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%'
    OR Cantidad COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%' OR Costo COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9.]%'
    OR TRY_CONVERT(int,Bodega) IS NULL OR TRY_CONVERT(int,Bodega)<=0 OR TRY_CONVERT(int,Repuesto) IS NULL OR TRY_CONVERT(int,Repuesto)<=0
    OR TRY_CONVERT(int,Cantidad) IS NULL OR TRY_CONVERT(int,Cantidad)<=0 OR TRY_CONVERT(decimal(12,2),Costo) IS NULL
    OR Costo LIKE N'%.%.%' OR (CHARINDEX(N'.',Costo)>0 AND LEN(Costo)-CHARINDEX(N'.',Costo)>2))
    THROW 52100,N'Cantidades e IDs deben ser enteros positivos; los costos admiten cero y hasta dos decimales.',1;
  DECLARE @Lineas dbo.TipoDetalleCompra;
  INSERT @Lineas SELECT Linea,CONVERT(int,Bodega),CONVERT(int,Repuesto),CONVERT(int,Cantidad),CONVERT(decimal(12,2),Costo) FROM @Crudo;
  IF EXISTS(SELECT 1 FROM @Lineas GROUP BY BodegaID,RepuestoID HAVING COUNT(*)>1)
    THROW 52100,N'No repitás el mismo repuesto y bodega en dos líneas.',1;
  DECLARE @Canon nvarchar(max)=(SELECT Linea,BodegaID,RepuestoID,Cantidad,CostoUnitario FROM @Lineas ORDER BY Linea FOR JSON PATH);
  DECLARE @Firma binary(32)=HASHBYTES('SHA2_256',CONCAT(CONVERT(nvarchar(max),DATALENGTH(@NumeroCompra)),N':',@NumeroCompra,N'|',@ProveedorID,N'|',
    COALESCE(DATALENGTH(@Observaciones),-1),N':',@Observaciones,N'|',@Canon)),@Anterior binary(32),@Actor int,@CompraID int;
  SELECT @CompraID=CompraID,@Anterior=Firma,@Actor=UsuarioID FROM dbo.SolicitudCompraApi WITH(UPDLOCK,HOLDLOCK) WHERE SolicitudID=@Solicitud;
  IF @CompraID IS NOT NULL
  BEGIN
    IF @Actor<>@UsuarioActorID OR @Anterior<>@Firma THROW 52103,N'La solicitud ya corresponde a otra compra o a otros datos. Revisá el listado.',1;
  END
  ELSE
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.Proveedor WITH(UPDLOCK,HOLDLOCK) WHERE ProveedorID=@ProveedorID AND Activo=1)
       THROW 52101,N'El proveedor debe estar activo.',1;
    IF EXISTS(SELECT 1 FROM @Lineas l LEFT JOIN dbo.Repuesto r WITH(HOLDLOCK) ON r.RepuestoID=l.RepuestoID
      LEFT JOIN dbo.Bodega b WITH(HOLDLOCK) ON b.BodegaID=l.BodegaID
      LEFT JOIN dbo.Inventario i WITH(HOLDLOCK) ON i.BodegaID=l.BodegaID AND i.RepuestoID=l.RepuestoID
      LEFT JOIN dbo.ProveedorRepuesto pr WITH(HOLDLOCK) ON pr.ProveedorID=@ProveedorID AND pr.RepuestoID=l.RepuestoID
      WHERE r.RepuestoID IS NULL OR r.Activo=0 OR b.BodegaID IS NULL OR b.Activo=0 OR i.RepuestoID IS NULL OR pr.RepuestoID IS NULL)
       THROW 52101,N'Cada repuesto debe estar activo, ofrecido por el proveedor y asociado a una bodega activa.',1;
    EXEC dbo.spRegistrarCompra @NumeroCompra,@ProveedorID,@UsuarioActorID,@Lineas,@CompraID OUTPUT,@Observaciones=@Observaciones;
    INSERT dbo.SolicitudCompraApi VALUES(@Solicitud,@CompraID,@UsuarioActorID,@Firma);
    INSERT dbo.EventoCompraApi SELECT @CompraID,'REGISTRO',u.UsuarioID,e.Nombres+N' '+e.Apellidos,c.Fecha,@Observaciones
      FROM dbo.Usuario u JOIN dbo.Empleado e ON e.EmpleadoID=u.EmpleadoID CROSS JOIN dbo.Compra c WHERE u.UsuarioID=@UsuarioActorID AND c.CompraID=@CompraID;
  END;
  IF @Propia=1 COMMIT TRANSACTION;
  SELECT * FROM dbo.vCompraApi WHERE CompraID=@CompraID;
 END TRY
 BEGIN CATCH
  IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION APICompraRegistro;
  THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spRecibirCompraApi @UsuarioActorID int,@CompraID int,@Revision nvarchar(max) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
 BEGIN TRY
  IF @Propia=1 BEGIN TRANSACTION;ELSE SAVE TRANSACTION APICompraRecepcion;
  EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
  DECLARE @Estado varchar(12),@Proveedor int,@Actual varchar(64);
  SELECT @Estado=Estado,@Proveedor=ProveedorID FROM dbo.Compra WITH(UPDLOCK,HOLDLOCK) WHERE CompraID=@CompraID;
  IF @Estado IS NULL THROW 52102,N'La compra no existe.',1;
  IF @Estado<>'PENDIENTE' THROW 52103,N'La compra ya fue recibida o anulada. Actualizá el expediente.',1;
  SELECT @Actual=Revision FROM dbo.vCompraApi WHERE CompraID=@CompraID;
  IF @Revision IS NULL OR DATALENGTH(@Revision)<>128 OR @Actual COLLATE Latin1_General_100_BIN2<>@Revision COLLATE Latin1_General_100_BIN2
     THROW 52103,N'La compra cambió. Volvé a revisar antes de recibir.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.Proveedor WITH(HOLDLOCK) WHERE ProveedorID=@Proveedor AND Activo=1) THROW 52101,N'Reactivá el proveedor antes de recibir su compra.',1;
  EXEC dbo.spRecibirCompra @CompraID,@UsuarioActorID;
  INSERT dbo.EventoCompraApi SELECT @CompraID,'RECEPCION',u.UsuarioID,e.Nombres+N' '+e.Apellidos,c.FechaRecepcion,NULL
    FROM dbo.Usuario u JOIN dbo.Empleado e ON e.EmpleadoID=u.EmpleadoID CROSS JOIN dbo.Compra c WHERE u.UsuarioID=@UsuarioActorID AND c.CompraID=@CompraID;
  IF @Propia=1 COMMIT TRANSACTION;
  SELECT * FROM dbo.vCompraApi WHERE CompraID=@CompraID;
 END TRY
 BEGIN CATCH
  IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION APICompraRecepcion;
  THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spAnularCompraApi @UsuarioActorID int,@CompraID int,@Revision nvarchar(max),@Motivo nvarchar(max) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
 BEGIN TRY
  IF @Propia=1 BEGIN TRANSACTION;ELSE SAVE TRANSACTION APICompraAnulacion;
  EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
  SET @Motivo=NULLIF(LTRIM(RTRIM(@Motivo)),N'');
  IF @Motivo IS NULL OR DATALENGTH(@Motivo)>2000 THROW 52100,N'Ingresá el motivo de anulación, hasta 1000 caracteres.',1;
  DECLARE @Estado varchar(12),@Actual varchar(64);
  SELECT @Estado=Estado FROM dbo.Compra WITH(UPDLOCK,HOLDLOCK) WHERE CompraID=@CompraID;
  IF @Estado IS NULL THROW 52102,N'La compra no existe.',1;
  IF @Estado<>'PENDIENTE' THROW 52103,N'Solo se anulan compras pendientes.',1;
  SELECT @Actual=Revision FROM dbo.vCompraApi WHERE CompraID=@CompraID;
  IF @Revision IS NULL OR DATALENGTH(@Revision)<>128 OR @Actual COLLATE Latin1_General_100_BIN2<>@Revision COLLATE Latin1_General_100_BIN2
     THROW 52103,N'La compra cambió. Volvé a revisar antes de anular.',1;
  IF EXISTS(SELECT 1 FROM dbo.MovimientoInventario WHERE CompraID=@CompraID) THROW 52103,N'La compra ya tiene entradas.',1;
  UPDATE dbo.Compra SET Estado='ANULADA' WHERE CompraID=@CompraID;
  INSERT dbo.EventoCompraApi SELECT @CompraID,'ANULACION',u.UsuarioID,e.Nombres+N' '+e.Apellidos,SYSUTCDATETIME(),@Motivo
    FROM dbo.Usuario u JOIN dbo.Empleado e ON e.EmpleadoID=u.EmpleadoID WHERE u.UsuarioID=@UsuarioActorID;
  IF @Propia=1 COMMIT TRANSACTION;
  SELECT * FROM dbo.vCompraApi WHERE CompraID=@CompraID;
 END TRY
 BEGIN CATCH
  IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION APICompraAnulacion;
  THROW;
 END CATCH;
END;
GO
-- Los consumos nuevos congelan el promedio vigente de su bodega.
CREATE OR ALTER PROCEDURE dbo.spConsumirRepuesto
    @ReparacionID int,@BodegaID int,@RepuestoID int,@Cantidad int,@UsuarioID int,@Fecha datetime2(0)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spConsumirRepuesto;

IF dbo.fnTieneRol(@UsuarioID,'TECNICO')=0 THROW 51014,N'Usuario sin rol técnico.',1;
IF @Cantidad IS NULL OR @Cantidad<=0 THROW 51015,N'Cantidad inválida.',1;
IF NOT EXISTS (SELECT 1 FROM dbo.Reparacion WITH (UPDLOCK,HOLDLOCK) WHERE ReparacionID=@ReparacionID AND Estado='EN_PROCESO') THROW 51016,N'Reparación no activa.',1;
DECLARE @Dummy int,@Stock bigint,@Linea smallint,@Costo decimal(12,2),@Precio decimal(12,2);
SELECT @Dummy=RepuestoID FROM dbo.Inventario WITH (UPDLOCK,HOLDLOCK) WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID;
IF @Dummy IS NULL THROW 51017,N'Repuesto sin registro en la bodega.',1;
SELECT @Costo=CONVERT(decimal(12,2),CostoPromedio) FROM dbo.Inventario WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID;
SELECT @Precio=PrecioVenta FROM dbo.Repuesto WITH(HOLDLOCK) WHERE RepuestoID=@RepuestoID AND Activo=1;
IF @Precio IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.Bodega WHERE BodegaID=@BodegaID AND Activo=1) THROW 51018,N'Repuesto/bodega inactivo.',1;
SET @Stock=dbo.fnExistencia(@BodegaID,@RepuestoID);
IF @Stock<@Cantidad THROW 51019,N'Stock insuficiente; no se aplicaron cambios.',1;
SELECT @Linea=CONVERT(smallint,COALESCE(MAX(Linea),0)+1) FROM dbo.ReparacionRepuesto WHERE ReparacionID=@ReparacionID;
INSERT dbo.ReparacionRepuesto (ReparacionID,Linea,BodegaID,RepuestoID,Cantidad,CostoUnitario,PrecioUnitario)
VALUES (@ReparacionID,@Linea,@BodegaID,@RepuestoID,@Cantidad,@Costo,@Precio);
INSERT dbo.MovimientoInventario (ReparacionID,LineaReparacion,Fecha,UsuarioID,ExistenciaResultante)
VALUES (@ReparacionID,@Linea,COALESCE(@Fecha,SYSUTCDATETIME()),@UsuarioID,@Stock-@Cantidad);
-- La salida disminuye inmediatamente vInventario; no existe un contador de stock editable.

 IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spConsumirRepuesto;
 THROW;
END CATCH;
END;
GO

-- Protección del costo de referencia legado, incluso si el cliente usa la API anterior.
CREATE OR ALTER PROCEDURE dbo.spGuardarRepuestoGestion
    @UsuarioActorID int,@RepuestoID int,@CategoriaID int,@Codigo nvarchar(max),@Nombre nvarchar(max),@Descripcion nvarchar(max),
    @CostoReferencia decimal(19,4),@PrecioVenta decimal(19,4),@Activo bit,@Revision nvarchar(max)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
    DECLARE @Contexto sql_variant=SESSION_CONTEXT(N'UsuarioID'),@ContextoCambiado bit=0;
    BEGIN TRY
        IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIRepuestoGestion;
        EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
        SET @Codigo=NULLIF(LTRIM(RTRIM(@Codigo)),N''); SET @Nombre=NULLIF(LTRIM(RTRIM(@Nombre)),N'');
        SET @Descripcion=NULLIF(LTRIM(RTRIM(@Descripcion)),N'');
        IF @RepuestoID<=0 OR (@RepuestoID IS NULL AND @Revision IS NOT NULL) OR @Activo IS NULL
           -- El guion literal va primero dentro del conjunto; no forma un rango con la barra.
           OR @Codigo IS NULL OR DATALENGTH(@Codigo)>60 OR @Codigo COLLATE Latin1_General_100_BIN2 LIKE N'%[^-0-9A-Za-z._/]%'
           OR @Nombre IS NULL OR DATALENGTH(@Nombre)>200 OR DATALENGTH(@Descripcion)>1000
            THROW 52000,N'Revisá código (30), nombre (100), descripción (500) y estado del repuesto.',1;
        IF @CostoReferencia IS NULL OR @PrecioVenta IS NULL OR @CostoReferencia<0 OR @PrecioVenta<0
           OR @CostoReferencia>9999999999.99 OR @PrecioVenta>9999999999.99
           OR ROUND(@CostoReferencia,2)<>@CostoReferencia OR ROUND(@PrecioVenta,2)<>@PrecioVenta
            THROW 52000,N'Los precios admiten valores desde cero y hasta dos decimales.',1;
        IF @CategoriaID IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.CategoriaRepuesto WITH (HOLDLOCK) WHERE CategoriaID=@CategoriaID)
            THROW 52001,N'La categoría del repuesto no existe.',1;
        -- Desde el bloque 30 el costo de inventario se calcula por bodega.
        IF ((@RepuestoID IS NULL AND @CostoReferencia<>0)
             OR (@RepuestoID IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.Repuesto WHERE RepuestoID=@RepuestoID AND CostoReferencia<>@CostoReferencia)))
            THROW 52000,N'El costo se calcula desde las compras recibidas por bodega. No se edita desde el catálogo.',1;
        IF @RepuestoID IS NULL
        BEGIN
            INSERT dbo.Repuesto(CategoriaID,Codigo,Nombre,Descripcion,CostoReferencia,PrecioVenta,Activo)
            VALUES (@CategoriaID,@Codigo,@Nombre,@Descripcion,@CostoReferencia,@PrecioVenta,@Activo);
            SET @RepuestoID=CONVERT(int,SCOPE_IDENTITY());
        END
        ELSE
        BEGIN
            DECLARE @Actual varchar(64),@BloqueoRepuesto int;
            SELECT @BloqueoRepuesto=RepuestoID FROM dbo.Repuesto WITH (UPDLOCK,HOLDLOCK) WHERE RepuestoID=@RepuestoID;
            SELECT @Actual=Revision FROM dbo.vRepuestoGestion WHERE RepuestoID=@RepuestoID;
            EXEC dbo.spValidarRevisionAbastecimiento @Actual,@Revision;
            -- El trigger existente registra al usuario autenticado que cambió costo/precio.
            EXEC sys.sp_set_session_context @key=N'UsuarioID',@value=@UsuarioActorID;
            SET @ContextoCambiado=1;
            UPDATE dbo.Repuesto SET CategoriaID=@CategoriaID,Codigo=@Codigo,Nombre=@Nombre,Descripcion=@Descripcion,
                CostoReferencia=@CostoReferencia,PrecioVenta=@PrecioVenta,Activo=@Activo WHERE RepuestoID=@RepuestoID;
            EXEC sys.sp_set_session_context @key=N'UsuarioID',@value=@Contexto;
            SET @ContextoCambiado=0;
        END;
        IF @Propia=1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vRepuestoGestion WHERE RepuestoID=@RepuestoID;
    END TRY
    BEGIN CATCH
        IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION APIRepuestoGestion;
        IF @ContextoCambiado=1 EXEC sys.sp_set_session_context @key=N'UsuarioID',@value=@Contexto;
        THROW;
    END CATCH;
END;
GO
IF DATABASE_PRINCIPAL_ID(N'techcare_app') IS NOT NULL
BEGIN
 GRANT EXECUTE ON SCHEMA::dbo TO techcare_app;
 DENY INSERT,UPDATE,DELETE ON dbo.Compra TO techcare_app;
 DENY INSERT,UPDATE,DELETE ON dbo.DetalleCompra TO techcare_app;
 DENY INSERT,UPDATE,DELETE ON dbo.Inventario TO techcare_app;
 DENY INSERT,UPDATE,DELETE ON dbo.ValoracionInventario TO techcare_app;
 DENY INSERT,UPDATE,DELETE ON dbo.SolicitudCompraApi TO techcare_app;
 DENY INSERT,UPDATE,DELETE ON dbo.EventoCompraApi TO techcare_app;
END;
GO
