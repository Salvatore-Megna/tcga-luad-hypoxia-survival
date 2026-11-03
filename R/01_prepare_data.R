# Ricostruzione verificabile da tabelle cBioPortal, NON codice originale del 2026.
# Eseguire dalla radice del repository tramite scripts/run_all.R.

leggi_tabella_cbioportal <- function(percorso) {
  if (!file.exists(percorso)) stop("File assente: ", percorso)
  read.delim(percorso, sep = "\t", header = TRUE, comment.char = "#",
             quote = "", check.names = FALSE, stringsAsFactors = FALSE,
             na.strings = c("", "NA", "[Not Available]"))
}

prepara_dati <- function(cartella_dati = "data/raw") {
  pazienti <- leggi_tabella_cbioportal(file.path(cartella_dati, "data_clinical_patient.txt"))
  campioni <- leggi_tabella_cbioportal(file.path(cartella_dati, "data_clinical_sample.txt"))
  ipossia <- leggi_tabella_cbioportal(file.path(cartella_dati, "data_clinical_supp_hypoxia.txt"))

  for (tabella in list(pazienti, campioni, ipossia)) {
    if (!"PATIENT_ID" %in% names(tabella)) stop("PATIENT_ID non presente")
    if (anyNA(tabella$PATIENT_ID) || anyDuplicated(tabella$PATIENT_ID)) {
      stop("Identificativo paziente mancante o duplicato")
    }
  }

  # I dati dei campioni forniscono descrizioni istologiche, ma la codifica
  # del report dipende dal codice ICD-O-3 presente nella tabella pazienti.
  dati <- merge(pazienti, campioni[c("PATIENT_ID", "TUMOR_TYPE")],
                by = "PATIENT_ID", all.x = TRUE, sort = FALSE)
  dati <- merge(dati, ipossia, by = "PATIENT_ID", all.x = TRUE, sort = FALSE)
  stopifnot(nrow(pazienti) == 566L, nrow(dati) == nrow(pazienti))

  dati$tempo_mesi <- suppressWarnings(as.numeric(dati$OS_MONTHS))
  dati$evento <- ifelse(dati$OS_STATUS == "1:DECEASED", 1L,
                       ifelse(dati$OS_STATUS == "0:LIVING", 0L, NA_integer_))
  con_outcome <- dati[!is.na(dati$tempo_mesi) & !is.na(dati$evento), ]
  con_tempo_positivo <- con_outcome[con_outcome$tempo_mesi > 0, ]

  variabili_necessarie <- c("AGE", "SEX", "AJCC_PATHOLOGIC_TUMOR_STAGE",
                            "ICD_O_3_HISTOLOGY", "TUMOR_TYPE",
                            "BUFFA_HYPOXIA_SCORE", "RAGNUM_HYPOXIA_SCORE",
                            "WINTER_HYPOXIA_SCORE")
  if (!all(variabili_necessarie %in% names(dati))) stop("Colonne indispensabili mancanti")
  completi <- stats::complete.cases(con_tempo_positivo[, variabili_necessarie])
  dati_cox <- con_tempo_positivo[completi, , drop = FALSE]

  # STAGE IA / IB -> I, IIA / IIB -> II, IIIA / IIIB -> III; IV resta IV.
  stadi <- sub("^STAGE (IV|III|II|I).*$", "\\1", dati_cox$AJCC_PATHOLOGIC_TUMOR_STAGE)
  if (!all(stadi %in% c("I", "II", "III", "IV"))) stop("Stadi non riconosciuti")
  dati_cox$stadio <- factor(stadi, levels = c("I", "II", "III", "IV"))
  dati_cox$sesso <- factor(dati_cox$SEX, levels = c("Female", "Male"))
  if (anyNA(dati_cox$sesso)) stop("Livelli del sesso non riconosciuti")

  # CRUCIALE: i modelli del report sono riprodotti con 8140/3 -> NOS,
  # 8255/3 -> Mixed, e tutti gli altri codici -> Other. Una classificazione
  # basata sul testo TUMOR_TYPE produce hazard ratio differenti.
  dati_cox$istologia <- factor(ifelse(dati_cox$ICD_O_3_HISTOLOGY == "8140/3", "NOS",
                               ifelse(dati_cox$ICD_O_3_HISTOLOGY == "8255/3", "Mixed", "Other")),
                                levels = c("NOS", "Mixed", "Other"))
  dati_cox$eta_10 <- as.numeric(dati_cox$AGE) / 10
  dati_cox$buffa_10 <- as.numeric(dati_cox$BUFFA_HYPOXIA_SCORE) / 10

  flusso <- data.frame(
    fase = c("Original patient records", "Complete survival outcome",
             "Positive observed survival time", "Complete-case analysis"),
    pazienti = c(nrow(dati), nrow(con_outcome), nrow(con_tempo_positivo), nrow(dati_cox))
  )
  stopifnot(identical(as.integer(flusso$pazienti), c(566L, 505L, 501L, 485L)))
  stopifnot(sum(dati_cox$evento) == 177L, sum(dati_cox$evento == 0) == 308L)
  stopifnot(!anyDuplicated(dati_cox$PATIENT_ID), !anyNA(dati_cox$istologia))
  list(dati = dati_cox, flusso = flusso, dati_sopravvivenza = con_tempo_positivo)
}
