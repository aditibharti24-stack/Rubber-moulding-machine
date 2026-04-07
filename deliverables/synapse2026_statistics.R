# Synapse 2026
# Inferential Statistics in R for the IoT-enabled 4-pillar compression rubber molding machine
# This script is fully reproducible and uses simulated data when real data are unavailable.

# -----------------------------
# 0. Setup
# -----------------------------

set.seed(2026)

if (!requireNamespace("MASS", quietly = TRUE)) {
  stop("Package 'MASS' is required. Install it with install.packages('MASS').")
}

suppressPackageStartupMessages(library(MASS))

# Resolve the script directory so outputs are written next to this file.
args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- args[grep(file_arg, args)]
script_path <- if (length(script_path) > 0) {
  normalizePath(sub(file_arg, "", script_path[1]))
} else {
  normalizePath(getwd())
}
script_dir <- if (dir.exists(script_path)) script_path else dirname(script_path)
output_dir <- file.path(script_dir, "statistics_output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

summary_file <- file.path(output_dir, "analysis_summary.txt")
sink(summary_file, split = TRUE)

cat("Synapse 2026 Statistical Analysis\n")
cat("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n\n")

# -----------------------------
# 1. Data simulation
# -----------------------------

# Assumptions:
# - 720 hourly observations (30 days x 24 hours)
# - Temperature target is around 180 degC
# - Pressure depends on process cycle: Pre-Heat, Compression, Cooling
# - Vibration is normally low but spikes during emerging mechanical faults
# - Some anomalies are injected deliberately for detection exercises

n_hours <- 24 * 30
timestamps <- seq.POSIXt(
  from = as.POSIXct("2026-03-01 00:00:00", tz = "Asia/Kolkata"),
  by = "hour",
  length.out = n_hours
)

hour_of_day <- as.integer(format(timestamps, "%H"))
shift <- ifelse(
  hour_of_day >= 6 & hour_of_day < 14, "Morning",
  ifelse(hour_of_day >= 14 & hour_of_day < 22, "Afternoon", "Night")
)
shift <- factor(shift, levels = c("Morning", "Afternoon", "Night"))

cycle_phase <- factor(
  rep(c("Pre-Heat", "Compression", "Cooling"), length.out = n_hours),
  levels = c("Pre-Heat", "Compression", "Cooling")
)

# Simulate temperature around the target with mild daily seasonality and shift effect.
temperature <- 180 +
  2.5 * sin(2 * pi * seq_len(n_hours) / 24) +
  ifelse(shift == "Morning", -0.8, ifelse(shift == "Afternoon", 1.1, -0.2)) +
  rnorm(n_hours, mean = 0, sd = 3.8)

# Simulate pressure by operating phase.
pressure <- ifelse(cycle_phase == "Pre-Heat", 72,
                   ifelse(cycle_phase == "Compression", 122, 84)) +
  rnorm(n_hours, mean = 0, sd = 6.5)

# Simulate vibration with slightly higher levels during compression.
vibration <- 1.1 +
  ifelse(cycle_phase == "Compression", 0.5, 0.15) +
  abs(rnorm(n_hours, mean = 0, sd = 0.45))

# Inject anomalies.
temp_spike_idx <- sample(seq_len(n_hours), 10)
pressure_spike_idx <- sample(setdiff(seq_len(n_hours), temp_spike_idx), 8)
vibration_spike_idx <- sample(setdiff(seq_len(n_hours), c(temp_spike_idx, pressure_spike_idx)), 12)

temperature[temp_spike_idx[1:5]] <- temperature[temp_spike_idx[1:5]] + runif(5, 12, 18)
temperature[temp_spike_idx[6:10]] <- temperature[temp_spike_idx[6:10]] - runif(5, 15, 20)
pressure[pressure_spike_idx] <- pressure[pressure_spike_idx] + runif(length(pressure_spike_idx), 22, 34)
vibration[vibration_spike_idx] <- vibration[vibration_spike_idx] + runif(length(vibration_spike_idx), 2.5, 4.2)

# Keep the simulated values in realistic ranges.
temperature <- pmax(pmin(temperature, 205), 145)
pressure <- pmax(pmin(pressure, 160), 50)
vibration <- pmax(pmin(vibration, 6), 0.05)

# Simulate quality and defects as downstream production outcomes.
quality_score <- 98 -
  0.18 * abs(temperature - 180) -
  0.05 * abs(pressure - 100) -
  1.15 * vibration +
  rnorm(n_hours, mean = 0, sd = 1.8)
quality_score <- pmax(pmin(quality_score, 100), 60)

defect_count <- round(
  pmax(
    0,
    1.5 +
      0.10 * abs(temperature - 180) +
      0.06 * abs(pressure - 100) +
      0.85 * vibration +
      rnorm(n_hours, mean = 0, sd = 1.2)
  )
)

iot_data <- data.frame(
  timestamp = timestamps,
  shift = shift,
  cycle_phase = cycle_phase,
  temperature = temperature,
  pressure = pressure,
  vibration = vibration,
  quality_score = quality_score,
  defect_count = defect_count
)

write.csv(iot_data, file.path(output_dir, "simulated_iot_data.csv"), row.names = FALSE)

cat("1. Data simulation complete\n")
cat("Rows generated:", nrow(iot_data), "\n")
cat("Columns:", paste(names(iot_data), collapse = ", "), "\n\n")

# -----------------------------
# 2. Descriptive statistics
# -----------------------------

descriptive_stats <- data.frame(
  sensor = c("temperature", "pressure", "vibration"),
  mean = c(mean(iot_data$temperature), mean(iot_data$pressure), mean(iot_data$vibration)),
  median = c(median(iot_data$temperature), median(iot_data$pressure), median(iot_data$vibration)),
  sd = c(sd(iot_data$temperature), sd(iot_data$pressure), sd(iot_data$vibration)),
  IQR = c(IQR(iot_data$temperature), IQR(iot_data$pressure), IQR(iot_data$vibration))
)

write.csv(descriptive_stats, file.path(output_dir, "descriptive_statistics.csv"), row.names = FALSE)

cat("2. Descriptive statistics\n")
print(descriptive_stats)
cat("\n")

png(file.path(output_dir, "sensor_histograms.png"), width = 1200, height = 400)
par(mfrow = c(1, 3))
hist(iot_data$temperature, breaks = 30, col = "tomato", main = "Temperature Histogram", xlab = "Temperature (degC)")
hist(iot_data$pressure, breaks = 30, col = "steelblue", main = "Pressure Histogram", xlab = "Pressure (bar)")
hist(iot_data$vibration, breaks = 30, col = "goldenrod", main = "Vibration Histogram", xlab = "Vibration (mm/s)")
dev.off()

png(file.path(output_dir, "sensor_boxplots.png"), width = 1200, height = 400)
par(mfrow = c(1, 3))
boxplot(iot_data$temperature, col = "tomato", main = "Temperature Boxplot", ylab = "Temperature (degC)")
boxplot(iot_data$pressure, col = "steelblue", main = "Pressure Boxplot", ylab = "Pressure (bar)")
boxplot(iot_data$vibration, col = "goldenrod", main = "Vibration Boxplot", ylab = "Vibration (mm/s)")
dev.off()

# -----------------------------
# 3. Hypothesis testing
# -----------------------------

cat("3. Hypothesis testing\n")

# One-sample t-test:
# H0: mean temperature = 180 degC
# H1: mean temperature != 180 degC
one_sample_t <- t.test(iot_data$temperature, mu = 180)
cat("One-sample t-test: Temperature vs 180 degC\n")
print(one_sample_t)
cat("\n")

# Two-sample t-test:
# Compare morning and afternoon temperature readings.
shift_data <- subset(iot_data, shift %in% c("Morning", "Afternoon"))
two_sample_t <- t.test(temperature ~ shift, data = shift_data)
cat("Two-sample t-test: Morning vs Afternoon temperature\n")
print(two_sample_t)
cat("\n")

# ANOVA:
# Test whether pressure differs across pre-heat, compression, and cooling.
anova_model <- aov(pressure ~ cycle_phase, data = iot_data)
cat("ANOVA: Pressure by cycle phase\n")
print(summary(anova_model))
cat("\n")

# -----------------------------
# 4. Regression analysis
# -----------------------------

cat("4. Regression analysis\n")

simple_lm <- lm(quality_score ~ temperature, data = iot_data)
multiple_lm <- lm(defect_count ~ temperature + pressure + vibration, data = iot_data)

cat("Simple linear regression: quality_score ~ temperature\n")
print(summary(simple_lm))
cat("\n")

cat("Multiple regression: defect_count ~ temperature + pressure + vibration\n")
print(summary(multiple_lm))
cat("\n")

simple_summary <- summary(simple_lm)
multiple_summary <- summary(multiple_lm)

cat("Interpretation notes\n")
cat(sprintf("Simple regression R-squared: %.4f\n", simple_summary$r.squared))
cat("Temperature coefficient tells how quality_score changes for each 1 degC change in temperature.\n")
cat(sprintf("Multiple regression R-squared: %.4f\n", multiple_summary$r.squared))
cat("Multiple regression coefficients estimate the change in defect_count associated with each predictor, holding the others constant.\n")
cat("Predictors with p-values below 0.05 are statistically significant at the 5 percent level.\n\n")

# -----------------------------
# 5. Control charts (SPC)
# -----------------------------

cat("5. Statistical process control\n")

# Create subgrouped temperature readings with subgroup size 5.
subgroup_size <- 5
n_groups <- floor(nrow(iot_data) / subgroup_size)
temperature_groups <- matrix(
  iot_data$temperature[1:(n_groups * subgroup_size)],
  ncol = subgroup_size,
  byrow = TRUE
)

group_means <- rowMeans(temperature_groups)
group_ranges <- apply(temperature_groups, 1, function(x) diff(range(x)))

# Control chart constants for subgroup size n = 5.
A2 <- 0.577
D3 <- 0.000
D4 <- 2.114

xbar_bar <- mean(group_means)
r_bar <- mean(group_ranges)

ucl_x <- xbar_bar + A2 * r_bar
lcl_x <- xbar_bar - A2 * r_bar
ucl_r <- D4 * r_bar
lcl_r <- D3 * r_bar

out_of_control_x <- which(group_means > ucl_x | group_means < lcl_x)
out_of_control_r <- which(group_ranges > ucl_r | group_ranges < lcl_r)

cat(sprintf("X-bar chart center line: %.3f\n", xbar_bar))
cat(sprintf("X-bar chart UCL: %.3f, LCL: %.3f\n", ucl_x, lcl_x))
cat(sprintf("R chart center line: %.3f\n", r_bar))
cat(sprintf("R chart UCL: %.3f, LCL: %.3f\n", ucl_r, lcl_r))
cat("Out-of-control X-bar subgroups:", if (length(out_of_control_x) == 0) "None" else paste(out_of_control_x, collapse = ", "), "\n")
cat("Out-of-control R subgroups:", if (length(out_of_control_r) == 0) "None" else paste(out_of_control_r, collapse = ", "), "\n")
cat("Out-of-control points suggest special-cause variation and should trigger investigation into heating control, hydraulics, or mechanical wear.\n\n")

png(file.path(output_dir, "temperature_control_charts.png"), width = 1200, height = 700)
par(mfrow = c(2, 1))

plot(group_means, type = "b", pch = 16, col = "firebrick",
     main = "X-bar Chart for Temperature",
     xlab = "Subgroup", ylab = "Mean Temperature (degC)")
abline(h = xbar_bar, col = "darkgreen", lwd = 2)
abline(h = c(lcl_x, ucl_x), col = "blue", lty = 2, lwd = 2)
if (length(out_of_control_x) > 0) {
  points(out_of_control_x, group_means[out_of_control_x], col = "red", pch = 19, cex = 1.3)
}

plot(group_ranges, type = "b", pch = 16, col = "darkorange",
     main = "R Chart for Temperature",
     xlab = "Subgroup", ylab = "Range (degC)")
abline(h = r_bar, col = "darkgreen", lwd = 2)
abline(h = c(lcl_r, ucl_r), col = "blue", lty = 2, lwd = 2)
if (length(out_of_control_r) > 0) {
  points(out_of_control_r, group_ranges[out_of_control_r], col = "red", pch = 19, cex = 1.3)
}
dev.off()

# -----------------------------
# 6. Survival / reliability analysis
# -----------------------------

cat("6. Survival and reliability analysis\n")

# Simulate time-between-failure data in hours.
# Weibull shape > 1 implies Increasing Failure Rate (IFR).
time_between_failure <- round(rweibull(40, shape = 1.8, scale = 120), 1)

exp_fit <- fitdistr(time_between_failure, densfun = "exponential")
weib_fit <- fitdistr(time_between_failure, densfun = "weibull")

exp_rate <- unname(exp_fit$estimate["rate"])
weib_shape <- unname(weib_fit$estimate["shape"])
weib_scale <- unname(weib_fit$estimate["scale"])

reliability_100h_exp <- exp(-exp_rate * 100)
reliability_100h_weib <- exp(- (100 / weib_scale) ^ weib_shape)

cat("Exponential fit\n")
print(exp_fit)
cat("\n")

cat("Weibull fit\n")
print(weib_fit)
cat("\n")

cat(sprintf("Estimated reliability at 100 hours (Exponential): %.4f\n", reliability_100h_exp))
cat(sprintf("Estimated reliability at 100 hours (Weibull): %.4f\n", reliability_100h_weib))

if (weib_shape > 1) {
  cat(sprintf("Weibull shape parameter = %.3f, so the system exhibits IFR behavior.\n", weib_shape))
  cat("Interpretation: failure likelihood increases with age or use, which supports preventive or predictive maintenance scheduling.\n\n")
} else {
  cat(sprintf("Weibull shape parameter = %.3f, so IFR is not supported by this sample.\n\n", weib_shape))
}

png(file.path(output_dir, "time_between_failure_histogram.png"), width = 800, height = 500)
hist(time_between_failure, breaks = 12, col = "gray70",
     main = "Time Between Failure Histogram", xlab = "Hours")
dev.off()

# -----------------------------
# 7. Anomaly detection using Z-scores
# -----------------------------

cat("7. Anomaly detection\n")

iot_data$temperature_z <- as.numeric(scale(iot_data$temperature))
iot_data$pressure_z <- as.numeric(scale(iot_data$pressure))
iot_data$vibration_z <- as.numeric(scale(iot_data$vibration))

iot_data$temp_anomaly <- abs(iot_data$temperature_z) > 3
iot_data$pressure_anomaly <- abs(iot_data$pressure_z) > 3
iot_data$vibration_anomaly <- abs(iot_data$vibration_z) > 3

anomaly_counts <- data.frame(
  sensor = c("temperature", "pressure", "vibration"),
  anomalies = c(sum(iot_data$temp_anomaly), sum(iot_data$pressure_anomaly), sum(iot_data$vibration_anomaly))
)

write.csv(anomaly_counts, file.path(output_dir, "anomaly_counts.csv"), row.names = FALSE)
write.csv(subset(iot_data, temp_anomaly | pressure_anomaly | vibration_anomaly),
          file.path(output_dir, "flagged_anomalies.csv"),
          row.names = FALSE)

print(anomaly_counts)
cat("\n")

png(file.path(output_dir, "anomaly_time_series.png"), width = 1200, height = 900)
par(mfrow = c(3, 1), mar = c(4, 4, 3, 1))

plot(iot_data$timestamp, iot_data$temperature, type = "l", col = "tomato",
     main = "Temperature Time Series with Anomalies", xlab = "Timestamp", ylab = "Temperature (degC)")
points(iot_data$timestamp[iot_data$temp_anomaly],
       iot_data$temperature[iot_data$temp_anomaly],
       col = "red", pch = 19)

plot(iot_data$timestamp, iot_data$pressure, type = "l", col = "steelblue",
     main = "Pressure Time Series with Anomalies", xlab = "Timestamp", ylab = "Pressure (bar)")
points(iot_data$timestamp[iot_data$pressure_anomaly],
       iot_data$pressure[iot_data$pressure_anomaly],
       col = "red", pch = 19)

plot(iot_data$timestamp, iot_data$vibration, type = "l", col = "goldenrod",
     main = "Vibration Time Series with Anomalies", xlab = "Timestamp", ylab = "Vibration (mm/s)")
points(iot_data$timestamp[iot_data$vibration_anomaly],
       iot_data$vibration[iot_data$vibration_anomaly],
       col = "red", pch = 19)
dev.off()

# -----------------------------
# 8. Optional database integration example
# -----------------------------

cat("8. Optional database integration note\n")
cat("In production, the simulated dataset can be replaced by a query to PostgreSQL.\n")
cat("Typical flow: PostgreSQL table -> exported CSV or DB connection -> R analysis -> dashboard/report.\n\n")

# Example template only. Uncomment if DBI and RPostgres are installed.
# library(DBI)
# library(RPostgres)
# con <- dbConnect(
#   RPostgres::Postgres(),
#   dbname = "synapse2026",
#   host = "127.0.0.1",
#   port = 5432,
#   user = "postgres",
#   password = "your_password"
# )
# db_data <- dbGetQuery(con, "SELECT * FROM sensor_reading;")
# dbDisconnect(con)

sink()

cat("Analysis complete. Outputs saved to:\n", output_dir, "\n")
