-- ============================================================
-- AJUSTE  075_ENT_TENENCIA_REPAD
-- Layout : LayoutTenencia_V2_FT_TENENCIA
-- Periodicidad  : Semanal
-- Origen        : LMDA (BRONZE.LMDA.FT_TENENCIA)
-- Segmentacion  : FECHA_EXTRACCION (el CSV fuente no contiene FECHA_INFO)
-- Reporte       : FILE_TENENCIA (nombre a confirmar)
-- ============================================================

-- ============================================================
-- SECTION 00 | BRONZE.[LMDA].[FT_TENENCIA]
--   sp_rename x11: camelCase -> UPPERCASE segun layout
-- ============================================================
USE [BRONZE]
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='TituloObjeto')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].TituloObjeto',          'TITULOOBJETO',          'COLUMN';
GO
USE [BRONZE]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='NumeroTitulos')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].NumeroTitulos',          'NUMEROTITULOS',          'COLUMN';
GO
USE [BRONZE]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='Contraparte')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].Contraparte',            'CONTRAPARTE',            'COLUMN';
GO
USE [BRONZE]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='Moneda')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].Moneda',                 'MONEDA',                 'COLUMN';
GO
USE [BRONZE]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='PrecioUnitario')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].PrecioUnitario',         'PRECIOUNITARIO',         'COLUMN';
GO
USE [BRONZE]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='PrecioValMercado')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].PrecioValMercado',       'PRECIO_VAL_MERCADO',     'COLUMN';
GO
USE [BRONZE]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='ClasificacionContable')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].ClasificacionContable',  'CLASIFICACIONCONTABLE',  'COLUMN';
GO
USE [BRONZE]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='PosicionOperacion')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].PosicionOperacion',      'POSICIONOPERACION',      'COLUMN';
GO
USE [BRONZE]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='CveTipoInstrumento')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].CveTipoInstrumento',     'CVETIPOINSTRUMENTO',     'COLUMN';
GO
USE [BRONZE]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='Oficina')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].Oficina',                'OFICINA',                'COLUMN';
GO
USE [BRONZE]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_TENENCIA' AND COLUMN_NAME='DepositadoEnGarantia')
    EXEC sp_rename 'LMDA.[FT_TENENCIA].DepositadoEnGarantia',   'DEPOSITADOENGARANTIA',   'COLUMN';
GO

-- ============================================================
-- SECTION 01 | SILVER.[RR].[075_ENT_TENENCIA_REPAD]
--   sp_rename x11: camelCase -> UPPERCASE segun layout
-- ============================================================
USE [SILVER]
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='TituloObjeto')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].TituloObjeto',          'TITULOOBJETO',          'COLUMN';
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='NumeroTitulos')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].NumeroTitulos',          'NUMEROTITULOS',          'COLUMN';
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='Contraparte')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].Contraparte',            'CONTRAPARTE',            'COLUMN';
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='Moneda')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].Moneda',                 'MONEDA',                 'COLUMN';
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='PrecioUnitario')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].PrecioUnitario',         'PRECIOUNITARIO',         'COLUMN';
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='PrecioValMercado')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].PrecioValMercado',       'PRECIO_VAL_MERCADO',     'COLUMN';
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='ClasificacionContable')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].ClasificacionContable',  'CLASIFICACIONCONTABLE',  'COLUMN';
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='PosicionOperacion')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].PosicionOperacion',      'POSICIONOPERACION',      'COLUMN';
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='CveTipoInstrumento')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].CveTipoInstrumento',     'CVETIPOINSTRUMENTO',     'COLUMN';
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='Oficina')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].Oficina',                'OFICINA',                'COLUMN';
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='075_ENT_TENENCIA_REPAD' AND COLUMN_NAME='DepositadoEnGarantia')
    EXEC sp_rename 'RR.[075_ENT_TENENCIA_REPAD].DepositadoEnGarantia',   'DEPOSITADOENGARANTIA',   'COLUMN';
GO

