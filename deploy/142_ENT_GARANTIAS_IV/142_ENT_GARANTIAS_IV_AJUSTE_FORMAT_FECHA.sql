-- ============================================================
-- AJUSTE  142_ENT_GARANTIAS_IV — FORMAT FECHAINFO dd/MM/yyyy en SP ION
-- ============================================================

-- ============================================================
-- SECTION 01 | SP ION — cambiar FORMAT FECHAINFO a dd/MM/yyyy
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[142_ENT_GARANTIAS_IV]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FECHA), MONTH(@FECHA), 1);
    DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);

    SELECT
        [OFICINA]                           AS [OFICINA],
        [CONT]                              AS [CONT],
        [NETEO_POS]                         AS [NETEO_POS],
        [TIP_CONTRAT]                       AS [TIP_CONTRAT],
        [EXP_POT]                           AS [EXP_POT],
        [RSG_MAX]                           AS [RSG_MAX],
        FORMAT([FECHAINFO], 'dd/MM/yyyy')   AS [FECHAINFO]
    FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
    WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin;
END;
GO
