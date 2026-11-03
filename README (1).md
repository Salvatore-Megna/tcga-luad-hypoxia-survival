# Data lineage

Three authentic patient-level files were downloaded from the cBioPortal DataHub's `luad_tcga_pan_can_atlas_2018` study and verified against SHA-256 hashes recorded for their Git LFS payloads. The exact identifiers are in `docs/PROVENANCE_AND_VALIDATION.md`.

- `data_clinical_patient.txt`: 566 patients, vital status, follow-up time, age, sex, stage and ICD-O-3 morphology.
- `data_clinical_sample.txt`: 566 patient-linked samples, tumor histology descriptions.
- `data_clinical_supp_hypoxia.txt`: 510 patients with Buffa, Ragnum and Winter expression signatures.

Files are used unchanged. The reconstructed analysis joins on `PATIENT_ID` and does not impute missing covariates. Check the study's data-use statement before any public redistribution. No artificially generated patient records are included.
