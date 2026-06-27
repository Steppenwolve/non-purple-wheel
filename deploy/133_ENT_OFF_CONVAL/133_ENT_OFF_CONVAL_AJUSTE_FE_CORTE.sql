-- ============================================================
-- AJUSTE  133_ENT_OFF_CONVAL — DROP FE_CORTE en SILVER
-- Hallazgo: FE_CORTE NOT NULL sin DEFAULT no existe en el layout
-- V11 (17 campos). El SP no la alimenta y falla en produccion.
-- ============================================================
USE [SILVER]
GO

ALTER TABLE [RR].[133_ENT_OFF_CONVAL]
    DROP COLUMN [FE_CORTE];
GO

-- Verificar
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'RR'
  AND TABLE_NAME   = '133_ENT_OFF_CONVAL'
  AND COLUMN_NAME  = 'FE_CORTE';
-- Debe retornar 0 filas
GO
