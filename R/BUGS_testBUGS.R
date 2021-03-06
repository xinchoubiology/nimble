# BUGS_testBUGS.R
# infrastructure code for nimble testing; it uses readBUGSmodel() for the heavy lifting of reading in the model information

# May 2014 (revised June 2014)
# Chris Paciorek

#' Tests BUGS examples in the NIMBLE system
#'
#' \code{testBUGSmodel} builds a BUGS model in the NIMBLE system and simulates from the model, comparing the values of the nodes and their log probabilities in the uncompiled and compiled versions of the model
#'
#' @param example (optional) example character vector indicating name of BUGS example to test; can be null if \code{model} is provided
#' @param dir (optional) character vector indicating directory in which files are contained, by default the classic-bugs directory if the installed package is used; to use the current working directory, set this to ""
#' @param model (optional) one of (1) a character string giving the file name containing the BUGS model code, (2) an R function whose body is the BUGS model code, or (3) the output of \code{nimbleCode}. If a file name, the file can contain a 'var' block and 'data' block in the manner of the JAGS versions of the BUGS examples but should not contain references to other input data files nor a const block. The '.bug' or '.txt' extension can be excluded.
#' @param data (optional) one of (1) character string giving the file name for an R file providing the input constants and data as R code [assigning individual objects or as a named list] or (2) a named list providing the input constants and data. If neither is provided, the function will look for a file named \code{example}-data including extensions .R, .r, or .txt.
#' @param inits (optional) (1) character string giving the file name for an R file providing the initial values for parameters as R code [assigning individual objects or as a named list] or (2) a named list providing the values. If neither is provided, the function will look for a file named \code{example}-init or \code{example}-inits including extensions .R, .r, or .txt. 
#' @param withInits boolean indicating whether to test model with initial values provided via \code{inits}
#' @author Christopher Paciorek
#' @details
#' Note that testing without initial values may cause warnings when parameters are sampled from improper or fat-tailed distributions
#' @export
#' @examples
#' testBUGSmodel('pump')
testBUGSmodel <- function(example = NULL, dir = NULL, model = NULL, data = NULL, inits = NULL, useInits = TRUE, debug = FALSE) {
  if(require(testthat)) { # should this be imported in NAMESPACE even if its only a suggests?

    if(!is.null(example) && !is.character(example))
      stop("testBUGSmodel: 'example' argument should be a character vector referring to an existing BUGS example or NULL if provided via the 'model' argument")
    context(paste0("testing for BUGS example: ", example))
    
    if(is.null(dir)) {

      if(is.null(example))
        stop("testBUGSmodel: 'example' is not provided; if not using an example from the BUGS manual examples, set 'dir' to \"\"")
      examplesDir <- system.file("classic-bugs", package = "nimble")
      
      if(file.exists(file.path(examplesDir, 'vol1', example))) {
        vol <- 1
      } else if(file.exists(file.path(examplesDir, 'vol2', example))) {
        vol <- 2
      } else {
        stop(paste0("Example: ", example, " not found in Classic BUGS examples; to use your current working directory or if passing inputs as R objects, set 'dir' to be \"\""))
      }
      cat("Using example in BUGS example directory of the NIMBLE package.\n")   
      dir <- file.path(examplesDir, paste0('vol', vol), example)
    }
    
    if(is.null(model)) model <- example 
    
    if(is.null(model))
      stop("testBUGSmodel: one of 'example' or 'model' must be provided")
    
    Rmodel <- readBUGSmodel(model = model, data = data, inits = inits, dir = dir, useInits = useInits, debug = debug)
    
    if(useInits) {
                                        # kludgey as this code is in readBUGSmodel() but no nice way to get it out if I want readBUGSmodel to return the R model; one possibility is to have the inits be embedded in the R model...
      initsFile <- NULL
      if(is.character(inits)) {
        initsFile <- file.path(dir, inits)
        if(!file.exists(initsFile)) 
          stop("testBUGSmodel: 'inits' input does not reference an existing file.")
      }
      if(is.null(inits)) {
        modelName <- gsub("\\..*", "", model)
        possibleNames <- c(
                           file.path(dir, paste0(modelName, "-init.R")),
                           file.path(dir, paste0(modelName, "-inits.R")),
                           file.path(dir, paste0(modelName, "-init.txt")),
                           file.path(dir, paste0(modelName, "-inits.txt")),
                           file.path(dir, paste0(modelName, "-init")),
                           file.path(dir, paste0(modelName, "-inits")))
        if(!Sys.info()['sysname'] %in% c("Darwin", "Windows")) # UNIX-like is case-sensitive
          possibleNames <- c(possibleNames,
                             file.path(dir, paste0(modelName, "-init.r")),
                             file.path(dir, paste0(modelName, "-inits.r")))
        fileExistence <- file.exists(possibleNames)
        if(!sum(fileExistence)) {
          stop("testBUGSmodel: 'inits' argument does not reference an existing file.")
        } else {
          if(sum(fileExistence) > 1)
            stop("testBUGSmodel: multiple possible initial value files; please pass as explicit 'inits' argument.")
          initsFile <- possibleNames[which(fileExistence)[1]]
        }
      }
      if(!is.null(initsFile)) {
        inits <- new.env()
        source(initsFile, inits)
        inits <- as.list(inits)
      }
    }
    if(useInits && is.null(inits))
      warning("testBUGSmodel: 'useInits' is TRUE but 'inits' is NULL and could not find file of initial values in directory provided; proceeding without initial values.")  
                                        # for C model
##    Cmodel <- compileBUGSmodel(Rmodel)
    project <- nimbleProjectClass(NULL, name = 'foo')
    Cmodel <- compileNimble(Rmodel, project = project)
                                        # topo-sorted nodes
    nodeNames <- Rmodel$getNodeNames()
    detNodeNames <- Rmodel$getNodeNames(determOnly = TRUE)
                                        #varNames <- Rmodel$getVarNames()
    
    set.seed(0)
                                        # simulate/calculate in topological order
    for(nodeName in nodeNames) {
      varName <- gsub("\\[.*\\]", "", nodeName)
      if(!(varName %in% names(inits)) && !Rmodel$isData(nodeName))  # only if not initialized and not data node
        simulate(Rmodel, nodeName)
      if(!(nodeName %in% detNodeNames && varName %in% names(inits))) # don't overwrite det nodes that have init values
        calculate(Rmodel, nodeName)
    }
    
    set.seed(0)
    for(nodeName in nodeNames) {
      varName <- gsub("\\[.*\\]", "", nodeName)
      if(!(varName %in% names(inits)) && !Rmodel$isData(nodeName))   # only if not initialized and not data node
        simulate(Cmodel, nodeName)
      if(!(nodeName %in% detNodeNames && varName %in% names(inits))) # don't overwrite det nodes that have init values
        calculate(Cmodel, nodeName)
    }
                                        # test that vals are maintained at their initial values
    if(!is.null(inits)) {
      test_that(paste0(example, ": test of the test: are initial values maintained?"), {
        varNames <- names(inits)[names(inits) %in% Rmodel$getVarNames()]
        for(varName in varNames) {
          Rvals <- Rmodel[[varName]][!Rmodel$isData(varName)]
          Cvals <- Cmodel[[varName]][!Rmodel$isData(varName)]
          initsVals <- inits[[varName]][!Rmodel$isData(varName)]
          attributes(Rvals) <- attributes(Cvals) <- attributes(initsVals) <- NULL
          expect_that(Rvals, equals(initsVals), info = paste0('Initial value not maintained in R model for variable ', varName))
          expect_that(Cvals, equals(initsVals), info = paste0('Initial value not maintained in C model for variable ', varName))
        }
      })
    }
                                        # test that vals and logprobs are equal
    test_that(paste0(example, ": test of variable values"), {
      for(nodeName in nodeNames) {
          Rvals <- Rmodel[[nodeName]]
          Cvals <- Cmodel[[nodeName]]
          attributes(Rvals) <- attributes(Cvals) <- NULL        
        expect_that(Rvals, equals(Cvals), info = paste0('Unexpected result for variable ', nodeName))
      }
    })
    test_that(paste0(example, ": test of logProbs"), {
      for(nodeName in nodeNames)  {
        Rvals <- getLogProb(Rmodel, nodeName)
        Cvals <- getLogProb(Cmodel, nodeName)
        attributes(Rvals) <- attributes(Cvals) <- NULL        
        expect_that(Rvals, equals(Cvals), info = paste0('Unexpected result for variable ', nodeName))
      }
    })

    # dyn.unload(project$cppProjects[[1]]$getSOName())
    # this works to avoid having too many DLLs, but gives segfault when one quits R afterwards
    if(debug) browser()
  } else warning("testBUGSmodel: testthat package is required")
}

