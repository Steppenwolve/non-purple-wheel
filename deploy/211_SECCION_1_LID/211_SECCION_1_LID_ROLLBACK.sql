-- ============================================================
-- ROLLBACK  211_SECCION_1_LID
-- Revierte todo lo creado por 211_SECCION_1_LID_AJUSTE.sql
-- ============================================================

-- SP ION
USE [ION]
GO
IF OBJECT_ID('[dbo].[211_SECCION_1_LID]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[211_SECCION_1_LID];
GO
DELETE FROM [dbo].[INDICE_REPORTES] WHERE [numero] = 211;
GO

-- SP SILVER
USE [SILVER]
GO
IF OBJECT_ID('[dbo].[211_SECCION_1_LID]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[211_SECCION_1_LID];
GO

-- Tabla SILVER
IF OBJECT_ID('[RR].[211_SECCION_1_LID]', 'U') IS NOT NULL
    DROP TABLE [RR].[211_SECCION_1_LID];
GO

-- Tabla BRONZE
USE [BRONZE]
GO
IF OBJECT_ID('[LMDA].[SECCION_1_LID]', 'U') IS NOT NULL
    DROP TABLE [LMDA].[SECCION_1_LID];
GO
