"""Independent Python verification of published Cox HRs (not the historical R source)."""
from pathlib import Path
import numpy as np
import pandas as pd
from statsmodels.duration.hazard_regression import PHReg
from statsmodels.duration.survfunc import SurvfuncRight, survdiff

ROOT = Path(__file__).resolve().parents[1]

def table(name):
    return pd.read_csv(ROOT / 'data/raw' / f'data_clinical_{name}.txt', sep='\t', comment='#')

p = table('patient').merge(table('sample')[['PATIENT_ID', 'TUMOR_TYPE']],
                           on='PATIENT_ID', validate='one_to_one').merge(table('supp_hypoxia'),
                           on='PATIENT_ID', how='left', validate='one_to_one')
p['event'] = pd.to_numeric(p['OS_STATUS'].str.extract(r'^(\d)')[0], errors='coerce')
p = p.loc[p.OS_MONTHS.gt(0) & p.event.notna()].dropna(subset=[
    'AGE', 'SEX', 'AJCC_PATHOLOGIC_TUMOR_STAGE', 'ICD_O_3_HISTOLOGY', 'TUMOR_TYPE',
    'BUFFA_HYPOXIA_SCORE', 'RAGNUM_HYPOXIA_SCORE', 'WINTER_HYPOXIA_SCORE']).copy()
assert len(p) == 485 and p.event.sum() == 177
p['stage'] = p.AJCC_PATHOLOGIC_TUMOR_STAGE.str.extract(r'^STAGE (IV|III|II|I)')[0]
p['histology'] = np.select([p.ICD_O_3_HISTOLOGY.eq('8140/3'),
                             p.ICD_O_3_HISTOLOGY.eq('8255/3')], ['NOS', 'Mixed'], default='Other')
x = pd.DataFrame({
    'Age (10 years)': p.AGE / 10,
    'Male': p.SEX.eq('Male').astype(int),
    'Stage II': p.stage.eq('II').astype(int),
    'Stage III': p.stage.eq('III').astype(int),
    'Stage IV': p.stage.eq('IV').astype(int),
    'Mixed histology': p.histology.eq('Mixed').astype(int),
    'Other histology': p.histology.eq('Other').astype(int),
    'Buffa (+10)': p.BUFFA_HYPOXIA_SCORE / 10,
}, index=p.index)
std = PHReg(p.OS_MONTHS, x, status=p.event, ties='efron').fit()
strat = PHReg(p.OS_MONTHS, x.iloc[:, [0, 5, 6, 7]], status=p.event,
              strata=p.SEX + '/' + p.stage, ties='efron').fit()
expected_std = np.array([1.236, 1.013, 1.931, 2.888, 3.821, .748, .477, 1.117])
expected_strat = np.array([1.241, .769, .473, 1.107])
assert np.allclose(np.exp(std.params), expected_std, atol=.0015), np.exp(std.params)
assert np.allclose(np.exp(strat.params), expected_strat, atol=.0015), np.exp(strat.params)
km = SurvfuncRight(p.OS_MONTHS, p.event)
km_survival = []
for t in (12, 36, 60):
    j = np.searchsorted(km.surv_times, t, side='right') - 1
    km_survival.append(km.surv_prob[j])
assert np.allclose(km_survival, [.875, .615, .392], atol=.001)
assert abs(km.quantile(.5) - 49.1) < .15
logrank_chi, logrank_p = survdiff(p.OS_MONTHS, p.event, p.stage)
assert logrank_p < .001
print('Independent KM and log-rank validation: OK')
print('KM survival:', np.round(km_survival, 6).tolist(), 'median', km.quantile(.5),
      'log-rank chi2', round(logrank_chi, 4))
print('Independent Cox HR validation: standard 8/8, stratified 4/4 matched')
for name, fit in [('Standard', std), ('Stratified', strat)]:
    print(name, 'HRs:', np.round(np.exp(fit.params), 4).tolist())
