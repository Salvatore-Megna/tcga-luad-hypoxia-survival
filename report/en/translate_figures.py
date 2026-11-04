"""Traduci le sole etichette delle figure vettoriali del report TCGA-LUAD.

Le geometrie dei grafici e tutti i valori numerici restano invariati.
I PDF originali in report/figures non vengono mai sovrascritti.
"""
from pathlib import Path
from collections import Counter
import re
import pymupdf as fitz

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "report" / "figures"
DEST = ROOT / "report" / "en" / "figures"

LABELS = {
    "distribuzione_tempo_sopravvivenza.pdf": {
        "Distribuzione del tempo di sopravvivenza": "Distribution of survival time",
        "Numero di pazienti": "Number of patients",
        "Tempo di sopravvivenza o follow−up (mesi)": "Survival or follow-up time (months)"},
    "distribuzione_eta.pdf": {
        "Distribuzione dell'età alla diagnosi": "Distribution of age at diagnosis",
        "Numero di pazienti": "Number of patients",
        "Età alla diagnosi (anni)": "Age at diagnosis (years)"},
    "distribuzione_sesso.pdf": {
        "Distribuzione dei pazienti per sesso": "Patient distribution by sex",
        "Numero di pazienti": "Number of patients",
        "Femmina": "Female", "Maschio": "Male"},
    "distribuzione_stadio.pdf": {
        "Distribuzione dei pazienti per stadio patologico": "Patient distribution by pathological stage",
        "Numero di pazienti": "Number of patients",
        "Stadio patologico": "Pathological stage"},
    "distribuzione_istologia.pdf": {
        "Distribuzione dei pazienti per sottotipo istologico": "Patient distribution by histological subtype",
        "Numero di pazienti": "Number of patients",
        "Adenocarcinoma misto": "Mixed adenocarcinoma",
        "Altri sottotipi": "Other subtypes"},
    "distribuzione_hypoxia_scores.pdf": {
        "Distribuzione degli indicatori di ipossia tumorale": "Distribution of tumor-hypoxia indicators",
        "Numero di pazienti": "Number of patients",
        "Valore dello score": "Score value"},
    "correlazione_hypoxia_scores.pdf": {
        "Correlazione fra gli indicatori di ipossia tumorale": "Correlation among tumor-hypoxia indicators",
        "Correlazione": "Correlation"},
    "km_complessiva.pdf": {
        "Stima Kaplan−Meier della sopravvivenza complessiva": "Kaplan-Meier estimate of overall survival",
        "Probabilità di sopravvivenza": "Survival probability",
        "Tempo di sopravvivenza (mesi)": "Survival time (months)"},
    "km_stadio.pdf": {
        "Curve di Kaplan−Meier per stadio patologico": "Kaplan-Meier curves by pathological stage",
        "Probabilità di sopravvivenza": "Survival probability",
        "Tempo di sopravvivenza (mesi)": "Survival time (months)",
        "Stadio": "Stage", "Stadio I": "Stage I", "Stadio II": "Stage II",
        "Stadio III": "Stage III", "Stadio IV": "Stage IV"},
    "schoenfeld_sesso_stadio.pdf": {
        "Residui di Schoenfeld per sesso e stadio patologico": "Schoenfeld residuals for sex and pathological stage",
        "Sesso": "Sex", "Stadio patologico": "Pathological stage", "Tempo": "Time"},
    "martingala_eta_buffa.pdf": {
        "Residui di Martingala": "Martingale residuals",
        "Età (unità di 10 anni)": "Age (units of 10 years)",
        "Buffa score (unità di 10 punti)": "Buffa score (units of 10 points)"},
    "curve_profili_prognostici.pdf": {
        "Sopravvivenza aggiustata per profilo prognostico": "Adjusted survival by prognostic profile",
        "Tempo di sopravvivenza (mesi)": "Survival time (months)",
        "Probabilità di sopravvivenza aggiustata": "Adjusted survival probability",
        "Profilo": "Profile", "Favorevole": "Favorable",
        "Intermedio": "Intermediate", "Sfavorevole": "Unfavorable"}
}

LEFT = {"Profilo", "Favorevole", "Intermedio", "Sfavorevole",
        "Stadio", "Stadio I", "Stadio II", "Stadio III", "Stadio IV"}
