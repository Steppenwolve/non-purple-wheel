-- ============================================================
-- AJUSTE  133_ENT_OFF_CONVAL — DROP columnas fuera de layout
-- Hallazgo: ACT_OPE_VAL y PAS_OPE_VAL no existen en Layout
-- OFF_FX_V11_OFF_CONVAL (17 campos). El SP no las alimenta
-- y el INSERT falla por NOT NULL sin valor.
-- ============================================================
USE [SILVER]
GO

ALTER TABLE [RR].[133_ENT_OFF_CONVAL]
    DROP COLUMN [ACT_OPE_VAL],
                [PAS_OPE_VAL];
GO

-- Verificar: debe retornar 0 filas
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'RR'
  AND TABLE_NAME   = '133_ENT_OFF_CONVAL'
  AND COLUMN_NAME IN ('ACT_OPE_VAL', 'PAS_OPE_VAL');
GO
