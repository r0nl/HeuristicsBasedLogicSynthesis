#!/bin/bash

# Run optimization scripts
./InitVal.sh
./GenRec.sh
./RSoptimizer.sh
./RStoCSV.sh

# Run Monte Carlo optimizer and generate CSV
./MCoptimizer.sh

# Run Simulated Annealing optimizer and generate CSV
./SAoptimizer.sh

# Generate plots
python PlotGraphs.py

echo "All scripts executed successfully."
