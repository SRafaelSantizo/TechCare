
-- ============================================================================
-- 01 / BASE Y TABLAS - SQL Server 2019 o posterior; ejecutar con SSMS o sqlcmd
-- ============================================================================

IF DB_ID(N'TechCare') IS NULL EXEC(N'CREATE DATABASE [TechCare]');
GO

USE [TechCare];
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF;
IF EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID(N'dbo'))
BEGIN
 RAISERROR(N'TechCare ya contiene tablas. Use una base nueva; este script no borra datos.',16,1);
 SET NOEXEC ON;
END;
GO

-- Clasifica clientes individuales y empresariales.
CREATE TABLE dbo.TipoCliente (
                                 TipoClienteID tinyint NOT NULL,
                                 Nombre nvarchar(30) NOT NULL UNIQUE,
                                 CONSTRAINT PK_TipoCliente PRIMARY KEY (TipoClienteID)
);
GO

-- Identidad fiscal y contacto principal del cliente.
CREATE TABLE dbo.Cliente (
                             ClienteID int IDENTITY(1,1) NOT NULL,
                             TipoClienteID tinyint NOT NULL,
                             NIT varchar(20) NOT NULL UNIQUE,
                             Nombre nvarchar(150) NOT NULL,
                             Email nvarchar(254) NULL,
                             Telefono varchar(25) NULL,
                             Direccion nvarchar(250) NULL,
                             Activo bit NOT NULL DEFAULT 1,
                             CONSTRAINT PK_Cliente PRIMARY KEY (ClienteID),
                             CONSTRAINT CK_Cliente_NIT CHECK (LEN(LTRIM(RTRIM(NIT))) > 0)
);
GO

-- Datos laborales independientes de la cuenta de acceso.
CREATE TABLE dbo.Empleado (
                              EmpleadoID int IDENTITY(1,1) NOT NULL,
                              Codigo varchar(20) NOT NULL UNIQUE,
                              Nombres nvarchar(80) NOT NULL,
                              Apellidos nvarchar(80) NOT NULL,
                              Activo bit NOT NULL DEFAULT 1,
                              CONSTRAINT PK_Empleado PRIMARY KEY (EmpleadoID)
);
GO

-- Cuenta vinculada de forma única con un empleado.
CREATE TABLE dbo.Usuario (
                             UsuarioID int IDENTITY(1,1) NOT NULL,
                             EmpleadoID int NOT NULL UNIQUE,
                             NombreUsuario varchar(50) NOT NULL UNIQUE,
                             PasswordHash varchar(255) NOT NULL,
                             AlgoritmoHash varchar(30) NOT NULL DEFAULT 'PBKDF2_SHA256',
                             Activo bit NOT NULL DEFAULT 1,
                             FechaCreacion datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                             CONSTRAINT PK_Usuario PRIMARY KEY (UsuarioID),
                             CONSTRAINT CK_Usuario_Hash CHECK (LEN(PasswordHash) >= 60)
);
GO

-- Roles funcionales de la aplicación.
CREATE TABLE dbo.Rol (
                         Codigo varchar(20) NOT NULL,
                         Nombre nvarchar(50) NOT NULL UNIQUE,
                         CONSTRAINT PK_Rol PRIMARY KEY (Codigo)
);
GO

-- Asociación N:M de usuarios y roles.
CREATE TABLE dbo.UsuarioRol (
                                UsuarioID int NOT NULL,
                                RolCodigo varchar(20) NOT NULL,
                                CONSTRAINT PK_UsuarioRol PRIMARY KEY (UsuarioID, RolCodigo)
);
GO

-- Categoría técnica de un modelo de equipo.
CREATE TABLE dbo.TipoEquipo (
                                TipoEquipoID tinyint NOT NULL,
                                Nombre nvarchar(50) NOT NULL UNIQUE,
                                CONSTRAINT PK_TipoEquipo PRIMARY KEY (TipoEquipoID)
);
GO

-- Fabricante de un modelo.
CREATE TABLE dbo.Marca (
                           MarcaID int IDENTITY(1,1) NOT NULL,
                           Nombre nvarchar(60) NOT NULL UNIQUE,
                           CONSTRAINT PK_Marca PRIMARY KEY (MarcaID)
);
GO

-- Un modelo determina su marca y tipo; no se duplican en Equipo.
CREATE TABLE dbo.ModeloEquipo (
                                  ModeloEquipoID int IDENTITY(1,1) NOT NULL,
                                  MarcaID int NOT NULL,
                                  TipoEquipoID tinyint NOT NULL,
                                  Nombre nvarchar(80) NOT NULL,
                                  CONSTRAINT PK_ModeloEquipo PRIMARY KEY (ModeloEquipoID),
                                  CONSTRAINT UQ_ModeloEquipo UNIQUE (MarcaID, TipoEquipoID, Nombre)
);
GO

-- Equipo de propietario fijo dentro del alcance del proyecto.
CREATE TABLE dbo.Equipo (
                            EquipoID int IDENTITY(1,1) NOT NULL,
                            ClienteID int NOT NULL,
                            ModeloEquipoID int NOT NULL,
                            NumeroSerie varchar(80) NOT NULL UNIQUE,
                            Descripcion nvarchar(500) NOT NULL,
                            Activo bit NOT NULL DEFAULT 1,
                            CONSTRAINT PK_Equipo PRIMARY KEY (EquipoID)
);
GO

-- Prioridad y orden de atención.
CREATE TABLE dbo.Prioridad (
                               Codigo varchar(10) NOT NULL,
                               Nombre nvarchar(30) NOT NULL UNIQUE,
                               Nivel tinyint NOT NULL UNIQUE,
                               CONSTRAINT PK_Prioridad PRIMARY KEY (Codigo),
                               CONSTRAINT CK_Prioridad_Nivel CHECK (Nivel BETWEEN 1 AND 4)
);
GO

-- Estados del ciclo de servicio.
CREATE TABLE dbo.EstadoOrden (
                                 Codigo varchar(30) NOT NULL,
                                 Nombre nvarchar(50) NOT NULL UNIQUE,
                                 EsFinal bit NOT NULL DEFAULT 0,
                                 CONSTRAINT PK_EstadoOrden PRIMARY KEY (Codigo)
);
GO

-- Aristas permitidas del ciclo de estados.
CREATE TABLE dbo.TransicionEstadoOrden (
                                           EstadoOrigen varchar(30) NOT NULL,
                                           EstadoDestino varchar(30) NOT NULL,
                                           CONSTRAINT PK_TransicionEstadoOrden PRIMARY KEY (EstadoOrigen, EstadoDestino),
                                           CONSTRAINT CK_Transicion_Distinta CHECK (EstadoOrigen <> EstadoDestino)
);
GO

-- Ingreso del equipo; el cliente se obtiene a través de Equipo.
CREATE TABLE dbo.OrdenServicio (
                                   OrdenID int IDENTITY(1,1) NOT NULL,
                                   NumeroOrden varchar(30) NOT NULL UNIQUE,
                                   EquipoID int NOT NULL,
                                   UsuarioRecepcionID int NOT NULL,
                                   FechaIngreso datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                                   ProblemaReportado nvarchar(1000) NOT NULL,
                                   PrioridadCodigo varchar(10) NOT NULL DEFAULT 'NORMAL',
                                   EstadoCodigo varchar(30) NOT NULL DEFAULT 'RECIBIDO',
                                   FechaEstimada datetime2(0) NULL,
                                   Observaciones nvarchar(1000) NULL,
                                   UsuarioCambioID int NOT NULL,
                                   FechaCambio datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                                   ObservacionCambio nvarchar(500) NULL,
                                   CONSTRAINT PK_OrdenServicio PRIMARY KEY (OrdenID),
                                   CONSTRAINT CK_Orden_Fechas CHECK (FechaCambio >= FechaIngreso AND (FechaEstimada IS NULL OR FechaEstimada >= FechaIngreso)),
                                   CONSTRAINT CK_Orden_Problema CHECK (LEN(LTRIM(RTRIM(ProblemaReportado))) > 0)
);
GO

-- Eventos inmutables de cambio de estado, incluido el ingreso.
CREATE TABLE dbo.HistorialEstadoOrden (
                                          HistorialID bigint IDENTITY(1,1) NOT NULL,
                                          OrdenID int NOT NULL,
                                          EstadoAnterior varchar(30) NULL,
                                          EstadoNuevo varchar(30) NOT NULL,
                                          Fecha datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                                          UsuarioID int NOT NULL,
                                          Observacion nvarchar(500) NULL,
                                          CONSTRAINT PK_HistorialEstadoOrden PRIMARY KEY (HistorialID)
);
GO

-- Un diagnóstico consolidado por orden; puede no tener reparación.
CREATE TABLE dbo.Diagnostico (
                                 DiagnosticoID int IDENTITY(1,1) NOT NULL,
                                 OrdenID int NOT NULL UNIQUE,
                                 UsuarioTecnicoID int NOT NULL,
                                 Fecha datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                                 Descripcion nvarchar(2000) NOT NULL,
                                 CostoManoObraEstimado decimal(12,2) NOT NULL,
                                 CONSTRAINT PK_Diagnostico PRIMARY KEY (DiagnosticoID),
                                 CONSTRAINT CK_Diagnostico_Costo CHECK (CostoManoObraEstimado >= 0)
);
GO

-- Una reparación por diagnóstico con actividades y consumos.
CREATE TABLE dbo.Reparacion (
                                ReparacionID int IDENTITY(1,1) NOT NULL,
                                DiagnosticoID int NOT NULL UNIQUE,
                                UsuarioTecnicoID int NOT NULL,
                                FechaInicio datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                                FechaFin datetime2(0) NULL,
                                DescripcionTrabajo nvarchar(2000) NOT NULL,
                                CostoManoObra decimal(12,2) NOT NULL,
                                Estado varchar(15) NOT NULL DEFAULT 'EN_PROCESO',
                                CONSTRAINT PK_Reparacion PRIMARY KEY (ReparacionID),
                                CONSTRAINT CK_Reparacion_Estado CHECK (Estado IN ('EN_PROCESO','TERMINADA')),
                                CONSTRAINT CK_Reparacion_Fechas CHECK ((Estado = 'EN_PROCESO' AND FechaFin IS NULL) OR (Estado = 'TERMINADA' AND FechaFin IS NOT NULL AND FechaFin >= FechaInicio)),
                                CONSTRAINT CK_Reparacion_Costo CHECK (CostoManoObra >= 0)
);
GO

-- Catálogo de tareas técnicas reutilizables.
CREATE TABLE dbo.Actividad (
                               ActividadID int IDENTITY(1,1) NOT NULL,
                               Nombre nvarchar(100) NOT NULL UNIQUE,
                               Activo bit NOT NULL DEFAULT 1,
                               CONSTRAINT PK_Actividad PRIMARY KEY (ActividadID)
);
GO

-- Asociación N:M de reparaciones y tareas efectuadas.
CREATE TABLE dbo.ReparacionActividad (
                                         ReparacionID int NOT NULL,
                                         ActividadID int NOT NULL,
                                         Fecha datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                                         Observacion nvarchar(500) NULL,
                                         CONSTRAINT PK_ReparacionActividad PRIMARY KEY (ReparacionID, ActividadID)
);
GO

-- Clasificación de repuestos.
CREATE TABLE dbo.CategoriaRepuesto (
                                       CategoriaID int IDENTITY(1,1) NOT NULL,
                                       Nombre nvarchar(80) NOT NULL UNIQUE,
                                       CONSTRAINT PK_CategoriaRepuesto PRIMARY KEY (CategoriaID)
);
GO

-- Catálogo con precios actuales de referencia.
CREATE TABLE dbo.Repuesto (
                              RepuestoID int IDENTITY(1,1) NOT NULL,
                              CategoriaID int NOT NULL,
                              Codigo varchar(30) NOT NULL UNIQUE,
                              Nombre nvarchar(100) NOT NULL,
                              Descripcion nvarchar(500) NULL,
                              CostoReferencia decimal(12,2) NOT NULL,
                              PrecioVenta decimal(12,2) NOT NULL,
                              Activo bit NOT NULL DEFAULT 1,
                              CONSTRAINT PK_Repuesto PRIMARY KEY (RepuestoID),
                              CONSTRAINT CK_Repuesto_Precios CHECK (CostoReferencia >= 0 AND PrecioVenta >= 0)
);
GO

-- Identidad fiscal y contacto del proveedor.
CREATE TABLE dbo.Proveedor (
                               ProveedorID int IDENTITY(1,1) NOT NULL,
                               NIT varchar(20) NOT NULL UNIQUE,
                               Nombre nvarchar(150) NOT NULL,
                               Email nvarchar(254) NULL,
                               Telefono varchar(25) NULL,
                               Direccion nvarchar(250) NULL,
                               Activo bit NOT NULL DEFAULT 1,
                               CONSTRAINT PK_Proveedor PRIMARY KEY (ProveedorID)
);
GO

