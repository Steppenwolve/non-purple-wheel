/* ============================================================================
   076_ENT_REPORTOS_MN_ME_ROLLBACK.sql
   Fin: Revertir el AJUSTE (origen LMDA + layout V7.1) y restaurar el 076
        a su definicion ORIGINAL (self-select, estructura previa).
   IMPORTANTE: el DROP de la tabla nueva elimina los datos cargados.
   ============================================================================ */

USE [SILVER];
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE name='076_ENT_REPORTOS_MN_ME' AND schema_id=SCHEMA_ID('RR') AND type='U') DROP TABLE [RR].[076_ENT_REPORTOS_MN_ME];
GO
CREATE TABLE [RR].[076_ENT_REPORTOS_MN_ME] (
    [ID] uniqueidentifier NOT NULL DEFAULT (newid()),
    [FECHACONCERTACION] date NOT NULL,
    [HORACONCERTACION] numeric(5,2) NOT NULL,
    [POSICIONOPERACION] varchar(1) NOT NULL,
    [FECHAINICIO] date NOT NULL,
    [FECHAVENCIMIENTO] date NOT NULL,
    [IMPORTEREPORTO] numeric(12,0) NOT NULL,
    [MONEDAPRECIOUNITARIO] varchar(3) NOT NULL,
    [TASAPREMIO] numeric(8,4) NOT NULL,
    [TIPOTASAPREMIO] varchar(1) NOT NULL,
    [TITULOOBJETOREPORTO] varchar(18) NOT NULL,
    [PRECIOUNITARIOTITULOS] numeric(19,8) NOT NULL,
    [NUMEROTITULOSOBJETOREPORTO] numeric(12,0) NOT NULL,
    [CONTRAPARTE_REPORTO] varchar(6) NOT NULL,
    [CORROELECTRONICO] varchar(2) NOT NULL,
    [TIPOPOSTURA] varchar(2) NOT NULL,
    [OPERACIONBANCOTRABAJO] varchar(1) NOT NULL,
    [NUMEROIDENTIFICACIONOPERACION] varchar(37) NOT NULL,
    [TIPOMODIFICACION] varchar(1) NOT NULL,
    [CLASIFICACIONCONTABLEOPERACION] varchar(2) NOT NULL,
    [FECHAVENCIMIENTO_TITULO] date NOT NULL,
    [OFICINA] varchar(1) NOT NULL,
    [EMISION] varchar(50) NOT NULL,
    [SERIE] varchar(50) NOT NULL,
    [TIPOVALOR] varchar(50) NOT NULL,
    [SOBRETASA] varchar(1) NOT NULL,
    [EMISOR] varchar(6) NOT NULL,
    [DIASXVENCER_CUPON] numeric(12,0) NOT NULL,
    [APLICA_ANEXO1C] varchar(1) NOT NULL,
    [CUSTODIO] numeric(6,0) NOT NULL,
    [FECHAVALOR] numeric(1,0) NOT NULL,
    [CLIENTE] numeric(6,0) NOT NULL,
    [RESTRICCION] varchar(2) NOT NULL,
    [FECHA_EXTRACCION] smalldatetime NOT NULL DEFAULT (getdate())
);
GO

