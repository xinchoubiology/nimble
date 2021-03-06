% Generated by roxygen2 (4.0.1): do not edit by hand
\name{nimCopy}
\alias{nimCopy}
\title{Copying function for NIMBLE}
\usage{
nimCopy(from, to, nodes, nodesTo = NA, row = NA, rowTo = NA,
  logProb = FALSE)
}
\arguments{
  \item{from}{Either a NIMBLE model or modelValues object}

  \item{to}{Either a NIMBLE model or modelValues object}

  \item{nodes}{The nodes of object \code{from} which will
  be copied from}

  \item{nodesTo}{The nodes of object \code{to} which will
  be copied to. If \code{nodesTo == NA}, will automatically
  be set to \code{nodes}}

  \item{row}{If \code{from} is a modelValues, the row which
  will be copied from}

  \item{rowTo}{If \code{to} is a modelValues, the row which
  will be copied to. If \code{rowTo == NA}, will
  automatically be set to \code{row}}

  \item{logProb}{A logical value indicating whether the log
  probabilities of the given nodes should also be copied
  (i.e. if \code{nodes = 'x'} and \code{logProb = TRUE},
  then both \code{'x'} and \code{'logProb_x'} will be
  copied)}
}
\description{
Copies values from a NIMBLE model or modelValues object to
another NIMBLE model or modelValues. Work in R and NIMBLE.
The NIMBLE keyword \code{copy} is identical to
\code{nimCopy}
}
\details{
See the User Manual for more details
}
\examples{
# Building model and modelValues object
simpleModelCode <- nimbleCode({
	for(i in 1:100)
		x[i] ~ dnorm(0,1)
})
rModel <- nimbleModel(simpleModelCode)
rModelValues <- modelValues(rModel)

#Setting model nodes
rModel$x <- rnorm(100)
#Using nimCopy in R.
nimCopy(from = rModel, to = rModelValues, nodes = 'x', rowTo = 1)

#Use of nimCopy in a simple nimbleFunction
cCopyGen <- nimbleFunction(
	setup = function(model, modelValues, nodeNames){},
	run = function(){
		nimCopy(from = model, to = modelValues, nodes = nodeNames, rowTo = 1)
	}
)

rCopy <- cCopyGen(rModel, rModelValues, 'x')
cModel <- compileNimble(rModel)
cCopy <- compileNimble(rCopy, project = rModel)
cModel[['x']] <- rnorm(100)

cCopy() ## execute the copy with the compiled function
}
\author{
Clifford Anderson-Bergman
}

