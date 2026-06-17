/* ============================================================================
   076_ENT_REPORTOS_MN_ME_AJUSTE.sql
   Reporte    : ENT_REPORTOS_MN_ME  (Reportos MN/ME)
   Objeto     : 076_ENT_REPORTOS_MN_ME   (SILVER e ION)
   Layout     : Layout_REPORTOS_MN_ME_V7.1_2024.xlsx (hoja 'REPORTOS_MNME', 45 campos)
   Periodicidad : DIARIA
   Patron     : ORIGEN LMDA (ver deploy/PATRON_ORIGEN_LMDA.md)
                Carga INSERT...SELECT desde BRONZE.[LMDA].[FT_REPORTOS].
   Fin        : Reestructurar el 076 (que estaba self-select / layout viejo) al
                layout V7.1: 43 campos regulatorios (ORDEN 1-43) + FECHA_INFO.
   Decisiones :
     - Se EXCLUYE TIPOTASAPREMIO (layout ORDEN 44, "solo version anterior a junio 2024";
       FT_REPORTOS no lo trae).
     - Se EXCLUYE TIPOMODIFICACION (no esta en el layout V7.1).
     - Naming CONTRAPARTEREPORTO (sin guion bajo, como el layout y FT_REPORTOS).
     - FECHA_INFO (ORDEN 45): no existe en FT_REPORTOS; el SP la puebla = @FechaDia.
     - Sin zero-pad (FT_REPORTOS ya trae los valores; mismo criterio que el 121).
   IMPORTANTE : recrea la tabla RR (DROP+CREATE) -> se pierden datos previos.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   00 - PREFLIGHT: la tabla origen BRONZE debe existir
   ---------------------------------------------------------------------------- */
USE [BRONZE];
GO
IF NOT EXISTS (SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
               WHERE s.name='LMDA' AND o.name='FT_REPORTOS' AND o.type='U')
BEGIN
    RAISERROR('Preflight fallido: BRONZE.[LMDA].[FT_REPORTOS] no existe. Abortando.',16,1);
    RETURN;
END
PRINT '>> Preflight OK: BRONZE.[LMDA].[FT_REPORTOS] existe.';
GO

