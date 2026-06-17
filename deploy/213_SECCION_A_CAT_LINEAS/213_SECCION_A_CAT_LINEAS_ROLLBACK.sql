/* ============================================================================
   213_SECCION_A_CAT_LINEAS_ROLLBACK.sql
   Fin : Revertir el despliegue de 213_SECCION_A_CAT_LINEAS (LID SA), dejando el
         entorno como antes de la creacion.
   Orden de reversa (dependencias):
     1. ION.dbo.INDICE_REPORTES  -> eliminar registro 213
     2. ION SP                   -> DROP
     3. SILVER SP                -> DROP
     4. SILVER RR tabla          -> DROP
   NO se elimina dbo.LogSilverDiario (compartido).
   IMPORTANTE: el DROP de la tabla elimina los datos cargados; no recuperable
   sin respaldo previo.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   01 - ION.dbo.INDICE_REPORTES : eliminar registro 213
   ---------------------------------------------------------------------------- */
USE [ION];
GO
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 213)
BEGIN
    DELETE FROM dbo.INDICE_REPORTES WHERE numero = 213;
    PRINT '>> Eliminado registro 213 de ION.dbo.INDICE_REPORTES.';
END
ELSE
    PRINT '>> Registro 213 no existe en ION.dbo.INDICE_REPORTES. Sin cambios.';
GO

/* ----------------------------------------------------------------------------
   02 - ION SP : DROP
   ---------------------------------------------------------------------------- */
USE [ION];
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = '213_SECCION_A_CAT_LINEAS' AND schema_id = SCHEMA_ID('dbo') AND type = 'P')
BEGIN
    DROP PROCEDURE [dbo].[213_SECCION_A_CAT_LINEAS];
    PRINT '>> Eliminado ION.dbo.[213_SECCION_A_CAT_LINEAS].';
END
ELSE
    PRINT '>> ION.dbo.[213_SECCION_A_CAT_LINEAS] no existe. Sin cambios.';
GO

/* ----------------------------------------------------------------------------
   03 - SILVER SP : DROP
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = '213_SECCION_A_CAT_LINEAS' AND schema_id = SCHEMA_ID('dbo') AND type = 'P')
BEGIN
    DROP PROCEDURE [dbo].[213_SECCION_A_CAT_LINEAS];
    PRINT '>> Eliminado SILVER.dbo.[213_SECCION_A_CAT_LINEAS].';
END
ELSE
    PRINT '>> SILVER.dbo.[213_SECCION_A_CAT_LINEAS] no existe. Sin cambios.';
GO

/* ----------------------------------------------------------------------------
   04 - SILVER RR tabla : DROP
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = '213_SECCION_A_CAT_LINEAS' AND schema_id = SCHEMA_ID('RR') AND type = 'U')
BEGIN
    DROP TABLE [RR].[213_SECCION_A_CAT_LINEAS];
    PRINT '>> Eliminada SILVER.[RR].[213_SECCION_A_CAT_LINEAS].';
END
ELSE
    PRINT '>> SILVER.[RR].[213_SECCION_A_CAT_LINEAS] no existe. Sin cambios.';
GO

PRINT '>> Rollback 213_SECCION_A_CAT_LINEAS completado.';
GO
