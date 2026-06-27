/* ============================================================================
   121_ENT_REPORTOS_MN_ME_AJUSTE.sql
   Reporte      : ENT_REPORTOS_MN_ME
   Objeto       : 121_ENT_REPORTOS_MN_ME  (SILVER e ION)
   Layout       : Layout_REPORTOS_MN_ME_V3_FT_REPORTOS.xlsx (hoja FT_REPORTOS, 32 campos)
   Periodicidad : DIARIA
   Patron       : ORIGEN LMDA
                  SP SILVER: INSERT...SELECT FROM BRONZE.[LMDA].[FT_REPORTOS]
                             filtrando FECHA_INFO = @FechaDia
   Enfoque      : ALTER sobre tablas existentes; sp_rename si aplica
   Hallazgos    : ver 121_ENT_REPORTOS_MN_ME_HALLAZGOS.md
   Decisiones   :
     - SILVER tenia 13 columnas del layout V7.1 que NO estan en V3 (se eliminan).
     - TIPOTASAPREMIO existia como int NULL; se convierte a varchar(1) NOT NULL.
     - TIPOMODIFICACION y FECHA_INFO (control LMDA) se agregan.
     - SP SILVER y ION se corrigen para reflejar V3 y filtrar por FECHA_INFO.
     - FECHA_INFO no se expone en ION (campo de control interno).
     - Formatos de fecha en ION: AAAA/MM/DD (consideracion 12 — yyyy/MM/dd).
   ============================================================================ */

/* ----------------------------------------------------------------------------
   00 - BRONZE.[LMDA].[FT_REPORTOS]
        Agregar columnas faltantes del layout V3:
          TIPOTASAPREMIO, TIPOMODIFICACION (datos del origen)
          FECHA_INFO (columna de control LMDA, no expuesta en ION)
   ---------------------------------------------------------------------------- */
USE [BRONZE];
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_REPORTOS' AND COLUMN_NAME='TIPOTASAPREMIO')
    ALTER TABLE [LMDA].[FT_REPORTOS] ADD [TIPOTASAPREMIO] varchar(1) NULL;

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_REPORTOS' AND COLUMN_NAME='TIPOMODIFICACION')
    ALTER TABLE [LMDA].[FT_REPORTOS] ADD [TIPOMODIFICACION] varchar(1) NULL;

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='FT_REPORTOS' AND COLUMN_NAME='FECHA_INFO')
    ALTER TABLE [LMDA].[FT_REPORTOS] ADD [FECHA_INFO] date NULL;

PRINT '>> BRONZE.[LMDA].[FT_REPORTOS]: columnas V3 verificadas.';
GO

