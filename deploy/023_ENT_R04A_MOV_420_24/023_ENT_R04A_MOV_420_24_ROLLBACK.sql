-- ============================================================
-- ROLLBACK  023_ENT_R04A_MOV_420_24
-- Revierte lo aplicado por:
--   023_R04A_MOV_420_24_LMDA_SUSTITUIR.sql
--   023_ENT_R04A_MOV_420_24_SILVER_AJUSTE.sql
--   023_ENT_R04A_MOV_420_24_AJUSTE.sql
-- Acciones:
--   * SP SILVER -> stub original (self-select, mensual)
--   * SP ION    -> passthrough original (6 columnas, sin zero-padding)
--   * SILVER: IMPORTE/MONEDA -> NULL ; TIPO_MOV_420_424 -> numeric(16,2)
--   * INDICE_REPORTES: eliminar 23
--   * BRONZE: dropear la tabla LMDA.R04A_MOV_420_24 (nueva estructura)
-- ============================================================

-- ------------------------------------------------------------
-- SP SILVER — restaurar stub original (self-select)
-- ------------------------------------------------------------
USE [SILVER]
GO
CREATE OR ALTER PROCEDURE [dbo].[023_ENT_R04A_MOV_420_24]
    @CorreoNotificacion NVARCHAR(255) = NULL,
    @PerfilCorreo       NVARCHAR(255) = NULL,
    @ProgramadorJob     NVARCHAR(128) = NULL,
    @FechaSistema       DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE @FechaIni DATE = datefromparts(year(@FechaSistema), month(@FechaSistema), 1);
    DECLARE @FechaFin DATE = Dateadd(month, 1, @FechaIni);
    DECLARE @FilasEliminadas INT = 0;

    IF EXISTS (SELECT ID FROM [SILVER].[RR].[023_ENT_R04A_MOV_420_24] WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin)
        DELETE FROM [SILVER].[RR].[023_ENT_R04A_MOV_420_24] WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;

    INSERT INTO [RR].[023_ENT_R04A_MOV_420_24] ([CUENTA_CREDITO],[ETAPA_DETERIORO],[TIPO_MOV_420_424],[IMPORTE],[MONEDA],[FECHA_INFO])
    SELECT [CUENTA_CREDITO],[ETAPA_DETERIORO],[TIPO_MOV_420_424],[IMPORTE],[MONEDA],@FechaIni
    FROM [SILVER].[RR].[023_ENT_R04A_MOV_420_24]
    WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;

    PRINT 'SP stub original restaurado.';
END;
GO

-- ------------------------------------------------------------
-- SP ION — restaurar passthrough original
-- ------------------------------------------------------------
USE [ION]
GO
CREATE OR ALTER PROCEDURE [dbo].[023_ENT_R04A_MOV_420_24]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE @FechaIni date = datefromparts(year(@Fecha), month(@Fecha), 1);
    DECLARE @FechaFin date = Dateadd(month, 1, @FechaIni);
    SELECT [CUENTA_CREDITO],[ETAPA_DETERIORO],[TIPO_MOV_420_424],[IMPORTE],[MONEDA],[FECHA_INFO]
    FROM [SILVER].[RR].[023_ENT_R04A_MOV_420_24]
    WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;
END;
GO

-- ------------------------------------------------------------
-- SILVER — revertir cambios de columnas
-- ------------------------------------------------------------
USE [SILVER]
GO
ALTER TABLE [RR].[023_ENT_R04A_MOV_420_24] ALTER COLUMN [TIPO_MOV_420_424] numeric(16,2) NOT NULL;
GO
ALTER TABLE [RR].[023_ENT_R04A_MOV_420_24] ALTER COLUMN [IMPORTE] numeric(16,2) NULL;
GO
ALTER TABLE [RR].[023_ENT_R04A_MOV_420_24] ALTER COLUMN [MONEDA] varchar(3) NULL;
GO

-- ------------------------------------------------------------
-- INDICE_REPORTES — quitar registro 23
-- ------------------------------------------------------------
USE [ION]
GO
DELETE FROM [dbo].[INDICE_REPORTES] WHERE [numero] = 23;
GO

-- ------------------------------------------------------------
-- BRONZE — dropear la tabla LMDA (nueva estructura desagregada)
-- ------------------------------------------------------------
USE [BRONZE]
GO
IF OBJECT_ID('[LMDA].[R04A_MOV_420_24]', 'U') IS NOT NULL
    DROP TABLE [LMDA].[R04A_MOV_420_24];
GO
