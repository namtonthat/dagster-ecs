"""
Data Science Team - ML Training DAG
"""

from dagster import Definitions, asset


@asset
def training_data():
    """Load and prepare training data"""
    return {"samples": 10000, "features": 50}


@asset
def feature_engineering(training_data):
    """Apply feature engineering transformations"""
    return {"processed_features": training_data["features"] * 2, "samples": training_data["samples"]}


@asset
def model_training(feature_engineering):
    """Train machine learning model"""
    return {"model_accuracy": 0.85, "model_type": "random_forest", "training_time": "45_minutes"}


@asset
def model_evaluation(model_training):
    """Evaluate trained model"""
    return {"accuracy": model_training["model_accuracy"], "precision": 0.82, "recall": 0.88, "f1_score": 0.85}


# Define the DAG (code location)
defs = Definitions(assets=[training_data, feature_engineering, model_training, model_evaluation])
