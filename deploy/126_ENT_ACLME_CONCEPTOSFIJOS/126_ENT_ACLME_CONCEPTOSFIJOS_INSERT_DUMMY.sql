-- ============================================================
-- INSERT DUMMY  126_ENT_ACLME_CONCEPTOSFIJOS
-- Carga 11 filas en BRONZE.LMDA.ACLME (mismo insumo; montos del archivo ConceptosFijos v3).
-- FECHA_EXTRACCION = @FechaReporte para que el SP procese el lote del dia (Opcion A).
--
-- Resultado esperado (SP SILVER, @FechaReporte=2025-06-12), agrupado por CONCEPTO:
--   9725 Compras de Spots   = 1000 + 5000                 = 6000   (2 mov)
--   9730 Ventas de Spots    = 16500 + 10000               = 26500  (2 mov)
--   9890 Compras de Forwards= 10000+12000+5000+5000+5000  = 37000  (5 mov)
--   9900 Venta de Forwards  = 15000                        = 15000  (1 mov)
--   (FX2516369350 SW+MXN se descarta; swaps 9895/9910 no se producen)
-- ============================================================
USE [BRONZE]
GO

DECLARE @FechaReporte DATETIME    = '2025-06-12';
DECLARE @Institucion  numeric(6,0) = 40138;   -- placeholder (por cliente)

DELETE FROM [LMDA].[ACLME] WHERE CAST([FECHA_EXTRACCION] AS DATE) = CAST(@FechaReporte AS DATE);

INSERT INTO [LMDA].[ACLME]
    ([ID_SISTEMA], [TIPO_OPERACION], [FECHA_CONCERTACION], [FECHA_INICIO], [FECHA_VALOR],
     [PLAZO], [FECHA_VMTO], [MONTO], [CONTRAPARTE], [MONEDA], [TIPO_CAMBIO], [MONTO_MXN],
     [MONEDA_MXN], [MEDIO], [BROKER], [TIPO_POSTURA], [HORA], [INSTITUCION], [FECHA_EXTRACCION])
SELECT d.*, @Institucion, @FechaReporte
FROM (VALUES
    ('FX2516369350', 'SW', '2025-06-12', '2025-06-12', NULL,  6, '2025-06-20', 10000.00, '10000750', 'MXN', 18.1000,       181000.00, 'USD', NULL, NULL,     NULL,      '09:59'),
    ('FX2516369351', 'SW', '2025-06-12', '2025-06-13', NULL,  6, '2025-07-04',  1000.00, '10000750', 'USD', 18.2000,        18200.00, 'MXN', NULL, NULL,     NULL,      '14:32'),
    ('FX2519610393', 'FX', '2025-07-15', '2025-07-15', NULL,  3, '2025-07-18',  5000.00, '10000750', 'USD', 19.0000,        95000.00, 'MXN', NULL, NULL,     NULL,      '14:57'),
    ('FX2520520079', 'FX', '2025-07-24', '2025-07-24', NULL,  4, '2025-07-30', 16500.00, '10000750', 'MXN', 17.5000,       288750.00, 'USD', NULL, NULL,     NULL,      '12:28'),
    ('FX2520545503', 'FX', '2025-07-24', '2025-07-24', NULL,  3, '2025-07-29', 10000.00, '10000750', 'MXN', 19.0000,       190000.00, 'USD', NULL, NULL,     NULL,      '18:31'),
    ('FX2520528523', 'FW', '2025-07-24', '2025-07-24', NULL,  3, '2025-07-29', 10000.00, '10000750', 'USD', 19.0000,       190000.00, 'MXN', NULL, NULL,     NULL,      '18:31'),
    ('FX2520560074', 'FW', '2025-07-24', '2025-07-24', NULL,  4, '2025-07-30', 15000.00, '10000750', 'MXN', 18.5000,       277500.00, 'USD', NULL, NULL,     NULL,      '12:28'),
    ('FX2521048565', 'FW', '2025-07-29', '2025-07-29', NULL,  3, '2025-08-01', 12000.00, '10000750', 'USD', 19.0000,       228000.00, 'MXN', NULL, NULL,     NULL,      '17:14'),
    ('FX2521701258', 'FW', '2025-08-05', '2025-08-05', NULL,  8, '2025-08-15',  5000.00, '10000963', 'USD', 19.5000, 19500000019.50, 'MXN', NULL, NULL,     NULL,      '16:02'),
    ('FX2521774163', 'FW', '2025-08-05', '2025-08-05', NULL, 13, '2025-08-22',  5000.00, '10000963', 'USD', 19.5000,   429000039.00, 'MXN', NULL, 'REMATE', 'AGRESOR', '16:03'),
    ('FX2521764604', 'FW', '2025-08-05', '2025-08-05', NULL, 18, '2025-08-29',  5000.00, '10000963', 'USD', 19.5000,   643500058.50, 'MXN', NULL, 'CICADA', 'AGRESOR', '16:03')
) AS d([ID_SISTEMA], [TIPO_OPERACION], [FECHA_CONCERTACION], [FECHA_INICIO], [FECHA_VALOR],
       [PLAZO], [FECHA_VMTO], [MONTO], [CONTRAPARTE], [MONEDA], [TIPO_CAMBIO], [MONTO_MXN],
       [MONEDA_MXN], [MEDIO], [BROKER], [TIPO_POSTURA], [HORA]);

PRINT 'INSERT DUMMY: 11 filas en BRONZE.LMDA.ACLME.';
GO

-- Probar:
--   EXEC [SILVER].[dbo].[126_ENT_ACLME_CONCEPTOSFIJOS] @FechaSistema = '2025-06-12';
--   EXEC [ION].[dbo].[126_ENT_ACLME_CONCEPTOSFIJOS]    @FECHA        = '2025-06-12';
