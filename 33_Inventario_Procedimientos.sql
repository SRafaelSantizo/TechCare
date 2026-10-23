-- Inventario y kardex de consulta. Ejecutar completo después del 30.
-- No inserta ni modifica existencias, movimientos, costos o documentos.
USE [TechCare];
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.ValoracionInventario',N'U') IS NULL
   OR COL_LENGTH(N'dbo.Inventario',N'CostoPromedio') IS NULL
    THROW 52290,N'Ejecutá primero 30_Compras_Procedimientos.sql.',1;
GO
CREATE OR ALTER VIEW dbo.vInventarioApi AS
SELECT i.BodegaID,b.Codigo AS CodigoBodega,b.Nombre AS Bodega,b.Activo AS BodegaActiva,
       i.RepuestoID,p.Codigo,p.Nombre AS Repuesto,p.Activo AS RepuestoActivo,
       p.CategoriaID,c.Nombre AS Categoria,i.Existencia,i.StockMinimo,
       CASE WHEN i.Existencia<i.StockMinimo THEN CONVERT(bigint,i.StockMinimo)-i.Existencia ELSE CONVERT(bigint,0) END AS Faltante,
       CONVERT(varchar(15),CASE WHEN i.Existencia=0 THEN 'SIN_EXISTENCIA'
            WHEN i.Existencia<=i.StockMinimo THEN 'BAJO' ELSE 'DISPONIBLE' END) AS EstadoStock,
       v.CostoPromedio,CONVERT(decimal(38,6),CONVERT(decimal(19,0),i.Existencia)*v.CostoPromedio) AS ValorExistencia
FROM dbo.vInventario i JOIN dbo.Inventario v ON v.BodegaID=i.BodegaID AND v.RepuestoID=i.RepuestoID
JOIN dbo.Bodega b ON b.BodegaID=i.BodegaID JOIN dbo.Repuesto p ON p.RepuestoID=i.RepuestoID
JOIN dbo.CategoriaRepuesto c ON c.CategoriaID=p.CategoriaID;
GO
CREATE OR ALTER VIEW dbo.vKardexApi AS
SELECT m.MovimientoID,m.Fecha,m.Tipo,m.BodegaID,m.RepuestoID,m.Cantidad,
       m.ExistenciaResultante-m.CantidadFirmada AS ExistenciaAnterior,m.ExistenciaResultante,
       COALESCE(dc.CostoUnitario,rr.CostoUnitario) AS CostoUnitario,
       CONVERT(decimal(38,2),CONVERT(decimal(10,0),m.Cantidad)*COALESCE(dc.CostoUnitario,rr.CostoUnitario)) AS Importe,
       v.CostoAnterior,v.CostoPosterior,
       CONVERT(decimal(38,6),CONVERT(decimal(19,0),m.ExistenciaResultante)*v.CostoPosterior) AS ValorExistencia,
       v.EsMigracion,m.CompraID,m.LineaCompra,c.NumeroCompra,c.ProveedorID,pr.Nombre AS Proveedor,
       o.OrdenID,o.NumeroOrden,m.ReparacionID,m.LineaReparacion,m.UsuarioID,
       COALESCE(ev.Responsable,CONCAT(e.Nombres,N' ',e.Apellidos)) AS Responsable,
       CONVERT(bit,CASE WHEN ev.CompraID IS NOT NULL THEN 1 ELSE 0 END) AS NombreHistorico