/* ----------------------------------------------------------------------------
   01 - SILVER.[RR].[121_ENT_REPORTOS_MN_ME]
        a) Eliminar 13 columnas del layout V7.1 que NO estan en V3.
        b) Corregir tipo de TIPOTASAPREMIO: int NULL -> varchar(1) NOT NULL.
        c) Agregar TIPOMODIFICACION varchar(1) NOT NULL.
        d) Agregar FECHA_INFO date NULL (control LMDA).
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO

-- a) Eliminar DEFAULT constraints de las 13 columnas V7.1 antes de eliminar columnas
DECLARE @sqldrop NVARCHAR(MAX) = '';
SELECT @sqldrop = @sqldrop
    + 'ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP CONSTRAINT ' + dc.name + '; '
FROM sys.default_constraints dc
JOIN sys.columns col ON col.default_object_id = dc.object_id
JOIN sys.objects o   ON o.object_id = dc.parent_object_id
WHERE o.name = '121_ENT_REPORTOS_MN_ME'
  AND col.name IN (
    'RESIDENCIA_CONTRAPARTE','PROPIA_TERCEROS','CLIENTE_PROV','HAIRCUT',
    'REP_SUSTITUCION','MODALIDAD_REPORTO','PLAZO_EVERGREEN','REP_CONJUNTO_VAL',
    'REP_AG_TRIPARTITO','AGENTE_TRIPARTITO','TASA_REFERENCIA_PREMIO',
    'SOBRETASA_PREMIO','PERIODO_PAGO_PREMIO'
  );
IF LEN(@sqldrop) > 0 EXEC sp_executesql @sqldrop;
PRINT '>> Constraints de columnas V7.1 eliminados (si existian).';
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='RESIDENCIA_CONTRAPARTE')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [RESIDENCIA_CONTRAPARTE];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='PROPIA_TERCEROS')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [PROPIA_TERCEROS];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='CLIENTE_PROV')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [CLIENTE_PROV];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='HAIRCUT')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [HAIRCUT];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='REP_SUSTITUCION')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [REP_SUSTITUCION];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='MODALIDAD_REPORTO')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [MODALIDAD_REPORTO];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='PLAZO_EVERGREEN')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [PLAZO_EVERGREEN];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='REP_CONJUNTO_VAL')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [REP_CONJUNTO_VAL];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='REP_AG_TRIPARTITO')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [REP_AG_TRIPARTITO];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='AGENTE_TRIPARTITO')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [AGENTE_TRIPARTITO];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='TASA_REFERENCIA_PREMIO')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [TASA_REFERENCIA_PREMIO];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='SOBRETASA_PREMIO')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [SOBRETASA_PREMIO];

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='PERIODO_PAGO_PREMIO')
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP COLUMN [PERIODO_PAGO_PREMIO];

PRINT '>> 13 columnas V7.1 eliminadas de SILVER.[RR].[121_ENT_REPORTOS_MN_ME] (si existian).';
GO

-- b) Corregir TIPOTASAPREMIO: int NULL -> varchar(1) NOT NULL
--    (El V3 layout define TIPOTASAPREMIO como TEXTO 1; catalogo: F=Fija, V=Variable)
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME'
             AND COLUMN_NAME='TIPOTASAPREMIO' AND DATA_TYPE='int')
BEGIN
    -- Eliminar DEFAULT constraint si existe
    DECLARE @sqltt NVARCHAR(MAX) = '';
    SELECT @sqltt = 'ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] DROP CONSTRAINT ' + dc.name
    FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o   ON o.object_id = dc.parent_object_id
    WHERE o.name='121_ENT_REPORTOS_MN_ME' AND col.name='TIPOTASAPREMIO';
    IF LEN(@sqltt) > 0 EXEC sp_executesql @sqltt;

    -- Convertir NULLs a '0' para poder cambiar a NOT NULL
    UPDATE [RR].[121_ENT_REPORTOS_MN_ME] SET [TIPOTASAPREMIO] = 0 WHERE [TIPOTASAPREMIO] IS NULL;

    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] ALTER COLUMN [TIPOTASAPREMIO] varchar(1) NOT NULL;

    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME]
        ADD CONSTRAINT DF_121_TIPOTASAPREMIO DEFAULT ('') FOR [TIPOTASAPREMIO];

    PRINT '>> TIPOTASAPREMIO convertido a varchar(1) NOT NULL.';
END
ELSE
    PRINT '>> TIPOTASAPREMIO: ya es varchar o no requiere cambio.';
GO

-- c) Agregar TIPOMODIFICACION (ORDEN 18 en V3, catalogo: A=Alta, B=Baja)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='TIPOMODIFICACION')
BEGIN
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME]
        ADD [TIPOMODIFICACION] varchar(1) NOT NULL
            CONSTRAINT DF_121_TIPOMODIFICACION DEFAULT ('');
    PRINT '>> Columna TIPOMODIFICACION agregada.';
END
ELSE
    PRINT '>> TIPOMODIFICACION ya existe.';
GO

-- d) Agregar FECHA_INFO (control LMDA, no expuesta en ION)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='121_ENT_REPORTOS_MN_ME' AND COLUMN_NAME='FECHA_INFO')
BEGIN
    ALTER TABLE [RR].[121_ENT_REPORTOS_MN_ME] ADD [FECHA_INFO] date NULL;
    PRINT '>> Columna FECHA_INFO agregada.';
END
ELSE
    PRINT '>> FECHA_INFO ya existe.';
GO

PRINT '>> SILVER.[RR].[121_ENT_REPORTOS_MN_ME]: estructura V3 aplicada.';
GO

/* ----------------------------------------------------------------------------
   02 - SILVER SP  [dbo].[121_ENT_REPORTOS_MN_ME]
        Origen LMDA (BRONZE.[LMDA].[FT_REPORTOS]). DIARIA. Filtro por FECHA_INFO.
        Columnas del layout V3 unicamente (32 campos + FECHA_INFO de control).
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[121_ENT_REPORTOS_MN_ME]
    @CorreoNotificacion NVARCHAR(255) = NULL,
    @PerfilCorreo       NVARCHAR(255) = NULL,
    @ProgramadorJob     NVARCHAR(128) = NULL,
    @FechaSistema       DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @MensajeError   NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion BIT           = 1;
    DECLARE @FilasInsertadas INT          = 0;
    DECLARE @FilasEliminadas INT          = 0;
    DECLARE @LogMessage     NVARCHAR(MAX) = '';
    DECLARE @DetallesLog    NVARCHAR(MAX) = '';
    DECLARE @FechaInicio    DATETIME      = GETDATE();
    DECLARE @NombreJob      NVARCHAR(128) = '[121_ENT_REPORTOS_MN_ME]';
    DECLARE @FechaDia       DATE          = CAST(@FechaSistema AS DATE);

    BEGIN TRY
        -- DIARIA: ventana = dia exacto de FECHA_INFO
        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[121_ENT_REPORTOS_MN_ME]
            WHERE [FECHA_INFO] = @FechaDia
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[121_ENT_REPORTOS_MN_ME]
            WHERE [FECHA_INFO] = @FechaDia;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[121_ENT_REPORTOS_MN_ME] (
            [FECHACONCERTACION],
            [HORACONCERTACION],
            [POSICIONOPERACION],
            [FECHAINICIO],
            [FECHAVENCIMIENTO],
            [IMPORTEREPORTO],
            [MONEDAPRECIOUNITARIO],
            [TASAPREMIO],
            [TIPOTASAPREMIO],
            [TITULOOBJETOREPORTO],
            [PRECIOUNITARIOTITULOS],
            [NUMEROTITULOSOBJETOREPORTO],
            [CONTRAPARTEREPORTO],
            [CORROELECTRONICO],
            [TIPOPOSTURA],
            [OPERACIONBANCOTRABAJO],
            [NUMEROIDENTIFICACIONOPERACION],
            [TIPOMODIFICACION],
            [CLASIFICACIONCONTABLEOPERACION],
            [FECHAVENCIMIENTO_TITULO],
            [OFICINA],
            [EMISION],
            [SERIE],
            [TIPOVALOR],
            [SOBRETASA],
            [EMISOR],
            [DIASXVENCER_CUPON],
            [APLICA_ANEXO1C],
            [CUSTODIO],
            [FECHAVALOR],
            [CLIENTE],
            [RESTRICCION],
            [FECHA_INFO]
        )
        SELECT
            R.[FECHACONCERTACION],
            R.[HORACONCERTACION],
            R.[POSICIONOPERACION],
            R.[FECHAINICIO],
            R.[FECHAVENCIMIENTO],
            R.[IMPORTEREPORTO],
            R.[MONEDAPRECIOUNITARIO],
            R.[TASAPREMIO],
            R.[TIPOTASAPREMIO],
            R.[TITULOOBJETOREPORTO],
            R.[PRECIOUNITARIOTITULOS],
            R.[NUMEROTITULOSOBJETOREPORTO],
            R.[CONTRAPARTEREPORTO],
            R.[CORROELECTRONICO],
            R.[TIPOPOSTURA],
            R.[OPERACIONBANCOTRABAJO],
            R.[NUMEROIDENTIFICACIONOPERACION],
            R.[TIPOMODIFICACION],
            R.[CLASIFICACIONCONTABLEOPERACION],
            R.[FECHAVENCIMIENTO_TITULO],
            R.[OFICINA],
            R.[EMISION],
            R.[SERIE],
            R.[TIPOVALOR],
            R.[SOBRETASA],
            R.[EMISOR],
            R.[DIASXVENCER_CUPON],
            R.[APLICA_ANEXO1C],
            R.[CUSTODIO],
            R.[FECHAVALOR],
            R.[CLIENTE],
            R.[RESTRICCION],
            R.[FECHA_INFO]
        FROM [BRONZE].[LMDA].[FT_REPORTOS] R
        WHERE R.[FECHA_INFO] = @FechaDia;

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

    IF @ExitoEjecucion = 0 AND @CorreoNotificacion IS NOT NULL AND @PerfilCorreo IS NOT NULL
    BEGIN
        DECLARE @Asunto NVARCHAR(255) = 'ALERTA: Error en ' + @NombreJob;
        DECLARE @Cuerpo NVARCHAR(MAX) = 'Error en ' + @NombreJob + CHAR(13) + CHAR(10)
            + '- Programado por: ' + ISNULL(@ProgramadorJob, 'No especificado') + CHAR(13) + CHAR(10)
            + '- Inicio: '         + CONVERT(VARCHAR, @FechaInicio, 120) + CHAR(13) + CHAR(10)
            + '- Mensaje: '        + @MensajeError + CHAR(13) + CHAR(10)
            + 'Log:' + CHAR(13) + CHAR(10) + @DetallesLog;
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
            SET @DetallesLog = @DetallesLog + 'Error al enviar alerta: ' + ERROR_MESSAGE() + CHAR(13) + CHAR(10);
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario
        (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (
        @FechaInicio, @FilasInsertadas,
        CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion = 1 THEN NULL ELSE @MensajeError END,
        @DetallesLog, @NombreJob, @ProgramadorJob
    );
END;
GO
PRINT '>> Creado/actualizado SILVER.dbo.[121_ENT_REPORTOS_MN_ME] (origen LMDA.FT_REPORTOS, V3, diaria).';
GO

/* ----------------------------------------------------------------------------
   03 - ION SP  [dbo].[121_ENT_REPORTOS_MN_ME]  (entrega V3)
        32 cols del layout en orden ORDEN del layout.
        FECHA_INFO NO se expone (campo de control interno).
        Fechas: AAAA/MM/DD -> FORMAT(col,'yyyy/MM/dd') (consideracion 12).
        Filtro: FECHA_INFO = @FECHA (diaria).
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[121_ENT_REPORTOS_MN_ME]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- Orden segun ORDEN del layout V3 (consideracion 14).
    -- Fechas: AAAA/MM/DD -> FORMAT(...,'yyyy/MM/dd') (consideracion 12).
    -- FECHA_INFO no expuesta: campo de control LMDA interno.
    SELECT
        FORMAT(S.[FECHACONCERTACION],     'yyyy/MM/dd') AS FECHACONCERTACION,     -- ORDEN 1
        S.[HORACONCERTACION]                            AS HORACONCERTACION,       -- ORDEN 2
        S.[POSICIONOPERACION]                           AS POSICIONOPERACION,      -- ORDEN 3
        FORMAT(S.[FECHAINICIO],           'yyyy/MM/dd') AS FECHAINICIO,            -- ORDEN 4
        FORMAT(S.[FECHAVENCIMIENTO],      'yyyy/MM/dd') AS FECHAVENCIMIENTO,       -- ORDEN 5
        S.[IMPORTEREPORTO]                              AS IMPORTEREPORTO,         -- ORDEN 6
        S.[MONEDAPRECIOUNITARIO]                        AS MONEDAPRECIOUNITARIO,   -- ORDEN 7
        S.[TASAPREMIO]                                  AS TASAPREMIO,             -- ORDEN 8
        S.[TIPOTASAPREMIO]                              AS TIPOTASAPREMIO,         -- ORDEN 9
        S.[TITULOOBJETOREPORTO]                         AS TITULOOBJETOREPORTO,    -- ORDEN 10
        S.[PRECIOUNITARIOTITULOS]                       AS PRECIOUNITARIOTITULOS,  -- ORDEN 11
        S.[NUMEROTITULOSOBJETOREPORTO]                  AS NUMEROTITULOSOBJETOREPORTO, -- ORDEN 12
        S.[CONTRAPARTEREPORTO]                          AS CONTRAPARTEREPORTO,     -- ORDEN 13
        S.[CORROELECTRONICO]                            AS CORROELECTRONICO,       -- ORDEN 14
        S.[TIPOPOSTURA]                                 AS TIPOPOSTURA,            -- ORDEN 15
        S.[OPERACIONBANCOTRABAJO]                       AS OPERACIONBANCOTRABAJO,  -- ORDEN 16
        S.[NUMEROIDENTIFICACIONOPERACION]               AS NUMEROIDENTIFICACIONOPERACION, -- ORDEN 17
        S.[TIPOMODIFICACION]                            AS TIPOMODIFICACION,       -- ORDEN 18
        S.[CLASIFICACIONCONTABLEOPERACION]              AS CLASIFICACIONCONTABLEOPERACION, -- ORDEN 19
        FORMAT(S.[FECHAVENCIMIENTO_TITULO],'yyyy/MM/dd') AS FECHAVENCIMIENTO_TITULO, -- ORDEN 20
        S.[OFICINA]                                     AS OFICINA,                -- ORDEN 21
        S.[EMISION]                                     AS EMISION,                -- ORDEN 22
        S.[SERIE]                                       AS SERIE,                  -- ORDEN 23
        S.[TIPOVALOR]                                   AS TIPOVALOR,              -- ORDEN 24
        S.[SOBRETASA]                                   AS SOBRETASA,              -- ORDEN 25
        S.[EMISOR]                                      AS EMISOR,                 -- ORDEN 26
        S.[DIASXVENCER_CUPON]                           AS DIASXVENCER_CUPON,      -- ORDEN 27
        S.[APLICA_ANEXO1C]                              AS APLICA_ANEXO1C,         -- ORDEN 28
        S.[CUSTODIO]                                    AS Custodio,               -- ORDEN 29
        S.[FECHAVALOR]                                  AS FechaValor,             -- ORDEN 30
        S.[CLIENTE]                                     AS Cliente,                -- ORDEN 31
        S.[RESTRICCION]                                 AS Restriccion             -- ORDEN 32
    FROM [SILVER].[RR].[121_ENT_REPORTOS_MN_ME] S
    WHERE S.[FECHA_INFO] = @FECHA;
END;
GO
PRINT '>> Creado/actualizado ION.dbo.[121_ENT_REPORTOS_MN_ME] (salida V3, 32 cols, diaria).';
GO

/* ----------------------------------------------------------------------------
   04 - ION.dbo.INDICE_REPORTES : verificar registro 121
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 121)
    UPDATE dbo.INDICE_REPORTES
       SET nombre='ENT_REPORTOS_MN_ME', frecuencia='Diaria'
     WHERE numero = 121;
ELSE
    INSERT INTO dbo.INDICE_REPORTES (numero, nombre, frecuencia, activo, nombre_archivo)
    VALUES (121, 'ENT_REPORTOS_MN_ME', 'Diaria', 0, NULL);
PRINT '>> Registro 121 verificado en ION.dbo.INDICE_REPORTES.';
GO
PRINT '>> Ajuste 121_ENT_REPORTOS_MN_ME (layout V3, origen LMDA.FT_REPORTOS, diaria) completado.';
GO
