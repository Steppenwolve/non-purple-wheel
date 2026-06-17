/* ============================================================================
   155_ENT_SWAP_IV_CORRECCION.sql
   Reporte : SWAP_IV  (Swaps - Diaria)
   Fin     : Corregir hallazgos detectados vs. Layout_SWAPS_V10_IV.xlsx:
               1. SILVER.RR.[155_ENT_SWAP_IV] - ADD FECHA_INFO date
               2. SILVER.dbo.[155_ENT_SWAP_IV] - eliminar ventana mensual
                  (codigo muerto), usar @FechaDia, incluir FECHA_INFO
               3. ION.dbo.[155_ENT_SWAP_IV]   - remover ID y FECHA_EXTRACCION,
                  agregar FECHA_INFO, eliminar comentarios muertos
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
    WHERE s.name = 'RR' AND o.name = '155_ENT_SWAP_IV' AND o.type = 'U'
)
BEGIN
    RAISERROR('Preflight fallido: SILVER.[RR].[155_ENT_SWAP_IV] no existe. Abortando.', 16, 1);
    RETURN;
END
PRINT '>> Preflight OK: SILVER.[RR].[155_ENT_SWAP_IV] existe.';
GO

/* --------------------------------------------------------------------------
   01 - TABLA: ADD FECHA_INFO date
        Layout campo #54: FECHA, formato AAAA/MM/DD.
        Ausente en la tabla original. Se agrega como NULL para compatibilidad
        con datos existentes.
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
-- Migracion de nombre (consideracion 11): el layout nombra FECHAINFO; se estandariza a FECHA_INFO.
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='155_ENT_SWAP_IV' AND COLUMN_NAME='FECHAINFO')
   AND NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='155_ENT_SWAP_IV' AND COLUMN_NAME='FECHA_INFO')
BEGIN
    EXEC sp_rename '[RR].[155_ENT_SWAP_IV].[FECHAINFO]', 'FECHA_INFO', 'COLUMN';
    PRINT '>> Columna FECHAINFO renombrada a FECHA_INFO.';
END

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '155_ENT_SWAP_IV' AND COLUMN_NAME = 'FECHA_INFO'
)
BEGIN
    ALTER TABLE [RR].[155_ENT_SWAP_IV]
        ADD [FECHA_INFO] date NULL;
    PRINT '>> Columna FECHA_INFO date agregada a SILVER.[RR].[155_ENT_SWAP_IV].';
END
ELSE
    PRINT '>> FECHA_INFO ya existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   02 - SP SILVER: CREATE OR ALTER con correcciones
        Cambios:
        - Eliminado calculo de ventana mensual (@FechaIni/@FechaFin): codigo muerto.
        - @FechaDia = CAST(@FechaSistema AS DATE) para comparaciones consistentes.
        - FECHA_INFO incluida en INSERT (= @FechaDia) y SELECT.
        - DELETE e IF EXISTS usan @FechaDia en lugar de @FechaSistema (DATETIME).
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[155_ENT_SWAP_IV]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[155_ENT_SWAP_IV]';
    DECLARE @FechaDia        DATE          = CAST(@FechaSistema AS DATE);

    BEGIN TRY
        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[155_ENT_SWAP_IV]
            WHERE [FE_CON_OPE] = @FechaDia
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[155_ENT_SWAP_IV]
            WHERE [FE_CON_OPE] = @FechaDia;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END

        INSERT INTO [RR].[155_ENT_SWAP_IV] (
            [OFICINA],
            [CONT],
            [FE_CON_OPE],
            [FE1_FLU_RE],
            [FEN_FLU_RE],
            [FE1_FLU_EN],
            [FEN_FLU_EN],
            [TIP_DER],
            [OBJ_OPE],
            [REV_SWAP],
            [DET_FLUJO],
            [INTERC_IMP],
            [IMP_BA_RE],
            [MDA_IMP_RE],
            [IMP_BA_EN],
            [MDA_IMP_EN],
            [LIQ_FLU],
            [NU_FLU_RE],
            [NU_FLU_EN],
            [INT_FLU_RE],
            [INT_FLU_EN],
            [TIP_LIQ],
            [MDA_LIQ],
            [SUBY_RE],
            [CVE_TIT_RE],
            [NU_SUBY_RE],
            [CUANT_RE],
            [PRE_SUB_RE],
            [MDA_PRE_EN],
            [FE_EN_RE],
            [SUBY_EN],
            [CVE_TIT_EN],
            [NU_SUBY_EN],
            [CUANT_EN],
            [PRE_SUB_EN],
            [MDA_PRE_RE],
            [FE_RE_EN],
            [CUO_COMP],
            [VEN_ANT],
            [TER_OPE],
            [PAQ_EST],
            [ID_PAQ_EST],
            [CON_PAQ_EST],
            [BROKER],
            [SOCIO_LIQ],
            [CAM_COM],
            [AG_CAL],
            [NUM_CONF],
            [NU_ID],
            [NUM_ID_OP_SBY],
            [MODIFICA],
            [UTI],
            [UPI],
            [FECHA_INFO]
        )
        SELECT
            [OFICINA],
            [CONT],
            [FE_CON_OPE],
            [FE1_FLU_RE],
            [FEN_FLU_RE],
            [FE1_FLU_EN],
            [FEN_FLU_EN],
            [TIP_DER],
            [OBJ_OPE],
            [REV_SWAP],
            [DET_FLUJO],
            [INTERC_IMP],
            [IMP_BA_RE],
            [MDA_IMP_RE],
            [IMP_BA_EN],
            [MDA_IMP_EN],
            [LIQ_FLU],
            [NU_FLU_RE],
            [NU_FLU_EN],
            [INT_FLU_RE],
            [INT_FLU_EN],
            [TIP_LIQ],
            [MDA_LIQ],
            [SUBY_RE],
            [CVE_TIT_RE],
            [NU_SUBY_RE],
            [CUANT_RE],
            [PRE_SUB_RE],
            [MDA_PRE_EN],
            [FE_EN_RE],
            [SUBY_EN],
            [CVE_TIT_EN],
            [NU_SUBY_EN],
            [CUANT_EN],
            [PRE_SUB_EN],
            [MDA_PRE_RE],
            [FE_RE_EN],
            [CUO_COMP],
            [VEN_ANT],
            [TER_OPE],
            [PAQ_EST],
            [ID_PAQ_EST],
            [CON_PAQ_EST],
            [BROKER],
            [SOCIO_LIQ],
            [CAM_COM],
            [AG_CAL],
            [NUM_CONF],
            [NU_ID],
            [NUM_ID_OP_SBY],
            [MODIFICA],
            [UTI],
            [UPI],
            @FechaDia
        FROM [SILVER].[RR].[155_ENT_SWAP_IV]
        WHERE [FE_CON_OPE] = @FechaDia;

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
PRINT '>> SILVER.dbo.[155_ENT_SWAP_IV] actualizado.';
GO

/* --------------------------------------------------------------------------
   03 - SP ION: CREATE OR ALTER con correcciones
        Cambios:
        - Removidos ID y FECHA_EXTRACCION del SELECT.
        - Agregada FECHA_INFO al SELECT.
        - Eliminados comentarios muertos al final.
   -------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[155_ENT_SWAP_IV]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- NOTA (consideracion 11): el layout nombra la columna FECHAINFO; se estandariza a FECHA_INFO.
    -- NOTA (consideracion 12): salida de fechas en AAAA/MM/DD via FORMAT(...,'yyyy/MM/dd').
    -- (FE_EN_RE y FE_RE_EN son catalogos de texto MOD_TAS, no fechas.)
    SELECT
        [OFICINA],
        [CONT],
        FORMAT([FE_CON_OPE], 'yyyy/MM/dd') AS [FE_CON_OPE],
        FORMAT([FE1_FLU_RE], 'yyyy/MM/dd') AS [FE1_FLU_RE],
        FORMAT([FEN_FLU_RE], 'yyyy/MM/dd') AS [FEN_FLU_RE],
        FORMAT([FE1_FLU_EN], 'yyyy/MM/dd') AS [FE1_FLU_EN],
        FORMAT([FEN_FLU_EN], 'yyyy/MM/dd') AS [FEN_FLU_EN],
        [TIP_DER],
        [OBJ_OPE],
        [REV_SWAP],
        [DET_FLUJO],
        [INTERC_IMP],
        [IMP_BA_RE],
        [MDA_IMP_RE],
        [IMP_BA_EN],
        [MDA_IMP_EN],
        [LIQ_FLU],
        [NU_FLU_RE],
        [NU_FLU_EN],
        [INT_FLU_RE],
        [INT_FLU_EN],
        [TIP_LIQ],
        [MDA_LIQ],
        [SUBY_RE],
        [CVE_TIT_RE],
        [NU_SUBY_RE],
        [CUANT_RE],
        [PRE_SUB_RE],
        [MDA_PRE_EN],
        [FE_EN_RE],
        [SUBY_EN],
        [CVE_TIT_EN],
        [NU_SUBY_EN],
        [CUANT_EN],
        [PRE_SUB_EN],
        [MDA_PRE_RE],
        [FE_RE_EN],
        [CUO_COMP],
        [VEN_ANT],
        [TER_OPE],
        [PAQ_EST],
        [ID_PAQ_EST],
        [CON_PAQ_EST],
        [BROKER],
        [SOCIO_LIQ],
        [CAM_COM],
        [AG_CAL],
        [NUM_CONF],
        [NU_ID],
        [NUM_ID_OP_SBY],
        [MODIFICA],
        [UTI],
        [UPI],
        FORMAT([FECHA_INFO], 'yyyy/MM/dd') AS [FECHA_INFO]
    FROM [SILVER].[RR].[155_ENT_SWAP_IV]
    WHERE [FE_CON_OPE] = @FECHA;
END;
GO
PRINT '>> ION.dbo.[155_ENT_SWAP_IV] actualizado.';
PRINT '>> Correccion 155_ENT_SWAP_IV completada.';
GO
