library(MASS)   # Regressione robusta (rlm) - caricata PRIMA di dplyr per evitare conflitti su select()
library(dplyr)  # ntile
library(readr)  # Lettura CSV

df <- read_csv("data/df_final.csv", show_col_types = FALSE)

# =========================
# 1) SCATTER X vs Y
# =========================
plot(df$X, df$Y,
     pch = 16, col = rgb(0, 0, 0, 0.3),
     xlab = "X (intenzione)",
     ylab = "Y (reazione)",
     main = "Scatter X vs Y")
abline(h = 0, v = 0, col = "grey")

# =========================
# 2) CORRELAZIONI
# =========================
cat("\n=== Correlazioni ===\n")
cat("Pearson :", round(cor(df$X, df$Y, method = "pearson"), 4), "\n")
cat("Spearman:", round(cor(df$X, df$Y, method = "spearman"), 4), "\n")

# =========================
# 3) REGRESSIONE LINEARE
# =========================
m1 <- lm(Y ~ X, data = df)
cat("\n=== Regressione lineare (OLS) ===\n")
print(summary(m1))
abline(m1, lwd = 2, col = "red")

# Diagnostica: residui vs valori stimati
plot(fitted(m1), resid(m1),
     pch = 16, col = rgb(0, 0, 0, 0.3),
     xlab = "Valori stimati (Y_hat)", ylab = "Residui",
     main = "Residui vs valori stimati")
abline(h = 0, col = "red", lwd = 2)

# =========================
# 4) REGRESSIONE ROBUSTA
# =========================
m2 <- rlm(Y ~ X, data = df)
cat("\n=== Regressione robusta (rlm) ===\n")
print(summary(m2))

# =========================
# 5) Y PER QUINTILI DI X
# =========================
df$X_q <- ntile(df$X, 5)

cat("\n=== Media di Y per quintile di X ===\n")
print(aggregate(Y ~ X_q, data = df, FUN = mean))

boxplot(Y ~ X_q, data = df,
        main = "Y per quintili di X",
        xlab = "Quintili X",
        ylab = "Y")