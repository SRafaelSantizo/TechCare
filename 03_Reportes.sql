USE [TechCare];
GO
-- Cambiar sólo los filtros necesarios. NULL significa sin filtro.
-- @Hasta es exclusivo; todas las fechas están en UTC.
DECLARE @Desde datetime2(0)=NULL,@Hasta datetime2(0)=NULL,@ClienteID int=NULL,
 @TecnicoID int=NULL,@BodegaID int=NULL,@ProveedorID int=NULL,@OrdenID int=NULL,
 @Estado varchar(30)=NULL,@Serie varchar(80)=NULL;

-- R01 / Órdenes activas por estado, prioridad y técnico responsable
SELECT o.NumeroOrden,o.FechaIngreso,eo.Nombre AS Estado,pr.Nombre AS Prioridad,c.Nombre AS Cliente,
 e.NumeroSerie,CONCAT(emp.Nombres,N' ',emp.Apellidos) AS Tecnico,r.ReparacionID
FROM dbo.OrdenServicio AS o INNER JOIN dbo.EstadoOrden AS eo ON eo.Codigo=o.EstadoCodigo
INNER JOIN dbo.Prioridad AS pr ON pr.Codigo=o.PrioridadCodigo INNER JOIN dbo.Equipo AS e ON e.EquipoID=o.EquipoID
INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID LEFT JOIN dbo.Diagnostico AS d ON d.OrdenID=o.OrdenID
LEFT JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID
LEFT JOIN dbo.Usuario AS u ON u.UsuarioID=COALESCE(r.UsuarioTecnicoID,d.UsuarioTecnicoID)
LEFT JOIN dbo.Empleado AS emp ON emp.EmpleadoID=u.EmpleadoID
WHERE eo.EsFinal=0 AND (@Estado IS NULL OR o.EstadoCodigo=@Estado) AND (@TecnicoID IS NULL OR u.UsuarioID=@TecnicoID)
 AND (@Desde IS NULL OR o.FechaIngreso>=@Desde) AND (@Hasta IS NULL OR o.FechaIngreso<@Hasta)
ORDER BY pr.Nivel DESC,o.FechaIngreso;

-- R02 / Historial completo de órdenes de un cliente, incluidos clientes sin órdenes
SELECT c.ClienteID,c.NIT,c.Nombre,e.NumeroSerie,o.NumeroOrden,o.FechaIngreso,o.EstadoCodigo,
 d.Descripcion AS Diagnostico,r.DescripcionTrabajo,f.NumeroFactura,f.Total,f.Saldo,en.Fecha AS FechaEntrega
FROM dbo.Cliente AS c LEFT JOIN dbo.Equipo AS e ON e.ClienteID=c.ClienteID
LEFT JOIN dbo.OrdenServicio AS o ON o.EquipoID=e.EquipoID LEFT JOIN dbo.Diagnostico AS d ON d.OrdenID=o.OrdenID
LEFT JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID LEFT JOIN dbo.vFacturaSaldo AS f ON f.OrdenID=o.OrdenID
LEFT JOIN dbo.Entrega AS en ON en.OrdenID=o.OrdenID
WHERE (@ClienteID IS NULL OR c.ClienteID=@ClienteID) ORDER BY c.ClienteID,o.FechaIngreso DESC;

-- R03 / Historial técnico por número de serie, incluso sin servicio
SELECT e.NumeroSerie,c.Nombre AS Cliente,te.Nombre AS Tipo,ma.Nombre AS Marca,mo.Nombre AS Modelo,
 o.NumeroOrden,o.EstadoCodigo,d.Fecha AS FechaDiagnostico,d.Descripcion,r.FechaInicio,r.FechaFin,
 r.DescripcionTrabajo,CONCAT(em.Nombres,N' ',em.Apellidos) AS TecnicoReparacion