-- SP SILVER original
GO
CREATE OR ALTER PROCEDURE [dbo].[076_ENT_REPORTOS_MN_ME] @CorreoNotificacion NVARCHAR(255) = NULL,
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
	DECLARE @NombreJob NVARCHAR(128) = '[076_ENT_REPORTOS_MN_ME]';
	DECLARE @FechaIni DATE,
		@FechaFin DATE;

	BEGIN TRY
		SET @FechaIni = datefromparts(year(@FechaSistema), month(@FechaSistema), 1)
		SET @FechaFin = Dateadd(month, 1, @FechaIni) --------------------------------------------------------------------------------
			-- QUERY

		IF EXISTS (
				SELECT ID
				FROM [SILVER].[RR].[076_ENT_REPORTOS_MN_ME]
				WHERE [FECHAVENCIMIENTO] = @FechaSistema
				)
		BEGIN
			DELETE
			FROM [SILVER].[RR].[076_ENT_REPORTOS_MN_ME]
			WHERE [FECHAVENCIMIENTO] = @FechaSistema;

			SET @FilasEliminadas = @@ROWCOUNT;
			SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));

			PRINT @LogMessage;

			SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
		END;

		INSERT INTO [RR].[076_ENT_REPORTOS_MN_ME] (
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
			[CONTRAPARTE_REPORTO],
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
			[RESTRICCION]
			)
		SELECT [FECHACONCERTACION],
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
			[CONTRAPARTE_REPORTO],
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
			[RESTRICCION]
		FROM [SILVER].[RR].[076_ENT_REPORTOS_MN_ME]
		WHERE [FECHAVENCIMIENTO] = @FechaSistema

		---------------------------------------------------------------------------------------------
		SET @FilasInsertadas = @@ROWCOUNT;
		SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));

		PRINT @LogMessage;

		SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
	END TRY

	BEGIN CATCH
		SET @ExitoEjecucion = 0;
		SET @MensajeError = ERROR_MESSAGE();
		SET @LogMessage = 'Error durante la ejecución: ' + @MensajeError;

		PRINT @LogMessage;

		SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
	END CATCH -- Preparar el mensaje detallado para la alerta

	DECLARE @Asunto NVARCHAR(255);
	DECLARE @Cuerpo NVARCHAR(MAX);
	DECLARE @FechaFinalizacion DATETIME = GETDATE();
	DECLARE @DuracionEjecucion VARCHAR(20) = CAST(DATEDIFF(SECOND, @FechaInicio, @FechaFinalizacion) AS VARCHAR(10)) + ' segundos';

	-- Solo enviar alerta si hay un error
	IF @ExitoEjecucion = 0
		AND @CorreoNotificacion IS NOT NULL
		AND @PerfilCorreo IS NOT NULL
	BEGIN
		SET @Asunto = 'ALERTA: Error en ' + ISNULL(@NombreJob, 'Job Desconocido');
		SET @Cuerpo = 'Se ha producido un error durante la ejecución de.' + @NombreJob + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 'Detalles del Job:' + CHAR(13) + CHAR(10) + '- Nombre del Job: ' + ISNULL(@NombreJob, 'No especificado') + CHAR(13) + CHAR(10) + '- Programado por: ' + ISNULL(@ProgramadorJob, 'No especificado') + CHAR(13) + CHAR(10) + '- Fecha y hora de inicio: ' + CONVERT(VARCHAR, @FechaInicio, 120) + CHAR(13) + CHAR(10) + '- Fecha y hora de finalización: ' + CONVERT(VARCHAR, @FechaFinalizacion, 120) + CHAR(13) + CHAR(10) + '- Duración de la ejecución: ' + @DuracionEjecucion + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 'Detalles de la Ejecución:' + CHAR(13) + CHAR(10) + 'Mensaje de Error:' + CHAR(13) + CHAR(10) + @MensajeError + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 'Log de Ejecución:' + CHAR(13) + CHAR(10) + @DetallesLog;

		BEGIN TRY
			EXEC msdb.dbo.sp_send_dbmail @profile_name = @PerfilCorreo,
				@recipients = @CorreoNotificacion,
				@subject = @Asunto,
				@body = @Cuerpo,
				@body_format = 'TEXT',
				@importance = 'High';

			SET @LogMessage = 'Alerta de error enviada exitosamente.';

			PRINT @LogMessage;

			SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
		END TRY

		BEGIN CATCH
			SET @LogMessage = 'Error al enviar alerta: ' + ERROR_MESSAGE();

			PRINT @LogMessage;

			SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
		END CATCH
	END -- Registrar en la tabla de log

	INSERT INTO dbo.LogSilverDiario (
		FechaEjecucion,
		FilasInsertadas,
		EstadoEjecucion,
		MensajeError,
		DetallesLog,
		NombreJob,
		ProgramadorJob
		)
	VALUES (
		@FechaInicio,
		@FilasInsertadas,
		CASE 
			WHEN @ExitoEjecucion = 1
				THEN 'Exitoso'
			ELSE 'Error'
			END,
		CASE 
			WHEN @ExitoEjecucion = 1
				THEN NULL
			ELSE @MensajeError
			END,
		@DetallesLog,
		@NombreJob,
		@ProgramadorJob
		);

	SET @LogMessage = 'Proceso completado y registrado en la tabla de log.';

	PRINT @LogMessage;
END;
GO

USE [ION];
GO
-- SP ION original
CREATE OR ALTER PROCEDURE [dbo].[076_ENT_REPORTOS_MN_ME]
    @FECHA DATE
AS
BEGIN
 	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
   
 
	SELECT 
		[ID],
		[FECHA_EXTRACCION],
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
		[CONTRAPARTE_REPORTO],
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
		[RESTRICCION]
    FROM [SILVER].[RR].[076_ENT_REPORTOS_MN_ME]
    WHERE [FECHAVENCIMIENTO] = @FECHA 

END;

--EXEC [dbo].[091_ENT_ML] @FECHA = '20240420'

    -- Para reportes diarios WHERE FECHA_REPORTE = @Fecha
GO
PRINT '>> Rollback 076 completado (restaurado a estructura original).';
GO
