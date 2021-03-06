
######################################
## System to label for eigenization ##
######################################

## exprClasses_labelForEigenization 
##
## This works recursively through a parse tree (exprClass object)
## Any expression in which any piece has a size expression (in its exprClass object) that is not all 1s
## will be wrapped in eigenize(). The exception is expressions that have indexing.
##
## e.g. In Y <- t(A) %*% A
## The result of t(A) %*% A might be length 1, but the A and t(A) have size expressions != 1, so this whole line becomes
## eigenize(Y <- t(A) %*% A)
##
## On the other hand, Y <- B[3,4] is not wrapped in eigenize() because, even though B might have non-1 size expressions,
## the exprClass object for `[`(B, 3, 4) has size expressions == list(1, 1)
##
## two kinds of intermediates should have already been pulled out:
## 1. arguments to nimbleFunctions or keywords like return() that ever involve non-scalar-equivalent steps
## 2. nimbleFunctions that return non-scalar-equivalent and are used within a larger expression

exprClasses_labelForEigenization <- function(code) {
    if(code$isCall) {
        if(code$name == '{') {
            for(i in seq_along(code$args)) {
                exprClasses_labelForEigenization(code$args[[i]])
            }
            return(invisible(NULL))
        }
        if(code$name == 'for') {
            exprClasses_labelForEigenization(code$args[[3]])
            return(invisible(NULL))
        }
        if(code$name %in% ifOrWhile) {
            exprClasses_labelForEigenization(code$args[[2]])
            if(length(code$args) == 3) exprClasses_labelForEigenization(code$args[[3]])
            return(invisible(NULL))
        }
                
        if(code$name %in% callToSkipInEigenization) return(invisible(NULL))

        if(length(code$toEigenize) > 0) {
            if(code$toEigenize == 'yes') {
         ##   if(anyNonScalar(code)) {
                output <- insertExprClassLayer(code$caller, code$callerArgID, 'eigenize')
        	return(output)
         ##   }
            }
        }
    }
    invisible(NULL)
}



##############
## Eigenize ##
##############

## EIGEN DOES NOT DO AUTOMATIC TYPE PROMOTION

callsFromExternalUnaries <- as.character(unlist(lapply(eigProxyTranslateExternalUnary, `[`, 1)))

eigenizeCalls <- c( ## component-wise unarys valid for either Eigen array or matrix
    makeCallList(c('abs','square','sqrt','('), 'eigenize_cWiseUnaryEither'),
    makeCallList('pow', 'eigenize_cWiseByScalarArray'),
                   makeCallList(c('asRow', 'asCol'), 'eigenize_asRowOrCol'),
                      ## component-wise unarys valid only for only Eigen array
                   makeCallList(c('exp','log','cube','cwiseInverse','sin','cos','tan','asin','acos', callsFromExternalUnaries), 'eigenize_cWiseUnaryArray'), 
                   
                   ## component-wise binarys valid for either Eigen array or matrix, but the arguments must match
                   ## Check on which if any of these can extend to a scalar on one side
                   makeCallList(c('pmin','pmax'), 'eigenize_cWiseBinaryArray'),

                   ## component-wise multiplication or division
                   makeCallList(c('*','/'), 'eigenize_cWiseMultDiv'),
                   
                   ## component-wise addition or subtraction
                   makeCallList(c('+','-'), 'eigenize_cWiseAddSub'),

                   makeCallList(reductionUnaryOperatorsEither, 'eigenize_reductionEither'), ##'eigenize_cWiseUnaryEither'),
                   makeCallList(reductionUnaryOperatorsArray, 'eigenize_reductionArray'),
                   makeCallList(reductionBinaryOperatorsEither, 'eigenize_reductionBinaryEither'),
                   makeCallList(c('%*%'), 'eigenize_cWiseBinaryMatrix'),
                      ## matrix ops
                   list('t' = 'eigenize_cWiseUnaryEither',
                        'inverse' = 'eigenize_cWiseUnaryMatrix',
                        'chol' = 'eigenize_chol')
                   )

