library(CVXR)
library(tidyr)
library(dplyr)
library(stringr)
# library(biostoreCapacity)

#' Optimize Backlog and Processed Tubes
#'
#' @description
#' Internal function that performs backlog minimization and capacity-constrained
#' processing optimization using CVXR. This function is called by
#' `predict_capacity_multiple_november1()` and should not be used directly.
#'
#' @param A_mat Matrix of arrivals (n_tube × n_time).
#' @param capacity_vec Vector of total monthly processing capacity.
#' @param stored_vec Vector of initial stored tube counts per tube type.
#' @param w_vec Vector of tube-specific weights.
#'
#' @return
#' A list containing optimization results (backlog, processed counts, etc.),
#' used internally by higher-level forecasting functions.
#'
#' @keywords internal
#' @noRd
library(CVXR)

optimize_backlog_and_processed <- function(
    A_mat, capacity_vec, stored_vec, w_vec,
    lambda = 0.1
) {
  n_tube <- nrow(A_mat)
  n_time <- ncol(A_mat)

  X <- Variable(n_tube, n_time, nonneg = TRUE)
  Q <- Variable(n_tube, n_time, nonneg = TRUE)
  D <- Variable(n_tube, n_time, nonneg = TRUE)

  constraints <- list()
  for (t in 1:n_time) {
    if (t == 1) {
      constraints <- c(constraints, Q[, t] == stored_vec + A_mat[, t] - X[, t])
    } else {
      constraints <- c(constraints, Q[, t] == Q[, t - 1] + A_mat[, t] - X[, t])
      constraints <- c(constraints, D[, t] >= Q[, t] - Q[, t - 1])
    }
    constraints <- c(constraints, sum_entries(X[, t]) <= capacity_vec[t])
  }

  # make weights the same dimension as Q
  W <- matrix(w_vec, n_tube, n_time)
  objective <- sum_entries(Q * W) + lambda * sum_entries(D)

  prob <- Problem(Minimize(objective), constraints)
  result <- solve(prob, solver = "ECOS")

  list(
    status = result$status,
    X_opt = result$getValue(X),
    Q_opt = result$getValue(Q),
    D_opt = result$getValue(D)
  )
}



# optimize_backlog_and_processed <- function(
#     A_mat,
#     capacity_vec,
#     stored_vec,
#     w_vec
# ) {
#   n_tube <- nrow(A_mat)
#   n_time <- ncol(A_mat)
#
#   X <- Variable(n_tube, n_time, nonneg = TRUE)
#   Q <- Variable(n_tube, n_time, nonneg = TRUE)
#
#   constraints <- list()
#   for (t in 1:n_time) {
#     if (t == 1) {
#       # backlog after first period >= stock + arrivals - processed
#       constraints <- c(constraints,
#                        Q[, t] >= stored_vec + A_mat[, t] - X[, t])
#     } else {
#       # backlog carries over; inequality avoids precision infeasibility
#       constraints <- c(constraints,
#                        Q[, t] >= Q[, t - 1] + A_mat[, t] - X[, t])
#     }
#     constraints <- c(constraints, sum_entries(X[, t]) <= capacity_vec[t])
#   }
#
#   # Quadratic backlog penalty
#   objective <- 0
#   for (i in 1:n_tube) {
#     objective <- objective + w_vec[i] * sum_squares(Q[i, ])
#   }
#
#   prob <- Problem(Minimize(objective), constraints)
#   result <- solve(prob, solver = "OSQP")  # OSQP handles QPs robustly
#
#   list(
#     status = result$status,
#     X_opt = result$getValue(X),
#     Q_opt = result$getValue(Q)
#   )
# }



