library(dplyr)
library(readr)

# ============================================
# NORMALIZZAZIONE FOREX -> PIPS
# ============================================
# 1 pip = 0.0001 per EURUSD, GBPUSD  -> moltiplicatore 10000
# 1 pip = 0.01   per USDJPY          -> moltiplicatore 100

PAIR           <- "EURUSD"   # cambia in "GBPUSD" per l'altro cross
PIP_MULTIPLIER <- 10000

input_file  <- paste0("data/dataset_start_", PAIR, ".csv")
output_file <- paste0("data/dataset_start_", PAIR, "_pips.csv")

df <- read_csv(input_file, show_col_types = FALSE)

price_cols <- c("Open_prec", "High_prec", "Low_prec", "Close_prec",
                "Open_succ", "High_succ", "Low_succ", "Close_succ")

if (median(df$Close_prec, na.rm = TRUE) < 10) {
  df <- df %>% mutate(across(all_of(price_cols), ~ .x * PIP_MULTIPLIER))
  cat("Prezzi convertiti in pips\n")
} else {
  cat("Prezzi già in pips: nessuna conversione\n")
}
# Salva in un file NUOVO (l'originale resta intatto)
write_csv(df, output_file)

cat("\n✅ Dataset salvato in:", output_file, "\n")