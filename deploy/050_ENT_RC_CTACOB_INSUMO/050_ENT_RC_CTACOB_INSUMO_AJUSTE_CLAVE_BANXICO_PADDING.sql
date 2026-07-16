-- ============================================================
-- AJUSTE  050_ENT_RC_CTACOB_INSUMO — Padding de ceros en CLAVE_BANXICO
-- Campo 5, layout exige 6 dígitos. CLAVE_BAN ya es varchar(6) en
-- BRONZE/SILVER; solo falta el relleno de ceros a la izquierda
-- al exponerlo en el SP ION.
-- ============================================================

USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[050_ENT_RC_CTACOB_INSUMO]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FECHA), MONTH(@FECHA), 1);
    DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);

    SELECT
        T.[CONTRATO]                              AS [CONTRATO],       -- ORDEN 1
        T.[NOMBRE]                                 AS [NOMBRE],         -- ORDEN 2
        T.[IMPORTE]                                AS [IMPORTE],        -- ORDEN 3
        T.[MONEDA]                                 AS [MONEDA],         -- ORDEN 4
        RIGHT('000000' + T.[CLAVE_BAN], 6)         AS [CLAVE_BANXICO]   -- ORDEN 5
    FROM [SILVER].[RR].[050_ENT_RC_CTACOB_INSUMO] T
    WHERE T.[FECHA_REPORTE] >= @FechaIni
      AND T.[FECHA_REPORTE] <  @FechaFin;
END;
GO
