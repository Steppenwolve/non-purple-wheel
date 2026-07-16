-- ============================================================
-- AJUSTE  076_ENT_REPORTOS_MN_ME — Agregar TIPOTASAPREMIO
-- Layout ORDEN 44, TEXTO(1), catálogo Tipo Tasa (1/2/3).
-- El AJUSTE original lo excluyó; el layout rige la estructura.
-- ============================================================

-- ============================================================
-- S01 | BRONZE — agregar TIPOTASAPREMIO varchar(1) NULL
-- ============================================================
USE [BRONZE]
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'LMDA' AND TABLE_NAME = 'REPORTOS_MN_ME'
      AND COLUMN_NAME = 'TIPOTASAPREMIO'
)
BEGIN
    ALTER TABLE [LMDA].[REPORTOS_MN_ME]
        ADD [TIPOTASAPREMIO] varchar(1) NULL;
    PRINT '>> BRONZE: TIPOTASAPREMIO agregado.';
END
ELSE
    PRINT '>> BRONZE: TIPOTASAPREMIO ya existe.';
GO

-- ============================================================
-- S02 | SILVER — agregar TIPOTASAPREMIO varchar(1) NULL
-- ============================================================
USE [SILVER]
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '076_ENT_REPORTOS_MN_ME'
      AND COLUMN_NAME = 'TIPOTASAPREMIO'
)
BEGIN
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME]
        ADD [TIPOTASAPREMIO] varchar(1) NULL;
    PRINT '>> SILVER: TIPOTASAPREMIO agregado.';
END
ELSE
    PRINT '>> SILVER: TIPOTASAPREMIO ya existe.';
GO

