using Pkg; Pkg.precompile()
using Documenter
using PlasticityCalibratinator

DocMeta.setdocmeta!(PlasticityCalibratinator, :DocTestSetup, :(using PlasticityCalibratinator); recursive=true)

makedocs(;
    modules=[PlasticityCalibratinator],
    authors="Joby M. Anthony III, Daniel S. Kenney",
    repo="https://github.com/jmanthony3/PlasticityCalibratinator.jl/blob/{commit}{path}#{line}",
    sitename="PlasticityCalibratinator.jl",
    doctest=false,
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jmanthony3.github.io/PlasticityCalibratinator.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jmanthony3/PlasticityCalibratinator.jl",
    devbranch="main",
)
