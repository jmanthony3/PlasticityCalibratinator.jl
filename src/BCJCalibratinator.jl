module BCJCalibratinator

include("functions.jl")
export BCJMetalExperimentalData
export constant_string
export dataseries_init
export plot_sets!
export bcjmetalcalibration_kernel
export bcjmetalcalibration_init
export bcjmetalcalibration_update!
export update!
export reset_sliders!

include("BCJCalibratinatorJohnsonCookExt.jl")
export JCExperimentalData
export jccalibration_init
export jccalibration_kernel
export jccalibration_update!
export plot_sets!
export update!

end
