-- Catálogos de abastecimiento. Ejecutar completo después del 23.
-- No crea existencias ni modifica compras, consumos o facturas históricas.
USE [TechCare];
GO
SET NOCOUNT ON; SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.spEmitirFacturaOrden',N'P') IS NULL
    THROW 52090,N'Ejecutá primero 23_Facturacion_Entrega_Procedimientos.sql.',1;
GO
CREATE OR ALTER VIEW dbo.vCategoriaRepuestoGestion AS
SELECT CategoriaID,Nombre,CONVERT(varchar(64),HASHBYTES('SHA2_256',CONCAT(CONVERT(nvarchar(max),CategoriaID),N'|',DATALENGTH(Nombre),N':',Nombre)),2) AS Revision
FROM dbo.CategoriaRepuesto;
GO
CREATE OR ALTER VIEW dbo.vRepuestoGestion AS
SELECT r.RepuestoID,r.CategoriaID,c.Nombre AS Categoria,r.Codigo,r.Nombre,r.Descripcion,r.CostoReferencia,r.PrecioVenta,r.Activo,
    CONVERT(varchar(64),HASHBYTES('SHA2_256',CONCAT(CONVERT(nvarchar(max),r.RepuestoID),N'|',r.CategoriaID,N'|',
        DATALENGTH(r.Codigo),N':',r.Codigo,N'|',DATALENGTH(r.Nombre),N':',r.Nombre,N'|',
        COALESCE(DATALENGTH(r.Descripcion),-1),N':',r.Descripcion,N'|',r.CostoReferencia,N'|',r.PrecioVenta,N'|',r.Activo)),2) AS Revision
FROM dbo.Repuesto r JOIN dbo.CategoriaRepuesto c ON c.CategoriaID=r.CategoriaID;
GO
CREATE OR ALTER VIEW dbo.vProveedorGestion AS
SELECT ProveedorID,NIT,Nombre,Email,Telefono,Direccion,Activo,
    CONVERT(varchar(64),HASHBYTES('SHA2_256',CONCAT(CONVERT(nvarchar(max),ProveedorID),N'|',DATALENGTH(NIT),N':',NIT,N'|',
        DATALENGTH(Nombre),N':',Nombre,N'|',COALESCE(DATALENGTH(Email),-1),N':',Email,N'|',
        COALESCE(DATALENGTH(Telefono),-1),N':',Telefono,N'|',COALESCE(DATALENGTH(Direccion),-1),N':',Direccion,N'|',Activo)),2) AS Revision
FROM dbo.Proveedor;
GO
CREATE OR ALTER VIEW dbo.vBodegaGestion AS
SELECT BodegaID,Codigo,Nombre,Direccion,Activo,
    CONVERT(varchar(64),HASHBYTES('SHA2_256',CONCAT(CONVERT(nvarchar(max),BodegaID),N'|',DATALENGTH(Codigo),N':',Codigo,N'|',
        DATALENGTH(Nombre),N':',Nombre,N'|',COALESCE(DATALENGTH(Direccion),-1),N':',Direccion,N'|',Activo)),2) AS Revision
FROM dbo.Bodega;
GO
CREATE OR ALTER VIEW dbo.vOfertaProveedorGestion AS
SELECT pr.ProveedorID,pr.RepuestoID,r.Codigo,r.Nombre,r.CategoriaID,c.Nombre AS Categoria,r.Activo,r.PrecioVenta,pr.CodigoProveedor,
    CONVERT(varchar(64),HASHBYTES('SHA2_256',CONCAT(CONVERT(nvarchar(max),pr.ProveedorID),N'|',pr.RepuestoID,N'|',
        COALESCE(DATALENGTH(pr.CodigoProveedor),-1),N':',pr.CodigoProveedor)),2) AS Revision
