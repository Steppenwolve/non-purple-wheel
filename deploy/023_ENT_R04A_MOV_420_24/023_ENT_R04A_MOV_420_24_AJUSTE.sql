-- ============================================================
-- AJUSTE  023_ENT_R04A_MOV_420_24  (R04A Movimientos 420/424, IFRS9)
-- Origen : BRONZE.LMDA.R04A_MOV_420_24 (insumo DESAGREGADO por E1/E2/E3)
-- Destino: SILVER.RR.023_ENT_R04A_MOV_420_24 (layout Credito_IFRS9_R04A_MOV_420_24)
-- Periodicidad: Mensual (ventana por FECHA_INFO)
--
-- Transformacion (DESPIVOTE de E1/E2/E3):
--   Por cada fila de BRONZE, por cada etapa (1=E1, 2=E2, 3=E3) con IMPORTE > 0
--   se genera una fila en SILVER:
--     CUENTA_CREDITO   = CUENTA_CREDITO (NULL -> 0 ; sin zero-padding)
--     ETAPA_DETERIORO  = 1 / 2 / 3 (segun E1/E2/E3)
--     TIPO_MOV_420_424 = TIPO_MOV_420_424 (numerico; zero-padding a 2 en el SP ION)
--     IMPORTE          = el valor de E1 / E2 / E3
--     MONEDA           = 'MXN' (constante)
--     FECHA_INFO       = FECHA_INFO (directo)
--   Sin filtro por CONCEPTO/TIPO/ESTATUS/TIPO_CARTERA/RESTRINGIDO (historico en BRONZE).
-- ============================================================

-- ============================================================
-- SECTION 01 | SILVER — alinear TIPO_MOV_420_424 al layout (longitud 2)
-- ============================================================
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='023_ENT_R04A_MOV_420_24'
             AND COLUMN_NAME='TIPO_MOV_420_424' AND (NUMERIC_PRECISION<>2 OR NUMERIC_SCALE<>0))
    ALTER TABLE [RR].[023_ENT_R04A_MOV_420_24] ALTER COLUMN [TIPO_MOV_420_424] numeric(2,0) NOT NULL;
GO
PRINT 'TIPO_MOV_420_424 -> numeric(2,0)';
GO

