-- ============================================================
-- AJUSTE  126_ENT_ACLME_CONCEPTOSFIJOS  (ACLME Conceptos Fijos)
-- Insumo  : Layout_ACLME_ConceptosFijos_v3/v4
-- Origen   : BRONZE.LMDA.ACLME (mismo insumo que 125; otra presentacion)
-- Destino  : SILVER.RR.126_ENT_ACLME_CONCEPTOSFIJOS   Frecuencia: Diaria
--
-- Transformacion (BRONZE -> SILVER):
--   * Se asigna un CONCEPTO a cada movimiento por (TIPO_OPERACION, MONEDA, MONEDA_MXN),
--     via catalogo BRONZE.RR.CAT_ACLME_CONCEPTOS_FIJOS (no hardcodeado).
--       FX  + USD + MXN -> 9725 COMPRA_SPOTS
--       SW  + USD + MXN -> 9725 COMPRA_SPOTS
--       FX  + MXN + USD -> 9730 VENTA_SPOTS
--       FW  + USD + MXN -> 9890 COMPRA_FORWARDS
--       FW  + MXN + USD -> 9900 VENTA_FORWARDS
--     (Operaciones sin match en el catalogo se descartan por INNER JOIN)
--   * IMPORTE = SUM(MONTO) agrupado por CONCEPTO. MONTO esta en USD.
--   * MONEDA='USD' fija ; RESERVAS='N/A' (se guarda 0, ION emite 'N/A') ; FECHA_INFO=FechaReporte.
--   * DESCRIPCION = OPERACION del catalogo (ej. COMPRA_SPOTS).
--   * Auxiliares persistidos por fila-concepto: DESCRIPCION y MOVIMIENTOS (conteo).
--   * Alcance entrada (Opcion A): lote del dia por FECHA_EXTRACCION = FechaReporte.
-- ============================================================

-- ============================================================
-- SECTION 00 | BRONZE.[LMDA].[ACLME] — verificar (mismo insumo que 125, ya incluye INSTITUCION)
-- ============================================================
USE [BRONZE]
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='ACLME')
    PRINT '>> ADVERTENCIA: BRONZE.LMDA.ACLME no existe. Aplicar primero el ajuste 125_ENT_ACLME.';
ELSE IF COL_LENGTH('LMDA.ACLME','INSTITUCION') IS NULL
    ALTER TABLE [LMDA].[ACLME] ADD [INSTITUCION] numeric(6,0) NOT NULL CONSTRAINT [DF_LMDA_ACLME_INSTITUCION] DEFAULT (0);
GO

-- ============================================================
-- SECTION 01 | SILVER.[RR].[126_ENT_ACLME_CONCEPTOSFIJOS]
--   Existe en prod con CONCEPTO/IMPORTE/MONEDA/RESERVAS/FECHA_INFO.
--   Se agregan INSTITUCION (layout) + auxiliares DESCRIPCION, MOVIMIENTOS.
-- ============================================================
USE [SILVER]
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='126_ENT_ACLME_CONCEPTOSFIJOS')
BEGIN
    CREATE TABLE [RR].[126_ENT_ACLME_CONCEPTOSFIJOS] (
        [ID]               uniqueidentifier NOT NULL CONSTRAINT [DF_RR_126_CF_ID] DEFAULT (NEWID()),
        [CONCEPTO]         numeric(5,0)     NOT NULL,
        [DESCRIPCION]      varchar(100)     NULL,     -- auxiliar
        [MOVIMIENTOS]      int              NULL,     -- auxiliar (conteo de movimientos sumados)
        [INSTITUCION]      numeric(6,0)     NOT NULL CONSTRAINT [DF_RR_126_CF_INSTITUCION] DEFAULT (0),
        [IMPORTE]          numeric(23,8)    NOT NULL,   -- 15 enteros + 8 decimales (el SUM en prod llega a 10 enteros)
        [MONEDA]           varchar(3)       NOT NULL,
        [RESERVAS]         numeric(23,8)    NULL,
        [FECHA_INFO]       date             NOT NULL,
        [FECHA_EXTRACCION] smalldatetime    NOT NULL CONSTRAINT [DF_RR_126_CF_FE] DEFAULT (GETDATE())
    );
    PRINT 'SILVER.RR.126_ENT_ACLME_CONCEPTOSFIJOS creada.';
END
ELSE
    PRINT 'SILVER.RR.126_ENT_ACLME_CONCEPTOSFIJOS ya existe — se verifican columnas nuevas.';
