# fraud_detection

This project is still in progress. The objective of this project is to illustrate the use of OpenDataHub running on Openshift to run AI/ML workload. OpenDataHub components used in the project include:
- Spache Spark
- Red Hat Data Virtualization
- Jupyterhub
- Seldon
- Kafka
- Rook

![Work In Progress](images/inProgress.jpeg "Work In Progress")

## 1 Repository Structure
Folders will be added as the project evolves. Currently, it consists of the following folders:
- data - contains the **creditcard.csv** which contains the data needed for the training/testing of fraud detection 
- images - contains images used in the README.md file
- notebook = contains the jupyter notebook **frauddetection.ipynb**. When completed, this notebook allows selection of input from either Spark, data virtualization or  CSV file. Currently, only CSV file is supported.

## 2 Fraud Detection
The Jupyter notebook uses the Random Forest algorithm to train a model to detect fraud based on the features in the **creditcard.csv** file. It also plots the confusion matrix to analyse how good the fit is.

## 3 Planned Data Sources
Reading CSV file is only the first step. Addition data sources include:
- Apache Spark
- Data Virtualization ie, a virtual database which combines info from a relational database and a CSV file which the Jupyter notebook accesses using JDBC.

## TODO
...