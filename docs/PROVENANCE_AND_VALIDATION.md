# Provenance and independent validation log

**Recorded:** 2026-11-03. **State:** private review candidate; no R execution in preparation environment.

## Authenticated source files

Source: `cBioPortal/datahub`, `public/luad_tcga_pan_can_atlas_2018/`.

| Source file | Size (bytes) | SHA-256 (Git LFS payload, verified locally) |
|---|---:|---|
| `data_clinical_patient.txt` | 158342 | `2c347251474ec48a365e9b9dcd3b86a7106a6bbf69469ec4b740ba4d92695df7` |
| `data_clinical_sample.txt` | 111469 | `b443896a6aed8256f3aa1b5e2f41e700392c76461be10936d2c344988bc5d84e` |
| `data_clinical_supp_hypoxia.txt` | 11846 | `4b7e1716cbb51a5af9d8f47855114c5866c16556d3bfb5ad5973adee22c118e5` |

Downloaded GitHub LFS pointer files (c. 130 bytes) **are not** the authentic raw datasets. The inputs here are the actual payloads.

## Distinction between historical and reconstructed sources

- **Original, recovered:** three data files; 17-page report and all LaTeX-referenced figures; intact Overleaf source `Report_Biostatistica_ultima_versione.tex` (see `original_overleaf_source.tex`). Original Overleaf project was `6a4e338f5dd6b7237f034398`.
- **Historical source available only in fragments:** the correlation matrix and CSV-writing R calls, as identified in the earlier forensic recovery; some older screenshots. The historical script files for Kaplan–Meier, Cox and residual diagnostics are not recovered.
- **New reconstruction:** all R programs and tests in this repository, derived from the original report and authentic data.
- **Report build:** `report/main.tex` has a single folder-path adjustment for portability; recompiled `report/report.pdf` has 17 pages and normalized word-for-word text matching the recovered PDF. An alternative historical version remains preserved in the earlier recovery ZIP, not mixed into this public-facing tree.

## Reconstructed cohort and independent models

Verified through both raw file parsing and the independent Python script:

| Stage | Patients |
|---|---:|
| Original records | 566 |
| Complete overall-survival outcome | 505 |
| Positive observed overall-survival time | 501 |
| Complete cases for analysis | **485** |
| Deaths | 177 |
| Censored | 308 |

Scores: Pearson Buffa/Ragnum = **0.851**, Buffa/Winter = **0.922**, Ragnum/Winter = **0.792** (rounded). Kaplan–Meier S(12)=**0.874645**, S(36)=**0.615143**, S(60)=**0.392114**; median = **49.051517 months**. Stage log-rank chi-square **49.1176**, p approximately **1.23e-10**, independently computed in Python. The original report uses rounded results.

**Histology: critical recovery detail.** Reimplementing histology by the `TUMOR_TYPE` string yields different HRs. The exact report HRs are recovered with `ICD_O_3_HISTOLOGY` codes: 8140/3 → NOS (n=289), 8255/3 → Mixed (n=104), every remaining code → Other (n=92). This is inferred from the report's category definition and validated by both fitted models. It is not asserted to be verbatim source code.

| Variable | Historical HR, standard | Recomputed HR, standard (Python) |
|---|---:|---:|
| Age (+10 years) | 1.236 | 1.2359 |
| Male vs Female | 1.013 | 1.0130 |
| Stage II vs I | 1.931 | 1.9309 |
| Stage III vs I | 2.888 | 2.8878 |
| Stage IV vs I | 3.821 | 3.8211 |
| Mixed vs NOS | 0.748 | 0.7481 |
| Other vs NOS | 0.477 | 0.4772 |
| Buffa (+10) | 1.117 | 1.1173 |

| Variable | Historical HR, stratified | Recomputed HR, stratified (Python) |
|---|---:|---:|
| Age (+10 years) | 1.241 | 1.2414 |
| Mixed vs NOS | 0.769 | 0.7686 |
| Other vs NOS | 0.473 | 0.4730 |
| Buffa (+10) | 1.107 | 1.1070 |

The independent implementation is `statsmodels.duration.hazard_regression.PHReg` with **Efron** ties and sex × stage-stratified baseline hazard as appropriate. `tests/independent_cox_check.py` reproduces all 12 ratios within the tolerance for three-decimal rounding.

## Current test status (not overstated)

- **Passed locally:** three SHA-256 hashes and sizes; source schema; unique patient IDs; 566→505→501→485 filters; 177/308 outcome counts; three correlations; independent Cox estimates (8 standard + 4 stratified); LaTeX compilation, 17 pages, normalized report text identical to recovered historical PDF.
- **Reconstructed but NOT R-executed in the current environment:** full R code (`survival`, `ggplot2`) for KM, log-rank, both Cox fits, Schoenfeld, martingale diagnostics and prognostic curves.
- **Remaining numerical comparisons:** full Schoenfeld tables (historical global p = 0.016 standard and p = 0.461 stratified), confidence intervals for the KM median, predicted 60-month survival for three profiles (0.546, 0.398, 0.246), and regenerated plots. A different estimate should be explained, not overwritten in the report.
- **CI:** `.github/workflows/checks.yml` is configured for both languages; **no workflow result exists for this new repository yet**. On creation, inspect the run results and fix any discrepancies before requesting public release.

## Publication gate

Do not publish this as a fully reproducible study until (1) R CI succeeds, (2) the remaining diagnostics and curves are reviewed, (3) licensing and rights of dataset/report are reviewed, (4) README is updated to true CI status. Do not commit to a different project to run unrelated checks, and do not claim the historical R code was recovered.
