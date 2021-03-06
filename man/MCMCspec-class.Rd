% Generated by roxygen2 (4.0.1): do not edit by hand
\docType{class}
\name{MCMCspec-class}
\alias{MCMCspec}
\alias{MCMCspec-class}
\alias{addMonitors}
\alias{addMonitors2}
\alias{addSampler}
\alias{configureMCMC}
\alias{getMonitors}
\alias{getSamplers}
\alias{removeSamplers}
\alias{resetMonitors}
\alias{setSamplers}
\alias{setThin}
\alias{setThin2}
\title{Class \code{MCMCspec}}
\description{
Objects of this class fully specify an MCMC algorithm,
specific to a particular model. Given an object spec of
class MCMCspec, the actual MCMC function may subsequently
be built by calling buildMCMC(spec). See documentation for
method initialize() or configureMCMC(), for details of
creating an MCMCspec object.
}
\section{Methods}{

\describe{
\item{\code{addMonitors(vars, ind = 1, print = TRUE)}}{Adds variables to the list of monitors.

Arguments:

vars: A character vector of indexed nodes, or variables, which are to be monitored.  These are added onto the current monitors list.

print: A boolean variable, specifying whether to print all current monitors.

Details: See the initialize() function
            }

\item{\code{addMonitors2(vars, print = TRUE)}}{Adds variables to the list of monitors2.

Arguments:

vars: A character vector of indexed nodes, or variables, which are to be monitored.  These are added onto the current monitors2 list.

print: A boolean variable, specifying whether to print all current monitors.

Details: See the initialize() function
            }

\item{\code{addSampler(type, control = list(), print = TRUE)}}{Adds a sampler to the list of samplers contained in the MCMCspec object.

Arguments:

type: The type of sampler to add.  If type='newSamplerType', then sampler_newSamplertype must correspond to a nimbleFunction generator.  Otherwise an error results.

control: A list of control arguments for sampler_newSamplertype.
These will override the defaults contained in the 'controlDefaultList' object, and any specified in the control list argument to configureMCMC().
An error results if sampler_newSamplertype requires any control elements which are 
not present in this argument, the control list argument to configureMCMC(), or in the 'controlDefaultList' object.

print: Boolean argument, specifying whether to print the details of the newly added sampler, as well as its position in the list of MCMC samplers.

Details: A single instance of the newly specified sampler is added to the end of the list of samplers for this MCMCspec object.}

\item{\code{getMonitors()}}{Prints all current monitors and monitors2

Details: See the initialize() function
            }

\item{\code{getSamplers(ind)}}{Prints details of the MCMC samplers.

Arguments:

ind: A numeric vector, specifying the indices of the samplers to print.  If omitted, then all samplers are printed.
This is generally the intended usage, to see all current samplers in the MCMCspec object.}

\item{\code{initialize(model, nodes, control = list(), monitors, thin = 1,
  monitors2 = character(), thin2 = 1, useConjugacy = TRUE,
  onlyRW = FALSE, onlySlice = FALSE, multivariateNodesAsScalars = FALSE,
  print = FALSE)}}{Creates a defaut MCMC specification for a given model.  The resulting object is suitable as an argument to buildMCMC().

Arguments:

model: A NIMBLE model object, created from nimbleModel(...)

nodes: An optional character vector, specifying the nodes for which samplers should be created.
Nodes may be specified in their indexed form, 'y[1, 3]', or nodes specified without indexing will be expanded fully, e.g., 'x' will be expanded to 'x[1]', 'x[2]', etc.
If missing, the default value is all non-data stochastic nodes.
If NULL, then no samplers are added.

control: An optional list of control arguments to sampler functions.  If a control list is provided, the elements will be provided to all sampler functions which utilize the named elements given.
For example, the standard Metropolis-Hastings random walk sampler (sampler_RW) utilizes control list elements 'adaptive', 'adaptInterval', 'scale', 
and also 'targetNode' however this should not generally be provided as a control list element to configureMCMC().
The default values for control list arguments for samplers (if not otherwise provided as an argument to configureMCMC() ) are contained in the 'controlDefaultList' object.

monitors: A character vector of node names or variable names, to record during MCMC sampling.
This set of monitors will be recorded with thinning interval 'thin', and the samples will be stored into the 'mvSamples' object.
The default value is all top-level stochastic nodes of the model -- those having no stochastic parent nodes.

monitors2: A character vector of node names or variable names, to record during MCMC sampling.
This set of monitors will be recorded with thinning interval 'thin2', and the samples will be stored into the 'mvSamples2' object.
The default value is an empty character vector, i.e. no values will be recorded.

thin: The thinning interval for 'monitors'.  Default value is one.

thin2: The thinning interval for 'monitors2'.  Default value is one.

useConjugacy: A boolean argument, with default value TRUE.  If specified as FALSE, then no conjugate samplers will be used, even when a node is determined to be in a conjugate relationship.

onlyRW: A boolean argument, with default value FALSE.  If specified as TRUE, then Metropolis-Hastings random walk samplers (sampler_RW) will be assigned for all non-terminal continuous-valued nodes nodes.
Discrete-valued nodes are assigned a slice sampler (sampler_slice), and terminal (predictive) nodes are assigned an end sampler (sampler_end).

onlySlice: A boolean argument, with default value FALSE.  If specified as TRUE, then a slice sampler is assigned for all non-terminal nodes.
Terminal (predictive) nodes are still assigned an end sampler (sampler_end).

multivariateNodesAsScalars: A boolean argument, with default value FALSE.  If specified as TRUE, then non-terminal multivariate stochastic nodes will have scalar samplers assigned to each of the scalar components of the multivariate node.  The default value of FALSE results in a single block sampler assigned to the entire multivariate node.  Note, multivariate nodes appearing in conjugate relationships will be assigned the corresponding conjugate sampler (provided useConjugacy == TRUE), regardless of the value of this argument.

print: Boolean argument, specifying whether to print the ordered list of default samplers.}

\item{\code{removeSamplers(ind, print = TRUE)}}{Removes one or more samplers from an MCMCspec object.

Arguments:

ind: A numeric vector, giving the indices of the samplers to be removed.  If omitted, then all samplers are removed.

print: Boolean argument, default value TRUE, specifying whether to print the current list of samplers once the removal has been done.}

\item{\code{resetMonitors()}}{Resets the current monitors and monitors2 lists to nothing.

Details: See the initialize() function
            }

\item{\code{setSamplers(ind, print = TRUE)}}{Sets the ordering of the list of MCMC samplers.

Arguments:

ind: A numeric vector, specifying the new list of MCMC samplers, in terms of the current ordered list of samplers.
For example, if the MCMCspec object currently has 3 samplers, then the ordering may be reversed by calling mcmcspec$setSamplers(3:1),
the list may be changed to only calling the first sampler 3 times, then the remaining two samplers by calling mcmcspec$setSamplers(c(1, 1, 1, 2, 3)),
or all samplers may be removed by calling mcmcspec$setSamplers(numeric(0)).

print: Boolean argument, default value TRUE, specifying whether to print the new list of samplers.}

\item{\code{setThin(thin, print = TRUE)}}{Sets the value of thin.

Arguments:

thin: The new value for the thinning interval 'thin'.

print: A boolean variable, specifying whether to print all current monitors.

Details: See the initialize() function
            }

\item{\code{setThin2(thin2, print = TRUE)}}{Sets the value of thin2.

Arguments:

thin2: The new value for the thinning interval 'thin2'.

print: A boolean variable, specifying whether to print all current monitors.

Details: See the initialize() function
            }
}}
\examples{
code <- nimbleCode({
 mu ~ dnorm(0, 1)
 x ~ dnorm(mu, 1)
})
Rmodel <- nimbleModel(code)
spec <- configureMCMC(Rmodel)
spec$setSamplers(1)
spec$addSampler(type = 'slice', control = list(targetNode = 'x'))
spec$addMonitors('mu', thin = 1)
spec$addMonitors2('x', thin2 = 10)
spec$getMonitors()
spec$getSamplers()
}
\author{
Daniel Turek
}

