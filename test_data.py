"""Cross-language integrity and cohort regression tests (Python stdlib only)."""
from pathlib import Path
import csv
import hashlib
import math
import unittest

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    'patient': ('data_clinical_patient.txt', '2c347251474ec48a365e9b9dcd3b86a7106a6bbf69469ec4b740ba4d92695df7', 158342),
    'sample': ('data_clinical_sample.txt', 'b443896a6aed8256f3aa1b5e2f41e700392c76461be10936d2c344988bc5d84e', 111469),
    'hypoxia': ('data_clinical_supp_hypoxia.txt', '4b7e1716cbb51a5af9d8f47855114c5866c16556d3bfb5ad5973adee22c118e5', 11846),
}


def load_rows(filename):
    with (ROOT / 'data/raw' / filename).open(encoding='utf-8', newline='') as handle:
        return list(csv.DictReader((line for line in handle if not line.startswith('#')), delimiter='\t'))


def complete(value):
    return value not in ('', 'NA', '[Not Available]', None)


class SourceVerification(unittest.TestCase):
    def test_exact_hashes_and_sizes(self):
        for filename, sha, size in FILES.values():
            with self.subTest(filename=filename):
                path = ROOT / 'data/raw' / filename
                payload = path.read_bytes()
                self.assertEqual(len(payload), size)
                self.assertEqual(hashlib.sha256(payload).hexdigest(), sha)
                self.assertFalse(payload.startswith(b'version https://git-lfs'))

    def test_cohort_flow_and_patient_matching(self):
        patients = load_rows(FILES['patient'][0])
        samples = load_rows(FILES['sample'][0])
        hypoxia = load_rows(FILES['hypoxia'][0])
        self.assertEqual((len(patients), len(samples), len(hypoxia)), (566, 566, 510))
        self.assertEqual(len({p['PATIENT_ID'] for p in patients}), 566)
        self.assertEqual(len({p['PATIENT_ID'] for p in samples}), 566)
        self.assertEqual(len({p['PATIENT_ID'] for p in hypoxia}), 510)
        sample_by_id = {x['PATIENT_ID']: x for x in samples}
        hypoxia_by_id = {x['PATIENT_ID']: x for x in hypoxia}
        with_survival, with_positive = [], []
        for p in patients:
            if complete(p['OS_MONTHS']) and complete(p['OS_STATUS']):
                with_survival.append(p)
                if float(p['OS_MONTHS']) > 0:
                    with_positive.append(p)
        self.assertEqual(len(with_survival), 505)
        self.assertEqual(len(with_positive), 501)
        required = ('AGE', 'SEX', 'AJCC_PATHOLOGIC_TUMOR_STAGE', 'ICD_O_3_HISTOLOGY')
        co = []
        for p in with_positive:
            s = sample_by_id.get(p['PATIENT_ID'], {})
            h = hypoxia_by_id.get(p['PATIENT_ID'], {})
            if (all(complete(p.get(k)) for k in required)
                    and complete(s.get('TUMOR_TYPE'))
                    and all(complete(h.get(k)) for k in ('BUFFA_HYPOXIA_SCORE', 'RAGNUM_HYPOXIA_SCORE', 'WINTER_HYPOXIA_SCORE'))):
                co.append((p, h))
        self.assertEqual(len(co), 485)
        self.assertEqual(sum(p['OS_STATUS'] == '1:DECEASED' for p, _ in co), 177)
        codes = [p['ICD_O_3_HISTOLOGY'] for p, _ in co]
        self.assertEqual((codes.count('8140/3'), codes.count('8255/3')),
                         (289, 104))
        def pearson(a, b):
            ma, mb = sum(a)/len(a), sum(b)/len(b)
            xa = [x-ma for x in a]
            xb = [x-mb for x in b]
            return sum(x*y for x,y in zip(xa, xb)) / math.sqrt(sum(x*x for x in xa) * sum(y*y for y in xb))
        buffa = [float(h['BUFFA_HYPOXIA_SCORE']) for _,h in co]
        ragnum = [float(h['RAGNUM_HYPOXIA_SCORE']) for _,h in co]
        winter = [float(h['WINTER_HYPOXIA_SCORE']) for _,h in co]
        self.assertAlmostEqual(pearson(buffa, ragnum), .851, delta=.001)
        self.assertAlmostEqual(pearson(buffa, winter), .922, delta=.001)
        self.assertAlmostEqual(pearson(ragnum, winter), .792, delta=.001)


if __name__ == '__main__':
    unittest.main()