FROM dbo.vMovimientoInventario m
LEFT JOIN dbo.DetalleCompra dc ON dc.CompraID=m.CompraID AND dc.Linea=m.LineaCompra
LEFT JOIN dbo.ReparacionRepuesto rr ON rr.ReparacionID=m.ReparacionID AND rr.Linea=m.LineaReparacion
LEFT JOIN dbo.Compra c ON c.CompraID=m.CompraID LEFT JOIN dbo.Proveedor pr ON pr.ProveedorID=c.ProveedorID
LEFT JOIN dbo.Reparacion r ON r.ReparacionID=m.ReparacionID LEFT JOIN dbo.Diagnostico d ON d.DiagnosticoID=r.DiagnosticoID
LEFT JOIN dbo.OrdenServicio o ON o.OrdenID=d.OrdenID
JOIN dbo.Usuario u ON u.UsuarioID=m.UsuarioID JOIN dbo.Empleado e ON e.EmpleadoID=u.EmpleadoID
LEFT JOIN dbo.ValoracionInventario v ON v.MovimientoID=m.MovimientoID
LEFT JOIN dbo.EventoCompraApi ev ON ev.CompraID=m.CompraID AND ev.Tipo='RECEPCION';
GO
CREATE OR ALTER FUNCTION dbo.fnInventarioFiltradoApi(
    @Buscar nvarchar(max),@BodegaID int,@CategoriaID int,@EstadoStock nvarchar(max),@Activo bit
) RETURNS TABLE AS RETURN (
    SELECT * FROM dbo.vInventarioApi
    WHERE (@Buscar IS NULL OR @Buscar=N'' OR CHARINDEX(@Buscar,Codigo)>0 OR CHARINDEX(@Buscar,Repuesto)>0
           OR CHARINDEX(@Buscar,CodigoBodega)>0 OR CHARINDEX(@Buscar,Bodega)>0 OR CHARINDEX(@Buscar,Categoria)>0)
      AND (@BodegaID IS NULL OR BodegaID=@BodegaID) AND (@CategoriaID IS NULL OR CategoriaID=@CategoriaID)
      AND (@EstadoStock IS NULL OR @EstadoStock=N'' OR EstadoStock=@EstadoStock)
      AND (@Activo IS NULL OR (@Activo=1 AND BodegaActiva=1 AND RepuestoActivo=1)
           OR (@Activo=0 AND (BodegaActiva=0 OR RepuestoActivo=0)))
);
GO
CREATE OR ALTER PROCEDURE dbo.spValidarFiltrosInventarioApi
    @UsuarioActorID int,@BodegaID int=NULL,@RepuestoID int=NULL,@CategoriaID int=NULL,
    @Buscar nvarchar(max)=NULL,@EstadoStock nvarchar(max)=NULL,@Desde date=NULL,@Hasta date=NULL,
    @Tipo nvarchar(max)=NULL,@Pagina int=1,@Tamano int=25
AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    IF @BodegaID<=0 OR @RepuestoID<=0 OR @CategoriaID<=0 OR DATALENGTH(@Buscar)>300
       OR @EstadoStock NOT IN (N'',N'SIN_EXISTENCIA',N'BAJO',N'DISPONIBLE')
       OR @Tipo NOT IN (N'',N'E',N'S') OR @Desde>@Hasta
       OR @Pagina IS NULL OR @Pagina<=0 OR @Tamano IS NULL OR @Tamano NOT BETWEEN 1 AND 100
        THROW 52200,N'Revisá IDs positivos, búsqueda (150), estado, tipo, fechas y paginación (1 a 100 filas).',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spResumenInventarioApi
    @UsuarioActorID int,@Buscar nvarchar(max)=NULL,@BodegaID int=NULL,@CategoriaID int=NULL,
    @EstadoStock nvarchar(max)=NULL,@Activo bit=NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarFiltrosInventarioApi @UsuarioActorID,@BodegaID,NULL,@CategoriaID,@Buscar,@EstadoStock;
    SELECT COUNT_BIG(*) AS Total,
           COALESCE(SUM(CONVERT(bigint,CASE WHEN EstadoStock='SIN_EXISTENCIA' THEN 1 ELSE 0 END)),0) AS SinExistencia,
           COALESCE(SUM(CONVERT(bigint,CASE WHEN EstadoStock='BAJO' THEN 1 ELSE 0 END)),0) AS StockBajo,
           COALESCE(SUM(ValorExistencia),CONVERT(decimal(38,6),0)) AS ValorTotal
    FROM dbo.fnInventarioFiltradoApi(@Buscar,@BodegaID,@CategoriaID,@EstadoStock,@Activo);
