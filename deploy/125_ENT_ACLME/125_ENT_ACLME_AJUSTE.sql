-- ============================================================
-- AJUSTE  125_ENT_ACLME  (ACLME Seccion I-V)
-- Insumo  : Layouts_ACLME_SECCION_I_V_v3
-- Origen   : BRONZE.LMDA.ACLME      Destino: SILVER.RR.125_ENT_ACLME
-- Frecuencia: Diaria
-- Transformacion (BRONZE -> SILVER) segun formulas del Excel:
--   PLAZO     = FECHA_INICIO - FechaReporte   (regla 1; se sigue la formula, NO dias por vencer)
--               -> solo se reportan operaciones con PLAZO >= 1 dia
--   POSICION  = USD -> Compra (C) ; MXN -> Venta (V)                (regla 2)
--   LLAVE     = POSICION + (TIPO='SW' -> 'FX', si no el propio TIPO) (regla 3-4; SW se trata como spot)
--   CLAVE     = VLOOKUP(LLAVE): CFX->3515 CFW->3561 VFX->6415 VFW->6477
--   AMORTIZACION=1 · IMPORTE=MONTO · FECHA_AMORT=FECHA_VMTO · NUM_ID=ID_SISTEMA
--   MONEDA='USD' · RESERVAS='N/A'(Excel) · FECHA_INFO=FechaReporte
--   Alcance entrada (Opcion A): lote del dia por FECHA_EXTRACCION = FechaReporte
-- ============================================================

-- ============================================================
-- SECTION 00 | BRONZE.[LMDA].[ACLME] — verificar tabla de aterrizaje
--   (ya existe en el esquema restaurado; se crea solo si faltara)
-- ============================================================
USE [BRONZE]
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='ACLME')
BEGIN
    CREATE TABLE [LMDA].[ACLME] (
        [ID]                 uniqueidentifier NOT NULL CONSTRAINT [DF_LMDA_ACLME_ID] DEFAULT (NEWID()),
        [ID_SISTEMA]         varchar(20)      NOT NULL,
        [TIPO_OPERACION]     varchar(5)       NOT NULL,   -- SW / FX / FW
        [FECHA_CONCERTACION] date             NOT NULL,
        [FECHA_INICIO]       date             NOT NULL,
        [FECHA_VALOR]        date             NULL,
        [PLAZO]              numeric(18,0)    NOT NULL,
        [FECHA_VMTO]         date             NOT NULL,
        [MONTO]              numeric(18,2)    NOT NULL,
        [CONTRAPARTE]        varchar(20)      NOT NULL,
        [MONEDA]             varchar(3)       NOT NULL,   -- MXN / USD
        [TIPO_CAMBIO]        numeric(18,4)    NOT NULL,
        [MONTO_MXN]          numeric(18,2)    NOT NULL,
        [MONEDA_MXN]         varchar(3)       NOT NULL,
        [MEDIO]              varchar(20)      NULL,
        [BROKER]             varchar(20)      NULL,
        [TIPO_POSTURA]       varchar(20)      NULL,
        [HORA]               varchar(10)      NULL,
        [INSTITUCION]        numeric(6,0)     NOT NULL CONSTRAINT [DF_LMDA_ACLME_INSTITUCION] DEFAULT (0),  -- clave institucion (por cliente)
        [FECHA_EXTRACCION]   smalldatetime    NOT NULL CONSTRAINT [DF_LMDA_ACLME_FECHA_EXTRACCION] DEFAULT (GETDATE()),
        CONSTRAINT [PK_LMDA_ACLME] PRIMARY KEY ([ID])
    );
    PRINT 'BRONZE.LMDA.ACLME creada.';
END
ELSE
    PRINT 'BRONZE.LMDA.ACLME ya existe — se verifica columna INSTITUCION.';
