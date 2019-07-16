###Getting response matrix: 1 for correct on first try, 0 otherwise

GiveUpPercent <- function(coursename, datadir, out_path){
  require(dplyr)
  datafile <- paste0(datadir,coursename,"AttNums.csv")
  fullatt <- read.csv(file=datafile, row.names = 1)
  
  questions <- unique(fullatt$Question)
  questions <- questions[order(questions)]
  
  learners <- unique(fullatt$Learner)
  
  giveup <- data.frame(Learner=learners, 
                      Opportunities=rep(0,length(learners)),
                      UsedOpportunities=rep(0,length(learners)))

  for(learner in learners){
    for(question in questions){
      value <- fullatt[fullatt$Learner==learner & fullatt$Question==question,"NumAtts"]
      if(!is.na(value)){
        if(value>1){
          opps <- value-1
          used <- opps
          giveup[giveup$Learner==learner,"Opportunities"] <- 
            giveup[giveup$Learner==learner,"Opportunities"]+opps
          giveup[giveup$Learner==learner,"UsedOpportunities"] <- 
            giveup[giveup$Learner==learner,"UsedOpportunities"]+used
        }
        else if(value<0){
          opps <- abs(value)
          used <- opps-1
          giveup[giveup$Learner==learner,"Opportunities"] <- 
            giveup[giveup$Learner==learner,"Opportunities"]+opps
          giveup[giveup$Learner==learner,"UsedOpportunities"] <- 
            giveup[giveup$Learner==learner,"UsedOpportunities"]+used
        }
      }
    }
  }
  giveup$PropUsedOpp <- NA
  for(i in 1:nrow(giveup)){
    if (giveup$Opportunities[i]!=0){
      giveup$PropUsedOpp[i] <- giveup$UsedOpportunities[i]/giveup$Opportunities[i]
    }
  }

  giveup <- giveup[,c(1,4)]
  
  write.csv(giveup, paste0(out_path,coursename,"GiveUp.csv"))
  
}