eigenizeCallsBeforeRecursing <- c( ## These cannot be calls that trigger aliasRisk.
    makeCallList(c('size','nimArr_dmnorm_chol', 'nimArr_dwish_chol', 'nimArr_ddirch'), 'eigenize_doNotRecurse'),
    list(nfVar = 'eigenize_nfVar',
         chainedCall = 'eigenize_chainedCall',
         '<-' = 'eigenize_assign_before_recurse',
         mvAccessRow = 'eigenize_nfVar') )

## This is a list of translations for the C++ code generation system.
## e.g. if abs(X) gets eigenized, it is turned into cwiseAbs(X)
## which in nimGenerateCpp is generated as X.cwiseAbs()
eigenizeTranslate <- list(abs = 'cwiseAbs',
                       square = 'cwiseAbs2',
                       sqrt = 'cwiseSqrt',
                          inprod = 'eiginprod',
                          
                       asRow = 'eigBlank',
                       asCol = 'eigBlank',
                       
                          exp = 'eigExp',
                          log = 'eigLog',
                          pow = 'eigPow',
                          cube = 'eigCube',
                          cwiseInverse = 'cwiseInverse',
                          sin = 'eigSin',
                          cos = 'eigCos',
                          tan = 'eigTan',
                          asin = 'eigAsin',
                          acos = 'eigAcos',
                          inverse = 'eigInverse',

                       pmin = 'eigpmin',
                       pmax = 'eigpmax',

                       '*' = 'cwiseProduct', ## detailed handling in eigenize_cWiseMultDiv
                       '/' = 'cwiseQuotient',
                       
                       '+' = '+',
                       '-' = '-',

                       ## matrix operations
                       '%*%' = '*',
                       't' = 'eigTranspose',
                          'det' = 'eigDeterminant',
                       
                       '<-' = '<-',
                       '(' = '('
                       )

ETentriesFromExternalUnaries <- as.list(names(eigProxyTranslateExternalUnary))
names(ETentriesFromExternalUnaries) <- callsFromExternalUnaries
eigenizeTranslate <- c(eigenizeTranslate, ETentriesFromExternalUnaries)

for(rop in reductionUnaryOperators) eigenizeTranslate[[rop]] <- paste0('eig', rop)
for(rop in matrixSquareReductionOperators) eigenizeTranslate[[rop]] <- paste0('eig', rop)

## scalar*matrix, matrix*scalar and matrix/scalar allowed
## ditter with matrix *= scalar and matrix /= scalar
## scalar+matrix and scalar-matrix NOT allowed

## arrays CANNOT do scalar*matrix (or maybe they can?) but CAN do scalar+matrix

## arrays have cWise min and max

## lists we need:
## cWiseUnaryArrayOnly
## cWiseUnaryEither
## cWiseBinaryArrayOnly
## cWiseBinaryMatrixOnly
## cWiseBinaryEither


