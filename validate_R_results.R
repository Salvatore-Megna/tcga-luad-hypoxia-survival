# Tolleranze esplicite rispetto ai valori arrotondati nel report (3 decimali).
validate_results <- function(preparazione, correlazioni, sopravvivenza, modelli, diagnostica) {
  stopifnot(identical(as.integer(preparazione$flusso$pazienti), c(566L, 505L, 501L, 485L)))
  stopifnot(sum(preparazione$dati$evento) == 177)
  stopifnot(abs(correlazioni[1, 2] - .851) < .001,
            abs(correlazioni[1, 3] - .922) < .001,
            abs(correlazioni[2, 3] - .792) < .001)

  # Controllo del risultato storico significativo: l'istologia proviene da ICD-O-3.
  cifre_standard <- c(1.236, 1.013, 1.931, 2.888, 3.821, .748, .477, 1.117)
  cifre_stratificate <- c(1.241, .769, .473, 1.107)
  hr_standard <- unname(exp(stats::coef(modelli$standard)))
  hr_stratificati <- unname(exp(stats::coef(modelli$stratificato)))
  stopifnot(length(hr_standard) == 8L, length(hr_stratificati) == 4L)
  stopifnot(all(abs(hr_standard - cifre_standard) < .0015),
            all(abs(hr_stratificati - cifre_stratificate) < .0015))
  stopifnot(sopravvivenza$logrank_p < .001)
  stopifnot(all(abs(sopravvivenza$tabella_km$survival - c(.875, .615, .392)) < .002))
  mediana <- as.numeric(summary(sopravvivenza$km)$table["median"])
  stopifnot(abs(mediana - 49.1) < .2)
  stopifnot(all(abs(diagnostica$profili$survival_60 - c(.546, .398, .246)) < .015))
  # I valori completi di Schoenfeld vengono salvati per confronto esplicito.
  stopifnot(is.finite(diagnostica$ph_standard$table["GLOBAL", "p"]),
            is.finite(diagnostica$ph_stratificato$table["GLOBAL", "p"]))
  invisible(TRUE)
}