FROM dbo.Equipo AS e INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID
INNER JOIN dbo.ModeloEquipo AS mo ON mo.ModeloEquipoID=e.ModeloEquipoID
INNER JOIN dbo.Marca AS ma ON ma.MarcaID=mo.MarcaID INNER JOIN dbo.TipoEquipo AS te ON te.TipoEquipoID=mo.TipoEquipoID
LEFT JOIN dbo.OrdenServicio AS o ON o.EquipoID=e.EquipoID LEFT JOIN dbo.Diagnostico AS d ON d.OrdenID=o.OrdenID
LEFT JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID LEFT JOIN dbo.Usuario AS u ON u.UsuarioID=r.UsuarioTecnicoID
LEFT JOIN dbo.Empleado AS em ON em.EmpleadoID=u.EmpleadoID
WHERE (@Serie IS NULL OR e.NumeroSerie=@Serie) ORDER BY e.NumeroSerie,o.FechaIngreso;

-- R04 / Diagnósticos y reparaciones por técnico y rango de fechas
SELECT 'DIAGNOSTICO' AS Proceso,d.DiagnosticoID AS RegistroID,d.Fecha AS Fecha,o.NumeroOrden,
 e.NumeroSerie,c.Nombre AS Cliente,u.UsuarioID,CONCAT(em.Nombres,N' ',em.Apellidos) AS Tecnico,
 d.Descripcion AS Trabajo,d.CostoManoObraEstimado AS ManoObra
FROM dbo.Diagnostico AS d INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=d.OrdenID
INNER JOIN dbo.Equipo AS e ON e.EquipoID=o.EquipoID INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID
INNER JOIN dbo.Usuario AS u ON u.UsuarioID=d.UsuarioTecnicoID INNER JOIN dbo.Empleado AS em ON em.EmpleadoID=u.EmpleadoID
WHERE (@TecnicoID IS NULL OR u.UsuarioID=@TecnicoID) AND (@Desde IS NULL OR d.Fecha>=@Desde) AND (@Hasta IS NULL OR d.Fecha<@Hasta)
UNION ALL
SELECT 'REPARACION',r.ReparacionID,r.FechaInicio,o.NumeroOrden,e.NumeroSerie,c.Nombre,u.UsuarioID,
 CONCAT(em.Nombres,N' ',em.Apellidos),r.DescripcionTrabajo,r.CostoManoObra
FROM dbo.Reparacion AS r INNER JOIN dbo.Diagnostico AS d ON d.DiagnosticoID=r.DiagnosticoID
INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=d.OrdenID INNER JOIN dbo.Equipo AS e ON e.EquipoID=o.EquipoID
INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID INNER JOIN dbo.Usuario AS u ON u.UsuarioID=r.UsuarioTecnicoID
INNER JOIN dbo.Empleado AS em ON em.EmpleadoID=u.EmpleadoID
WHERE (@TecnicoID IS NULL OR u.UsuarioID=@TecnicoID) AND (@Desde IS NULL OR r.FechaInicio>=@Desde) AND (@Hasta IS NULL OR r.FechaInicio<@Hasta)
ORDER BY Tecnico,Fecha;

-- R05 / Repuestos utilizados por orden, técnico y bodega con valores históricos
SELECT o.NumeroOrden,u.NombreUsuario AS Tecnico,b.Nombre AS Bodega,p.Codigo,p.Nombre,rr.Cantidad,
 rr.CostoUnitario,rr.PrecioUnitario,rr.Cantidad*rr.CostoUnitario AS CostoHistorico,
 rr.Cantidad*rr.PrecioUnitario AS VentaHistorica,m.MovimientoID,m.Fecha
