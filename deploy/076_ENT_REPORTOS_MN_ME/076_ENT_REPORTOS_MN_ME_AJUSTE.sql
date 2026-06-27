/* ============================================================================
   076_ENT_REPORTOS_MN_ME_AJUSTE.sql
   Reporte    : ENT_REPORTOS_MN_ME  (Reportos MN/ME)
   Objeto     : 076_ENT_REPORTOS_MN_ME   (SILVER e ION)
   Layout     : Layout_REPORTOS_MN_ME_V7.1_2024.xlsx (hoja 'REPORTOS_MNME', 45 campos)
   Periodicidad : DIARIA
   Patron     : ORIGEN LMDA (ver deploy/PATRON_ORIGEN_LMDA.md)
                Crea BRONZE.[LMDA].[REPORTOS_MN_ME] (tabla landing dedicada).
                SP SILVER: INSERT...SELECT FROM BRONZE.[LMDA].[REPORTOS_MN_ME]
                           filtrando por FECHA_INFO = @FechaDia.
   Decisiones :
     - Se EXCLUYE TIPOTASAPREMIO (layout ORDEN 44, "solo version anterior a junio 2024").
     - Se EXCLUYE TIPOMODIFICACION (no esta en el layout V7.1).
     - Sin zero-pad (los valores llegan ya formateados en la tabla LMDA).
     - FECHA_INFO viene de BRONZE.LMDA.REPORTOS_MN_ME (no se inyecta desde @FechaDia).
   Enfoque    : ALTER sobre tabla existente (preserva datos). Operaciones en orden:
                DEFAULT constraints -> sp_rename -> DROP columnas obsoletas ->
                ALTER COLUMN tipo -> ADD columnas nuevas.
                Nueva tabla si no existe ninguna version.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   00 - BRONZE  [LMDA].[REPORTOS_MN_ME]  -> tabla landing dedicada
        Estructura: ID + 44 cols regulatorias + FECHA_EXTRACCION + FECHA_INFO
        (patron identico a BRONZE.[LMDA].[CVT_MN_ME] y similares)
   ---------------------------------------------------------------------------- */