# optimize_backlog_and_processed <- function(
#     A_mat,        # arrivals matrix (n_tube x n_time)
#     capacity_vec,        # capacity vector (length n_time)
#     stored_vec,   # initial stock (length n_tube)
#     w_vec,        # weight vector (length n_tube)
#     w_stored = 1000,
#     w_stored_increase = 0.01
# ) {
#   # --- basic validations ---
#   if (!is.matrix(A_mat)) stop("A_mat must be a matrix (n_tube x n_time).")
#   if (!is.numeric(capacity_vec)) stop("capacity_vec must be a numeric vector.")
#   if (!is.numeric(stored_vec)) stop("stored_vec must be numeric.")
#   if (!is.numeric(w_vec)) stop("w_vec must be numeric.")
#
#   n_tube <- nrow(A_mat)
#   n_time <- ncol(A_mat)
#
#   if (length(capacity_vec) != n_time)
#     stop("Length of capacity_vec must match number of columns in A_mat.")
#   if (length(stored_vec) != n_tube)
#     stop("Length of stored_vec must match number of rows in A_mat.")
#   if (length(w_vec) != n_tube)
#     stop("Length of w_vec must match number of rows in A_mat.")
#
#   # --- define variables ---
#   X <- Variable(n_tube, n_time, nonneg = TRUE)
#   Q <- Variable(n_tube, n_time, nonneg = TRUE)
#
#   # --- constraints ---
#   constraints <- list()
#   for (t in 1:n_time) {
#     if (t == 1) {
#       constraints <- c(constraints, Q[, t] == stored_vec + A_mat[, t] - X[, t])
#     } else {
#       constraints <- c(constraints, Q[, t] == Q[, t - 1] + A_mat[, t] - X[, t])
#     }
#     constraints <- c(constraints, sum_entries(X[, t]) <= capacity_vec[t])
#   }
#
#   # --- g weights (large start, small slope) ---
#   # g <- matrix(w_stored + w_stored_increase * (1:n_time), nrow = 1)
#   g  <- matrix(w_stored * exp(-w_stored_increase * (0:(n_time-1))), nrow = 1)
#   # --- objective ---
#   objective <- sum_entries(t(w_vec) %*% (Q %*% diag(as.numeric(g))))
#
#   # --- solve ---
#   prob <- Problem(Minimize(objective), constraints)
#   result <- solve(prob, solver = "ECOS")
#
#   # --- extract results ---
#   X_opt <- result$getValue(X)
#   Q_opt <- result$getValue(Q)
#
#   # --- sanity check ---
#   if (any(is.na(X_opt)) || any(is.na(Q_opt))) warning("Optimization returned NA values.")
#
#   list(
#     status = result$status,
#     g = g,
#     X_opt = X_opt,
#     Q_opt = Q_opt
#   )
# }



# # Example data
# tube_types <- c("Tube5", "Tube10")
# n_tube <- length(tube_types)
# periods <- seq.Date(as.Date("2025-01-01"), by = "2 weeks", length.out = 100)
# n_time <- length(periods)
#
# A_mat <- matrix(0, nrow = n_tube, ncol = n_time)
# A_mat[1, 1:6] <- c(100, 100, 50, 50, 25, 25)
# A_mat[2, 1:4] <- c(50, 50, 50, 50)
#
# capacity_vec <- c(rep(20, n_time%/%2),rep(50, n_time%/%2))
# stored_vec <- c(100, 50)
# w_vec <- c(1, 1)
#
# res <- optimize_backlog_and_processed(A_mat, capacity_vec, stored_vec, w_vec, w_stored = 1000, w_stored_increase = 0.02)
#
# # Inspect
# round(res$X_opt, 1)
# round(res$Q_opt, 1)
#
# # Plot backlog
# matplot(t(res$Q_opt), type = "l", lty = 1, col = 1:2,
#         ylab = "Backlog", xlab = "Period", main = "Backlog over time")
# legend("topright", legend = tube_types, col = 1:2, lty = 1)
#
# matplot(t(res$X_opt), type = "l", lty = 1, col = 1:2,
#         ylab = "Backlog", xlab = "Period", main = "Processed over time")
# legend("topright", legend = tube_types, col = 1:2, lty = 1)
#
# matplot(colSums(res$X_opt), type = "l", lty = 1, col = 1:2,
#         ylab = "Backlog", xlab = "Period", main = "Total processed over time")
# legend("topright", legend = tube_types, col = 1:2, lty = 1)
#
#
#
# plot_backlog_and_processed <- function(Q_opt, X_opt, tube_types, periods) {
#   stopifnot(is.matrix(Q_opt), is.matrix(X_opt))
#   stopifnot(all(dim(Q_opt) == dim(X_opt)))
#   stopifnot(length(tube_types) == nrow(Q_opt))
#   stopifnot(length(periods) == ncol(Q_opt))
#
#   n_tube <- nrow(Q_opt)
#   n_time <- ncol(Q_opt)
#
#   # Build tidy data
#   dfQ <- data.frame(
#     tube_type = rep(tube_types, each = n_time),
#     period = rep(periods, times = n_tube),
#     value = as.vector(t(Q_opt)),
#     metric = "Backlog (Q)"
#   )
#
#   dfX <- data.frame(
#     tube_type = rep(tube_types, each = n_time),
#     period = rep(periods, times = n_tube),
#     value = as.vector(t(X_opt)),
#     metric = "Processed (X)"
#   )
#
#   df <- rbind(dfQ, dfX)
#
#   # Plot
#   if (!requireNamespace("ggplot2", quietly = TRUE)) {
#     stop("Please install.packages('ggplot2') to use this plotting function.")
#   }
#
#   library(ggplot2)
#   ggplot(df, aes(x = period, y = value, color = metric, linetype = metric)) +
#     geom_line(linewidth = 1) +
#     facet_wrap(~ tube_type, scales = "free_y") +
#     scale_x_date(date_labels = "%b %d", date_breaks = "1 month") +
#     theme_minimal(base_size = 13) +
#     theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
#     labs(
#       title = "Processed vs Backlog per Tube Type",
#       x = "Time (Period)",
#       y = "Number of Tubes",
#       color = "Metric",
#       linetype = "Metric"
#     )
# }
# # plot_backlog_and_processed(res$Q_opt, res$X_opt, tube_types,periods)
# plot_backlog_processed_arrivals <- function(Q_opt, X_opt, A_mat, tube_types, periods) {
#   stopifnot(is.matrix(Q_opt), is.matrix(X_opt), is.matrix(A_mat))
#   stopifnot(all(dim(Q_opt) == dim(X_opt)), all(dim(Q_opt) == dim(A_mat)))
#   stopifnot(length(tube_types) == nrow(Q_opt))
#   stopifnot(length(periods) == ncol(Q_opt))
#
#   n_tube <- nrow(Q_opt)
#   n_time <- ncol(Q_opt)
#
#   # Build tidy frames
#   dfQ <- data.frame(
#     tube_type = rep(tube_types, each = n_time),
#     period = rep(periods, times = n_tube),
#     value = as.vector(t(Q_opt)),
#     metric = "Backlog (Q)"
#   )
#   dfX <- data.frame(
#     tube_type = rep(tube_types, each = n_time),
#     period = rep(periods, times = n_tube),
#     value = as.vector(t(X_opt)),
#     metric = "Processed (X)"
#   )
#   dfA <- data.frame(
#     tube_type = rep(tube_types, each = n_time),
#     period = rep(periods, times = n_tube),
#     value = as.vector(t(A_mat)),
#     metric = "Arrivals (A)"
#   )
#
#   df <- rbind(dfA, dfX, dfQ)
#
#   library(ggplot2)
#   ggplot(df, aes(x = period, y = value, color = metric, linetype = metric)) +
#     geom_line(linewidth = 1) +
#     facet_wrap(~ tube_type, scales = "free_y") +
#     scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
#     theme_minimal(base_size = 13) +
#     theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
#     labs(
#       title = "Arrivals (A), Processed (X), and Backlog (Q) per Tube Type",
#       x = "Time (biweekly steps)",
#       y = "Number of Tubes",
#       color = "",
#       linetype = ""
#     )
# }

