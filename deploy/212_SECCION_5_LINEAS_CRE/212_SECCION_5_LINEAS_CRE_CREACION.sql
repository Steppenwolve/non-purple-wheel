/* ============================================================================
   212_SECCION_5_LINEAS_CRE_CREACION.sql
   Reporte    : LID S5  (LID - Seccion 5: Uso/Ejercicio de Lineas de Credito Intradia)
   Objeto     : 212_SECCION_5_LINEAS_CRE   (SILVER e ION, mismo nombre)
   Layout     : LAYOUT LID V4 LID S5.xlsx  (hoja 'LID S5')
   Periodicidad : MENSUAL  (ventana mensual ACTIVA por FECHA_INFO)
   Patron     : Sigue el patron de los reportes existentes (080, 081, 083, 132,
                155, 156): el SP de SILVER hace INSERT ... SELECT sobre la MISMA
                tabla RR (sin landing BRONZE y sin transformacion de catalogos).
                Los valores de catalogo se arrastran tal cual (sin zero-pad).
   Idempotente : cada bloque verifica estado antes de actuar.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   01 - ION: verificar catalogos consumidos (solo consumo, no se crean ni llenan)
        Verificacion informativa; no bloquea el despliegue.
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET NOCOUNT ON;
DECLARE @cat TABLE (nombre SYSNAME);
INSERT INTO @cat VALUES
 ('repo_lakehouse_Catalogo_Moneda'),
 ('repo_lakehouse_Catalogo_Carcteristica_Linea'),
 ('repo_lakehouse_Catalogo_Tipo_Gar'),
 ('repo_lakehouse_Catalogo_Motivo_Ret');

SELECT  c.nombre AS catalogo_requerido,
        CASE WHEN o.object_id IS NULL THEN 'FALTA' ELSE 'OK' END AS estatus
FROM    @cat c
LEFT JOIN sys.objects o
       ON o.name = c.nombre AND o.schema_id = SCHEMA_ID('s3') AND o.type = 'U';
PRINT '>> Verificacion de catalogos (informativa) completada.';
GO

/* ----------------------------------------------------------------------------
   02 - SILVER  [RR].[212_SECCION_5_LINEAS_CRE]   (tabla de resultado regulatorio)
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = '212_SECCION_5_LINEAS_CRE' AND schema_id = SCHEMA_ID('RR') AND type = 'U')
BEGIN
    CREATE TABLE [RR].[212_SECCION_5_LINEAS_CRE]
    (
        [ID]               [uniqueidentifier] NOT NULL CONSTRAINT DF_212_SECCION_5_LINEAS_CRE_ID DEFAULT (NEWID()),
        [FECHA_EJE]         [date]            NOT NULL,
        [HORA_USO]          [varchar](5)      NOT NULL,
        [ID_LINEA]          [varchar](50)     NOT NULL,
        [FECHA_LIQ_L]       [date]            NOT NULL,
        [HORA_LIQ_L]        [varchar](5)      NULL,
        [MONTO_EJ_L]        [numeric](12, 0)  NOT NULL,
        [MONEDA_EJ_L]       [varchar](3)      NOT NULL,   -- cat Moneda
        [CAR_LINEA]         [varchar](1)      NOT NULL,   -- cat Carcteristica_Linea
        [PORC_CUBIERTO]     [numeric](5, 2)   NOT NULL,
        [TIPO_GAR]          [varchar](2)      NOT NULL,   -- cat Tipo_Gar
        [MONTO_PENALIZA]    [numeric](12, 0)  NOT NULL,
        [MOTIVO_REST]       [varchar](2)      NOT NULL,   -- cat Motivo_Ret
        [FECHA_INFO]        [date]            NOT NULL,
        [FECHA_EXTRACCION] [smalldatetime]   NOT NULL CONSTRAINT DF_212_SECCION_5_LINEAS_CRE_FEXT DEFAULT (GETDATE()),
        CONSTRAINT PK_RR_212_SECCION_5_LINEAS_CRE PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada SILVER.[RR].[212_SECCION_5_LINEAS_CRE].';
END
ELSE
    PRINT '>> SILVER.[RR].[212_SECCION_5_LINEAS_CRE] ya existe. Sin cambios.';
GO

/* ----------------------------------------------------------------------------
   03 - SILVER SP  [dbo].[212_SECCION_5_LINEAS_CRE]
        Ventana MENSUAL por FECHA_INFO. INSERT ... SELECT sobre la misma tabla RR
        (mismo patron que los reportes existentes). Catalogos sin transformacion.
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[212_SECCION_5_LINEAS_CRE]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[212_SECCION_5_LINEAS_CRE]';
    DECLARE @FechaIni        DATE,
            @FechaFin        DATE;

    BEGIN TRY
        -- Ventana MENSUAL por FECHA_INFO
        SET @FechaIni = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
        SET @FechaFin = DATEADD(MONTH, 1, @FechaIni);

        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[212_SECCION_5_LINEAS_CRE]
                   WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin)
        BEGIN
            DELETE FROM [SILVER].[RR].[212_SECCION_5_LINEAS_CRE]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
        END

        --------------------------------------------------------------------------------
        -- QUERY (mismo patron que los reportes existentes: INSERT ... SELECT sobre RR)
        INSERT INTO [RR].[212_SECCION_5_LINEAS_CRE] (
            [FECHA_EJE], [HORA_USO], [ID_LINEA], [FECHA_LIQ_L], [HORA_LIQ_L],
            [MONTO_EJ_L], [MONEDA_EJ_L], [CAR_LINEA], [PORC_CUBIERTO], [TIPO_GAR],
            [MONTO_PENALIZA], [MOTIVO_REST], [FECHA_INFO]
        )
        SELECT
            [FECHA_EJE], [HORA_USO], [ID_LINEA], [FECHA_LIQ_L], [HORA_LIQ_L],
            [MONTO_EJ_L], [MONEDA_EJ_L], [CAR_LINEA], [PORC_CUBIERTO], [TIPO_GAR],
            [MONTO_PENALIZA], [MOTIVO_REST], [FECHA_INFO]
        FROM [SILVER].[RR].[212_SECCION_5_LINEAS_CRE]
        WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;
        --------------------------------------------------------------------------------

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError   = ERROR_MESSAGE();
        SET @LogMessage     = 'Error durante la ejecucion: ' + @MensajeError;
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
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
            '- Programado por: ' + ISNULL(@ProgramadorJob, 'No especificado') + CHAR(13)+CHAR(10) +
            '- Inicio: '         + CONVERT(VARCHAR, @FechaInicio, 120)         + CHAR(13)+CHAR(10) +
            '- Fin: '            + CONVERT(VARCHAR, @FechaFinalizacion, 120)    + CHAR(13)+CHAR(10) +
            '- Duracion: '       + @DuracionEjecucion + CHAR(13)+CHAR(10) +
            'Error: '            + @MensajeError      + CHAR(13)+CHAR(10) +
            'Log: '              + @DetallesLog;
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

    SET @LogMessage = 'Proceso completado y registrado en la tabla de log.';
    PRINT @LogMessage;
END;
GO
PRINT '>> Creado/actualizado SILVER.dbo.[212_SECCION_5_LINEAS_CRE].';
GO

/* ----------------------------------------------------------------------------
   04 - ION SP  [dbo].[212_SECCION_5_LINEAS_CRE]   (extraccion regulatoria)
        Ventana MENSUAL por FECHA_INFO. Fechas en AAAA/MM/DD (consideracion 12).
        Orden de columnas segun 'COLUMNA REPORTE APLICA'. Sin ID ni FECHA_EXTRACCION.
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[212_SECCION_5_LINEAS_CRE]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE, @FechaFin DATE;
    SET @FechaIni = DATEFROMPARTS(YEAR(@FECHA), MONTH(@FECHA), 1);
    SET @FechaFin = DATEADD(MONTH, 1, @FechaIni);

    -- NOTA (consideracion 12): salida en AAAA/MM/DD, conforme al layout LID S5.
    -- NOTA (consideracion 13): orden de columnas segun la columna ORDEN del layout
    -- (FECHA_INFO es ORDEN 13 -> ultima columna).
    SELECT
        FORMAT([FECHA_EJE], 'yyyy/MM/dd')    AS FECHA_EJE,
        [HORA_USO]                         AS HORA_USO,
        [ID_LINEA]                         AS ID_LINEA,
        FORMAT([FECHA_LIQ_L], 'yyyy/MM/dd')  AS FECHA_LIQ_L,
        [HORA_LIQ_L]                       AS HORA_LIQ_L,
        [MONTO_EJ_L]                       AS MONTO_EJ_L,
        [MONEDA_EJ_L]                      AS MONEDA_EJ_L,
        [CAR_LINEA]                        AS CAR_LINEA,
        [PORC_CUBIERTO]                    AS PORC_CUBIERTO,
        [TIPO_GAR]                         AS TIPO_GAR,
        [MONTO_PENALIZA]                   AS MONTO_PENALIZA,
        [MOTIVO_REST]                      AS MOTIVO_REST,
        FORMAT([FECHA_INFO], 'yyyy/MM/dd')   AS FECHA_INFO
    FROM [SILVER].[RR].[212_SECCION_5_LINEAS_CRE]
    WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin
    ORDER BY [FECHA_EJE], [ID_LINEA];
END;
GO
PRINT '>> Creado/actualizado ION.dbo.[212_SECCION_5_LINEAS_CRE].';
-- Prueba: EXEC [dbo].[212_SECCION_5_LINEAS_CRE] @FECHA = '20260131';
GO

/* ----------------------------------------------------------------------------
   05 - ION.dbo.INDICE_REPORTES : registrar reporte 212 (LID S5)
        numero=212, nombre='SECCION_5_LINEAS_CRE', frecuencia='Mensual', activo=0, nombre_archivo=NULL.
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 212)
BEGIN
    UPDATE dbo.INDICE_REPORTES
       SET nombre = 'SECCION_5_LINEAS_CRE', frecuencia = 'Mensual', activo = 0, nombre_archivo = NULL
     WHERE numero = 212;
    PRINT '>> Actualizado registro 212 (SECCION_5_LINEAS_CRE) en ION.dbo.INDICE_REPORTES.';
END
ELSE
BEGIN
    INSERT INTO dbo.INDICE_REPORTES (numero, nombre, frecuencia, activo, nombre_archivo)
    VALUES (212, 'SECCION_5_LINEAS_CRE', 'Mensual', 0, NULL);
    PRINT '>> Insertado registro 212 (SECCION_5_LINEAS_CRE) en ION.dbo.INDICE_REPORTES.';
END
GO
PRINT '>> Creacion 212_SECCION_5_LINEAS_CRE completada.';
GO
