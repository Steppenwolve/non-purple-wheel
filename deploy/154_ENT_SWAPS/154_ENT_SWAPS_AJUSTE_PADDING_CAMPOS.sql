-- ============================================================
-- AJUSTE  154_ENT_SWAPS — Zero-padding a 6 dígitos en ION
-- Campos: CONT (ORDEN 2), SOCIO_LIQ (ORDEN 44), AG_CAL (ORDEN 46)
-- Los tres son varchar(6) en SILVER; el padding normaliza valores
-- que vienen sin ceros del catálogo CASFIM_V2.
-- Solo se modifica el SP ION; BRONZE y SILVER no cambian.
-- ============================================================

USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[154_ENT_SWAPS]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        T.[OFICINA]                                         AS [OFICINA],        -- ORDEN  1
        RIGHT('000000' + T.[CONT],        6)                AS [CONT],           -- ORDEN  2
        FORMAT(T.[FE_CON_OPE],  'yyyy/MM/dd')               AS [FE_CON_OPE],    -- ORDEN  3
        FORMAT(T.[FE1_FLU_RE],  'yyyy/MM/dd')               AS [FE1_FLU_RE],    -- ORDEN  4
        FORMAT(T.[FEN_FLU_RE],  'yyyy/MM/dd')               AS [FEN_FLU_RE],    -- ORDEN  5
        FORMAT(T.[FE1_FLU_EN],  'yyyy/MM/dd')               AS [FE1_FLU_EN],    -- ORDEN  6
        FORMAT(T.[FEN_FLU_EN],  'yyyy/MM/dd')               AS [FEN_FLU_EN],    -- ORDEN  7
        T.[TIP_DER]                                         AS [TIP_DER],        -- ORDEN  8
        T.[OBJ_OPE]                                         AS [OBJ_OPE],        -- ORDEN  9
        T.[REV_SWAP]                                        AS [REV_SWAP],       -- ORDEN 10
        T.[DET_FLUJO]                                       AS [DET_FLUJO],      -- ORDEN 11
        T.[IMP_BASE]                                        AS [IMP_BASE],       -- ORDEN 12
        T.[MDA_IMP]                                         AS [MDA_IMP],        -- ORDEN 13
        T.[LIQ_FLU]                                         AS [LIQ_FLU],        -- ORDEN 14
        T.[NU_FLU_RE]                                       AS [NU_FLU_RE],      -- ORDEN 15
        T.[NU_FLU_EN]                                       AS [NU_FLU_EN],      -- ORDEN 16
        T.[INT_FLU_RE]                                      AS [INT_FLU_RE],     -- ORDEN 17
        T.[INT_FLU_EN]                                      AS [INT_FLU_EN],     -- ORDEN 18
        T.[TIP_TAS_RE]                                      AS [TIP_TAS_RE],     -- ORDEN 19
        T.[TAS_FIJ_RE]                                      AS [TAS_FIJ_RE],     -- ORDEN 20
        T.[TAS_REF_RE]                                      AS [TAS_REF_RE],     -- ORDEN 21
        T.[REV_TREF_RE]                                     AS [REV_TREF_RE],    -- ORDEN 22
        T.[ANIO_RE]                                         AS [ANIO_RE],        -- ORDEN 23
        T.[FE_REF_RE]                                       AS [FE_REF_RE],      -- ORDEN 24
        T.[FA1_TAS_RE]                                      AS [FA1_TAS_RE],     -- ORDEN 25
        T.[OP1_TAS_RE]                                      AS [OP1_TAS_RE],     -- ORDEN 26
        T.[PT1_TAS_RE]                                      AS [PT1_TAS_RE],     -- ORDEN 27
        T.[TIP_TAS_EN]                                      AS [TIP_TAS_EN],     -- ORDEN 28
        T.[TAS_FIJ_EN]                                      AS [TAS_FIJ_EN],     -- ORDEN 29
        T.[TAS_REF_EN]                                      AS [TAS_REF_EN],     -- ORDEN 30
        T.[REV_TREF_EN]                                     AS [REV_TREF_EN],    -- ORDEN 31
        T.[ANIO_EN]                                         AS [ANIO_EN],        -- ORDEN 32
        T.[FE_REF_EN]                                       AS [FE_REF_EN],      -- ORDEN 33
        T.[FA1_TAS_EN]                                      AS [FA1_TAS_EN],     -- ORDEN 34
        T.[OP1_TAS_EN]                                      AS [OP1_TAS_EN],     -- ORDEN 35
        T.[PT1_TAS_EN]                                      AS [PT1_TAS_EN],     -- ORDEN 36
        T.[CUO_COMP]                                        AS [CUO_COMP],       -- ORDEN 37
        T.[VEN_ANT]                                         AS [VEN_ANT],        -- ORDEN 38
        T.[TER_OPE]                                         AS [TER_OPE],        -- ORDEN 39
        T.[PAQ_EST]                                         AS [PAQ_EST],        -- ORDEN 40
        T.[ID_PAQ_EST]                                      AS [ID_PAQ_EST],     -- ORDEN 41
        T.[CON_PAQ_EST]                                     AS [CON_PAQ_EST],    -- ORDEN 42
        T.[BROKER]                                          AS [BROKER],         -- ORDEN 43
        RIGHT('000000' + T.[SOCIO_LIQ],   6)                AS [SOCIO_LIQ],      -- ORDEN 44
        T.[CAM_COM]                                         AS [CAM_COM],        -- ORDEN 45
        RIGHT('000000' + T.[AG_CAL],      6)                AS [AG_CAL],         -- ORDEN 46
        T.[NUM_CONF]                                        AS [NUM_CONF],       -- ORDEN 47
        T.[NU_ID]                                           AS [NU_ID],          -- ORDEN 48
        T.[NUM_ID_OP_SBY]                                   AS [NUM_ID_OP_SBY],  -- ORDEN 49
        T.[MODIFICA]                                        AS [MODIFICA],       -- ORDEN 50
        T.[INTERC_IMP]                                      AS [INTERC_IMP],     -- ORDEN 51
        T.[IMP_BA_RE]                                       AS [IMP_BA_RE],      -- ORDEN 52
        T.[MDA_IMP_RE]                                      AS [MDA_IMP_RE],     -- ORDEN 53
        T.[IMP_BA_EN]                                       AS [IMP_BA_EN],      -- ORDEN 54
        T.[MDA_IMP_EN]                                      AS [MDA_IMP_EN],     -- ORDEN 55
        T.[PRO_TER]                                         AS [PRO_TER],        -- ORDEN 56
        FORMAT(T.[FECVEN_A],    'yyyy/MM/dd')               AS [FECVEN_A],       -- ORDEN 57
        FORMAT(T.[FECLIQ_A],    'yyyy/MM/dd')               AS [FECLIQ_A],       -- ORDEN 58
        T.[IMP_VEN]                                         AS [IMP_VEN],        -- ORDEN 59
        T.[MDA_VEN]                                         AS [MDA_VEN],        -- ORDEN 60
        T.[VTOT_IMPE]                                       AS [VTOT_IMPE],      -- ORDEN 61
        T.[VPAR_IMPR]                                       AS [VPAR_IMPR],      -- ORDEN 62
        T.[VPAR_IMPE]                                       AS [VPAR_IMPE],      -- ORDEN 63
        T.[PAG_VENA]                                        AS [PAG_VENA],       -- ORDEN 64
        T.[MOT_VENA]                                        AS [MOT_VENA],       -- ORDEN 65
        T.[VEN_ANT_CD]                                      AS [VEN_ANT_CD],     -- ORDEN 66
        T.[NUM_ID_CP]                                       AS [NUM_ID_CP],      -- ORDEN 67
        T.[UTI_N]                                           AS [UTI_N],          -- ORDEN 68
        T.[UTI]                                             AS [UTI],            -- ORDEN 69
        T.[UPI]                                             AS [UPI],            -- ORDEN 70
        FORMAT(T.[FECHAINFO],   'yyyy/MM/dd')               AS [FECHAINFO]       -- ORDEN 71
    FROM [SILVER].[RR].[154_ENT_SWAPS] T
    WHERE T.[FECHAINFO] = @FECHA;
END;
GO