FROM dbo.ProveedorRepuesto pr JOIN dbo.Repuesto r ON r.RepuestoID=pr.RepuestoID JOIN dbo.CategoriaRepuesto c ON c.CategoriaID=r.CategoriaID;
GO
CREATE OR ALTER VIEW dbo.vRepuestoBodegaGestion AS
SELECT i.BodegaID,i.RepuestoID,r.Codigo,r.Nombre,r.Activo,i.StockMinimo,i.Existencia
FROM dbo.vInventario i JOIN dbo.Repuesto r ON r.RepuestoID=i.RepuestoID;
GO
CREATE OR ALTER PROCEDURE dbo.spValidarActorAbastecimiento @UsuarioActorID int AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fnTieneRol(@UsuarioActorID,'BODEGA')=0 THROW 52004,N'Se requiere un usuario activo de bodega o administración.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spValidarRevisionAbastecimiento @Actual varchar(64),@Revision nvarchar(max) AS
BEGIN
    SET NOCOUNT ON;
    IF @Actual IS NULL THROW 52002,N'El registro no existe.',1;
    IF @Revision IS NULL OR DATALENGTH(@Revision)<>128
       OR @Actual COLLATE Latin1_General_100_BIN2<>@Revision COLLATE Latin1_General_100_BIN2
        THROW 52003,N'El registro cambió. Actualizá los datos y revisalos antes de guardar.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spListarCategoriasRepuesto @UsuarioActorID int AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    SELECT * FROM dbo.vCategoriaRepuestoGestion ORDER BY Nombre,CategoriaID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spGuardarCategoriaRepuesto
    @UsuarioActorID int,@CategoriaID int,@Nombre nvarchar(max),@Revision nvarchar(max)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APICategoriaRepuesto;
        EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
        SET @Nombre=NULLIF(LTRIM(RTRIM(@Nombre)),N'');
        IF @Nombre IS NULL OR DATALENGTH(@Nombre)>160 OR @CategoriaID<=0 OR (@CategoriaID IS NULL AND @Revision IS NOT NULL)
            THROW 52000,N'Ingresá una categoría de hasta 80 caracteres y un ID válido.',1;
        IF @CategoriaID IS NULL
        BEGIN
            INSERT dbo.CategoriaRepuesto(Nombre) VALUES (@Nombre); SET @CategoriaID=CONVERT(int,SCOPE_IDENTITY());
        END
        ELSE
        BEGIN
            DECLARE @Actual varchar(64);
            SELECT @Actual=Revision FROM dbo.vCategoriaRepuestoGestion WITH (UPDLOCK,HOLDLOCK) WHERE CategoriaID=@CategoriaID;
            EXEC dbo.spValidarRevisionAbastecimiento @Actual,@Revision;
            UPDATE dbo.CategoriaRepuesto SET Nombre=@Nombre WHERE CategoriaID=@CategoriaID;
        END;
        IF @Propia=1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vCategoriaRepuestoGestion WHERE CategoriaID=@CategoriaID;
    END TRY
    BEGIN CATCH
        IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION APICategoriaRepuesto;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spListarRepuestosGestion
    @UsuarioActorID int,@Buscar nvarchar(max)=NULL,@CategoriaID int=NULL,@Activo bit=NULL
AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    SET @Buscar=NULLIF(LTRIM(RTRIM(@Buscar)),N'');
    IF DATALENGTH(@Buscar)>300 OR @CategoriaID<=0 THROW 52000,N'Revisá los filtros de repuestos.',1;
    SELECT * FROM dbo.vRepuestoGestion WHERE (@CategoriaID IS NULL OR CategoriaID=@CategoriaID)
      AND (@Activo IS NULL OR Activo=@Activo)
      AND (@Buscar IS NULL OR CHARINDEX(@Buscar,Codigo)>0 OR CHARINDEX(@Buscar,Nombre)>0 OR CHARINDEX(@Buscar,Descripcion)>0)
    ORDER BY Nombre,RepuestoID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spConsultarRepuestoGestion @UsuarioActorID int,@RepuestoID int AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    IF @RepuestoID IS NULL OR @RepuestoID<=0 THROW 52000,N'El ID del repuesto no es válido.',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Repuesto WHERE RepuestoID=@RepuestoID) THROW 52002,N'El repuesto no existe.',1;
    SELECT * FROM dbo.vRepuestoGestion WHERE RepuestoID=@RepuestoID;
