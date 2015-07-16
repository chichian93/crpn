################################################################################
###
### Replication of Oswiak 2012, "Signing Up for Peace," 
### replacing CINC ratio with DOE scores
###
### Replicating Table 3, Model 3
###
################################################################################

library("caret")
library("dplyr")
library("foreign")
library("MASS")

data_oswiak_2012 <- read.dta("oswiak-2012.dta")
doe_dyad <- read.csv("../R/results-predict-dyad.csv")

## clean spline names
names(data_oswiak_2012)[names(data_oswiak_2012) == "_spline1"] <- "spline1"
names(data_oswiak_2012)[names(data_oswiak_2012) == "_spline2"] <- "spline2"
names(data_oswiak_2012)[names(data_oswiak_2012) == "_spline3"] <- "spline3"

## replication formula
f_oswiak_2012 <- 
  midonset ~ settlem + jtdem6 + majinvolve + atopally + lncincratio + 
  peaceyears + spline1 + spline2 + spline3

## run the reported model
reported_model <- glm(formula = f_oswiak_2012,
                      data = data_oswiak_2012,
                      family = binomial(link = "logit"))

summary(reported_model)
                                           ## coefficients exact

## switch to factor for caret
data_oswiak_2012$midonset <- factor(data_oswiak_2012$midonset,
                                    levels = 0:1,
                                    labels = c("No", "Yes"))

## run the reported model with cross validation
set.seed(90210)
cr_oswiak_2012 <- train(
  f_oswiak_2012,
  data = data_oswiak_2012,
  method = "glm",
  metric = "logLoss",
  trControl = trainControl(
    method = "repeatedcv",
    number = 10,
    repeats = 100,
    returnData = FALSE,
    summaryFunction = mnLogLoss,
    classProbs = TRUE,
    trim = TRUE
  )
)

## Don't save cross-validation indices (takes tons of space with large N)
cr_oswiak_2012$control$index <- NULL
cr_oswiak_2012$control$indexOut <- NULL

prettyNum(coef(cr_oswiak_2012$finalModel))

## merge in the DOE scores and compute pairwise max and min
data_oswiak_2012 <- left_join(data_oswiak_2012,
                                doe_dyad,
                                by = c(ccode1 = "ccode_a",
                                       ccode2 = "ccode_b",
                                       year = "year")) %>%
    mutate(VictoryMax = pmax(VictoryA, VictoryB),
           VictoryMin = pmin(VictoryA, VictoryB))

## DOE in every row
length(which(is.na(data_oswiak_2012$VictoryA)))

## he logs, so we log:
data_oswiak_2012$logVictoryMax <- log(data_oswiak_2012$VictoryMax)
data_oswiak_2012$logVictoryMin <- log(data_oswiak_2012$VictoryMin)

## run it with DOE
set.seed(8032)
doeForm <- update(f_oswiak_2012,
                  . ~ . - lncincratio + logVictoryMax + logVictoryMin)
doe_oswiak_2012 <-  train(
  doeForm,
  data = data_oswiak_2012,
  method = "glm",
  metric = "logLoss",
  trControl = trainControl(
    method = "repeatedcv",
    number = 10,
    repeats = 100,
    returnData = FALSE,
    summaryFunction = mnLogLoss,
    classProbs = TRUE,
    trim = TRUE
  )
)

## Don't save cross-validation indices (takes tons of space with large N)
doe_oswiak_2012$control$index <- NULL
doe_oswiak_2012$control$indexOut <- NULL

prettyNum(coef(doe_oswiak_2012$finalModel))

## save it
save(cr_oswiak_2012,
     doe_oswiak_2012,
     data_oswiak_2012,
     file = "results-oswiak-2012.rda")
