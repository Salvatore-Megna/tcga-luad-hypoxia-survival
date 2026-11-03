# Specificazioni Cox del report; codice ricostruito, verificato numericamente in Python.
modelli_cox <- function(dati, cartella_output) {
  formula_standard <- survival::Surv(tempo_mesi, evento) ~ eta_10 + sesso + stadio + istologia + buffa_10
  formula_stratificata <- survival::Surv(tempo_mesi, evento) ~ eta_10 + istologia + buffa_10 +
    strata(sesso, stadio)
  standard <- survival::coxph(formula_standard, data = dati, ties = "efron", x = TRUE, model = TRUE)
  stratificato <- survival::coxph(formula_stratificata, data = dati, ties = "efron", x = TRUE, model = TRUE)
  tabella_cox <- function(modello) {
    conf <- stats::confint(modello)
    sm <- summary(modello)
    data.frame(term = names(stats::coef(modello)), HR = exp(stats::coef(modello)),
               CI_low = exp(conf[, 1]), CI_high = exp(conf[, 2]),
               p_value = sm$coefficients[, "Pr(>|z|)"], check.names = FALSE)
  }
  write.csv(tabella_cox(standard), file.path(cartella_output, "cox_standard.csv"), row.names = FALSE)
  write.csv(tabella_cox(stratificato), file.path(cartella_output, "cox_stratified.csv"), row.names = FALSE)
  list(standard = standard, stratificato = stratificato)
}
