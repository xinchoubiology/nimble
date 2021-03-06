## CASE 1: nodeFunctionVector
## simulate(model, nodes) becomes:
## model_nodes <- nodeFunctionVector(model, nodes)
## simulate(model_nodes)
## model_nodes$getNodeFunctions() returns a list of the nfRefClassObjets underlying the nodeFunctions

nodeFunctionVector <- setRefClass(
    Class = 'nodeFunctionVector',
    fields = list(model = 'ANY',
               	   gids = 'ANY'),
               #   nodes = 'ANY'),
               #   nodeFunctionRefClassObjects = 'ANY'),
    methods = list(
        initialize = function(model, nodeNames, excludeData = FALSE, env = parent.frame()) {
            model <<- model
            if(length(nodeNames) == 0)
            	gids <<- numeric(0)
            else{
	            if(is.numeric(nodeNames))		#In case we start with graph ids instead of names
 		           	temp_gids <- unique( sort(nodeNames) )
    	        else
    	        	temp_gids <- unique( sort(model$modelDef$nodeName2GraphIDs(nodeNames)))
    	        if(excludeData == TRUE)
    	        	temp_gids <- temp_gids[!model$isDataFromGraphID(temp_gids)]
    	        gids <<- temp_gids
    	        }
        },
        getNodeNames = function(){
        	model$expandNodeNames(gids)	
        },
        show = function() cat(paste0('nodeFunctionVector: ', paste(nodes, collapse=', '), '\n'))
    )
)

getNodeFxnPtrs <- function(cModel){	
    lapply( cModel$nodes, `[[`, '.basePtr' )
    ## output <- list()
    ## rNodeFxnVecNames = names(cModel$nodes)						
    ## for(vN in rNodeFxnVecNames){
    ##     output[[vN]] <- cModel$nodes[[vN]]$.basePtr		
    ## }
    ## return(output)
}