## exprClasses_eigenize
##
## This does several things:
## Generate Eigen map (and other) vars
## Identify slices and handle them correctly in maps (not done yet)
## Add EigMatrix() and EigArray() transformations
## Handle special treatment for eigen() and chol() and [forward]solve()
## Watch out for aliasing
##
## Return object is a list of setup expressions, which are then emplaced before the calling line in a new `{` expression
## The setup expressions typically create the eigen maps needed
##
## First: set it up to handle one RHS line
## Put new objects in the typeEnv
## Return the type setup calls (the "new in place" notation)
exprClasses_eigenize <- function(code, symTab, typeEnv, workEnv = new.env()) {
    setupExprs <- list()
    if(code$isName) {
        ## Generate EigenMap and "new" assignment
        setupExprs <- c(setupExprs, eigenizeName(code, symTab, typeEnv, workEnv))
    }
    if(code$isCall) {
        if(code$name == '{') {
            for(i in seq_along(code$args)) {
                recurse <- FALSE
                if(code$args[[i]]$name == 'eigenize') {
                    removeExprClassLayer(code$args[[i]]) ## strip the eigenize()
                    recurse <- TRUE
                }
                if(code$args[[i]]$name %in% c('for', ifOrWhile, '{')) recurse <- TRUE
                if(recurse) {
                    setupCalls <- unlist(exprClasses_eigenize(code$args[[i]], symTab, typeEnv, workEnv = new.env())) ## a new line
                    if(length(setupCalls) > 0) {
                        newExpr <- newBracketExpr(args = c(setupCalls, code$args[[i]]))
                        setArg(code, i, newExpr)
                    }
                }
            }
            return(invisible(NULL))
        }
        if(code$name == 'for') {exprClasses_eigenize(code$args[[3]], symTab, typeEnv); return(invisible(NULL))}
        if(code$name %in% ifOrWhile) {
            exprClasses_eigenize(code$args[[2]], symTab, typeEnv)
            if(length(code$args)==3) exprClasses_eigenize(code$args[[3]], symTab, typeEnv)
            return(NULL)
        }
        if(code$name == 'map') {
            ## Generate EigenMap and new assignment with strides
            setupExprs <- c(setupExprs, eigenizeNameStrided(code, symTab, typeEnv, workEnv))
            return(setupExprs)
        }
        if(code$name == '[') { ## If there is still A[i] in the code, it is because it ces to a scalar and does not need eigenization
            if(code$nDim == 0) {
##                writeLines(paste0('Not eigenizing ', nimDeparse(code)))
                return(NULL)
            } else {
                writeLines(paste0('Warning, in eigenizing ',nimDeparse(code), ' the [ is still there but nDim is not 0 (not a scalar).') )
            }
        }
        
        eCall <- eigenizeCallsBeforeRecursing[[code$name]] ## previous cases can be absorbed into this.  This allows catching expressions that evaluate to something numeric, like nfVar(nf, 'x')
        if(!is.null(eCall)) {
            setupExprs <- c(setupExprs, eval(call(eCall, code, symTab, typeEnv, workEnv)))
            return(if(length(setupExprs) == 0) NULL else setupExprs)
        }

        IsetAliasRisk <- FALSE
        if(code$name %in% c('t', 'asRow')) {IsetAliasRisk <- workEnv[['aliasRisk']] <- TRUE}
        
        for(i in seq_along(code$args)) {
            if(inherits(code$args[[i]], 'exprClass'))
                setupExprs <- c(setupExprs, exprClasses_eigenize(code$args[[i]], symTab, typeEnv, workEnv))
        }
        ## finally, call any special handlers
        eCall <- eigenizeCalls[[code$name]]
                
        if(!is.null(eCall)) {
            setupExprs <- c(setupExprs, eval(call(eCall, code, symTab, typeEnv, workEnv)))
        }
        
        if(IsetAliasRisk) workEnv[['aliasRisk']] <- NULL
    }
    return(if(length(setupExprs) == 0) NULL else setupExprs)
}

eigenize_doNotRecurse <- function(code, symTab, typeEnv, workEnv) {
    invisible(NULL)
}

## eigenizeHandlers
eigenize_asRowOrCol <- function(code, symTab, typeEnv, workEnv) {
    code$eigMatrix <- code$args[[1]]$eigMatrix
    if(code$args[[1]]$isName | code$args[[1]]$name == 'map') {
        code$name <- eigenizeTranslate[[code$name]] ## should be eigBlank
        return(invisible(NULL))
    }
    if(code$name == 'asRow') {
        code$name <- eigenizeTranslate[['t']]
    } else {
        code$name <- eigenizeTranslate[['asCol']]
    }
    invisible(NULL)
}

