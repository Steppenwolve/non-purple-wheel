# Mapeo de campos — Salida SP ION `016_ENT_ANEXO19`

**Contexto:** REPORTES ORIGEN SAF · Periodicidad **Mensual** · `FECHA_INFO = EOMONTH(@FechaSistema)` (calculada).
> Ojo con el nombre: el objeto es **`016_ENT_ANEXO19`** (sin guion antes del 19).

**Tablas de origen** (JOIN en el SP SILVER):
- **A** = `BRONZE.SAF.PR_CREDITOS` — tabla base (créditos)
- **B** = `BRONZE.INF.CREDITO_EMPRESARIAL` — `INNER JOIN` por `A.ID_EXTERNO = B.IDCREDITO`, **deduplicada** con `ROW_NUMBER() OVER(PARTITION BY IDCREDITO ORDER BY IDCREDITO DESC) = 1`. Aporta fechas y **todos los atributos de riesgo**
- **C** = `BRONZE.PO.SAF_CIERRE_CMR_REP` — `LEFT JOIN` filtrado por `FECHA_SISTEMA = EOMONTH(@FechaSistema)`. ⚠️ **No aporta ninguna columna** a la salida (join muerto)
- **F** = `BRONZE.LMDA.FLUJOS` — `LEFT JOIN` por `ID_EXTERNO`, filtrada por `FECHA_VPN` en **ventana trimestral**
- **E** = `BRONZE.RR.FLUJO_ETAPAS` — `LEFT JOIN` por `E.DESCRIPCION = F.ETAPA_PROYECTO`
- **Catálogos homologados** en `BRONZE.RR` (16), todos `LEFT JOIN` por `VALOR_PANTALLA_COMERCIAL` contra un atributo de **B**, devolviendo `CODIGO`:
  `G` Riesgo_Politico_Entorno_Regulatorio_BW · `H` Eventos_Fuerza_Mayor_BW · `I` Adquisicion_Apoyos_BW · `J` Cumplimiento_Contratos_BW · `K` Riesgo_Construccion_BW · `L` Tipo_Contrato_Construccion_BW · `M` Riesgo_Operativo_BW · `N` Prenda_Activo_BW · `O` Control_Flujo_Efectivo_BW · `P` Fondos_Reserva_BW · `Q` Historial_Patrocinador_BW · `R` Cobertura_Seguros_BW · `S` Caracteristicas_Activo_BRGR · `T` Analisis_estres_BW · `U` Estructura_Financiera_BW · `V` Tipo_de_Credito_BW *(sufijo `_homologado`)*

## Filtro (`WHERE`) — un solo crédito por cliente
```sql
WHERE A.NUM_CREDITO IN (
    SELECT MAX(NUM_CREDITO) FROM BRONZE.SAF.PR_CREDITOS   -- "para evitar duplicidad"
    WHERE ( IND_ESTADO = 'D'                                    -- dispuesto/vigente
            OR (IND_ESTADO = 'C'                                -- o cancelado DENTRO del mes
                AND FEC_CANCELACION >= @FechaIni
                AND FEC_CANCELACION <  @FechaFin) )
      AND TIP_CREDITO = 16
      AND A.NUM_DESC_TIPO_CREDITO IN (12,13,14,15,28,2,5,18,27) -- comercial
      AND IND_LINEA = 'N'                                       -- no es línea
    GROUP BY COD_CLIENTE)
```
Se queda **un crédito por cliente** (el de mayor `NUM_CREDITO`), de tipo **comercial**, **no línea**, y **vigente o cancelado en el mes**.

> Todas las 40 columnas del reporte están documentadas (una línea por campo), incluidas las que salen en blanco/cero/NULL.

