# GEV-for-matlab

# README

## Software title
GEV Flood Frequency Analysis (MATLAB)

## 1. Overview
This software performs generalized extreme value (GEV) flood frequency analysis for a univariate hydrological series stored in an Excel file. The script reads one column of input data, removes `NaN` and non-positive values, estimates GEV parameters, plots empirical and fitted frequency curves, calculates confidence bounds and selected return-level estimates, performs a Kolmogorov–Smirnov (KS) goodness-of-fit test, and exports tabular and figure outputs.

Typical use case: annual maximum discharge or other positive hydrological extremes.
## 2. System requirements
This script is written in **MATLAB** and requires:

- **MATLAB** (recommended: R2025b)
- **Statistics and Machine Learning Toolbox** for:
  - `gevfit`
  - `gevinv`
  - `gevcdf`
  - `kstest`

Supported operating systems (MATLAB-supported platforms):
- Windows 10/11
- macOS
- Linux

## 3. Installation guide
1. Install **MATLAB**.
2. Install or enable the **Statistics and Machine Learning Toolbox**.
3. Place the following files in the same working directory:
   - `GEV.m`
   - `Input.xlsx`
4. Open MATLAB and set the current folder to that directory.
5. Run the script:
   ```matlab
   GEV
   ```
