-- ============================================================
-- ROLLBACK  209_LID_CORRESPONSALES
-- ============================================================

-- ============================================================
-- SECTION R01 | Eliminar SP ION
-- ============================================================
USE [ION]
GO

IF OBJECT_ID('dbo.[209_LID_CORRESPONSALES]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[209_LID_CORRESPONSALES];
GO

-- ============================================================
-- SECTION R02 | Eliminar SP SILVER
-- ============================================================
USE [SILVER]
GO

IF OBJECT_ID('dbo.[209_LID_CORRESPONSALES]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[209_LID_CORRESPONSALES];
GO

-- ============================================================
-- SECTION R03 | Eliminar tabla SILVER.RR.209_LID_CORRESPONSALES
-- ============================================================
USE [SILVER]
GO

IF OBJECT_ID('RR.[209_LID_CORRESPONSALES]', 'U') IS NOT NULL
    DROP TABLE [RR].[209_LID_CORRESPONSALES];
GO

-- ============================================================
-- SECTION R04 | Eliminar tabla BRONZE.LMDA.LID_CORRESPONSALES
-- ============================================================
USE [BRONZE]
GO

IF OBJECT_ID('LMDA.[LID_CORRESPONSALES]', 'U') IS NOT NULL
    DROP TABLE [LMDA].[LID_CORRESPONSALES];
GO

-- ============================================================
-- SECTION R05 | INDICE_REPORTES — eliminar registro 209
-- ============================================================
USE [ION]
GO

DELETE FROM dbo.INDICE_REPORTES WHERE numero = 209;
PRINT 'INDICE_REPORTES: registro 209 eliminado.';
GO
