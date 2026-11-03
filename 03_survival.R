# Curve Kaplan-Meier e log-rank sul campione comune di 485 pazienti.
analisi_sopravvivenza <- function(dati, cartella_output) {
  risposta <- survival::Surv(dati$tempo_mesi, dati$evento)
  km <- survival::survfit(risposta ~ 1, data = dati, conf.type = "log")
  km_stadi <- survival::survfit(risposta ~ stadio, data = dati, conf.type = "log")
  logrank <- survival::survdiff(risposta ~ stadio, data = dati)
  p_logrank <- stats::pchisq(logrank$chisq, df = length(logrank$n) - 1L, lower.tail = FALSE)
  intervalli <- summary(km, times = c(12, 36, 60), extend = TRUE)
  tabella_km <- data.frame(month = intervalli$time, survival = intervalli$surv,
                           lower_95 = intervalli$lower, upper_95 = intervalli$upper,
                           n_risk = intervalli$n.risk)
  write.csv(tabella_km, file.path(cartella_output, "km_overall.csv"), row.names = FALSE)
  write.csv(data.frame(chi_square = logrank$chisq, p_value = p_logrank),
            file.path(cartella_output, "logrank_stage.csv"), row.names = FALSE)
  stopifnot(p_logrank < 0.001)
  stopifnot(all(abs(tabella_km$survival - c(.875, .615, .392)) < .002))

  s <- summary(km)
  tabella_curve <- data.frame(month = s$time, survival = s$surv,
                              lower = s$lower, upper = s$upper)
  grafico <- ggplot2::ggplot(tabella_curve, ggplot2::aes(x = month, y = survival)) +
    ggplot2::geom_step(linewidth = .85, color = "#286e95") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = lower, ymax = upper),
                         fill = "#286e95", alpha = .12) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(title = "Overall survival", x = "Months from diagnosis", y = "Survival probability") +
    ggplot2::theme_minimal(base_size = 12)
  ggplot2::ggsave(file.path(cartella_output, "km_overall.png"), grafico,
                  width = 8, height = 5.5, dpi = 220)

  ss <- summary(km_stadi)
  dati_curve <- data.frame(month = ss$time, survival = ss$surv,
                            stage = sub("stadio=", "", as.character(ss$strata)))
  grafico_stadi <- ggplot2::ggplot(dati_curve,
                      ggplot2::aes(x = month, y = survival, color = stage)) +
    ggplot2::geom_step(linewidth = .8) +
    ggplot2::scale_color_brewer(palette = "Dark2") +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(title = "Survival by pathological stage", x = "Months", y = "Survival", color = "Stage") +
    ggplot2::theme_minimal(base_size = 12)
  ggplot2::ggsave(file.path(cartella_output, "km_by_stage.png"), grafico_stadi,
                  width = 8, height = 5.5, dpi = 220)
  list(km = km, km_stadi = km_stadi, logrank_p = p_logrank, tabella_km = tabella_km)
}