-- ============================================================
-- SECTION 02 | SP SILVER — [dbo].[075_ENT_TENENCIA_REPAD]
--   Origen         : BRONZE.LMDA.FT_TENENCIA
--   Segmentacion   : FECHA_EXTRACCION (semanal)
--   Nota           : El CSV fuente no contiene FECHA_INFO;
--                    se usa FECHA_EXTRACCION del ETL como control de semana.
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[075_ENT_TENENCIA_REPAD]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[075_ENT_TENENCIA_REPAD] ';

    -- Ventana semanal basada en FECHA_EXTRACCION del ETL
    DECLARE @FechaIni DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @FechaSistema) + 5) % 7), CAST(@FechaSistema AS DATE));
    DECLARE @FechaFin DATE = DATEADD(DAY, 7, @FechaIni);

    BEGIN TRY --------------------------------------------------------------------------------

        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[075_ENT_TENENCIA_REPAD]
            WHERE [FECHA_EXTRACCION] >= @FechaIni AND [FECHA_EXTRACCION] < @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[075_ENT_TENENCIA_REPAD]
            WHERE [FECHA_EXTRACCION] >= @FechaIni AND [FECHA_EXTRACCION] < @FechaFin;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[075_ENT_TENENCIA_REPAD] (
            [TITULOOBJETO],
            [NUMEROTITULOS],
            [CONTRAPARTE],
            [MONEDA],
            [PRECIOUNITARIO],
            [PRECIO_VAL_MERCADO],
            [CLASIFICACIONCONTABLE],
            [POSICIONOPERACION],
            [CVETIPOINSTRUMENTO],
            [OFICINA],
            [DEPOSITADOENGARANTIA]
        )
        SELECT
            T.[TITULOOBJETO],
            T.[NUMEROTITULOS],
            T.[CONTRAPARTE],
            T.[MONEDA],
            T.[PRECIOUNITARIO],
            T.[PRECIO_VAL_MERCADO],
            T.[CLASIFICACIONCONTABLE],
            T.[POSICIONOPERACION],
            T.[CVETIPOINSTRUMENTO],
            T.[OFICINA],
            T.[DEPOSITADOENGARANTIA]
        FROM [BRONZE].[LMDA].[FT_TENENCIA] T
        WHERE T.[FECHA_EXTRACCION] >= @FechaIni AND T.[FECHA_EXTRACCION] < @FechaFin;

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

    DECLARE @FechaFinalizacion DATETIME = GETDATE();
    DECLARE @DuracionEjecucion VARCHAR(20) =
        CAST(DATEDIFF(SECOND, @FechaInicio, @FechaFinalizacion) AS VARCHAR(10)) + ' segundos';

    IF @ExitoEjecucion = 0
        AND @CorreoNotificacion IS NOT NULL
        AND @PerfilCorreo IS NOT NULL
    BEGIN
        DECLARE @Asunto NVARCHAR(255) = 'ALERTA: Error en ' + ISNULL(@NombreJob, 'Job Desconocido');
        DECLARE @Cuerpo NVARCHAR(MAX) = 'Error en ' + @NombreJob + CHAR(13) + CHAR(10)
            + 'Mensaje: ' + @MensajeError + CHAR(13) + CHAR(10)
            + 'Log: ' + @DetallesLog;

        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @PerfilCorreo,
                @recipients   = @CorreoNotificacion,
                @subject      = @Asunto,
                @body         = @Cuerpo,
                @body_format  = 'TEXT',
                @importance   = 'High';
        END TRY
        BEGIN CATCH
            PRINT 'Error al enviar alerta: ' + ERROR_MESSAGE();
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario (
        FechaEjecucion, FilasInsertadas, EstadoEjecucion,
        MensajeError, DetallesLog, NombreJob, ProgramadorJob
    )
    VALUES (
        @FechaInicio,
        @FilasInsertadas,
        CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion = 1 THEN NULL ELSE @MensajeError END,
        @DetallesLog,
        @NombreJob,
        @ProgramadorJob
    );

    PRINT 'Proceso completado y registrado en la tabla de log.';
END;
GO

-- ============================================================
-- SECTION 03 | SP ION — [dbo].[075_ENT_TENENCIA_REPAD]
--   Columnas: ORDEN 1-11 del layout
--   Sin ID ni FECHA_EXTRACCION en salida
--   Filtro semanal por SILVER.FECHA_EXTRACCION
--   Nota: FECHA_INFO no aplica; segmentacion por FECHA_EXTRACCION
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[075_ENT_TENENCIA_REPAD]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @FECHA) + 5) % 7), @FECHA);
    DECLARE @FechaFin DATE = DATEADD(DAY, 7, @FechaIni);

    SELECT
        T.[TITULOOBJETO]          AS [TITULOOBJETO],          -- ORDEN 1
        T.[NUMEROTITULOS]         AS [NUMEROTITULOS],         -- ORDEN 2
        T.[CONTRAPARTE]           AS [CONTRAPARTE],           -- ORDEN 3
        T.[MONEDA]                AS [MONEDA],                -- ORDEN 4
        T.[PRECIOUNITARIO]        AS [PRECIOUNITARIO],        -- ORDEN 5
        T.[PRECIO_VAL_MERCADO]    AS [PRECIO_VAL_MERCADO],    -- ORDEN 6
        T.[CLASIFICACIONCONTABLE] AS [CLASIFICACIONCONTABLE], -- ORDEN 7
        T.[POSICIONOPERACION]     AS [POSICIONOPERACION],     -- ORDEN 8
        T.[CVETIPOINSTRUMENTO]    AS [CVETIPOINSTRUMENTO],    -- ORDEN 9
        T.[OFICINA]               AS [OFICINA],               -- ORDEN 10
        T.[DEPOSITADOENGARANTIA]  AS [DEPOSITADOENGARANTIA]   -- ORDEN 11
    FROM [SILVER].[RR].[075_ENT_TENENCIA_REPAD] T
    WHERE T.[FECHA_EXTRACCION] >= @FechaIni AND T.[FECHA_EXTRACCION] < @FechaFin;

END;
GO

-- ============================================================
-- SECTION 04 | INDICE_REPORTES — corregir frecuencia
-- ============================================================
USE [ION]
GO

UPDATE [dbo].[INDICE_REPORTES]
SET [frecuencia] = 'Semanal'
WHERE [numero] = 75 AND [frecuencia] <> 'Semanal';

IF @@ROWCOUNT > 0
    PRINT 'INDICE_REPORTES 75: frecuencia actualizada a Semanal.';
ELSE
    PRINT 'INDICE_REPORTES 75: ya estaba en Semanal.';
GO
