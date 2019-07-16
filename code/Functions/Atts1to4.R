Atts1to4 <- function(coursename, datadir, out_path){
  require(dplyr)
  
  # check and load data
  # note: need to subset first so that all courses used have these files
  in_path <- paste0(datadir,coursename,"/")
  quizfile <- grep("question-response.csv",dir(path=in_path), value = T)
  peoplefile <- grep("enrolments.csv",dir(path=in_path), value = T)
  stepfile <- grep("step-activity.csv",dir(path=in_path), value = T)
  
  
  # save data from folder
  scores <- read.csv(paste0(in_path, quizfile), stringsAsFactors = FALSE)
  people <- read.csv(paste0(in_path, peoplefile), stringsAsFactors = FALSE)
  steps <- read.csv(paste0(in_path, stepfile), stringsAsFactors = FALSE)
  
  
  # save IDs and re-code correct vs incorrect
  IDs <- unique(scores$learner_id)
  scores$correct[scores$correct=="true"] <- 1
  scores$correct[scores$correct=="false"] <- 0
  
  #this was due to missing data in Anatomy 1
  errs <- which(steps$first_visited_at=="")
  steps <- steps[-errs,]
  
  #convert dates/times to POSIXct format (so they can be ordered)
  scores$submitted_at <- as.POSIXct(scores$submitted_at)
  steps$first_visited_at <- as.POSIXct(steps$first_visited_at)
  
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
  timesmat <- data.frame(Learner=rep(learners, each=length(questions)),
                         Question=rep(questions, times=length(learners)), 
                         Start=rep(NA,lq),
                         Att1 = rep(NA,lq), 
                         Att2 = rep(NA,lq), 
                         Att3 = rep(NA,lq),
                         Att4 = rep(NA,lq),
                         Last = rep(NA,lq))
  
  #add week, step, and question numbers
  timesmat$Week_num <- NA
  timesmat$Step_num <- NA
  timesmat$Question_num <- NA
  for(i in 1:lq){
    q <- as.character(timesmat$Question[i])
    timesmat$Week_num[i] <- strsplit(q, "(?<=.{2})", perl = TRUE)[[1]][1]
    timesmat$Step_num[i] <- strsplit(q, "(?<=.{2})", perl = TRUE)[[1]][2]
    timesmat$Question_num[i] <- strsplit(q, "(?<=.{2})", perl = TRUE)[[1]][3]
  }
  timesmat$Week_num <- as.numeric(timesmat$Week_num)
  timesmat$Step_num <- as.numeric(timesmat$Step_num)
  timesmat$Question_num <- as.numeric(timesmat$Question_num)
  
  # get start times for question 1 of a step activity
  for (question in questions){
    for (learner in learners){
      timesmat_section <- filter(timesmat, Learner==learner, Question==question)
      wknum <-  timesmat_section$Week_num
      stepnum <- timesmat_section$Step_num
      qnum <- timesmat_section$Question_num
      if(qnum==1){
        steptime <- filter(steps, learner_id==learner, week_number==wknum, step_number==stepnum)
        if(nrow(steptime)==1){
          timesmat[timesmat$Learner==learner & timesmat$Question==question,]$Start <- 
            as.POSIXct(steptime$first_visited_at)
        }
      }
    }  
  }
  
  
  #fill in last time student worked on a question
  for (question in questions){
    for (learner in learners){
      atts <- filter(scores, learner_id==learner, newnames==question)
      if(nrow(atts)>0){
        timesmat[timesmat$Learner==learner & timesmat$Question==question,]$Last <- 
          atts$submitted_at[nrow(atts)]
      }
    }  
  }
  
  #use last times to fill in first times where possible
  for (question in questions){
    for (learner in learners){
      qnum <- as.numeric(strsplit(as.character(question), "(?<=.{2})", perl = TRUE)[[1]][3])
      if(qnum != 1){
        wknum <- strsplit(as.character(question), "(?<=.{2})", perl = TRUE)[[1]][1]
        stepnum <- strsplit(as.character(question), "(?<=.{2})", perl = TRUE)[[1]][2]
        qnum <- qnum - 1
        qnum <- sprintf("%02s", qnum)
        prevq <- paste0(wknum,stepnum,qnum)
        lasttime <- timesmat[timesmat$Learner==learner & timesmat$Question==prevq,]$Last
        if(!is.na(lasttime)){
          timesmat[timesmat$Learner==learner & timesmat$Question==question,]$Start <- lasttime
        }
      }
    }  
  }
  
  # fill in submit times for 1st, 2nd, 3rd, and 4th attempts
  for (question in questions){
    for (learner in learners){
      atts <- filter(scores, learner_id==learner, newnames==question)
      natts <- nrow(atts)
      if(natts>0){
        timesmat[timesmat$Learner==learner & timesmat$Question==question,]$Att1 <- 
          atts$submitted_at[1]
        if(natts>1 & atts$correct[1]!=1){
          timesmat[timesmat$Learner==learner & timesmat$Question==question,]$Att2 <- 
            atts$submitted_at[2]
          if(natts>2 & atts$correct[2]!=1){
            timesmat[timesmat$Learner==learner & timesmat$Question==question,]$Att3 <- 
              atts$submitted_at[3]
            if(natts>3 & atts$correct[3]!=1){
              timesmat[timesmat$Learner==learner & timesmat$Question==question,]$Att4 <- 
                atts$submitted_at[4]
            }
          }
        }
      }
    }  
  }
  
  #subset to learners for whom we have at least a start and end time recorded
  AttTimes1to4 <- timesmat[!is.na(timesmat$Start) & !is.na(timesmat$Last),]
  AttTimes1to4$Att1_Time <- NA
  AttTimes1to4$Att2_Time <- NA
  AttTimes1to4$Att3_Time <- NA
  AttTimes1to4$Att4_Time <- NA
  
  learnersub <- unique(AttTimes1to4$Learner)
  
  #get actual attempt times
  for(learner in learnersub){
    for (question in questions){
      AttTimes1to4_row <- AttTimes1to4[AttTimes1to4$Learner==learner & AttTimes1to4$Question==question,]
      check <- nrow(AttTimes1to4_row)
      if(check != 0){
        if(!is.na(AttTimes1to4_row$Att1)){
          AttTimes1to4[AttTimes1to4$Learner==learner & AttTimes1to4$Question==question,"Att1_Time"] <- 
            AttTimes1to4_row$Att1 - AttTimes1to4_row$Start
          if(!is.na(AttTimes1to4_row$Att2)){
            AttTimes1to4[AttTimes1to4$Learner==learner & AttTimes1to4$Question==question,"Att2_Time"] <- 
              AttTimes1to4_row$Att2 - AttTimes1to4_row$Att1
            if(!is.na(AttTimes1to4_row$Att3)){
              AttTimes1to4[AttTimes1to4$Learner==learner & AttTimes1to4$Question==question,"Att3_Time"] <- 
                AttTimes1to4_row$Att3 - AttTimes1to4_row$Att2
              if(!is.na(AttTimes1to4_row$Att4)){
                AttTimes1to4[AttTimes1to4$Learner==learner & AttTimes1to4$Question==question,"Att4_Time"] <- 
                  AttTimes1to4_row$Att4 - AttTimes1to4_row$Att3
              }
            }
          }
        }
      }
    }
  }
  
  #subset to just the data that makes sense
  AttTimes1to4_sub <- AttTimes1to4
  AttTimes1to4_sub <- AttTimes1to4_sub[,c(1,2,12:15)]
  AttTimes1to4_sub <- AttTimes1to4_sub[AttTimes1to4_sub$Att1_Time>0,]
  
  
  #write files
  write.csv(timesmat, paste0(out_path,coursename,"Atts1to4.csv"))
  write.csv(AttTimes1to4_sub, paste0(out_path,coursename,"AttTimes1to4.csv"))
}