| # | CAMPO ION | VIENE DE | CÁLCULO | TIPO DE ORIGEN |
|---|-----------|----------|---------|----------------|
| 1 | `ID_PERSONA` | `A.COD_CLIENTE` | — | Directo |
| 2 | `TIPO_PROYECTO` | `RR.Tipo_de_Credito_BW` (V) vía `B.TipoProyecto` | `ISNULL(V.CODIGO, 0)` | Catálogo homologado |
| 3 | `FECHA_INICIO_OPERACION` | `B.FechaFirma` | `ISNULL(...,0)` + `FORMAT('yyyy-MM-dd')` | Directo (fecha) |
| 4 | `POR_EXPOS_29_INST_BAN` | — | `CAST(NULL AS NUMERIC(10,6))` | NULL fijo |
| 5 | `VP_FEGP` | `F.VP_FEGP` (LMDA.FLUJOS) | `ISNULL(CAST(... AS NUMERIC(21,2)),0)` | Directo |
| 6 | `ETAPA_PROYECTO` | `RR.FLUJO_ETAPAS` (E) vía `F.ETAPA_PROYECTO` | `ISNULL(E.CLAVE, 0)` | Catálogo |
| 7 | `ANALISIS_ESTRES` | `RR.Analisis_estres_BW` (T) vía `B.AnalisisEstres` | `ISNULL(T.CODIGO, 0)` | Catálogo homologado |
| 8 | `ESTRUCTURA_FINANCIERA` | `RR.Estructura_Financiera_BW` (U) vía `B.EstructuraFinanciera` | `ISNULL(U.CODIGO, 0)` | Catálogo homologado |
| 9 | `RIES_POL_ENT_REG` | `RR.Riesgo_Politico_Entorno_Regulatorio_BW` (G) vía `B.RiesgoPolitico` | `ISNULL(G.CODIGO, '')` | Catálogo homologado |
| 10 | `TASA_DE_DESCUENTO_VP` | `F.TASA_DE_DESCUENTO_VP` | `ISNULL(...,0)` | Directo |
| 11 | `RIESGO_EVENTOS_FUERZA_MAY` | `RR.Eventos_Fuerza_Mayor_BW` (H) vía `B.RiesgoEventosFuerzaMayor` | `ISNULL(H.CODIGO, 0)` | Catálogo homologado |
| 12 | `ADQ_APOYOS_APROBAC` | `RR.Adquisicion_Apoyos_BW` (I) vía **`B.ImpactoAmbiental`** | `ISNULL(I.CODIGO, 0)` | Catálogo homologado |
| 13 | `CUMPLIMIENTO_CONTRATOS` | `RR.Cumplimiento_Contratos_BW` (J) vía `B.CumplimientoContratos` | `ISNULL(J.CODIGO, 0)` | Catálogo homologado |
| 14 | `RIESGO_CONSTRUCCION` | `RR.Riesgo_Construccion_BW` (K) vía `B.RiesgoConstruccion` | `ISNULL(K.CODIGO, 0)` | Catálogo homologado |
| 15 | `TIPO_CONTRATO_CONSTRUCCION` | `RR.Tipo_Contrato_Construccion_BW` (L) vía `B.ContratoConstruccion` | `ISNULL(L.CODIGO, 0)` | Catálogo homologado |
| 16 | `RIESGO_OPERATIVO` | `RR.Riesgo_Operativo_BW` (M) vía **`B.ContratoOperacion`** | `ISNULL(M.CODIGO, 0)` | Catálogo homologado |
| 17 | `RIESGO_SUMINISTRO` | — (constante en SP ION) | `'9'` | Constante |
| 18 | `PRENDA_ACTIVOS` | `RR.Prenda_Activo_BW` (N) vía `B.PrendaActivos` | `ISNULL(N.CODIGO, 0)` | Catálogo homologado |
| 19 | `CONTROL_INST_FLUJO_EFECTIVO` | `RR.Control_Flujo_Efectivo_BW` (O) vía `B.ControlFlujoEfectivo` | `ISNULL(O.CODIGO, 0)` | Catálogo homologado |
| 20 | `FONDOS_RESERVA` | `RR.Fondos_Reserva_BW` (P) vía `B.FondoReserva` | `ISNULL(P.CODIGO, 0)` | Catálogo homologado |
| 21 | `HISTORIAL_PATROCINADOR` | `RR.Historial_Patrocinador_BW` (Q) vía `B.HistorialPatrocinador` | `ISNULL(Q.CODIGO, 0)` | Catálogo homologado |
| 22 | `COBERTURA_SEGUROS` | `RR.Cobertura_Seguros_BW` (R) vía `B.CoberturaSeguros` | `ISNULL(R.CODIGO, 0)` | Catálogo homologado |
| 23 | `ACTIVO_BRGR` | `RR.Caracteristicas_Activo_BRGR` (S) vía `B.BRGR` | `ISNULL(S.CODIGO, 0)` | Catálogo homologado |
| 24 | `ACTIVO_FA` | — (constante en SP ION) | `''` | Constante vacía |
| 25 | `ACTIVO_FC` | — (constante en SP ION) | `''` | Constante vacía |
| 26 | `ACTIVO_FP_FP1` | — (constante en SP ION) | `''` | Constante vacía |
| 27 | `SOBRECOSTO` | `F.SOBRECOSTO` | `ISNULL(...,0)` | Directo |
| 28 | `INGRESOS_PROPIOS_PROY` | — (constante en SP SILVER) | `0.0` | Constante |
| 29 | `GASTOS_TOTALES_PROY` | — (constante en SP SILVER) | `0.0` | Constante |
| 30 | `IMPACTO_FISCAL_PROY` | — (constante en SP SILVER) | `0.0` | Constante |
| 31 | `PAGO_DEDUDA_12MESES` | `F.PAGO_DEDUDA_12MESES` | — (sin `ISNULL`) | Directo |
| 32 | `FLUJO_EFECTIVO_ADICIONAL` | `F.FLUJO_EFECTIVO_ADICIONAL` | — (sin `ISNULL`) | Directo |
| 33 | `FECHA_INFO` | `@FechaSistema` (parámetro) | `EOMONTH(@FechaSistema)` + `FORMAT('yyyy-MM-dd')` | Cálculo (fin de mes) |
| 34 | `ID_PROYECTO` | `A.ID_EXTERNO` | `ISNULL(...,'')` | Directo |
| 35 | `VENTAS_NETAS_INGRESOS` | — (constante en SP SILVER) | `0.0` | Constante |
| 36 | `RESERVA_PROYECTO` | — (constante en SP SILVER) | `0.0` | Constante |
| 37 | `VP_FEGP_12MESES` | `F.VP_FEGP_12MESES` | `ISNULL(...,0)` | Directo |
| 38 | `VALOR_ACTIVO_SUBY` | — (constante en SP SILVER) | `0` | Constante |
| 39 | `FECHA_INFO_FIN` | — | `CAST(NULL AS DATE)` + `FORMAT` | NULL fijo |
| 40 | `FECHA_INFO_BURO` | `B.FechaConsultaBuro` | `ISNULL(...,0)` + `FORMAT('yyyy-MM-dd')` | Directo (fecha) |

