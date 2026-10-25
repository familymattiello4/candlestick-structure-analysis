library(dplyr)
library(readr)

df <- read_csv("data/df_final.csv")

df <- df %>%
  mutate(
    range_prec = High_prec - Low_prec,
    Y_raw = ifelse(
      dir == 1, (High_succ - Close_prec) / range_prec,
      ifelse(
        dir == -1, (Low_succ - Close_prec) / range_prec,
        NA
      )
    ),
    # ✅ LIMITA Y tra -2 e +2 (valori ragionevoli)
    Y = pmax(-2, pmin(2, Y_raw))  # Clip tra -2 e 2
  )

df <- df %>%
  filter(is.finite(Y), range_prec > 0)

# Confronto prima/dopo
print("=== Y RAW (prima del clip) ===")
print(summary(df$Y_raw))
print("\n=== Y CLIPPED (dopo il clip) ===")
print(summary(df$Y))

plot(ecdf(df$Y),
     main = "FD empirica di Y (clipped tra -2 e 2)",
     xlab = "Y",
     ylab = "F(Y)")
grid()

hist(df$Y, breaks = 50, 
     main = "Distribuzione Y (clipped)", 
     col = "lightblue")

write_csv(df, "data/df_final.csv")