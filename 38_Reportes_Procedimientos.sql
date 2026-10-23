-- Reportes R01-R12 para API. Instalar después de 33 y 36. Sólo crea objetos de consulta.
USE [TechCare];
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.vKardexApi',N'V') IS NULL
    THROW 52390,N'Ejecutá primero 33_Inventario_Procedimientos.sql y 36_Corregir_Redondeo_Costos.sql.',1;
GO
CREATE OR ALTER FUNCTION dbo.fnPuedeConsultarReporteApi(@Actor int,@Codigo nvarchar(3)) RETURNS bit AS
BEGIN
 RETURN CASE WHEN dbo.fnTieneRol(@Actor,'ADMIN')=1 THEN 1
 WHEN dbo.fnTieneRol(@Actor,'RECEPCION')=1 AND @Codigo IN (N'R01',N'R02',N'R03') THEN 1
 WHEN dbo.fnTieneRol(@Actor,'TECNICO')=1 AND @Codigo IN (N'R01',N'R03',N'R04',N'R05') THEN 1
 WHEN dbo.fnTieneRol(@Actor,'BODEGA')=1 AND @Codigo IN (N'R05',N'R06',N'R07',N'R08',N'R09') THEN 1
 WHEN dbo.fnTieneRol(@Actor,'CAJA')=1 AND @Codigo IN (N'R10',N'R11') THEN 1
 ELSE 0 END;
END;
GO
CREATE OR ALTER FUNCTION dbo.fnTecnicoLimitadoReporteApi(@Actor int,@Codigo nvarchar(3)) RETURNS bit AS
BEGIN
 RETURN CASE WHEN dbo.fnTieneRol(@Actor,'ADMIN')=1 THEN 0
 WHEN @Codigo IN(N'R01',N'R03') AND dbo.fnTieneRol(@Actor,'RECEPCION')=1 THEN 0
 WHEN @Codigo=N'R05' AND dbo.fnTieneRol(@Actor,'BODEGA')=1 THEN 0
 WHEN @Codigo IN(N'R01',N'R03',N'R04',N'R05') THEN 1 ELSE 0 END;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spCatalogoReportesApi @UsuarioActorID int AS
BEGIN
 SET NOCOUNT ON;
 IF dbo.fnTieneRol(@UsuarioActorID,'ADMIN')=0 AND dbo.fnTieneRol(@UsuarioActorID,'RECEPCION')=0
 AND dbo.fnTieneRol(@UsuarioActorID,'TECNICO')=0 AND dbo.fnTieneRol(@UsuarioActorID,'BODEGA')=0 AND dbo.fnTieneRol(@UsuarioActorID,'CAJA')=0
    THROW 52304,N'Se requiere una cuenta y empleado activos con acceso a reportes.',1;
 SELECT Codigo FROM (VALUES (N'R01'),(N'R02'),(N'R03'),(N'R04'),(N'R05'),(N'R06'),(N'R07'),(N'R08'),(N'R09'),(N'R10'),(N'R11'),(N'R12'))r(Codigo)
 WHERE dbo.fnPuedeConsultarReporteApi(@UsuarioActorID,Codigo)=1 ORDER BY Codigo;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spValidarReporteApi
 @UsuarioActorID int,@Codigo nvarchar(max),@Desde date=NULL,@Hasta date=NULL,@ClienteID int=NULL,@TecnicoID int=NULL,
 @BodegaID int=NULL,@ProveedorID int=NULL,@OrdenID int=NULL,@CategoriaID int=NULL,@RepuestoID int=NULL,
 @Estado nvarchar(max)=NULL,@Serie nvarchar(max)=NULL,@Pagina int=1,@Tamano int=25
AS
BEGIN
 SET NOCOUNT ON;
 IF @Codigo IS NULL OR DATALENGTH(@Codigo)<>6 OR @Codigo NOT IN(N'R01',N'R02',N'R03',N'R04',N'R05',N'R06',N'R07',N'R08',N'R09',N'R10',N'R11',N'R12')
    THROW 52302,N'El reporte no existe.',1;
 IF dbo.fnPuedeConsultarReporteApi(@UsuarioActorID,@Codigo)=0 THROW 52304,N'Tu usuario no tiene permiso para este reporte.',1;
 IF @ClienteID<=0 OR @TecnicoID<=0 OR @BodegaID<=0 OR @ProveedorID<=0 OR @OrdenID<=0 OR @CategoriaID<=0 OR @RepuestoID<=0
 OR @Desde>@Hasta OR DATALENGTH(@Serie)>160 OR DATALENGTH(@Estado)>60
 OR @Pagina IS NULL OR @Pagina<=0 OR @Tamano IS NULL OR @Tamano NOT BETWEEN 1 AND 100
    THROW 52300,N'Revisá los filtros, fechas e identificadores y el tamaño de página (1 a 100).',1;
 IF @Desde IS NOT NULL AND @Codigo NOT IN (N'R01',N'R04',N'R08',N'R09',N'R11') THROW 52300,N'Este reporte no admite el filtro desde.',1;
 IF @Hasta IS NOT NULL AND @Codigo NOT IN (N'R01',N'R04',N'R08',N'R09',N'R11') THROW 52300,N'Este reporte no admite el filtro hasta.',1;
 IF @ClienteID IS NOT NULL AND @Codigo NOT IN (N'R02',N'R10',N'R11',N'R12') THROW 52300,N'Este reporte no admite el filtro clienteId.',1;
 IF @TecnicoID IS NOT NULL AND @Codigo NOT IN (N'R01',N'R04',N'R05') THROW 52300,N'Este reporte no admite el filtro tecnicoId.',1;
 IF @BodegaID IS NOT NULL AND @Codigo NOT IN (N'R05',N'R06',N'R07',N'R08',N'R09') THROW 52300,N'Este reporte no admite el filtro bodegaId.',1;
 IF @ProveedorID IS NOT NULL AND @Codigo NOT IN (N'R08') THROW 52300,N'Este reporte no admite el filtro proveedorId.',1;
 IF @OrdenID IS NOT NULL AND @Codigo NOT IN (N'R05',N'R12') THROW 52300,N'Este reporte no admite el filtro ordenId.',1;
 IF @CategoriaID IS NOT NULL AND @Codigo NOT IN (N'R06',N'R07') THROW 52300,N'Este reporte no admite el filtro categoriaId.',1;
 IF @RepuestoID IS NOT NULL AND @Codigo NOT IN (N'R06',N'R07',N'R09') THROW 52300,N'Este reporte no admite el filtro repuestoId.',1;
 IF @Estado IS NOT NULL AND @Codigo NOT IN (N'R01',N'R08') THROW 52300,N'Este reporte no admite el filtro estado.',1;
 IF @Serie IS NOT NULL AND @Codigo NOT IN (N'R03') THROW 52300,N'Este reporte no admite el filtro serie.',1;
 IF @Estado IS NOT NULL AND ((@Codigo=N'R01' AND NOT EXISTS(SELECT 1 FROM dbo.EstadoOrden WHERE Codigo=@Estado))
 OR (@Codigo=N'R08' AND @Estado NOT IN(N'PENDIENTE',N'RECIBIDA',N'ANULADA')))
    THROW 52300,N'El estado no es válido para este reporte.',1;
 IF dbo.fnTecnicoLimitadoReporteApi(@UsuarioActorID,@Codigo)=1 AND @TecnicoID IS NOT NULL AND @TecnicoID<>@UsuarioActorID
    THROW 52304,N'El técnico consulta únicamente su propio trabajo.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spConsultarReporteApi
 @UsuarioActorID int,@Codigo nvarchar(max),@Desde date=NULL,@Hasta date=NULL,@ClienteID int=NULL,@TecnicoID int=NULL,
 @BodegaID int=NULL,@ProveedorID int=NULL,@OrdenID int=NULL,@CategoriaID int=NULL,@RepuestoID int=NULL,
 @Estado nvarchar(max)=NULL,@Serie nvarchar(max)=NULL,@SoloResumen bit=0,@Pagina int=1,@Tamano int=25
