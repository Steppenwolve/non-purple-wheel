# Hallazgos — 122_ENT_REPORTOS_CANASTA (Layout_REPORTOS_MN_ME_V7.1_2024_CANASTA_REPORTOS)

| # | Hallazgo | Corrección aplicada |
|---|----------|---------------------|
| 1 | SP SILVER filtra el DELETE por `FECHACONCERTACION = @FechaSistema` en lugar de `FECHA_INFO = @FechaDia` | Filtro cambiado a `FECHA_INFO = @FechaDia` (columna de control LMDA) |
| 2 | SP SILVER calcula ventana mensual (`@FechaIni`/`@FechaFin`) no utilizada; el INSERT filtra por `FECHACONCERTACION = @FechaSistema` en lugar de `FECHA_INFO = @FechaDia` | Variables mensuales eliminadas; filtro INSERT corregido a `FECHA_INFO = @FechaDia` (patrón DIARIO) |
| 3 | SP ION filtra por `FECHACONCERTACION = @FECHA` en lugar de `FECHA_INFO = @FECHA` | Filtro corregido a `WHERE [FECHA_INFO] = @FECHA` |
