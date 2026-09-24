-- ============================================================
-- FIX PROD  SILVER.RR.126_ENT_ACLME_CONCEPTOSFIJOS
-- Error: "Arithmetic overflow error converting numeric to data type numeric"
-- Causa: IMPORTE numeric(15,8) = solo 7 digitos enteros; el SUM(MONTO) por
--        concepto en prod llega a 10 digitos (ej. concepto 9890 = 1,055,022,006).
-- Fix  : ampliar IMPORTE (y RESERVAS) a numeric(23,8) = 15 enteros + 8 decimales.
--        (Interpretacion del layout "15,8" como enteros,decimales.)
-- Cambio de metadata (aumenta precision, misma escala) -> online, conserva datos.
-- ============================================================
USE [SILVER]
GO
ALTER TABLE [RR].[126_ENT_ACLME_CONCEPTOSFIJOS] ALTER COLUMN [IMPORTE]  numeric(23,8) NOT NULL;
GO
ALTER TABLE [RR].[126_ENT_ACLME_CONCEPTOSFIJOS] ALTER COLUMN [RESERVAS] numeric(23,8) NULL;
GO
PRINT 'IMPORTE / RESERVAS -> numeric(23,8)';
GO
-- Despues, reejecutar:
--   EXEC [SILVER].[dbo].[126_ENT_ACLME_CONCEPTOSFIJOS] @FechaSistema = '2025-06-12';
