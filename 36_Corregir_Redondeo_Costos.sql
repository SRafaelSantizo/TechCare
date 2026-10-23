-- Corrección puntual del redondeo del promedio móvil a seis decimales.
-- Ejecutar después de 30 y 33, con el backend detenido.
-- Sólo actualiza una función; conserva stock, costos guardados e historia.
USE [TechCare];
GO
SET NOCOUNT ON; SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 52290,N'Ejecutá sin una transacción abierta.',1;
IF OBJECT_ID(N'dbo.fnPromedioEntrada',N'FN') IS NULL
    THROW 52290,N'Ejecutá primero 30_Compras_Procedimientos.sql.',1;
DECLARE @Antes decimal(18,6)=dbo.fnPromedioEntrada(8,12.25,6,20);
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC sys.sp_executesql N'CREATE OR ALTER FUNCTION dbo.fnPromedioEntrada
(@Stock bigint,@Costo decimal(18,6),@Cantidad int,@CostoEntrada decimal(12,2))
RETURNS decimal(18,6) AS
BEGIN
    -- Se opera en millonésimas enteras para redondear una sola vez al final.
    -- bigint (19 dígitos) * costo en millonésimas (18) cabe en decimal(38,0).
    DECLARE @CostoMicro decimal(18,0)=CONVERT(decimal(18,0),@Costo*CONVERT(decimal(7,0),1000000));
    DECLARE @EntradaMicro decimal(18,0)=CONVERT(decimal(18,0),@CostoEntrada*CONVERT(decimal(7,0),1000000));
    DECLARE @ValorMicro decimal(38,0)=CONVERT(decimal(19,0),@Stock)*@CostoMicro
                                       +CONVERT(decimal(19,0),@Cantidad)*@EntradaMicro;
    DECLARE @Unidades decimal(20,0)=CONVERT(decimal(20,0),@Stock)+@Cantidad;
    DECLARE @Resto decimal(20,0)=@ValorMicro % NULLIF(@Unidades,0);
    -- Se retira el resto antes de dividir. La base tiene seis decimales
    -- exactos; decimal(37,6) deja espacio para la escala de la división.
    DECLARE @ValorBase decimal(37,6)=CONVERT(decimal(37,6),(@ValorMicro-@Resto)*CONVERT(decimal(7,6),0.000001));
    DECLARE @Promedio decimal(18,6)=CONVERT(decimal(18,6),@ValorBase/NULLIF(@Unidades,0));
    IF @Resto*CONVERT(decimal(1,0),2)>=@Unidades SET @Promedio=@Promedio+CONVERT(decimal(7,6),0.000001);
    RETURN @Promedio;
END;';
    DECLARE @Casos TABLE(ID int,Stock bigint,Costo decimal(18,6),Cantidad int,CostoEntrada decimal(12,2),Esperado decimal(18,6));
    INSERT @Casos VALUES
      (1,8,12.25,6,20,15.571429),
      (2,2,1,1,2,1.333333),
      (3,1,0.000001,1,0,0.000001),
      (4,1,0.000001,2,0,0.000000),
      (5,10,12.25,10,20,16.125000),
      (6,0,0,2147483647,9999999999.99,9999999999.990000),
      (7,10,12.25,10,9999999999.99,5000000006.120000),
      (8,9223372036854775807,999999999999.999999,2147483647,0,999999999767.169356);
    IF EXISTS(SELECT 1 FROM @Casos WHERE dbo.fnPromedioEntrada(Stock,Costo,Cantidad,CostoEntrada) IS NULL
                  OR dbo.fnPromedioEntrada(Stock,Costo,Cantidad,CostoEntrada)<>Esperado)
        THROW 52293,N'La comprobación del redondeo falló; se revirtió la actualización de la función.',1;
    COMMIT TRANSACTION;
    SELECT @Antes AS PromedioAntes,dbo.fnPromedioEntrada(8,12.25,6,20) AS PromedioCorregido,
           CONVERT(decimal(38,6),CONVERT(decimal(19,0),14)*dbo.fnPromedioEntrada(8,12.25,6,20)) AS ValorExistencias;
    SELECT ID,Esperado,dbo.fnPromedioEntrada(Stock,Costo,Cantidad,CostoEntrada) AS Obtenido,'PASS' AS Resultado
    FROM @Casos ORDER BY ID;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
