\name{fit_t_env}
\alias{fit_t_env}

\title{
Maximum likelihood fit of the environmental model of trait evolution
}
\description{
Fits model of trait evolution for which evolutionary rates depends on an environmental function.
}
\usage{

fit_t_env(phylo, data, env_data, error=NULL, model=c("EnvExp", "EnvLin"), 
          method="Nelder-Mead", control=list(maxit=20000), ...)
}
\arguments{
  \item{phylo}{
An object of class 'phylo' (see ape documentation)
}
  \item{data}{
A named vector of phenotypic trait with the same size of the tree.
}
  \item{env_data}{
Environmental data, given as a time continuous function (see, e.g. splinefun) or a data frame with two columns. The first column is time, the second column is the environmental data (temperature for instance).
}
  \item{error}{
A named vector with standard error for each species.
}
  \item{model}{
The model describing the functional form of variation of the evolutionary rate \eqn{\sigma^2} with time and the environmental variable. Default models are "EnvExp" and "EnvLin" (see details). An user defined function of any functional form may be used (forward in time).
This function has three arguments: the first argument is time; the second argument is the environmental variable; the third argument is a numeric vector of the parameters controlling the time and environmental variation (to be estimated). See the example below.
}

  \item{method}{
Methods used by the optimization routine (see ?optim for details).
}
  \item{control}{
Max. bound for the number of iteration of the optimizer; other options can be fixed on the list (see ?optim). 
}

\item{...}{
Arguments to be passed to the function. See details. 
}
}


\value{
	a list with the following components
  
  \item{LH}{the maximum log-likelihood value}
  \item{aic}{the Akaike's Information Criterion}
  \item{aicc}{the size sample corrected Akaike's Information Criterion}
  \item{free.parameters}{the number of estimated parameters}
  \item{param}{a numeric vector of estimated parameters, sigma and beta respectively for the defaults models. In the same order as defined by the user if a     customized model is provided}
  \item{root}{the estimated root value}
  \item{convergence}{convergence status of the optimizing function; "0" indicates convergence (See ?optim for details)}
  \item{hess.value}{reliability of the likelihood estimates calculated through the eigen-decomposition of the hessian matrix. "0" means that a reliable estimate has been reached}
  \item{env_func}{the environmental function}
  \item{tot_time}{the root age of the tree}
  \item{model}{the fitted model (default models or user specified)}
}

\details{
\code{fit_t_env} allows fitting environmental models of trait evolution. 
The default models \emph{EnvExp} and \emph{EnvLin} represents models for which the 
evolutionary rates are changing as a function of environmental changes though times as 
defined below.

\code{EnvExp}:
\deqn{\sigma^2 (t)  =  \sigma_0^2  e^{(\beta T(t))}}{sigma^2(t) = sigma^2 * e^(beta * T(t))}
\code{EnvLin}:
\deqn{\sigma^2 (t)  =  \sigma_0^2 + \beta T(t)}{sigma^2(t) = sigma^2 + beta * T(t)}

Users defined models should have the following form:

\code{fun <- function(t, env, param){ param*env(t)}}

\emph{t}: is the time parameter.

\emph{env}: is a time function of an environmental variable. 
See for instance object created by \code{splinefun} when interpolating coordinate of points.

\emph{param}: is a vector of parameters to estimates.

For instance, the \code{EnvExp} function can be coded as: 

\code{fun <- function(t, env, param){ param[1]*exp(param[2]*env(t))}} 

where \code{param[1]} is the \eqn{\sigma^2} parameter and \code{param[2]} is 
the \eqn{\beta} parameter. 
Note that in this later case, two starting values should be provided in the \code{param} 
argument through the \code{par} list.

e.g.:

\code{sigma=0.1}

\code{beta=0}

\code{fit_t_env(tree, data, env_data=InfTemp, model=fun, par=list(param=c(sigma,beta)))}



The various options are passed through "...". 

-param: The starting values used for the model. The lengths of the "param" argument in the par list is used to compute the total number of parameters for user specified models.

-scale: scale the amplitude of the environmental curve between 0 and 1. This improve the parameters search.

-df: the degree of freedom to use to define the spline. As a default, smooth.spline(env_data[,1], env_data[,2])$df is used. See \emph{sm.spline} for details.

-upper: the upper bound for the parameter search when the "L-BFGS-B" method is used. See \emph{optim} for details.

-lower: the lower bound for the parameter search when the "L-BFGS-B" method is used. See \emph{optim} for details.

-sig2: can be used instead of param to define the starting sigma value only

-beta: can be used instead of param to define the beta starting value only
}

\note{
	The users defined function is evaluated forward in time i.e.: from the root to the tips.
	The speed of convergence of the fit might depend on the degree of freedom chosen to define the spline. 
}
\references{
Clavel, J. & Morlon, H. (in prep) 
}

\author{J. Clavel}

\seealso{
%% add later  \code{\link{sim_t_env}}  
\code{\link{plot.fit_t.env}}, 
\code{\link{likelihood_t_env}}
}

\examples{
data(Cetacea)
data(InfTemp)

# Simulate trait on the Cetacean tree
set.seed(123)

trait <- sim_t_env(Cetacea, param=c(0.1,-0.2), env_data=InfTemp, model="EnvExp", 
					root.value=0, step=0.001, plot=TRUE)

## Fit the Environmental-exponential model
  # Fit the environmental model
  result1=fit_t_env(Cetacea, trait, env_data=InfTemp, scale=TRUE)
  plot(result1)
\donttest{
  # Add to the plot the results from different smoothing of the temperature curve
  result2=fit_t_env(Cetacea, trait, env_data=InfTemp, df=10, scale=TRUE)
  lines(result2, col="red")

  result3=fit_t_env(Cetacea, trait, env_data=InfTemp, df=50, scale=TRUE)
  lines(result3, col="blue")

## Fit the environmental linear model

  fit_t_env(Cetacea, trait, env_data=InfTemp, model="EnvLin", df=50, scale=TRUE)

## Fit user defined model

  # We define the function for the model
  my_fun<-function(t, env_cont, param){ 
      exp(param[1])*exp(param[2]*env_cont(t))
  }
  
  res<-fit_t_env(Cetacea, trait, env_data=InfTemp, model=my_fun, 
                 param=c(0.1,0), scale=TRUE)
  # Retrieve the parameters and compare to 'result1'
  res
  plot(res, col="red")
	

## Fit user defined environmental function

require(pspline)
  	 spline_result <- sm.spline(x=InfTemp[,1],y=InfTemp[,2], df=50)
  	 env_func <- function(t){predict(spline_result,t)}
  	 t<-unique(InfTemp[,1])
  	
  # We build the interpolated smoothing spline function
  	 env_data<-splinefun(t,env_func(t))
  
  # We then fit the model
  	 fit_t_env(Cetacea, trait, env_data=env_data)
  
## Various parameterization (box constraints, df, scaling of the curve...) example
 fit_t_env(Cetacea, trait, env_data=InfTemp, model="EnvLin", method="L-BFGS-B", 
 			scale=TRUE, lower=-30, upper=20, df=10)
 }
}
