# Diagnostica dei residui e predizioni illustrate nel report storico.
analisi_diagnostica <- function(dati, modelli, cartella_output) {
  ph_standard <- survival::cox.zph(modelli$standard, terms = TRUE, transform = "km")
  ph_stratificato <- survival::cox.zph(modelli$stratificato, terms = TRUE, transform = "km")
  write.csv(as.data.frame(ph_standard$table), file.path(cartella_output, "schoenfeld_standard.csv"))
  write.csv(as.data.frame(ph_stratificato$table), file.path(cartella_output, "schoenfeld_stratified.csv"))

  # Si conservano anche grafici standard di diagnostica, esplicitamente rigenerati.
  grDevices::pdf(file.path(cartella_output, "schoenfeld_standard.pdf"), width = 8, height = 5)
  plot(ph_standard)
  grDevices::dev.off()
  grDevices::pdf(file.path(cartella_output, "schoenfeld_stratified.pdf"), width = 8, height = 5)
  plot(ph_stratificato)
  grDevices::dev.off()

  martingala <- as.numeric(stats::residuals(modelli$stratificato, type = "martingale"))
  for (colonna in c("eta_10", "buffa_10")) {
    grafico <- ggplot2::ggplot(data.frame(x = dati[[colonna]], residuo = martingala),
                               ggplot2::aes(x = x, y = residuo)) +
      ggplot2::geom_point(alpha = .3, size = 1.1, color = "#286e95") +
      ggplot2::geom_smooth(method = "loess", se = FALSE, color = "#b3593a") +
      ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
      ggplot2::labs(x = colonna, y = "Martingale residuals",
                     title = paste("Model diagnostics:", colonna)) +
      ggplot2::theme_minimal(base_size = 12)
    ggplot2::ggsave(file.path(cartella_output, paste0("martingale_", colonna, ".png")),
                    grafico, width = 7.5, height = 4.5, dpi = 220)
  }
  profili <- data.frame(
    profilo = c("Favorable", "Intermediate", "Unfavorable"),
    eta_10 = c(5.5, 6.5, 7.5), buffa_10 = c(-2, 0, 2),
    sesso = factor(rep("Female", 3), levels = levels(dati$sesso)),
    stadio = factor(rep("I", 3), levels = levels(dati$stadio)),
    istologia = factor(rep("NOS", 3), levels = levels(dati$istologia))
  )
  curve <- list()
  tabella_profili <- data.frame(profilo = profili$profilo,
                                survival_60 = NA_real_)
  for (i in seq_len(nrow(profili))) {
    predizione <- survival::survfit(modelli$stratificato,
                                    newdata = profili[i, , drop = FALSE])
    ss <- summary(predizione)
    curve[[i]] <- data.frame(month = ss$time, survival = ss$surv,
                             profile = profili$profilo[i])
    tabella_profili$survival_60[i] <- summary(predizione, times = 60, extend = TRUE)$surv[1]
  }
  write.csv(tabella_profili, file.path(cartella_output, "prognostic_profiles.csv"), row.names = FALSE)
  grafico <- ggplot2::ggplot(do.call(rbind, curve),
                             ggplot2::aes(x = month, y = survival, color = profile)) +
    ggplot2::geom_step(linewidth = .85) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(title = "Illustrative prognostic profiles", x = "Months",
                   y = "Survival probability", color = "Profile") +
    ggplot2::theme_minimal(base_size = 12)
  ggplot2::ggsave(file.path(cartella_output, "prognostic_profiles.png"), grafico,
                  width = 8, height = 5.5, dpi = 220)
  list(ph_standard = ph_standard, ph_stratificato = ph_stratificato,
       profili = tabella_profili)
}