GO
-- INSTITUCION: agregar si falta (tabla preexistente en local; en prod se crea de origen)
IF COL_LENGTH('LMDA.ACLME','INSTITUCION') IS NULL
    ALTER TABLE [LMDA].[ACLME] ADD [INSTITUCION] numeric(6,0) NOT NULL CONSTRAINT [DF_LMDA_ACLME_INSTITUCION] DEFAULT (0);
GO

-- ============================================================
-- SECTION 01 | SILVER.[RR].[125_ENT_ACLME] — verificar tabla destino
--   (ya existe; se crea solo si faltara)
-- ============================================================
USE [SILVER]
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='125_ENT_ACLME')
BEGIN
    CREATE TABLE [RR].[125_ENT_ACLME] (
        [ID]                     uniqueidentifier NOT NULL CONSTRAINT [DF_RR_125_ENT_ACLME_ID] DEFAULT (NEWID()),
        -- Columnas de AUDITORIA (calculo intermedio del SP; no forman parte del reporte ION)
        [PLAZO]                  numeric(18,0)    NULL,   -- FECHA_INICIO - FechaReporte
        [OPERACIONES_A_REPORTAR] varchar(5)       NULL,   -- tipo original (SW/FX/FW) de las reportadas
        [POSICION_OPERACION]     varchar(1)       NULL,   -- C=Compra / V=Venta
        [LLAVE]                  varchar(4)       NULL,   -- llave del VLOOKUP (CFX/CFW/VFX/VFW)
        [TIPO_OPERACION]         varchar(4)       NOT NULL,
        [INSTITUCION]            numeric(6,0)     NOT NULL CONSTRAINT [DF_RR_125_ENT_ACLME_INSTITUCION] DEFAULT (0),  -- clave institucion (por cliente)
        [AMORTIZACION]           numeric(5,0)     NOT NULL,
        [IMPORTE_AMORTIZACION]   numeric(18,6)    NOT NULL,
        [FECHA_AMORTIZACION]     date             NOT NULL,
        [NUMERO_IDENTIFICACION]  varchar(20)      NOT NULL,
        [MONEDA]                 varchar(3)       NOT NULL,
        [RESERVAS]               numeric(18,6)    NOT NULL,
        [FECHA_INFO]             date             NOT NULL,
        [FECHA_EXTRACCION]       smalldatetime    NOT NULL CONSTRAINT [DF_RR_125_ENT_ACLME_FECHA_EXTRACCION] DEFAULT (GETDATE())
    );
    PRINT 'SILVER.RR.125_ENT_ACLME creada.';
END
ELSE
    PRINT 'SILVER.RR.125_ENT_ACLME ya existe — se verifican columnas de auditoria e INSTITUCION.';
GO
IF COL_LENGTH('RR.125_ENT_ACLME','INSTITUCION') IS NULL
    ALTER TABLE [RR].[125_ENT_ACLME] ADD [INSTITUCION] numeric(6,0) NOT NULL CONSTRAINT [DF_RR_125_ENT_ACLME_INSTITUCION] DEFAULT (0);
GO
-- Auditoria: agregar columnas intermedias si faltan (tabla preexistente)
IF COL_LENGTH('RR.125_ENT_ACLME','PLAZO') IS NULL
    ALTER TABLE [RR].[125_ENT_ACLME] ADD [PLAZO] numeric(18,0) NULL;
GO
IF COL_LENGTH('RR.125_ENT_ACLME','OPERACIONES_A_REPORTAR') IS NULL
    ALTER TABLE [RR].[125_ENT_ACLME] ADD [OPERACIONES_A_REPORTAR] varchar(5) NULL;
GO
IF COL_LENGTH('RR.125_ENT_ACLME','POSICION_OPERACION') IS NULL
    ALTER TABLE [RR].[125_ENT_ACLME] ADD [POSICION_OPERACION] varchar(1) NULL;
GO
IF COL_LENGTH('RR.125_ENT_ACLME','LLAVE') IS NULL
    ALTER TABLE [RR].[125_ENT_ACLME] ADD [LLAVE] varchar(4) NULL;