# # -----------------------------
# # Example 1: SINGLE tube
# tube_types <- c("Tube5")
# n_tube <- length(tube_types)
# periods <- seq.Date(as.Date("2025-01-01"), by = "2 weeks", length.out = 40)
# n_time <- length(periods)
#
# A_mat <- matrix(0, nrow = n_tube, ncol = n_time)
# A_mat[1, 1:8] <- c(100, 80, 60, 40, 20, 10, 5, 5)
# # capacity_vec <- rep(50, n_time)
# capacity_vec <- c(rep(30, n_time/2), rep(70, n_time/2))
#
# stored_vec <- c(200)
# w_vec <- c(1)
#
# res1 <- optimize_backlog_and_processed(A_mat, capacity_vec, stored_vec, w_vec,
#                                        w_stored = 10., w_stored_increase = 1.)
#
# cat("\n--- Single Tube Example ---\n")
# print(round(res1$X_opt, 1))
# print(round(res1$Q_opt, 1))
#
# p1 <- plot_backlog_processed_arrivals(res1$Q_opt, res1$X_opt, A_mat, tube_types, periods)
# ggsave("man/figures/example_single_tube.png", p1, width = 8, height = 4)
# p1
#
# # -----------------------------
# # Example 2: THREE tubes
# tube_types <- c("Tube5", "Tube10", "Tube15")
# n_tube <- length(tube_types)
# # periods <- seq.Date(as.Date("2025-01-01"), by = "2 weeks", length.out = 60)
# # n_time <- length(periods)
#
# A_mat <- matrix(0, nrow = n_tube, ncol = n_time)
# A_mat[1, 1:6] <- c(100, 100, 50, 50, 25, 25)
# A_mat[2, 1:5] <- c(80, 80, 60, 40, 20)
# A_mat[3, 1:4] <- c(30, 30, 20, 10)
#
# # capacity_vec <- c(rep(30, n_time/2), rep(70, n_time/2))
# stored_vec <- c(200, 100, 50)
# w_vec <- c(1, 1.5, 2)  # Tube15 gets highest priority
#
# res3 <- optimize_backlog_and_processed(A_mat, capacity_vec, stored_vec, w_vec,
#                                        w_stored = 10., w_stored_increase = 1.)
#
# cat("\n--- Three Tube Example ---\n")
# print(round(res3$X_opt, 1))
# print(round(res3$Q_opt, 1))
#
# p3 <- plot_backlog_processed_arrivals(res3$Q_opt, res3$X_opt, A_mat, tube_types, periods)
# ggsave("man/figures/example_three_tubes.png", p3, width = 8, height = 4)
# p3
#
#
#
