-- ============================================================
-- SUSTITUIR tabla de origen LMDA  ->  BRONZE.LMDA.R04A_MOV_420_24
-- Recibe el insumo desagregado (Excel Simulado_Desagregado_v2, hoja Fuente_datos).
-- Estructura NUEVA (desagregada por E1/E2/E3), distinta a la SILVER actual.
-- ============================================================
USE [BRONZE]
GO

-- "Sustituir": si existe, se reemplaza por la nueva estructura
IF OBJECT_ID('[LMDA].[R04A_MOV_420_24]', 'U') IS NOT NULL
BEGIN
    DROP TABLE [LMDA].[R04A_MOV_420_24];
    PRINT 'BRONZE.LMDA.R04A_MOV_420_24 existente eliminada.';
END
GO

CREATE TABLE [LMDA].[R04A_MOV_420_24] (
    [ID]               uniqueidentifier NOT NULL CONSTRAINT [DF_LMDA_R04A_MOV_420_24_ID] DEFAULT (NEWID()),   -- control
    [CONCEPTO]         varchar(96)      NOT NULL,
    [TIPO]             varchar(50)      NOT NULL,   -- Entrada / Salida
    [TIPO_MOV_420_424] numeric(2,0)     NOT NULL,   -- valores 1..42
    [ESTATUS]          varchar(16)      NOT NULL,   -- Aplica / No aplica
    [TIPO_CARTERA]     varchar(96)      NOT NULL,
    [RESTRINGIDO]      varchar(50)      NOT NULL,
    [CUENTA_CREDITO]   numeric(15,0)    NULL,        -- no obligatorio; sin decimales
    [E1]               numeric(16,2)    NULL,        -- no obligatorio
    [E2]               numeric(16,2)    NULL,        -- no obligatorio
    [E3]               numeric(16,2)    NULL,        -- no obligatorio
    [FECHA_INFO]       date             NOT NULL,    -- obligatorio
    [FECHA_EXTRACCION] smalldatetime    NOT NULL CONSTRAINT [DF_LMDA_R04A_MOV_420_24_FEXT] DEFAULT (GETDATE()),  -- control
    CONSTRAINT [PK_LMDA_R04A_MOV_420_24] PRIMARY KEY ([ID])
);
PRINT 'BRONZE.LMDA.R04A_MOV_420_24 creada.';
GO
