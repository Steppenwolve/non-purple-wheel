-- ============================================================
-- AJUSTE SILVER  RR.023_ENT_R04A_MOV_420_24
-- Configurar la tabla conforme al layout Credito_IFRS9_R04A_MOV_420_24.xlsx (Opcion A):
--   IMPORTE y MONEDA son OBLIGATORIOS en el layout -> pasar a NOT NULL.
--   Se conservan las columnas de control (ID, FECHA_EXTRACCION) y el orden fisico actual.
-- (La tabla esta vacia, el ALTER es directo.)
-- ============================================================
USE [SILVER]
GO

ALTER TABLE [RR].[023_ENT_R04A_MOV_420_24] ALTER COLUMN [IMPORTE] numeric(16,2) NOT NULL;
GO
PRINT 'IMPORTE -> NOT NULL';
GO

ALTER TABLE [RR].[023_ENT_R04A_MOV_420_24] ALTER COLUMN [MONEDA] varchar(3) NOT NULL;
GO
PRINT 'MONEDA -> NOT NULL';
GO
