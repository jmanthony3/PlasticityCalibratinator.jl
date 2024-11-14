using PlasticityCalibratinator
include("JohnsonCook.jl")

using BammannChiesaJohnsonPlasticity
include("BCJMetal.jl")
include("DK.jl")
include("Bammann1990Modeling.jl")

GLMakie.closeall(); main()