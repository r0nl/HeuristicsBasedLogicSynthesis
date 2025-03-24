#!/bin/bash

# Run optimization scripts
./InitVal.sh
./GenRec.sh
./RSoptimizer.sh
./RStoCSV.sh

# Run Monte Carlo optimizer and generate CSV
./MCoptimizer.sh
./MCtoCSV.sh

# Run Simulated Annealing optimizer and generate CSV
./SAoptimizer.sh
./SAtoCSV.sh

# Generate plots
python PlotGraphs.py

echo "All scripts executed successfully."