GO
IF COL_LENGTH('RR.126_ENT_ACLME_CONCEPTOSFIJOS','INSTITUCION') IS NULL
    ALTER TABLE [RR].[126_ENT_ACLME_CONCEPTOSFIJOS] ADD [INSTITUCION] numeric(6,0) NOT NULL CONSTRAINT [DF_RR_126_CF_INSTITUCION] DEFAULT (0);
GO
IF COL_LENGTH('RR.126_ENT_ACLME_CONCEPTOSFIJOS','DESCRIPCION') IS NULL
    ALTER TABLE [RR].[126_ENT_ACLME_CONCEPTOSFIJOS] ADD [DESCRIPCION] varchar(100) NULL;
GO
IF COL_LENGTH('RR.126_ENT_ACLME_CONCEPTOSFIJOS','MOVIMIENTOS') IS NULL
    ALTER TABLE [RR].[126_ENT_ACLME_CONCEPTOSFIJOS] ADD [MOVIMIENTOS] int NULL;
GO
-- IMPORTE/RESERVAS: ampliar a numeric(23,8) si vienen como (15,8) (evita overflow del SUM en prod)
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='126_ENT_ACLME_CONCEPTOSFIJOS' AND COLUMN_NAME='IMPORTE' AND NUMERIC_PRECISION<23)
    ALTER TABLE [RR].[126_ENT_ACLME_CONCEPTOSFIJOS] ALTER COLUMN [IMPORTE] numeric(23,8) NOT NULL;
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='126_ENT_ACLME_CONCEPTOSFIJOS' AND COLUMN_NAME='RESERVAS' AND NUMERIC_PRECISION<23)
    ALTER TABLE [RR].[126_ENT_ACLME_CONCEPTOSFIJOS] ALTER COLUMN [RESERVAS] numeric(23,8) NULL;
GO

-- ============================================================
-- SECTION 01C | BRONZE.[RR].[CAT_ACLME_CONCEPTOS_FIJOS]
--   Mapeo (TIPO_OPERACION, MONEDA, MONEDA_MXN) -> CONCEPTO + OPERACION.
--   DESCRIPCION en SILVER = OPERACION del catalogo.
-- ============================================================
USE [BRONZE]
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='CAT_ACLME_CONCEPTOS_FIJOS')
BEGIN
    CREATE TABLE [RR].[CAT_ACLME_CONCEPTOS_FIJOS] (
        [CONCEPTO]       int          NOT NULL,
        [OPERACION]      varchar(50)  NOT NULL,
        [TIPO_OPERACION] varchar(10)  NOT NULL,
        [MONEDA]         varchar(10)  NOT NULL,
        [MONEDA_MXN]     varchar(10)  NOT NULL,
        CONSTRAINT [PK_RR_CAT_ACLME_CONCEPTOS_FIJOS] PRIMARY KEY ([TIPO_OPERACION],[MONEDA],[MONEDA_MXN])
    );
    PRINT 'BRONZE.RR.CAT_ACLME_CONCEPTOS_FIJOS creada.';
END
ELSE
    PRINT 'BRONZE.RR.CAT_ACLME_CONCEPTOS_FIJOS ya existe.';
GO
MERGE [RR].[CAT_ACLME_CONCEPTOS_FIJOS] AS t
USING (VALUES
    (9725, 'COMPRA_SPOTS',    'SW', 'USD', 'MXN'),
    (9725, 'COMPRA_SPOTS',    'FX', 'USD', 'MXN'),
    (9730, 'VENTA_SPOTS',     'FX', 'MXN', 'USD'),
    (9890, 'COMPRA_FORWARDS', 'FW', 'USD', 'MXN'),
    (9900, 'VENTA_FORWARDS',  'FW', 'MXN', 'USD')
) AS s([CONCEPTO],[OPERACION],[TIPO_OPERACION],[MONEDA],[MONEDA_MXN])
ON t.[TIPO_OPERACION]=s.[TIPO_OPERACION] AND t.[MONEDA]=s.[MONEDA] AND t.[MONEDA_MXN]=s.[MONEDA_MXN]
WHEN MATCHED THEN UPDATE SET t.[CONCEPTO]=s.[CONCEPTO], t.[OPERACION]=s.[OPERACION]
WHEN NOT MATCHED THEN INSERT ([CONCEPTO],[OPERACION],[TIPO_OPERACION],[MONEDA],[MONEDA_MXN])
    VALUES (s.[CONCEPTO],s.[OPERACION],s.[TIPO_OPERACION],s.[MONEDA],s.[MONEDA_MXN]);
