# Eseguire dalla root: Rscript scripts/run_all.R
if (!file.exists("R/01_prepare_data.R")) {
  stop("Eseguire dalla radice del repository, non dalla cartella scripts/.")
}
for (pacchetto in c("survival", "ggplot2")) {
  if (!requireNamespace(pacchetto, quietly = TRUE)) {
    stop("Installare il pacchetto R: ", pacchetto)
  }
}
for (file in c("01_prepare_data.R", "02_descriptive.R", "03_survival.R",
               "04_cox_models.R", "05_diagnostics.R")) source(file.path("R", file), encoding = "UTF-8")

cartella_output <- "outputs"
dir.create(cartella_output, recursive = TRUE, showWarnings = FALSE)
preparazione <- prepara_dati()
dati_cox <- preparazione$dati
write.csv(preparazione$flusso, file.path(cartella_output, "cohort_flow.csv"), row.names = FALSE)
correlazioni <- analisi_descrittiva(dati_cox, cartella_output)
sopravvivenza <- analisi_sopravvivenza(dati_cox, cartella_output)
modelli <- modelli_cox(dati_cox, cartella_output)
diagnostica <- analisi_diagnostica(dati_cox, modelli, cartella_output)

# I controlli numerici sono indipendenti dai grafici e interrompono la pipeline in caso di errore.
source("tests/validate_R_results.R", encoding = "UTF-8")
validate_results(preparazione, correlazioni, sopravvivenza, modelli, diagnostica)
message("Analisi TCGA-LUAD completata e controlli R superati.")