END;
GO
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
CREATE OR ALTER PROCEDURE dbo.spPreciosRepuestoGestion @UsuarioActorID int,@RepuestoID int AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    IF @RepuestoID IS NULL OR @RepuestoID<=0 THROW 52000,N'El ID del repuesto no es válido.',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Repuesto WHERE RepuestoID=@RepuestoID) THROW 52002,N'El repuesto no existe.',1;
    SELECT a.AuditoriaID,a.Fecha,a.CostoAnterior,a.CostoNuevo,a.PrecioAnterior,a.PrecioNuevo,
       e.Nombres+N' '+e.Apellidos AS RegistradoPor
    FROM dbo.AuditoriaPrecioRepuesto a LEFT JOIN dbo.Usuario u ON u.UsuarioID=a.UsuarioAplicacionID
    LEFT JOIN dbo.Empleado e ON e.EmpleadoID=u.EmpleadoID
    WHERE a.RepuestoID=@RepuestoID ORDER BY a.AuditoriaID DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spListarProveedoresGestion @UsuarioActorID int,@Buscar nvarchar(max)=NULL,@Activo bit=NULL AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    SET @Buscar=NULLIF(LTRIM(RTRIM(@Buscar)),N'');
    IF DATALENGTH(@Buscar)>300 THROW 52000,N'La búsqueda admite hasta 150 caracteres.',1;
    SELECT * FROM dbo.vProveedorGestion WHERE (@Activo IS NULL OR Activo=@Activo)
      AND (@Buscar IS NULL OR CHARINDEX(@Buscar,NIT)>0 OR CHARINDEX(@Buscar,Nombre)>0 OR CHARINDEX(@Buscar,Email)>0 OR CHARINDEX(@Buscar,Telefono)>0)
    ORDER BY Nombre,ProveedorID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spConsultarProveedorGestion @UsuarioActorID int,@ProveedorID int AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    IF @ProveedorID IS NULL OR @ProveedorID<=0 THROW 52000,N'El ID del proveedor no es válido.',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE ProveedorID=@ProveedorID) THROW 52002,N'El proveedor no existe.',1;
    SELECT * FROM dbo.vProveedorGestion WHERE ProveedorID=@ProveedorID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spGuardarProveedorGestion
    @UsuarioActorID int,@ProveedorID int,@NIT nvarchar(max),@Nombre nvarchar(max),@Email nvarchar(max),
    @Telefono nvarchar(max),@Direccion nvarchar(max),@Activo bit,@Revision nvarchar(max)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIProveedorGestion;
        EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
        SET @NIT=NULLIF(LTRIM(RTRIM(@NIT)),N''); SET @Nombre=NULLIF(LTRIM(RTRIM(@Nombre)),N'');
        SET @Email=NULLIF(LTRIM(RTRIM(@Email)),N''); SET @Telefono=NULLIF(LTRIM(RTRIM(@Telefono)),N''); SET @Direccion=NULLIF(LTRIM(RTRIM(@Direccion)),N'');
        IF @ProveedorID<=0 OR (@ProveedorID IS NULL AND @Revision IS NOT NULL) OR @Activo IS NULL
           OR @NIT IS NULL OR DATALENGTH(@NIT)>40 OR @NIT COLLATE Latin1_General_100_BIN2 LIKE N'%[^-0-9A-Za-z]%'
           OR @Nombre IS NULL OR DATALENGTH(@Nombre)>300 OR DATALENGTH(@Email)>508 OR DATALENGTH(@Telefono)>50 OR DATALENGTH(@Direccion)>500
           OR (@Email IS NOT NULL AND (@Email NOT LIKE N'%_@_%._%' OR @Email LIKE N'% %'))
           OR @Telefono COLLATE Latin1_General_100_BIN2 LIKE N'%[^ -~]%'
            THROW 52000,N'Revisá NIT (20), nombre (150), correo (254), teléfono (25), dirección (250) y estado.',1;
        IF @ProveedorID IS NULL
        BEGIN
            INSERT dbo.Proveedor(NIT,Nombre,Email,Telefono,Direccion,Activo) VALUES (@NIT,@Nombre,@Email,@Telefono,@Direccion,@Activo);
            SET @ProveedorID=CONVERT(int,SCOPE_IDENTITY());
        END
        ELSE
        BEGIN
            DECLARE @Actual varchar(64);
            SELECT @Actual=Revision FROM dbo.vProveedorGestion WITH (UPDLOCK,HOLDLOCK) WHERE ProveedorID=@ProveedorID;
            EXEC dbo.spValidarRevisionAbastecimiento @Actual,@Revision;
            UPDATE dbo.Proveedor SET NIT=@NIT,Nombre=@Nombre,Email=@Email,Telefono=@Telefono,Direccion=@Direccion,Activo=@Activo WHERE ProveedorID=@ProveedorID;
        END;
        IF @Propia=1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vProveedorGestion WHERE ProveedorID=@ProveedorID;
    END TRY
    BEGIN CATCH
        IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION APIProveedorGestion;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spOfertasProveedorGestion @UsuarioActorID int,@ProveedorID int AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    IF @ProveedorID IS NULL OR @ProveedorID<=0 THROW 52000,N'El ID del proveedor no es válido.',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE ProveedorID=@ProveedorID) THROW 52002,N'El proveedor no existe.',1;
    SELECT * FROM dbo.vOfertaProveedorGestion WHERE ProveedorID=@ProveedorID ORDER BY Nombre,RepuestoID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spGuardarOfertaProveedor
    @UsuarioActorID int,@ProveedorID int,@RepuestoID int,@CodigoProveedor nvarchar(max),@Ofrecido bit,@Revision nvarchar(max)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIOfertaProveedor;
        EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
        SET @CodigoProveedor=NULLIF(LTRIM(RTRIM(@CodigoProveedor)),N'');
        IF @ProveedorID IS NULL OR @ProveedorID<=0 OR @RepuestoID IS NULL OR @RepuestoID<=0 OR @Ofrecido IS NULL
           OR DATALENGTH(@CodigoProveedor)>100 OR @CodigoProveedor COLLATE Latin1_General_100_BIN2 LIKE N'%[^-0-9A-Za-z._/ ]%'
            THROW 52000,N'Revisá proveedor, repuesto y código del proveedor (hasta 50 caracteres).',1;
        DECLARE @ProveedorActivo bit,@RepuestoActivo bit,@Actual varchar(64);
        SELECT @ProveedorActivo=Activo FROM dbo.Proveedor WITH (UPDLOCK,HOLDLOCK) WHERE ProveedorID=@ProveedorID;
        SELECT @RepuestoActivo=Activo FROM dbo.Repuesto WITH (HOLDLOCK) WHERE RepuestoID=@RepuestoID;
        IF @ProveedorActivo IS NULL OR @RepuestoActivo IS NULL THROW 52002,N'El proveedor o repuesto no existe.',1;
        DECLARE @BloqueoOferta int;
        SELECT @BloqueoOferta=RepuestoID FROM dbo.ProveedorRepuesto WITH (UPDLOCK,HOLDLOCK) WHERE ProveedorID=@ProveedorID AND RepuestoID=@RepuestoID;
        SELECT @Actual=Revision FROM dbo.vOfertaProveedorGestion WHERE ProveedorID=@ProveedorID AND RepuestoID=@RepuestoID;
        IF @Actual IS NULL AND (@Revision IS NOT NULL OR @Ofrecido=0)
            THROW 52003,N'La asociación cambió o ya fue retirada. Actualizá el catálogo del proveedor.',1;
        IF @Actual IS NOT NULL EXEC dbo.spValidarRevisionAbastecimiento @Actual,@Revision;
        IF @Ofrecido=1
        BEGIN
            IF @ProveedorActivo=0 OR @RepuestoActivo=0 THROW 52001,N'El proveedor y el repuesto deben estar activos para ofrecerlo.',1;
            IF @Actual IS NULL INSERT dbo.ProveedorRepuesto(ProveedorID,RepuestoID,CodigoProveedor) VALUES (@ProveedorID,@RepuestoID,@CodigoProveedor);
            ELSE UPDATE dbo.ProveedorRepuesto SET CodigoProveedor=@CodigoProveedor WHERE ProveedorID=@ProveedorID AND RepuestoID=@RepuestoID;
        END
        ELSE
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Compra c WITH (HOLDLOCK) JOIN dbo.DetalleCompra d WITH (HOLDLOCK) ON d.CompraID=c.CompraID
                       WHERE c.ProveedorID=@ProveedorID AND c.Estado='PENDIENTE' AND d.RepuestoID=@RepuestoID)
                THROW 52003,N'Hay compras pendientes de este repuesto con el proveedor. Resolvelas antes de retirar la asociación.',1;
            DELETE FROM dbo.ProveedorRepuesto WHERE ProveedorID=@ProveedorID AND RepuestoID=@RepuestoID;
        END;
        IF @Propia=1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vOfertaProveedorGestion WHERE ProveedorID=@ProveedorID AND RepuestoID=@RepuestoID;
    END TRY
    BEGIN CATCH
        IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION APIOfertaProveedor;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spListarBodegasGestion @UsuarioActorID int,@Buscar nvarchar(max)=NULL,@Activo bit=NULL AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    SET @Buscar=NULLIF(LTRIM(RTRIM(@Buscar)),N'');
    IF DATALENGTH(@Buscar)>300 THROW 52000,N'La búsqueda admite hasta 150 caracteres.',1;
    SELECT * FROM dbo.vBodegaGestion WHERE (@Activo IS NULL OR Activo=@Activo)
      AND (@Buscar IS NULL OR CHARINDEX(@Buscar,Codigo)>0 OR CHARINDEX(@Buscar,Nombre)>0 OR CHARINDEX(@Buscar,Direccion)>0)
    ORDER BY Nombre,BodegaID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spConsultarBodegaGestion @UsuarioActorID int,@BodegaID int AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    IF @BodegaID IS NULL OR @BodegaID<=0 THROW 52000,N'El ID de bodega no es válido.',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE BodegaID=@BodegaID) THROW 52002,N'La bodega no existe.',1;
    SELECT * FROM dbo.vBodegaGestion WHERE BodegaID=@BodegaID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spGuardarBodegaGestion
    @UsuarioActorID int,@BodegaID int,@Codigo nvarchar(max),@Nombre nvarchar(max),@Direccion nvarchar(max),@Activo bit,@Revision nvarchar(max)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIBodegaGestion;
        EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
        SET @Codigo=NULLIF(LTRIM(RTRIM(@Codigo)),N''); SET @Nombre=NULLIF(LTRIM(RTRIM(@Nombre)),N''); SET @Direccion=NULLIF(LTRIM(RTRIM(@Direccion)),N'');
        IF @BodegaID<=0 OR (@BodegaID IS NULL AND @Revision IS NOT NULL) OR @Activo IS NULL
           OR @Codigo IS NULL OR DATALENGTH(@Codigo)>40 OR @Codigo COLLATE Latin1_General_100_BIN2 LIKE N'%[^-0-9A-Za-z._/]%'
           OR @Nombre IS NULL OR DATALENGTH(@Nombre)>200 OR DATALENGTH(@Direccion)>500
            THROW 52000,N'Revisá código (20), nombre (100), dirección (250) y estado de la bodega.',1;
        IF @BodegaID IS NULL
        BEGIN
            INSERT dbo.Bodega(Codigo,Nombre,Direccion,Activo) VALUES (@Codigo,@Nombre,@Direccion,@Activo); SET @BodegaID=CONVERT(int,SCOPE_IDENTITY());
        END
        ELSE
        BEGIN
            DECLARE @Actual varchar(64);
            SELECT @Actual=Revision FROM dbo.vBodegaGestion WITH (UPDLOCK,HOLDLOCK) WHERE BodegaID=@BodegaID;
            EXEC dbo.spValidarRevisionAbastecimiento @Actual,@Revision;
            UPDATE dbo.Bodega SET Codigo=@Codigo,Nombre=@Nombre,Direccion=@Direccion,Activo=@Activo WHERE BodegaID=@BodegaID;
        END;
        IF @Propia=1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vBodegaGestion WHERE BodegaID=@BodegaID;
    END TRY
    BEGIN CATCH
        IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION APIBodegaGestion;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spRepuestosBodegaGestion @UsuarioActorID int,@BodegaID int AS
