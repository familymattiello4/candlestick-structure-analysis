library(dplyr)
library(cluster)

# =========================
# 1) CARICAMENTO DATI
# =========================
df <- read.csv("data/df_final.csv")

# =========================
# 2) FEATURE STRUTTURALI
# =========================
features <- df %>%
  transmute(body_ratio, shadow_bias)

features_scaled <- scale(features)
D <- dist(features_scaled, method = "euclidean")   # calcolata una volta sola

# =========================
# 3) CLUSTERING GERARCHICO ESPLORATIVO
# =========================
hc <- hclust(D, method = "ward.D2")

plot(hc,
     main = "Dendrogramma - Gerarchico (Ward D2)",
     xlab = "", sub = "", cex = 0.6)
abline(h = 11, col = "red", lty = 2, lwd = 2)

df$cluster_h <- factor(cutree(hc, k = 3))

plot(features$body_ratio, features$shadow_bias,
     col = as.integer(df$cluster_h), pch = 16,
     xlab = "Body ratio", ylab = "Shadow bias",
     main = "Clustering Gerarchico")
legend("topright", legend = paste("Cluster", 1:3), col = 1:3, pch = 16)

# =========================
# 4) SCELTA DI K: SILHOUETTE PER k = 2..10
# =========================
set.seed(123)
k_values <- 2:10
sil_scores <- sapply(k_values, function(k) {
  km <- kmeans(features_scaled, centers = k, nstart = 25)
  mean(silhouette(km$cluster, D)[, 3])
})

plot(k_values, sil_scores,
     type = "b", pch = 19,
     xlab = "k", ylab = "Silhouette media",
     main = "Silhouette media")
abline(v = k_values[which.max(sil_scores)], col = "red", lty = 2, lwd = 2)

# =========================
# 5) K-MEANS FINALE
# =========================
set.seed(123)
kmeans_res <- kmeans(features_scaled, centers = 3, nstart = 25)
df$cluster_raw <- kmeans_res$cluster

# Etichette assegnate in base alle CARATTERISTICHE, non all'ordine casuale:
#   1 = ombra inferiore prevalente (shadow_bias > 0)
#   2 = candele impulsive (body_ratio massimo)
#   3 = ombra superiore prevalente (shadow_bias < 0)
centri <- df %>%
  group_by(cluster_raw) %>%
  summarise(body = mean(body_ratio), shadow = mean(shadow_bias))

id_impulsivo <- centri$cluster_raw[which.max(centri$body)]
resto        <- centri %>% filter(cluster_raw != id_impulsivo)
id_inferiore <- resto$cluster_raw[which.max(resto$shadow)]
id_superiore <- resto$cluster_raw[which.min(resto$shadow)]

df$cluster_km <- factor(
  case_when(
    df$cluster_raw == id_inferiore ~ 1L,
    df$cluster_raw == id_impulsivo ~ 2L,
    df$cluster_raw == id_superiore ~ 3L
  ),
  levels = 1:3
)

plot(features$body_ratio, features$shadow_bias,
     col = as.integer(df$cluster_km), pch = 16,
     xlab = "Body ratio", ylab = "Shadow bias",
     main = "K-means (k = 3)")
legend("topright",
       legend = c("1 - Ombra inferiore", "2 - Impulsive", "3 - Ombra superiore"),
       col = 1:3, pch = 16, cex = 0.8)

cat("\nSilhouette media (K-means):",
    round(mean(silhouette(as.integer(df$cluster_km), D)[, 3]), 4), "\n")

# =========================
# 6) TABELLA DI PROFILO
# =========================
profile_km <- df %>%
  group_by(cluster_km) %>%
  summarise(
    n           = n(),
    body_ratio  = round(mean(body_ratio), 4),
    shadow_bias = round(mean(shadow_bias), 4),
    mean_Y      = round(mean(Y, na.rm = TRUE), 4),
    sd_Y        = round(sd(Y, na.rm = TRUE), 4)
  )

cat("\n=== Tabella di profilo dei cluster (K-means) ===\n")
print(profile_km)

# =========================
# 7) BOXPLOT Y PER CLUSTER
# =========================
boxplot(Y ~ cluster_km, data = df,
        main = "Distribuzione di Y per cluster",
        xlab = "Cluster", ylab = "Y")

# =========================
# 8) ANALISI CONDIZIONALE: DIREZIONE x CLUSTER
# =========================
rialz <- function(k) df %>% filter(cluster_km == k, dir == 1)
ribas <- function(k) df %>% filter(cluster_km == k, dir == -1)

boxplot_pro_contro <- function(g1, g2, nomi, colori, titolo) {
  boxplot(setNames(list(g1$Y, g2$Y), nomi),
          main = titolo, ylab = "Y", col = colori, ylim = c(-3, 3))
  abline(h = 0, col = "red", lty = 2)
  legend("topright",
         legend = paste(gsub("\n.*", "", nomi), "n =", c(nrow(g1), nrow(g2))),
         fill = colori, cex = 0.8)
}

stampa <- function(g, etichetta) {
  cat(etichetta, "- mean_Y:", round(mean(g$Y, na.rm = TRUE), 4),
      "| sd_Y:", round(sd(g$Y, na.rm = TRUE), 4),
      "| n:", nrow(g), "\n")
}

par(mfrow = c(1, 3))

# Cluster 1: ombra inferiore -> coerenti le rialziste
boxplot_pro_contro(rialz(1), ribas(1),
                   c("Rialziste\n(coerente)", "Ribassiste\n(incoerente)"),
                   c("lightblue", "lightcoral"),
                   "Cluster 1 - Pro vs Contro")

# Cluster 2: impulsive -> nessun giudizio di coerenza
boxplot_pro_contro(rialz(2), ribas(2),
                   c("Rialziste", "Ribassiste"),
                   c("lightblue", "lightcoral"),
                   "Cluster 2 - Rialziste vs Ribassiste")

# Cluster 3: ombra superiore -> coerenti le ribassiste
boxplot_pro_contro(ribas(3), rialz(3),
                   c("Ribassiste\n(coerente)", "Rialziste\n(incoerente)"),
                   c("lightcoral", "lightblue"),
                   "Cluster 3 - Pro vs Contro")

par(mfrow = c(1, 1))

cat("\n=== CLUSTER 1 (ombra inferiore) ===\n")
stampa(rialz(1), "Rialziste  (coerente)  ")
stampa(ribas(1), "Ribassiste (incoerente)")

cat("\n=== CLUSTER 2 (impulsive) ===\n")
stampa(rialz(2), "Rialziste ")
stampa(ribas(2), "Ribassiste")

cat("\n=== CLUSTER 3 (ombra superiore) ===\n")
stampa(ribas(3), "Ribassiste (coerente)  ")
stampa(rialz(3), "Rialziste  (incoerente)")