## This is for inprod
## It is same as eigenize_cWiseBinaryEitherMatch except that it does not bail if nDim == 0
eigenize_reductionBinaryEither <- function(code, symTab, typeEnv, workEnv) {
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
##    makeEigenArgsMatch(code)
##    for(i in 1:2) 
##        if(code$args[[i]]$eigMatrix) eigenizeArrayize(code$args[[i]])

    invisible(NULL)
}

eigenize_reductionEither <- function(code, symTab, typeEnv, workEnv) {
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
##    code$eigMatrix <- code$args[[1]]$eigMatrix
    invisible(NULL)
}

eigenize_reductionArray <- function(code, symTab, typeEnv, workEnv) {
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
##    code$eigMatrix <- code$args[[1]]$eigMatrix
    if(length(code$args[[1]]$eigMatrix) == 0) stop(paste0("Trying it eigenize ", nimDeparse(code), " but information from the argument is not complete."), call. = FALSE)
    if(code$args[[1]]$eigMatrix) eigenizeArrayize(code$args[[1]])
    invisible(NULL)
}

eigenize_cWiseUnaryEither <- function(code, symTab, typeEnv, workEnv) {
    if(code$nDim == 0) return(NULL)
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
    code$eigMatrix <- code$args[[1]]$eigMatrix
    invisible(NULL)
}

eigenize_assign_before_recurse <- function(code, symTab, typeEnv, workEnv) {
    setupExprs <- list()
    if(length(code$args) != 2) stop(paste0('There is an assignment without 2 arguments'))
    workEnv$OnLHSnow <- TRUE
    setupExprs <- c(setupExprs, exprClasses_eigenize(code$args[[1]], symTab, typeEnv, workEnv))
    workEnv$OnLHSnow <- NULL ## allows workEnv[['OnLHSnow']] to be NULL if is does not exist or if set to NULL
    setupExprs <- c(setupExprs, exprClasses_eigenize(code$args[[2]], symTab, typeEnv, workEnv))

    if(!is.null(workEnv[['mustAddEigenEval']])) insertExprClassLayer(code, 2, 'eigEval')
    
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
    code$eigMatrix <- code$args[[1]]$eigMatrix
    setupExprs
}

## eigenize_assign <- function(code, symTab, typeEnv, workEnv) {
##     newName <- eigenizeTranslate[[code$name]]
##     if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
##     code$name <- newName
##     code$eigMatrix <- code$args[[1]]$eigMatrix
##     invisible(NULL)
## }

eigenize_chol <- function(code, symTab, typeEnv, workEnv) {
    if(!code$args[[1]]$eigMatrix) eigenizeMatricize(code$args[[1]])
    code$eigMatrix <- TRUE
    code$name <- 'matrixU' ## replace 'chol' by 'matrixU'
    insertExprClassLayer(code, 1, 'llt', eigMatrix = TRUE, nDim = code$nDim, sizeExprs = code$sizeExprs, type = code$type) ## insert llt 
    invisible(NULL)
}

eigenize_cWiseUnaryArray <- function(code, symTab, typeEnv, workEnv) {
    if(code$nDim == 0) return(NULL)
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
    code$eigMatrix <- FALSE
    if(length(code$args[[1]]$eigMatrix) == 0) stop(paste0("Trying it eigenize ", nimDeparse(code), " but information from the argument is not complete."), call. = FALSE)
    if(code$args[[1]]$eigMatrix) eigenizeArrayize(code$args[[1]])
    invisible(NULL)
}

eigenize_cWiseUnaryMatrix <- function(code, symTab, typeEnv, workEnv) {
    if(code$nDim == 0) return(NULL)
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
    code$eigMatrix <- TRUE
    if(!code$args[[1]]$eigMatrix) eigenizeMatricize(code$args[[1]])
    invisible(NULL)
}

