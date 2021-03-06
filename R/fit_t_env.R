################################################################################
##                                                                            ##
##                         RPANDA : Climatic-model                            ##
##                                                                            ##
##   Julien Clavel - 01-08-2015                                               ##
##   require: mvMORPH                                                         ##
##                                                                            ##
################################################################################

fit_t_env<-function(phylo, data, env_data, error=NULL, model=c("EnvExp", "EnvLin"), method="Nelder-Mead", control=list(maxit=20000), ...){
    
    ## Use ellipsis for param arguments
    par<-list(...)
    
    ## Parameterization
    if(!is.function(model)){
        model<-model[1]
    }
    
    # reorder the trait vector according to the tree
    if(is.null(names(data))){
        stop("You should provide a named vector for \"data\" ")
    }else{
        data<-data[phylo$tip.label]
    }
    
    # Number of parameters (fixed up to now)
    if(!is.function(model)){
        nparam = 3 # 3 parameters: sig2, beta, mu
    }else{
        nparam = length(par$param)+1 # number of parameters + mu
    }
    
    # Number of taxa
    n = length(phylo$tip.label)
    
    # Check for Box constraints if L-BFGS-B is used
    if(is.null(par[["lower"]]) & is.null(par[["upper"]])){
        par$lower = -Inf
        par$upper = Inf
    }
    
    # Control for the integrate function: number of subdivisions
    if(is.null(par[["subdivisions"]])){
        subdivisions<-200L
    }else{
        subdivisions<-par$subdivisions
    }

    
    # Control options for the optimizer
    # set it to maximize the log-likelihood (allows using the likelihood function in mcmc without inverting the sign)
    control$fnscale=-1
    
    # Reorder the tree
    phylo<-reorder.phylo(phylo,"postorder")
    
    # Compute the branching times
    if(is.ultrametric(phylo)){
        times<-branching.times(phylo)
    }else{
        # Use "phytools" called by mvMORPH
        times<-max(nodeHeights(phylo))-nodeHeights(phylo)[match(1:phylo$Nnode+n,phylo$edge[,1]),1]
        names(times)<-1:phylo$Nnode+n
    }
    
    # Root age
    tot_time<-max(times)
    
    # Set the root to zero
    times<-tot_time-times
    
    # Index of terminal branches for measurement error
    if(!is.null(error)){
      index_error<-sapply(1:n, function(x){ which(phylo$edge[,2]==x)})
      # reorder the trait vector according to the tree
      if(is.null(names(error))){
          stop("You should provide a named vector for \"error\" ")
      }else{
          error<-error[phylo$tip.label]
      }
      is_error<-TRUE
    }else{
      index_error<-NULL
      is_error<-FALSE
    }
    
    ## Transform a time-serie dataset in a function
    
    # Check if the climatic function is provided
    if(is.null(env_data)){
        stop("Please provide a time-function or a time-serie dataset for the environmental changes; see ?fit_t_env")
    }else if(!is.function(env_data)){
        
       # env_data is a dataframe with two columns: 1) is time; 2) is datapoints
       if(is.null(par[["df"]])){
       par$df <- smooth.spline(env_data[,1], env_data[,2])$df
       }
       spline_result <- sm.spline(env_data[,1],env_data[,2], df=par$df)
       env_func <- function(t){predict(spline_result,t)}
       
       # if we don't provide a time step in par we take the time steps of the dataset?
       t<-unique(env_data[,1])
       
       # If the ClimLin model is used we should standardize the environmental curve: i.e. sigma is the maximum rate value.
       # the user can choose by specifying it in the "par" list
       
       if(is.null(par[["scale"]])){
       # We build the interpolated smoothing spline function
           env_data<-splinefun(t,env_func(t))
       }else{
           curve_int<-env_func(t)
           curve_scaled=scale(curve_int,min(curve_int,na.rm=T),max(curve_int, na.rm=T)-min(curve_int,na.rm=T))
           env_data<-splinefun(t,curve_scaled)
       }
       
       # Otherwise we assume that the environnemental function is given
    } 
    
    
    ## Optimization of the log-likelihood
    
    # Starting values for the default models
    if(!is.function(model)){
        # Check if sigma is provided by the user
        if(is.null(par[["sig2"]]) & is.null(par[["param"]])){
            # Use default values
            sigma_guess<-var(data)/tot_time
        }else if(!is.null(par[["sig2"]])){
            sigma_guess<-par$sig2
        }else{
            sigma_guess<-par$param[1]
        }
        
        # Check if beta is provided by the user
        if(is.null(par[["beta"]]) & is.null(par[["param"]])){
            # Use default values
            if(model=="EnvExp"){
                # Set beta = 0; i.e. no effect of the climate
                beta_guess<-0
            }else if(model=="EnvLin"){
                # For the linear-climatic model, the climatic effect vanish when beta=sigma
                beta_guess<-sigma_guess
            }
            
        }else if(!is.null(par[["beta"]])){
            beta_guess<-par$beta
        }else{
            beta_guess<-par$param[2]
        }
    
    # Vector of starting values
    startval<-c(sigma_guess,beta_guess)
    
    }else{
        if(is.null(par[["param"]])){
            stop("Please provide starting values for the parameter search of your model through the \"param\" argument. See ?fit_t_env")
        }
    # Vector of starting values is provided by the user
    startval<-par$param
    }
   
    # Optimization
    #estim<-optim(par=startval,fn=function(x){likelihood_t_env(phylo, data, par=list(param=x, fun=env_data, times=times, mu=NULL, check=FALSE, error=error, index_error=index_error, mtot=tot_time, subdivisions=subdivisions), model)},control=control, hessian=TRUE, method=method, lower=par$lower, upper=par$upper)
     estim<-optim(par=startval,fn=function(x){likelihood_t_env(phylo=phylo, data=data, model=model, param=x, fun=env_data, times=times, mu=NULL, check=FALSE, error=error, index_error=index_error, mtot=tot_time, subdivisions=subdivisions)},control=control, hessian=TRUE, method=method, lower=par$lower, upper=par$upper)
    
    ## Results
    
        # Check the Hessian
        hess<-eigen(-estim$hessian)$values
        
        if(any(hess<0)){
            hess.value<-1
               }else{
            hess.value<-0
        }

    
        # Loglik
        LL = estim$value
        
        # AIC
        AIC = -2*LL+2*nparam
        
        # AICc
        AICc = AIC+((2*nparam*(nparam+1))/(n-nparam-1))
        
  
        
        # Root value function
        return_root<-function(param, mtot, times, fun, model, tips, is_error){
            phylo <- .CLIMtransform(phylo, param=param, mtot=mtot, times=times, funEnv=fun, model=model, tips=tips, subdivisions=subdivisions)
            # Add measurement error
            if(is_error){
                phylo$edge.length[index_error]<-phylo$edge.length[index_error]+error^2 # assume the "se" are provided in the error vector
            }
            root<-mvLL(tree=phylo,data=data,method="pic",param=list(estim=FALSE, check=FALSE, mu=NULL, sigma=1))$theta
            return(root)
        }
        
        # Root
        root<-return_root(estim$par,tot_time,times,env_data,model,n,is_error)
    
    if(is.function(model)){
        # If the model is defined by the user we return a customized result
        results<-list(LH = LL, aic = AIC, aicc = AICc, free.parameters = nparam, param = estim$par, root = root, convergence = estim$convergence, hess.value=hess.value, env_func=env_data, tot_time=tot_time, model=model)
        
    }else if(model=="EnvExp"){
        
        # sig2
        sig2 = exp(estim$par[1])
        
        # beta
        beta = estim$par[2]
        
        # results
        results<-list(LH = LL, aic = AIC, aicc = AICc, free.parameters = nparam, param = c(sig2, beta), root = root, convergence = estim$convergence, hess.value=hess.value, env_func=env_data, tot_time=tot_time, model=model)
        
    }else if(model=="EnvLin"){
        # sig2
        sig2 = exp(estim$par[1])
        
        # beta
        beta = exp(estim$par[2])
        
        # results
        results<-list(LH = LL, aic = AIC, aicc = AICc, free.parameters = nparam, param = c(sig2, beta), root = root, convergence = estim$convergence, hess.value=hess.value, env_func=env_data, tot_time=tot_time, model=model)
    
    }
    
    class(results)<-c("fit_t.env")
    
    return(results)
   
}