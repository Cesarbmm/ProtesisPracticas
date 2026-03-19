# TD3 Training Report

This folder contains a LaTeX report for the recent training-only intervention on the MATLAB TD3 prosthesis project.

## Files

- `report.tex`: main manuscript
- `references.bib`: bibliography
- `figures/training_progress_300eps.png`: optional screenshot of the MATLAB training-progress window

## Recommended figure path

If you want the training plot to appear automatically in the PDF, save the screenshot as:

```text
EMG_Prosthesis_TD3/docs/td3_training_report/figures/training_progress_300eps.png
```

If the file does not exist, the report will still compile and show a placeholder box.

## Compile

From this directory:

```text
pdflatex report.tex
bibtex report
pdflatex report.tex
pdflatex report.tex
```

## Scope

This report documents:

- the reward redesign
- the environment and logging changes
- the TD3 hyperparameter cleanup
- the 300-episode training run from 2026-03-12
- the next experimental steps before any hardware integration
