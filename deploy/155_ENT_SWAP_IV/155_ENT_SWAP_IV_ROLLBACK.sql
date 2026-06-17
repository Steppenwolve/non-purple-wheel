/* ============================================================================
   155_ENT_SWAP_IV_ROLLBACK.sql
   Fin     : Revertir los cambios aplicados por 155_ENT_SWAP_IV_CORRECCION.sql.
   IMPORTANTE:
     - Los datos en FECHA_INFO se pierden al hacer DROP COLUMN.
     - CREATE OR ALTER restaura la definicion PRE-correccion conocida.
   ============================================================================ */

/* --------------------------------------------------------------------------
   01 - SP ION: restaurar definicion original
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

    SELECT
        [ID],
        [FECHA_EXTRACCION],
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
        [UPI]
    FROM [SILVER].[RR].[155_ENT_SWAP_IV]
    WHERE [FE_CON_OPE] = @FECHA;

    --EXEC [dbo].[155_ENT_SWAP_IV] @FECHA = '20240420'

    -- Para reportes diarios WHERE FECHA_REPORTE = @Fecha
END;
GO
PRINT '>> ION.dbo.[155_ENT_SWAP_IV] revertido al estado original.';
GO

/* --------------------------------------------------------------------------
   02 - SP SILVER: restaurar definicion original
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

    DECLARE @SQL             NVARCHAR(MAX);
    DECLARE @MensajeError    NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion  BIT           = 1;
    DECLARE @FilasInsertadas INT           = 0;
    DECLARE @LogMessage      NVARCHAR(MAX) = '';
    DECLARE @DetallesLog     NVARCHAR(MAX) = '';
    DECLARE @FechaInicio     DATETIME      = GETDATE();
    DECLARE @FilasEliminadas INT           = 0;
    DECLARE @NombreJob       NVARCHAR(128) = '[155_ENT_SWAP_IV]';
    DECLARE @FechaIni        DATE,
            @FechaFin        DATE;

    BEGIN TRY
        SET @FechaIni = datefromparts(year(@FechaSistema), month(@FechaSistema), 1)
        SET @FechaFin = Dateadd(month, 1, @FechaIni) --------------------------------------------------------------------------------
            -- QUERY

        IF EXISTS (
            SELECT ID FROM [SILVER].[RR].[155_ENT_SWAP_IV]
            WHERE [FE_CON_OPE] = @FechaSistema
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[155_ENT_SWAP_IV]
            WHERE [FE_CON_OPE] = @FechaSistema;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

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
            [UPI]
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
            [UPI]
        FROM [SILVER].[RR].[155_ENT_SWAP_IV]
        WHERE [FE_CON_OPE] = @FechaSistema;

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
            'Se ha producido un error durante la ejecucion de.' + @NombreJob + CHAR(13)+CHAR(10) +
            '- Nombre del Job: '           + ISNULL(@NombreJob,     'No especificado') + CHAR(13)+CHAR(10) +
            '- Programado por: '           + ISNULL(@ProgramadorJob, 'No especificado') + CHAR(13)+CHAR(10) +
            '- Fecha y hora de inicio: '   + CONVERT(VARCHAR, @FechaInicio,      120)   + CHAR(13)+CHAR(10) +
            '- Fecha y hora de fin: '      + CONVERT(VARCHAR, @FechaFinalizacion, 120)   + CHAR(13)+CHAR(10) +
            '- Duracion: '                 + @DuracionEjecucion + CHAR(13)+CHAR(10) +
            'Mensaje de Error: '           + @MensajeError      + CHAR(13)+CHAR(10) +
            'Log: '                        + @DetallesLog;
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @PerfilCorreo,
                @recipients   = @CorreoNotificacion,
                @subject      = @Asunto,
                @body         = @Cuerpo,
                @body_format  = 'TEXT',
                @importance   = 'High';
            SET @DetallesLog = @DetallesLog + 'Alerta de error enviada exitosamente.' + CHAR(13)+CHAR(10);
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

    SET @LogMessage = 'Proceso completado y registrado en la tabla de log.';
    PRINT @LogMessage;
END;
GO
PRINT '>> SILVER.dbo.[155_ENT_SWAP_IV] revertido al estado original.';
GO

/* --------------------------------------------------------------------------
   03 - TABLA: DROP COLUMN FECHA_INFO
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '155_ENT_SWAP_IV' AND COLUMN_NAME = 'FECHA_INFO'
)
BEGIN
    ALTER TABLE [RR].[155_ENT_SWAP_IV]
        DROP COLUMN [FECHA_INFO];
    PRINT '>> Columna FECHA_INFO eliminada de SILVER.[RR].[155_ENT_SWAP_IV].';
END
ELSE
    PRINT '>> FECHA_INFO no existe. Sin cambios.';
GO

PRINT '>> Rollback 155_ENT_SWAP_IV completado.';
GO
