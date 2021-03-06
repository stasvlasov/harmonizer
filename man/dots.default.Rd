% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/harmonizer.r
\name{dots.default}
\alias{dots.default}
\title{If no argument \code{arg.name} is provided in ... (dots) then use \code{arg.val} as new default. Otherwise use value specified in ... (dots) by user.}
\usage{
dots.default(
  arg.name,
  arg.val,
  env = parent.frame(),
  dots = eval(expression(list(...)), envir = env)
)
}
\arguments{
\item{arg.name}{Name of argument in dots to update defaults}

\item{arg.val}{New default value}

\item{env}{Do not set. This function needs its calling environment.}

\item{dots}{Do not set. This function needs ... (dots) values of calling}
}
\value{
Updated value for dots argument.
}
\description{
If no argument \code{arg.name} is provided in ... (dots) then use \code{arg.val} as new default. Otherwise use value specified in ... (dots) by user.
}