PRINT 'Catalogo CAT_ACLME_CONCEPTOS_FIJOS poblado.';
GO

-- ============================================================
-- SECTION 02 | SP SILVER — [dbo].[126_ENT_ACLME_CONCEPTOSFIJOS]
--   Corrige el stub (self-select + mensual). Agrega por CONCEPTO. Filtro DIARIO.
-- ============================================================
USE [SILVER]
GO
CREATE OR ALTER PROCEDURE [dbo].[126_ENT_ACLME_CONCEPTOSFIJOS]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[126_ENT_ACLME_CONCEPTOSFIJOS]';
    DECLARE @FechaRef        DATE          = CAST(@FechaSistema AS DATE);

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[126_ENT_ACLME_CONCEPTOSFIJOS] WHERE [FECHA_INFO] = @FechaRef)
        BEGIN
            DELETE FROM [SILVER].[RR].[126_ENT_ACLME_CONCEPTOSFIJOS] WHERE [FECHA_INFO] = @FechaRef;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[126_ENT_ACLME_CONCEPTOSFIJOS] (
            [CONCEPTO], [DESCRIPCION], [MOVIMIENTOS], [INSTITUCION],
            [IMPORTE], [MONEDA], [RESERVAS], [FECHA_INFO]
        )
        SELECT
            C.[CONCEPTO],
            C.[OPERACION],                  -- DESCRIPCION = OPERACION del catalogo
            COUNT(*),                       -- auxiliar: movimientos sumados
            MAX(A.[INSTITUCION]),           -- INSTITUCION (constante por corrida; no es llave de agrupacion)
            SUM(A.[MONTO]),                 -- IMPORTE = suma del monto en USD por concepto
            'USD',                          -- MONEDA (constante)
            0,                              -- RESERVAS: fijo (se guarda 0; ION emite 'N/A')
            @FechaRef                       -- FECHA_INFO
        FROM [BRONZE].[LMDA].[ACLME] A
        INNER JOIN [BRONZE].[RR].[CAT_ACLME_CONCEPTOS_FIJOS] C
                ON A.[TIPO_OPERACION] = C.[TIPO_OPERACION]
               AND A.[MONEDA]         = C.[MONEDA]
               AND A.[MONEDA_MXN]     = C.[MONEDA_MXN]
        WHERE CAST(A.[FECHA_EXTRACCION] AS DATE) = @FechaRef      -- Opcion A: lote del dia
        GROUP BY C.[CONCEPTO], C.[OPERACION];

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
-- SECTION 03 | SP ION — [dbo].[126_ENT_ACLME_CONCEPTOSFIJOS]
--   Salida conforme al layout (6 columnas). Auxiliares quedan solo en SILVER.
-- ============================================================
USE [ION]
GO
CREATE OR ALTER PROCEDURE [dbo].[126_ENT_ACLME_CONCEPTOSFIJOS]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        T.[CONCEPTO]                          AS [CONCEPTO],        -- ORDEN 1
        FORMAT(T.[INSTITUCION], '000000')     AS [INSTITUCION],     -- ORDEN 2 (TEXTO 6, zero-pad)
        T.[IMPORTE]                           AS [IMPORTE],         -- ORDEN 3
        T.[MONEDA]                            AS [MONEDA],          -- ORDEN 4
        'N/A'                                 AS [RESERVAS],        -- ORDEN 5 (SILVER guarda 0; se emite 'N/A')
        FORMAT(T.[FECHA_INFO], 'yyyy/MM/dd')  AS [FECHA_INFO]       -- ORDEN 6
    FROM [SILVER].[RR].[126_ENT_ACLME_CONCEPTOSFIJOS] T
    WHERE T.[FECHA_INFO] = @FECHA;
END;
GO

-- ============================================================
-- SECTION 04 | INDICE_REPORTES — registrar reporte 126 (Diaria)
-- ============================================================
USE [ION]
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[INDICE_REPORTES] WHERE [numero] = 126)
    INSERT INTO [dbo].[INDICE_REPORTES] ([numero], [nombre], [frecuencia], [activo], [nombre_archivo])
    VALUES (126, 'ENT_ACLME_CONCEPTOSFIJOS', 'Diaria', 1, 'ACLME_CONCEPTOSFIJOS');

SELECT numero, nombre, frecuencia, activo, nombre_archivo FROM dbo.INDICE_REPORTES WHERE numero = 126;
GO