makeEigenArgsMatch <- function(code) {
    if(xor(code$args[[1]]$eigMatrix, code$args[[2]]$eigMatrix)) {
        ## default to matrix:
        if(!code$args[[1]]$eigMatrix)
            eigenizeMatricize(code$args[[1]])
        else
            eigenizeMatricize(code$args[[2]])
    }
}

eigenize_cWiseBinaryEitherMatch <- function(code, symTab, typeEnv, workEnv) {
    if(code$nDim == 0) return(NULL)
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
    makeEigenArgsMatch(code)
    code$eigMatrix <- code$args[[1]]$eigMatrix
	invisible(NULL)
}


eigenize_cWiseBinaryArray <- function(code, symTab, typeEnv, workEnv) {
    if(code$nDim == 0) return(NULL)
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
    code$eigMatrix <- TRUE
    if(code$args[[1]]$eigMatrix) eigenizeArrayize(code$args[[1]])
    if(code$args[[2]]$eigMatrix) eigenizeArrayize(code$args[[2]])
    invisible(NULL)
}

eigenize_cWiseByScalarArray <- function(code, symTab, typeEnv, workEnv) {
    if(code$nDim == 0) return(NULL)
    if(!is.numeric(code$args[[2]]))
        if(code$args[[2]]$nDim != 0) stop(paste0('Error, the second argument to pow must be a scalar in ', nimDeparse(code)))
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
    code$eigMatrix <- FALSE
    if(code$args[[1]]$eigMatrix) eigenizeArrayize(code$args[[1]])
    invisible(NULL)
}

eigenize_cWiseBinaryMatrix <- function(code, symTab, typeEnv, workEnv) {
    if(code$nDim == 0) return(NULL)
    newName <- eigenizeTranslate[[code$name]]
    if(is.null(newName)) stop(paste0('Error, missing eigenizeTranslate entry for ', code$name,' in ', nimDeparse(code)))
    code$name <- newName
    code$eigMatrix <- TRUE
    if(!code$args[[1]]$eigMatrix) eigenizeMatricize(code$args[[1]])
    if(!code$args[[2]]$eigMatrix) eigenizeMatricize(code$args[[2]])
    invisible(NULL)
}

isEigScalar <- function(code) {
    if(is.numeric(code)) return(TRUE)
    return(length(code$eigMatrix) == 0)
}

eigenize_cWiseMultDiv <- function(code, symTab, typeEnv, workEnv) {
    ## first see if one or both arguments are scalar
    scalar1 <- isEigScalar(code$args[[1]])
    scalar2 <- isEigScalar(code$args[[2]]) 
 
    if(scalar1 | scalar2) {
        if(scalar1 & scalar2) return(invisible(NULL))
        if(code$name == '*' | scalar2) {
            code$eigMatrix <- if(scalar1) code$args[[2]]$eigMatrix else code$args[[1]]$eigMatrix
            return(invisible(NULL))
        }
        ## for an Eig object in denominator, require an array
        eigenizeArrayize(code$args[[2]])
        code$eigMatrix <- FALSE
        return(invisible(NULL))
    }
    ## Both arguments are Eigen:
    eigenize_cWiseBinaryEitherMatch(code, symTab, typeEnv, workEnv)
}


eigenize_cWiseAddSub <- function(code, symTab, typeEnv, workEnv) {
    ## first see if one argument is scalar
    if(length(code$args)==1) return(eigenize_cWiseUnaryEither(code, symTab, typeEnv, workEnv))
    
    if(isEigScalar(code$args[[1]]) | isEigScalar(code$args[[2]])) {
        for(i in 1:2) { 
            if(!isEigScalar(code$args[[i]])) { 
                if(code$args[[i]]$eigMatrix) eigenizeArrayize(code$args[[i]])
                code$eigMatrix <- FALSE ## if both are scalar, this will remain UNSET, indicating scalar
            }
        }
        return(invisible(NULL))
    }
    ## Both arguments are Eigen:
    eigenize_cWiseBinaryEitherMatch(code, symTab, typeEnv, workEnv)
}

