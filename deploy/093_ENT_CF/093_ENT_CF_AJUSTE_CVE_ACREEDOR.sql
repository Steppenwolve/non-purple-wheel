-- ============================================================
-- AJUSTE  093_ENT_CF — CVE_ACREEDOR varchar(18) -> varchar(6)
-- Layout actualizado: longitud del campo 7 reducida a 6.
-- ============================================================

-- ============================================================
-- S01 | BRONZE
-- ============================================================
USE [BRONZE]
GO

ALTER TABLE [LMDA].[CF_I]
    ALTER COLUMN [CVE_ACREEDOR] varchar(6) NOT NULL;
PRINT '>> BRONZE: CVE_ACREEDOR ajustado a varchar(6).';
GO

-- ============================================================
-- S02 | SILVER
-- ============================================================
USE [SILVER]
GO

ALTER TABLE [RR].[093_ENT_CF]
    ALTER COLUMN [CVE_ACREEDOR] varchar(6) NOT NULL;
PRINT '>> SILVER: CVE_ACREEDOR ajustado a varchar(6).';
GO