FROM dbo.ReparacionRepuesto AS rr INNER JOIN dbo.Reparacion AS r ON r.ReparacionID=rr.ReparacionID
INNER JOIN dbo.Diagnostico AS d ON d.DiagnosticoID=r.DiagnosticoID INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=d.OrdenID
INNER JOIN dbo.Usuario AS u ON u.UsuarioID=r.UsuarioTecnicoID INNER JOIN dbo.Bodega AS b ON b.BodegaID=rr.BodegaID
INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=rr.RepuestoID
INNER JOIN dbo.MovimientoInventario AS m ON m.ReparacionID=rr.ReparacionID AND m.LineaReparacion=rr.Linea
WHERE (@OrdenID IS NULL OR o.OrdenID=@OrdenID) AND (@BodegaID IS NULL OR b.BodegaID=@BodegaID)
 AND (@TecnicoID IS NULL OR u.UsuarioID=@TecnicoID) ORDER BY o.NumeroOrden,rr.Linea;

-- R06 / Inventario actual por bodega, categoría y repuesto
SELECT b.Codigo AS CodigoBodega,b.Nombre AS Bodega,c.Nombre AS Categoria,p.Codigo,p.Nombre,
 i.Existencia,i.StockMinimo,p.CostoReferencia,p.PrecioVenta
FROM dbo.vInventario AS i INNER JOIN dbo.Bodega AS b ON b.BodegaID=i.BodegaID
INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=i.RepuestoID INNER JOIN dbo.CategoriaRepuesto AS c ON c.CategoriaID=p.CategoriaID
WHERE (@BodegaID IS NULL OR i.BodegaID=@BodegaID) ORDER BY b.Nombre,c.Nombre,p.Nombre;

-- R07 / Existencia igual o inferior al stock mínimo por bodega
SELECT b.Nombre AS Bodega,c.Nombre AS Categoria,p.Codigo,p.Nombre,i.Existencia,i.StockMinimo,
 i.StockMinimo-i.Existencia AS FaltanteParaMinimo
FROM dbo.vInventario AS i INNER JOIN dbo.Bodega AS b ON b.BodegaID=i.BodegaID
INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=i.RepuestoID INNER JOIN dbo.CategoriaRepuesto AS c ON c.CategoriaID=p.CategoriaID
WHERE i.Existencia<=i.StockMinimo AND (@BodegaID IS NULL OR i.BodegaID=@BodegaID)
ORDER BY b.Nombre,i.Existencia,p.Nombre;

-- R08 / Compras por proveedor con detalles y costos históricos
SELECT pr.Nombre AS Proveedor,c.NumeroCompra,c.Fecha,c.Estado,dc.Linea,p.Codigo,p.Nombre,b.Nombre AS Destino,
 dc.Cantidad,dc.CostoUnitario,dc.Cantidad*dc.CostoUnitario AS CostoLinea,u.NombreUsuario AS RegistradoPor
FROM dbo.Compra AS c INNER JOIN dbo.Proveedor AS pr ON pr.ProveedorID=c.ProveedorID
INNER JOIN dbo.DetalleCompra AS dc ON dc.CompraID=c.CompraID INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=dc.RepuestoID
INNER JOIN dbo.Bodega AS b ON b.BodegaID=dc.BodegaID INNER JOIN dbo.Usuario AS u ON u.UsuarioID=c.UsuarioRegistroID
WHERE (@ProveedorID IS NULL OR pr.ProveedorID=@ProveedorID) AND (@Desde IS NULL OR c.Fecha>=@Desde)
 AND (@Hasta IS NULL OR c.Fecha<@Hasta) ORDER BY pr.Nombre,c.Fecha,dc.Linea;

-- R09 / Kardex con origen, usuario y existencia resultante
SELECT m.MovimientoID,m.Fecha,m.Tipo,b.Nombre AS Bodega,p.Codigo,p.Nombre,m.Cantidad,m.CantidadFirmada,
 m.ExistenciaResultante,COALESCE(c.NumeroCompra,o.NumeroOrden) AS DocumentoOrigen,
 c.NumeroCompra,pr.Nombre AS Proveedor,o.NumeroOrden,u.NombreUsuario AS Responsable