eigenizeArrayize <- function(code) {
    newExpr <- exprClass(name = 'eigArray', args = list(code), eigMatrix = FALSE,
                         isName = FALSE, isCall = TRUE, isAssign = FALSE,
                         nDim = code$nDim, sizeExprs = code$sizeExprs, type = code$type,
                         caller = code$caller, callerArgID = code$callerArgID)
    setArg(code$caller, code$callerArgID, newExpr)
    setCaller(code, newExpr, 1)
    invisible(NULL)
}

eigenizeMatricize <- function(code) {
    newExpr <- exprClass(name = 'eigMatrix', args = list(code), eigMatrix = TRUE,
                         isName = FALSE, isCall = TRUE, isAssign = FALSE,
                         nDim = code$nDim, sizeExprs = code$sizeExprs, type = code$type,
                         caller = code$caller, callerArgID = code$callerArgID)
    setArg(code$caller, code$callerArgID, newExpr)
    setCaller(code, newExpr, 1)
    invisible(NULL)
}

## handler issues for eigenizing:
## 

EigenNewExpr <- function(EigenName, targetName, offsetExpr = NULL, MatrixType, nrowExpr, ncolExpr, strides = NULL) {
    targetExpr <- substitute(getPtr(A), list(A = if(is.character(targetName)) as.name(targetName) else targetName))
    if(!is.null(offsetExpr)) {
        targetExpr <- substitute(A + chainedCall(template(static_cast, int), B), list(A = targetExpr, B = offsetExpr))
    }
    if(is.null(strides)) {
        template <- quote(AssignEigenMap(EIGENNAME, TARGETNAME, MT, NRE, NCE)) ## Later the type of MAPNAME will allow filling in the nrow and ncol
        return(codeSubstitute(template, list(EIGENNAME = as.name(EigenName), TARGETNAME = targetExpr,
                                             MT = as.name(MatrixType), NRE = nrowExpr, NCE = ncolExpr )))
    } else {
        template <- quote(AssignEigenMap(EIGENNAME, TARGETNAME, MT, NRE, NCE, S1, S2))
        return(codeSubstitute(template, list(EIGENNAME = as.name(EigenName), TARGETNAME = targetExpr,
                                             MT = as.name(MatrixType), NRE = nrowExpr, NCE = ncolExpr,
                                             S1 = strides[[1]], S2 = strides[[2]]))) ## not sure what strides will look like yet
    }
    
    ## eventual C++ code will be new (&EigenName) Map<MatrixType, stride<Dynamic, Dynamic>>(&NimArrName, nrow, ncol, stride<Dynamic, Dynamic>(rowStride, colStride))
}

makeEigenName <- function(name) paste0('Eig_',name)

makeEigenTypeLabel <- function(Matrix = TRUE, baseType = 'double') {
    paste0(if(Matrix) 'MatrixX' else 'ArrayXX', if(baseType == 'double') 'd' else 'i')
}

eigenize_chainedCall <- function(code, symTab, typeEnv, workEnv) {
    if(code$nDim == 0) return(NULL)
    warning(paste0('Problem in eigenize_chainedCall for ', nimDeparse(code), '. nDim != 0, so this expression should have been lifted prior to eigenization.'))
    NULL
}

