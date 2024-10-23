using Pkg; Pkg.precompile()
using Documenter
using BCJCalibratinator

DocMeta.setdocmeta!(BCJCalibratinator, :DocTestSetup, :(using BCJCalibratinator); recursive=true)

makedocs(;
    modules=[BCJCalibratinator],
    authors="Joby M. Anthony III, Daniel S. Kenney",
    repo="https://github.com/jmanthony3/BCJCalibratinator.jl/blob/{commit}{path}#{line}",
    sitename="BCJCalibratinator.jl",
    doctest=false,
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jmanthony3.github.io/BCJCalibratinator.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jmanthony3/BCJCalibratinator.jl",
    devbranch="main",
)
