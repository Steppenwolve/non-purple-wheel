/* ============================================================================
   212_SECCION_5_LINEAS_CRE_ROLLBACK.sql
   Fin : Revertir el despliegue de 212_SECCION_5_LINEAS_CRE (LID S5), dejando el
         entorno como antes de la creacion.
   Orden de reversa (dependencias):
     1. ION.dbo.INDICE_REPORTES  -> eliminar registro 212
     2. ION SP                   -> DROP
     3. SILVER SP                -> DROP
     4. SILVER RR tabla          -> DROP
   NO se elimina dbo.LogSilverDiario (compartido).
   IMPORTANTE: el DROP de la tabla elimina los datos cargados; no recuperable
   sin respaldo previo.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   01 - ION.dbo.INDICE_REPORTES : eliminar registro 212
   ---------------------------------------------------------------------------- */
USE [ION];
GO
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 212)
BEGIN
    DELETE FROM dbo.INDICE_REPORTES WHERE numero = 212;
    PRINT '>> Eliminado registro 212 de ION.dbo.INDICE_REPORTES.';
END
ELSE
    PRINT '>> Registro 212 no existe en ION.dbo.INDICE_REPORTES. Sin cambios.';
GO

/* ----------------------------------------------------------------------------
   02 - ION SP : DROP
   ---------------------------------------------------------------------------- */
USE [ION];
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = '212_SECCION_5_LINEAS_CRE' AND schema_id = SCHEMA_ID('dbo') AND type = 'P')
BEGIN
    DROP PROCEDURE [dbo].[212_SECCION_5_LINEAS_CRE];
    PRINT '>> Eliminado ION.dbo.[212_SECCION_5_LINEAS_CRE].';
END
ELSE
    PRINT '>> ION.dbo.[212_SECCION_5_LINEAS_CRE] no existe. Sin cambios.';
GO

/* ----------------------------------------------------------------------------
   03 - SILVER SP : DROP
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = '212_SECCION_5_LINEAS_CRE' AND schema_id = SCHEMA_ID('dbo') AND type = 'P')
BEGIN
    DROP PROCEDURE [dbo].[212_SECCION_5_LINEAS_CRE];
    PRINT '>> Eliminado SILVER.dbo.[212_SECCION_5_LINEAS_CRE].';
END
ELSE
    PRINT '>> SILVER.dbo.[212_SECCION_5_LINEAS_CRE] no existe. Sin cambios.';
GO

/* ----------------------------------------------------------------------------
   04 - SILVER RR tabla : DROP
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = '212_SECCION_5_LINEAS_CRE' AND schema_id = SCHEMA_ID('RR') AND type = 'U')
BEGIN
    DROP TABLE [RR].[212_SECCION_5_LINEAS_CRE];
    PRINT '>> Eliminada SILVER.[RR].[212_SECCION_5_LINEAS_CRE].';
END
ELSE
    PRINT '>> SILVER.[RR].[212_SECCION_5_LINEAS_CRE] no existe. Sin cambios.';
GO

PRINT '>> Rollback 212_SECCION_5_LINEAS_CRE completado.';
GO
