/* ============================================================================
   080_CVT_TRP_CORRECCION.sql
   Reporte : CVT_TRP  (Custodia / Transferencia de Titulos - Diaria)
   Fin     : Corregir hallazgos detectados vs. Layout_CVT_TRP_V3.xlsx:
               1. SILVER.RR.[080_CVT TRP] - columna NUMTITULOS: int -> numeric(12,0)
               2. SILVER.RR.[080_CVT TRP] - columna FECHA_INFO: faltante, se agrega
               3. SILVER.dbo.[080_CVT TRP] - SP: eliminar calculo de ventana
                  mensual (codigo muerto), incluir FECHA_INFO en INSERT/SELECT
               4. ION.dbo.[080_CVT TRP]    - SP: remover ID y FECHA_EXTRACCION
                  del SELECT (columnas internas sin salida regulatoria)
   Idempotente : cada bloque verifica estado antes de actuar.
   Entorno destino: SILVER e ION (mismo servidor).
   ============================================================================ */

/* --------------------------------------------------------------------------
   00 - PREFLIGHT: verificar que los objetos base existen
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
    WHERE s.name = 'RR' AND o.name = '080_CVT TRP' AND o.type = 'U'
)
BEGIN
    RAISERROR('Preflight fallido: SILVER.[RR].[080_CVT TRP] no existe. Abortando.', 16, 1);
    RETURN;
END
PRINT '>> Preflight OK: SILVER.[RR].[080_CVT TRP] existe.';
GO

/* --------------------------------------------------------------------------
   01 - TABLA: NUMTITULOS  int -> numeric(12,0)
        Layout campo #5: NUMERO, longitud 12.
        La BD tenia int (max 10 digitos), el layout exige 12.
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
DECLARE @tipo SYSNAME;
SELECT @tipo = DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '080_CVT TRP' AND COLUMN_NAME = 'NUMTITULOS';

IF @tipo = 'int'
BEGIN
    ALTER TABLE [RR].[080_CVT TRP]
        ALTER COLUMN [NUMTITULOS] numeric(12, 0) NOT NULL;
    PRINT '>> NUMTITULOS alterado: int -> numeric(12,0).';
END
ELSE
    PRINT '>> NUMTITULOS ya es ' + ISNULL(@tipo,'?') + '. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   02 - TABLA: agregar FECHA_INFO (date)
        Layout campo #9: FECHA, formato aaaammdd.
        Ausente en la tabla original; es la fecha de reporte regulatorio.
        Se agrega como NULL para compatibilidad con datos existentes.
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '080_CVT TRP' AND COLUMN_NAME = 'FECHA_INFO'
)
BEGIN
    ALTER TABLE [RR].[080_CVT TRP]
        ADD [FECHA_INFO] date NULL;
    PRINT '>> Columna FECHA_INFO (date NULL) agregada a SILVER.[RR].[080_CVT TRP].';
END
ELSE
    PRINT '>> FECHA_INFO ya existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   03 - SP SILVER: CREATE OR ALTER con correcciones
        Cambios:
        - Eliminado calculo de ventana mensual (@FechaIni/@FechaFin): codigo
          muerto que nunca se usaba en el WHERE (el reporte es DIARIO).
        - WHERE del DELETE e INSERT usan CAST(@FechaSistema AS DATE) explicito.
        - FECHA_INFO incluida en INSERT y SELECT (= CAST(@FechaSistema AS DATE)).
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[080_CVT TRP]
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
    DECLARE @FilasEliminadas INT           = 0;
    DECLARE @LogMessage      NVARCHAR(MAX) = '';
    DECLARE @DetallesLog     NVARCHAR(MAX) = '';
    DECLARE @FechaInicio     DATETIME      = GETDATE();
    DECLARE @NombreJob       NVARCHAR(128) = '[080_CVT TRP]';
    DECLARE @FechaDia        DATE          = CAST(@FechaSistema AS DATE);

    BEGIN TRY
        /* DELETE idempotente por dia exacto */
        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[080_CVT TRP]
            WHERE [FECHATRANS] = @FechaDia
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[080_CVT TRP]
            WHERE [FECHATRANS] = @FechaDia;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END

        INSERT INTO [RR].[080_CVT TRP] (
            [INSTCUENTRANS],
            [FECHATRANS],
            [TIPOTRANSCUST],
            [TITULOBJTRANS],
            [NUMTITULOS],
            [CUSTCONTRAPARTE],
            [NUMIDTRANS],
            [TIPOMODIFICACION],
            [FECHA_INFO]
        )
        SELECT
            [INSTCUENTRANS],
            [FECHATRANS],
            [TIPOTRANSCUST],
            [TITULOBJTRANS],
            [NUMTITULOS],
            [CUSTCONTRAPARTE],
            [NUMIDTRANS],
            [TIPOMODIFICACION],
            @FechaDia
        FROM [SILVER].[RR].[080_CVT TRP]
        WHERE [FECHATRANS] = @FechaDia;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError   = ERROR_MESSAGE();
        SET @LogMessage     = 'Error durante la ejecucion: ' + @MensajeError;
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
    END CATCH

    DECLARE @Asunto              NVARCHAR(255);
    DECLARE @Cuerpo              NVARCHAR(MAX);
    DECLARE @FechaFinalizacion   DATETIME = GETDATE();
    DECLARE @DuracionEjecucion   VARCHAR(20) =
        CAST(DATEDIFF(SECOND, @FechaInicio, @FechaFinalizacion) AS VARCHAR(10)) + ' segundos';

    IF @ExitoEjecucion = 0
        AND @CorreoNotificacion IS NOT NULL
        AND @PerfilCorreo IS NOT NULL
    BEGIN
        SET @Asunto = 'ALERTA: Error en ' + ISNULL(@NombreJob, 'Job Desconocido');
        SET @Cuerpo =
            'Error en ' + @NombreJob + CHAR(13)+CHAR(10) +
            '- Job: '        + ISNULL(@NombreJob,     'No especificado') + CHAR(13)+CHAR(10) +
            '- Programado: ' + ISNULL(@ProgramadorJob, 'No especificado') + CHAR(13)+CHAR(10) +
            '- Inicio: '     + CONVERT(VARCHAR, @FechaInicio,       120)  + CHAR(13)+CHAR(10) +
            '- Fin: '        + CONVERT(VARCHAR, @FechaFinalizacion,  120)  + CHAR(13)+CHAR(10) +
            '- Duracion: '   + @DuracionEjecucion + CHAR(13)+CHAR(10) +
            'Error: '        + @MensajeError      + CHAR(13)+CHAR(10) +
            'Log: '          + @DetallesLog;
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @PerfilCorreo,
                @recipients   = @CorreoNotificacion,
                @subject      = @Asunto,
                @body         = @Cuerpo,
                @body_format  = 'TEXT',
                @importance   = 'High';
            SET @DetallesLog = @DetallesLog + 'Alerta enviada.' + CHAR(13)+CHAR(10);
        END TRY
        BEGIN CATCH
            SET @DetallesLog = @DetallesLog + 'Error al enviar alerta: ' + ERROR_MESSAGE() + CHAR(13)+CHAR(10);
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario
        (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (
        @FechaInicio,
        @FilasInsertadas,
        CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion = 1 THEN NULL      ELSE @MensajeError END,
        @DetallesLog,
        @NombreJob,
        @ProgramadorJob
    );
END;
GO
PRINT '>> SILVER.dbo.[080_CVT TRP] actualizado.';
GO

/* --------------------------------------------------------------------------
   04 - SP ION: CREATE OR ALTER con correcciones
        Cambios:
        - Removidos ID y FECHA_EXTRACCION del SELECT (columnas internas).
        - Agregado FECHA_INFO al SELECT (campo regulatorio del layout).
        - Eliminado comentario muerto al final del SP.
   -------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[080_CVT TRP]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- NOTA (formato de fecha): el layout marca AAAAMMDD; por estandar (consideracion 12)
    -- la salida se entrega en AAAA/MM/DD via FORMAT(...,'yyyy/MM/dd').
    SELECT
        [INSTCUENTRANS],
        FORMAT([FECHATRANS], 'yyyy/MM/dd')   AS [FECHATRANS],
        [TIPOTRANSCUST],
        [TITULOBJTRANS],
        [NUMTITULOS],
        [CUSTCONTRAPARTE],
        [NUMIDTRANS],
        [TIPOMODIFICACION],
        FORMAT([FECHA_INFO], 'yyyy/MM/dd')   AS [FECHA_INFO]
    FROM [SILVER].[RR].[080_CVT TRP]
    WHERE [FECHATRANS] = @FECHA;
END;
GO
PRINT '>> ION.dbo.[080_CVT TRP] actualizado.';
GO