-- ============================================================
-- S03 | SP SILVER — incluir TIPOTASAPREMIO en INSERT/SELECT
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[076_ENT_REPORTOS_MN_ME]
    @CorreoNotificacion NVARCHAR(255) = NULL,
    @PerfilCorreo       NVARCHAR(255) = NULL,
    @ProgramadorJob     NVARCHAR(128) = NULL,
    @FechaSistema       DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @MensajeError NVARCHAR(MAX)='', @ExitoEjecucion BIT=1,
            @FilasInsertadas INT=0, @FilasEliminadas INT=0,
            @LogMessage NVARCHAR(MAX)='', @DetallesLog NVARCHAR(MAX)='',
            @FechaInicio DATETIME=GETDATE(), @NombreJob NVARCHAR(128)='[076_ENT_REPORTOS_MN_ME]',
            @FechaDia DATE = CAST(@FechaSistema AS DATE);

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[076_ENT_REPORTOS_MN_ME] WHERE [FECHA_INFO] = @FechaDia)
        BEGIN
            DELETE FROM [SILVER].[RR].[076_ENT_REPORTOS_MN_ME] WHERE [FECHA_INFO] = @FechaDia;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
        END

        INSERT INTO [RR].[076_ENT_REPORTOS_MN_ME] (
            [FECHACONCERTACION],[HORACONCERTACION],[POSICIONOPERACION],[FECHAINICIO],[FECHAVENCIMIENTO],
            [IMPORTEREPORTO],[MONEDAPRECIOUNITARIO],[TASAPREMIO],[TITULOOBJETOREPORTO],[PRECIOUNITARIOTITULOS],
            [NUMEROTITULOSOBJETOREPORTO],[CONTRAPARTEREPORTO],[RESIDENCIA_CONTRAPARTE],[PROPIA_TERCEROS],[CLIENTE_PROV],
            [CORROELECTRONICO],[TIPOPOSTURA],[OPERACIONBANCOTRABAJO],[HAIRCUT],[REP_SUSTITUCION],
            [MODALIDAD_REPORTO],[PLAZO_EVERGREEN],[REP_CONJUNTO_VAL],[REP_AG_TRIPARTITO],[AGENTE_TRIPARTITO],
            [TASA_REFERENCIA_PREMIO],[SOBRETASA_PREMIO],[PERIODO_PAGO_PREMIO],[NUMEROIDENTIFICACIONOPERACION],
            [CLASIFICACIONCONTABLEOPERACION],[FECHAVENCIMIENTO_TITULO],[OFICINA],[EMISION],[SERIE],[TIPOVALOR],
            [SOBRETASA],[EMISOR],[DIASXVENCER_CUPON],[APLICA_ANEXO1C],[CUSTODIO],[FECHAVALOR],[CLIENTE],
            [RESTRICCION],[TIPOTASAPREMIO],[FECHA_INFO]
        )
        SELECT
            R.[FECHACONCERTACION], R.[HORACONCERTACION], R.[POSICIONOPERACION], R.[FECHAINICIO], R.[FECHAVENCIMIENTO],
            R.[IMPORTEREPORTO], R.[MONEDAPRECIOUNITARIO], R.[TASAPREMIO], R.[TITULOOBJETOREPORTO], R.[PRECIOUNITARIOTITULOS],
            R.[NUMEROTITULOSOBJETOREPORTO], R.[CONTRAPARTEREPORTO], R.[RESIDENCIA_CONTRAPARTE], R.[PROPIA_TERCEROS], R.[CLIENTE_PROV],
            R.[CORROELECTRONICO], R.[TIPOPOSTURA], R.[OPERACIONBANCOTRABAJO], R.[HAIRCUT], R.[REP_SUSTITUCION],
            R.[MODALIDAD_REPORTO], R.[PLAZO_EVERGREEN], R.[REP_CONJUNTO_VAL], R.[REP_AG_TRIPARTITO], R.[AGENTE_TRIPARTITO],
            R.[TASA_REFERENCIA_PREMIO], R.[SOBRETASA_PREMIO], R.[PERIODO_PAGO_PREMIO], R.[NUMEROIDENTIFICACIONOPERACION],
            R.[CLASIFICACIONCONTABLEOPERACION], R.[FECHAVENCIMIENTO_TITULO], R.[OFICINA], R.[EMISION], R.[SERIE], R.[TIPOVALOR],
            R.[SOBRETASA], R.[EMISOR], R.[DIASXVENCER_CUPON], R.[APLICA_ANEXO1C], R.[CUSTODIO], R.[FECHAVALOR], R.[CLIENTE],
            R.[RESTRICCION], R.[TIPOTASAPREMIO], R.[FECHA_INFO]
        FROM [BRONZE].[LMDA].[REPORTOS_MN_ME] R
        WHERE R.[FECHA_INFO] = @FechaDia;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion=0; SET @MensajeError=ERROR_MESSAGE();
        SET @DetallesLog = @DetallesLog + 'Error durante la ejecucion: ' + @MensajeError + CHAR(13)+CHAR(10);
    END CATCH

    IF @ExitoEjecucion=0 AND @CorreoNotificacion IS NOT NULL AND @PerfilCorreo IS NOT NULL
    BEGIN
        DECLARE @Asunto NVARCHAR(255)='ALERTA: Error en ' + @NombreJob;
        DECLARE @Cuerpo NVARCHAR(MAX)='Error en ' + @NombreJob + CHAR(13)+CHAR(10) +
            '- Programado por: ' + ISNULL(@ProgramadorJob,'No especificado') + CHAR(13)+CHAR(10) +
            '- Inicio: ' + CONVERT(VARCHAR,@FechaInicio,120) + CHAR(13)+CHAR(10) +
            '- Mensaje: ' + @MensajeError + CHAR(13)+CHAR(10) + 'Log:' + CHAR(13)+CHAR(10) + @DetallesLog;
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail @profile_name=@PerfilCorreo, @recipients=@CorreoNotificacion,
                 @subject=@Asunto, @body=@Cuerpo, @body_format='TEXT', @importance='High';
        END TRY BEGIN CATCH
            SET @DetallesLog = @DetallesLog + 'Error al enviar alerta: ' + ERROR_MESSAGE() + CHAR(13)+CHAR(10);
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario
        (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (@FechaInicio, @FilasInsertadas,
        CASE WHEN @ExitoEjecucion=1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion=1 THEN NULL ELSE @MensajeError END,
        @DetallesLog, @NombreJob, @ProgramadorJob);
END;
GO

-- ============================================================
-- S04 | SP ION — TIPOTASAPREMIO en ORDEN 44, FECHA_INFO en 45
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[076_ENT_REPORTOS_MN_ME]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        FORMAT([FECHACONCERTACION], 'yyyy/MM/dd')       AS FECHACONCERTACION,        -- ORDEN  1
        [HORACONCERTACION]                              AS HORACONCERTACION,          -- ORDEN  2
        [POSICIONOPERACION]                             AS POSICIONOPERACION,         -- ORDEN  3
        FORMAT([FECHAINICIO], 'yyyy/MM/dd')             AS FECHAINICIO,              -- ORDEN  4
        FORMAT([FECHAVENCIMIENTO], 'yyyy/MM/dd')        AS FECHAVENCIMIENTO,         -- ORDEN  5
        [IMPORTEREPORTO]                                AS IMPORTEREPORTO,            -- ORDEN  6
        [MONEDAPRECIOUNITARIO]                          AS MONEDAPRECIOUNITARIO,      -- ORDEN  7
        [TASAPREMIO]                                    AS TASAPREMIO,               -- ORDEN  8
        [TITULOOBJETOREPORTO]                           AS TITULOOBJETOREPORTO,       -- ORDEN  9
        [PRECIOUNITARIOTITULOS]                         AS PRECIOUNITARIOTITULOS,     -- ORDEN 10
        [NUMEROTITULOSOBJETOREPORTO]                    AS NUMEROTITULOSOBJETOREPORTO, -- ORDEN 11
        RIGHT('000000' + [CONTRAPARTEREPORTO], 6)       AS CONTRAPARTEREPORTO,        -- ORDEN 12
        [RESIDENCIA_CONTRAPARTE]                        AS RESIDENCIA_CONTRAPARTE,    -- ORDEN 13
        [PROPIA_TERCEROS]                               AS PROPIA_TERCEROS,           -- ORDEN 14
        [CLIENTE_PROV]                                  AS CLIENTE_PROV,             -- ORDEN 15
        [CORROELECTRONICO]                              AS CORROELECTRONICO,          -- ORDEN 16
        [TIPOPOSTURA]                                   AS TIPOPOSTURA,              -- ORDEN 17
        [OPERACIONBANCOTRABAJO]                         AS OPERACIONBANCOTRABAJO,     -- ORDEN 18
        [HAIRCUT]                                       AS HAIRCUT,                  -- ORDEN 19
        [REP_SUSTITUCION]                               AS REP_SUSTITUCION,           -- ORDEN 20
        [MODALIDAD_REPORTO]                             AS MODALIDAD_REPORTO,         -- ORDEN 21
        [PLAZO_EVERGREEN]                               AS PLAZO_EVERGREEN,           -- ORDEN 22
        [REP_CONJUNTO_VAL]                              AS REP_CONJUNTO_VAL,          -- ORDEN 23
        [REP_AG_TRIPARTITO]                             AS REP_AG_TRIPARTITO,         -- ORDEN 24
        RIGHT('000000' + [AGENTE_TRIPARTITO], 6)        AS AGENTE_TRIPARTITO,         -- ORDEN 25
        [TASA_REFERENCIA_PREMIO]                        AS TASA_REFERENCIA_PREMIO,    -- ORDEN 26
        [SOBRETASA_PREMIO]                              AS SOBRETASA_PREMIO,          -- ORDEN 27
        [PERIODO_PAGO_PREMIO]                           AS PERIODO_PAGO_PREMIO,       -- ORDEN 28
        [NUMEROIDENTIFICACIONOPERACION]                 AS NUMEROIDENTIFICACIONOPERACION, -- ORDEN 29
        [CLASIFICACIONCONTABLEOPERACION]                AS CLASIFICACIONCONTABLEOPERACION, -- ORDEN 30
        FORMAT([FECHAVENCIMIENTO_TITULO], 'yyyy/MM/dd') AS FECHAVENCIMIENTO_TITULO,   -- ORDEN 31
        [OFICINA]                                       AS OFICINA,                  -- ORDEN 32
        [EMISION]                                       AS EMISION,                  -- ORDEN 33
        [SERIE]                                         AS SERIE,                    -- ORDEN 34
        [TIPOVALOR]                                     AS TIPOVALOR,                -- ORDEN 35
        [SOBRETASA]                                     AS SOBRETASA,                -- ORDEN 36
        RIGHT('000000' + [EMISOR], 6)                   AS EMISOR,                   -- ORDEN 37
        [DIASXVENCER_CUPON]                             AS DIASXVENCER_CUPON,         -- ORDEN 38
        [APLICA_ANEXO1C]                                AS APLICA_ANEXO1C,            -- ORDEN 39
        RIGHT('000000' + CAST([CUSTODIO] AS VARCHAR(6)), 6) AS CUSTODIO,             -- ORDEN 40
        [FECHAVALOR]                                    AS FECHAVALOR,               -- ORDEN 41
        RIGHT('000000' + CAST([CLIENTE] AS VARCHAR(6)), 6)  AS CLIENTE,             -- ORDEN 42
        [RESTRICCION]                                   AS RESTRICCION,              -- ORDEN 43
        [TIPOTASAPREMIO]                                AS TIPOTASAPREMIO,           -- ORDEN 44
        FORMAT([FECHA_INFO], 'yyyy/MM/dd')              AS FECHA_INFO               -- ORDEN 45
    FROM [SILVER].[RR].[076_ENT_REPORTOS_MN_ME]
    WHERE [FECHA_INFO] = @FECHA;
END;
GO

-- Verificar
SELECT COLUMN_NAME FROM BRONZE.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='REPORTOS_MN_ME' AND COLUMN_NAME='TIPOTASAPREMIO';
SELECT COLUMN_NAME FROM SILVER.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='TIPOTASAPREMIO';
GO