-- Asociación N:M del catálogo ofrecido por cada proveedor.
CREATE TABLE dbo.ProveedorRepuesto (
                                       ProveedorID int NOT NULL,
                                       RepuestoID int NOT NULL,
                                       CodigoProveedor varchar(50) NULL,
                                       CONSTRAINT PK_ProveedorRepuesto PRIMARY KEY (ProveedorID, RepuestoID)
);
GO

-- Ubicación de almacenamiento.
CREATE TABLE dbo.Bodega (
                            BodegaID int IDENTITY(1,1) NOT NULL,
                            Codigo varchar(20) NOT NULL UNIQUE,
                            Nombre nvarchar(100) NOT NULL,
                            Direccion nvarchar(250) NULL,
                            Activo bit NOT NULL DEFAULT 1,
                            CONSTRAINT PK_Bodega PRIMARY KEY (BodegaID)
);
GO

-- Asociación N:M repuesto/bodega y mínimo local; stock en vInventario.
CREATE TABLE dbo.Inventario (
                                BodegaID int NOT NULL,
                                RepuestoID int NOT NULL,
                                StockMinimo int NOT NULL DEFAULT 5,
                                CONSTRAINT PK_Inventario PRIMARY KEY (BodegaID, RepuestoID),
                                CONSTRAINT CK_Inventario_Minimo CHECK (StockMinimo >= 0)
);
GO

-- Encabezado de compra; la recepción es completa y única.
CREATE TABLE dbo.Compra (
                            CompraID int IDENTITY(1,1) NOT NULL,
                            NumeroCompra varchar(30) NOT NULL UNIQUE,
                            ProveedorID int NOT NULL,
                            UsuarioRegistroID int NOT NULL,
                            Fecha datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                            Estado varchar(12) NOT NULL DEFAULT 'PENDIENTE',
                            FechaRecepcion datetime2(0) NULL,
                            Observaciones nvarchar(1000) NULL,
                            CONSTRAINT PK_Compra PRIMARY KEY (CompraID),
                            CONSTRAINT CK_Compra_Estado CHECK (Estado IN ('PENDIENTE','RECIBIDA','ANULADA')),
                            CONSTRAINT CK_Compra_Recepcion CHECK ((Estado = 'RECIBIDA' AND FechaRecepcion IS NOT NULL AND FechaRecepcion >= Fecha) OR (Estado <> 'RECIBIDA' AND FechaRecepcion IS NULL))
);
GO

-- Líneas con cantidad, costo histórico y bodega destino.
CREATE TABLE dbo.DetalleCompra (
                                   CompraID int NOT NULL,
                                   Linea smallint NOT NULL,
                                   BodegaID int NOT NULL,
                                   RepuestoID int NOT NULL,
                                   Cantidad int NOT NULL,
                                   CostoUnitario decimal(12,2) NOT NULL,
                                   CONSTRAINT PK_DetalleCompra PRIMARY KEY (CompraID, Linea),
                                   CONSTRAINT CK_DetalleCompra_Valores CHECK (Linea > 0 AND Cantidad > 0 AND CostoUnitario >= 0)
);
GO

-- Consumos con cantidad y precio/costo históricos.
CREATE TABLE dbo.ReparacionRepuesto (
                                        ReparacionID int NOT NULL,
                                        Linea smallint NOT NULL,
                                        BodegaID int NOT NULL,
                                        RepuestoID int NOT NULL,
                                        Cantidad int NOT NULL,
                                        CostoUnitario decimal(12,2) NOT NULL,
                                        PrecioUnitario decimal(12,2) NOT NULL,
                                        CONSTRAINT PK_ReparacionRepuesto PRIMARY KEY (ReparacionID, Linea),
                                        CONSTRAINT CK_ReparacionRepuesto_Valores CHECK (Linea > 0 AND Cantidad > 0 AND CostoUnitario >= 0 AND PrecioUnitario >= 0)
);
GO

-- Evento con FK al detalle origen; cantidad, bodega y repuesto se obtienen de ese detalle.
CREATE TABLE dbo.MovimientoInventario (
                                          MovimientoID bigint IDENTITY(1,1) NOT NULL,
                                          CompraID int NULL,
                                          LineaCompra smallint NULL,
                                          ReparacionID int NULL,
                                          LineaReparacion smallint NULL,
                                          Fecha datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                                          UsuarioID int NOT NULL,
                                          ExistenciaResultante bigint NOT NULL,
                                          Tipo AS CONVERT(char(1), CASE WHEN CompraID IS NOT NULL THEN 'E' ELSE 'S' END) PERSISTED,
                                          CONSTRAINT PK_MovimientoInventario PRIMARY KEY (MovimientoID),
                                          CONSTRAINT CK_Movimiento_Origen CHECK ((CompraID IS NOT NULL AND LineaCompra IS NOT NULL AND ReparacionID IS NULL AND LineaReparacion IS NULL) OR (CompraID IS NULL AND LineaCompra IS NULL AND ReparacionID IS NOT NULL AND LineaReparacion IS NOT NULL)),
                                          CONSTRAINT CK_Movimiento_Existencia CHECK (ExistenciaResultante >= 0)
);
GO

-- Documento fiscal histórico de una orden; totales calculados en vFacturaSaldo.
CREATE TABLE dbo.Factura (
                             FacturaID int IDENTITY(1,1) NOT NULL,
                             NumeroFactura varchar(30) NOT NULL UNIQUE,
                             OrdenID int NOT NULL UNIQUE,
                             UsuarioEmisionID int NOT NULL,
                             Fecha datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                             NITFacturacion varchar(20) NOT NULL,
                             NombreFacturacion nvarchar(150) NOT NULL,
                             DireccionFacturacion nvarchar(250) NULL,
                             TasaImpuesto decimal(5,4) NOT NULL DEFAULT 0.1200,
                             Estado varchar(10) NOT NULL DEFAULT 'EMITIDA',
                             CONSTRAINT PK_Factura PRIMARY KEY (FacturaID),
                             CONSTRAINT CK_Factura_Impuesto CHECK (TasaImpuesto BETWEEN 0 AND 1),
                             CONSTRAINT CK_Factura_Estado CHECK (Estado IN ('EMITIDA','ANULADA'))
);
GO

-- Concepto facturado y precio pactado; nunca lee el precio actual.
CREATE TABLE dbo.FacturaDetalle (
                                    FacturaID int NOT NULL,
                                    Linea smallint NOT NULL,
                                    TipoConcepto varchar(3) NOT NULL,
                                    ReparacionID int NOT NULL,
                                    LineaReparacion smallint NULL,
                                    Concepto nvarchar(200) NOT NULL,
                                    Cantidad int NOT NULL,
                                    PrecioUnitario decimal(12,2) NOT NULL,
                                    CONSTRAINT PK_FacturaDetalle PRIMARY KEY (FacturaID, Linea),
                                    CONSTRAINT CK_FacturaDetalle_Tipo CHECK ((TipoConcepto = 'MO' AND LineaReparacion IS NULL AND Cantidad = 1) OR (TipoConcepto = 'REP' AND LineaReparacion IS NOT NULL)),
                                    CONSTRAINT CK_FacturaDetalle_Valores CHECK (Linea > 0 AND Cantidad > 0 AND PrecioUnitario >= 0)
);
GO

-- Medios de pago permitidos.
CREATE TABLE dbo.MetodoPago (
                                MetodoPagoID tinyint NOT NULL,
                                Nombre nvarchar(40) NOT NULL UNIQUE,
                                CONSTRAINT PK_MetodoPago PRIMARY KEY (MetodoPagoID)
);
GO

-- Abono inmutable; múltiples pagos por factura.
CREATE TABLE dbo.Pago (
                          PagoID bigint IDENTITY(1,1) NOT NULL,
                          FacturaID int NOT NULL,
                          MetodoPagoID tinyint NOT NULL,
                          UsuarioRegistroID int NOT NULL,
                          Fecha datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                          Monto decimal(12,2) NOT NULL,
                          Referencia nvarchar(100) NULL,
                          CONSTRAINT PK_Pago PRIMARY KEY (PagoID),
                          CONSTRAINT CK_Pago_Monto CHECK (Monto > 0)
);
GO

-- Cierre único con identificación de la persona que recibe.
CREATE TABLE dbo.Entrega (
                             OrdenID int NOT NULL,
                             UsuarioEntregaID int NOT NULL,
                             NombreRecibe nvarchar(150) NOT NULL,
                             DocumentoRecibe varchar(30) NULL,
                             Fecha datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                             Observaciones nvarchar(1000) NULL,
                             CONSTRAINT PK_Entrega PRIMARY KEY (OrdenID)
);
GO

-- Eventos de auditoría de cambio de costo/precio del catálogo.
CREATE TABLE dbo.AuditoriaPrecioRepuesto (
                                             AuditoriaID bigint IDENTITY(1,1) NOT NULL,
                                             RepuestoID int NOT NULL,
                                             CostoAnterior decimal(12,2) NOT NULL,
                                             CostoNuevo decimal(12,2) NOT NULL,
                                             PrecioAnterior decimal(12,2) NOT NULL,
                                             PrecioNuevo decimal(12,2) NOT NULL,
                                             Fecha datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                                             LoginSQL nvarchar(128) NOT NULL,
                                             UsuarioAplicacionID int NULL,
                                             CONSTRAINT PK_AuditoriaPrecioRepuesto PRIMARY KEY (AuditoriaID)
);
GO


-- ============================================================================
-- 02 / CLAVES FORANEAS - Sin borrado en cascada de historia
-- ============================================================================

