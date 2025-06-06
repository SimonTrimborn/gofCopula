# Internal function for the estimation of the margins and the parameter
# estimates
.margins.param.est <- function(copula, margins, x, param, param.est, df, 
                               df.est, dispstr, lower, upper, flip) {
  if (copula == "gaussian") {
warning(
"Please note that the old (pre 0.1-3) term 'gaussian' was replaced with 
'normal'."
)
    copula <- "normal"
  }
  
  if (df.est == TRUE) {
    df.fixed <- FALSE
  } else if (df.est == FALSE) {
    df.fixed <- TRUE
  }
  if (length(margins) > 1 & length(margins) != dim(x)[2]) {
stop(paste(
"If length(margins)>1, then the number of entries has to fit the number of data 
sequences. You included ", length(margins), " distributions, though ", 
dim(x)[2], " data sequences are used. Please amend and run the function again."
))
  }
  if (any(!is.element(margins, c("ranks", "beta", "cauchy", "chisq", "f", 
                                 "gamma", "lnorm", "norm", "t", "weibull", 
                                 "exp")))) {
stop(
"At least one of the distributions in `margins' is not implemented. Please 
amend and run the function again. It has to be either of `ranks', `beta', 
`cauchy', `chisq', `f', `gamma', `lnorm', `norm', `t', `weibull', `exp'."
)
  }

  # estimate margins
  param.margins <- NULL
  if (!is.null(margins)) {
    cat(paste("The margins will be estimated as: ", 
              paste0(margins, collapse = ", "), sep = ""), fill = TRUE)

    res.margins <- .margins(x, margins)
    param.margins <- list()
    if (length(margins) == 1) {
      margins.dummy <- rep(margins, dim(x)[2])
    } else {
      margins.dummy <- margins
    }
    for (i in seq_along(margins.dummy)) {
      if (margins.dummy[i] == "ranks") {
        x[, i] <- res.margins[[i]][[1]]
      } else {
        param.margins[[i]] <- res.margins[[i]][[1]]
        x[, i] <- res.margins[[i]][[2]]
      }
    }
  } else {
    if (any(x > 1) || any(x < 0)) {
cat(
"The observations aren't in [0,1]. This will lead to errors while the 
estimation. Please set 'margins' to any of the incorporated functions.", 
fill = TRUE)
    }
  }
  
  # flip the data when required
  if (!is.null(flip)) {
    if (!is.element(flip, c(0,90,180,270))) {
stop("flip has to be either of NULL, 0, 90, 180, 270.")
      }
    x = .rotateCopula(x = x, flip = flip)
    if (flip == 0) {flip = NULL}
  }

  # estimate the copula parameters with fitCopula from copula package
  # differentiated by copula type
  # maximum likelihood (mpl) sometimes fails, then automatic switch to 
  # inversion of Kendall's tau (itau)
  if ("normal" == copula) {
    if (param.est == TRUE) {
      param <- try(fitCopula(ellipCopula(copula, dim = dim(x)[2], df = df, 
                                         df.fixed = df.fixed, 
                                         dispstr = dispstr), data = x, 
                             method = "mpl", estimate.variance = FALSE, 
                             hideWarnings = TRUE, lower = lower, 
                             upper = upper)@estimate, silent = TRUE)
      estim.method <- "mpl"
      if (inherits(param, "try-error")) {
warning(
"Pseudo Maximum Likelihood estimation of the parameter failed. The estimation 
was performed with inversion of Kendall's Tau."
)
        param <- fitCopula(ellipCopula(copula, dim = dim(x)[2], df = df, 
                                       df.fixed = df.fixed, dispstr = dispstr), 
                           data = x, method = "itau", estimate.variance = FALSE, 
                           hideWarnings = TRUE, lower = lower, 
                           upper = upper)@estimate
        estim.method <- "itau"
      }
    }
    copula <- ellipCopula(copula, param = param, dim = dim(x)[2], df = df, 
                          df.fixed = TRUE, dispstr = dispstr)
    estim.method <- "mpl"
    if (inherits(copula, "indepCopula")) {
stop(
"The parameter estimation is at boundary and an independence copula was 
returned."
)
    }
  } else if ("t" == copula) {
    if (param.est == TRUE) {
      lower.t <- lower
      upper.t <- upper
      if (!is.null(lower) & df.est == TRUE) {
        lower.t <- c(lower, 0)
      }
      if (!is.null(upper) & df.est == TRUE) {
        upper.t <- c(upper, 1000)
      }
      param <- try(fitCopula(ellipCopula(copula, dim = dim(x)[2], df = df, 
                                         df.fixed = df.fixed, 
                                         dispstr = dispstr), data = x, 
                             method = "mpl", estimate.variance = FALSE, 
                             hideWarnings = TRUE, lower = lower.t, 
                             upper = upper.t)@estimate, silent = TRUE)
      estim.method <- "mpl"
      if (inherits(param, "try-error")) {
warning(
"Pseudo Maximum Likelihood estimation of the parameter failed. The estimation 
was performed with inversion of Kendall's Tau. Therefore df.est was set to 
FALSE."
)
        # df no longer needs a lower/upper bound, hence only constrain theta
        param <- fitCopula(ellipCopula(copula, dim = dim(x)[2], df = df, 
                                       df.fixed = TRUE, dispstr = dispstr), 
                           data = x, method = "itau", estimate.variance = FALSE, 
                           hideWarnings = TRUE, lower = lower, 
                           upper = upper)@estimate
        estim.method <- "itau"
        df.fixed <- TRUE
        df.est <- FALSE
      }
    }
    if (copula == "t" & df.fixed == FALSE & param.est == TRUE) {
      df <- tail(param, n = 1)
      copula <- ellipCopula(copula, param = param[-length(param)], 
                            dim = dim(x)[2], df = df, df.fixed = TRUE, 
                            dispstr = dispstr)
      estim.method <- "mpl"
    } else {
      copula <- ellipCopula(copula, param = param, dim = dim(x)[2], df = df, 
                            df.fixed = TRUE, dispstr = dispstr)
      estim.method <- "mpl"
    }
    if (inherits(copula, "indepCopula")) {
stop(
"The parameter estimation is at boundary and an independence copula was 
returned."
)
    }
  } else if ("clayton" == copula || "frank" == copula || "gumbel" == copula ||
    "amh" == copula || "joe" == copula) {
    if (param.est == TRUE) {
      if ("clayton" == copula) {
        param <- try(fitCopula(archmCopula(copula, dim = dim(x)[2]), data = x, 
                               method = "mpl", estimate.variance = FALSE, 
                               hideWarnings = TRUE, lower = lower, 
                               upper = upper)@estimate, silent = TRUE)
        estim.method <- "mpl"
        if (inherits(param, "try-error")) {
warning(
"Pseudo Maximum Likelihood estimation of the parameter failed. The estimation 
was performed with inversion of Kendall's Tau."
)
          param <- fitCopula(archmCopula(copula, dim = dim(x)[2]), data = x, 
                             method = "itau", estimate.variance = FALSE, 
                             hideWarnings = TRUE, lower = lower, 
                             upper = upper)@estimate
          estim.method <- "itau"
        }
      } else {
        param <- try(fitCopula(archmCopula(copula, dim = dim(x)[2]), data = x, 
                               method = "mpl", estimate.variance = FALSE, 
                               hideWarnings = TRUE, lower = lower, 
                               upper = upper)@estimate, silent = TRUE)
        estim.method <- "mpl"
        if (inherits(param, "try-error")) {
warning(
"Pseudo Maximum Likelihood estimation of the parameter failed. The estimation 
was performed with inversion of Kendall's Tau."
)
          param <- fitCopula(archmCopula(copula, dim = dim(x)[2]), data = x, 
                             method = "itau", estimate.variance = FALSE, 
                             hideWarnings = TRUE, lower = lower, 
                             upper = upper)@estimate
          estim.method <- "itau"
        }
      }
    }
    if (copula == "clayton" & param < 0) {
stop(
"The dependence parameter is negative for the dataset. For the clayton copula 
this cannot be the case. Therefore is this not an appropriate copula for the 
dataset. Please consider to use another one."
)
    }
    if (copula == "frank" & dim(x)[2] > 2 & param < 0) {
stop(
"The dependence parameter is negative for the dataset. For the frank copula 
can this be only the case if the dimension is 2. Therefore is this not an 
appropriate copula for the dataset. Please consider to use another one."
)
    }
    copula <- archmCopula(copula, param = param, dim = dim(x)[2])
    estim.method <- "mpl"
    if (inherits(copula, "indepCopula")) {
stop(
"The parameter estimation is at boundary and an independence copula was 
returned."
)
    }
  } else if ("galambos" == copula || "huslerReiss" == copula || 
             "tawn" == copula) {
    if (param.est == TRUE) {
        param <- try(fitCopula(evCopula(copula, dim = dim(x)[2]), data = x, 
                               method = "mpl", estimate.variance = FALSE, 
                               hideWarnings = TRUE, lower = lower, 
                               upper = upper)@estimate, silent = TRUE)
        estim.method <- "mpl"
        if (inherits(param, "try-error")) {
warning(
"Pseudo Maximum Likelihood estimation of the parameter failed. The estimation 
was performed with inversion of Kendall's Tau."
)
          param <- fitCopula(evCopula(copula, dim = dim(x)[2]), data = x, 
                             method = "itau", estimate.variance = FALSE, 
                             hideWarnings = TRUE, lower = lower, 
                             upper = upper)@estimate
          estim.method <- "itau"
        }
    }
    copula <- evCopula(copula, param = param, dim = dim(x)[2])
    estim.method <- "mpl"
    if (inherits(copula, "indepCopula")) {
stop(
"The parameter estimation is at boundary and an independence copula was 
returned."
)
    }
  } else if ("tev" == copula) {
    if (param.est == TRUE) {
      lower.t <- lower
      upper.t <- upper
      if (!is.null(lower) & df.est == TRUE) {
        lower.t <- c(lower, 0)
      }
      if (!is.null(upper) & df.est == TRUE) {
        upper.t <- c(upper, 1000)
      }
      param <- try(fitCopula(evCopula(copula, dim = dim(x)[2], df = df, 
                                      df.fixed = df.fixed), data = x, 
                             method = "mpl", estimate.variance = FALSE, 
                             hideWarnings = TRUE, lower = lower.t, 
                             upper = upper.t)@estimate, silent = TRUE)
      estim.method <- "mpl"
      if (inherits(param, "try-error")) {
warning(
"Pseudo Maximum Likelihood estimation of the parameter failed. The estimation 
was performed with inversion of Kendall's Tau. Therefore df.est was set to 
FALSE."
)
        # df no longer needs a lower/upper bound, hence only constrain theta
        param <- fitCopula(evCopula(copula, dim = dim(x)[2], df = df, 
                                    df.fixed = TRUE), data = x, 
                           method = "itau", estimate.variance = FALSE, 
                           hideWarnings = TRUE, lower = lower, 
                           upper = upper)@estimate
        estim.method <- "itau"
        df.fixed <- TRUE
        df.est <- FALSE
      }
    }
    if (copula == "tev" & df.fixed == FALSE & param.est == TRUE) {
      df <- tail(param, n = 1)
      copula <- evCopula(copula, param = param[-length(param)], 
                         dim = dim(x)[2], df = df, df.fixed = TRUE)
      estim.method <- "mpl"
    } else {
      copula <- evCopula(copula, param = param, dim = dim(x)[2], df = df, 
                         df.fixed = TRUE)
      estim.method <- "mpl"
    }
    if (inherits(copula, "indepCopula")) {
stop(
"The parameter estimation is at boundary and an independence copula was 
returned."
)
    }
  } else if ("fgm" == copula) {
    if (param.est == TRUE) {
      param <- try(fitCopula(fgmCopula(dim = dim(x)[2]), data = x, 
                             method = "mpl", estimate.variance = FALSE, 
                             hideWarnings = TRUE, lower = lower, 
                             upper = upper)@estimate, silent = TRUE)
      estim.method <- "mpl"
      if (inherits(param, "try-error")) {
warning(
"Pseudo Maximum Likelihood estimation of the parameter failed. The estimation 
was performed with inversion of Kendall's Tau."
)
        param <- fitCopula(fgmCopula(dim = dim(x)[2]), data = x, 
                           method = "itau", estimate.variance = FALSE, 
                           hideWarnings = TRUE, lower = lower, 
                           upper = upper)@estimate
        estim.method <- "itau"
      }
    }
    copula <- fgmCopula(param = param, dim = dim(x)[2])
    estim.method <- "mpl"
    if (inherits(copula, "indepCopula")) {
stop(
"The parameter estimation is at boundary and an independence copula was 
returned."
)
    }
  } else if ("plackett" == copula) {
    if (param.est == TRUE) {
      param <- try(fitCopula(plackettCopula(), data = x, method = "mpl", 
                             estimate.variance = FALSE, hideWarnings = TRUE, 
                             lower = lower, upper = upper)@estimate, 
                   silent = TRUE)
      estim.method <- "mpl"
      if (inherits(param, "try-error")) {
warning(
"Pseudo Maximum Likelihood estimation of the parameter failed. The estimation 
was performed with inversion of Kendall's Tau."
)
        param <- fitCopula(plackettCopula(), data = x, method = "itau", 
                           estimate.variance = FALSE, hideWarnings = TRUE, 
                           lower = lower, upper = upper)@estimate
        estim.method <- "itau"
      }
    }
    copula <- plackettCopula(param = param)
    estim.method <- "mpl"
    if (inherits(copula, "indepCopula")) {
stop(
"The parameter estimation is at boundary and an independence copula was 
returned."
)
    }
  }
  
  # interruption of the gof test when detected that the parameter
  # estimates suggest the data do not fit the copula
  if (any(copula@param.lowbnd == copula@parameters || 
          copula@param.upbnd == copula@parameters)) {
stop(
"The provided or estimated copula parameter, performed with the copula package, 
is at its boundary. The copula is excluded from the analysis since this 
leads to very instable results for the GoF tests. Please consider amending the 
parameter or control its estimation via the upper and lower bounds."
)
  }
  
  return(list(copula, x, estim.method, param.margins, df.est, flip))
}
