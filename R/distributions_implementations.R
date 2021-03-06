# additional distributions provided by NIMBLE
# FIXME: these should be modified to go directly to C w/o type conversion, with error-checking in C

dwish_chol <- function(x, cholesky, df, scale_param = TRUE, log = FALSE) {
  # scale_param = TRUE is the GCSR parameterization (i.e., scale matrix); scale_param = FALSE is the BUGS parameterization (i.e., rate matrix)
  .Call('C_dwish_chol', as.double(x), as.double(cholesky), as.double(df), as.logical(scale_param), as.logical(log))
}

rwish_chol <- function(n = 1, cholesky, df, scale_param = TRUE) {
    if(n != 1) warning('rwish_chol only handles n = 1 at the moment')
    matrix(.Call('C_rwish_chol', as.double(cholesky), as.double(df), as.logical(scale_param)), nrow = sqrt(length(cholesky)))
}

ddirch <- function(x, alpha, log = FALSE) {
    .Call('C_ddirch', as.double(x), as.double(alpha), as.logical(log))
}

rdirch <- function(n = 1, alpha) {
    if(n != 1) warning('rdirch only handles n = 1 at the moment')
  .Call('C_rdirch', as.double(alpha))
}

dmulti <- function(x, size = sum(x), prob, log = FALSE) {
  .Call('C_dmulti', as.integer(x), as.integer(size), as.double(prob), as.logical(log))
}

rmulti <- function(n = 1, size, prob) {
  .Call('C_rmulti', as.integer(size), as.double(prob))
}

dcat <- function(x, prob, log = FALSE) {
  .Call('C_dcat', as.integer(x), as.double(prob), as.logical(log))
}

rcat <- function(n = 1, prob) {
  .Call('C_rcat', as.integer(n), as.double(prob))
}

dt_nonstandard <- function(x, df = 1, mu = 0, sigma = 1, log = FALSE) {
  .Call('C_dt_nonstandard', as.double(x), as.double(df), as.double(mu), as.double(sigma), as.logical(log))
}

rt_nonstandard <- function(n, df = 1, mu = 0, sigma = 1) {
  .Call('C_rt_nonstandard', as.integer(n), as.double(mu), as.double(sigma), as.double(df))
}

dmnorm_chol <- function(x, mean, cholesky, prec_param = TRUE, log = FALSE) {
  # cholesky should be upper triangular
  # FIXME: allow cholesky to be lower tri
  .Call('C_dmnorm_chol', as.double(x), as.double(mean), as.double(cholesky), as.logical(prec_param), as.logical(log))
}

rmnorm_chol <- function(n = 1, mean, cholesky, prec_param = TRUE) {
 ## cholesky should be upper triangular
 ## FIXME: allow cholesky to be lower tri
    if(n != 1) warning('rmnorm_chol only handles n = 1 at the moment')
    .Call('C_rmnorm_chol', as.double(mean), as.double(cholesky), as.logical(prec_param))
}