## Resumen
- **Directos (dato real):** 1, 3, 5, 10, 27, 31, 32, 34, 37, 40 → de `A` (2), `B` (2) y `F` (6).
- **Catálogo:** 2, 6, 7, 8, 9, 11–16, 18–23 → **17 campos** (16 homologados de `RR` + `FLUJO_ETAPAS`).
- **Cálculo:** 33 (`EOMONTH`).
- **Constantes / NULL fijo:** 4, 17, 24, 25, 26, 28, 29, 30, 35, 36, 38, 39 → **12 campos**.
- **`C` (`PO.SAF_CIERRE_CMR_REP`) no aporta ninguna columna** (join muerto).

## 🚩 Hallazgos
1. **Join muerto:** `C = BRONZE.PO.SAF_CIERRE_CMR_REP` se une (filtrado por `FECHA_SISTEMA`) pero **ninguna columna suya se usa**, y al ser `LEFT JOIN` tampoco filtra. Solo agrega costo.
2. **Posible bug en el subquery del `WHERE`:** usa **`A.NUM_DESC_TIPO_CREDITO`**, que referencia la tabla **externa** `A` (la del subquery no tiene alias) → correlación probablemente no intencional.
3. **Posible bug de ventana:** `@FechaFin2 = DATEADD(month, 3, @FechaIni)` usa `@FechaIni` (mensual) en lugar de `@FechaIni2` (trimestral) → la ventana de `LMDA.FLUJOS` puede quedar corrida.
4. **`ISNULL(fecha, 0)`** en campos 3 y 40: mezcla fecha con `0` → si viene NULL queda **1900-01-01** (mismo anti-patrón visto en el 008).
5. **Nombres cruzados a revisar:** `ADQ_APOYOS_APROBAC` se alimenta de `B.ImpactoAmbiental` y `RIESGO_OPERATIVO` de `B.ContratoOperacion` — conviene confirmar con negocio que el mapeo es correcto.
6. **Dedup bien resuelto** (a diferencia del 008): `ROW_NUMBER` en B + `MAX(NUM_CREDITO) GROUP BY COD_CLIENTE` + **UNIQUE constraint** `UK_Anexo19_Persona_Fecha` en la tabla SILVER.
