/* ============================================================================
   UPDATE_INDICE_212_213_nombre.sql
   Objeto : ION.dbo.INDICE_REPORTES
   Fin    : Actualizar SOLO la columna [nombre] de los reportes 212 y 213:
              - 212 : 'LID S5' -> 'SECCION_5_LINEAS_CRE'
              - 213 : 'LID SA' -> 'SECCION_A_CAT_LINEAS'
            El resto de columnas (frecuencia, activo, nombre_archivo) NO se tocan.
   Idempotente : si el nombre ya es el destino, no realiza cambios.
   ============================================================================ */
USE [ION];
GO
SET NOCOUNT ON;

/* --- Estado ANTES --- */
PRINT '--- INDICE_REPORTES (antes) ---';
SELECT numero, nombre, frecuencia, activo, nombre_archivo
FROM dbo.INDICE_REPORTES
WHERE numero IN (212, 213)
ORDER BY numero;

BEGIN TRANSACTION;

/* 212 -> SECCION_5_LINEAS_CRE */
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 212 AND nombre <> 'SECCION_5_LINEAS_CRE')
BEGIN
    UPDATE dbo.INDICE_REPORTES
        SET nombre = 'SECCION_5_LINEAS_CRE'
    WHERE numero = 212;
    PRINT '>> 212: nombre actualizado a SECCION_5_LINEAS_CRE (filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ').';
END
ELSE
    PRINT '>> 212: sin cambios (ya es SECCION_5_LINEAS_CRE o el registro no existe).';

/* 213 -> SECCION_A_CAT_LINEAS */
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 213 AND nombre <> 'SECCION_A_CAT_LINEAS')
BEGIN
    UPDATE dbo.INDICE_REPORTES
        SET nombre = 'SECCION_A_CAT_LINEAS'
    WHERE numero = 213;
    PRINT '>> 213: nombre actualizado a SECCION_A_CAT_LINEAS (filas: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ').';
END
ELSE
    PRINT '>> 213: sin cambios (ya es SECCION_A_CAT_LINEAS o el registro no existe).';

COMMIT TRANSACTION;

/* --- Estado DESPUES --- */
PRINT '--- INDICE_REPORTES (despues) ---';
SELECT numero, nombre, frecuencia, activo, nombre_archivo
FROM dbo.INDICE_REPORTES
WHERE numero IN (212, 213)
ORDER BY numero;
GO