USE [BRONZE];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE s.name='LMDA' AND o.name='REPORTOS_MN_ME' AND o.type='U'
)
BEGIN
    CREATE TABLE [LMDA].[REPORTOS_MN_ME]
    (
        [ID]                             [uniqueidentifier] NOT NULL CONSTRAINT DF_LMDA_REPORTOS_MN_ME_ID DEFAULT (NEWID()),
        [FECHACONCERTACION]              [date]            NOT NULL,
        [HORACONCERTACION]               [numeric](5, 2)   NOT NULL,
        [POSICIONOPERACION]              [varchar](1)      NOT NULL,
        [FECHAINICIO]                    [date]            NOT NULL,
        [FECHAVENCIMIENTO]               [date]            NOT NULL,
        [IMPORTEREPORTO]                 [numeric](12, 0)  NOT NULL,
        [MONEDAPRECIOUNITARIO]           [varchar](3)      NOT NULL,
        [TASAPREMIO]                     [numeric](8, 4)   NOT NULL,
        [TITULOOBJETOREPORTO]            [varchar](18)     NOT NULL,
        [PRECIOUNITARIOTITULOS]          [numeric](19, 8)  NOT NULL,
        [NUMEROTITULOSOBJETOREPORTO]     [numeric](12, 0)  NOT NULL,
        [CONTRAPARTEREPORTO]             [varchar](6)      NOT NULL,
        [RESIDENCIA_CONTRAPARTE]         [varchar](3)      NOT NULL,
        [PROPIA_TERCEROS]                [varchar](1)      NOT NULL,
        [CLIENTE_PROV]                   [varchar](6)      NOT NULL,
        [CORROELECTRONICO]               [numeric](2, 0)   NOT NULL,
        [TIPOPOSTURA]                    [varchar](2)      NOT NULL,
        [OPERACIONBANCOTRABAJO]          [varchar](1)      NOT NULL,
        [HAIRCUT]                        [numeric](4, 2)   NOT NULL,
        [REP_SUSTITUCION]                [varchar](1)      NOT NULL,
        [MODALIDAD_REPORTO]              [varchar](2)      NOT NULL,
        [PLAZO_EVERGREEN]                [numeric](3, 0)   NOT NULL,
        [REP_CONJUNTO_VAL]               [varchar](1)      NOT NULL,
        [REP_AG_TRIPARTITO]              [varchar](1)      NOT NULL,
        [AGENTE_TRIPARTITO]              [varchar](6)      NOT NULL,
        [TASA_REFERENCIA_PREMIO]         [numeric](3, 0)   NOT NULL,
        [SOBRETASA_PREMIO]               [numeric](8, 4)   NOT NULL,
        [PERIODO_PAGO_PREMIO]            [numeric](6, 0)   NOT NULL,
        [NUMEROIDENTIFICACIONOPERACION]  [varchar](37)     NOT NULL,
        [CLASIFICACIONCONTABLEOPERACION] [varchar](2)      NOT NULL,
        [FECHAVENCIMIENTO_TITULO]        [date]            NOT NULL,
        [OFICINA]                        [varchar](1)      NOT NULL,
        [EMISION]                        [varchar](50)     NOT NULL,
        [SERIE]                          [varchar](50)     NOT NULL,
        [TIPOVALOR]                      [varchar](50)     NOT NULL,
        [SOBRETASA]                      [varchar](1)      NOT NULL,
        [EMISOR]                         [varchar](6)      NOT NULL,
        [DIASXVENCER_CUPON]              [numeric](12, 0)  NOT NULL,
        [APLICA_ANEXO1C]                 [varchar](1)      NOT NULL,
        [CUSTODIO]                       [numeric](6, 0)   NOT NULL,
        [FECHAVALOR]                     [numeric](1, 0)   NOT NULL,
        [CLIENTE]                        [numeric](6, 0)   NOT NULL,
        [RESTRICCION]                    [varchar](2)      NOT NULL,
        [FECHA_EXTRACCION]               [smalldatetime]   NOT NULL CONSTRAINT DF_LMDA_REPORTOS_MN_ME_FEXT DEFAULT (GETDATE()),
        [FECHA_INFO]                     [date]            NULL,
        CONSTRAINT PK_LMDA_REPORTOS_MN_ME PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada BRONZE.[LMDA].[REPORTOS_MN_ME].';
END
ELSE
    PRINT '>> BRONZE.[LMDA].[REPORTOS_MN_ME] ya existe, se omite creacion.';
GO

/* ----------------------------------------------------------------------------
   01 - SILVER  [RR].[076_ENT_REPORTOS_MN_ME]  -> ALTER a estructura V7.1
        Cambios respecto a la version original:
          - DROP: TIPOTASAPREMIO, TIPOMODIFICACION
          - RENAME: CONTRAPARTE_REPORTO -> CONTRAPARTEREPORTO
          - ALTER COLUMN: CORROELECTRONICO varchar(2) -> numeric(2,0)
          - ADD (13 cols nuevas): RESIDENCIA_CONTRAPARTE, PROPIA_TERCEROS, CLIENTE_PROV,
            HAIRCUT, REP_SUSTITUCION, MODALIDAD_REPORTO, PLAZO_EVERGREEN, REP_CONJUNTO_VAL,
            REP_AG_TRIPARTITO, AGENTE_TRIPARTITO, TASA_REFERENCIA_PREMIO, SOBRETASA_PREMIO,
            PERIODO_PAGO_PREMIO
          - ADD: FECHA_INFO (columna control LMDA)
          - Si la tabla no existe: CREATE desde cero con estructura completa V7.1.
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- a) Asegurar DEFAULT constraints (pueden faltar en tablas importadas del DDL)
IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o ON o.object_id = dc.parent_object_id
    WHERE o.name='076_ENT_REPORTOS_MN_ME' AND col.name='ID'
)
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME]
        ADD CONSTRAINT DF_076_REPORTOS_MN_ME_ID DEFAULT (NEWID()) FOR [ID];

IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o ON o.object_id = dc.parent_object_id
    WHERE o.name='076_ENT_REPORTOS_MN_ME' AND col.name='FECHA_EXTRACCION'
)
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME]
        ADD CONSTRAINT DF_076_REPORTOS_MN_ME_FEXT DEFAULT (GETDATE()) FOR [FECHA_EXTRACCION];
PRINT '>> DEFAULT constraints verificados en SILVER.[RR].[076_ENT_REPORTOS_MN_ME].';
GO

-- b) Renombrar CONTRAPARTE_REPORTO -> CONTRAPARTEREPORTO (layout V7.1)
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='CONTRAPARTE_REPORTO')
   AND NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='CONTRAPARTEREPORTO')
BEGIN
    EXEC sp_rename '[RR].[076_ENT_REPORTOS_MN_ME].[CONTRAPARTE_REPORTO]', 'CONTRAPARTEREPORTO', 'COLUMN';
    PRINT '>> Columna CONTRAPARTE_REPORTO renombrada a CONTRAPARTEREPORTO.';
END
ELSE
    PRINT '>> Rename CONTRAPARTE_REPORTO->CONTRAPARTEREPORTO: ya aplicado o no necesario.';
GO

-- c) Eliminar columnas obsoletas (no presentes en layout V7.1)
--    Primero eliminar DEFAULT constraints que puedan bloquear el DROP COLUMN.
DECLARE @sqlc NVARCHAR(MAX) = '';
SELECT @sqlc = @sqlc + 'ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] DROP CONSTRAINT ' + dc.name + '; '
FROM sys.default_constraints dc
JOIN sys.columns col ON col.default_object_id = dc.object_id
JOIN sys.objects o ON o.object_id = dc.parent_object_id
WHERE o.name = '076_ENT_REPORTOS_MN_ME' AND col.name IN ('TIPOTASAPREMIO','TIPOMODIFICACION');
IF LEN(@sqlc) > 0 EXEC sp_executesql @sqlc;
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='TIPOTASAPREMIO')
BEGIN
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] DROP COLUMN [TIPOTASAPREMIO];
    PRINT '>> Columna TIPOTASAPREMIO eliminada.';
END
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='TIPOMODIFICACION')
BEGIN
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] DROP COLUMN [TIPOMODIFICACION];
    PRINT '>> Columna TIPOMODIFICACION eliminada.';
END
GO

-- d) Cambio de tipo CORROELECTRONICO: varchar(2) -> numeric(2,0)
--    Requiere que todos los valores existentes sean numericos. La carga LMDA garantiza esto.
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME'
             AND COLUMN_NAME='CORROELECTRONICO' AND DATA_TYPE='varchar')
BEGIN
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME]
        ALTER COLUMN [CORROELECTRONICO] [numeric](2, 0) NOT NULL;
    PRINT '>> Columna CORROELECTRONICO cambiada a numeric(2,0).';
END
ELSE
    PRINT '>> CORROELECTRONICO ya es numeric o no existe: sin cambio de tipo.';
GO

-- e) Agregar columnas nuevas del layout V7.1
--    Las columnas NOT NULL se agregan con DEFAULT para compatibilidad con filas existentes.
--    Los defaults son marcadores de migracion; datos reales llegaran por SP SILVER.
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='RESIDENCIA_CONTRAPARTE')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [RESIDENCIA_CONTRAPARTE] [varchar](3) NOT NULL CONSTRAINT DF_076_RES_CONT DEFAULT ('');
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='PROPIA_TERCEROS')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [PROPIA_TERCEROS] [varchar](1) NOT NULL CONSTRAINT DF_076_PROP_TERC DEFAULT ('');
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='CLIENTE_PROV')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [CLIENTE_PROV] [varchar](6) NOT NULL CONSTRAINT DF_076_CLI_PROV DEFAULT ('');
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='HAIRCUT')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [HAIRCUT] [numeric](4, 2) NOT NULL CONSTRAINT DF_076_HAIRCUT DEFAULT (0);
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='REP_SUSTITUCION')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [REP_SUSTITUCION] [varchar](1) NOT NULL CONSTRAINT DF_076_REP_SUST DEFAULT ('');
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='MODALIDAD_REPORTO')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [MODALIDAD_REPORTO] [varchar](2) NOT NULL CONSTRAINT DF_076_MOD_REP DEFAULT ('');
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='PLAZO_EVERGREEN')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [PLAZO_EVERGREEN] [numeric](3, 0) NOT NULL CONSTRAINT DF_076_PLAZO_EV DEFAULT (0);
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='REP_CONJUNTO_VAL')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [REP_CONJUNTO_VAL] [varchar](1) NOT NULL CONSTRAINT DF_076_REP_CONJ DEFAULT ('');
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='REP_AG_TRIPARTITO')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [REP_AG_TRIPARTITO] [varchar](1) NOT NULL CONSTRAINT DF_076_REP_TRIP DEFAULT ('');
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='AGENTE_TRIPARTITO')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [AGENTE_TRIPARTITO] [varchar](6) NOT NULL CONSTRAINT DF_076_AGE_TRIP DEFAULT ('');
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='TASA_REFERENCIA_PREMIO')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [TASA_REFERENCIA_PREMIO] [numeric](3, 0) NOT NULL CONSTRAINT DF_076_TASA_REF DEFAULT (0);
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='SOBRETASA_PREMIO')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [SOBRETASA_PREMIO] [numeric](8, 4) NOT NULL CONSTRAINT DF_076_SOB_PREM DEFAULT (0);
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='PERIODO_PAGO_PREMIO')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [PERIODO_PAGO_PREMIO] [numeric](6, 0) NOT NULL CONSTRAINT DF_076_PER_PAG DEFAULT (0);
-- FECHA_INFO: columna de control LMDA, nullable
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='076_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='FECHA_INFO')
    ALTER TABLE [RR].[076_ENT_REPORTOS_MN_ME] ADD [FECHA_INFO] [date] NULL;
PRINT '>> Columnas nuevas V7.1 verificadas en SILVER.[RR].[076_ENT_REPORTOS_MN_ME].';
GO

-- f) Si la tabla no existe en absoluto: CREATE desde cero con estructura completa V7.1
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name='076_ENT_REPORTOS_MN_ME' AND schema_id=SCHEMA_ID('RR') AND type='U')
BEGIN
    CREATE TABLE [RR].[076_ENT_REPORTOS_MN_ME]
    (
        [ID]                             [uniqueidentifier] NOT NULL CONSTRAINT DF_076_REPORTOS_MN_ME_ID DEFAULT (NEWID()),
        [FECHACONCERTACION]              [date]            NOT NULL,
        [HORACONCERTACION]               [numeric](5, 2)   NOT NULL,
        [POSICIONOPERACION]              [varchar](1)      NOT NULL,
        [FECHAINICIO]                    [date]            NOT NULL,
        [FECHAVENCIMIENTO]               [date]            NOT NULL,
        [IMPORTEREPORTO]                 [numeric](12, 0)  NOT NULL,
        [MONEDAPRECIOUNITARIO]           [varchar](3)      NOT NULL,
        [TASAPREMIO]                     [numeric](8, 4)   NOT NULL,
        [TITULOOBJETOREPORTO]            [varchar](18)     NOT NULL,
        [PRECIOUNITARIOTITULOS]          [numeric](19, 8)  NOT NULL,
        [NUMEROTITULOSOBJETOREPORTO]     [numeric](12, 0)  NOT NULL,
        [CONTRAPARTEREPORTO]             [varchar](6)      NOT NULL,
        [RESIDENCIA_CONTRAPARTE]         [varchar](3)      NOT NULL,
        [PROPIA_TERCEROS]                [varchar](1)      NOT NULL,
        [CLIENTE_PROV]                   [varchar](6)      NOT NULL,
        [CORROELECTRONICO]               [numeric](2, 0)   NOT NULL,
        [TIPOPOSTURA]                    [varchar](2)      NOT NULL,
        [OPERACIONBANCOTRABAJO]          [varchar](1)      NOT NULL,
        [HAIRCUT]                        [numeric](4, 2)   NOT NULL,
        [REP_SUSTITUCION]                [varchar](1)      NOT NULL,
        [MODALIDAD_REPORTO]              [varchar](2)      NOT NULL,
        [PLAZO_EVERGREEN]                [numeric](3, 0)   NOT NULL,
        [REP_CONJUNTO_VAL]               [varchar](1)      NOT NULL,
        [REP_AG_TRIPARTITO]              [varchar](1)      NOT NULL,
        [AGENTE_TRIPARTITO]              [varchar](6)      NOT NULL,
        [TASA_REFERENCIA_PREMIO]         [numeric](3, 0)   NOT NULL,
        [SOBRETASA_PREMIO]               [numeric](8, 4)   NOT NULL,
        [PERIODO_PAGO_PREMIO]            [numeric](6, 0)   NOT NULL,
        [NUMEROIDENTIFICACIONOPERACION]  [varchar](37)     NOT NULL,
        [CLASIFICACIONCONTABLEOPERACION] [varchar](2)      NOT NULL,
        [FECHAVENCIMIENTO_TITULO]        [date]            NOT NULL,
        [OFICINA]                        [varchar](1)      NOT NULL,
        [EMISION]                        [varchar](50)     NOT NULL,
        [SERIE]                          [varchar](50)     NOT NULL,
        [TIPOVALOR]                      [varchar](50)     NOT NULL,
        [SOBRETASA]                      [varchar](1)      NOT NULL,
        [EMISOR]                         [varchar](6)      NOT NULL,
        [DIASXVENCER_CUPON]              [numeric](12, 0)  NOT NULL,
        [APLICA_ANEXO1C]                 [varchar](1)      NOT NULL,
        [CUSTODIO]                       [numeric](6, 0)   NOT NULL,
        [FECHAVALOR]                     [numeric](1, 0)   NOT NULL,
        [CLIENTE]                        [numeric](6, 0)   NOT NULL,
        [RESTRICCION]                    [varchar](2)      NOT NULL,
        [FECHA_INFO]                     [date]            NULL,
        [FECHA_EXTRACCION]               [smalldatetime]   NOT NULL CONSTRAINT DF_076_REPORTOS_MN_ME_FEXT DEFAULT (GETDATE()),
        CONSTRAINT PK_RR_076_REPORTOS_MN_ME PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada SILVER.[RR].[076_ENT_REPORTOS_MN_ME] desde cero (estructura V7.1).';
END
ELSE
    PRINT '>> SILVER.[RR].[076_ENT_REPORTOS_MN_ME] lista (ALTER V7.1).';
GO

/* ----------------------------------------------------------------------------
   02 - SILVER SP  [dbo].[076_ENT_REPORTOS_MN_ME]  (ORIGEN LMDA)
        Carga desde BRONZE.[LMDA].[REPORTOS_MN_ME]. DIARIA.
        Filtro: WHERE FECHA_INFO = @FechaDia (columna presente en la tabla LMDA).
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
        -- DIARIA: ventana delimitada por FECHA_INFO (columna en BRONZE.LMDA.REPORTOS_MN_ME)
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
            R.[FECHACONCERTACION], R.[HORACONCERTACION], R.[POSICIONOPERACION], R.[FECHAINICIO], R.[FECHAVENCIMIENTO],
            R.[IMPORTEREPORTO], R.[MONEDAPRECIOUNITARIO], R.[TASAPREMIO], R.[TITULOOBJETOREPORTO], R.[PRECIOUNITARIOTITULOS],
            R.[NUMEROTITULOSOBJETOREPORTO], R.[CONTRAPARTEREPORTO], R.[RESIDENCIA_CONTRAPARTE], R.[PROPIA_TERCEROS], R.[CLIENTE_PROV],
            R.[CORROELECTRONICO], R.[TIPOPOSTURA], R.[OPERACIONBANCOTRABAJO], R.[HAIRCUT], R.[REP_SUSTITUCION],
            R.[MODALIDAD_REPORTO], R.[PLAZO_EVERGREEN], R.[REP_CONJUNTO_VAL], R.[REP_AG_TRIPARTITO], R.[AGENTE_TRIPARTITO],
            R.[TASA_REFERENCIA_PREMIO], R.[SOBRETASA_PREMIO], R.[PERIODO_PAGO_PREMIO], R.[NUMEROIDENTIFICACIONOPERACION],
            R.[CLASIFICACIONCONTABLEOPERACION], R.[FECHAVENCIMIENTO_TITULO], R.[OFICINA], R.[EMISION], R.[SERIE], R.[TIPOVALOR],
            R.[SOBRETASA], R.[EMISOR], R.[DIASXVENCER_CUPON], R.[APLICA_ANEXO1C], R.[CUSTODIO], R.[FECHAVALOR], R.[CLIENTE],
            R.[RESTRICCION], R.[FECHA_INFO]
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
PRINT '>> Creado/actualizado SILVER.dbo.[076_ENT_REPORTOS_MN_ME] (origen LMDA.REPORTOS_MN_ME).';
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
PRINT '>> Ajuste 076_ENT_REPORTOS_MN_ME (origen LMDA.REPORTOS_MN_ME, layout V7.1) completado.';
GO