eigenize_nfVar <- function(code, symTab, typeEnv, workEnv) { ## A lot like eigenizeName.  Makes the map.  These could be combined
    EigenName <- Rname2CppName(makeEigenName(nimDeparse(code)))
    if(code$nDim == 0) return(NULL) ## it is a scalar
    targetTypeSizeExprs <- code$sizeExprs

    if(length(targetTypeSizeExprs) > 2) {stop('Error, cannot eigenize a map of dimensions > 2')}
    if(length(targetTypeSizeExprs) == 2) {
        nrowExpr <- targetTypeSizeExprs[[1]]
        ncolExpr <- targetTypeSizeExprs[[2]]
    }
    if(length(targetTypeSizeExprs) == 1) {
        if(code$caller$name == 'asRow') {
            nrowExpr <- 1
            ncolExpr <- targetTypeSizeExprs[[1]]
            EigenName <- paste0(EigenName,'_asRow')
        } else {
            ## default to column
            nrowExpr <- targetTypeSizeExprs[[1]]
            ncolExpr <- 1
        }
    }

    targetVarProxy <- EigenName ## don't have a more direct targetVar - a little redundant but keeps the code similar to eigenizeName and eigenizeNameStrided
    thisMapAlreadySet <- FALSE
    if(!is.null(workEnv[['OnLHSnow']])) { ## this is the var on the LHS
        if(!is.null(workEnv[['LHSeigenName']])) stop(paste0('Error for ', code$name, '. LHSeigenName already exists'), call. = FALSE)
        workEnv$LHSeigenName <- list(EigenName = EigenName, targetVar = targetVarProxy)
        workEnv[[EigenName]] <- TRUE
    } else { ## This is on the RHS
        if(EigenName %in% ls(workEnv) ) {
            thisMapAlreadySet <- TRUE
        } else {
            workEnv[[EigenName]] <- TRUE
        }
        if(!is.null(workEnv[['LHSeigenName']])) { ## There was a LHS (there may not be for nimPrint(x), for example)
            alreadyAliased <- !is.null(workEnv[['mustAddEigenEval']])
            if(!alreadyAliased) {
                aliasRisk <- !is.null(workEnv[['aliasRisk']])
                if(targetVarProxy == workEnv[['LHSeigenName']]$targetVar) { ## this uses the same targetVar as the LHS
                    if(aliasRisk || EigenName != workEnv[['LHSeigenName']]$EigenName) {
                        workEnv[['mustAddEigenEval']] <- TRUE
                    }
                }
            }
        }
    }
   
    
    ## Later we must look up to caller and see if it is asRow or asCol
    if(!symTab$symbolExists(EigenName, TRUE)) {
        if(thisMapAlreadySet) warning(paste0('Weird, it looks like an Eigen map for ', targetVarProxy, 'was already set but the symbol did not exist.'), call. = FALSE)
        newSym <- symbolEigenMap(name = EigenName,
                                 eigMatrix = TRUE, ## default to matrix
                                 type = code$type,
                                 strides = numeric())
        symTab$addSymbol(newSym)
    }
    code$eigMatrix <- TRUE

    deparsedCode <- parse(text = nimDeparse(code), keep.source = FALSE)[[1]]
    setArg(code$caller, code$callerArgID, RparseTree2ExprClasses(as.name(EigenName)))

    if(!thisMapAlreadySet) {
        return(RparseTree2ExprClasses(
            EigenNewExpr(EigenName, deparsedCode, NULL, makeEigenTypeLabel(TRUE, code$type),
                         nrowExpr, ncolExpr, strides = NULL))
           )
    } else {
        return(NULL)
    }
}

