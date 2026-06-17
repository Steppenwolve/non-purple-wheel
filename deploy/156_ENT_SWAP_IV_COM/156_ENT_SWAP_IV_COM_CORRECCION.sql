/* ============================================================================
   156_ENT_SWAP_IV_COM_CORRECCION.sql
   Reporte : SWAP_IV_COM  (Swaps IV Complemento - Diaria)
   Fin     : Corregir hallazgos detectados vs. Layout_SWAPS_V10_IV_COM.xlsx:
               1. SILVER.RR.[156_ENT_SWAP_IV_COM] - ADD FECHAINFO date
               2. SILVER.dbo.[156_ENT_SWAP_IV_COM] - eliminar ventana mensual
                  (codigo muerto), usar @FechaDia, incluir FECHAINFO
               3. ION.dbo.[156_ENT_SWAP_IV_COM]   - remover ID y FECHA_EXTRACCION,
                  agregar FECHAINFO, eliminar comentarios muertos
   Idempotente : cada bloque verifica estado antes de actuar.
   Entorno destino: SILVER e ION (mismo servidor).
   ============================================================================ */

/* --------------------------------------------------------------------------
   00 - PREFLIGHT
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
    WHERE s.name = 'RR' AND o.name = '156_ENT_SWAP_IV_COM' AND o.type = 'U'
)
BEGIN
    RAISERROR('Preflight fallido: SILVER.[RR].[156_ENT_SWAP_IV_COM] no existe. Abortando.', 16, 1);
    RETURN;
END
PRINT '>> Preflight OK: SILVER.[RR].[156_ENT_SWAP_IV_COM] existe.';
GO

/* --------------------------------------------------------------------------
   01 - TABLA: ADD FECHAINFO date
        Layout campo #23: FECHA, formato AAAA/MM/DD.
        EXCEPCION (como el 132): el 156 conserva el nombre LITERAL del layout FECHAINFO
        (sin guion bajo). Si quedó FECHA_INFO de una correccion previa, se renombra.
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
-- Migracion inversa: si existe la columna FECHA_INFO (de una correccion previa), renombrar a FECHAINFO.
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='156_ENT_SWAP_IV_COM' AND COLUMN_NAME='FECHA_INFO')
   AND NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='156_ENT_SWAP_IV_COM' AND COLUMN_NAME='FECHAINFO')
BEGIN
    EXEC sp_rename '[RR].[156_ENT_SWAP_IV_COM].[FECHA_INFO]', 'FECHAINFO', 'COLUMN';
    PRINT '>> Columna FECHA_INFO renombrada a FECHAINFO.';
END

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '156_ENT_SWAP_IV_COM' AND COLUMN_NAME = 'FECHAINFO'
)
BEGIN
    ALTER TABLE [RR].[156_ENT_SWAP_IV_COM]
        ADD [FECHAINFO] date NULL;
    PRINT '>> Columna FECHAINFO date agregada a SILVER.[RR].[156_ENT_SWAP_IV_COM].';
END
ELSE
    PRINT '>> FECHAINFO ya existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   02 - SP SILVER: CREATE OR ALTER con correcciones
        Cambios:
        - Eliminado calculo de ventana mensual (@FechaIni/@FechaFin): codigo muerto.
        - @FechaDia = CAST(@FechaSistema AS DATE) para comparaciones consistentes.
        - FECHAINFO incluida en INSERT (= @FechaDia) y SELECT.
        - DELETE e IF EXISTS usan @FechaDia en lugar de @FechaSistema (DATETIME).
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[156_ENT_SWAP_IV_COM]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[156_ENT_SWAP_IV_COM]';
    DECLARE @FechaDia        DATE          = CAST(@FechaSistema AS DATE);

    BEGIN TRY
        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[156_ENT_SWAP_IV_COM]
            WHERE [FECHA] = @FechaDia
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[156_ENT_SWAP_IV_COM]
            WHERE [FECHA] = @FechaDia;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END

        INSERT INTO [RR].[156_ENT_SWAP_IV_COM] (
            [CONT],
            [FECHA],
            [NU_ID],
            [NU_FL_RE],
            [IMP_BA_RE],
            [FEIN_FL_RE],
            [FEIN_VE_RE],
            [SUBY_RE],
            [CVE_TIT_RE],
            [NU_SUBY_RE],
            [CUANT_RE],
            [PRE_SUB_RE],
            [NU_FL_EN],
            [IMP_BA_EN],
            [FEIN_FL_EN],
            [FEIN_VE_EN],
            [SUBY_EN],
            [CVE_TIT_EN],
            [NU_SUBY_EN],
            [CUANT_EN],
            [PRE_SUB_EN],
            [MODIFICA],
            [FECHAINFO]
        )
        SELECT
            [CONT],
            [FECHA],
            [NU_ID],
            [NU_FL_RE],
            [IMP_BA_RE],
            [FEIN_FL_RE],
            [FEIN_VE_RE],
            [SUBY_RE],
            [CVE_TIT_RE],
            [NU_SUBY_RE],
            [CUANT_RE],
            [PRE_SUB_RE],
            [NU_FL_EN],
            [IMP_BA_EN],
            [FEIN_FL_EN],
            [FEIN_VE_EN],
            [SUBY_EN],
            [CVE_TIT_EN],
            [NU_SUBY_EN],
            [CUANT_EN],
            [PRE_SUB_EN],
            [MODIFICA],
            @FechaDia
        FROM [SILVER].[RR].[156_ENT_SWAP_IV_COM]
        WHERE [FECHA] = @FechaDia;

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

    DECLARE @Asunto            NVARCHAR(255);
    DECLARE @Cuerpo            NVARCHAR(MAX);
    DECLARE @FechaFinalizacion DATETIME = GETDATE();
    DECLARE @DuracionEjecucion VARCHAR(20) =
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
PRINT '>> SILVER.dbo.[156_ENT_SWAP_IV_COM] actualizado.';
GO

/* --------------------------------------------------------------------------
   03 - SP ION: CREATE OR ALTER con correcciones
        Cambios:
        - Removidos ID y FECHA_EXTRACCION del SELECT.
        - Agregada FECHAINFO al SELECT.
        - Eliminados comentarios muertos al final.
   -------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[156_ENT_SWAP_IV_COM]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- NOTA: EXCEPCION (como el 132) - el 156 conserva el nombre LITERAL del layout: FECHAINFO.
    -- NOTA (consideracion 12): salida de fechas en AAAA/MM/DD via FORMAT(...,'yyyy/MM/dd').
    SELECT
        [CONT],
        FORMAT([FECHA], 'yyyy/MM/dd')      AS [FECHA],
        [NU_ID],
        [NU_FL_RE],
        [IMP_BA_RE],
        FORMAT([FEIN_FL_RE], 'yyyy/MM/dd') AS [FEIN_FL_RE],
        FORMAT([FEIN_VE_RE], 'yyyy/MM/dd') AS [FEIN_VE_RE],
        [SUBY_RE],
        [CVE_TIT_RE],
        [NU_SUBY_RE],
        [CUANT_RE],
        [PRE_SUB_RE],
        [NU_FL_EN],
        [IMP_BA_EN],
        FORMAT([FEIN_FL_EN], 'yyyy/MM/dd') AS [FEIN_FL_EN],
        FORMAT([FEIN_VE_EN], 'yyyy/MM/dd') AS [FEIN_VE_EN],
        [SUBY_EN],
        [CVE_TIT_EN],
        [NU_SUBY_EN],
        [CUANT_EN],
        [PRE_SUB_EN],
        [MODIFICA],
        FORMAT([FECHAINFO], 'yyyy/MM/dd') AS [FECHAINFO]
    FROM [SILVER].[RR].[156_ENT_SWAP_IV_COM]
    WHERE [FECHA] = @FECHA;
END;
GO
PRINT '>> ION.dbo.[156_ENT_SWAP_IV_COM] actualizado.';
PRINT '>> Correccion 156_ENT_SWAP_IV_COM completada.';
GO
