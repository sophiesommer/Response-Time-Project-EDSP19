#load libraries
require(dplyr)
require(ltm)

coursename <- "Money Run 1"
datadir <- "protected_data/"
out_path <- "clean_data/"

# uncomment to run for different courses
# coursename <- "Anatomy Abdomen Run 1"
# coursename <- "Money Run 2"

source("code/Functions/Attemptnumbers.R")
source("code/Functions/Atts1to4.R")
source("code/Functions/GiveUpPercent.R")
source("code/Functions/SimpleAtts.R")

###NOTE: THIS FUNCTION TAKES ~8 MINUTES TO RUN###
#This function creates a data frame where every row represents a particular student's interaction 
#with a particular question. The NumAtts column is then populated as follows:
#NA: Student did not attempt the question
#Positive value: Number of attempts until the student got the correct answer
#Negative value: Number of attempts until the student gave up
#This is saved as Money In Business 1AttNums.csv
AttemptNums(coursename, datadir, out_path) 

###NOTE: THIS FUNCTION TAKES ~2 MINUTES TO RUN###
#This function takes the output from the previous function and uses it to create a matrix where
#rows are students, columns are questions, and values are defined as follows:
#NA: Student did not attempt the question
#1: Student got the question correct on first attempt
#0: Student did not get the question correct on first attempt
#Saved as Money In Business 1simpleatts.csv
SimpleAtts(coursename, out_path, out_path)

###NOTE: THIS FUNCTION TAKES ~AN HOUR TO RUN###
#This function calculates response times on 1st, 2nd, 3rd, and 4th attempts for all questions and students
#this is saved as Money In Business 1AttTimes1to4.csv
Atts1to4(coursename, datadir, out_path) 

###NOTE: THIS FUNCTION TAKES ~2 MINUTES TO RUN###
#This function calculates the percent of opportunities to re-try a question that students used
#If they got all questions correct, so never had additional opportunities to re-try questions, 
#they are recorded as NA
GiveUpPercent(coursename, out_path, out_path)  

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~``

#Load the attempt times matrix
AllAtts <- read.csv(file=paste0(out_path,coursename,"AttTimes1to4.csv"), row.names = 1)

#Update it to include total time and number of attempts for each question
AllAtts$TotalTime <- rowSums(AllAtts[,3:6],na.rm=TRUE)
AllAtts$Atts <- rowSums(!is.na(AllAtts[,3:6]))

#Load the full attempts file 
fullatt <- read.csv(file=paste0(out_path,coursename,"AttNums.csv"), row.names = 1)

#Create a data frame to store question summary
questions <- unique(fullatt$Question)
questionsumm <- data.frame(Question=questions,
                           PropAttemptedQ=rep(NA,length(questions)),
                           PropCorrect1stQ=rep(NA,length(questions)),
                           PropGaveUpQ=rep(NA,length(questions)),
                           PropGaveUpAfterWrongQ=rep(NA,length(questions)),
                           MeanLogTimeAtt1Q=rep(NA,length(questions)))

#Fill in question summary
for(question in questions){
  qatt <- filter(fullatt, Question==question)
  questionsumm$PropAttemptedQ[questionsumm$Question==question] <- sum(!is.na(qatt$NumAtts))/nrow(qatt)
  questionsumm$PropCorrect1stQ[questionsumm$Question==question] <- sum(qatt$NumAtts==1, na.rm=T)/sum(!is.na(qatt$NumAtts))
  questionsumm$PropGaveUpQ[questionsumm$Question==question] <- sum(qatt$NumAtts<0, na.rm=T)/sum(!is.na(qatt$NumAtts))
  questionsumm$PropGaveUpAfterWrongQ[questionsumm$Question==question] <- sum(qatt$NumAtts<0, na.rm=T)/
    sum(qatt$NumAtts!=1, na.rm=T)
  Att1 <- na.omit(AllAtts[AllAtts$Question==question,"Att1_Time"])
  Att1 <- Att1[Att1 <=1000]
  questionsumm$MeanLogTimeAtt1Q[questionsumm$Question==question] <- mean(log(Att1))
}

#load simple attempts matrix and % of extra opportunities used files from above
attmat <- read.csv(file=paste0(out_path,coursename,"simpleatts.csv"), row.names = 1)
giveups <- read.csv(file=paste0(out_path,coursename,"giveup.csv"), row.names = 1)

#Save a new column in the attempts matrix to represent how many questions students attempted
attmat$numattd <- rowSums(!is.na(attmat[,1:length(questions)]))

#Estimate student ability using the attempts matrix and save this information in both the
#attempts matrix and question summary
fit2 <- ltm::rasch(attmat[,1:length(questions)])
scores <- factor.scores(fit2, resp.patterns = attmat[,1:length(questions)])
scores <- scores$score.dat$z1
attmat$scoreRasch <- scores
attmat$scoreRaw <- rowMeans(attmat[,1:length(questions)],na.rm=T)
difficulties <- fit2$coefficients[,1]
questionsumm$difficultyQ <- difficulties

#Save question summary
write.csv(questionsumm, paste0(out_path,coursename,"QuestionSumm.csv"))

#Merge all this new information from the attempts matrix with the attempt times and save as attmat2
attmat$Learner <- rownames(attmat)
attmat2 <- dplyr::left_join(AllAtts, attmat, by = "Learner")
attmat2 <- attmat2[,-c(9:(9+length(questions)-1))]
attmat2 <- dplyr::left_join(attmat2, giveups, by = "Learner")
attmat2 <- dplyr::left_join(attmat2, questionsumm, by = "Question")

#Initialize learner summary
learners <- unique(fullatt$Learner)
learnersumm <- data.frame(Learner=learners,
                          PropAttempted=rep(NA,length(learners)),
                          ScoreRasch=rep(NA,length(learners)),
                          PropCorrect1st=rep(NA,length(learners)),
                          MeanLogTotalTime=rep(NA,length(learners)),
                          MeanLogTimeAtt1=rep(NA,length(learners)))


#Fill in learner summary
for(learner in learners){
  qatt <- filter(attmat2, Learner==learner)
  if(nrow(qatt)>0){
    learnersumm$PropAttempted[learnersumm$Learner==learner] <- qatt$numattd[1]/30
    learnersumm$PropCorrect1st[learnersumm$Learner==learner] <- qatt$scoreRaw[1]
    learnersumm$ScoreRasch[learnersumm$Learner==learner] <- qatt$scoreRasch[1]
    Att1 <- na.omit(qatt$Att1_Time)
    Att1 <- Att1[Att1 <=1000]
    AttTotal <- na.omit(qatt$TotalTime)
    AttTotal <- AttTotal[AttTotal <=1000]
    learnersumm$MeanLogTimeAtt1[learnersumm$Learner==learner] <- mean(log(Att1)) 
    learnersumm$MeanLogTotalTime[learnersumm$Learner==learner] <- mean(log(AttTotal)) 
  }
}
learnersumm <- dplyr::left_join(learnersumm, giveups, by = "Learner")

#Save learner summary
write.csv(learnersumm, paste0(out_path,coursename,"LearnerSumm.csv"))

#Resave attmat2 as attmat3, which eliminates responses that are greater than 2400 seconds
attmat3 <- attmat2[attmat2$TotalTime<2400,]

#Create a score^2 variable
attmat3$scoreRaschSq <- attmat3$scoreRasch * attmat3$scoreRasch

#Save full dataset
write.csv(attmat3, paste0(out_path,coursename,"FinalData.csv"))