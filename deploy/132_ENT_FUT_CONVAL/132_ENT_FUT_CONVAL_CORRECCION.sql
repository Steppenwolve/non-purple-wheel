/* ============================================================================
   132_ENT_FUT_CONVAL_CORRECCION.sql
   Reporte : FUT_CONVAL  (Futuros - Convalidaciones - Diaria)
   Fin     : Corregir hallazgos detectados vs. Layout OFF_FX_V11.xlsx:
               1. SILVER.RR.[132_ENT_FUT_CONVAL] - ADD NOCIONAL numeric(15,0)
               2. SILVER.RR.[132_ENT_FUT_CONVAL] - ADD MON_NOCIONAL varchar(3)
               3. SILVER.RR.[132_ENT_FUT_CONVAL] - ADD FECHAINFO date
               4. SILVER.dbo.[132_ENT_FUT_CONVAL] - eliminar ventana mensual
                  (codigo muerto), usar @FechaDia, incluir 3 columnas nuevas
               5. ION.dbo.[132_ENT_FUT_CONVAL]   - remover ID y FECHA_EXTRACCION,
                  agregar NOCIONAL, MON_NOCIONAL, FECHAINFO, eliminar comentario muerto
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
    WHERE s.name = 'RR' AND o.name = '132_ENT_FUT_CONVAL' AND o.type = 'U'
)
BEGIN
    RAISERROR('Preflight fallido: SILVER.[RR].[132_ENT_FUT_CONVAL] no existe. Abortando.', 16, 1);
    RETURN;
END
PRINT '>> Preflight OK: SILVER.[RR].[132_ENT_FUT_CONVAL] existe.';
GO

/* --------------------------------------------------------------------------
   01 - TABLA: ADD NOCIONAL numeric(15,0)
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '132_ENT_FUT_CONVAL' AND COLUMN_NAME = 'NOCIONAL'
)
BEGIN
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL]
        ADD [NOCIONAL] numeric(15, 0) NULL;
    PRINT '>> Columna NOCIONAL numeric(15,0) agregada.';
END
ELSE
    PRINT '>> NOCIONAL ya existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   02 - TABLA: ADD MON_NOCIONAL varchar(3)
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '132_ENT_FUT_CONVAL' AND COLUMN_NAME = 'MON_NOCIONAL'
)
BEGIN
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL]
        ADD [MON_NOCIONAL] varchar(3) NULL;
    PRINT '>> Columna MON_NOCIONAL varchar(3) agregada.';
END
ELSE
    PRINT '>> MON_NOCIONAL ya existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   03 - TABLA: ADD FECHAINFO date
        Para 132 se conserva el nombre LITERAL del layout: FECHAINFO (sin guion bajo).
        Si quedó una columna FECHA_INFO de una corrección previa, se renombra a FECHAINFO.
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
-- Migracion inversa: si existe la columna FECHA_INFO (de una correccion previa), renombrar a FECHAINFO.
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='132_ENT_FUT_CONVAL' AND COLUMN_NAME='FECHA_INFO')
   AND NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='132_ENT_FUT_CONVAL' AND COLUMN_NAME='FECHAINFO')
BEGIN
    EXEC sp_rename '[RR].[132_ENT_FUT_CONVAL].[FECHA_INFO]', 'FECHAINFO', 'COLUMN';
    PRINT '>> Columna FECHA_INFO renombrada a FECHAINFO.';
END

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '132_ENT_FUT_CONVAL' AND COLUMN_NAME = 'FECHAINFO'
)
BEGIN
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL]
        ADD [FECHAINFO] date NULL;
    PRINT '>> Columna FECHAINFO date agregada.';
END
ELSE
    PRINT '>> FECHAINFO ya existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   03b - TABLA: eliminar columnas que NO pertenecen al layout
         OFF_FX_V11 tiene 21 campos y NO incluye 'Campos Calculados'.
         FE_CORTE, ACT_OPE_VAL y PAS_OPE_VAL no son del layout -> se eliminan.
         (Ninguna tiene default constraint asociado.)
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='132_ENT_FUT_CONVAL' AND COLUMN_NAME='ACT_OPE_VAL')
BEGIN
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL] DROP COLUMN [ACT_OPE_VAL];
    PRINT '>> Columna ACT_OPE_VAL eliminada.';
END
ELSE PRINT '>> ACT_OPE_VAL no existe. Sin cambios.';

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='132_ENT_FUT_CONVAL' AND COLUMN_NAME='PAS_OPE_VAL')
BEGIN
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL] DROP COLUMN [PAS_OPE_VAL];
    PRINT '>> Columna PAS_OPE_VAL eliminada.';
END
ELSE PRINT '>> PAS_OPE_VAL no existe. Sin cambios.';

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='132_ENT_FUT_CONVAL' AND COLUMN_NAME='FE_CORTE')
BEGIN
    ALTER TABLE [RR].[132_ENT_FUT_CONVAL] DROP COLUMN [FE_CORTE];
    PRINT '>> Columna FE_CORTE eliminada.';
END
ELSE PRINT '>> FE_CORTE no existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   04 - SP SILVER: CREATE OR ALTER con correcciones
        Cambios:
        - Eliminado calculo de ventana mensual (@FechaIni/@FechaFin): codigo muerto.
        - WHERE del DELETE e INSERT usan @FechaDia = CAST(@FechaSistema AS DATE).
        - NOCIONAL, MON_NOCIONAL, FECHAINFO incluidos en INSERT y SELECT.
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

    DECLARE @MensajeError    NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion  BIT           = 1;
    DECLARE @FilasInsertadas INT           = 0;
    DECLARE @FilasEliminadas INT           = 0;
    DECLARE @LogMessage      NVARCHAR(MAX) = '';
    DECLARE @DetallesLog     NVARCHAR(MAX) = '';
    DECLARE @FechaInicio     DATETIME      = GETDATE();
    DECLARE @NombreJob       NVARCHAR(128) = '[132_ENT_FUT_CONVAL]';
    DECLARE @FechaDia        DATE          = CAST(@FechaSistema AS DATE);

    BEGIN TRY
        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[132_ENT_FUT_CONVAL]
            WHERE [FECHAINFO] = @FechaDia
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[132_ENT_FUT_CONVAL]
            WHERE [FECHAINFO] = @FechaDia;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END

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
            [NOCIONAL],
            [MON_NOCIONAL],
            [FECHAINFO]
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
            [NOCIONAL],
            [MON_NOCIONAL],
            @FechaDia
        FROM [SILVER].[RR].[132_ENT_FUT_CONVAL]
        WHERE [FECHAINFO] = @FechaDia;

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
PRINT '>> SILVER.dbo.[132_ENT_FUT_CONVAL] actualizado.';
GO

/* --------------------------------------------------------------------------
   05 - SP ION: CREATE OR ALTER con correcciones
        Cambios:
        - Removidos ID y FECHA_EXTRACCION del SELECT.
        - Agregados NOCIONAL, MON_NOCIONAL, FECHAINFO al SELECT.
        - Eliminado comentario muerto al final.
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

    -- NOTA: para 132 se conserva el nombre LITERAL del layout: FECHAINFO (sin guion bajo).
    -- NOTA (consideracion 12): salida de fechas en AAAA/MM/DD via FORMAT(...,'yyyy/MM/dd').
    -- NOTA (consideracion 13): orden segun la columna ORDEN del layout (21 campos; FECHAINFO ORDEN 21 -> ultima).
    -- NOTA: FE_CORTE, ACT_OPE_VAL y PAS_OPE_VAL NO son campos del layout (no existe seccion de
    --       'Campos Calculados' en OFF_FX_V11); se ELIMINARON tambien de la tabla. El filtro de
    --       la ventana ahora es FECHAINFO (antes era FE_CORTE).
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
        [NOCIONAL],
        [MON_NOCIONAL],
        FORMAT([FECHAINFO], 'yyyy/MM/dd') AS [FECHAINFO]
    FROM [SILVER].[RR].[132_ENT_FUT_CONVAL]
    WHERE [FECHAINFO] = @FECHA;
END;
GO
PRINT '>> ION.dbo.[132_ENT_FUT_CONVAL] actualizado.';
PRINT '>> Correccion 132_ENT_FUT_CONVAL completada.';
GO
