# Correlazioni, metriche descrittive e grafici rigenerabili.
analisi_descrittiva <- function(dati, cartella_output) {
  dir.create(cartella_output, recursive = TRUE, showWarnings = FALSE)
  variabili <- c("BUFFA_HYPOXIA_SCORE", "RAGNUM_HYPOXIA_SCORE", "WINTER_HYPOXIA_SCORE")
  matrice <- cor(dati[, variabili], method = "pearson")
  write.csv(round(matrice, 3), file.path(cartella_output, "correlazioni_hypoxia.csv"))
  stopifnot(abs(matrice[1, 2] - 0.851) < 0.001,
            abs(matrice[1, 3] - 0.922) < 0.001,
            abs(matrice[2, 3] - 0.792) < 0.001)
  grafico <- ggplot2::ggplot(data.frame(eta = dati$AGE), ggplot2::aes(x = eta)) +
    ggplot2::geom_histogram(binwidth = 5, fill = "#28739a", color = "white") +
    ggplot2::labs(title = "Age at diagnosis", x = "Age (years)", y = "Patients") +
    ggplot2::theme_minimal(base_size = 12)
  ggplot2::ggsave(file.path(cartella_output, "age_distribution.png"), grafico,
                  width = 8, height = 5, dpi = 220)
  invisible(matrice)
}