eigenizeName <- function(code, symTab, typeEnv, workEnv) {
    targetSym <- symTab$getSymbolObject(code$name, TRUE)
    if(!exists('nDim', envir = targetSym, inherits = FALSE)) {
        stop(paste0('Error in eigenizeName for ', nimDeparse(code), '. Symbol does not have an nDim.'))
    }
    if(targetSym$nDim == 0) return(NULL) ## it is a scalar

    EigenName <- Rname2CppName(makeEigenName(code$name))
    needStrides <- !is.null(typeEnv$passedArgumentNames[[code$name]])

    if(needStrides) {
        newArgs <- list()
        newArgs[[1]] <- code$name
        newArgs[[2]] <- code$nDim ## not used but for completeness
        newArgs[[3]] <- quote(0) ## eigenizeNameStrided will insert getOffset(ptr)
        newArgs[[4]] <- code$sizeExprs
        newArgs[[5]] <- makeStrideRexprs(as.name(code$name), code$nDim)
        oldArgs <- code$args
        code$args <- newArgs ## This will show an error if displayed via code$show, but it's ok for temporary use
        ans <- eigenizeNameStrided(code, symTab, typeEnv, workEnv)
        code$args <- oldArgs
        return(ans)
    }
    
    if(!identical(as.integer(targetSym$nDim), as.integer(code$nDim))) { writeLines('found a case where !identical(targetSym$nDim, code$nDim)'); browser() }
    if(!identical(targetSym$type, code$type)) { writeLines('found a case where !identical(targetSym$type, code$type)'); browser() }
    if(!identical(targetSym$name, code$name)) { writeLines('found a case where !identical(targetSym$name, code$name)'); browser() }
    ##targetType <- get(code$name, envir = typeEnv, inherits = FALSE) ## Turns out this is not the right thing if names have been re-used!
    targetTypeSizeExprs <- code$sizeExprs

    if(length(targetTypeSizeExprs) > 2) {stop('Error, cannot eigenize a map of dimensions > 2')}
    if(length(targetTypeSizeExprs) == 2) {
        nrowExpr <- targetTypeSizeExprs[[1]]
        ncolExpr <- targetTypeSizeExprs[[2]]
    }
    if(length(targetTypeSizeExprs) == 1) {
        if(code$caller$name == 'asRow') {
            nrowExpr <- 1
            ncolExpr <- targetTypeSizeExprs[[1]]
            EigenName <- paste0(EigenName,'_asRow')
        } else {
            ## default to column
            nrowExpr <- targetTypeSizeExprs[[1]]
            ncolExpr <- 1
        }
    }

    thisMapAlreadySet <- FALSE
    if(!is.null(workEnv[['OnLHSnow']])) { ## this is the var on the LHS
        if(!is.null(workEnv[['LHSeigenName']])) stop(paste0('Error for ', code$name, '. LHSeigenName already exists'), call. = FALSE)
        workEnv$LHSeigenName <- list(EigenName = EigenName, targetVar = code$name)
        workEnv[[EigenName]] <- TRUE
    } else { ## This is on the RHS
        if(EigenName %in% ls(workEnv) ) {
            thisMapAlreadySet <- TRUE
        } else {
            workEnv[[EigenName]] <- TRUE
        }
        if(!is.null(workEnv[['LHSeigenName']])) { ## There was a LHS (there may not be for nimPrint(x), for example)
            alreadyAliased <- !is.null(workEnv[['mustAddEigenEval']])
            if(!alreadyAliased) {
                aliasRisk <- !is.null(workEnv[['aliasRisk']])
                if(code$name == workEnv[['LHSeigenName']]$targetVar) { ## this uses the same targetVar as the LHS
                    if(aliasRisk || EigenName != workEnv[['LHSeigenName']]$EigenName) {
                        workEnv[['mustAddEigenEval']] <- TRUE
                    }
                }
            }
        }
    }
    
    ## Later we must look up to caller and see if it is asRow or asCol
    if(!symTab$symbolExists(EigenName, TRUE)) {
        if(thisMapAlreadySet) warning(paste0('Weird, it looks like an Eigen map for ', code$name, 'was already set but the symbol did not exist.'), call. = FALSE)
        newSym <- symbolEigenMap(name = EigenName,
                                 eigMatrix = TRUE, ## default to matrix
                                 type = targetSym$type,
                                 strides = numeric())
        symTab$addSymbol(newSym)
    }
    
    code$eigMatrix <- TRUE
    code$name <- EigenName

    if(!thisMapAlreadySet) {
        return(RparseTree2ExprClasses(
            EigenNewExpr(EigenName, targetSym$name, NULL, makeEigenTypeLabel(TRUE, targetSym$type),
                         nrowExpr, ncolExpr, strides = NULL))
               )
    } else {
        return(NULL)
    }
}
