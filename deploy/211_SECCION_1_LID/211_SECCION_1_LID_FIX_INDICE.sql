-- ============================================================
-- FIX INDICE_REPORTES  211_SECCION_1_LID
-- Corrige nombre, activo y nombre_archivo
-- ============================================================
USE [ION]
GO

UPDATE [dbo].[INDICE_REPORTES]
SET [nombre]         = 'SECCION_1_LID',
    [activo]         = 0,
    [nombre_archivo] = NULL
WHERE [numero] = 211;
GO

SELECT [numero], [nombre], [frecuencia], [activo], [nombre_archivo]
FROM [dbo].[INDICE_REPORTES]
WHERE [numero] = 211;
GO