FROM dbo.vMovimientoInventario AS m INNER JOIN dbo.Bodega AS b ON b.BodegaID=m.BodegaID
INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=m.RepuestoID INNER JOIN dbo.Usuario AS u ON u.UsuarioID=m.UsuarioID
LEFT JOIN dbo.Compra AS c ON c.CompraID=m.CompraID LEFT JOIN dbo.Proveedor AS pr ON pr.ProveedorID=c.ProveedorID
LEFT JOIN dbo.Reparacion AS r ON r.ReparacionID=m.ReparacionID LEFT JOIN dbo.Diagnostico AS d ON d.DiagnosticoID=r.DiagnosticoID
LEFT JOIN dbo.OrdenServicio AS o ON o.OrdenID=d.OrdenID
WHERE (@BodegaID IS NULL OR m.BodegaID=@BodegaID) AND (@Desde IS NULL OR m.Fecha>=@Desde) AND (@Hasta IS NULL OR m.Fecha<@Hasta)
ORDER BY m.MovimientoID;

-- R10 / Facturas pendientes con detalle de pagos; una fila por pago o factura sin pagos
SELECT f.NumeroFactura,c.Nombre AS Cliente,o.NumeroOrden,s.Subtotal,s.Impuesto,s.Total,s.Pagado,s.Saldo,
 pg.PagoID,pg.Fecha AS FechaPago,pg.Monto,mp.Nombre AS Metodo,u.NombreUsuario AS Cajero
FROM dbo.Factura AS f INNER JOIN dbo.vFacturaSaldo AS s ON s.FacturaID=f.FacturaID
INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=f.OrdenID INNER JOIN dbo.Equipo AS e ON e.EquipoID=o.EquipoID
INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID LEFT JOIN dbo.Pago AS pg ON pg.FacturaID=f.FacturaID
LEFT JOIN dbo.MetodoPago AS mp ON mp.MetodoPagoID=pg.MetodoPagoID LEFT JOIN dbo.Usuario AS u ON u.UsuarioID=pg.UsuarioRegistroID
WHERE f.Estado='EMITIDA' AND s.Saldo>0 AND (@ClienteID IS NULL OR c.ClienteID=@ClienteID)
ORDER BY f.Fecha,pg.Fecha,pg.PagoID;
-- No sumar Total/Saldo sobre este resultado: el encabezado se repite por cada pago.
-- Para agregados financieros utilice vFacturaSaldo (una fila por factura).

-- R11 / Ingresos facturados por mes, separando mano de obra, repuestos e impuesto
WITH porFactura AS (
 SELECT fd.FacturaID,
 SUM(CASE WHEN fd.TipoConcepto='MO' THEN CONVERT(decimal(18,2),fd.Cantidad*fd.PrecioUnitario) ELSE 0 END) AS ManoObra,
 SUM(CASE WHEN fd.TipoConcepto='REP' THEN CONVERT(decimal(18,2),fd.Cantidad*fd.PrecioUnitario) ELSE 0 END) AS Repuestos
 FROM dbo.FacturaDetalle AS fd GROUP BY fd.FacturaID
)
SELECT DATEFROMPARTS(YEAR(f.Fecha),MONTH(f.Fecha),1) AS Mes,COUNT_BIG(1) AS CantidadFacturas,
 SUM(pf.ManoObra) AS ManoObra,SUM(pf.Repuestos) AS Repuestos,
 SUM(ROUND((pf.ManoObra+pf.Repuestos)*f.TasaImpuesto,2)) AS Impuesto,
 SUM(pf.ManoObra+pf.Repuestos+ROUND((pf.ManoObra+pf.Repuestos)*f.TasaImpuesto,2)) AS TotalFacturado
FROM dbo.Factura AS f INNER JOIN porFactura AS pf ON pf.FacturaID=f.FacturaID
INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=f.OrdenID INNER JOIN dbo.Equipo AS e ON e.EquipoID=o.EquipoID
INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID
WHERE f.Estado='EMITIDA' AND (@Desde IS NULL OR f.Fecha>=@Desde) AND (@Hasta IS NULL OR f.Fecha<@Hasta)
 AND (@ClienteID IS NULL OR c.ClienteID=@ClienteID)
