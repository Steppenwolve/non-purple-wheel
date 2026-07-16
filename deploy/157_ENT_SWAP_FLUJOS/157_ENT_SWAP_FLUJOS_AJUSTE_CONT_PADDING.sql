-- ============================================================
-- AJUSTE  157_ENT_SWAP_FLUJOS — CONT zero-padding en SP ION
-- Layout indica longitud 6 para CONT (catalogo CASFIM_V2).
-- RIGHT('000000' + CONT, 6) garantiza el padding sin importar
-- cuantos digitos lleguen desde SILVER.
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[157_ENT_SWAP_FLUJOS]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        RIGHT('000000' + T.[CONT], 6)               AS [CONT],        -- ORDEN  1
        FORMAT(T.[FECHA],      'yyyy/MM/dd')         AS [FECHA],       -- ORDEN  2
        T.[NU_ID]                                    AS [NU_ID],       -- ORDEN  3
        T.[IMP_BASE]                                 AS [IMP_BASE],    -- ORDEN  4
        T.[NU_FL_RE]                                 AS [NU_FL_RE],    -- ORDEN  5
        FORMAT(T.[FEIN_FL_RE], 'yyyy/MM/dd')         AS [FEIN_FL_RE],  -- ORDEN  6
        FORMAT(T.[FEIN_VE_RE], 'yyyy/MM/dd')         AS [FEIN_VE_RE],  -- ORDEN  7
        T.[TIP_TAS_RE]                               AS [TIP_TAS_RE],  -- ORDEN  8
        T.[TAS_FIJ_RE]                               AS [TAS_FIJ_RE],  -- ORDEN  9
        T.[TAS_REF_RE]                               AS [TAS_REF_RE],  -- ORDEN 10
        T.[OP1_TAS_RE]                               AS [OP1_TAS_RE],  -- ORDEN 11
        T.[PT1_TAS_RE]                               AS [PT1_TAS_RE],  -- ORDEN 12
        T.[FE_REF_RE]                                AS [FE_REF_RE],   -- ORDEN 13
        T.[NU_FL_EN]                                 AS [NU_FL_EN],    -- ORDEN 14
        FORMAT(T.[FE_IN_FLRE], 'yyyy/MM/dd')         AS [FE_IN_FLRE],  -- ORDEN 15
        FORMAT(T.[FE_VE_FLEN], 'yyyy/MM/dd')         AS [FE_VE_FLEN],  -- ORDEN 16
        T.[TIP_TAS_EN]                               AS [TIP_TAS_EN],  -- ORDEN 17
        T.[TAS_FIJ_EN]                               AS [TAS_FIJ_EN],  -- ORDEN 18
        T.[TAS_REF_EN]                               AS [TAS_REF_EN],  -- ORDEN 19
        T.[OP1_TAS_EN]                               AS [OP1_TAS_EN],  -- ORDEN 20
        T.[PT1_TAS_EN]                               AS [PT1_TAS_EN],  -- ORDEN 21
        T.[FE_REF_EN]                                AS [FE_REF_EN],   -- ORDEN 22
        T.[IMP_BA_EN]                                AS [IMP_BA_EN],   -- ORDEN 23
        T.[IMP_BA_RE]                                AS [IMP_BA_RE],   -- ORDEN 24
        FORMAT(T.[FEIN_FL_EN], 'yyyy/MM/dd')         AS [FEIN_FL_EN],  -- ORDEN 25
        FORMAT(T.[FEIN_VE_EN], 'yyyy/MM/dd')         AS [FEIN_VE_EN],  -- ORDEN 26
        T.[MODIFICA]                                 AS [MODIFICA],    -- ORDEN 27
        FORMAT(T.[FECHAINFO],  'yyyy/MM/dd')         AS [FECHAINFO]    -- ORDEN 28
    FROM [SILVER].[RR].[157_ENT_SWAP_FLUJOS] T
    WHERE T.[FECHAINFO] = @FECHA;
END;
GO
