-- Ejecutar completo en SSMS después del 08, usando una cuenta de pruebas con permisos de administración.
-- Cada caso se revierte. Los únicos registros temporales persistidos son dos clientes y dos equipos;
-- se eliminan al terminar. No se cambia ninguna orden, cliente ni equipo preexistente.
-- Requiere los catálogos y un usuario de RECEPCION del conjunto de demostración.
USE [TechCare];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 51981,N'Ejecutá las pruebas sin una transacción previa abierta.',1;
DECLARE @Token varchar(20)=LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),20);
DECLARE @Cliente1 int,@Cliente2 int,@Equipo1 int,@Equipo2 int,
 @Modelo1 int=(SELECT MIN(ModeloEquipoID) FROM dbo.ModeloEquipo),@Modelo2 int,
 @Recepcion int=(SELECT MIN(UsuarioID) FROM dbo.Usuario WHERE Activo=1 AND dbo.fnTieneRol(UsuarioID,'RECEPCION')=1),
 @TipoCliente tinyint=(SELECT MIN(TipoClienteID) FROM dbo.TipoCliente),@Marca int,@Tipo int;
SET @Modelo2=(SELECT MIN(ModeloEquipoID) FROM dbo.ModeloEquipo WHERE ModeloEquipoID<>@Modelo1);
IF @Modelo1 IS NULL OR @Modelo2 IS NULL OR @Recepcion IS NULL OR @TipoCliente IS NULL
 THROW 51982,N'Faltan catálogos, dos modelos o un usuario de RECEPCION para las pruebas.',1;
SELECT @Marca=MarcaID,@Tipo=TipoEquipoID FROM dbo.ModeloEquipo WHERE ModeloEquipoID=@Modelo1;
DECLARE @Serie1 nvarchar(80)=N'TEST-EQ-A-'+@Token,@Serie2 nvarchar(80)=N'TEST-EQ-B-'+@Token,
 @NuevaSerie nvarchar(80)=N'TEST-EQ-C-'+@Token,@NumeroOrden varchar(30)='TEST-EQ-'+@Token,
 @NIT1 varchar(20)='EQA'+LEFT(@Token,17),@NIT2 varchar(20)='EQB'+LEFT(@Token,17);