GO

-- ============================================================
-- SECTION 01C | BRONZE.[RR].[CATALOGO_TIPO_OPERACION_ACLME]
--   Catalogo de Tipo de Operacion (equivalencias LLAVE -> CLAVE).
--   Externaliza el mapeo (antes hardcodeado en CASE); el SP hace JOIN por LLAVE.
-- ============================================================
USE [BRONZE]
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='CATALOGO_TIPO_OPERACION_ACLME')
BEGIN
    CREATE TABLE [RR].[CATALOGO_TIPO_OPERACION_ACLME] (
        [CLAVE]       varchar(4)   NOT NULL,
        [DESCRIPCION] varchar(100) NOT NULL,
        [LLAVE]       varchar(4)   NULL,   -- llave de busqueda (posicion + tipo); NULL cuando no aplica
        [POSICION]    varchar(1)   NULL,   -- C = Compra / V = Venta
        [TIPO_INSUMO] varchar(20)  NULL,   -- tipo(s) del insumo asociados
        CONSTRAINT [PK_RR_CATALOGO_TIPO_OPERACION_ACLME] PRIMARY KEY ([CLAVE])
    );
    CREATE UNIQUE INDEX [UX_RR_CATALOGO_TIPO_OPERACION_ACLME_LLAVE]
        ON [RR].[CATALOGO_TIPO_OPERACION_ACLME]([LLAVE]) WHERE [LLAVE] IS NOT NULL;
    PRINT 'BRONZE.RR.CATALOGO_TIPO_OPERACION_ACLME creada.';
END
ELSE
    PRINT 'BRONZE.RR.CATALOGO_TIPO_OPERACION_ACLME ya existe.';
GO
-- Poblar / actualizar (idempotente por CLAVE)
MERGE [RR].[CATALOGO_TIPO_OPERACION_ACLME] AS t
USING (VALUES
    ('3050', 'Depósitos en Bancos Mexicanos',    NULL,  NULL, NULL),
    ('3515', 'Compra de Spots',                  'CFX', 'C',  'SW/FX'),
    ('3561', 'Compra de Forwards',               'CFW', 'C',  'FW'),
    ('3636', 'Compra de Swaps',                  NULL,  'C',  NULL),
    ('6415', 'Venta Spots',                      'VFX', 'V',  'SW/FX'),
    ('6477', 'Venta de Forwards',                'VFW', 'V',  'FW'),
    ('6542', 'Venta Swaps',                      NULL,  'V',  NULL),
    ('7635', 'Cancelaciones Anticipadas Activas',NULL,  NULL, NULL),
    ('7790', 'Cancelaciones Anticipadas Pasivas',NULL,  NULL, NULL)
) AS s([CLAVE],[DESCRIPCION],[LLAVE],[POSICION],[TIPO_INSUMO])
ON t.[CLAVE] = s.[CLAVE]
WHEN MATCHED THEN UPDATE SET
    t.[DESCRIPCION]=s.[DESCRIPCION], t.[LLAVE]=s.[LLAVE], t.[POSICION]=s.[POSICION], t.[TIPO_INSUMO]=s.[TIPO_INSUMO]
WHEN NOT MATCHED THEN
    INSERT ([CLAVE],[DESCRIPCION],[LLAVE],[POSICION],[TIPO_INSUMO])
    VALUES (s.[CLAVE],s.[DESCRIPCION],s.[LLAVE],s.[POSICION],s.[TIPO_INSUMO]);
PRINT 'BRONZE.RR.CATALOGO_TIPO_OPERACION_ACLME poblado.';
GO

