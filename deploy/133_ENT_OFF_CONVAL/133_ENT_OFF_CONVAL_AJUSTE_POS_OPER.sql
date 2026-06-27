-- ============================================================
-- AJUSTE  133_ENT_OFF_CONVAL
-- Hallazgo: POS_OPER varchar(1) en SILVER — datos fuente son 3 chars
-- Fix: ampliar a varchar(3) para alinear con BRONZE.LMDA.OFF_CONVAL
-- ============================================================
USE [SILVER]
GO

ALTER TABLE [RR].[133_ENT_OFF_CONVAL]
    ALTER COLUMN [POS_OPER] varchar(3) NOT NULL;
GO

-- Verificar
SELECT COLUMN_NAME, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'RR'
  AND TABLE_NAME   = '133_ENT_OFF_CONVAL'
  AND COLUMN_NAME  = 'POS_OPER';
GO
