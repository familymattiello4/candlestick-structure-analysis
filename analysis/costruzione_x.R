library(zoo)    # Funzioni per medie mobili/rolling
library(dplyr)  # Pipeline e trasformazioni dati (mutate/filter ecc.)
library(readr)  # Lettura/scrittura CSV veloce
library(tidyr)  # Utility per NA e reshaping

df <- read_csv("data/dataset_start_AAPL.csv") # Carica dataset OHLCV già shiftato (_prec/_succ)

df <- df %>%
  mutate(
    dir = ifelse(Close_prec > Open_prec,  1, ifelse(Close_prec < Open_prec, -1, 0)), # Direzione candela precedente: long(+1), short(-1), neutra(0)
    body = abs(Close_prec - Open_prec),                                              # Ampiezza corpo: misura “decisione” della candela
    range_prec = High_prec - Low_prec,                                               # Range totale: scala/volatilità della candela
    body_ratio = ifelse(range_prec > 0, body / range_prec, 0),                       # Corpo normalizzato: forza relativa indipendente dalla scala
    upper_shadow = High_prec - pmax(Open_prec, Close_prec),                          # Ombra superiore: pressione di vendita durante la candela
    lower_shadow = pmin(Open_prec, Close_prec) - Low_prec,                           # Ombra inferiore: pressione di acquisto durante la candela
    shadow_bias = ifelse(range_prec > 0, (lower_shadow - upper_shadow) / range_prec, 0), # Bias ombre: >0 bullish, <0 bearish
    shadow_factor = 1 + dir * shadow_bias
  )





df <- df %>%
  mutate(

    X = dir * body_ratio * shadow_factor 
  )

# FD (funzione di distribuzione empirica) di X
plot(ecdf(df$X),
     main = "Funzione di distribuzione empirica di X",
     xlab = "X",
     ylab = "F(X)")
grid()



summary(df$X) # Riassunto statistico di X (controllo sanity)
hist(df$X, breaks = 50, main = "Distribuzione X") # Istogramma X (controllo forma/distribuzione)

write_csv(df, "data/df_final.csv")
