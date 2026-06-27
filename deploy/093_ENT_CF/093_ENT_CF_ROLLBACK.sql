/* ============================================================================
   093_ENT_CF_ROLLBACK.sql
   Fin: Revertir el AJUSTE y restaurar el 093 a su estado original:
        - Nombre [093_ ENT_CF] (con espacio), self-select, sin FECHA_INFO.
   Incluye: eliminacion de BRONZE.[LMDA].[CF_I] (creada por el AJUSTE).
   IMPORTANTE: el DROP de tablas elimina los datos cargados.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   00 - Eliminar BRONZE.[LMDA].[CF_I] (creada por el AJUSTE)
   ---------------------------------------------------------------------------- */
USE [BRONZE];
GO
IF EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE s.name='LMDA' AND o.name='CF_I' AND o.type='U'
)
    DROP TABLE [LMDA].[CF_I];
PRINT '>> BRONZE.[LMDA].[CF_I] eliminada (si existia).';
GO

/* ----------------------------------------------------------------------------
   01 - SILVER: eliminar tabla nueva, restaurar tabla original
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name='093_ENT_CF' AND schema_id=SCHEMA_ID('RR') AND type='U')
    DROP TABLE [RR].[093_ENT_CF];
GO
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name='093_ ENT_CF' AND schema_id=SCHEMA_ID('RR') AND type='U')
BEGIN
    CREATE TABLE [RR].[093_ ENT_CF]
    (
        [ID]               [uniqueidentifier] NOT NULL DEFAULT (NEWID()),
        [TIPOOPERACION]    [numeric](2, 0)    NOT NULL,
        [TIPOFONDEO]       [numeric](2, 0)    NOT NULL,
        [FECHA_INICIO]     [date]             NOT NULL,
        [FECHA_VENC]       [date]             NOT NULL,
        [MONTO_OPER]       [numeric](12, 0)   NOT NULL,
        [MONEDA]           [varchar](3)        NOT NULL,
        [CVE_ACREEDOR]     [varchar](18)       NOT NULL,
        [TIP_REL_ACREED]   [numeric](2, 0)    NOT NULL,
        [CVE_OPERACION]    [varchar](34)       NOT NULL,
        [FECHA_EXTRACCION] [smalldatetime]    NOT NULL DEFAULT (GETDATE()),
        CONSTRAINT [PK_093_ ENT_CF] PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Restaurada SILVER.[RR].[093_ ENT_CF].';
END
GO

/* ----------------------------------------------------------------------------
   02 - SILVER SP: eliminar nuevo, restaurar original con nombre con espacio
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name='093_ENT_CF' AND type='P')
    DROP PROCEDURE [dbo].[093_ENT_CF];
GO
CREATE PROCEDURE [dbo].[093_ ENT_CF] @CorreoNotificacion NVARCHAR(255) = NULL,
	@PerfilCorreo NVARCHAR(255) = NULL,
	@ProgramadorJob NVARCHAR(128) = NULL,
	@FechaSistema DATETIME
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @SQL NVARCHAR(MAX);
	DECLARE @MensajeError NVARCHAR(MAX) = '';
	DECLARE @ExitoEjecucion BIT = 1;
	DECLARE @FilasInsertadas INT = 0;
	DECLARE @LogMessage NVARCHAR(MAX) = '';
	DECLARE @DetallesLog NVARCHAR(MAX) = '';
	DECLARE @FechaInicio DATETIME = GETDATE();
	DECLARE @FilasEliminadas INT = 0;
	DECLARE @NombreJob NVARCHAR(128) = '[093_ ENT_CF]  ';
	DECLARE @FechaIni DATE, @FechaFin DATE;

	BEGIN TRY
		SET @FechaIni = DATEADD(DAY, - (DATEPART(WEEKDAY, @FechaSistema) + 5) % 7, @FechaSistema)
		SET @FechaFin = DATEADD(DAY, 7, @FechaIni)

		IF EXISTS (SELECT ID FROM [SILVER].[RR].[093_ ENT_CF]
		           WHERE [FECHA_INICIO] >= @FechaIni AND [FECHA_INICIO] < @FechaFin)
		BEGIN
			DELETE FROM [SILVER].[RR].[093_ ENT_CF]
			WHERE [FECHA_INICIO] >= @FechaIni AND [FECHA_INICIO] < @FechaFin;
			SET @FilasEliminadas = @@ROWCOUNT;
			SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
			PRINT @LogMessage;
			SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
		END;

		INSERT INTO [RR].[093_ ENT_CF] ([TIPOOPERACION],[TIPOFONDEO],[FECHA_INICIO],[FECHA_VENC],
		    [MONTO_OPER],[MONEDA],[CVE_ACREEDOR],[TIP_REL_ACREED],[CVE_OPERACION])
		SELECT [TIPOOPERACION],[TIPOFONDEO],[FECHA_INICIO],[FECHA_VENC],
		    [MONTO_OPER],[MONEDA],[CVE_ACREEDOR],[TIP_REL_ACREED],[CVE_OPERACION]
		FROM [SILVER].[RR].[093_ ENT_CF]
		WHERE [FECHA_INICIO] >= @FechaIni AND [FECHA_INICIO] < @FechaFin;

		SET @FilasInsertadas = @@ROWCOUNT;
		SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
		PRINT @LogMessage;
		SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
	END TRY
	BEGIN CATCH
		SET @ExitoEjecucion = 0;
		SET @MensajeError = ERROR_MESSAGE();
		SET @LogMessage = 'Error durante la ejecucion: ' + @MensajeError;
		PRINT @LogMessage;
		SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
	END CATCH

	IF @ExitoEjecucion = 0 AND @CorreoNotificacion IS NOT NULL AND @PerfilCorreo IS NOT NULL
	BEGIN
		DECLARE @Asunto NVARCHAR(255) = 'ALERTA: Error en ' + ISNULL(@NombreJob,'Job Desconocido');
		DECLARE @Cuerpo NVARCHAR(MAX) = 'Error en ' + @NombreJob + CHAR(13)+CHAR(10) +
		    '- Programado por: ' + ISNULL(@ProgramadorJob,'No especificado') + CHAR(13)+CHAR(10) +
		    '- Mensaje: ' + @MensajeError + CHAR(13)+CHAR(10) + 'Log:' + CHAR(13)+CHAR(10) + @DetallesLog;
		BEGIN TRY
			EXEC msdb.dbo.sp_send_dbmail @profile_name=@PerfilCorreo, @recipients=@CorreoNotificacion,
			     @subject=@Asunto, @body=@Cuerpo, @body_format='TEXT', @importance='High';
		END TRY BEGIN CATCH
			SET @DetallesLog = @DetallesLog + 'Error al enviar alerta: ' + ERROR_MESSAGE() + CHAR(13)+CHAR(10);
		END CATCH
	END

	INSERT INTO dbo.LogSilverDiario (FechaEjecucion, FilasInsertadas, EstadoEjecucion,
	    MensajeError, DetallesLog, NombreJob, ProgramadorJob)
	VALUES (@FechaInicio, @FilasInsertadas,
	    CASE WHEN @ExitoEjecucion=1 THEN 'Exitoso' ELSE 'Error' END,
	    CASE WHEN @ExitoEjecucion=1 THEN NULL ELSE @MensajeError END,
	    @DetallesLog, @NombreJob, @ProgramadorJob);
END;
GO
PRINT '>> Restaurado SILVER.dbo.[093_ ENT_CF] (SP original).';
GO

/* ----------------------------------------------------------------------------
   03 - ION SP: eliminar nuevo, restaurar original con nombre con espacio
   ---------------------------------------------------------------------------- */
USE [ION];
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name='093_ENT_CF' AND type='P')
    DROP PROCEDURE [dbo].[093_ENT_CF];
GO
CREATE PROCEDURE [dbo].[093_ ENT_CF]
    @FECHA DATE
AS
BEGIN
    DECLARE @FechaIni DATE, @FechaFin DATE;
    SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FECHA) + 5) % 7, @FECHA);
    SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

    SELECT
        [ID], [FECHA_EXTRACCION],
        [TIPOOPERACION],[TIPOFONDEO],[FECHA_INICIO],[FECHA_VENC],
        [MONTO_OPER],[MONEDA],[CVE_ACREEDOR],[TIP_REL_ACREED],[CVE_OPERACION]
    FROM [SILVER].[RR].[093_ ENT_CF]
    WHERE [FECHA_INICIO] >= @FechaIni AND [FECHA_INICIO] < @FechaFin;
END;
GO
PRINT '>> Restaurado ION.dbo.[093_ ENT_CF] (SP original).';
GO
PRINT '>> Rollback 093_ENT_CF completado.';
GO
