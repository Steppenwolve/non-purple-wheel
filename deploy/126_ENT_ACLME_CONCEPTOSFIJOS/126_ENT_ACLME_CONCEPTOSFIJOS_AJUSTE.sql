-- ============================================================
-- AJUSTE  126_ENT_ACLME_CONCEPTOSFIJOS  (ACLME Conceptos Fijos)
-- Insumo  : Layout_ACLME_ConceptosFijos_v3/v4
-- Origen   : BRONZE.LMDA.ACLME (mismo insumo que 125; otra presentacion)
-- Destino  : SILVER.RR.126_ENT_ACLME_CONCEPTOSFIJOS   Frecuencia: Diaria
--
-- Transformacion (BRONZE -> SILVER):
--   * Se asigna un CONCEPTO a cada movimiento por (MONEDA, TIPO_OPERACION),
--     via catalogo BRONZE.RR.CATALOGO_CONCEPTOS_PLAZO_FIJO_ACLME (no hardcodeado).
--       USD + (SW|FX) -> 9725 Compras de Spots
--       MXN + FX      -> 9730 Ventas de Spots
--       USD + FW      -> 9890 Compras de Forwards
--       MXN + FW      -> 9900 Venta de Forwards
--     (SW+MXN no mapea -> se descarta; swaps 9895/9910 no se producen, segun reglas)
--   * IMPORTE = SUM(MONTO) agrupado por CONCEPTO (NO se agrupa por INSTITUCION).
--   * MONEDA='USD' fija ; RESERVAS='N/A' (se guarda 0, ION emite 'N/A') ; FECHA_INFO=FechaReporte.
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
        [IMPORTE]          numeric(15,8)    NOT NULL,
        [MONEDA]           varchar(3)       NOT NULL,
        [RESERVAS]         numeric(15,8)    NULL,
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

-- ============================================================
-- SECTION 01C | BRONZE.[RR].[CATALOGO_CONCEPTOS_PLAZO_FIJO_ACLME]
--   Mapeo (MONEDA, TIPO_OPERACION) -> CONCEPTO. El SP hace JOIN (no hardcodeo).
-- ============================================================
USE [BRONZE]
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='CATALOGO_CONCEPTOS_PLAZO_FIJO_ACLME')
BEGIN
    CREATE TABLE [RR].[CATALOGO_CONCEPTOS_PLAZO_FIJO_ACLME] (
        [MONEDA]         varchar(3)   NOT NULL,
        [TIPO_OPERACION] varchar(5)   NOT NULL,
        [CONCEPTO]       numeric(5,0) NOT NULL,
        [DESCRIPCION]    varchar(100) NOT NULL,
        CONSTRAINT [PK_RR_CAT_CONCEPTOS_PLAZO_FIJO_ACLME] PRIMARY KEY ([MONEDA],[TIPO_OPERACION])
    );
    PRINT 'BRONZE.RR.CATALOGO_CONCEPTOS_PLAZO_FIJO_ACLME creada.';
END
ELSE
    PRINT 'BRONZE.RR.CATALOGO_CONCEPTOS_PLAZO_FIJO_ACLME ya existe.';
GO
MERGE [RR].[CATALOGO_CONCEPTOS_PLAZO_FIJO_ACLME] AS t
USING (VALUES
    ('USD','SW',9725,'Compras de Spots'),
    ('USD','FX',9725,'Compras de Spots'),
    ('MXN','FX',9730,'Ventas de Spots'),
    ('USD','FW',9890,'Compras de Forwards'),
    ('MXN','FW',9900,'Venta de Forwards')
) AS s([MONEDA],[TIPO_OPERACION],[CONCEPTO],[DESCRIPCION])
ON t.[MONEDA]=s.[MONEDA] AND t.[TIPO_OPERACION]=s.[TIPO_OPERACION]
WHEN MATCHED THEN UPDATE SET t.[CONCEPTO]=s.[CONCEPTO], t.[DESCRIPCION]=s.[DESCRIPCION]
WHEN NOT MATCHED THEN INSERT ([MONEDA],[TIPO_OPERACION],[CONCEPTO],[DESCRIPCION])
    VALUES (s.[MONEDA],s.[TIPO_OPERACION],s.[CONCEPTO],s.[DESCRIPCION]);
PRINT 'Catalogo de conceptos poblado.';
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
            cat.[CONCEPTO],                 -- concepto (catalogo por MONEDA+TIPO_OPERACION)
            cat.[DESCRIPCION],              -- auxiliar
            COUNT(*),                       -- auxiliar: movimientos sumados
            MAX(A.[INSTITUCION]),           -- INSTITUCION (constante por corrida; no es llave de agrupacion)
            SUM(A.[MONTO]),                 -- IMPORTE = suma del monto por concepto
            'USD',                          -- MONEDA (constante)
            0,                              -- RESERVAS: fijo (se guarda 0; ION emite 'N/A')
            @FechaRef                       -- FECHA_INFO
        FROM [BRONZE].[LMDA].[ACLME] A
        INNER JOIN [BRONZE].[RR].[CATALOGO_CONCEPTOS_PLAZO_FIJO_ACLME] cat
                ON cat.[MONEDA] = A.[MONEDA] AND cat.[TIPO_OPERACION] = A.[TIPO_OPERACION]
        WHERE CAST(A.[FECHA_EXTRACCION] AS DATE) = @FechaRef      -- Opcion A: lote del dia
        GROUP BY cat.[CONCEPTO], cat.[DESCRIPCION];              -- NO se agrupa por INSTITUCION

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