GROUP BY YEAR(f.Fecha),MONTH(f.Fecha) ORDER BY Mes;
-- Ingresos facturados (devengado), distintos del efectivo cobrado en Pago.

-- R12 / Trazabilidad completa sin multiplicar repuestos por pagos
SELECT o.OrdenID,o.NumeroOrden,o.FechaIngreso,o.EstadoCodigo,o.ProblemaReportado,c.NIT,c.Nombre AS Cliente,
 e.NumeroSerie,ur.NombreUsuario AS Recepcion,ud.NombreUsuario AS TecnicoDiagnostico,d.Fecha AS FechaDiagnostico,
 d.Descripcion AS Diagnostico,r.ReparacionID,r.DescripcionTrabajo,r.FechaInicio,r.FechaFin,
 ut.NombreUsuario AS TecnicoReparacion,f.NumeroFactura,f.Subtotal,f.Impuesto,f.Total,f.Pagado,f.Saldo,
 en.NombreRecibe,en.Fecha AS FechaEntrega,
 (SELECT h.EstadoAnterior,h.EstadoNuevo,h.Fecha,u.NombreUsuario,h.Observacion
  FROM dbo.HistorialEstadoOrden AS h INNER JOIN dbo.Usuario AS u ON u.UsuarioID=h.UsuarioID
  WHERE h.OrdenID=o.OrdenID ORDER BY h.HistorialID FOR JSON PATH) AS HistorialEstados,
 (SELECT rr.Linea,p.Codigo,p.Nombre,b.Nombre AS Bodega,rr.Cantidad,rr.CostoUnitario,rr.PrecioUnitario,
         m.MovimientoID,m.Tipo,m.Fecha,m.ExistenciaResultante
  FROM dbo.ReparacionRepuesto AS rr INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=rr.RepuestoID
  INNER JOIN dbo.Bodega AS b ON b.BodegaID=rr.BodegaID
  LEFT JOIN dbo.MovimientoInventario AS m ON m.ReparacionID=rr.ReparacionID AND m.LineaReparacion=rr.Linea
  WHERE rr.ReparacionID=r.ReparacionID ORDER BY rr.Linea FOR JSON PATH) AS RepuestosYMovimientos,
 (SELECT pg.PagoID,pg.Fecha,pg.Monto,mp.Nombre AS Metodo,pg.Referencia
  FROM dbo.Pago AS pg INNER JOIN dbo.MetodoPago AS mp ON mp.MetodoPagoID=pg.MetodoPagoID
  WHERE pg.FacturaID=f.FacturaID ORDER BY pg.PagoID FOR JSON PATH) AS Pagos
FROM dbo.OrdenServicio AS o INNER JOIN dbo.Equipo AS e ON e.EquipoID=o.EquipoID
INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID INNER JOIN dbo.Usuario AS ur ON ur.UsuarioID=o.UsuarioRecepcionID
LEFT JOIN dbo.Diagnostico AS d ON d.OrdenID=o.OrdenID LEFT JOIN dbo.Usuario AS ud ON ud.UsuarioID=d.UsuarioTecnicoID
LEFT JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID LEFT JOIN dbo.Usuario AS ut ON ut.UsuarioID=r.UsuarioTecnicoID
LEFT JOIN dbo.vFacturaSaldo AS f ON f.OrdenID=o.OrdenID LEFT JOIN dbo.Entrega AS en ON en.OrdenID=o.OrdenID
WHERE (@OrdenID IS NULL OR o.OrdenID=@OrdenID) AND (@ClienteID IS NULL OR c.ClienteID=@ClienteID)
ORDER BY o.OrdenID;
-- Una fila por orden. Las listas JSON independientes evitan la unión N repuestos x M pagos.
-- Una orden sin diagnóstico, factura o pagos permanece en el resultado.