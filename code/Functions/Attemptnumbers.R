AttemptNums <- function(coursename, datadir, out_path){
  require(dplyr)
  
  # check and load data
  # note: need to subset first so that all courses used have these files
  in_path <- paste0(datadir,coursename,"/")
  quizfile <- grep("question-response.csv",dir(path=in_path), value = T)
  peoplefile <- grep("enrolments.csv",dir(path=in_path), value = T)
  
  
  # save data from folder
  scores <- read.csv(paste0(in_path, quizfile), stringsAsFactors = FALSE)
  people <- read.csv(paste0(in_path, peoplefile), stringsAsFactors = FALSE)
  
  
  # save IDs and re-code correct vs incorrect
  IDs <- unique(scores$learner_id)
  scores$correct[scores$correct=="true"] <- 1
  scores$correct[scores$correct=="false"] <- 0
  
  
  #convert dates/times to POSIXct format (so they can be ordered)
  scores$submitted_at <- as.POSIXct(scores$submitted_at)
  
  # quiz_questions have the form W.S.Q, e.g., 1.12.4 for 
  # Week 1 Step 12 Question 4
  # To remap this to 011204   
  scores$newnames <- scores$quiz_question %>% 
    strsplit(., "[.]") %>%  
    sapply(., FUN=function(a){sprintf("%02s", a)}) %>%
    apply(., 2, FUN=function(a){paste(a, collapse="")})
  
  
  #arrange scores by ID, question, and time
  scores <- arrange(scores, learner_id, newnames, submitted_at)
  
  
  # save learners and unique question IDs
  learners <- IDs
  questions <- unique(scores$newnames)
  
  # initialize data frame to collect times
  lq <- length(learners)*length(questions)
  attsmat <- data.frame(Learner=rep(learners, each=length(questions)),
                         Question=rep(questions, times=length(learners)), 
                         NumAtts = rep(NA,lq))
  
  
  # get start times for question 1 of a step activity
  for (question in questions){
    for (learner in learners){
      atts <- filter(scores, learner_id==learner, newnames==question)
      natts <- nrow(atts)
      if(natts>0){
        evercorrect <- any(atts[,"correct"]==1)
        if(evercorrect==FALSE){
          attsmat[attsmat$Learner==learner & attsmat$Question==question,"NumAtts"] <- -1*natts
        }
        else if(evercorrect==TRUE){
          firstcorrect <- which.max(atts$correct)
          atts <- atts[1:firstcorrect,]
          natts <- nrow(atts)
          attsmat[attsmat$Learner==learner & attsmat$Question==question,"NumAtts"] <- natts
        }
      }
    }  
  }
  
  
  
  
  #write files
  write.csv(attsmat, paste0(out_path,coursename,"AttNums.csv"))
}
