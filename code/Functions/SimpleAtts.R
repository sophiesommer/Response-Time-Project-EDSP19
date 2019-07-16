###Getting response matrix: 1 for correct on first try, 0 otherwise

SimpleAtts <- function(coursename, datadir, out_path){
  require(dplyr)
  datafile <- paste0(datadir,coursename,"AttNums.csv")
  fullatt <- read.csv(file=datafile, row.names = 1)
  
  questions <- unique(fullatt$Question)
  questions <- questions[order(questions)]
  
  learners <- unique(fullatt$Learner)
  
  attmat <- matrix(NA,ncol=length(questions),nrow=length(learners))
  colnames(attmat) <- questions
  row.names(attmat) <- learners
  attmat <- as.data.frame(attmat)
  for(question in questions){
    for(learner in learners){
      natt <- fullatt[fullatt$Learner==learner & fullatt$Question==question,"NumAtts"]
      if(!is.na(natt)){
        if(natt == 1){
          attmat[learner,as.character(question)] <- 1
        }
        else{
          attmat[learner,as.character(question)] <- 0
        }
      }
    }
  }
  
  write.csv(attmat, paste0(out_path,coursename,"simpleatts.csv"))
  
}

