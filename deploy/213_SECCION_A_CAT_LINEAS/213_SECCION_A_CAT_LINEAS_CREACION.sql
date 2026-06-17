/* ============================================================================
   213_SECCION_A_CAT_LINEAS_CREACION.sql
   Reporte    : LID SA  (LID - Seccion A: Catalogo de Lineas de Credito Intradia)
   Objeto     : 213_SECCION_A_CAT_LINEAS   (SILVER e ION, mismo nombre)
   Layout     : LAYOUT LID V4 LID SA.xlsx  (hoja 'LID SA')
   Periodicidad : MENSUAL  (ventana mensual ACTIVA por FECHA_INFO)
   Patron     : Sigue el patron de los reportes existentes (080, 081, 083, 132,
                155, 156): el SP de SILVER hace INSERT ... SELECT sobre la MISMA
                tabla RR (sin landing BRONZE y sin transformacion de catalogos).
                Los valores de catalogo se arrastran tal cual (sin zero-pad).
   Relacion   : Es el catalogo (Seccion A) que valida el ID_LINEA del reporte
                LID S5 (212_SECCION_5_LINEAS_CRE).
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
 ('repo_lakehouse_Catalogo_Tipo_Linea'),
 ('repo_lakehouse_Catalogo_Moneda'),
 ('repo_lakehouse_Catalogo_Modif_Linea');

SELECT  c.nombre AS catalogo_requerido,
        CASE WHEN o.object_id IS NULL THEN 'FALTA' ELSE 'OK' END AS estatus
FROM    @cat c
LEFT JOIN sys.objects o
       ON o.name = c.nombre AND o.schema_id = SCHEMA_ID('s3') AND o.type = 'U';
PRINT '>> Verificacion de catalogos (informativa) completada.';
GO

/* ----------------------------------------------------------------------------
   02 - SILVER  [RR].[213_SECCION_A_CAT_LINEAS]   (tabla de resultado regulatorio)
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = '213_SECCION_A_CAT_LINEAS' AND schema_id = SCHEMA_ID('RR') AND type = 'U')
BEGIN
    CREATE TABLE [RR].[213_SECCION_A_CAT_LINEAS]
    (
        [ID]               [uniqueidentifier] NOT NULL CONSTRAINT DF_213_SECCION_A_CAT_LINEAS_ID DEFAULT (NEWID()),
        [FECHA_OTORG_L]     [date]            NOT NULL,
        [FECHA_MODIF_L]     [date]            NOT NULL,
        [FECHA_VENC_L]      [date]            NOT NULL,
        [ID_LINEA]          [varchar](50)     NOT NULL,
        [ID_CONTRAPARTE]    [varchar](6)      NOT NULL,
        [TIPO_LINEA]        [varchar](1)      NOT NULL,   -- cat Tipo_Linea
        [MONEDA_L]          [varchar](3)      NOT NULL,   -- cat Moneda
        [IND_CAMBIOS_L]     [varchar](1)      NOT NULL,   -- cat Modif_Linea
        [MONTO_LINEA]       [numeric](12, 0)  NOT NULL,
        [FECHA_INFO]        [date]            NOT NULL,
        [FECHA_EXTRACCION] [smalldatetime]   NOT NULL CONSTRAINT DF_213_SECCION_A_CAT_LINEAS_FEXT DEFAULT (GETDATE()),
        CONSTRAINT PK_RR_213_SECCION_A_CAT_LINEAS PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada SILVER.[RR].[213_SECCION_A_CAT_LINEAS].';
END
ELSE
    PRINT '>> SILVER.[RR].[213_SECCION_A_CAT_LINEAS] ya existe. Sin cambios.';
GO

/* ----------------------------------------------------------------------------
   03 - SILVER SP  [dbo].[213_SECCION_A_CAT_LINEAS]
        Ventana MENSUAL por FECHA_INFO. INSERT ... SELECT sobre la misma tabla RR
        (mismo patron que los reportes existentes). Catalogos sin transformacion.
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[213_SECCION_A_CAT_LINEAS]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[213_SECCION_A_CAT_LINEAS]';
    DECLARE @FechaIni        DATE,
            @FechaFin        DATE;

    BEGIN TRY
        -- Ventana MENSUAL por FECHA_INFO
        SET @FechaIni = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
        SET @FechaFin = DATEADD(MONTH, 1, @FechaIni);

        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[213_SECCION_A_CAT_LINEAS]
                   WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin)
        BEGIN
            DELETE FROM [SILVER].[RR].[213_SECCION_A_CAT_LINEAS]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
        END

        --------------------------------------------------------------------------------
        -- QUERY (mismo patron que los reportes existentes: INSERT ... SELECT sobre RR)
        INSERT INTO [RR].[213_SECCION_A_CAT_LINEAS] (
            [FECHA_OTORG_L], [FECHA_MODIF_L], [FECHA_VENC_L], [ID_LINEA], [ID_CONTRAPARTE],
            [TIPO_LINEA], [MONEDA_L], [IND_CAMBIOS_L], [MONTO_LINEA], [FECHA_INFO]
        )
        SELECT
            [FECHA_OTORG_L], [FECHA_MODIF_L], [FECHA_VENC_L], [ID_LINEA], [ID_CONTRAPARTE],
            [TIPO_LINEA], [MONEDA_L], [IND_CAMBIOS_L], [MONTO_LINEA], [FECHA_INFO]
        FROM [SILVER].[RR].[213_SECCION_A_CAT_LINEAS]
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
PRINT '>> Creado/actualizado SILVER.dbo.[213_SECCION_A_CAT_LINEAS].';
GO

/* ----------------------------------------------------------------------------
   04 - ION SP  [dbo].[213_SECCION_A_CAT_LINEAS]   (extraccion regulatoria)
        Ventana MENSUAL por FECHA_INFO. Fechas en AAAA/MM/DD (consideracion 12).
        Orden de columnas segun 'COLUMNA REPORTE APLICA'. Sin ID ni FECHA_EXTRACCION.
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[213_SECCION_A_CAT_LINEAS]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE, @FechaFin DATE;
    SET @FechaIni = DATEFROMPARTS(YEAR(@FECHA), MONTH(@FECHA), 1);
    SET @FechaFin = DATEADD(MONTH, 1, @FechaIni);

    -- NOTA (consideracion 12): salida en AAAA/MM/DD, conforme al layout LID SA.
    -- NOTA (consideracion 13): orden de columnas segun la columna ORDEN del layout
    -- (FECHA_INFO es ORDEN 10 -> ultima columna).
    SELECT
        FORMAT([FECHA_OTORG_L], 'yyyy/MM/dd') AS FECHA_OTORG_L,
        FORMAT([FECHA_MODIF_L], 'yyyy/MM/dd') AS FECHA_MODIF_L,
        FORMAT([FECHA_VENC_L], 'yyyy/MM/dd')  AS FECHA_VENC_L,
        [ID_LINEA]                          AS ID_LINEA,
        [ID_CONTRAPARTE]                    AS ID_CONTRAPARTE,
        [TIPO_LINEA]                        AS TIPO_LINEA,
        [MONEDA_L]                          AS MONEDA_L,
        [IND_CAMBIOS_L]                     AS IND_CAMBIOS_L,
        [MONTO_LINEA]                       AS MONTO_LINEA,
        FORMAT([FECHA_INFO], 'yyyy/MM/dd')    AS FECHA_INFO
    FROM [SILVER].[RR].[213_SECCION_A_CAT_LINEAS]
    WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin
    ORDER BY [ID_LINEA], [ID_CONTRAPARTE];
END;
GO
PRINT '>> Creado/actualizado ION.dbo.[213_SECCION_A_CAT_LINEAS].';
-- Prueba: EXEC [dbo].[213_SECCION_A_CAT_LINEAS] @FECHA = '20260131';
GO

/* ----------------------------------------------------------------------------
   05 - ION.dbo.INDICE_REPORTES : registrar reporte 213 (LID SA)
        numero=213, nombre='SECCION_A_CAT_LINEAS', frecuencia='Mensual', activo=0, nombre_archivo=NULL.
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 213)
BEGIN
    UPDATE dbo.INDICE_REPORTES
       SET nombre = 'SECCION_A_CAT_LINEAS', frecuencia = 'Mensual', activo = 0, nombre_archivo = NULL
     WHERE numero = 213;
    PRINT '>> Actualizado registro 213 (SECCION_A_CAT_LINEAS) en ION.dbo.INDICE_REPORTES.';
END
ELSE
BEGIN
    INSERT INTO dbo.INDICE_REPORTES (numero, nombre, frecuencia, activo, nombre_archivo)
    VALUES (213, 'SECCION_A_CAT_LINEAS', 'Mensual', 0, NULL);
    PRINT '>> Insertado registro 213 (SECCION_A_CAT_LINEAS) en ION.dbo.INDICE_REPORTES.';
END
GO
PRINT '>> Creacion 213_SECCION_A_CAT_LINEAS completada.';
GO
