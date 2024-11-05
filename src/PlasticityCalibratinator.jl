module PlasticityCalibratinator

include("functions.jl")
export characteristicequations
export dependenceequations
export dependencesliders
export GUIEquations
export ModelInputs
export ModelData
export ModelCalibration
export constant_string
export dataseries_init
export calibration_kernel
export calibration_init
export calibration_update!
export plot_sets!
export update!
export reset_sliders!
export update_propsfile!
export update_experimentaldata!
export update_experimentaldata_draganddrop!
export update_inputs!
export depeq_label!
export toggle!
export sg_slider!
export update_modelselection
export calibrateconstantselection!
export save_propsfile
export save_experimentaldata
export main

# include("figure.jl")
# export main

end
