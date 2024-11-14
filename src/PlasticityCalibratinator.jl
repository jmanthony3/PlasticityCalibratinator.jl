module PlasticityCalibratinator
# __precompile__(true)

include("gui.jl")
export ModelInputs
export ModelData
export ModelCalibration
export main
public screen_main
public screen_main_inputs!
public screen_main_interactions!

# include("gui_functions.jl")
export materialproperties
export materialconstants
export materialdora
export collect
export characteristicequations
export dependenceequations
export dependencesliders
export doraequations
export dorasliders
export modeldata
export plotdata_initialize
export plotdata_insert!
export plotdata_straincontrolkernel
export plotdata_updatekernel
export plotdata_update!

# include("gui_backend.jl")
public update_propsfile!
public update_experimentaldata_browse!
public update_experimentaldata_draganddrop!
public collectragged!
public constructgrid_chareqlabel!
public constructgrid_depeqlabel!
public constructgrid_toggle!
public constructgrid_slider!
public reset_sliders!
public update_modelinputs!
public doratheexplorer_sliders

end