-- ============================================================
-- SECTION 02 | SP SILVER — [dbo].[125_ENT_ACLME]
--   Corrige el stub original (self-select + filtro mensual) e implementa
--   la transformacion BRONZE -> SILVER descrita arriba. Filtro DIARIO.
--   La CLAVE se obtiene por JOIN al catalogo (no hardcodeada).
-- ============================================================
USE [SILVER]
GO
CREATE OR ALTER PROCEDURE [dbo].[125_ENT_ACLME]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[125_ENT_ACLME]';

    -- FechaReporte = @FechaSistema (celda B15 del insumo): fecha del reporte Y referencia del plazo
    DECLARE @FechaRef DATE = CAST(@FechaSistema AS DATE);

    BEGIN TRY

        -- Idempotencia diaria
        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[125_ENT_ACLME] WHERE [FECHA_INFO] = @FechaRef)
        BEGIN
            DELETE FROM [SILVER].[RR].[125_ENT_ACLME] WHERE [FECHA_INFO] = @FechaRef;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        ;WITH base AS (
            SELECT
                A.[ID_SISTEMA],
                A.[INSTITUCION],
                A.[MONTO],
                A.[FECHA_VMTO],
                A.[TIPO_OPERACION] AS TIPO_ORIG,                              -- OPERACIONES A REPORTAR (auditoria)
                DATEDIFF(DAY, @FechaRef, A.[FECHA_INICIO]) AS PLAZO,          -- auditoria: FECHA_INICIO - FechaReporte
                CASE WHEN A.[MONEDA] = 'MXN' THEN 'V' ELSE 'C' END AS POSICION,  -- auditoria: C/V
                -- LLAVE = POSICION(USD=C / MXN=V) + (SW -> FX, si no el propio tipo)
                ( CASE WHEN A.[MONEDA] = 'MXN' THEN 'V' ELSE 'C' END
                + CASE WHEN A.[TIPO_OPERACION] = 'SW' THEN 'FX' ELSE A.[TIPO_OPERACION] END ) AS LLAVE
            FROM [BRONZE].[LMDA].[ACLME] A
            WHERE CAST(A.[FECHA_EXTRACCION] AS DATE) = @FechaRef          -- Opcion A: lote del dia
              AND DATEDIFF(DAY, @FechaRef, A.[FECHA_INICIO]) > 0          -- PLAZO >= 1 (regla 1: FECHA_INICIO - FechaReporte)
        )
        INSERT INTO [RR].[125_ENT_ACLME] (
            [PLAZO], [OPERACIONES_A_REPORTAR], [POSICION_OPERACION], [LLAVE],   -- columnas de auditoria
            [TIPO_OPERACION], [INSTITUCION], [AMORTIZACION], [IMPORTE_AMORTIZACION], [FECHA_AMORTIZACION],
            [NUMERO_IDENTIFICACION], [MONEDA], [RESERVAS], [FECHA_INFO]
        )
        SELECT
            b.PLAZO,                  -- auditoria: plazo (FECHA_INICIO - FechaReporte)
            b.TIPO_ORIG,              -- auditoria: OPERACIONES A REPORTAR (SW/FX/FW original)
            b.POSICION,               -- auditoria: posicion C/V
            b.LLAVE,                  -- auditoria: llave del VLOOKUP
            cat.[CLAVE],              -- TIPO_OPERACION: clave desde el catalogo (JOIN por LLAVE, no hardcodeado)
            b.[INSTITUCION],          -- INSTITUCION (arrastrado desde LMDA)
            1,                        -- AMORTIZACION (constante)
            b.[MONTO],                -- IMPORTE_AMORTIZACION
            b.[FECHA_VMTO],           -- FECHA_AMORTIZACION
            b.[ID_SISTEMA],           -- NUMERO_IDENTIFICACION
            'USD',                    -- MONEDA (constante)
            0,                        -- RESERVAS: en el Excel es 'N/A' (texto); la columna es numerica,
                                      --           por eso se guarda 0 y el SP ION emite 'N/A'.
            @FechaRef                 -- FECHA_INFO
        FROM base b
        -- El INNER JOIN por LLAVE trae la CLAVE y ademas descarta llaves sin equivalencia en catalogo
        INNER JOIN [BRONZE].[RR].[CATALOGO_TIPO_OPERACION_ACLME] cat
                ON cat.[LLAVE] = b.LLAVE;

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

    DECLARE @Asunto NVARCHAR(255);
    DECLARE @Cuerpo NVARCHAR(MAX);

    IF @ExitoEjecucion = 0 AND @CorreoNotificacion IS NOT NULL AND @PerfilCorreo IS NOT NULL
    BEGIN
        SET @Asunto = 'ALERTA: Error en ' + ISNULL(@NombreJob, 'Job Desconocido');
        SET @Cuerpo = 'Error durante la ejecucion de ' + @NombreJob + CHAR(13) + CHAR(10)
            + 'Mensaje: ' + @MensajeError + CHAR(13) + CHAR(10) + 'Log:' + CHAR(13) + CHAR(10) + @DetallesLog;
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail @profile_name=@PerfilCorreo, @recipients=@CorreoNotificacion,
                @subject=@Asunto, @body=@Cuerpo, @body_format='TEXT', @importance='High';
        END TRY
        BEGIN CATCH
            PRINT 'Error al enviar alerta: ' + ERROR_MESSAGE();
        END CATCH
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
-- SECTION 03 | SP ION — [dbo].[125_ENT_ACLME]
--   Salida final del reporte. RESERVAS se emite como 'N/A' (en SILVER es 0).
--   Fechas en formato AAAA/MM/DD. Filtro diario por FECHA_INFO.
-- ============================================================
USE [ION]
GO
CREATE OR ALTER PROCEDURE [dbo].[125_ENT_ACLME]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- Salida conforme al layout 'SALIDA_ION' (9 columnas). Las columnas auxiliares
    -- (PLAZO, OPERACIONES_A_REPORTAR, POSICION_OPERACION, LLAVE) permanecen en SILVER
    -- para auditoria pero NO se emiten en el reporte.
    SELECT
        T.[TIPO_OPERACION]                           AS [TIPO_OPERACION],          -- ORDEN 1
        FORMAT(T.[INSTITUCION], '000000')            AS [INSTITUCION],             -- ORDEN 2 (TEXTO 6, zero-pad)
        T.[AMORTIZACION]                             AS [AMORTIZACION],            -- ORDEN 3
        T.[IMPORTE_AMORTIZACION]                     AS [IMPORTE_AMORTIZACION],    -- ORDEN 4
        FORMAT(T.[FECHA_AMORTIZACION], 'yyyy/MM/dd') AS [FECHA_AMORTIZACION],      -- ORDEN 5
        T.[NUMERO_IDENTIFICACION]                    AS [NUMERO_IDENTIFICACION],   -- ORDEN 6
        T.[MONEDA]                                   AS [MONEDA],                  -- ORDEN 7
        'N/A'                                        AS [RESERVAS],                -- ORDEN 8 (SILVER guarda 0; se emite 'N/A')
        FORMAT(T.[FECHA_INFO], 'yyyy/MM/dd')         AS [FECHA_INFO]               -- ORDEN 9
    FROM [SILVER].[RR].[125_ENT_ACLME] T
    WHERE T.[FECHA_INFO] = @FECHA;
END;
GO

-- ============================================================
-- SECTION 04 | INDICE_REPORTES — registrar reporte 125 (Diaria)
-- ============================================================
USE [ION]
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[INDICE_REPORTES] WHERE [numero] = 125)
    INSERT INTO [dbo].[INDICE_REPORTES] ([numero], [nombre], [frecuencia], [activo], [nombre_archivo])
    VALUES (125, 'ENT_ACLME', 'Diaria', 1, 'ACLME');

SELECT numero, nombre, frecuencia, activo, nombre_archivo FROM dbo.INDICE_REPORTES WHERE numero = 125;
GO
