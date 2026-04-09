# Do-Local-Industrial-Policies-Drive-Battery-Energy-Storage-Innovation
This repository provides the BESS policy text processing code, panel data, and Stata code used in the paper Do Local Industrial Policies Drive Battery Energy Storage Innovation? Evidence of Threshold Effects and Industrial-Chain Spillovers from China.

# File Name	Description
Baseline Staggered DID.do：Stata do-file for baseline staggered difference-in-differences (DID) estimation, including core regression specifications, parallel trend tests, and robustness checks.
CSDID.do：Stata do-file for Callaway-Sant'Anna DID (CSDID) estimation, a robust method for staggered treatment adoption with heterogeneous treatment effects.
Industry Chain Spillovers.do：Stata do-file for industry chain spillover effect analysis, examining how policy shocks propagate across upstream/midstram/downstream industries, etc.
Regional Heterogeneity.do：Stata do-file for regional heterogeneity analysis, testing differential policy effects across geographic regions.
llm_api.py：Python script for LLM API integration and prompt engineering. Handles API calls to large language models, constructs standardized prompts for policy analysis, and manages request/response workflows.
process_policies.py：Python script for structured extraction of LLM analysis results. Parses unstructured LLM outputs, standardizes policy coding, and transforms raw model responses into machine-readable, analysis-ready structured data.
panel_data.xlsx：Raw panel dataset used for all regression analyses, containing city-level variables, treatment timing, and control variables.
README.md	Project documentation file (this file).

# Usage Instructions
1. Policy Data Preparation
Use llm_api.py to send policy text to the LLM API with pre-built prompts.
Use process_policies.py to extract and structure the LLM's output into a format compatible with the panel dataset.

# Dependencies
Stata
Required packages: csdid, reghdfe, estout (install via ssc install if missing)
Stata version 16 or higher recommended
Python
Required libraries: openai (or other LLM API clients), pandas, numpy, json, re
Python version 3.8 or higher recommended

# Notes
All regression code is pre-configured for the panel_data.xlsx dataset. Modify file paths and variable names as needed for your specific analysis.
Ensure API keys are securely stored and not hard-coded in llm_api.py for production use.
For reproducibility, all do-files and Python scripts include detailed comments for each step of the analysis.

# Contact
For questions or issues related to the code or analysis, please contact the repository maintainer.
