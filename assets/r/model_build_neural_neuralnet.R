# Build a neuralnet() network.
#
# Copyright (C) 2024, Togaware Pty Ltd.
#
# License: GNU General Public License, Version 3 (the "License")
# https://www.gnu.org/licenses/gpl-3.0.en.html
#
# Time-stamp: <Tuesday 2024-10-29 15:17:21 +1100 Graham Williams>
#
# Licensed under the GNU General Public License, Version 3 (the "License");
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Author: Zheyuan Xu

library(neuralnet)
library(caret)
library(NeuralNetTools)  # For neural network plotting

# Subset the training data.

if (neural_ignore_categoric) {

  # Only use numerical variables when ignoring categorical.

  vars_to_use <- numerical_vars
  tds <- ds[tr, c(numerical_vars, target)]

} else {

  vars_to_use <- vars
  tds <- ds[tr, vars]

}

# Remove rows with missing values in predictors or target variable.

tds <- tds[complete.cases(tds), ]

# Initialize empty data frame for predictors.

predictors_combined <- data.frame()

# Handle numerical variables scaling.

if (length(numerical_vars) > 0) {
  predictors_numeric_scaled <- scale(tds[numerical_vars])
  predictors_combined <- as.data.frame(predictors_numeric_scaled)
}

# Handle categorical variables only if not ignoring them.

if (!neural_ignore_categoric && length(categorical_vars) > 0) {
  # Create dummy variables for categorical predictors.

  dmy_predictors <- dummyVars(~ ., data = tds[categorical_vars])
  predictors_categorical <- as.data.frame(predict(dmy_predictors, newdata = tds[categorical_vars]))

  # Combine with numeric predictors if they exist.

  predictors_combined <- if (ncol(predictors_combined) > 0) {
    cbind(predictors_combined, predictors_categorical)
  } else {
    predictors_categorical
  }
}

# Handle Target Variable Encoding.

target_levels <- unique(tds[[target]])
target_levels <- target_levels[!is.na(target_levels)]  # Remove NA if present

if (length(target_levels) == 2) {
  # Binary Classification
  # Map target variable to 0 and 1.

  tds$target_num <- ifelse(tds[[target]] == target_levels[1], 0, 1)
  
  # Combine predictors and target.

  ds_final <- cbind(predictors_combined, target_num = tds$target_num)
  
  # Create formula.

  predictor_vars <- names(predictors_combined)
  formula_nn <- as.formula(paste('target_num ~', paste(predictor_vars, collapse = ' + ')))
  
  # Train neural network.

  model_neuralnet <- neuralnet(
    formula = formula_nn,
    data = ds_final,
    hidden = NEURAL_HIDDEN_LAYERS,
    act.fct = NEURAL_ACT_FCT,
    err.fct = NEURAL_ERROR_FCT,
    linear.output = FALSE,
    threshold = NEURAL_THRESHOLD,
    stepmax = NEURAL_STEP_MAX,
  )
} else {
  # Multiclass Classification
  # One-Hot Encode the Target Variable.

  dmy_target <- dummyVars(~ ., data = tds[target])
  target_onehot <- as.data.frame(predict(dmy_target, newdata = tds[target]))
  
  # Combine predictors and target.

  ds_final <- cbind(predictors_combined, target_onehot)
  
  # Create formula.

  predictor_vars <- names(predictors_combined)
  target_vars <- names(target_onehot)
  formula_nn <- as.formula(paste(
    paste(target_vars, collapse = ' + '),
    '~',
    paste(predictor_vars, collapse = ' + ')
  ))
  
  # Train neural network.

  model_neuralnet <- neuralnet(
    formula = formula_nn,
    data = ds_final,
    hidden = NEURAL_HIDDEN_LAYERS,
    act.fct = NEURAL_ACT_FCT,
    err.fct = NEURAL_ERROR_FCT,
    linear.output = FALSE,
    threshold = NEURAL_THRESHOLD,
    stepmax = NEURAL_STEP_MAX,
  )
}

# Generate a textual view of the Neural Network model.

print(model_neuralnet)
summary(model_neuralnet)

# Save the plot as an SVG file.

svg("TEMPDIR/model_neuralnet.svg")
NeuralNetTools::plotnet(model_neuralnet,
                        cex_val    = 0.5,
                        circle_cex = 2,
                        rel_rsc    = c(1, 3),
                        pos_col    = "orange",
                        neg_col    = "grey",
                        node_labs  = TRUE)
dev.off()
