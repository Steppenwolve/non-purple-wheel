-- ============================================================
-- AJUSTE  133_ENT_OFF_CONVAL — PAQ_EST numeric(2,0) → varchar(6)
-- Hallazgo: tipo incompatible con BRONZE.LMDA.OFF_CONVAL (varchar(6))
-- ============================================================
USE [SILVER]
GO

ALTER TABLE [RR].[133_ENT_OFF_CONVAL]
    ALTER COLUMN [PAQ_EST] varchar(6) NOT NULL;
GO

-- Verificar
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'RR'
  AND TABLE_NAME   = '133_ENT_OFF_CONVAL'
  AND COLUMN_NAME  = 'PAQ_EST';
GO
