# NOTE: run claim_frequency_model.R first in the same session -this script depends on 'data' and 'model2' created there

#Load foreign package so we can read arff files
library("foreign") 

# Load the French motor insurance data set, this project uses the 'freMTPL2sev' available from OpenML : https://www.openml.org/search?type=data&id=41215&sort=runs&status=active
sev_data <- read.arff("freMTPL2sev.arff")

# Check overall structure and column names in the dataset
str(sev_data) 

# Check the distribution of claim severity 
summary(sev_data$ClaimAmount)

# Check how many times the same policy appears
table(table(sev_data$IDpol))

# Merge policies that have had multiple claims so they only have one row in the table 
sev_summed <- aggregate(ClaimAmount ~ IDpol, data = sev_data, FUN = sum)
nrow(sev_summed)

# Merge claim frequency and claim severity data 
data_merged <- merge(data, sev_summed, by = "IDpol", all.x = TRUE)

# Change any claim amounts from na to 0 
data_merged$ClaimAmount[is.na(data_merged$ClaimAmount)] <- 0

# Check to if na to 0 changed worked
summary(data_merged$ClaimAmount)

# Create age bands as frequency model uses age bands
data_merged$AgeBand <- cut(
  data_merged$DrivAge,
  breaks = c(17, 25, 35, 45 ,55 ,65 ,100),
  labels = c("18-25", "26-35", "36-45", "46-55", "56-65", "66+")
)

# Check to see if age bands were created 
str(data_merged)

# Create new data set containing only policies that made at least one claim
claims_only <- data_merged[data_merged$ClaimAmount> 0,]

# GLM model using gamma to predict claim severity 
sev_model <- glm(
  ClaimAmount ~ AgeBand + BonusMalus + Region,
  family = Gamma(link = "log"),
  data = claims_only
)

# Check coefficients to interpret each predictor's effect on claim severity
summary(sev_model)

# Create pricing data frame and ensure all policies are calculated over one year
pricing_data <- data_merged
pricing_data$Exposure <- 1

# Predict frequency 
pred_freq <- predict(model2, newdata = pricing_data,type="response")

# Predict severity
pred_sev <- predict(sev_model, newdata= pricing_data, type= "response")

# Predict premiums and appended them to the table
pricing_data$PurePremium <- pred_freq * pred_sev

# Predicted average premium by age band 
aggregate(PurePremium ~ AgeBand, data = pricing_data, FUN = mean)

# Find actual average claim amount by age band 
actual_annualized <- aggregate(cbind(ClaimAmount, Exposure) ~ AgeBand, data = data_merged, FUN = sum)
actual_annualized$AnnualizedClaimCost <- actual_annualized$ClaimAmount / actual_annualized$Exposure
actual_annualized

# Use the model to calculate premium price for younger and older driver
young_pricing <- data.frame(
  AgeBand = "18-25",
  BonusMalus = 88.96,
  Region = "R24",
  Exposure = 1
)

older_pricing <- data.frame(
  AgeBand = "46-55",
  BonusMalus = 54.08,
  Region = "R24",
  Exposure = 1
)

young_freq <- predict(model2, newdata = young_pricing, type = "response")
young_sev  <- predict(sev_model, newdata = young_pricing, type = "response")

older_freq <- predict(model2, newdata = older_pricing, type = "response")
older_sev  <- predict(sev_model, newdata = older_pricing, type = "response")

young_premium <- young_freq * young_sev
older_premium <- older_freq * older_sev

young_premium
older_premium
