# PlasticityCalibratinator

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jmanthony3.github.io/PlasticityCalibratinator.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jmanthony3.github.io/PlasticityCalibratinator.jl/dev/)
[![Build Status](https://github.com/jmanthony3/PlasticityCalibratinator.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jmanthony3/PlasticityCalibratinator.jl/actions/workflows/CI.yml?query=branch%3Amain)

## Methodology
- screen_main() # Launches main GUI window
  - screen_main = GLMakie.Screen()
  - fig = Figure(layout=(2, 1))
  - a = GridLayout(fig[1, 1], 2, 1)
  - screenmain_inputs!(a) # top-section for model inputs (model selection, material properties, datasets, etc...)
    - 
  - screenmain_submodelequations!() # lower-left section of updating inputs, characteristic equations, and showing sliders
  - screenmain_plot!() # lower-right section for plot window and export buttons

## Model Specific Functions
- GUIEquations
- ModelData
- ModelCalibration
- materialproperties
- materialconstants
- referenceconfiguration
- solve!()
- calibration_init()
- dataseries_init()
- plot_sets!()
- update!()

## Citing

See [`CITATION.bib`](CITATION.bib) for the relevant reference(s).