/* ----------------------------------------------------------------------------
   01 - SILVER  [RR].[076_ENT_REPORTOS_MN_ME]  -> recrear con estructura V7.1
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name='076_ENT_REPORTOS_MN_ME' AND schema_id=SCHEMA_ID('RR') AND type='U')
    DROP TABLE [RR].[076_ENT_REPORTOS_MN_ME];
GO
CREATE TABLE [RR].[076_ENT_REPORTOS_MN_ME]
(
    [ID]                             [uniqueidentifier] NOT NULL CONSTRAINT DF_076_REPORTOS_MN_ME_ID DEFAULT (NEWID()),
    [FECHACONCERTACION]              [date]            NOT NULL,
    [HORACONCERTACION]               [numeric](5, 2)   NOT NULL,
    [POSICIONOPERACION]              [varchar](1)      NOT NULL,   -- cat PosicionOperacionRepo
    [FECHAINICIO]                    [date]            NOT NULL,
    [FECHAVENCIMIENTO]               [date]            NOT NULL,
    [IMPORTEREPORTO]                 [numeric](12, 0)  NOT NULL,
    [MONEDAPRECIOUNITARIO]           [varchar](3)      NOT NULL,   -- cat MonedaISO
    [TASAPREMIO]                     [numeric](8, 4)   NOT NULL,
    [TITULOOBJETOREPORTO]            [varchar](18)     NOT NULL,
    [PRECIOUNITARIOTITULOS]          [numeric](19, 8)  NOT NULL,
    [NUMEROTITULOSOBJETOREPORTO]     [numeric](12, 0)  NOT NULL,
    [CONTRAPARTEREPORTO]             [varchar](6)      NOT NULL,   -- cat CASFIM
    [RESIDENCIA_CONTRAPARTE]         [varchar](3)      NOT NULL,
    [PROPIA_TERCEROS]                [varchar](1)      NOT NULL,
    [CLIENTE_PROV]                   [varchar](6)      NOT NULL,
    [CORROELECTRONICO]               [numeric](2, 0)   NOT NULL,   -- cat CorreoElectronico
    [TIPOPOSTURA]                    [varchar](2)      NOT NULL,   -- cat TipoPostura
    [OPERACIONBANCOTRABAJO]          [varchar](1)      NOT NULL,   -- cat OperacionRealizadaBanco
    [HAIRCUT]                        [numeric](4, 2)   NOT NULL,
    [REP_SUSTITUCION]                [varchar](1)      NOT NULL,   -- cat SustitucionValores
    [MODALIDAD_REPORTO]              [varchar](2)      NOT NULL,   -- cat Mod_reporto
    [PLAZO_EVERGREEN]                [numeric](3, 0)   NOT NULL,
    [REP_CONJUNTO_VAL]               [varchar](1)      NOT NULL,   -- cat Canasta
    [REP_AG_TRIPARTITO]              [varchar](1)      NOT NULL,   -- cat Tripartito
    [AGENTE_TRIPARTITO]              [varchar](6)      NOT NULL,   -- cat CASFIM
    [TASA_REFERENCIA_PREMIO]         [numeric](3, 0)   NOT NULL,   -- cat Tasas de Referencia
    [SOBRETASA_PREMIO]               [numeric](8, 4)   NOT NULL,
    [PERIODO_PAGO_PREMIO]            [numeric](6, 0)   NOT NULL,
    [NUMEROIDENTIFICACIONOPERACION]  [varchar](37)     NOT NULL,
    [CLASIFICACIONCONTABLEOPERACION] [varchar](2)      NOT NULL,   -- cat ClasificacionContableCVT
    [FECHAVENCIMIENTO_TITULO]        [date]            NOT NULL,
    [OFICINA]                        [varchar](1)      NOT NULL,   -- cat CveOficina
    [EMISION]                        [varchar](50)     NOT NULL,
    [SERIE]                          [varchar](50)     NOT NULL,
    [TIPOVALOR]                      [varchar](50)     NOT NULL,
    [SOBRETASA]                      [varchar](1)      NOT NULL,   -- cat CveSobretasa
    [EMISOR]                         [varchar](6)      NOT NULL,   -- cat CASFIM
    [DIASXVENCER_CUPON]              [numeric](12, 0)  NOT NULL,
    [APLICA_ANEXO1C]                 [varchar](1)      NOT NULL,   -- cat CveAplicaAnexo1C
    [CUSTODIO]                       [numeric](6, 0)   NOT NULL,   -- cat CASFIM
    [FECHAVALOR]                     [numeric](1, 0)   NOT NULL,   -- cat Fecha Valor
    [CLIENTE]                        [numeric](6, 0)   NOT NULL,   -- cat CASFIM
    [RESTRICCION]                    [varchar](2)      NOT NULL,   -- cat Restriccion
    [FECHA_INFO]                     [date]            NOT NULL,
    [FECHA_EXTRACCION]              [smalldatetime]   NOT NULL CONSTRAINT DF_076_REPORTOS_MN_ME_FEXT DEFAULT (GETDATE()),
    CONSTRAINT PK_RR_076_REPORTOS_MN_ME PRIMARY KEY CLUSTERED ([ID] ASC)
) ON [PRIMARY];
PRINT '>> Recreada SILVER.[RR].[076_ENT_REPORTOS_MN_ME] (estructura V7.1).';
GO

/* ----------------------------------------------------------------------------
   02 - SILVER SP  [dbo].[076_ENT_REPORTOS_MN_ME]  (ORIGEN LMDA)
        Carga desde BRONZE.[LMDA].[FT_REPORTOS]. DIARIA. FECHA_INFO = @FechaDia.
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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
        -- DIARIA: la ventana se delimita por FECHA_INFO (= dia de proceso)
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
            [RESTRICCION],[FECHA_INFO]
        )
        SELECT
            R.FECHACONCERTACION, R.HORACONCERTACION, R.POSICIONOPERACION, R.FECHAINICIO, R.FECHAVENCIMIENTO,
            R.IMPORTEREPORTO, R.MONEDAPRECIOUNITARIO, R.TASAPREMIO, R.TITULOOBJETOREPORTO, R.PRECIOUNITARIOTITULOS,
            R.NUMEROTITULOSOBJETOREPORTO, R.CONTRAPARTEREPORTO, R.RESIDENCIA_CONTRAPARTE, R.PROPIA_TERCEROS, R.CLIENTE_PROV,
            R.CORROELECTRONICO, R.TIPOPOSTURA, R.OPERACIONBANCOTRABAJO, R.HAIRCUT, R.REP_SUSTITUCION,
            R.MODALIDAD_REPORTO, R.PLAZO_EVERGREEN, R.REP_CONJUNTO_VAL, R.REP_AG_TRIPARTITO, R.AGENTE_TRIPARTITO,
            R.TASA_REFERENCIA_PREMIO, R.SOBRETASA_PREMIO, R.PERIODO_PAGO_PREMIO, R.NUMEROIDENTIFICACIONOPERACION,
            R.CLASIFICACIONCONTABLEOPERACION, R.FECHAVENCIMIENTO_TITULO, R.OFICINA, R.EMISION, R.SERIE, R.TIPOVALOR,
            R.SOBRETASA, R.EMISOR, R.DIASXVENCER_CUPON, R.APLICA_ANEXO1C, R.CUSTODIO, R.FECHAVALOR, R.CLIENTE,
            R.RESTRICCION, @FechaDia
        FROM [BRONZE].[LMDA].[FT_REPORTOS] R
        WHERE R.FECHACONCERTACION = @FechaDia;

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
PRINT '>> Creado/actualizado SILVER.dbo.[076_ENT_REPORTOS_MN_ME] (origen LMDA).';
GO

/* ----------------------------------------------------------------------------
   03 - ION SP  [dbo].[076_ENT_REPORTOS_MN_ME]  (entrega V7.1)
        Orden por columna ORDEN del layout (1-43 + FECHA_INFO=45). Sin TIPOTASAPREMIO.
        Fechas en AAAA/MM/DD. Sin ID ni FECHA_EXTRACCION. Filtro DIARIO por FECHA_INFO.
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[076_ENT_REPORTOS_MN_ME]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- NOTA (consideracion 12): fechas en AAAA/MM/DD. (consideracion 13): orden por ORDEN del layout.
    SELECT
        FORMAT([FECHACONCERTACION], 'yyyy/MM/dd')       AS FECHACONCERTACION,
        [HORACONCERTACION]                              AS HORACONCERTACION,
        [POSICIONOPERACION]                             AS POSICIONOPERACION,
        FORMAT([FECHAINICIO], 'yyyy/MM/dd')             AS FECHAINICIO,
        FORMAT([FECHAVENCIMIENTO], 'yyyy/MM/dd')        AS FECHAVENCIMIENTO,
        [IMPORTEREPORTO]                                AS IMPORTEREPORTO,
        [MONEDAPRECIOUNITARIO]                          AS MONEDAPRECIOUNITARIO,
        [TASAPREMIO]                                    AS TASAPREMIO,
        [TITULOOBJETOREPORTO]                           AS TITULOOBJETOREPORTO,
        [PRECIOUNITARIOTITULOS]                         AS PRECIOUNITARIOTITULOS,
        [NUMEROTITULOSOBJETOREPORTO]                    AS NUMEROTITULOSOBJETOREPORTO,
        [CONTRAPARTEREPORTO]                            AS CONTRAPARTEREPORTO,
        [RESIDENCIA_CONTRAPARTE]                        AS RESIDENCIA_CONTRAPARTE,
        [PROPIA_TERCEROS]                               AS PROPIA_TERCEROS,
        [CLIENTE_PROV]                                  AS CLIENTE_PROV,
        [CORROELECTRONICO]                              AS CORROELECTRONICO,
        [TIPOPOSTURA]                                   AS TIPOPOSTURA,
        [OPERACIONBANCOTRABAJO]                         AS OPERACIONBANCOTRABAJO,
        [HAIRCUT]                                       AS HAIRCUT,
        [REP_SUSTITUCION]                               AS REP_SUSTITUCION,
        [MODALIDAD_REPORTO]                             AS MODALIDAD_REPORTO,
        [PLAZO_EVERGREEN]                               AS PLAZO_EVERGREEN,
        [REP_CONJUNTO_VAL]                              AS REP_CONJUNTO_VAL,
        [REP_AG_TRIPARTITO]                             AS REP_AG_TRIPARTITO,
        [AGENTE_TRIPARTITO]                             AS AGENTE_TRIPARTITO,
        [TASA_REFERENCIA_PREMIO]                        AS TASA_REFERENCIA_PREMIO,
        [SOBRETASA_PREMIO]                              AS SOBRETASA_PREMIO,
        [PERIODO_PAGO_PREMIO]                           AS PERIODO_PAGO_PREMIO,
        [NUMEROIDENTIFICACIONOPERACION]                 AS NUMEROIDENTIFICACIONOPERACION,
        [CLASIFICACIONCONTABLEOPERACION]                AS CLASIFICACIONCONTABLEOPERACION,
        FORMAT([FECHAVENCIMIENTO_TITULO], 'yyyy/MM/dd') AS FECHAVENCIMIENTO_TITULO,
        [OFICINA]                                       AS OFICINA,
        [EMISION]                                       AS EMISION,
        [SERIE]                                         AS SERIE,
        [TIPOVALOR]                                     AS TIPOVALOR,
        [SOBRETASA]                                     AS SOBRETASA,
        [EMISOR]                                        AS EMISOR,
        [DIASXVENCER_CUPON]                             AS DIASXVENCER_CUPON,
        [APLICA_ANEXO1C]                                AS APLICA_ANEXO1C,
        [CUSTODIO]                                      AS CUSTODIO,
        [FECHAVALOR]                                    AS FECHAVALOR,
        [CLIENTE]                                       AS CLIENTE,
        [RESTRICCION]                                   AS RESTRICCION,
        FORMAT([FECHA_INFO], 'yyyy/MM/dd')              AS FECHA_INFO
    FROM [SILVER].[RR].[076_ENT_REPORTOS_MN_ME]
    WHERE [FECHA_INFO] = @FECHA;
END;
GO
PRINT '>> Creado/actualizado ION.dbo.[076_ENT_REPORTOS_MN_ME] (salida V7.1).';
GO

/* ----------------------------------------------------------------------------
   04 - ION.dbo.INDICE_REPORTES : asegurar registro 76
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 76)
    UPDATE dbo.INDICE_REPORTES SET nombre='ENT_REPORTOS_MN_ME', frecuencia='Diaria' WHERE numero = 76;
ELSE
    INSERT INTO dbo.INDICE_REPORTES (numero,nombre,frecuencia,activo,nombre_archivo)
    VALUES (76,'ENT_REPORTOS_MN_ME','Diaria',0,NULL);
PRINT '>> Registro 76 verificado en ION.dbo.INDICE_REPORTES.';
GO
PRINT '>> Ajuste 076_ENT_REPORTOS_MN_ME (origen LMDA, layout V7.1) completado.';
GO
