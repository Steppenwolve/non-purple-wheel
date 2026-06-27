-- ============================================================
-- AJUSTE  093_ENT_CF — FORMAT fechas en SP ION
-- Hallazgo: FECHA_INICIO y FECHA_VENC se exponían sin FORMAT
-- ============================================================

-- ============================================================
-- SECTION 01 | SP ION — agregar FORMAT('yyyy/MM/dd') en fechas
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[093_ENT_CF]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE, @FechaFin DATE;
    SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FECHA) + 5) % 7, @FECHA);
    SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

    SELECT
        [TIPOOPERACION]                             AS [TIPOOPERACION],
        [TIPOFONDEO]                                AS [TIPOFONDEO],
        FORMAT([FECHA_INICIO], 'yyyy/MM/dd')        AS [FECHA_INICIO],
        FORMAT([FECHA_VENC],   'yyyy/MM/dd')        AS [FECHA_VENC],
        [MONTO_OPER]                                AS [MONTO_OPER],
        [MONEDA]                                    AS [MONEDA],
        [CVE_ACREEDOR]                              AS [CVE_ACREEDOR],
        [TIP_REL_ACREED]                            AS [TIP_REL_ACREED],
        [CVE_OPERACION]                             AS [CVE_OPERACION]
    FROM [SILVER].[RR].[093_ENT_CF]
    WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;
END;
GO