END;
GO
CREATE OR ALTER PROCEDURE dbo.spListarInventarioApi
    @UsuarioActorID int,@Buscar nvarchar(max)=NULL,@BodegaID int=NULL,@CategoriaID int=NULL,
    @EstadoStock nvarchar(max)=NULL,@Activo bit=NULL,@Pagina int=1,@Tamano int=25
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarFiltrosInventarioApi @UsuarioActorID,@BodegaID,NULL,@CategoriaID,@Buscar,@EstadoStock,
         @Pagina=@Pagina,@Tamano=@Tamano;
    SELECT * FROM dbo.fnInventarioFiltradoApi(@Buscar,@BodegaID,@CategoriaID,@EstadoStock,@Activo)
    ORDER BY Bodega,Repuesto,BodegaID,RepuestoID
    OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spConsultarInventarioApi @UsuarioActorID int,@BodegaID int,@RepuestoID int AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarFiltrosInventarioApi @UsuarioActorID,@BodegaID,@RepuestoID;
    IF NOT EXISTS(SELECT 1 FROM dbo.Inventario WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID)
        THROW 52202,N'El repuesto no está asociado a esa bodega.',1;
    SELECT * FROM dbo.vInventarioApi WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spResumenKardexApi
    @UsuarioActorID int,@BodegaID int,@RepuestoID int,@Desde date=NULL,@Hasta date=NULL,@Tipo nvarchar(max)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarFiltrosInventarioApi @UsuarioActorID,@BodegaID,@RepuestoID,@Desde=@Desde,@Hasta=@Hasta,@Tipo=@Tipo;
    IF NOT EXISTS(SELECT 1 FROM dbo.Inventario WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID)
        THROW 52202,N'El repuesto no está asociado a esa bodega.',1;
    -- Los saldos incluyen ambos tipos. Filtrar E/S sólo cambia las filas y Total.
    SELECT COALESCE(SUM(CASE WHEN @Desde IS NOT NULL AND Fecha<@Desde THEN CantidadFirmada ELSE CONVERT(bigint,0) END),0) AS SaldoInicial,
      COALESCE(SUM(CASE WHEN (@Desde IS NULL OR Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,Fecha)<=@Hasta)
                       AND Tipo='E' THEN CantidadFirmada ELSE CONVERT(bigint,0) END),0) AS Entradas,
      COALESCE(SUM(CASE WHEN (@Desde IS NULL OR Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,Fecha)<=@Hasta)
                       AND Tipo='S' THEN -CantidadFirmada ELSE CONVERT(bigint,0) END),0) AS Salidas,
      COALESCE(SUM(CASE WHEN @Hasta IS NULL OR CONVERT(date,Fecha)<=@Hasta THEN CantidadFirmada ELSE CONVERT(bigint,0) END),0) AS SaldoFinal,
      COALESCE(SUM(CONVERT(bigint,CASE WHEN (@Desde IS NULL OR Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,Fecha)<=@Hasta)
                       AND (@Tipo IS NULL OR @Tipo=N'' OR Tipo=@Tipo) THEN 1 ELSE 0 END)),0) AS Total
    FROM dbo.vMovimientoInventario WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spListarKardexApi
    @UsuarioActorID int,@BodegaID int,@RepuestoID int,@Desde date=NULL,@Hasta date=NULL,
    @Tipo nvarchar(max)=NULL,@Pagina int=1,@Tamano int=25
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.spValidarFiltrosInventarioApi @UsuarioActorID,@BodegaID,@RepuestoID,
         @Desde=@Desde,@Hasta=@Hasta,@Tipo=@Tipo,@Pagina=@Pagina,@Tamano=@Tamano;
    IF NOT EXISTS(SELECT 1 FROM dbo.Inventario WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID)
        THROW 52202,N'El repuesto no está asociado a esa bodega.',1;
    SELECT * FROM dbo.vKardexApi WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID
      AND (@Desde IS NULL OR Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,Fecha)<=@Hasta)
      AND (@Tipo IS NULL OR @Tipo=N'' OR Tipo=@Tipo)
    ORDER BY MovimientoID
    OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
END;
GO
IF DATABASE_PRINCIPAL_ID(N'techcare_app') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.vInventarioApi TO techcare_app;
    GRANT SELECT ON dbo.vKardexApi TO techcare_app;
    GRANT EXECUTE ON dbo.spResumenInventarioApi TO techcare_app;
    GRANT EXECUTE ON dbo.spListarInventarioApi TO techcare_app;
    GRANT EXECUTE ON dbo.spConsultarInventarioApi TO techcare_app;
    GRANT EXECUTE ON dbo.spResumenKardexApi TO techcare_app;
    GRANT EXECUTE ON dbo.spListarKardexApi TO techcare_app;
END;
GO