-- ============================================================
-- SECTION 02 | SP SILVER — [dbo].[023_ENT_R04A_MOV_420_24]
-- ============================================================
USE [SILVER]
GO
CREATE OR ALTER PROCEDURE [dbo].[023_ENT_R04A_MOV_420_24]
    @CorreoNotificacion NVARCHAR(255) = NULL,
    @PerfilCorreo       NVARCHAR(255) = NULL,
    @ProgramadorJob     NVARCHAR(128) = NULL,
    @FechaSistema       DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @MensajeError    NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion  BIT           = 1;
    DECLARE @FilasInsertadas INT           = 0;
    DECLARE @LogMessage      NVARCHAR(MAX) = '';
    DECLARE @DetallesLog     NVARCHAR(MAX) = '';
    DECLARE @FechaInicio     DATETIME      = GETDATE();
    DECLARE @FilasEliminadas INT           = 0;
    DECLARE @NombreJob       NVARCHAR(128) = '[023_ENT_R04A_MOV_420_24]';

    -- Ventana mensual por FECHA_INFO
    DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
    DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[023_ENT_R04A_MOV_420_24]
                   WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin)
        BEGIN
            DELETE FROM [SILVER].[RR].[023_ENT_R04A_MOV_420_24]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[023_ENT_R04A_MOV_420_24] (
            [CUENTA_CREDITO], [ETAPA_DETERIORO], [TIPO_MOV_420_424], [IMPORTE], [MONEDA], [FECHA_INFO]
        )
        SELECT
            CONVERT(varchar(12), CAST(ISNULL(A.[CUENTA_CREDITO], 0) AS bigint)),  -- NULL->0 ; sin zero-padding
            v.etapa,                                                              -- 1 / 2 / 3
            A.[TIPO_MOV_420_424],                                                 -- numerico (zero-pad en ION)
            v.importe,                                                            -- IMPORTE = E1/E2/E3
            'MXN',                                                                -- MONEDA constante
            A.[FECHA_INFO]
        FROM [BRONZE].[LMDA].[R04A_MOV_420_24] A
        CROSS APPLY (VALUES (1, A.[E1]), (2, A.[E2]), (3, A.[E3])) AS v(etapa, importe)
        WHERE A.[FECHA_INFO] >= @FechaIni AND A.[FECHA_INFO] < @FechaFin
          AND v.importe > 0;   -- solo etapas con importe > 0

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0; SET @MensajeError = ERROR_MESSAGE();
        SET @LogMessage = 'Error durante la ejecucion: ' + @MensajeError;
        PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
    END CATCH

    DECLARE @Asunto NVARCHAR(255), @Cuerpo NVARCHAR(MAX);
    IF @ExitoEjecucion = 0 AND @CorreoNotificacion IS NOT NULL AND @PerfilCorreo IS NOT NULL
    BEGIN
        SET @Asunto = 'ALERTA: Error en ' + ISNULL(@NombreJob, 'Job Desconocido');
        SET @Cuerpo = 'Error durante la ejecucion de ' + @NombreJob + CHAR(13) + CHAR(10)
            + 'Mensaje: ' + @MensajeError + CHAR(13) + CHAR(10) + 'Log:' + CHAR(13) + CHAR(10) + @DetallesLog;
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail @profile_name=@PerfilCorreo, @recipients=@CorreoNotificacion,
                @subject=@Asunto, @body=@Cuerpo, @body_format='TEXT', @importance='High';
        END TRY BEGIN CATCH PRINT 'Error al enviar alerta: ' + ERROR_MESSAGE(); END CATCH
    END

    INSERT INTO dbo.LogSilverDiario (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (@FechaInicio, @FilasInsertadas,
            CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
            CASE WHEN @ExitoEjecucion = 1 THEN NULL ELSE @MensajeError END,
            @DetallesLog, @NombreJob, @ProgramadorJob);
    PRINT 'Proceso completado y registrado en la tabla de log.';
END;
GO

-- ============================================================
-- SECTION 03 | SP ION — [dbo].[023_ENT_R04A_MOV_420_24]
--   Presenta TIPO_MOV_420_424 con zero-padding a 2 digitos. Filtro mensual.
-- ============================================================
USE [ION]
GO
CREATE OR ALTER PROCEDURE [dbo].[023_ENT_R04A_MOV_420_24]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FECHA), MONTH(@FECHA), 1);
    DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);

    SELECT
        T.[CUENTA_CREDITO]                                          AS [CUENTA_CREDITO],
        T.[ETAPA_DETERIORO]                                        AS [ETAPA_DETERIORO],
        RIGHT('00' + CAST(CAST(T.[TIPO_MOV_420_424] AS int) AS varchar(2)), 2) AS [TIPO_MOV_420_424],  -- zero-pad a 2
        T.[IMPORTE]                                                AS [IMPORTE],
        T.[MONEDA]                                                 AS [MONEDA],
        FORMAT(T.[FECHA_INFO], 'yyyy/MM/dd')                       AS [FECHA_INFO]   -- AAAA/MM/DD (10 chars)
    FROM [SILVER].[RR].[023_ENT_R04A_MOV_420_24] T
    WHERE T.[FECHA_INFO] >= @FechaIni AND T.[FECHA_INFO] < @FechaFin;
END;
GO

-- ============================================================
-- SECTION 04 | INDICE_REPORTES — registrar reporte 23 (Mensual)
-- ============================================================
USE [ION]
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[INDICE_REPORTES] WHERE [numero] = 23)
    INSERT INTO [dbo].[INDICE_REPORTES] ([numero], [nombre], [frecuencia], [activo], [nombre_archivo])
    VALUES (23, 'ENT_R04A_MOV_420_24', 'Mensual', 1, 'R04A_MOV_420_24');

SELECT numero, nombre, frecuencia, activo, nombre_archivo FROM dbo.INDICE_REPORTES WHERE numero = 23;
GO