RIGHT = {"Adenocarcinoma misto", "Altri sottotipi"}


def numerical_tokens(text):
    return Counter(re.findall(r"(?<!\w)[+-]?\d+(?:[.,]\d+)?%?",
                              text.replace("−", "-")))


def translate_one(source, destination, mapping):
    with fitz.open(source) as pdf:
        if len(pdf) != 1:
            raise ValueError(f"Expected a one-page original figure: {source}")
        page = pdf[0]
        original_text = page.get_text()
        edits = []
        numerical_spans = []

        for block in page.get_text("dict")["blocks"]:
            for line in block.get("lines", []):
                spans = line["spans"]
                text = "".join(span["text"] for span in spans).strip()
                if text not in mapping:
                    for span in spans:
                        if re.fullmatch(r"[+−-]?\d+(?:[.,]\d+)?%?", span["text"].strip()):
                            numerical_spans.append(span)
                    continue
                edits.append((text, mapping[text], fitz.Rect(line["bbox"]),
                              line["dir"], spans[0]))

        if set(mapping) != {item[0] for item in edits}:
            raise ValueError(f"Original figure labels do not match: {source.name}")

        for _, _, rect, _, _ in edits:
            page.add_redact_annot(rect + (-0.1, -0.1, 0.1, 0.1), fill=(1, 1, 1))
        # Rimuovi soltanto i glifi; conserva immagini e vettori del grafico.
        page.apply_redactions(images=0, graphics=0, text=0)

        for old, new, rect, direction, span in edits:
            fontname = "hebo" if "Bold" in span["font"] else "helv"
            font = fitz.Font(fontname=fontname)
            size = span["size"]
            width = font.text_length(new, fontsize=size)
            vertical = direction[1] < -0.9
            if not (vertical or direction[0] > 0.9):
                raise ValueError(f"Unexpected rotation for {old!r}")
            allowed = (page.rect.height if vertical else page.rect.width) - 12
            if width > allowed:
                size *= allowed / width
                width = font.text_length(new, fontsize=size)
            if vertical:
                x = span["origin"][0]
                y = rect.y0 + (rect.height + width) / 2
                y = max(width + 5, min(y, page.rect.height - 5))
            else:
                if old in LEFT:
                    x = span["origin"][0]
                elif old in RIGHT:
                    x = rect.x1 - width
                else:
                    x = rect.x0 + (rect.width - width) / 2
                x = max(5, min(x, page.rect.width - width - 5))
                y = span["origin"][1]
            page.insert_text((x, y), new, fontname=fontname, fontsize=size,
                             rotate=90 if vertical else 0, color=(0, 0, 0),
                             overlay=True)

        # I rettangoli di alcune etichette si sovrappongono marginalmente ai tick.
        # Ripristina i tick colpiti, sempre con gli stessi valori e nella stessa sede.
        missing = numerical_tokens(original_text) - numerical_tokens(page.get_text())
        for span in numerical_spans:
            value = span["text"].strip().replace("−", "-")
            if missing[value] <= 0:
                continue
            bounds = fitz.Rect(span["bbox"])
            if not any(bounds.intersects(item[2]) for item in edits):
                continue
            fontname = "hebo" if "Bold" in span["font"] else "helv"
            page.insert_text(span["origin"], value, fontname=fontname,
                             fontsize=span["size"], color=(0, 0, 0), overlay=True)
            missing[value] -= 1

        translated_text = page.get_text()
        if numerical_tokens(original_text) != numerical_tokens(translated_text):
            raise AssertionError(f"Numeric tick/annotation changed in {source.name}")
        if not all(text in translated_text for text in mapping.values()):
            raise AssertionError(f"Some English labels are missing in {source.name}")
        DEST.mkdir(parents=True, exist_ok=True)
        pdf.save(destination, garbage=4, deflate=True)
        return len(edits)


def main():
    total = 0
    for name, mapping in LABELS.items():
        count = translate_one(SOURCE / name, DEST / name, mapping)
        print(f"{name}: {count} labels translated; numerical annotations verified")
        total += count
    print(f"Completed {len(LABELS)} vector figures, {total} English labels.")


if __name__ == "__main__":
    main()