BEGIN
    SET NOCOUNT ON; EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
    IF @BodegaID IS NULL OR @BodegaID<=0 THROW 52000,N'El ID de bodega no es válido.',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE BodegaID=@BodegaID) THROW 52002,N'La bodega no existe.',1;
    SELECT * FROM dbo.vRepuestoBodegaGestion WHERE BodegaID=@BodegaID ORDER BY Nombre,RepuestoID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spGuardarRepuestoBodega
    @UsuarioActorID int,@BodegaID int,@RepuestoID int,@StockMinimo decimal(19,4),@StockMinimoEsperado decimal(19,4)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Propia bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @Propia=1 BEGIN TRANSACTION; ELSE SAVE TRANSACTION APIRepuestoBodega;
        EXEC dbo.spValidarActorAbastecimiento @UsuarioActorID;
        IF @BodegaID IS NULL OR @BodegaID<=0 OR @RepuestoID IS NULL OR @RepuestoID<=0
           OR @StockMinimo IS NULL OR @StockMinimo<0 OR @StockMinimo>2147483647 OR ROUND(@StockMinimo,0)<>@StockMinimo
           OR (@StockMinimoEsperado IS NOT NULL AND (@StockMinimoEsperado<0 OR @StockMinimoEsperado>2147483647 OR ROUND(@StockMinimoEsperado,0)<>@StockMinimoEsperado))
            THROW 52000,N'Ingresá IDs válidos y mínimos enteros desde cero hasta 2147483647.',1;
        DECLARE @BodegaActiva bit,@RepuestoActivo bit,@Actual int;
        SELECT @BodegaActiva=Activo FROM dbo.Bodega WITH (UPDLOCK,HOLDLOCK) WHERE BodegaID=@BodegaID;
        SELECT @RepuestoActivo=Activo FROM dbo.Repuesto WITH (HOLDLOCK) WHERE RepuestoID=@RepuestoID;
        IF @BodegaActiva IS NULL OR @RepuestoActivo IS NULL THROW 52002,N'La bodega o repuesto no existe.',1;
        IF @BodegaActiva=0 OR @RepuestoActivo=0 THROW 52001,N'La bodega y el repuesto deben estar activos.',1;
        SELECT @Actual=StockMinimo FROM dbo.Inventario WITH (UPDLOCK,HOLDLOCK) WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID;
        IF (@Actual IS NULL AND @StockMinimoEsperado IS NOT NULL) OR (@Actual IS NOT NULL AND (@StockMinimoEsperado IS NULL OR @Actual<>@StockMinimoEsperado))
            THROW 52003,N'El mínimo o la asociación cambió. Actualizá los repuestos de la bodega.',1;
        IF @Actual IS NULL INSERT dbo.Inventario(BodegaID,RepuestoID,StockMinimo) VALUES (@BodegaID,@RepuestoID,@StockMinimo);
        ELSE UPDATE dbo.Inventario SET StockMinimo=@StockMinimo WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID;
        IF @Propia=1 COMMIT TRANSACTION;
        SELECT * FROM dbo.vRepuestoBodegaGestion WHERE BodegaID=@BodegaID AND RepuestoID=@RepuestoID;
    END TRY
    BEGIN CATCH
        IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @Propia=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION APIRepuestoBodega;
        THROW;
    END CATCH;
END;
GO
IF DATABASE_PRINCIPAL_ID(N'techcare_app') IS NOT NULL
BEGIN
    GRANT EXECUTE ON SCHEMA::dbo TO techcare_app;
    DENY INSERT,UPDATE,DELETE ON dbo.Repuesto TO techcare_app;
    DENY INSERT,UPDATE,DELETE ON dbo.Proveedor TO techcare_app;
    DENY INSERT,UPDATE,DELETE ON dbo.ProveedorRepuesto TO techcare_app;
    DENY INSERT,UPDATE,DELETE ON dbo.Bodega TO techcare_app;
    DENY INSERT,UPDATE,DELETE ON dbo.Inventario TO techcare_app;
    DENY INSERT,UPDATE,DELETE ON dbo.CategoriaRepuesto TO techcare_app;
END;
GO
