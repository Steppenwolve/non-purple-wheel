/* ============================================================================
   132_ENT_FUT_CONVAL_ROLLBACK.sql
   Fin     : Revertir los cambios aplicados por 132_ENT_FUT_CONVAL_CORRECCION.sql.
   IMPORTANTE:
     - Los datos existentes en NOCIONAL, MON_NOCIONAL y FECHAINFO se pierden
       al hacer DROP COLUMN; no son recuperables sin respaldo previo.
     - Las columnas FE_CORTE, ACT_OPE_VAL y PAS_OPE_VAL se vuelven a crear (como
       NULL, ya que sus datos se perdieron al eliminarlas en la correccion).
     - CREATE OR ALTER restaura la definicion PRE-correccion conocida.
   ============================================================================ */

/* --------------------------------------------------------------------------
   00 - TABLA: re-crear columnas eliminadas por la correccion (antes de
        restaurar los SPs originales, que las referencian).
        Se crean como NULL (los datos originales no son recuperables).
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='132_ENT_FUT_CONVAL' AND COLUMN_NAME='FE_CORTE')
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL] ADD [FE_CORTE] date NULL;
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='132_ENT_FUT_CONVAL' AND COLUMN_NAME='ACT_OPE_VAL')
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL] ADD [ACT_OPE_VAL] numeric(15,0) NULL;
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='132_ENT_FUT_CONVAL' AND COLUMN_NAME='PAS_OPE_VAL')
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL] ADD [PAS_OPE_VAL] numeric(15,0) NULL;
PRINT '>> Columnas FE_CORTE, ACT_OPE_VAL, PAS_OPE_VAL re-creadas (NULL).';
GO

/* --------------------------------------------------------------------------
   01 - SP ION: restaurar definicion original
   -------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[132_ENT_FUT_CONVAL]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        [ID],
        [FECHA_EXTRACCION],
        [PRO_TER],
        [CLIENTE],
        [POS_OPER],
        [PIZARRA],
        [SOCIO_LIQ],
        [CONTRAT_VIG],
        [OBJ_OPE],
        [PAQ_FUT],
        [ID_PAQ],
        [CONSEQ_PAQ],
        [ACT_OPE],
        [MON_ACT_OPE],
        [PAS_OPE],
        [MON_PAS_OPE],
        [DUR_ACT],
        [DUR_PAS],
        [ID_GAR_VG],
        [NUM_ID],
        [FE_CORTE],
        [ACT_OPE_VAL],
        [PAS_OPE_VAL]
    FROM [SILVER].[RR].[132_ENT_FUT_CONVAL]
    WHERE [FE_CORTE] = @FECHA;

    --EXEC [dbo].[132_ENT_FUT_CONVAL]  @FECHA = '20240420'

    -- Para reportes diarios WHERE FECHA_REPORTE = @Fecha
END;
GO
PRINT '>> ION.dbo.[132_ENT_FUT_CONVAL] revertido al estado original.';
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
CREATE OR ALTER PROCEDURE [dbo].[132_ENT_FUT_CONVAL]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[132_ENT_FUT_CONVAL] ';
    DECLARE @FechaIni        DATE,
            @FechaFin        DATE;

    BEGIN TRY
        SET @FechaIni = datefromparts(year(@FechaSistema), month(@FechaSistema), 1)
        SET @FechaFin = Dateadd(month, 1, @FechaIni) --------------------------------------------------------------------------------
            -- QUERY

        IF EXISTS (
            SELECT ID FROM [SILVER].[RR].[132_ENT_FUT_CONVAL]
            WHERE [FE_CORTE] = @FechaSistema
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[132_ENT_FUT_CONVAL]
            WHERE [FE_CORTE] = @FechaSistema;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[132_ENT_FUT_CONVAL] (
            [PRO_TER],
            [CLIENTE],
            [POS_OPER],
            [PIZARRA],
            [SOCIO_LIQ],
            [CONTRAT_VIG],
            [OBJ_OPE],
            [PAQ_FUT],
            [ID_PAQ],
            [CONSEQ_PAQ],
            [ACT_OPE],
            [MON_ACT_OPE],
            [PAS_OPE],
            [MON_PAS_OPE],
            [DUR_ACT],
            [DUR_PAS],
            [ID_GAR_VG],
            [NUM_ID],
            [FE_CORTE],
            [ACT_OPE_VAL],
            [PAS_OPE_VAL]
        )
        SELECT
            [PRO_TER],
            [CLIENTE],
            [POS_OPER],
            [PIZARRA],
            [SOCIO_LIQ],
            [CONTRAT_VIG],
            [OBJ_OPE],
            [PAQ_FUT],
            [ID_PAQ],
            [CONSEQ_PAQ],
            [ACT_OPE],
            [MON_ACT_OPE],
            [PAS_OPE],
            [MON_PAS_OPE],
            [DUR_ACT],
            [DUR_PAS],
            [ID_GAR_VG],
            [NUM_ID],
            [FE_CORTE],
            [ACT_OPE_VAL],
            [PAS_OPE_VAL]
        FROM [SILVER].[RR].[132_ENT_FUT_CONVAL]
        WHERE [FE_CORTE] = @FechaSistema;

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
PRINT '>> SILVER.dbo.[132_ENT_FUT_CONVAL] revertido al estado original.';
GO

/* --------------------------------------------------------------------------
   03 - TABLA: DROP COLUMN FECHAINFO
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '132_ENT_FUT_CONVAL' AND COLUMN_NAME = 'FECHAINFO'
)
BEGIN
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL]
        DROP COLUMN [FECHAINFO];
    PRINT '>> Columna FECHAINFO eliminada.';
END
ELSE
    PRINT '>> FECHAINFO no existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   04 - TABLA: DROP COLUMN MON_NOCIONAL
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '132_ENT_FUT_CONVAL' AND COLUMN_NAME = 'MON_NOCIONAL'
)
BEGIN
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL]
        DROP COLUMN [MON_NOCIONAL];
    PRINT '>> Columna MON_NOCIONAL eliminada.';
END
ELSE
    PRINT '>> MON_NOCIONAL no existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   05 - TABLA: DROP COLUMN NOCIONAL
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '132_ENT_FUT_CONVAL' AND COLUMN_NAME = 'NOCIONAL'
)
BEGIN
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL]
        DROP COLUMN [NOCIONAL];
    PRINT '>> Columna NOCIONAL eliminada.';
END
ELSE
    PRINT '>> NOCIONAL no existe. Sin cambios.';
GO

PRINT '>> Rollback 132_ENT_FUT_CONVAL completado.';
GO