BEGIN TRY
 BEGIN TRANSACTION;
 INSERT dbo.Cliente(TipoClienteID,NIT,Nombre,Activo) VALUES(@TipoCliente,@NIT1,N'PRUEBA temporal Equipos A',1);
 SET @Cliente1=CONVERT(int,SCOPE_IDENTITY());
 INSERT dbo.Cliente(TipoClienteID,NIT,Nombre,Activo) VALUES(@TipoCliente,@NIT2,N'PRUEBA temporal Equipos B',0);
 SET @Cliente2=CONVERT(int,SCOPE_IDENTITY());
 INSERT dbo.Equipo(ClienteID,ModeloEquipoID,NumeroSerie,Descripcion,Activo)
 VALUES(@Cliente1,@Modelo1,@Serie1,N'PRUEBA temporal Equipos A',1);
 SET @Equipo1=CONVERT(int,SCOPE_IDENTITY());
 INSERT dbo.Equipo(ClienteID,ModeloEquipoID,NumeroSerie,Descripcion,Activo)
 VALUES(@Cliente1,@Modelo1,@Serie2,N'PRUEBA temporal Equipos B',1);
 SET @Equipo2=CONVERT(int,SCOPE_IDENTITY());
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
DECLARE @Casos TABLE(ID int IDENTITY(1,1),Caso nvarchar(200),Sentencia nvarchar(max),ErrorEsperado int);
INSERT @Casos(Caso,Sentencia,ErrorEsperado) VALUES
(N'Registrar devuelve ID y conserva Unicode',N'DECLARE @R TABLE (EquipoID int, ClienteID int, Cliente nvarchar(150), ClienteActivo bit,
ModeloEquipoID int, Modelo nvarchar(80), MarcaID int, Marca nvarchar(60), TipoEquipoID tinyint,
TipoEquipo nvarchar(50), NumeroSerie varchar(80), Descripcion nvarchar(500), Activo bit, TieneOrdenes bit);
INSERT @R EXEC dbo.spRegistrarEquipo @Cliente1, @Modelo1, @NuevaSerie, N''Revisión ñ 漢字'', 1;
IF NOT EXISTS(SELECT 1 FROM @R WHERE EquipoID>0 AND Descripcion=N''Revisión ñ 漢字'' AND TieneOrdenes=0) THROW 51980,N''Respuesta de registro incorrecta.'',1;',0),
(N'Actualizar conserva la misma serie',N'DECLARE @R TABLE (EquipoID int, ClienteID int, Cliente nvarchar(150), ClienteActivo bit,
ModeloEquipoID int, Modelo nvarchar(80), MarcaID int, Marca nvarchar(60), TipoEquipoID tinyint,
TipoEquipo nvarchar(50), NumeroSerie varchar(80), Descripcion nvarchar(500), Activo bit, TieneOrdenes bit);
INSERT @R EXEC dbo.spActualizarEquipo @Equipo1, @Cliente1, @Modelo1, @Serie1, N''Descripción modificada'', 1;
IF NOT EXISTS(SELECT 1 FROM @R WHERE EquipoID=@Equipo1 AND NumeroSerie=@Serie1 AND Descripcion=N''Descripción modificada'') THROW 51980,N''Actualización incorrecta.'',1;',0),
(N'Desactivar conserva el registro',N'EXEC dbo.spActualizarEquipo @Equipo1,@Cliente1,@Modelo1,@Serie1,N''Equipo inactivo'',0; IF NOT EXISTS(SELECT 1 FROM dbo.Equipo WHERE EquipoID=@Equipo1 AND Activo=0) THROW 51980,N''No conservó el registro.'',1;',0),
(N'Serie duplicada al crear',N'EXEC dbo.spRegistrarEquipo @Cliente1,@Modelo1,@Serie1,N''Duplicado'',1;',51303),
(N'Serie de otro equipo al actualizar',N'EXEC dbo.spActualizarEquipo @Equipo1,@Cliente1,@Modelo1,@Serie2,N''Duplicado'',1;',51303),
(N'Cliente inexistente',N'EXEC dbo.spRegistrarEquipo -1,@Modelo1,@NuevaSerie,N''Cliente inválido'',1;',51301),
(N'Modelo inexistente',N'EXEC dbo.spRegistrarEquipo @Cliente1,-1,@NuevaSerie,N''Modelo inválido'',1;',51301),
(N'Equipo activo requiere cliente activo',N'EXEC dbo.spRegistrarEquipo @Cliente2,@Modelo1,@NuevaSerie,N''Cliente inactivo'',1;',51301),
(N'Serie obligatoria en la BD',N'EXEC dbo.spRegistrarEquipo @Cliente1,@Modelo1,N''   '',N''Prueba'',1;',51300),
(N'Descripción obligatoria en la BD',N'EXEC dbo.spRegistrarEquipo @Cliente1,@Modelo1,@NuevaSerie,N''   '',1;',51300),
(N'Serie larga rechazada sin truncar',N'DECLARE @Texto nvarchar(max)=REPLICATE(N''X'',81); EXEC dbo.spRegistrarEquipo @Cliente1,@Modelo1,@Texto,N''Prueba'',1;',51300),
(N'Descripción larga rechazada sin truncar',N'DECLARE @Texto nvarchar(max)=REPLICATE(N''X'',501); EXEC dbo.spRegistrarEquipo @Cliente1,@Modelo1,@NuevaSerie,@Texto,1;',51300),
(N'Activo obligatorio en la BD',N'EXEC dbo.spRegistrarEquipo @Cliente1,@Modelo1,@NuevaSerie,N''Prueba'',NULL;',51300),
(N'Consultar equipo inexistente',N'EXEC dbo.spConsultarEquipo 2147483647;',51302),
(N'Consultar ID no positivo',N'EXEC dbo.spConsultarEquipo 0;',51300),
(N'Actualizar equipo inexistente',N'EXEC dbo.spActualizarEquipo 2147483647,@Cliente1,@Modelo1,@NuevaSerie,N''Prueba'',1;',51302),
(N'Filtro de cliente y serie',N'DECLARE @R TABLE (EquipoID int, ClienteID int, Cliente nvarchar(150), ClienteActivo bit,
ModeloEquipoID int, Modelo nvarchar(80), MarcaID int, Marca nvarchar(60), TipoEquipoID tinyint,
TipoEquipo nvarchar(50), NumeroSerie varchar(80), Descripcion nvarchar(500), Activo bit, TieneOrdenes bit);
INSERT @R EXEC dbo.spListarEquipos @ClienteID=@Cliente1,@Serie=@Serie1,@Activo=1; IF (SELECT COUNT(*) FROM @R)<>1 OR NOT EXISTS(SELECT 1 FROM @R WHERE EquipoID=@Equipo1) THROW 51980,N''Filtro incorrecto.'',1;',0),
(N'Serie con comodines se busca como texto literal',N'DECLARE @R TABLE (EquipoID int, ClienteID int, Cliente nvarchar(150), ClienteActivo bit,
ModeloEquipoID int, Modelo nvarchar(80), MarcaID int, Marca nvarchar(60), TipoEquipoID tinyint,
TipoEquipo nvarchar(50), NumeroSerie varchar(80), Descripcion nvarchar(500), Activo bit, TieneOrdenes bit);
INSERT @R EXEC dbo.spListarEquipos @ClienteID=@Cliente1,@Serie=N''%_'',@Activo=NULL; IF EXISTS(SELECT 1 FROM @R) THROW 51980,N''Interpretó comodines como patrón.'',1;',0),
(N'Historial sin órdenes devuelve cero filas',N'DECLARE @H TABLE(EquipoID int, NumeroSerie varchar(80), ClienteID int, Cliente nvarchar(150), OrdenID int, NumeroOrden varchar(30), FechaIngreso datetime2, EstadoCodigo varchar(30), FechaDiagnostico datetime2, Diagnostico nvarchar(2000), ReparacionID int, FechaInicio datetime2, FechaFin datetime2, DescripcionTrabajo nvarchar(2000), FacturaID int, Total decimal(18,2), Saldo decimal(18,2), FechaEntrega datetime2); INSERT @H EXEC dbo.spHistorialEquipo @Equipo1; IF EXISTS(SELECT 1 FROM @H) THROW 51980,N''Historial vacío incorrecto.'',1;',0),
(N'Historial de equipo inexistente',N'EXEC dbo.spHistorialEquipo 2147483647;',51302),
(N'Equipo con orden indica historial',N'DECLARE @Orden int; EXEC dbo.spCrearOrden @NumeroOrden=@NumeroOrden, @EquipoID=@Equipo1, @UsuarioID=@Recepcion, @Problema=N''Prueba reversible'', @OrdenID=@Orden OUTPUT;
DECLARE @R TABLE (EquipoID int, ClienteID int, Cliente nvarchar(150), ClienteActivo bit,
ModeloEquipoID int, Modelo nvarchar(80), MarcaID int, Marca nvarchar(60), TipoEquipoID tinyint,
TipoEquipo nvarchar(50), NumeroSerie varchar(80), Descripcion nvarchar(500), Activo bit, TieneOrdenes bit);
INSERT @R EXEC dbo.spConsultarEquipo @Equipo1; IF NOT EXISTS(SELECT 1 FROM @R WHERE TieneOrdenes=1) THROW 51980,N''No indicó historial.'',1;',0),
(N'No cambiar serie de equipo con órdenes',N'DECLARE @Orden int; EXEC dbo.spCrearOrden @NumeroOrden=@NumeroOrden, @EquipoID=@Equipo1, @UsuarioID=@Recepcion, @Problema=N''Prueba reversible'', @OrdenID=@Orden OUTPUT;
EXEC dbo.spActualizarEquipo @Equipo1,@Cliente1,@Modelo1,@NuevaSerie,N''Prueba'',1;',51304),
(N'No cambiar propietario de equipo con órdenes',N'DECLARE @Orden int; EXEC dbo.spCrearOrden @NumeroOrden=@NumeroOrden, @EquipoID=@Equipo1, @UsuarioID=@Recepcion, @Problema=N''Prueba reversible'', @OrdenID=@Orden OUTPUT;
EXEC dbo.spActualizarEquipo @Equipo1,@Cliente2,@Modelo1,@Serie1,N''Prueba'',0;',51304),
(N'No cambiar modelo de equipo con órdenes',N'DECLARE @Orden int; EXEC dbo.spCrearOrden @NumeroOrden=@NumeroOrden, @EquipoID=@Equipo1, @UsuarioID=@Recepcion, @Problema=N''Prueba reversible'', @OrdenID=@Orden OUTPUT;
EXEC dbo.spActualizarEquipo @Equipo1,@Cliente1,@Modelo2,@Serie1,N''Prueba'',1;',51304),
(N'Con historial sí permite descripción y estado',N'DECLARE @Orden int; EXEC dbo.spCrearOrden @NumeroOrden=@NumeroOrden, @EquipoID=@Equipo1, @UsuarioID=@Recepcion, @Problema=N''Prueba reversible'', @OrdenID=@Orden OUTPUT;
EXEC dbo.spActualizarEquipo @Equipo1,@Cliente1,@Modelo1,@Serie1,N''Descripción de prueba'',0; IF NOT EXISTS(SELECT 1 FROM dbo.Equipo WHERE EquipoID=@Equipo1 AND Activo=0 AND Descripcion=N''Descripción de prueba'') THROW 51980,N''Actualización permitida rechazada.'',1;',0),
(N'Modelos filtran por marca y tipo',N'DECLARE @M TABLE(ModeloEquipoID int, Nombre nvarchar(80), MarcaID int, Marca nvarchar(60), TipoEquipoID tinyint, TipoEquipo nvarchar(50)); INSERT @M EXEC dbo.spListarModelosEquipo @Marca,@Tipo; IF NOT EXISTS(SELECT 1 FROM @M) OR EXISTS(SELECT 1 FROM @M WHERE MarcaID<>@Marca OR TipoEquipoID<>@Tipo) THROW 51980,N''Filtro de modelos incorrecto.'',1;',0),
(N'Filtros no positivos rechazados',N'EXEC dbo.spListarModelosEquipo @MarcaID=0;',51300),
(N'Catálogos reales no vacíos',N'DECLARE @T TABLE(TipoEquipoID tinyint,Nombre nvarchar(50)); DECLARE @M TABLE(MarcaID int,Nombre nvarchar(60)); INSERT @T EXEC dbo.spListarTiposEquipo; INSERT @M EXEC dbo.spListarMarcas; IF NOT EXISTS(SELECT 1 FROM @T) OR NOT EXISTS(SELECT 1 FROM @M) THROW 51980,N''Catálogos vacíos.'',1;',0);

DECLARE @Resultados TABLE(Caso nvarchar(200),Resultado varchar(4),Detalle nvarchar(2000));
DECLARE @i int=1,@Caso nvarchar(200),@SQL nvarchar(max),@Esperado int;
WHILE @i<=(SELECT COUNT(*) FROM @Casos)
BEGIN
 SELECT @Caso=Caso,@SQL=Sentencia,@Esperado=ErrorEsperado FROM @Casos WHERE ID=@i;
 BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sys.sp_executesql @SQL,
   N'@Cliente1 int,@Cliente2 int,@Modelo1 int,@Modelo2 int,@Equipo1 int,@Equipo2 int,@Serie1 nvarchar(80),@Serie2 nvarchar(80),@NuevaSerie nvarchar(80),@Recepcion int,@NumeroOrden varchar(30),@Marca int,@Tipo int',
   @Cliente1,@Cliente2,@Modelo1,@Modelo2,@Equipo1,@Equipo2,@Serie1,@Serie2,@NuevaSerie,@Recepcion,@NumeroOrden,@Marca,@Tipo;
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  INSERT @Resultados VALUES(@Caso,CASE WHEN @Esperado=0 THEN 'PASS' ELSE 'FAIL' END,
   CASE WHEN @Esperado=0 THEN NULL ELSE N'No rechazó la operación inválida.' END);
 END TRY
 BEGIN CATCH
  DECLARE @Error int=ERROR_NUMBER(),@Mensaje nvarchar(2000)=ERROR_MESSAGE();
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  INSERT @Resultados VALUES(@Caso,CASE WHEN @Error=@Esperado THEN 'PASS' ELSE 'FAIL' END,
   CASE WHEN @Error=@Esperado THEN NULL ELSE CONCAT(N'Error ',@Error,N': ',@Mensaje) END);
 END CATCH;
 SET @i+=1;
END;
-- Limpieza atómica de los cuatro registros de preparación, siempre por sus IDs propios.
BEGIN TRY
 BEGIN TRANSACTION;
 DELETE FROM dbo.Equipo WHERE EquipoID IN (@Equipo1,@Equipo2);
 DELETE FROM dbo.Cliente WHERE ClienteID IN (@Cliente1,@Cliente2);
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 SELECT * FROM @Resultados;
 THROW;
END CATCH;
INSERT @Resultados VALUES(N'Errores y pruebas sin registros adicionales',
 CASE WHEN EXISTS(SELECT 1 FROM dbo.Equipo WHERE NumeroSerie IN (@Serie1,@Serie2,@NuevaSerie))
        OR EXISTS(SELECT 1 FROM dbo.Cliente WHERE NIT IN (@NIT1,@NIT2))
        OR EXISTS(SELECT 1 FROM dbo.OrdenServicio WHERE NumeroOrden=@NumeroOrden)
      THEN 'FAIL' ELSE 'PASS' END,NULL);
SELECT Caso,Resultado,Detalle FROM @Resultados;
IF EXISTS(SELECT 1 FROM @Resultados WHERE Resultado='FAIL')
 THROW 51983,N'Falló una prueba de Equipos; revisá el detalle de los resultados.',1;
GO
