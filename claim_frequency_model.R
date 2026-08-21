# Load the foreign package so we can read .arff files
# Load the ggplot2 package so we can draw plots
library(foreign)
library(ggplot2)
# Load the French motor insurance data set 
data <- read.arff("freMTPL2freq.arff")

# Check overall structure and column names in the dataset
str(data)

# Check the distribution of claims - expect positive skew (mostly zeros)
table(data$ClaimNb)

# Try and get a rough trend using just age 
aggregate(ClaimNb ~ DrivAge, data = data, FUN = mean)

# To see sample size
table(data$DrivAge)
 # Since sample size beyond 85 gets small, claim rates there are unreliable

# Plot to show average number of claims by age
AvgClaimNb <- aggregate(ClaimNb ~ DrivAge, data = data, FUN = mean)

ggplot(AvgClaimNb, aes(x = DrivAge, y = ClaimNb)) +
  geom_line()+
  scale_x_continuous(limits = c(18, 85), breaks = seq(20, 85, by = 5)) +
  scale_y_continuous(limits = c(0, 0.1), breaks = seq(0, 0.1, by = 0.01))+
  labs(
    title = "Average Claim Frequency by Driver Age",
    x = "Driver Age",
    y= "Average Claims per policy"
  )
      
# Check for overdispersion, to see if the Poisson constant - rate assumption holds
mean(data$ClaimNb)
var(data$ClaimNb)

# GLM model using a Poisson distribution to predict claim frequency 
model <- glm(
  ClaimNb ~ DrivAge + BonusMalus + Region,
  offset = log(Exposure),
  family = poisson(link = "log"),
  data = data 
)

# View coefficients to interpret each predictor's effect on claim frequency 
summary(model)

# Find average driving scores by age
aggregate(BonusMalus ~ DrivAge, data = data, FUN = mean)


# Use the model to estimate claim frequency comparing younger vs older driver
young_driver <- data.frame(
  DrivAge = 18, 
  BonusMalus = 93,
  Region = "R24",
  Exposure = 1 
)
older_driver <- data.frame(
  DrivAge = 50, 
  BonusMalus = 54.1,
  Region = "R24",
  Exposure = 1 
)
predict(model, newdata = young_driver, type = "response")
predict(model, newdata = older_driver, type = "response") 

# Split age into bands so it is treated as a factor than a continuous slope 
data$AgeBand <- cut(
  data$DrivAge,
  breaks = c(17, 25, 35, 45 ,55 ,65 ,100),
  labels = c("18-25", "26-35", "36-45", "46-55", "56-65", "66+")
)


# Revised model using age bands
model2 <- glm(
  ClaimNb ~ AgeBand + BonusMalus + Region,
  offset = log(Exposure),
  family = poisson(link = "log"),
  data = data 
)

# View coefficients of revised model
summary(model2)

# Find average driving score by age band
aggregate(BonusMalus ~ AgeBand, data = data, FUN = mean)

young_driver2 <- data.frame(
  AgeBand= "18-25", 
  BonusMalus = 88.96,
  Region = "R24",
  Exposure = 1 
)
older_driver2 <- data.frame(
  AgeBand = "46-55", 
  BonusMalus = 54.08,
  Region = "R24",
  Exposure = 1 
)

# Predictions with revised model
predict(model2, newdata = young_driver2, type = "response")
predict(model2, newdata = older_driver2, type = "response")

# Same realistic BonusMalus used for both models, to isolate the age-handling difference
driver30 <- data.frame(DrivAge = 30, AgeBand = "26-35", BonusMalus = 69.28, Region = "R24", Exposure = 1)
driver40 <- data.frame(DrivAge = 40, AgeBand = "36-45", BonusMalus =57.52 , Region = "R24", Exposure = 1)

predict(model, newdata = driver30, type = "response")
predict(model, newdata = driver40, type = "response")

predict(model2, newdata = driver30, type = "response")
predict(model2, newdata = driver40, type = "response")


