using BCJCalibratinator
using Documenter

DocMeta.setdocmeta!(BCJCalibratinator, :DocTestSetup, :(using BCJCalibratinator); recursive=true)

makedocs(;
    modules=[BCJCalibratinator],
    authors="Joby M. Anthony III, Daniel S. Kenney",
    sitename="BCJCalibratinator.jl",
    format=Documenter.HTML(;
        canonical="https://jmanthony3.github.io/BCJCalibratinator.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jmanthony3/BCJCalibratinator.jl",
    devbranch="master",
)