AS
BEGIN
 SET NOCOUNT ON;
 EXEC dbo.spValidarReporteApi @UsuarioActorID,@Codigo,@Desde,@Hasta,@ClienteID,@TecnicoID,@BodegaID,@ProveedorID,@OrdenID,@CategoriaID,@RepuestoID,@Estado,@Serie,@Pagina,@Tamano;
 IF @SoloResumen IS NULL THROW 52300,N'Indicá el modo de consulta.',1;
 DECLARE @Limitado int=CASE WHEN dbo.fnTecnicoLimitadoReporteApi(@UsuarioActorID,@Codigo)=1 THEN @UsuarioActorID ELSE NULL END;
 IF @Codigo=N'R01'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT o.OrdenID,o.NumeroOrden,o.FechaIngreso,o.Estado,o.Prioridad,o.Cliente,o.NumeroSerie,o.Tecnico,o.ReparacionID,p.Nivel
 FROM dbo.vOrdenAcceso o JOIN dbo.Prioridad p ON p.Codigo=o.PrioridadCodigo
 WHERE o.EsFinal=0 AND (@Estado IS NULL OR o.EstadoCodigo=@Estado)
 AND (@TecnicoID IS NULL OR o.UsuarioTecnicoID=@TecnicoID) AND (@Limitado IS NULL OR o.UsuarioTecnicoID=@Limitado)
 AND (@Desde IS NULL OR o.FechaIngreso>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,o.FechaIngreso)<=@Hasta)
   )
   SELECT COUNT_BIG(*) AS Total FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT o.OrdenID,o.NumeroOrden,o.FechaIngreso,o.Estado,o.Prioridad,o.Cliente,o.NumeroSerie,o.Tecnico,o.ReparacionID,p.Nivel
 FROM dbo.vOrdenAcceso o JOIN dbo.Prioridad p ON p.Codigo=o.PrioridadCodigo
 WHERE o.EsFinal=0 AND (@Estado IS NULL OR o.EstadoCodigo=@Estado)
 AND (@TecnicoID IS NULL OR o.UsuarioTecnicoID=@TecnicoID) AND (@Limitado IS NULL OR o.UsuarioTecnicoID=@Limitado)
 AND (@Desde IS NULL OR o.FechaIngreso>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,o.FechaIngreso)<=@Hasta)
   )
   SELECT OrdenID,NumeroOrden,FechaIngreso,Estado,Prioridad,Cliente,NumeroSerie,Tecnico,ReparacionID FROM Datos ORDER BY Nivel DESC,FechaIngreso,OrdenID
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R02'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT c.ClienteID,c.NIT,c.Nombre AS Cliente,e.NumeroSerie,o.OrdenID,o.NumeroOrden,o.FechaIngreso,o.EstadoCodigo,
 d.Descripcion AS Diagnostico,r.DescripcionTrabajo,f.NumeroFactura,f.Total,f.Saldo,en.Fecha AS FechaEntrega,e.EquipoID
 FROM dbo.Cliente c LEFT JOIN dbo.Equipo e ON e.ClienteID=c.ClienteID
 LEFT JOIN dbo.OrdenServicio o ON o.EquipoID=e.EquipoID LEFT JOIN dbo.Diagnostico d ON d.OrdenID=o.OrdenID
 LEFT JOIN dbo.Reparacion r ON r.DiagnosticoID=d.DiagnosticoID LEFT JOIN dbo.vFacturaSaldo f ON f.OrdenID=o.OrdenID
 LEFT JOIN dbo.Entrega en ON en.OrdenID=o.OrdenID WHERE (@ClienteID IS NULL OR c.ClienteID=@ClienteID)
   )
   SELECT COUNT_BIG(*) AS Total FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT c.ClienteID,c.NIT,c.Nombre AS Cliente,e.NumeroSerie,o.OrdenID,o.NumeroOrden,o.FechaIngreso,o.EstadoCodigo,
 d.Descripcion AS Diagnostico,r.DescripcionTrabajo,f.NumeroFactura,f.Total,f.Saldo,en.Fecha AS FechaEntrega,e.EquipoID
 FROM dbo.Cliente c LEFT JOIN dbo.Equipo e ON e.ClienteID=c.ClienteID
 LEFT JOIN dbo.OrdenServicio o ON o.EquipoID=e.EquipoID LEFT JOIN dbo.Diagnostico d ON d.OrdenID=o.OrdenID
 LEFT JOIN dbo.Reparacion r ON r.DiagnosticoID=d.DiagnosticoID LEFT JOIN dbo.vFacturaSaldo f ON f.OrdenID=o.OrdenID
 LEFT JOIN dbo.Entrega en ON en.OrdenID=o.OrdenID WHERE (@ClienteID IS NULL OR c.ClienteID=@ClienteID)
   )
   SELECT ClienteID,NIT,Cliente,NumeroSerie,OrdenID,NumeroOrden,FechaIngreso,EstadoCodigo,Diagnostico,DescripcionTrabajo,NumeroFactura,Total,Saldo,FechaEntrega FROM Datos ORDER BY ClienteID,EquipoID,FechaIngreso DESC,OrdenID
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R03'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT e.EquipoID,e.NumeroSerie,c.Nombre AS Cliente,te.Nombre AS Tipo,ma.Nombre AS Marca,mo.Nombre AS Modelo,
 o.OrdenID,o.NumeroOrden,o.EstadoCodigo,o.FechaDiagnostico,o.DescripcionDiagnostico AS Diagnostico,
 o.FechaInicioReparacion AS FechaInicio,o.FechaFinReparacion AS FechaFin,o.DescripcionTrabajo,o.Tecnico
 FROM dbo.Equipo e JOIN dbo.Cliente c ON c.ClienteID=e.ClienteID
 JOIN dbo.ModeloEquipo mo ON mo.ModeloEquipoID=e.ModeloEquipoID JOIN dbo.Marca ma ON ma.MarcaID=mo.MarcaID
 JOIN dbo.TipoEquipo te ON te.TipoEquipoID=mo.TipoEquipoID LEFT JOIN dbo.vOrdenAcceso o ON o.EquipoID=e.EquipoID
 WHERE (@Serie IS NULL OR e.NumeroSerie=@Serie) AND (@Limitado IS NULL OR o.UsuarioTecnicoID=@Limitado)
   )
   SELECT COUNT_BIG(*) AS Total FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT e.EquipoID,e.NumeroSerie,c.Nombre AS Cliente,te.Nombre AS Tipo,ma.Nombre AS Marca,mo.Nombre AS Modelo,
 o.OrdenID,o.NumeroOrden,o.EstadoCodigo,o.FechaDiagnostico,o.DescripcionDiagnostico AS Diagnostico,
 o.FechaInicioReparacion AS FechaInicio,o.FechaFinReparacion AS FechaFin,o.DescripcionTrabajo,o.Tecnico
 FROM dbo.Equipo e JOIN dbo.Cliente c ON c.ClienteID=e.ClienteID
 JOIN dbo.ModeloEquipo mo ON mo.ModeloEquipoID=e.ModeloEquipoID JOIN dbo.Marca ma ON ma.MarcaID=mo.MarcaID
 JOIN dbo.TipoEquipo te ON te.TipoEquipoID=mo.TipoEquipoID LEFT JOIN dbo.vOrdenAcceso o ON o.EquipoID=e.EquipoID
 WHERE (@Serie IS NULL OR e.NumeroSerie=@Serie) AND (@Limitado IS NULL OR o.UsuarioTecnicoID=@Limitado)
   )
   SELECT EquipoID,NumeroSerie,Cliente,Tipo,Marca,Modelo,OrdenID,NumeroOrden,EstadoCodigo,FechaDiagnostico,Diagnostico,FechaInicio,FechaFin,DescripcionTrabajo,Tecnico FROM Datos ORDER BY NumeroSerie,EquipoID,OrdenID
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R04'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT CONVERT(varchar(12),'DIAGNOSTICO') AS Proceso,d.DiagnosticoID AS RegistroID,d.Fecha,o.OrdenID,o.NumeroOrden,o.NumeroSerie,o.Cliente,
 d.UsuarioTecnicoID AS UsuarioID,CONCAT(em.Nombres,N' ',em.Apellidos) AS Tecnico,d.Descripcion AS Trabajo,d.CostoManoObraEstimado AS ManoObra
 FROM dbo.Diagnostico d JOIN dbo.vOrdenAcceso o ON o.OrdenID=d.OrdenID JOIN dbo.Usuario u ON u.UsuarioID=d.UsuarioTecnicoID
 JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID WHERE (@TecnicoID IS NULL OR d.UsuarioTecnicoID=@TecnicoID)
 AND (@Limitado IS NULL OR (o.UsuarioTecnicoID=@Limitado AND d.UsuarioTecnicoID=@Limitado)) AND (@Desde IS NULL OR d.Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,d.Fecha)<=@Hasta)
 UNION ALL
 SELECT 'REPARACION',r.ReparacionID,r.FechaInicio,o.OrdenID,o.NumeroOrden,o.NumeroSerie,o.Cliente,r.UsuarioTecnicoID,
 CONCAT(em.Nombres,N' ',em.Apellidos),r.DescripcionTrabajo,r.CostoManoObra
 FROM dbo.Reparacion r JOIN dbo.Diagnostico d ON d.DiagnosticoID=r.DiagnosticoID JOIN dbo.vOrdenAcceso o ON o.OrdenID=d.OrdenID
 JOIN dbo.Usuario u ON u.UsuarioID=r.UsuarioTecnicoID JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
 WHERE (@TecnicoID IS NULL OR r.UsuarioTecnicoID=@TecnicoID) AND (@Limitado IS NULL OR (o.UsuarioTecnicoID=@Limitado AND r.UsuarioTecnicoID=@Limitado))
 AND (@Desde IS NULL OR r.FechaInicio>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,r.FechaInicio)<=@Hasta)
   )
   SELECT COUNT_BIG(*) AS Total FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT CONVERT(varchar(12),'DIAGNOSTICO') AS Proceso,d.DiagnosticoID AS RegistroID,d.Fecha,o.OrdenID,o.NumeroOrden,o.NumeroSerie,o.Cliente,
 d.UsuarioTecnicoID AS UsuarioID,CONCAT(em.Nombres,N' ',em.Apellidos) AS Tecnico,d.Descripcion AS Trabajo,d.CostoManoObraEstimado AS ManoObra
 FROM dbo.Diagnostico d JOIN dbo.vOrdenAcceso o ON o.OrdenID=d.OrdenID JOIN dbo.Usuario u ON u.UsuarioID=d.UsuarioTecnicoID
 JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID WHERE (@TecnicoID IS NULL OR d.UsuarioTecnicoID=@TecnicoID)
 AND (@Limitado IS NULL OR (o.UsuarioTecnicoID=@Limitado AND d.UsuarioTecnicoID=@Limitado)) AND (@Desde IS NULL OR d.Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,d.Fecha)<=@Hasta)
 UNION ALL
 SELECT 'REPARACION',r.ReparacionID,r.FechaInicio,o.OrdenID,o.NumeroOrden,o.NumeroSerie,o.Cliente,r.UsuarioTecnicoID,
 CONCAT(em.Nombres,N' ',em.Apellidos),r.DescripcionTrabajo,r.CostoManoObra
 FROM dbo.Reparacion r JOIN dbo.Diagnostico d ON d.DiagnosticoID=r.DiagnosticoID JOIN dbo.vOrdenAcceso o ON o.OrdenID=d.OrdenID
 JOIN dbo.Usuario u ON u.UsuarioID=r.UsuarioTecnicoID JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
 WHERE (@TecnicoID IS NULL OR r.UsuarioTecnicoID=@TecnicoID) AND (@Limitado IS NULL OR (o.UsuarioTecnicoID=@Limitado AND r.UsuarioTecnicoID=@Limitado))
 AND (@Desde IS NULL OR r.FechaInicio>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,r.FechaInicio)<=@Hasta)
   )
   SELECT Proceso,RegistroID,Fecha,OrdenID,NumeroOrden,NumeroSerie,Cliente,UsuarioID,Tecnico,Trabajo,ManoObra FROM Datos ORDER BY Tecnico,Fecha,Proceso,RegistroID
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R05'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT o.OrdenID,o.NumeroOrden,CONCAT(em.Nombres,N' ',em.Apellidos) AS Tecnico,b.Nombre AS Bodega,p.Codigo,p.Nombre AS Repuesto,
 rr.Cantidad,rr.CostoUnitario,rr.PrecioUnitario,CONVERT(decimal(28,2),CONVERT(decimal(10,0),rr.Cantidad)*rr.CostoUnitario) AS CostoHistorico,
 CONVERT(decimal(28,2),CONVERT(decimal(10,0),rr.Cantidad)*rr.PrecioUnitario) AS VentaHistorica,m.MovimientoID,m.Fecha
 FROM dbo.ReparacionRepuesto rr JOIN dbo.vOrdenAcceso o ON o.ReparacionID=rr.ReparacionID
 JOIN dbo.Usuario u ON u.UsuarioID=o.UsuarioTecnicoID JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
 JOIN dbo.Bodega b ON b.BodegaID=rr.BodegaID JOIN dbo.Repuesto p ON p.RepuestoID=rr.RepuestoID
 JOIN dbo.MovimientoInventario m ON m.ReparacionID=rr.ReparacionID AND m.LineaReparacion=rr.Linea
 WHERE (@OrdenID IS NULL OR o.OrdenID=@OrdenID) AND (@TecnicoID IS NULL OR o.UsuarioTecnicoID=@TecnicoID)
 AND (@BodegaID IS NULL OR b.BodegaID=@BodegaID) AND (@Limitado IS NULL OR o.UsuarioTecnicoID=@Limitado)
   )
   SELECT COUNT_BIG(*) AS Total,COALESCE(SUM(CostoHistorico),0) AS CostoHistoricoTotal,COALESCE(SUM(VentaHistorica),0) AS VentaHistoricaTotal FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT o.OrdenID,o.NumeroOrden,CONCAT(em.Nombres,N' ',em.Apellidos) AS Tecnico,b.Nombre AS Bodega,p.Codigo,p.Nombre AS Repuesto,
 rr.Cantidad,rr.CostoUnitario,rr.PrecioUnitario,CONVERT(decimal(28,2),CONVERT(decimal(10,0),rr.Cantidad)*rr.CostoUnitario) AS CostoHistorico,
 CONVERT(decimal(28,2),CONVERT(decimal(10,0),rr.Cantidad)*rr.PrecioUnitario) AS VentaHistorica,m.MovimientoID,m.Fecha
 FROM dbo.ReparacionRepuesto rr JOIN dbo.vOrdenAcceso o ON o.ReparacionID=rr.ReparacionID
 JOIN dbo.Usuario u ON u.UsuarioID=o.UsuarioTecnicoID JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
 JOIN dbo.Bodega b ON b.BodegaID=rr.BodegaID JOIN dbo.Repuesto p ON p.RepuestoID=rr.RepuestoID
 JOIN dbo.MovimientoInventario m ON m.ReparacionID=rr.ReparacionID AND m.LineaReparacion=rr.Linea
 WHERE (@OrdenID IS NULL OR o.OrdenID=@OrdenID) AND (@TecnicoID IS NULL OR o.UsuarioTecnicoID=@TecnicoID)
 AND (@BodegaID IS NULL OR b.BodegaID=@BodegaID) AND (@Limitado IS NULL OR o.UsuarioTecnicoID=@Limitado)
   )
   SELECT OrdenID,NumeroOrden,Tecnico,Bodega,Codigo,Repuesto,Cantidad,CostoUnitario,PrecioUnitario,CostoHistorico,VentaHistorica,MovimientoID,Fecha FROM Datos ORDER BY OrdenID,MovimientoID
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R06'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT i.BodegaID,i.Bodega,i.Categoria,i.Codigo,i.Repuesto,i.Existencia,i.StockMinimo,i.Faltante,i.EstadoStock,
 i.CostoPromedio,i.ValorExistencia,i.BodegaActiva,i.RepuestoActivo,i.RepuestoID
 FROM dbo.vInventarioApi i WHERE (@BodegaID IS NULL OR i.BodegaID=@BodegaID)
 AND (@CategoriaID IS NULL OR i.CategoriaID=@CategoriaID) AND (@RepuestoID IS NULL OR i.RepuestoID=@RepuestoID)
   )
   SELECT COUNT_BIG(*) AS Total,COALESCE(SUM(ValorExistencia),0) AS ValorTotal FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT i.BodegaID,i.Bodega,i.Categoria,i.Codigo,i.Repuesto,i.Existencia,i.StockMinimo,i.Faltante,i.EstadoStock,
 i.CostoPromedio,i.ValorExistencia,i.BodegaActiva,i.RepuestoActivo,i.RepuestoID
 FROM dbo.vInventarioApi i WHERE (@BodegaID IS NULL OR i.BodegaID=@BodegaID)
 AND (@CategoriaID IS NULL OR i.CategoriaID=@CategoriaID) AND (@RepuestoID IS NULL OR i.RepuestoID=@RepuestoID)
   )
   SELECT BodegaID,Bodega,Categoria,Codigo,Repuesto,Existencia,StockMinimo,Faltante,EstadoStock,CostoPromedio,ValorExistencia,BodegaActiva,RepuestoActivo FROM Datos ORDER BY Bodega,Categoria,Repuesto,BodegaID,RepuestoID
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R07'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT i.BodegaID,i.Bodega,i.Categoria,i.Codigo,i.Repuesto,i.Existencia,i.StockMinimo,i.Faltante,i.EstadoStock,
 i.CostoPromedio,i.ValorExistencia,i.BodegaActiva,i.RepuestoActivo,i.RepuestoID
 FROM dbo.vInventarioApi i WHERE (@BodegaID IS NULL OR i.BodegaID=@BodegaID)
 AND (@CategoriaID IS NULL OR i.CategoriaID=@CategoriaID) AND (@RepuestoID IS NULL OR i.RepuestoID=@RepuestoID) AND i.Existencia<=i.StockMinimo
   )
   SELECT COUNT_BIG(*) AS Total FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT i.BodegaID,i.Bodega,i.Categoria,i.Codigo,i.Repuesto,i.Existencia,i.StockMinimo,i.Faltante,i.EstadoStock,
 i.CostoPromedio,i.ValorExistencia,i.BodegaActiva,i.RepuestoActivo,i.RepuestoID
 FROM dbo.vInventarioApi i WHERE (@BodegaID IS NULL OR i.BodegaID=@BodegaID)
 AND (@CategoriaID IS NULL OR i.CategoriaID=@CategoriaID) AND (@RepuestoID IS NULL OR i.RepuestoID=@RepuestoID) AND i.Existencia<=i.StockMinimo
   )
   SELECT BodegaID,Bodega,Categoria,Codigo,Repuesto,Existencia,StockMinimo,Faltante,EstadoStock,CostoPromedio,ValorExistencia,BodegaActiva,RepuestoActivo FROM Datos ORDER BY Bodega,Existencia,Repuesto,BodegaID,RepuestoID
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R08'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT c.CompraID,pr.Nombre AS Proveedor,c.NumeroCompra,c.Fecha,c.Estado,dc.Linea,p.Codigo,p.Nombre AS Repuesto,b.Nombre AS Destino,
 dc.Cantidad,dc.CostoUnitario,CONVERT(decimal(28,2),CONVERT(decimal(10,0),dc.Cantidad)*dc.CostoUnitario) AS CostoLinea,
 COALESCE(ev.Responsable,CONCAT(em.Nombres,N' ',em.Apellidos)) AS RegistradoPor
 FROM dbo.Compra c JOIN dbo.Proveedor pr ON pr.ProveedorID=c.ProveedorID JOIN dbo.DetalleCompra dc ON dc.CompraID=c.CompraID
 JOIN dbo.Repuesto p ON p.RepuestoID=dc.RepuestoID JOIN dbo.Bodega b ON b.BodegaID=dc.BodegaID
 JOIN dbo.Usuario u ON u.UsuarioID=c.UsuarioRegistroID JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
 LEFT JOIN dbo.EventoCompraApi ev ON ev.CompraID=c.CompraID AND ev.Tipo='REGISTRO'
 WHERE (@ProveedorID IS NULL OR c.ProveedorID=@ProveedorID) AND (@BodegaID IS NULL OR dc.BodegaID=@BodegaID)
 AND (@Estado IS NULL OR c.Estado=@Estado) AND (@Desde IS NULL OR c.Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,c.Fecha)<=@Hasta)
   )
   SELECT COUNT_BIG(*) AS Total,COUNT_BIG(DISTINCT CompraID) AS Compras,COALESCE(SUM(CostoLinea),0) AS CostoTotal FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT c.CompraID,pr.Nombre AS Proveedor,c.NumeroCompra,c.Fecha,c.Estado,dc.Linea,p.Codigo,p.Nombre AS Repuesto,b.Nombre AS Destino,
 dc.Cantidad,dc.CostoUnitario,CONVERT(decimal(28,2),CONVERT(decimal(10,0),dc.Cantidad)*dc.CostoUnitario) AS CostoLinea,
 COALESCE(ev.Responsable,CONCAT(em.Nombres,N' ',em.Apellidos)) AS RegistradoPor
 FROM dbo.Compra c JOIN dbo.Proveedor pr ON pr.ProveedorID=c.ProveedorID JOIN dbo.DetalleCompra dc ON dc.CompraID=c.CompraID
 JOIN dbo.Repuesto p ON p.RepuestoID=dc.RepuestoID JOIN dbo.Bodega b ON b.BodegaID=dc.BodegaID
 JOIN dbo.Usuario u ON u.UsuarioID=c.UsuarioRegistroID JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
 LEFT JOIN dbo.EventoCompraApi ev ON ev.CompraID=c.CompraID AND ev.Tipo='REGISTRO'
 WHERE (@ProveedorID IS NULL OR c.ProveedorID=@ProveedorID) AND (@BodegaID IS NULL OR dc.BodegaID=@BodegaID)
 AND (@Estado IS NULL OR c.Estado=@Estado) AND (@Desde IS NULL OR c.Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,c.Fecha)<=@Hasta)
   )
   SELECT CompraID,Proveedor,NumeroCompra,Fecha,Estado,Linea,Codigo,Repuesto,Destino,Cantidad,CostoUnitario,CostoLinea,RegistradoPor FROM Datos ORDER BY Proveedor,Fecha,CompraID,Linea
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R09'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT k.MovimientoID,k.Fecha,k.Tipo,i.Bodega,i.Codigo,i.Repuesto,k.Cantidad,
 CASE WHEN k.Tipo='E' THEN CONVERT(bigint,k.Cantidad) ELSE -CONVERT(bigint,k.Cantidad) END AS CantidadFirmada,
 k.ExistenciaResultante,COALESCE(k.NumeroCompra,k.NumeroOrden) AS DocumentoOrigen,k.Proveedor,k.Responsable,k.CostoUnitario,k.CostoPosterior
 FROM dbo.vKardexApi k JOIN dbo.vInventarioApi i ON i.BodegaID=k.BodegaID AND i.RepuestoID=k.RepuestoID
 WHERE (@BodegaID IS NULL OR k.BodegaID=@BodegaID) AND (@RepuestoID IS NULL OR k.RepuestoID=@RepuestoID)
 AND (@Desde IS NULL OR k.Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,k.Fecha)<=@Hasta)
   )
   SELECT COUNT_BIG(*) AS Total FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT k.MovimientoID,k.Fecha,k.Tipo,i.Bodega,i.Codigo,i.Repuesto,k.Cantidad,
 CASE WHEN k.Tipo='E' THEN CONVERT(bigint,k.Cantidad) ELSE -CONVERT(bigint,k.Cantidad) END AS CantidadFirmada,
 k.ExistenciaResultante,COALESCE(k.NumeroCompra,k.NumeroOrden) AS DocumentoOrigen,k.Proveedor,k.Responsable,k.CostoUnitario,k.CostoPosterior
 FROM dbo.vKardexApi k JOIN dbo.vInventarioApi i ON i.BodegaID=k.BodegaID AND i.RepuestoID=k.RepuestoID
 WHERE (@BodegaID IS NULL OR k.BodegaID=@BodegaID) AND (@RepuestoID IS NULL OR k.RepuestoID=@RepuestoID)
 AND (@Desde IS NULL OR k.Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,k.Fecha)<=@Hasta)
   )
   SELECT MovimientoID,Fecha,Tipo,Bodega,Codigo,Repuesto,Cantidad,CantidadFirmada,ExistenciaResultante,DocumentoOrigen,Proveedor,Responsable,CostoUnitario,CostoPosterior FROM Datos ORDER BY MovimientoID
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R10'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT f.FacturaID,f.NumeroFactura,c.Nombre AS Cliente,o.NumeroOrden,f.Subtotal,f.Impuesto,f.Total,f.Pagado,f.Saldo,
 pg.PagoID,pg.Fecha AS FechaPago,pg.Monto,mp.Nombre AS Metodo,CASE WHEN u.UsuarioID IS NULL THEN NULL ELSE CONCAT(em.Nombres,N' ',em.Apellidos) END AS Cajero
 FROM dbo.vFacturaSaldo f JOIN dbo.OrdenServicio o ON o.OrdenID=f.OrdenID JOIN dbo.Equipo e ON e.EquipoID=o.EquipoID
 JOIN dbo.Cliente c ON c.ClienteID=e.ClienteID LEFT JOIN dbo.Pago pg ON pg.FacturaID=f.FacturaID
 LEFT JOIN dbo.MetodoPago mp ON mp.MetodoPagoID=pg.MetodoPagoID LEFT JOIN dbo.Usuario u ON u.UsuarioID=pg.UsuarioRegistroID
 LEFT JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
 WHERE f.Estado='EMITIDA' AND f.Saldo>0 AND (@ClienteID IS NULL OR c.ClienteID=@ClienteID)
   )
   SELECT (SELECT COUNT_BIG(*) FROM Datos) AS Total,COUNT_BIG(*) AS Facturas,
 COALESCE(SUM(TotalFactura),0) AS TotalFacturado,COALESCE(SUM(Pagado),0) AS PagadoTotal,COALESCE(SUM(Saldo),0) AS SaldoTotal
 FROM(SELECT FacturaID,MAX(Total) AS TotalFactura,MAX(Pagado) AS Pagado,MAX(Saldo) AS Saldo FROM Datos GROUP BY FacturaID)f;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT f.FacturaID,f.NumeroFactura,c.Nombre AS Cliente,o.NumeroOrden,f.Subtotal,f.Impuesto,f.Total,f.Pagado,f.Saldo,
 pg.PagoID,pg.Fecha AS FechaPago,pg.Monto,mp.Nombre AS Metodo,CASE WHEN u.UsuarioID IS NULL THEN NULL ELSE CONCAT(em.Nombres,N' ',em.Apellidos) END AS Cajero
 FROM dbo.vFacturaSaldo f JOIN dbo.OrdenServicio o ON o.OrdenID=f.OrdenID JOIN dbo.Equipo e ON e.EquipoID=o.EquipoID
 JOIN dbo.Cliente c ON c.ClienteID=e.ClienteID LEFT JOIN dbo.Pago pg ON pg.FacturaID=f.FacturaID
 LEFT JOIN dbo.MetodoPago mp ON mp.MetodoPagoID=pg.MetodoPagoID LEFT JOIN dbo.Usuario u ON u.UsuarioID=pg.UsuarioRegistroID
 LEFT JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
 WHERE f.Estado='EMITIDA' AND f.Saldo>0 AND (@ClienteID IS NULL OR c.ClienteID=@ClienteID)
   )
   SELECT FacturaID,NumeroFactura,Cliente,NumeroOrden,Subtotal,Impuesto,Total,Pagado,Saldo,PagoID,FechaPago,Monto,Metodo,Cajero FROM Datos ORDER BY FacturaID,FechaPago,PagoID
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R11'
 BEGIN
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT DATEFROMPARTS(YEAR(f.Fecha),MONTH(f.Fecha),1) AS Mes,COUNT_BIG(*) AS CantidadFacturas,
 SUM(f.ManoObra) AS ManoObra,SUM(f.Repuestos) AS Repuestos,SUM(f.Impuesto) AS Impuesto,SUM(f.Total) AS TotalFacturado
 FROM dbo.vFacturaSaldo f JOIN dbo.OrdenServicio o ON o.OrdenID=f.OrdenID JOIN dbo.Equipo e ON e.EquipoID=o.EquipoID
 JOIN dbo.Cliente c ON c.ClienteID=e.ClienteID WHERE f.Estado='EMITIDA' AND (@ClienteID IS NULL OR c.ClienteID=@ClienteID)
 AND (@Desde IS NULL OR f.Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,f.Fecha)<=@Hasta) GROUP BY YEAR(f.Fecha),MONTH(f.Fecha)
   )
   SELECT COUNT_BIG(*) AS Total,COALESCE(SUM(CantidadFacturas),0) AS Facturas,COALESCE(SUM(TotalFacturado),0) AS TotalFacturado FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT DATEFROMPARTS(YEAR(f.Fecha),MONTH(f.Fecha),1) AS Mes,COUNT_BIG(*) AS CantidadFacturas,
 SUM(f.ManoObra) AS ManoObra,SUM(f.Repuestos) AS Repuestos,SUM(f.Impuesto) AS Impuesto,SUM(f.Total) AS TotalFacturado
 FROM dbo.vFacturaSaldo f JOIN dbo.OrdenServicio o ON o.OrdenID=f.OrdenID JOIN dbo.Equipo e ON e.EquipoID=o.EquipoID
 JOIN dbo.Cliente c ON c.ClienteID=e.ClienteID WHERE f.Estado='EMITIDA' AND (@ClienteID IS NULL OR c.ClienteID=@ClienteID)
 AND (@Desde IS NULL OR f.Fecha>=@Desde) AND (@Hasta IS NULL OR CONVERT(date,f.Fecha)<=@Hasta) GROUP BY YEAR(f.Fecha),MONTH(f.Fecha)
   )
   SELECT Mes,CantidadFacturas,ManoObra,Repuestos,Impuesto,TotalFacturado FROM Datos ORDER BY Mes
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
 IF @Codigo=N'R12'
 BEGIN
  -- Las etapas opcionales mantienen listas JSON vacías, nunca NULL.
  IF @SoloResumen=1
  BEGIN
   ;WITH Datos AS (
SELECT o.OrdenID,o.NumeroOrden,o.FechaIngreso,o.EstadoCodigo,o.ProblemaReportado,o.NIT,o.Cliente,o.NumeroSerie,o.Recepcionista AS Recepcion,
 CASE WHEN ud.UsuarioID IS NULL THEN NULL ELSE CONCAT(ed.Nombres,N' ',ed.Apellidos) END AS TecnicoDiagnostico,
 d.Fecha AS FechaDiagnostico,d.Descripcion AS Diagnostico,r.DescripcionTrabajo,r.FechaInicio,r.FechaFin,
 CASE WHEN ut.UsuarioID IS NULL THEN NULL ELSE CONCAT(et.Nombres,N' ',et.Apellidos) END AS TecnicoReparacion,
 f.NumeroFactura,f.Estado AS EstadoFactura,ff.NombreFacturacion,f.Subtotal,f.Impuesto,f.Total,f.Pagado,f.Saldo,en.NombreRecibe,en.Fecha AS FechaEntrega,
 ISNULL((SELECT CONVERT(varchar(20),h.HistorialID) AS HistorialID,h.EstadoAnterior,h.EstadoNuevo,CONVERT(varchar(19),h.Fecha,126)+'Z' AS Fecha,CONCAT(em.Nombres,N' ',em.Apellidos) AS Responsable,h.Observacion
  FROM dbo.HistorialEstadoOrden h JOIN dbo.Usuario u ON u.UsuarioID=h.UsuarioID JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
  WHERE h.OrdenID=o.OrdenID ORDER BY h.HistorialID FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]') AS HistorialEstados,
 CASE WHEN r.ReparacionID IS NULL THEN N'[]' ELSE ISNULL((SELECT rr.Linea,p.Codigo,p.Nombre AS Repuesto,b.Nombre AS Bodega,rr.Cantidad,CONVERT(varchar(40),rr.CostoUnitario) AS CostoUnitario,
  CONVERT(varchar(40),rr.PrecioUnitario) AS PrecioUnitario,CONVERT(varchar(20),m.MovimientoID) AS MovimientoID,m.Tipo,CONVERT(varchar(19),m.Fecha,126)+'Z' AS Fecha,
  CONVERT(varchar(20),m.ExistenciaResultante) AS ExistenciaResultante
  FROM dbo.ReparacionRepuesto rr JOIN dbo.Repuesto p ON p.RepuestoID=rr.RepuestoID JOIN dbo.Bodega b ON b.BodegaID=rr.BodegaID
  LEFT JOIN dbo.MovimientoInventario m ON m.ReparacionID=rr.ReparacionID AND m.LineaReparacion=rr.Linea
  WHERE rr.ReparacionID=r.ReparacionID ORDER BY rr.Linea FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]') END AS RepuestosYMovimientos,
 CASE WHEN f.FacturaID IS NULL THEN N'[]' ELSE ISNULL((SELECT CONVERT(varchar(20),pg.PagoID) AS PagoID,CONVERT(varchar(19),pg.Fecha,126)+'Z' AS Fecha,CONVERT(varchar(40),pg.Monto) AS Monto,mp.Nombre AS Metodo,pg.Referencia
  FROM dbo.Pago pg JOIN dbo.MetodoPago mp ON mp.MetodoPagoID=pg.MetodoPagoID WHERE pg.FacturaID=f.FacturaID
  ORDER BY pg.PagoID FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]') END AS Pagos
 FROM dbo.vOrdenAcceso o LEFT JOIN dbo.Diagnostico d ON d.OrdenID=o.OrdenID
 LEFT JOIN dbo.Usuario ud ON ud.UsuarioID=d.UsuarioTecnicoID LEFT JOIN dbo.Empleado ed ON ed.EmpleadoID=ud.EmpleadoID
 LEFT JOIN dbo.Reparacion r ON r.DiagnosticoID=d.DiagnosticoID LEFT JOIN dbo.Usuario ut ON ut.UsuarioID=r.UsuarioTecnicoID
 LEFT JOIN dbo.Empleado et ON et.EmpleadoID=ut.EmpleadoID LEFT JOIN dbo.vFacturaSaldo f ON f.OrdenID=o.OrdenID
 LEFT JOIN dbo.Factura ff ON ff.FacturaID=f.FacturaID LEFT JOIN dbo.Entrega en ON en.OrdenID=o.OrdenID
 WHERE (@OrdenID IS NULL OR o.OrdenID=@OrdenID) AND (@ClienteID IS NULL OR o.ClienteID=@ClienteID)
   )
   SELECT COUNT_BIG(*) AS Total FROM Datos;
  END
  ELSE
  BEGIN
   ;WITH Datos AS (
SELECT o.OrdenID,o.NumeroOrden,o.FechaIngreso,o.EstadoCodigo,o.ProblemaReportado,o.NIT,o.Cliente,o.NumeroSerie,o.Recepcionista AS Recepcion,
 CASE WHEN ud.UsuarioID IS NULL THEN NULL ELSE CONCAT(ed.Nombres,N' ',ed.Apellidos) END AS TecnicoDiagnostico,
 d.Fecha AS FechaDiagnostico,d.Descripcion AS Diagnostico,r.DescripcionTrabajo,r.FechaInicio,r.FechaFin,
 CASE WHEN ut.UsuarioID IS NULL THEN NULL ELSE CONCAT(et.Nombres,N' ',et.Apellidos) END AS TecnicoReparacion,
 f.NumeroFactura,f.Estado AS EstadoFactura,ff.NombreFacturacion,f.Subtotal,f.Impuesto,f.Total,f.Pagado,f.Saldo,en.NombreRecibe,en.Fecha AS FechaEntrega,
 ISNULL((SELECT CONVERT(varchar(20),h.HistorialID) AS HistorialID,h.EstadoAnterior,h.EstadoNuevo,CONVERT(varchar(19),h.Fecha,126)+'Z' AS Fecha,CONCAT(em.Nombres,N' ',em.Apellidos) AS Responsable,h.Observacion
  FROM dbo.HistorialEstadoOrden h JOIN dbo.Usuario u ON u.UsuarioID=h.UsuarioID JOIN dbo.Empleado em ON em.EmpleadoID=u.EmpleadoID
  WHERE h.OrdenID=o.OrdenID ORDER BY h.HistorialID FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]') AS HistorialEstados,
 CASE WHEN r.ReparacionID IS NULL THEN N'[]' ELSE ISNULL((SELECT rr.Linea,p.Codigo,p.Nombre AS Repuesto,b.Nombre AS Bodega,rr.Cantidad,CONVERT(varchar(40),rr.CostoUnitario) AS CostoUnitario,
  CONVERT(varchar(40),rr.PrecioUnitario) AS PrecioUnitario,CONVERT(varchar(20),m.MovimientoID) AS MovimientoID,m.Tipo,CONVERT(varchar(19),m.Fecha,126)+'Z' AS Fecha,
  CONVERT(varchar(20),m.ExistenciaResultante) AS ExistenciaResultante
  FROM dbo.ReparacionRepuesto rr JOIN dbo.Repuesto p ON p.RepuestoID=rr.RepuestoID JOIN dbo.Bodega b ON b.BodegaID=rr.BodegaID
  LEFT JOIN dbo.MovimientoInventario m ON m.ReparacionID=rr.ReparacionID AND m.LineaReparacion=rr.Linea
  WHERE rr.ReparacionID=r.ReparacionID ORDER BY rr.Linea FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]') END AS RepuestosYMovimientos,
 CASE WHEN f.FacturaID IS NULL THEN N'[]' ELSE ISNULL((SELECT CONVERT(varchar(20),pg.PagoID) AS PagoID,CONVERT(varchar(19),pg.Fecha,126)+'Z' AS Fecha,CONVERT(varchar(40),pg.Monto) AS Monto,mp.Nombre AS Metodo,pg.Referencia
  FROM dbo.Pago pg JOIN dbo.MetodoPago mp ON mp.MetodoPagoID=pg.MetodoPagoID WHERE pg.FacturaID=f.FacturaID
  ORDER BY pg.PagoID FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]') END AS Pagos
 FROM dbo.vOrdenAcceso o LEFT JOIN dbo.Diagnostico d ON d.OrdenID=o.OrdenID
 LEFT JOIN dbo.Usuario ud ON ud.UsuarioID=d.UsuarioTecnicoID LEFT JOIN dbo.Empleado ed ON ed.EmpleadoID=ud.EmpleadoID
 LEFT JOIN dbo.Reparacion r ON r.DiagnosticoID=d.DiagnosticoID LEFT JOIN dbo.Usuario ut ON ut.UsuarioID=r.UsuarioTecnicoID
 LEFT JOIN dbo.Empleado et ON et.EmpleadoID=ut.EmpleadoID LEFT JOIN dbo.vFacturaSaldo f ON f.OrdenID=o.OrdenID
 LEFT JOIN dbo.Factura ff ON ff.FacturaID=f.FacturaID LEFT JOIN dbo.Entrega en ON en.OrdenID=o.OrdenID
 WHERE (@OrdenID IS NULL OR o.OrdenID=@OrdenID) AND (@ClienteID IS NULL OR o.ClienteID=@ClienteID)
   )
   SELECT OrdenID,NumeroOrden,FechaIngreso,EstadoCodigo,ProblemaReportado,NIT,Cliente,NumeroSerie,Recepcion,TecnicoDiagnostico,FechaDiagnostico,Diagnostico,DescripcionTrabajo,FechaInicio,FechaFin,TecnicoReparacion,NumeroFactura,EstadoFactura,NombreFacturacion,Subtotal,Impuesto,Total,Pagado,Saldo,NombreRecibe,FechaEntrega,HistorialEstados,RepuestosYMovimientos,Pagos FROM Datos ORDER BY OrdenID
   OFFSET (CONVERT(bigint,@Pagina)-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
  END;
  RETURN;
 END;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spOpcionesReporteApi
 @UsuarioActorID int,@Codigo nvarchar(max),@Tipo nvarchar(max),@Buscar nvarchar(max)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 EXEC dbo.spValidarReporteApi @UsuarioActorID,@Codigo;
 IF DATALENGTH(@Buscar)>300 OR @Tipo IS NULL THROW 52300,N'La búsqueda admite hasta 150 caracteres.',1;
 DECLARE @Limitado int=CASE WHEN dbo.fnTecnicoLimitadoReporteApi(@UsuarioActorID,@Codigo)=1 THEN @UsuarioActorID ELSE NULL END;
 IF @Tipo=N'clienteId' AND @Codigo IN(N'R02',N'R10',N'R11',N'R12')
 BEGIN
  SELECT TOP(100) CONVERT(nvarchar(20),ClienteID) AS Valor,CONCAT(Nombre,N' · ',NIT,CASE WHEN Activo=0 THEN N' (inactivo)' ELSE N'' END) AS Etiqueta
  FROM dbo.Cliente WHERE @Buscar IS NULL OR CHARINDEX(@Buscar,CONCAT(Nombre,N' ',NIT))>0
  ORDER BY Nombre,ClienteID;RETURN;
 END;
 IF @Tipo=N'tecnicoId' AND @Codigo IN(N'R01',N'R04',N'R05')
 BEGIN
  SELECT TOP(100) CONVERT(nvarchar(20),u.UsuarioID) AS Valor,
   CONCAT(e.Nombres,N' ',e.Apellidos,CASE WHEN u.Activo=0 OR e.Activo=0 THEN N' (inactivo)' ELSE N'' END) AS Etiqueta
  FROM dbo.Usuario u JOIN dbo.Empleado e ON e.EmpleadoID=u.EmpleadoID
  WHERE (@Limitado IS NULL OR u.UsuarioID=@Limitado) AND (@Buscar IS NULL OR CHARINDEX(@Buscar,CONCAT(e.Nombres,N' ',e.Apellidos))>0)
   AND(EXISTS(SELECT 1 FROM dbo.UsuarioRol ur WHERE ur.UsuarioID=u.UsuarioID AND ur.RolCodigo='TECNICO')
       OR EXISTS(SELECT 1 FROM dbo.Diagnostico d WHERE d.UsuarioTecnicoID=u.UsuarioID)
       OR EXISTS(SELECT 1 FROM dbo.Reparacion r WHERE r.UsuarioTecnicoID=u.UsuarioID)
       OR EXISTS(SELECT 1 FROM dbo.AsignacionOrden a WHERE a.UsuarioTecnicoID=u.UsuarioID))
  ORDER BY e.Nombres,e.Apellidos,u.UsuarioID;RETURN;
 END;
 IF @Tipo=N'bodegaId' AND @Codigo IN(N'R05',N'R06',N'R07',N'R08',N'R09')
 BEGIN
  SELECT TOP(100) CONVERT(nvarchar(20),b.BodegaID) AS Valor,CONCAT(b.Nombre,N' · ',b.Codigo,CASE WHEN b.Activo=0 THEN N' (inactiva)' ELSE N'' END) AS Etiqueta
  FROM dbo.Bodega b WHERE (@Buscar IS NULL OR CHARINDEX(@Buscar,CONCAT(b.Nombre,N' ',b.Codigo))>0)
   AND(@Limitado IS NULL OR EXISTS(SELECT 1 FROM dbo.ReparacionRepuesto rr JOIN dbo.vOrdenAcceso o ON o.ReparacionID=rr.ReparacionID WHERE rr.BodegaID=b.BodegaID AND o.UsuarioTecnicoID=@Limitado))
  ORDER BY b.Nombre,b.BodegaID;RETURN;
 END;
 IF @Tipo=N'proveedorId' AND @Codigo=N'R08'
 BEGIN
  SELECT TOP(100) CONVERT(nvarchar(20),ProveedorID) AS Valor,CONCAT(Nombre,N' · ',NIT,CASE WHEN Activo=0 THEN N' (inactivo)' ELSE N'' END) AS Etiqueta
  FROM dbo.Proveedor WHERE @Buscar IS NULL OR CHARINDEX(@Buscar,CONCAT(Nombre,N' ',NIT))>0 ORDER BY Nombre,ProveedorID;RETURN;
 END;
 IF @Tipo=N'categoriaId' AND @Codigo IN(N'R06',N'R07')
 BEGIN
  SELECT TOP(100) CONVERT(nvarchar(20),CategoriaID) AS Valor,Nombre AS Etiqueta FROM dbo.CategoriaRepuesto
  WHERE @Buscar IS NULL OR CHARINDEX(@Buscar,Nombre)>0 ORDER BY Nombre,CategoriaID;RETURN;
 END;
 IF @Tipo=N'repuestoId' AND @Codigo IN(N'R06',N'R07',N'R09')
 BEGIN
  SELECT TOP(100) CONVERT(nvarchar(20),RepuestoID) AS Valor,CONCAT(Nombre,N' · ',Codigo,CASE WHEN Activo=0 THEN N' (inactivo)' ELSE N'' END) AS Etiqueta
  FROM dbo.Repuesto WHERE @Buscar IS NULL OR CHARINDEX(@Buscar,CONCAT(Nombre,N' ',Codigo))>0 ORDER BY Nombre,RepuestoID;RETURN;
 END;
 IF @Tipo=N'ordenId' AND @Codigo IN(N'R05',N'R12')
 BEGIN
  SELECT TOP(100) CONVERT(nvarchar(20),o.OrdenID) AS Valor,o.NumeroOrden AS Etiqueta
  FROM dbo.vOrdenAcceso o WHERE (@Buscar IS NULL OR CHARINDEX(@Buscar,o.NumeroOrden)>0)
   AND(@Limitado IS NULL OR o.UsuarioTecnicoID=@Limitado)
   AND(@Codigo=N'R12' OR EXISTS(SELECT 1 FROM dbo.ReparacionRepuesto rr WHERE rr.ReparacionID=o.ReparacionID))
  ORDER BY o.NumeroOrden,o.OrdenID;RETURN;
 END;
 IF @Tipo=N'estado' AND @Codigo=N'R01'
 BEGIN
  SELECT CONVERT(nvarchar(30),Codigo) AS Valor,Nombre AS Etiqueta FROM dbo.EstadoOrden
  WHERE EsFinal=0 AND (@Buscar IS NULL OR CHARINDEX(@Buscar,Nombre)>0) ORDER BY Nombre,Codigo;RETURN;
 END;
 IF @Tipo=N'estado' AND @Codigo=N'R08'
 BEGIN
  SELECT Valor,Etiqueta FROM(VALUES(N'PENDIENTE',N'Pendiente'),(N'RECIBIDA',N'Recibida'),(N'ANULADA',N'Anulada')) e(Valor,Etiqueta)
  WHERE @Buscar IS NULL OR CHARINDEX(@Buscar,Etiqueta)>0 ORDER BY Etiqueta;RETURN;
 END;
 THROW 52300,N'Este reporte no ofrece ese catálogo de filtros.',1;
END;
GO
IF DATABASE_PRINCIPAL_ID(N'techcare_app') IS NOT NULL
BEGIN
 GRANT EXECUTE ON dbo.spCatalogoReportesApi TO techcare_app;
 GRANT EXECUTE ON dbo.spConsultarReporteApi TO techcare_app;
 GRANT EXECUTE ON dbo.spOpcionesReporteApi TO techcare_app;
END;
GO