ALTER TABLE dbo.Cliente ADD CONSTRAINT FK_Cliente_TipoClienteID FOREIGN KEY (TipoClienteID) REFERENCES dbo.TipoCliente (TipoClienteID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Usuario ADD CONSTRAINT FK_Usuario_EmpleadoID FOREIGN KEY (EmpleadoID) REFERENCES dbo.Empleado (EmpleadoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.UsuarioRol ADD CONSTRAINT FK_UsuarioRol_UsuarioID FOREIGN KEY (UsuarioID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.UsuarioRol ADD CONSTRAINT FK_UsuarioRol_RolCodigo FOREIGN KEY (RolCodigo) REFERENCES dbo.Rol (Codigo) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.ModeloEquipo ADD CONSTRAINT FK_ModeloEquipo_MarcaID FOREIGN KEY (MarcaID) REFERENCES dbo.Marca (MarcaID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.ModeloEquipo ADD CONSTRAINT FK_ModeloEquipo_TipoEquipoID FOREIGN KEY (TipoEquipoID) REFERENCES dbo.TipoEquipo (TipoEquipoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Equipo ADD CONSTRAINT FK_Equipo_ClienteID FOREIGN KEY (ClienteID) REFERENCES dbo.Cliente (ClienteID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Equipo ADD CONSTRAINT FK_Equipo_ModeloEquipoID FOREIGN KEY (ModeloEquipoID) REFERENCES dbo.ModeloEquipo (ModeloEquipoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.TransicionEstadoOrden ADD CONSTRAINT FK_TransicionEstadoOrden_EstadoOrigen FOREIGN KEY (EstadoOrigen) REFERENCES dbo.EstadoOrden (Codigo) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.TransicionEstadoOrden ADD CONSTRAINT FK_TransicionEstadoOrden_EstadoDestino FOREIGN KEY (EstadoDestino) REFERENCES dbo.EstadoOrden (Codigo) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.OrdenServicio ADD CONSTRAINT FK_OrdenServicio_EquipoID FOREIGN KEY (EquipoID) REFERENCES dbo.Equipo (EquipoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.OrdenServicio ADD CONSTRAINT FK_OrdenServicio_UsuarioRecepcionID FOREIGN KEY (UsuarioRecepcionID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.OrdenServicio ADD CONSTRAINT FK_OrdenServicio_UsuarioCambioID FOREIGN KEY (UsuarioCambioID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.OrdenServicio ADD CONSTRAINT FK_OrdenServicio_PrioridadCodigo FOREIGN KEY (PrioridadCodigo) REFERENCES dbo.Prioridad (Codigo) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.OrdenServicio ADD CONSTRAINT FK_OrdenServicio_EstadoCodigo FOREIGN KEY (EstadoCodigo) REFERENCES dbo.EstadoOrden (Codigo) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.HistorialEstadoOrden ADD CONSTRAINT FK_HistorialEstadoOrden_OrdenID FOREIGN KEY (OrdenID) REFERENCES dbo.OrdenServicio (OrdenID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.HistorialEstadoOrden ADD CONSTRAINT FK_HistorialEstadoOrden_EstadoAnterior FOREIGN KEY (EstadoAnterior) REFERENCES dbo.EstadoOrden (Codigo) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.HistorialEstadoOrden ADD CONSTRAINT FK_HistorialEstadoOrden_EstadoNuevo FOREIGN KEY (EstadoNuevo) REFERENCES dbo.EstadoOrden (Codigo) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.HistorialEstadoOrden ADD CONSTRAINT FK_HistorialEstadoOrden_UsuarioID FOREIGN KEY (UsuarioID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Diagnostico ADD CONSTRAINT FK_Diagnostico_OrdenID FOREIGN KEY (OrdenID) REFERENCES dbo.OrdenServicio (OrdenID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Diagnostico ADD CONSTRAINT FK_Diagnostico_UsuarioTecnicoID FOREIGN KEY (UsuarioTecnicoID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Reparacion ADD CONSTRAINT FK_Reparacion_DiagnosticoID FOREIGN KEY (DiagnosticoID) REFERENCES dbo.Diagnostico (DiagnosticoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Reparacion ADD CONSTRAINT FK_Reparacion_UsuarioTecnicoID FOREIGN KEY (UsuarioTecnicoID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.ReparacionActividad ADD CONSTRAINT FK_ReparacionActividad_ReparacionID FOREIGN KEY (ReparacionID) REFERENCES dbo.Reparacion (ReparacionID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.ReparacionActividad ADD CONSTRAINT FK_ReparacionActividad_ActividadID FOREIGN KEY (ActividadID) REFERENCES dbo.Actividad (ActividadID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Repuesto ADD CONSTRAINT FK_Repuesto_CategoriaID FOREIGN KEY (CategoriaID) REFERENCES dbo.CategoriaRepuesto (CategoriaID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.ProveedorRepuesto ADD CONSTRAINT FK_ProveedorRepuesto_ProveedorID FOREIGN KEY (ProveedorID) REFERENCES dbo.Proveedor (ProveedorID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.ProveedorRepuesto ADD CONSTRAINT FK_ProveedorRepuesto_RepuestoID FOREIGN KEY (RepuestoID) REFERENCES dbo.Repuesto (RepuestoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Inventario ADD CONSTRAINT FK_Inventario_BodegaID FOREIGN KEY (BodegaID) REFERENCES dbo.Bodega (BodegaID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Inventario ADD CONSTRAINT FK_Inventario_RepuestoID FOREIGN KEY (RepuestoID) REFERENCES dbo.Repuesto (RepuestoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Compra ADD CONSTRAINT FK_Compra_ProveedorID FOREIGN KEY (ProveedorID) REFERENCES dbo.Proveedor (ProveedorID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Compra ADD CONSTRAINT FK_Compra_UsuarioRegistroID FOREIGN KEY (UsuarioRegistroID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.DetalleCompra ADD CONSTRAINT FK_DetalleCompra_CompraID FOREIGN KEY (CompraID) REFERENCES dbo.Compra (CompraID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.DetalleCompra ADD CONSTRAINT FK_DetalleCompra_BodegaID_RepuestoID FOREIGN KEY (BodegaID, RepuestoID) REFERENCES dbo.Inventario (BodegaID, RepuestoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.ReparacionRepuesto ADD CONSTRAINT FK_ReparacionRepuesto_ReparacionID FOREIGN KEY (ReparacionID) REFERENCES dbo.Reparacion (ReparacionID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.ReparacionRepuesto ADD CONSTRAINT FK_ReparacionRepuesto_BodegaID_RepuestoID FOREIGN KEY (BodegaID, RepuestoID) REFERENCES dbo.Inventario (BodegaID, RepuestoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT FK_MovimientoInventario_CompraID_LineaCompra FOREIGN KEY (CompraID, LineaCompra) REFERENCES dbo.DetalleCompra (CompraID, Linea) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT FK_MovimientoInventario_ReparacionID_LineaReparacion FOREIGN KEY (ReparacionID, LineaReparacion) REFERENCES dbo.ReparacionRepuesto (ReparacionID, Linea) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.MovimientoInventario ADD CONSTRAINT FK_MovimientoInventario_UsuarioID FOREIGN KEY (UsuarioID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Factura ADD CONSTRAINT FK_Factura_OrdenID FOREIGN KEY (OrdenID) REFERENCES dbo.OrdenServicio (OrdenID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Factura ADD CONSTRAINT FK_Factura_UsuarioEmisionID FOREIGN KEY (UsuarioEmisionID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.FacturaDetalle ADD CONSTRAINT FK_FacturaDetalle_FacturaID FOREIGN KEY (FacturaID) REFERENCES dbo.Factura (FacturaID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.FacturaDetalle ADD CONSTRAINT FK_FacturaDetalle_ReparacionID FOREIGN KEY (ReparacionID) REFERENCES dbo.Reparacion (ReparacionID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.FacturaDetalle ADD CONSTRAINT FK_FacturaDetalle_ReparacionID_LineaReparacion FOREIGN KEY (ReparacionID, LineaReparacion) REFERENCES dbo.ReparacionRepuesto (ReparacionID, Linea) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Pago ADD CONSTRAINT FK_Pago_FacturaID FOREIGN KEY (FacturaID) REFERENCES dbo.Factura (FacturaID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Pago ADD CONSTRAINT FK_Pago_MetodoPagoID FOREIGN KEY (MetodoPagoID) REFERENCES dbo.MetodoPago (MetodoPagoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Pago ADD CONSTRAINT FK_Pago_UsuarioRegistroID FOREIGN KEY (UsuarioRegistroID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Entrega ADD CONSTRAINT FK_Entrega_OrdenID FOREIGN KEY (OrdenID) REFERENCES dbo.OrdenServicio (OrdenID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.Entrega ADD CONSTRAINT FK_Entrega_UsuarioEntregaID FOREIGN KEY (UsuarioEntregaID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.AuditoriaPrecioRepuesto ADD CONSTRAINT FK_AuditoriaPrecioRepuesto_RepuestoID FOREIGN KEY (RepuestoID) REFERENCES dbo.Repuesto (RepuestoID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

ALTER TABLE dbo.AuditoriaPrecioRepuesto ADD CONSTRAINT FK_AuditoriaPrecioRepuesto_UsuarioAplicacionID FOREIGN KEY (UsuarioAplicacionID) REFERENCES dbo.Usuario (UsuarioID) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO


-- ============================================================================
-- 03 / CATALOGOS INDISPENSABLES
-- ============================================================================

INSERT dbo.TipoCliente VALUES (1,N'Individual'),(2,N'Empresarial');
INSERT dbo.TipoEquipo VALUES (1,N'Laptop'),(2,N'Escritorio'),(3,N'Impresora'),(4,N'Equipo de red'),(5,N'Otro dispositivo');
INSERT dbo.Rol VALUES ('ADMIN',N'Administrador'),('RECEPCION',N'Recepción'),('TECNICO',N'Técnico'),('BODEGA',N'Bodega'),('CAJA',N'Caja');
INSERT dbo.Prioridad VALUES ('BAJA',N'Baja',1),('NORMAL',N'Normal',2),('ALTA',N'Alta',3),('URGENTE',N'Urgente',4);
INSERT dbo.EstadoOrden VALUES ('RECIBIDO',N'Recibido',0),('DIAGNOSTICO',N'Diagnóstico',0),('ESPERANDO_AUTORIZACION',N'Esperando autorización',0),('REPARACION',N'En reparación',0),('LISTO',N'Listo para entregar',0),('ENTREGADO',N'Entregado',1),('CANCELADO',N'Cancelado',1);
INSERT dbo.TransicionEstadoOrden VALUES ('RECIBIDO','DIAGNOSTICO'),('RECIBIDO','CANCELADO'),('DIAGNOSTICO','ESPERANDO_AUTORIZACION'),('DIAGNOSTICO','CANCELADO'),('ESPERANDO_AUTORIZACION','REPARACION'),('ESPERANDO_AUTORIZACION','CANCELADO'),('REPARACION','LISTO'),('LISTO','ENTREGADO');
INSERT dbo.MetodoPago VALUES (1,N'Efectivo'),(2,N'Tarjeta'),(3,N'Transferencia');
GO


-- ============================================================================
-- 04 / INDICES PARA ORIGEN, BUSQUEDA Y REPORTES
-- ============================================================================

CREATE UNIQUE NONCLUSTERED INDEX UX_Movimiento_Compra ON dbo.MovimientoInventario (CompraID, LineaCompra) WHERE CompraID IS NOT NULL;
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_Movimiento_Reparacion ON dbo.MovimientoInventario (ReparacionID, LineaReparacion) WHERE ReparacionID IS NOT NULL;
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_FacturaDetalle_ManoObra ON dbo.FacturaDetalle (FacturaID) WHERE TipoConcepto = 'MO';
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_FacturaDetalle_Consumo ON dbo.FacturaDetalle (ReparacionID, LineaReparacion) WHERE LineaReparacion IS NOT NULL;
GO

CREATE NONCLUSTERED INDEX IX_Equipo_Cliente ON dbo.Equipo (ClienteID);
GO

CREATE NONCLUSTERED INDEX IX_Orden_Estado_Fecha ON dbo.OrdenServicio (EstadoCodigo, FechaIngreso);
GO

CREATE NONCLUSTERED INDEX IX_Orden_Equipo_Fecha ON dbo.OrdenServicio (EquipoID, FechaIngreso);
GO

CREATE NONCLUSTERED INDEX IX_Historial_Orden ON dbo.HistorialEstadoOrden (OrdenID, HistorialID);
GO

CREATE NONCLUSTERED INDEX IX_Diagnostico_Tecnico_Fecha ON dbo.Diagnostico (UsuarioTecnicoID, Fecha);
GO

CREATE NONCLUSTERED INDEX IX_Reparacion_Tecnico_Fecha ON dbo.Reparacion (UsuarioTecnicoID, FechaInicio);
GO

CREATE NONCLUSTERED INDEX IX_DetalleCompra_Inventario ON dbo.DetalleCompra (BodegaID, RepuestoID);
GO

CREATE NONCLUSTERED INDEX IX_Consumo_Inventario ON dbo.ReparacionRepuesto (BodegaID, RepuestoID);
GO

CREATE NONCLUSTERED INDEX IX_Compra_Proveedor_Fecha ON dbo.Compra (ProveedorID, Fecha);
GO

CREATE NONCLUSTERED INDEX IX_Movimiento_Fecha ON dbo.MovimientoInventario (Fecha);
GO

CREATE NONCLUSTERED INDEX IX_Factura_Fecha ON dbo.Factura (Fecha);
GO

CREATE NONCLUSTERED INDEX IX_Pago_Factura_Fecha ON dbo.Pago (FacturaID, Fecha);
GO

CREATE NONCLUSTERED INDEX IX_Inventario_Repuesto ON dbo.Inventario (RepuestoID, BodegaID);
GO


-- ============================================================================
-- 05 / VISTAS - STOCK Y TOTALES DERIVADOS, SIN CONTADORES EDITABLES
-- ============================================================================

CREATE VIEW dbo.vMovimientoInventario AS
SELECT m.MovimientoID, m.Tipo, dc.BodegaID, dc.RepuestoID, dc.Cantidad,
       CONVERT(bigint,dc.Cantidad) AS CantidadFirmada, m.Fecha, m.UsuarioID,
       m.ExistenciaResultante, m.CompraID, m.LineaCompra, m.ReparacionID, m.LineaReparacion
FROM dbo.MovimientoInventario AS m
         INNER JOIN dbo.DetalleCompra AS dc ON dc.CompraID=m.CompraID AND dc.Linea=m.LineaCompra
UNION ALL
SELECT m.MovimientoID, m.Tipo, rr.BodegaID, rr.RepuestoID, rr.Cantidad,
       -CONVERT(bigint,rr.Cantidad), m.Fecha, m.UsuarioID,
       m.ExistenciaResultante, m.CompraID, m.LineaCompra, m.ReparacionID, m.LineaReparacion
FROM dbo.MovimientoInventario AS m
         INNER JOIN dbo.ReparacionRepuesto AS rr ON rr.ReparacionID=m.ReparacionID AND rr.Linea=m.LineaReparacion;
GO

CREATE VIEW dbo.vInventario AS
SELECT i.BodegaID, i.RepuestoID, i.StockMinimo,
       COALESCE(s.Existencia,CONVERT(bigint,0)) AS Existencia
FROM dbo.Inventario AS i
         LEFT JOIN (SELECT BodegaID,RepuestoID,SUM(CantidadFirmada) AS Existencia
                    FROM dbo.vMovimientoInventario GROUP BY BodegaID,RepuestoID) AS s
                   ON s.BodegaID=i.BodegaID AND s.RepuestoID=i.RepuestoID;
GO

CREATE VIEW dbo.vFacturaSaldo AS
WITH lineas AS (
    SELECT FacturaID,SUM(CONVERT(decimal(18,2),Cantidad*PrecioUnitario)) AS Subtotal,
           SUM(CASE WHEN TipoConcepto='MO' THEN CONVERT(decimal(18,2),Cantidad*PrecioUnitario) ELSE 0 END) AS ManoObra,
           SUM(CASE WHEN TipoConcepto='REP' THEN CONVERT(decimal(18,2),Cantidad*PrecioUnitario) ELSE 0 END) AS Repuestos
    FROM dbo.FacturaDetalle GROUP BY FacturaID
), pagos AS (SELECT FacturaID,SUM(CONVERT(decimal(18,2),Monto)) AS Pagado FROM dbo.Pago GROUP BY FacturaID)
SELECT f.FacturaID,f.NumeroFactura,f.OrdenID,f.Fecha,f.Estado,f.TasaImpuesto,
       COALESCE(l.Subtotal,0) AS Subtotal,COALESCE(l.ManoObra,0) AS ManoObra,COALESCE(l.Repuestos,0) AS Repuestos,
       ROUND(COALESCE(l.Subtotal,0)*f.TasaImpuesto,2) AS Impuesto,
       CONVERT(decimal(18,2),COALESCE(l.Subtotal,0)+ROUND(COALESCE(l.Subtotal,0)*f.TasaImpuesto,2)) AS Total,
       COALESCE(p.Pagado,0) AS Pagado,
       CONVERT(decimal(18,2),COALESCE(l.Subtotal,0)+ROUND(COALESCE(l.Subtotal,0)*f.TasaImpuesto,2)-COALESCE(p.Pagado,0)) AS Saldo,
       CASE WHEN f.Estado='ANULADA' THEN 'ANULADA' WHEN COALESCE(p.Pagado,0)=0 AND COALESCE(l.Subtotal,0)>0 THEN 'PENDIENTE'
            WHEN COALESCE(l.Subtotal,0)+ROUND(COALESCE(l.Subtotal,0)*f.TasaImpuesto,2)=COALESCE(p.Pagado,0) THEN 'PAGADA' ELSE 'PARCIAL' END AS EstadoPago
FROM dbo.Factura AS f LEFT JOIN lineas AS l ON l.FacturaID=f.FacturaID LEFT JOIN pagos AS p ON p.FacturaID=f.FacturaID;
GO

CREATE VIEW dbo.vOrdenResumen AS
SELECT o.OrdenID,o.NumeroOrden,o.EquipoID,e.NumeroSerie,c.ClienteID,c.NIT,c.Nombre AS Cliente,
       mo.Nombre AS Modelo,ma.Nombre AS Marca,te.Nombre AS TipoEquipo,o.FechaIngreso,o.FechaEstimada,
       o.EstadoCodigo,o.PrioridadCodigo,COALESCE(r.UsuarioTecnicoID,d.UsuarioTecnicoID) AS UsuarioTecnicoID,
       d.DiagnosticoID,r.ReparacionID,f.FacturaID,f.Total,f.Pagado,f.Saldo
FROM dbo.OrdenServicio AS o INNER JOIN dbo.Equipo AS e ON e.EquipoID=o.EquipoID
                            INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID INNER JOIN dbo.ModeloEquipo AS mo ON mo.ModeloEquipoID=e.ModeloEquipoID
                            INNER JOIN dbo.Marca AS ma ON ma.MarcaID=mo.MarcaID INNER JOIN dbo.TipoEquipo AS te ON te.TipoEquipoID=mo.TipoEquipoID
                            LEFT JOIN dbo.Diagnostico AS d ON d.OrdenID=o.OrdenID LEFT JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID
                            LEFT JOIN dbo.vFacturaSaldo AS f ON f.OrdenID=o.OrdenID;
GO

CREATE VIEW dbo.vConsumoRepuesto AS
SELECT rr.ReparacionID,rr.Linea,rr.BodegaID,rr.RepuestoID,rr.Cantidad,rr.CostoUnitario,rr.PrecioUnitario,
       m.MovimientoID,m.Fecha,r.UsuarioTecnicoID,d.OrdenID
FROM dbo.ReparacionRepuesto AS rr INNER JOIN dbo.Reparacion AS r ON r.ReparacionID=rr.ReparacionID
                                  INNER JOIN dbo.Diagnostico AS d ON d.DiagnosticoID=r.DiagnosticoID
                                  INNER JOIN dbo.MovimientoInventario AS m ON m.ReparacionID=rr.ReparacionID AND m.LineaReparacion=rr.Linea;
GO

CREATE VIEW dbo.vHistorialEquipo AS
SELECT e.EquipoID,e.NumeroSerie,c.ClienteID,c.Nombre AS Cliente,o.OrdenID,o.NumeroOrden,o.FechaIngreso,o.EstadoCodigo,
       d.Fecha AS FechaDiagnostico,d.Descripcion AS Diagnostico,r.ReparacionID,r.FechaInicio,r.FechaFin,r.DescripcionTrabajo,
       f.FacturaID,f.Total,f.Saldo,en.Fecha AS FechaEntrega
FROM dbo.Equipo AS e INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID
                     LEFT JOIN dbo.OrdenServicio AS o ON o.EquipoID=e.EquipoID LEFT JOIN dbo.Diagnostico AS d ON d.OrdenID=o.OrdenID
                     LEFT JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID LEFT JOIN dbo.vFacturaSaldo AS f ON f.OrdenID=o.OrdenID
                     LEFT JOIN dbo.Entrega AS en ON en.OrdenID=o.OrdenID;
GO

CREATE VIEW dbo.vDashboard AS
SELECT (SELECT COUNT_BIG(1) FROM dbo.OrdenServicio WHERE EstadoCodigo NOT IN ('ENTREGADO','CANCELADO')) AS OrdenesAbiertas,
       (SELECT COUNT_BIG(1) FROM dbo.OrdenServicio WHERE EstadoCodigo='DIAGNOSTICO') AS EnDiagnostico,
       (SELECT COUNT_BIG(1) FROM dbo.OrdenServicio WHERE EstadoCodigo='REPARACION') AS EnReparacion,
       (SELECT COUNT_BIG(1) FROM dbo.OrdenServicio WHERE EstadoCodigo='LISTO') AS Listas,
       (SELECT COUNT_BIG(1) FROM dbo.vFacturaSaldo WHERE Estado='EMITIDA' AND Saldo>0) AS FacturasPendientes,
       (SELECT COUNT_BIG(1) FROM dbo.vInventario WHERE Existencia<=StockMinimo) AS StockBajo;
GO


-- ============================================================================
-- 06 / FUNCIONES
-- ============================================================================

CREATE FUNCTION dbo.fnTieneRol(@UsuarioID int,@Rol varchar(20)) RETURNS bit AS
BEGIN
RETURN CASE WHEN EXISTS (SELECT 1 FROM dbo.Usuario AS u INNER JOIN dbo.Empleado AS e ON e.EmpleadoID=u.EmpleadoID
                                                        INNER JOIN dbo.UsuarioRol AS ur ON ur.UsuarioID=u.UsuarioID WHERE u.UsuarioID=@UsuarioID AND u.Activo=1 AND e.Activo=1
                                                                                                                      AND ur.RolCodigo IN (@Rol,'ADMIN')) THEN 1 ELSE 0 END;
END;
GO

CREATE FUNCTION dbo.fnExistencia(@BodegaID int,@RepuestoID int) RETURNS bigint AS
BEGIN
 DECLARE @Stock bigint;
SELECT @Stock=Existencia FROM dbo.vInventario WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID;
RETURN @Stock;
END;
GO

CREATE FUNCTION dbo.fnSaldoFactura(@FacturaID int) RETURNS decimal(18,2) AS
BEGIN
 DECLARE @Saldo decimal(18,2);
SELECT @Saldo=Saldo FROM dbo.vFacturaSaldo WHERE FacturaID=@FacturaID AND Estado='EMITIDA';
RETURN @Saldo;
END;
GO

CREATE FUNCTION dbo.fnTotalOrden(@OrdenID int) RETURNS decimal(18,2) AS
BEGIN
 DECLARE @MO decimal(18,2)=0,@REP decimal(18,2)=0;
SELECT @MO=r.CostoManoObra FROM dbo.Diagnostico AS d INNER JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID WHERE d.OrdenID=@OrdenID;
SELECT @REP=COALESCE(SUM(CONVERT(decimal(18,2),Cantidad*PrecioUnitario)),0) FROM dbo.vConsumoRepuesto WHERE OrdenID=@OrdenID;
RETURN COALESCE(@MO,0)+@REP;
END;
GO


-- ============================================================================
-- 07 / PROCESOS TRANSACCIONALES
-- ============================================================================

CREATE TYPE dbo.TipoDetalleCompra AS TABLE (
    Linea smallint NOT NULL PRIMARY KEY,BodegaID int NOT NULL,RepuestoID int NOT NULL,
    Cantidad int NOT NULL CHECK (Cantidad>0),CostoUnitario decimal(12,2) NOT NULL CHECK (CostoUnitario>=0)
    );
GO

-- API de Clientes. Cada procedimiento resuelve una sola operación.
CREATE OR ALTER PROCEDURE dbo.spListarClientes
    AS
BEGIN
    SET NOCOUNT ON;
SELECT ClienteID, TipoClienteID, NIT, Nombre, Email, Telefono, Direccion, Activo
FROM dbo.Cliente
ORDER BY ClienteID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spConsultarCliente
    @ClienteID int
    AS
BEGIN
    SET NOCOUNT ON;
    IF @ClienteID IS NULL OR @ClienteID <= 0
        THROW 51200, N'El ID debe ser mayor que cero.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteID = @ClienteID)
        THROW 51202, N'El cliente no existe.', 1;
SELECT ClienteID, TipoClienteID, NIT, Nombre, Email, Telefono, Direccion, Activo
FROM dbo.Cliente
WHERE ClienteID = @ClienteID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spRegistrarCliente
    @TipoClienteID int,
    @NIT nvarchar(max),
    @Nombre nvarchar(max),
    @Email nvarchar(max),
    @Telefono nvarchar(max),
    @Direccion nvarchar(max),
    @Activo bit
    AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @Resultado TABLE (
        ClienteID int, TipoClienteID tinyint, NIT varchar(20), Nombre nvarchar(150),
        Email nvarchar(254), Telefono varchar(25), Direccion nvarchar(250), Activo bit
    );
BEGIN TRY
IF @Propia = 1 BEGIN TRANSACTION;
ELSE SAVE TRANSACTION spRegistrarCliente;

        SET @NIT = NULLIF(LTRIM(RTRIM(@NIT)), N'');
        SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
        SET @Email = NULLIF(LTRIM(RTRIM(@Email)), N'');
        SET @Telefono = NULLIF(LTRIM(RTRIM(@Telefono)), N'');
        SET @Direccion = NULLIF(LTRIM(RTRIM(@Direccion)), N'');

        -- Se reciben textos amplios para rechazar excesos antes de que SQL los trunque.
        IF @NIT IS NULL OR DATALENGTH(CONVERT(varchar(max), @NIT)) > 20
            THROW 51200, N'El NIT es obligatorio y admite hasta 20 caracteres.', 1;
        IF @Nombre IS NULL OR DATALENGTH(@Nombre) > 300
            THROW 51200, N'El nombre es obligatorio y admite hasta 150 caracteres.', 1;
        IF DATALENGTH(@Email) > 508 OR
           (@Email IS NOT NULL AND (@Email NOT LIKE N'%_@_%' OR @Email LIKE N'% %'))
            THROW 51200, N'El correo no es válido o supera los 254 caracteres.', 1;
        IF DATALENGTH(CONVERT(varchar(max), @Telefono)) > 25
            THROW 51200, N'El teléfono admite hasta 25 caracteres.', 1;
        IF DATALENGTH(@Direccion) > 500
            THROW 51200, N'La dirección admite hasta 250 caracteres.', 1;
        IF @Activo IS NULL
            THROW 51200, N'Activo es obligatorio.', 1;
        IF @TipoClienteID IS NULL OR NOT EXISTS (
            SELECT 1 FROM dbo.TipoCliente WHERE TipoClienteID = @TipoClienteID)
            THROW 51201, N'El tipo de cliente no existe.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Cliente WHERE NIT = @NIT)
            THROW 51203, N'El NIT ya está registrado en otro cliente.', 1;

        INSERT dbo.Cliente (TipoClienteID, NIT, Nombre, Email, Telefono, Direccion, Activo)
        OUTPUT inserted.ClienteID, inserted.TipoClienteID, inserted.NIT, inserted.Nombre,
               inserted.Email, inserted.Telefono, inserted.Direccion, inserted.Activo
        INTO @Resultado
        VALUES (@TipoClienteID, @NIT, @Nombre, @Email, @Telefono, @Direccion, @Activo);

        IF @Propia = 1 COMMIT TRANSACTION;
        -- Se devuelve la fila de esta operación después de confirmar los cambios.
SELECT ClienteID, TipoClienteID, NIT, Nombre, Email, Telefono, Direccion, Activo
FROM @Resultado;
END TRY
BEGIN CATCH
IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION spRegistrarCliente;
        -- La restricción UNIQUE también protege dos solicitudes concurrentes.
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 51203, N'El NIT ya está registrado en otro cliente.', 1;
        THROW;
END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spActualizarCliente
    @ClienteID int,
    @TipoClienteID int,
    @NIT nvarchar(max),
    @Nombre nvarchar(max),
    @Email nvarchar(max),
    @Telefono nvarchar(max),
    @Direccion nvarchar(max),
    @Activo bit
    AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @Resultado TABLE (
        ClienteID int, TipoClienteID tinyint, NIT varchar(20), Nombre nvarchar(150),
        Email nvarchar(254), Telefono varchar(25), Direccion nvarchar(250), Activo bit
    );
BEGIN TRY
IF @Propia = 1 BEGIN TRANSACTION;
ELSE SAVE TRANSACTION spActualizarCliente;

        SET @NIT = NULLIF(LTRIM(RTRIM(@NIT)), N'');
        SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
        SET @Email = NULLIF(LTRIM(RTRIM(@Email)), N'');
        SET @Telefono = NULLIF(LTRIM(RTRIM(@Telefono)), N'');
        SET @Direccion = NULLIF(LTRIM(RTRIM(@Direccion)), N'');

        -- Se reciben textos amplios para rechazar excesos antes de que SQL los trunque.
        IF @NIT IS NULL OR DATALENGTH(CONVERT(varchar(max), @NIT)) > 20
            THROW 51200, N'El NIT es obligatorio y admite hasta 20 caracteres.', 1;
        IF @Nombre IS NULL OR DATALENGTH(@Nombre) > 300
            THROW 51200, N'El nombre es obligatorio y admite hasta 150 caracteres.', 1;
        IF DATALENGTH(@Email) > 508 OR
           (@Email IS NOT NULL AND (@Email NOT LIKE N'%_@_%' OR @Email LIKE N'% %'))
            THROW 51200, N'El correo no es válido o supera los 254 caracteres.', 1;
        IF DATALENGTH(CONVERT(varchar(max), @Telefono)) > 25
            THROW 51200, N'El teléfono admite hasta 25 caracteres.', 1;
        IF DATALENGTH(@Direccion) > 500
            THROW 51200, N'La dirección admite hasta 250 caracteres.', 1;
        IF @Activo IS NULL
            THROW 51200, N'Activo es obligatorio.', 1;
        IF @TipoClienteID IS NULL OR NOT EXISTS (
            SELECT 1 FROM dbo.TipoCliente WHERE TipoClienteID = @TipoClienteID)
            THROW 51201, N'El tipo de cliente no existe.', 1;

        IF @ClienteID IS NULL OR @ClienteID <= 0
            THROW 51200, N'El ID debe ser mayor que cero.', 1;
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Cliente WITH (UPDLOCK, HOLDLOCK) WHERE ClienteID = @ClienteID)
            THROW 51202, N'El cliente no existe.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Cliente WHERE NIT = @NIT AND ClienteID <> @ClienteID)
            THROW 51203, N'El NIT ya está registrado en otro cliente.', 1;

UPDATE dbo.Cliente
SET TipoClienteID = @TipoClienteID, NIT = @NIT, Nombre = @Nombre,
    Email = @Email, Telefono = @Telefono, Direccion = @Direccion, Activo = @Activo
    OUTPUT inserted.ClienteID, inserted.TipoClienteID, inserted.NIT, inserted.Nombre,
               inserted.Email, inserted.Telefono, inserted.Direccion, inserted.Activo
INTO @Resultado
WHERE ClienteID = @ClienteID;
IF @@ROWCOUNT = 0
            THROW 51202, N'El cliente no existe.', 1;

        IF @Propia = 1 COMMIT TRANSACTION;
        -- Se devuelve la fila de esta operación después de confirmar los cambios.
SELECT ClienteID, TipoClienteID, NIT, Nombre, Email, Telefono, Direccion, Activo
FROM @Resultado;
END TRY
BEGIN CATCH
IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
ELSE IF @Propia = 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION spActualizarCliente;
        -- La restricción UNIQUE también protege dos solicitudes concurrentes.
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 51203, N'El NIT ya está registrado en otro cliente.', 1;
        THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spCrearOrden
    @NumeroOrden varchar(30),@EquipoID int,@UsuarioID int,@Problema nvarchar(1000),
@OrdenID int OUTPUT,@Prioridad varchar(10)='NORMAL',@Fecha datetime2(0)=NULL,
@FechaEstimada datetime2(0)=NULL,@Observaciones nvarchar(1000)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spCrearOrden;

IF dbo.fnTieneRol(@UsuarioID,'RECEPCION')=0 THROW 51001,N'Usuario sin rol de recepción.',1;
IF NOT EXISTS (SELECT 1 FROM dbo.Equipo AS e INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID WHERE e.EquipoID=@EquipoID AND e.Activo=1 AND c.Activo=1) THROW 51002,N'Equipo o cliente inactivo/inexistente.',1;
SET @Fecha=COALESCE(@Fecha,SYSUTCDATETIME());
INSERT dbo.OrdenServicio (NumeroOrden,EquipoID,UsuarioRecepcionID,FechaIngreso,ProblemaReportado,PrioridadCodigo,FechaEstimada,Observaciones,UsuarioCambioID,FechaCambio,ObservacionCambio)
VALUES (@NumeroOrden,@EquipoID,@UsuarioID,@Fecha,@Problema,@Prioridad,@FechaEstimada,@Observaciones,@UsuarioID,@Fecha,N'Ingreso del equipo');
SET @OrdenID=CONVERT(int,SCOPE_IDENTITY());
 IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spCrearOrden;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spCambiarEstadoOrden
    @OrdenID int,@EstadoNuevo varchar(30),@UsuarioID int,@Observacion nvarchar(500)=NULL,@Fecha datetime2(0)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spCambiarEstadoOrden;

IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioID=@UsuarioID AND Activo=1) THROW 51003,N'Usuario inexistente/inactivo.',1;
DECLARE @Anterior varchar(30);
SELECT @Anterior=EstadoCodigo FROM dbo.OrdenServicio WITH (UPDLOCK,HOLDLOCK) WHERE OrdenID=@OrdenID;
IF @Anterior IS NULL THROW 51004,N'Orden inexistente.',1;
IF @Anterior=@EstadoNuevo THROW 51005,N'El estado ya es el solicitado.',1;
IF (@EstadoNuevo IN ('DIAGNOSTICO','ESPERANDO_AUTORIZACION','REPARACION','LISTO') AND dbo.fnTieneRol(@UsuarioID,'TECNICO')=0)
 OR (@EstadoNuevo='CANCELADO' AND dbo.fnTieneRol(@UsuarioID,'RECEPCION')=0)
 OR (@EstadoNuevo='ENTREGADO' AND dbo.fnTieneRol(@UsuarioID,'RECEPCION')=0) THROW 51006,N'Rol insuficiente para la transición.',1;
UPDATE dbo.OrdenServicio SET EstadoCodigo=@EstadoNuevo,UsuarioCambioID=@UsuarioID,
                             FechaCambio=COALESCE(@Fecha,SYSUTCDATETIME()),ObservacionCambio=@Observacion WHERE OrdenID=@OrdenID;
IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spCambiarEstadoOrden;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spRegistrarDiagnostico
    @OrdenID int,@UsuarioTecnicoID int,@Descripcion nvarchar(2000),@CostoEstimado decimal(12,2),
@DiagnosticoID int OUTPUT,@Fecha datetime2(0)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spRegistrarDiagnostico;

IF dbo.fnTieneRol(@UsuarioTecnicoID,'TECNICO')=0 THROW 51007,N'Usuario sin rol técnico.',1;
DECLARE @Estado varchar(30); SET @Fecha=COALESCE(@Fecha,SYSUTCDATETIME());
SELECT @Estado=EstadoCodigo FROM dbo.OrdenServicio WITH (UPDLOCK,HOLDLOCK) WHERE OrdenID=@OrdenID;
IF @Estado IS NULL OR @Estado NOT IN ('RECIBIDO','DIAGNOSTICO') THROW 51008,N'Orden no disponible para diagnóstico.',1;
IF @Estado='RECIBIDO' EXEC dbo.spCambiarEstadoOrden @OrdenID,'DIAGNOSTICO',@UsuarioTecnicoID,N'Inicio de diagnóstico',@Fecha;
INSERT dbo.Diagnostico (OrdenID,UsuarioTecnicoID,Fecha,Descripcion,CostoManoObraEstimado)
VALUES (@OrdenID,@UsuarioTecnicoID,@Fecha,@Descripcion,@CostoEstimado);
SET @DiagnosticoID=CONVERT(int,SCOPE_IDENTITY());
EXEC dbo.spCambiarEstadoOrden @OrdenID,'ESPERANDO_AUTORIZACION',@UsuarioTecnicoID,N'Diagnóstico registrado; requiere autorización',@Fecha;
 IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spRegistrarDiagnostico;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spIniciarReparacion
    @DiagnosticoID int,@UsuarioTecnicoID int,@Descripcion nvarchar(2000),@CostoManoObra decimal(12,2),
@ReparacionID int OUTPUT,@Autorizacion nvarchar(500),@Fecha datetime2(0)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spIniciarReparacion;

IF dbo.fnTieneRol(@UsuarioTecnicoID,'TECNICO')=0 THROW 51009,N'Usuario sin rol técnico.',1;
IF NULLIF(LTRIM(RTRIM(@Autorizacion)),N'') IS NULL THROW 51010,N'Debe documentar la autorización del cliente.',1;
DECLARE @OrdenID int;
SELECT @OrdenID=d.OrdenID FROM dbo.Diagnostico AS d INNER JOIN dbo.OrdenServicio AS o WITH (UPDLOCK,HOLDLOCK) ON o.OrdenID=d.OrdenID WHERE d.DiagnosticoID=@DiagnosticoID AND o.EstadoCodigo='ESPERANDO_AUTORIZACION';
IF @OrdenID IS NULL THROW 51011,N'Requiere diagnóstico y orden esperando autorización.',1;
SET @Fecha=COALESCE(@Fecha,SYSUTCDATETIME());
INSERT dbo.Reparacion (DiagnosticoID,UsuarioTecnicoID,FechaInicio,DescripcionTrabajo,CostoManoObra)
VALUES (@DiagnosticoID,@UsuarioTecnicoID,@Fecha,@Descripcion,@CostoManoObra);
SET @ReparacionID=CONVERT(int,SCOPE_IDENTITY());
EXEC dbo.spCambiarEstadoOrden @OrdenID,'REPARACION',@UsuarioTecnicoID,@Autorizacion,@Fecha;
 IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spIniciarReparacion;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spRegistrarActividad
    @ReparacionID int,@ActividadID int,@UsuarioID int,@Observacion nvarchar(500)=NULL,@Fecha datetime2(0)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spRegistrarActividad;

IF dbo.fnTieneRol(@UsuarioID,'TECNICO')=0 THROW 51012,N'Usuario sin rol técnico.',1;
IF NOT EXISTS (SELECT 1 FROM dbo.Reparacion WITH (UPDLOCK,HOLDLOCK) WHERE ReparacionID=@ReparacionID AND Estado='EN_PROCESO') THROW 51013,N'Reparación no activa.',1;
INSERT dbo.ReparacionActividad (ReparacionID,ActividadID,Fecha,Observacion) VALUES (@ReparacionID,@ActividadID,COALESCE(@Fecha,SYSUTCDATETIME()),@Observacion);
 IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spRegistrarActividad;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spConsumirRepuesto
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
SELECT @Costo=CostoReferencia,@Precio=PrecioVenta FROM dbo.Repuesto WHERE RepuestoID=@RepuestoID AND Activo=1;
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

CREATE PROCEDURE dbo.spCerrarReparacion
    @ReparacionID int,@UsuarioID int,@Fecha datetime2(0)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spCerrarReparacion;

IF dbo.fnTieneRol(@UsuarioID,'TECNICO')=0 THROW 51020,N'Usuario sin rol técnico.',1;
DECLARE @OrdenID int;
SELECT @OrdenID=d.OrdenID FROM dbo.Reparacion AS r WITH (UPDLOCK,HOLDLOCK) INNER JOIN dbo.Diagnostico AS d ON d.DiagnosticoID=r.DiagnosticoID
WHERE r.ReparacionID=@ReparacionID AND r.Estado='EN_PROCESO';
IF @OrdenID IS NULL THROW 51021,N'Reparación no activa.',1;
IF EXISTS (SELECT 1 FROM dbo.ReparacionRepuesto AS rr LEFT JOIN dbo.MovimientoInventario AS m ON m.ReparacionID=rr.ReparacionID AND m.LineaReparacion=rr.Linea WHERE rr.ReparacionID=@ReparacionID AND m.MovimientoID IS NULL) THROW 51022,N'Hay consumos sin movimiento de salida.',1;
SET @Fecha=COALESCE(@Fecha,SYSUTCDATETIME());
UPDATE dbo.Reparacion SET Estado='TERMINADA',FechaFin=@Fecha WHERE ReparacionID=@ReparacionID;
EXEC dbo.spCambiarEstadoOrden @OrdenID,'LISTO',@UsuarioID,N'Reparación terminada',@Fecha;
 IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spCerrarReparacion;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spRegistrarCompra
    @NumeroCompra varchar(30),@ProveedorID int,@UsuarioID int,@Detalle dbo.TipoDetalleCompra READONLY,
@CompraID int OUTPUT,@Fecha datetime2(0)=NULL,@Observaciones nvarchar(1000)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spRegistrarCompra;

IF dbo.fnTieneRol(@UsuarioID,'BODEGA')=0 THROW 51023,N'Usuario sin rol de bodega.',1;
IF NOT EXISTS (SELECT 1 FROM @Detalle) THROW 51024,N'Compra sin detalle.',1;
IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE ProveedorID=@ProveedorID AND Activo=1) THROW 51025,N'Proveedor inactivo/inexistente.',1;
INSERT dbo.Compra (NumeroCompra,ProveedorID,UsuarioRegistroID,Fecha,Observaciones) VALUES (@NumeroCompra,@ProveedorID,@UsuarioID,COALESCE(@Fecha,SYSUTCDATETIME()),@Observaciones);
SET @CompraID=CONVERT(int,SCOPE_IDENTITY());
INSERT dbo.DetalleCompra (CompraID,Linea,BodegaID,RepuestoID,Cantidad,CostoUnitario)
SELECT @CompraID,Linea,BodegaID,RepuestoID,Cantidad,CostoUnitario FROM @Detalle;
IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spRegistrarCompra;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spRecibirCompra
    @CompraID int,@UsuarioID int,@Fecha datetime2(0)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spRecibirCompra;

IF dbo.fnTieneRol(@UsuarioID,'BODEGA')=0 THROW 51026,N'Usuario sin rol de bodega.',1;
IF NOT EXISTS (SELECT 1 FROM dbo.Compra WITH (UPDLOCK,HOLDLOCK) WHERE CompraID=@CompraID AND Estado='PENDIENTE') THROW 51027,N'Compra inexistente, recibida o anulada.',1;
IF NOT EXISTS (SELECT 1 FROM dbo.DetalleCompra WHERE CompraID=@CompraID) THROW 51028,N'Compra sin líneas.',1;
SET @Fecha=COALESCE(@Fecha,SYSUTCDATETIME());
DECLARE @Linea smallint,@Bodega int,@Repuesto int,@Cantidad int,@Stock bigint,@Dummy int;
-- Orden de bloqueo uniforme reduce interbloqueos entre compras concurrentes.
DECLARE lineas CURSOR LOCAL FAST_FORWARD FOR SELECT Linea,BodegaID,RepuestoID,Cantidad FROM dbo.DetalleCompra WHERE CompraID=@CompraID ORDER BY BodegaID,RepuestoID,Linea;
OPEN lineas; FETCH NEXT FROM lineas INTO @Linea,@Bodega,@Repuesto,@Cantidad;
WHILE @@FETCH_STATUS=0
BEGIN
 SET @Dummy=NULL;
SELECT @Dummy=RepuestoID FROM dbo.Inventario WITH (UPDLOCK,HOLDLOCK) WHERE BodegaID=@Bodega AND RepuestoID=@Repuesto;
IF @Dummy IS NULL THROW 51029,N'Inventario destino inexistente.',1;
 IF NOT EXISTS (SELECT 1 FROM dbo.Repuesto WHERE RepuestoID=@Repuesto AND Activo=1) OR NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE BodegaID=@Bodega AND Activo=1) THROW 51030,N'Destino/repuesto inactivo.',1;
 SET @Stock=dbo.fnExistencia(@Bodega,@Repuesto);
 INSERT dbo.MovimientoInventario (CompraID,LineaCompra,Fecha,UsuarioID,ExistenciaResultante) VALUES (@CompraID,@Linea,@Fecha,@UsuarioID,@Stock+@Cantidad);
FETCH NEXT FROM lineas INTO @Linea,@Bodega,@Repuesto,@Cantidad;
END;
CLOSE lineas; DEALLOCATE lineas;
UPDATE dbo.Compra SET Estado='RECIBIDA',FechaRecepcion=@Fecha WHERE CompraID=@CompraID;
-- Todas las entradas y el cambio de estado se confirman o revierten juntos.

IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spRecibirCompra;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spGenerarFactura
    @OrdenID int,@NumeroFactura varchar(30),@UsuarioID int,@FacturaID int OUTPUT,
@TasaImpuesto decimal(5,4)=0.1200,@Fecha datetime2(0)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spGenerarFactura;

IF dbo.fnTieneRol(@UsuarioID,'CAJA')=0 THROW 51031,N'Usuario sin rol de caja.',1;
DECLARE @ReparacionID int,@MO decimal(12,2),@NIT varchar(20),@Nombre nvarchar(150),@Direccion nvarchar(250);
SELECT @ReparacionID=r.ReparacionID,@MO=r.CostoManoObra,@NIT=c.NIT,@Nombre=c.Nombre,@Direccion=c.Direccion
FROM dbo.OrdenServicio AS o WITH (UPDLOCK,HOLDLOCK) INNER JOIN dbo.Equipo AS e ON e.EquipoID=o.EquipoID
    INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID INNER JOIN dbo.Diagnostico AS d ON d.OrdenID=o.OrdenID
    INNER JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID WHERE o.OrdenID=@OrdenID AND o.EstadoCodigo='LISTO' AND r.Estado='TERMINADA';
IF @ReparacionID IS NULL THROW 51032,N'Orden no terminada/lista para facturar.',1;
IF EXISTS (SELECT 1 FROM dbo.Factura WHERE OrdenID=@OrdenID) THROW 51033,N'La orden ya tiene factura.',1;
IF EXISTS (SELECT 1 FROM dbo.ReparacionRepuesto AS rr LEFT JOIN dbo.MovimientoInventario AS m ON m.ReparacionID=rr.ReparacionID AND m.LineaReparacion=rr.Linea WHERE rr.ReparacionID=@ReparacionID AND m.MovimientoID IS NULL) THROW 51034,N'Consumos sin movimiento.',1;
INSERT dbo.Factura (NumeroFactura,OrdenID,UsuarioEmisionID,Fecha,NITFacturacion,NombreFacturacion,DireccionFacturacion,TasaImpuesto)
VALUES (@NumeroFactura,@OrdenID,@UsuarioID,COALESCE(@Fecha,SYSUTCDATETIME()),@NIT,@Nombre,@Direccion,@TasaImpuesto);
SET @FacturaID=CONVERT(int,SCOPE_IDENTITY());
INSERT dbo.FacturaDetalle (FacturaID,Linea,TipoConcepto,ReparacionID,Concepto,Cantidad,PrecioUnitario)
VALUES (@FacturaID,1,'MO',@ReparacionID,N'Mano de obra del servicio',1,@MO);
INSERT dbo.FacturaDetalle (FacturaID,Linea,TipoConcepto,ReparacionID,LineaReparacion,Concepto,Cantidad,PrecioUnitario)
SELECT @FacturaID,CONVERT(smallint,ROW_NUMBER() OVER (ORDER BY rr.Linea)+1),'REP',rr.ReparacionID,rr.Linea,p.Nombre,rr.Cantidad,rr.PrecioUnitario
FROM dbo.ReparacionRepuesto AS rr INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=rr.RepuestoID WHERE rr.ReparacionID=@ReparacionID;
IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spGenerarFactura;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spRegistrarPago
    @FacturaID int,@MetodoPagoID tinyint,@Monto decimal(12,2),@UsuarioID int,@Referencia nvarchar(100)=NULL,@Fecha datetime2(0)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spRegistrarPago;

IF dbo.fnTieneRol(@UsuarioID,'CAJA')=0 THROW 51035,N'Usuario sin rol de caja.',1;
IF @Monto IS NULL OR @Monto<=0 THROW 51036,N'Monto inválido.',1;
DECLARE @Dummy int,@Saldo decimal(18,2);
SELECT @Dummy=FacturaID FROM dbo.Factura WITH (UPDLOCK,HOLDLOCK) WHERE FacturaID=@FacturaID AND Estado='EMITIDA';
IF @Dummy IS NULL THROW 51037,N'Factura inexistente/anulada.',1;
SET @Saldo=dbo.fnSaldoFactura(@FacturaID);
IF @Monto>@Saldo THROW 51038,N'El pago excede el saldo pendiente.',1;
INSERT dbo.Pago (FacturaID,MetodoPagoID,UsuarioRegistroID,Fecha,Monto,Referencia)
VALUES (@FacturaID,@MetodoPagoID,@UsuarioID,COALESCE(@Fecha,SYSUTCDATETIME()),@Monto,@Referencia);
 IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spRegistrarPago;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spEntregarOrden
    @OrdenID int,@UsuarioID int,@NombreRecibe nvarchar(150),@DocumentoRecibe varchar(30)=NULL,
@Observaciones nvarchar(1000)=NULL,@Fecha datetime2(0)=NULL
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spEntregarOrden;

IF dbo.fnTieneRol(@UsuarioID,'RECEPCION')=0 THROW 51039,N'Usuario sin rol de recepción.',1;
DECLARE @FacturaID int,@Dummy int;
SELECT @Dummy=OrdenID FROM dbo.OrdenServicio WITH (UPDLOCK,HOLDLOCK) WHERE OrdenID=@OrdenID AND EstadoCodigo='LISTO';
IF @Dummy IS NULL THROW 51040,N'Orden no lista para entrega.',1;
SELECT @FacturaID=FacturaID FROM dbo.Factura WITH (UPDLOCK,HOLDLOCK) WHERE OrdenID=@OrdenID AND Estado='EMITIDA';
IF @FacturaID IS NULL OR dbo.fnSaldoFactura(@FacturaID)<>0 THROW 51041,N'Requiere factura emitida y saldo cero.',1;
SET @Fecha=COALESCE(@Fecha,SYSUTCDATETIME());
INSERT dbo.Entrega (OrdenID,UsuarioEntregaID,NombreRecibe,DocumentoRecibe,Fecha,Observaciones)
VALUES (@OrdenID,@UsuarioID,@NombreRecibe,@DocumentoRecibe,@Fecha,@Observaciones);
EXEC dbo.spCambiarEstadoOrden @OrdenID,'ENTREGADO',@UsuarioID,N'Entrega con saldo cancelado',@Fecha;
 IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spEntregarOrden;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spAnularCompra
    @CompraID int,@UsuarioID int,@Motivo nvarchar(1000)
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spAnularCompra;

IF dbo.fnTieneRol(@UsuarioID,'BODEGA')=0 THROW 51042,N'Usuario sin rol de bodega.',1;
IF NULLIF(LTRIM(RTRIM(@Motivo)),N'') IS NULL THROW 51043,N'Debe indicar el motivo.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Compra WITH (UPDLOCK,HOLDLOCK) WHERE CompraID=@CompraID AND Estado='PENDIENTE') THROW 51044,N'Sólo se anulan compras pendientes.',1;
UPDATE dbo.Compra SET Estado='ANULADA',Observaciones=@Motivo WHERE CompraID=@CompraID;
IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spAnularCompra;
 THROW;
END CATCH;
END;
GO

CREATE PROCEDURE dbo.spAnularFactura
    @FacturaID int,@UsuarioID int
AS
BEGIN
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION spAnularFactura;

IF dbo.fnTieneRol(@UsuarioID,'CAJA')=0 THROW 51045,N'Usuario sin rol de caja.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Factura WITH (UPDLOCK,HOLDLOCK) WHERE FacturaID=@FacturaID AND Estado='EMITIDA') THROW 51046,N'Factura no emitida.',1;
UPDATE dbo.Factura SET Estado='ANULADA' WHERE FacturaID=@FacturaID;
IF @Propia=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION spAnularFactura;
 THROW;
END CATCH;
END;
GO


-- ============================================================================
-- 08 / 16 TRIGGERS: UNA PROTECCION POR TABLA - Soportan varias filas
-- inserted = filas nuevas; deleted = filas anteriores.
-- Consulte GUIA_TRIGGERS.md para ejemplos y explicación de cada objeto.
-- ============================================================================

-- Valida el ingreso y los estados; guarda el historial y protege la orden contra borrado.
CREATE TRIGGER dbo.trOrdenEstado
    ON dbo.OrdenServicio
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En DELETE hay filas anteriores y no hay filas nuevas.
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 51141, N'No se permite borrar físicamente OrdenServicio.', 1;

    -- INSERT y UPDATE conservan las reglas originales del proceso.
IF EXISTS (SELECT 1
        FROM inserted AS i
        LEFT JOIN deleted AS d ON d.OrdenID=i.OrdenID
        WHERE d.OrdenID IS NULL
            AND (i.EstadoCodigo<>'RECIBIDO'
            OR dbo.fnTieneRol(i.UsuarioRecepcionID,'RECEPCION')=0))
        THROW 51101,N'Ingreso inválido o usuario sin rol de recepción.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Equipo AS e ON e.EquipoID=i.EquipoID
        INNER JOIN dbo.Cliente AS c ON c.ClienteID=e.ClienteID
        WHERE e.Activo=0
            OR c.Activo=0)
        THROW 51102,N'Equipo/cliente inactivo.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.OrdenID=i.OrdenID
        WHERE i.EquipoID<>d.EquipoID
            OR i.UsuarioRecepcionID<>d.UsuarioRecepcionID
            OR i.FechaIngreso<>d.FechaIngreso
            OR i.NumeroOrden<>d.NumeroOrden)
        THROW 51103,N'No se puede cambiar la identidad del ingreso.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.OrdenID=i.OrdenID
        WHERE i.EstadoCodigo<>d.EstadoCodigo
            AND (i.FechaCambio<d.FechaCambio
            OR NOT EXISTS(SELECT 1
        FROM dbo.TransicionEstadoOrden AS t
        WHERE t.EstadoOrigen=d.EstadoCodigo
            AND t.EstadoDestino=i.EstadoCodigo)))
        THROW 51104,N'Transición/fecha no permitida.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.OrdenID=i.OrdenID
        WHERE i.EstadoCodigo<>d.EstadoCodigo
            AND
 ((i.EstadoCodigo IN ('DIAGNOSTICO','ESPERANDO_AUTORIZACION','REPARACION','LISTO')
            AND dbo.fnTieneRol(i.UsuarioCambioID,'TECNICO')=0)
            OR (i.EstadoCodigo IN ('CANCELADO','ENTREGADO')
            AND dbo.fnTieneRol(i.UsuarioCambioID,'RECEPCION')=0)))
        THROW 51105,N'Usuario no autorizado para el cambio.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        WHERE i.EstadoCodigo='ESPERANDO_AUTORIZACION'
            AND NOT EXISTS(SELECT 1
        FROM dbo.Diagnostico
        WHERE OrdenID=i.OrdenID))
        THROW 51106,N'Requiere diagnóstico.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        WHERE i.EstadoCodigo IN ('REPARACION','LISTO')
            AND NOT EXISTS(SELECT 1
        FROM dbo.Diagnostico AS d
        INNER JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID
        WHERE d.OrdenID=i.OrdenID
            AND ((i.EstadoCodigo='REPARACION'
            AND r.Estado='EN_PROCESO')
            OR (i.EstadoCodigo='LISTO'
            AND r.Estado='TERMINADA'))))
        THROW 51107,N'Estado incompatible con la reparación.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        WHERE i.EstadoCodigo='ENTREGADO'
            AND (NOT EXISTS(SELECT 1
        FROM dbo.Entrega
        WHERE OrdenID=i.OrdenID)
            OR NOT EXISTS(SELECT 1
        FROM dbo.vFacturaSaldo
        WHERE OrdenID=i.OrdenID
            AND Estado='EMITIDA'
            AND Saldo=0)))
        THROW 51108,N'Entrega requiere registro y factura pagada.',1;
 INSERT dbo.HistorialEstadoOrden (OrdenID,EstadoAnterior,EstadoNuevo,Fecha,UsuarioID,Observacion)
SELECT i.OrdenID,d.EstadoCodigo,i.EstadoCodigo,i.FechaCambio,i.UsuarioCambioID,i.ObservacionCambio

FROM inserted AS i
         LEFT JOIN deleted AS d ON d.OrdenID=i.OrdenID
WHERE d.OrdenID IS NULL
   OR i.EstadoCodigo<>d.EstadoCodigo;
END;
GO

-- Protege la identidad y el propietario de equipos que ya tienen historial.
CREATE TRIGGER dbo.trEquipoPropietario
    ON dbo.Equipo
    AFTER UPDATE
              AS
BEGIN
    SET NOCOUNT ON;
IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.EquipoID=i.EquipoID
        INNER JOIN dbo.OrdenServicio AS o ON o.EquipoID=i.EquipoID
        WHERE i.ClienteID<>d.ClienteID
            OR i.NumeroSerie<>d.NumeroSerie
            OR i.ModeloEquipoID<>d.ModeloEquipoID)
        THROW 51109,N'Equipo con historial: propietario, serie y modelo no se cambian.',1;
END;
GO

-- Valida técnico, estado y fecha; conserva el diagnóstico como historia.
CREATE TRIGGER dbo.trDiagnosticoValido
    ON dbo.Diagnostico
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N'Historia inmutable: no se permite modificar o borrar Diagnostico.', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=i.OrdenID
        WHERE dbo.fnTieneRol(i.UsuarioTecnicoID,'TECNICO')=0
            OR o.EstadoCodigo<>'DIAGNOSTICO'
            OR i.Fecha<o.FechaIngreso)
        THROW 51110,N'Diagnóstico no autorizado, estado/fecha inválido.',1;
END;
GO

-- Valida el inicio y cierre; protege los datos originales y evita borrar la reparación.
CREATE TRIGGER dbo.trReparacionValida
    ON dbo.Reparacion
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En DELETE hay filas anteriores y no hay filas nuevas.
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 51141, N'No se permite borrar físicamente Reparacion.', 1;

    -- INSERT y UPDATE conservan las reglas originales del proceso.
IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Diagnostico AS dg ON dg.DiagnosticoID=i.DiagnosticoID
        INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=dg.OrdenID
        LEFT JOIN deleted AS d ON d.ReparacionID=i.ReparacionID

        WHERE dbo.fnTieneRol(i.UsuarioTecnicoID,'TECNICO')=0
            OR i.FechaInicio<dg.Fecha
            OR (d.ReparacionID IS NULL
            AND (i.Estado<>'EN_PROCESO'
            OR o.EstadoCodigo<>'ESPERANDO_AUTORIZACION'))

            OR (d.ReparacionID IS NOT NULL
            AND (d.Estado<>'EN_PROCESO'
            OR i.Estado<>'TERMINADA'
            OR o.EstadoCodigo<>'REPARACION')))
        THROW 51111,N'Reparación no autorizada o ciclo inválido.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.ReparacionID=i.ReparacionID
        WHERE i.DiagnosticoID<>d.DiagnosticoID
            OR i.UsuarioTecnicoID<>d.UsuarioTecnicoID
            OR i.FechaInicio<>d.FechaInicio
            OR i.CostoManoObra<>d.CostoManoObra
            OR i.DescripcionTrabajo<>d.DescripcionTrabajo)
        THROW 51112,N'No se pueden reescribir datos históricos de reparación.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.ReparacionRepuesto AS rr ON rr.ReparacionID=i.ReparacionID
        LEFT JOIN dbo.MovimientoInventario AS m ON m.ReparacionID=rr.ReparacionID
            AND m.LineaReparacion=rr.Linea
        WHERE i.Estado='TERMINADA'
            AND m.MovimientoID IS NULL)
        THROW 51113,N'Consumo sin movimiento de salida.',1;
END;
GO

-- Valida una tarea de reparación y conserva la tarea registrada.
CREATE TRIGGER dbo.trActividadValida
    ON dbo.ReparacionActividad
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N'Historia inmutable: no se permite modificar o borrar ReparacionActividad.', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Reparacion AS r ON r.ReparacionID=i.ReparacionID
        INNER JOIN dbo.Actividad AS a ON a.ActividadID=i.ActividadID
        WHERE r.Estado<>'EN_PROCESO'
            OR a.Activo=0
            OR i.Fecha<r.FechaInicio)
        THROW 51114,N'Actividad/fecha inválida para la reparación.',1;
END;
GO

-- Valida el consumo de repuestos y conserva sus cantidades y precios históricos.
CREATE TRIGGER dbo.trConsumoValido
    ON dbo.ReparacionRepuesto
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N'Historia inmutable: no se permite modificar o borrar ReparacionRepuesto.', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Reparacion AS r ON r.ReparacionID=i.ReparacionID
        INNER JOIN dbo.Diagnostico AS d ON d.DiagnosticoID=r.DiagnosticoID
        INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=d.OrdenID
        INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=i.RepuestoID
        INNER JOIN dbo.Bodega AS b ON b.BodegaID=i.BodegaID

        WHERE r.Estado<>'EN_PROCESO'
            OR o.EstadoCodigo<>'REPARACION'
            OR p.Activo=0
            OR b.Activo=0)
        THROW 51115,N'Consumo requiere reparación, repuesto y bodega activos.',1;
END;
GO

-- Valida registro, recepción y anulación; protege la compra contra borrado.
CREATE TRIGGER dbo.trCompraCiclo
    ON dbo.Compra
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En DELETE hay filas anteriores y no hay filas nuevas.
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 51141, N'No se permite borrar físicamente Compra.', 1;

    -- INSERT y UPDATE conservan las reglas originales del proceso.
IF EXISTS (SELECT 1
        FROM inserted AS i
        LEFT JOIN deleted AS d ON d.CompraID=i.CompraID
        WHERE d.CompraID IS NULL
            AND (i.Estado<>'PENDIENTE'
            OR dbo.fnTieneRol(i.UsuarioRegistroID,'BODEGA')=0))
        THROW 51116,N'Compra nueva debe estar pendiente y autorizada.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.CompraID=i.CompraID
        WHERE d.Estado<>'PENDIENTE'
            OR i.Estado NOT IN ('RECIBIDA','ANULADA')
            OR i.ProveedorID<>d.ProveedorID
            OR i.UsuarioRegistroID<>d.UsuarioRegistroID
            OR i.NumeroCompra<>d.NumeroCompra
            OR i.Fecha<>d.Fecha)
        THROW 51117,N'No se puede reabrir o reescribir una compra.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        WHERE i.Estado='RECIBIDA'
            AND (NOT EXISTS(SELECT 1
        FROM dbo.DetalleCompra
        WHERE CompraID=i.CompraID)
            OR EXISTS(SELECT 1
        FROM dbo.DetalleCompra AS dc
        LEFT JOIN dbo.MovimientoInventario AS m ON m.CompraID=dc.CompraID
            AND m.LineaCompra=dc.Linea
        WHERE dc.CompraID=i.CompraID
            AND m.MovimientoID IS NULL)))
        THROW 51118,N'Compra recibida requiere todas sus entradas.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.MovimientoInventario AS m ON m.CompraID=i.CompraID
        WHERE i.Estado='ANULADA')
        THROW 51119,N'No se puede anular una compra con entradas.',1;
END;
GO

-- Valida proveedor, repuesto y bodega; conserva las líneas de compra.
CREATE TRIGGER dbo.trDetalleCompraValido
    ON dbo.DetalleCompra
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N'Historia inmutable: no se permite modificar o borrar DetalleCompra.', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Compra AS c ON c.CompraID=i.CompraID
        INNER JOIN dbo.Repuesto AS p ON p.RepuestoID=i.RepuestoID
        INNER JOIN dbo.Bodega AS b ON b.BodegaID=i.BodegaID
        WHERE c.Estado<>'PENDIENTE'
            OR p.Activo=0
            OR b.Activo=0
            OR EXISTS(SELECT 1
        FROM dbo.MovimientoInventario
        WHERE CompraID=i.CompraID)
            OR NOT EXISTS(SELECT 1
        FROM dbo.ProveedorRepuesto AS pr
        WHERE pr.ProveedorID=c.ProveedorID
            AND pr.RepuestoID=i.RepuestoID))
        THROW 51120,N'Detalle fuera de catálogo, destino inactivo o compra ya recibida/en recepción.',1;
END;
GO

-- Valida origen, fecha y stock; conserva los movimientos del kardex.
CREATE TRIGGER dbo.trMovimientoIntegridad
    ON dbo.MovimientoInventario
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N'Historia inmutable: no se permite modificar o borrar MovimientoInventario.', 1;

    -- Para INSERT, continúa la validación original.
DECLARE @Pares TABLE (BodegaID int NOT NULL,RepuestoID int NOT NULL,PRIMARY KEY(BodegaID,RepuestoID));
 INSERT @Pares SELECT vm.BodegaID,vm.RepuestoID
               FROM inserted AS i
                        INNER JOIN dbo.vMovimientoInventario AS vm ON vm.MovimientoID=i.MovimientoID
               GROUP BY vm.BodegaID,vm.RepuestoID;
DECLARE @Lock int;
SELECT @Lock=iv.RepuestoID
FROM dbo.Inventario AS iv WITH (UPDLOCK,HOLDLOCK)
        INNER JOIN @Pares AS p ON p.BodegaID=iv.BodegaID
    AND p.RepuestoID=iv.RepuestoID;
IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Compra AS c ON c.CompraID=i.CompraID
        WHERE c.Estado<>'PENDIENTE'
            OR i.Fecha<c.Fecha
            OR dbo.fnTieneRol(i.UsuarioID,'BODEGA')=0)
        THROW 51121,N'Entrada no autorizada o compra/fecha inválida.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Reparacion AS r ON r.ReparacionID=i.ReparacionID
        WHERE r.Estado<>'EN_PROCESO'
            OR i.Fecha<r.FechaInicio
            OR dbo.fnTieneRol(i.UsuarioID,'TECNICO')=0)
        THROW 51122,N'Salida no autorizada o reparación/fecha inválida.',1;
 IF EXISTS (SELECT 1
        FROM dbo.vInventario AS v
        INNER JOIN @Pares AS p ON p.BodegaID=v.BodegaID
            AND p.RepuestoID=v.RepuestoID
        WHERE v.Existencia<0)
        THROW 51123,N'El movimiento produciría stock negativo.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.vMovimientoInventario AS vm ON vm.MovimientoID=i.MovimientoID

        CROSS APPLY (SELECT SUM(a.CantidadFirmada) AS Stock
        FROM dbo.vMovimientoInventario AS a
        WHERE a.BodegaID=vm.BodegaID
            AND a.RepuestoID=vm.RepuestoID
            AND a.MovimientoID<=i.MovimientoID) AS saldo

        WHERE i.ExistenciaResultante<>saldo.Stock)
        THROW 51124,N'Existencia resultante no corresponde al kardex.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.vMovimientoInventario AS vm ON vm.MovimientoID=i.MovimientoID
        INNER JOIN dbo.vMovimientoInventario AS previo ON previo.BodegaID=vm.BodegaID
            AND previo.RepuestoID=vm.RepuestoID
            AND previo.MovimientoID<i.MovimientoID
        WHERE previo.Fecha>i.Fecha)
        THROW 51125,N'No se permiten movimientos retroactivos respecto del kardex.',1;
END;
GO

-- Valida emisión y anulación; conserva los datos fiscales y protege contra borrado.
CREATE TRIGGER dbo.trFacturaValida
    ON dbo.Factura
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En DELETE hay filas anteriores y no hay filas nuevas.
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 51141, N'No se permite borrar físicamente Factura.', 1;

    -- INSERT y UPDATE conservan las reglas originales del proceso.
IF EXISTS (SELECT 1
        FROM inserted AS i
        LEFT JOIN deleted AS old ON old.FacturaID=i.FacturaID
        INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=i.OrdenID
        LEFT JOIN dbo.Diagnostico AS d ON d.OrdenID=o.OrdenID
        LEFT JOIN dbo.Reparacion AS r ON r.DiagnosticoID=d.DiagnosticoID
        WHERE old.FacturaID IS NULL
            AND (i.Estado<>'EMITIDA'
            OR o.EstadoCodigo<>'LISTO'
            OR r.ReparacionID IS NULL
            OR r.Estado<>'TERMINADA'
            OR i.Fecha<r.FechaFin
            OR dbo.fnTieneRol(i.UsuarioEmisionID,'CAJA')=0))
        THROW 51126,N'Factura requiere servicio terminado y usuario de caja.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.FacturaID=i.FacturaID
        WHERE d.Estado<>'EMITIDA'
            OR i.Estado<>'ANULADA'
            OR i.OrdenID<>d.OrdenID
            OR i.NumeroFactura<>d.NumeroFactura
            OR i.Fecha<>d.Fecha
            OR i.TasaImpuesto<>d.TasaImpuesto
            OR i.NITFacturacion<>d.NITFacturacion
            OR i.NombreFacturacion<>d.NombreFacturacion
            OR i.UsuarioEmisionID<>d.UsuarioEmisionID
            OR EXISTS(SELECT 1
        FROM dbo.Pago
        WHERE FacturaID=i.FacturaID)
            OR EXISTS(SELECT 1
        FROM dbo.Entrega
        WHERE OrdenID=i.OrdenID))
        THROW 51127,N'Factura histórica inmutable; anulación sólo sin pagos/entrega.',1;
END;
GO

-- Valida conceptos y precios de la factura; conserva sus líneas.
CREATE TRIGGER dbo.trFacturaDetalleValido
    ON dbo.FacturaDetalle
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N'Historia inmutable: no se permite modificar o borrar FacturaDetalle.', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Factura AS f ON f.FacturaID=i.FacturaID
        INNER JOIN dbo.Reparacion AS r ON r.ReparacionID=i.ReparacionID
        INNER JOIN dbo.Diagnostico AS d ON d.DiagnosticoID=r.DiagnosticoID
        LEFT JOIN dbo.ReparacionRepuesto AS rr ON rr.ReparacionID=i.ReparacionID
            AND rr.Linea=i.LineaReparacion

        WHERE f.OrdenID<>d.OrdenID
            OR f.Estado<>'EMITIDA'
            OR r.Estado<>'TERMINADA'
            OR EXISTS(SELECT 1
        FROM dbo.Pago
        WHERE FacturaID=i.FacturaID)

            OR (i.TipoConcepto='MO'
            AND i.PrecioUnitario<>r.CostoManoObra)

            OR (i.TipoConcepto='REP'
            AND (i.Cantidad<>rr.Cantidad
            OR i.PrecioUnitario<>rr.PrecioUnitario
            OR NOT EXISTS(SELECT 1
        FROM dbo.MovimientoInventario
        WHERE ReparacionID=i.ReparacionID
            AND LineaReparacion=i.LineaReparacion))))
        THROW 51128,N'Línea de factura incompatible con su servicio histórico.',1;
END;
GO

-- Valida usuario, fecha y saldo; conserva cada pago registrado.
CREATE TRIGGER dbo.trPagoSaldo
    ON dbo.Pago
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N'Historia inmutable: no se permite modificar o borrar Pago.', 1;

    -- Para INSERT, continúa la validación original.
DECLARE @Lock int;
SELECT @Lock=f.FacturaID
FROM dbo.Factura AS f WITH (UPDLOCK,HOLDLOCK)
        INNER JOIN inserted AS i ON i.FacturaID=f.FacturaID;
IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Factura AS f ON f.FacturaID=i.FacturaID
        WHERE f.Estado<>'EMITIDA'
            OR i.Fecha<f.Fecha
            OR dbo.fnTieneRol(i.UsuarioRegistroID,'CAJA')=0
            OR NOT EXISTS(SELECT 1
        FROM dbo.FacturaDetalle
        WHERE FacturaID=f.FacturaID))
        THROW 51129,N'Pago no autorizado o factura/fecha inválida.',1;
 IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.vFacturaSaldo AS f ON f.FacturaID=i.FacturaID
        WHERE f.Saldo<0)
        THROW 51130,N'La suma de pagos excede el total de la factura.',1;
END;
GO

-- Valida receptor, fecha y factura pagada; conserva la entrega.
CREATE TRIGGER dbo.trEntregaValida
    ON dbo.Entrega
    AFTER INSERT, UPDATE, DELETE
    AS
BEGIN
    SET NOCOUNT ON;
    -- En UPDATE o DELETE, deleted contiene las filas anteriores.
    -- Estos registros históricos sólo pueden insertarse.
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51140, N'Historia inmutable: no se permite modificar o borrar Entrega.', 1;

    -- Para INSERT, continúa la validación original.
IF EXISTS (SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.OrdenServicio AS o ON o.OrdenID=i.OrdenID
        LEFT JOIN dbo.vFacturaSaldo AS f ON f.OrdenID=i.OrdenID
        WHERE o.EstadoCodigo<>'LISTO'
            OR f.FacturaID IS NULL
            OR f.Estado<>'EMITIDA'
            OR f.Saldo<>0
            OR i.Fecha<f.Fecha
            OR dbo.fnTieneRol(i.UsuarioEntregaID,'RECEPCION')=0
            OR NULLIF(LTRIM(RTRIM(i.NombreRecibe)),N'') IS NULL
            OR EXISTS(SELECT 1
        FROM dbo.Pago AS p
        WHERE p.FacturaID=f.FacturaID
            AND p.Fecha>i.Fecha))
        THROW 51131,N'Entrega requiere factura pagada, fecha y receptor válidos.',1;
END;
GO

-- Guarda automáticamente el precio y costo anterior y nuevo del catálogo.
CREATE TRIGGER dbo.trAuditoriaPrecio
    ON dbo.Repuesto
    AFTER UPDATE
              AS
BEGIN
    SET NOCOUNT ON;
INSERT dbo.AuditoriaPrecioRepuesto (RepuestoID,CostoAnterior,CostoNuevo,PrecioAnterior,PrecioNuevo,LoginSQL,UsuarioAplicacionID)
SELECT i.RepuestoID,d.CostoReferencia,i.CostoReferencia,d.PrecioVenta,i.PrecioVenta,ORIGINAL_LOGIN(),
       CASE WHEN EXISTS (SELECT 1
                         FROM dbo.Usuario
                         WHERE UsuarioID=TRY_CONVERT(int,SESSION_CONTEXT(N'UsuarioID'))) THEN TRY_CONVERT(int,SESSION_CONTEXT(N'UsuarioID')) ELSE NULL END

FROM inserted AS i
         INNER JOIN deleted AS d ON d.RepuestoID=i.RepuestoID

WHERE i.CostoReferencia<>d.CostoReferencia
   OR i.PrecioVenta<>d.PrecioVenta;
END;
GO

-- Protege los cambios de estado ya registrados.
CREATE TRIGGER dbo.trHistorialEstadoOrdenInmutable
    ON dbo.HistorialEstadoOrden
    INSTEAD OF UPDATE,DELETE
    AS
BEGIN
    SET NOCOUNT ON;
THROW 51140,N'Historia inmutable: no se permite UPDATE/DELETE en HistorialEstadoOrden.',1;
END;
GO


-- Protege los registros de auditoría de precios.
CREATE TRIGGER dbo.trAuditoriaPrecioRepuestoInmutable
    ON dbo.AuditoriaPrecioRepuesto
    INSTEAD OF UPDATE,DELETE
    AS
BEGIN
    SET NOCOUNT ON;
THROW 51140,N'Historia inmutable: no se permite UPDATE/DELETE en AuditoriaPrecioRepuesto.',1;
END;
GO


-- ============================================================================
-- 09 / PERMISOS DEL BACKEND - Cadena de propiedad para los procedimientos
-- ============================================================================

CREATE ROLE techcare_app AUTHORIZATION dbo;
GRANT SELECT ON SCHEMA::dbo TO techcare_app;
GRANT EXECUTE ON SCHEMA::dbo TO techcare_app;
GRANT REFERENCES ON SCHEMA::dbo TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.OrdenServicio TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.HistorialEstadoOrden TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.Diagnostico TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.Reparacion TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ReparacionActividad TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.Compra TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.DetalleCompra TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ReparacionRepuesto TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.MovimientoInventario TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.Factura TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.FacturaDetalle TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.Pago TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.Entrega TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.AuditoriaPrecioRepuesto TO techcare_app;
GO

DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.Cliente TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.Equipo TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.Proveedor TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.ProveedorRepuesto TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.Repuesto TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.Bodega TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.Inventario TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.Actividad TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.Marca TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.ModeloEquipo TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.CategoriaRepuesto TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.Empleado TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.Usuario TO techcare_app;
GO

GRANT INSERT,UPDATE ON OBJECT::dbo.UsuarioRol TO techcare_app;
GO

PRINT N'TechCare creada. Ejecute 02_Datos_Prueba.sql, 03_Reportes.sql y 04_Pruebas_Integridad.sql.';
SET NOEXEC OFF;
GO
