using CSV
using DataFrames
using Distributed
using GLMakie
using LaTeXStrings
using PlasticityBase
using PlasticityCalibratinator

set_theme!(theme_latexfonts())

abstract type JC <: Plasticity end

materialprops = Dict(
    # Comment,Johnson & Cook 1985
    "A"     => 835.014717457143,
    "B"     => 810.9199208476191,
    "n"     => 0.5152083333333339,
    "C"     => 0.004992526238095374,
    "m"     => 1.1721130952380956,
    "Tr"    => 295.0,
    "Tm"    => 1793.0,
    "er0"   => 1.0,
)
PlasticityBase.materialproperties(::Type{JC}) = materialprops
materialconsts = Dict(
    "A"     => 835.014717457143,
    "B"     => 810.9199208476191,
    "n"     => 0.5152083333333339,
    "C"     => 0.004992526238095374,
    "m"     => 1.1721130952380956,
)
PlasticityBase.materialconstants(::Type{JC}) = materialconsts
PlasticityBase.materialconstants_index(::Type{JC}) = [
    "A",
    "B",
    "n",
    "C",
    "m"
]
constantsrange_max = [
    300.,   # A
    400.,   # B
    1.,     # n
    0.1,    # C
    0.5,    # m
]

PlasticityCalibratinator.characteristicequations(::Type{JC}) = [
    L"\sigma = (A + B\mathrm{exp}(n)) * (1 + C*\log(\epsilon^{*})) * (1 - (T^{*})^{m}))"]
PlasticityCalibratinator.dependenceequations(::Type{JC})     = [L"A", L"B", L"n", L"C", L"m"]
PlasticityCalibratinator.dependencesliders(::Type{JC})       = [
    (label=L"A", range=range(materialconsts["A"] - constantsrange_max[ 1], materialconsts["A"] + constantsrange_max[ 1]; length=1_000), format="{:.3e}", startvalue=materialconsts["A"]),
    (label=L"B", range=range(materialconsts["B"] - constantsrange_max[ 2], materialconsts["B"] + constantsrange_max[ 2]; length=1_000), format="{:.3e}", startvalue=materialconsts["B"]),
    (label=L"n", range=range(materialconsts["n"] - constantsrange_max[ 3], materialconsts["n"] + constantsrange_max[ 3]; length=1_000), format="{:.3e}", startvalue=materialconsts["n"]),
    (label=L"C", range=range(materialconsts["C"] - constantsrange_max[ 4], materialconsts["C"] + constantsrange_max[ 4]; length=1_000), format="{:.3e}", startvalue=materialconsts["C"]),
    (label=L"m", range=range(materialconsts["m"] - constantsrange_max[ 5], materialconsts["m"] + constantsrange_max[ 5]; length=1_000), format="{:.3e}", startvalue=materialconsts["m"]),
]

struct JCStrainControl{T<:AbstractFloat}
    θ       ::T
    ϵ_dot   ::T
    ϵₙ      ::T
    N       ::Integer
    params  ::Dict{String, T}
end

mutable struct JCCurrentConfiguration{T<:AbstractFloat}
    N       ::Integer
    θ       ::T
    ϵ       ::T
    ϵ_dot   ::T
    Δϵ      ::T
    Tr      ::T
    Tm      ::T
    er0     ::T
    ϵ⁺      ::T
    θ⁺      ::T
    A       ::T
    B       ::T
    n       ::T
    C       ::T
    m       ::T
    σ       ::T
end

mutable struct JCConfigurationHistory{T<:AbstractFloat}
    σ::Vector{T}
    ϵ::Vector{T}
end

function Base.:+(x::T, y::T) where {T<:JCConfigurationHistory}
    return JCConfigurationHistory{eltype(x.σ)}(
        hcat(x.σ, y.σ),
        hcat(x.ϵ, y.ϵ .+ x.ϵ[:, end])
    )
end

function Base.copyto!(reference::JCCurrentConfiguration, history::JCConfigurationHistory)
    reference.σ = history.σ[:, end]
    return nothing
end

function record!(history::JCConfigurationHistory, i::Integer, current::JCCurrentConfiguration)
    history.σ[i] = current.σ
    history.ϵ[i] = current.ϵ
    return nothing
end

function PlasticityBase.referenceconfiguration(::Type{JC}, jc::JCStrainControl)::Tuple{JCCurrentConfiguration, JCCurrentConfiguration, JCConfigurationHistory}
    θ       = jc.θ
    ϵ_dot   = jc.ϵ_dot
    ϵₙ      = jc.ϵₙ
    N       = jc.N
    params  = jc.params
    M       = N + 1
    Tr      = params["Tr"]
    Tm      = params["Tm"]
    er0     = params["er0"]
    A       = params["A"]
    B       = params["B"]
    n       = params["n"]
    C       = params["C"]
    m       = params["m"]
    T       = typeof(float(jc.θ))
    ϵ⁺ = ϵ_dot / er0
    θ⁺ = ( θ - Tr ) / ( Tm - Tr )
    Δϵ = ϵₙ/N
    current = JCCurrentConfiguration{T}(N, θ, 0., ϵ_dot, Δϵ,
        Tr, Tm, er0, ϵ⁺, θ⁺, A, B, n, C, m, 0.)
    history = JCConfigurationHistory{T}(
        Vector{T}(undef, M),
        # [range(0., ϵₙ; length=M)...]
        Vector{T}(undef, M)
    )
    record!(history, 1, current)
    return (current, current, history)
end

# JC stress function
function johnsoncookstress(A, B, ϵ, n, C, ϵ⁺, θ⁺, m)::AbstractFloat
    return ( A + B * ϵ^n ) * ( 1. + C * log(ϵ⁺) ) * ( 1. - θ⁺^m )
end

function PlasticityBase.solve!(jc::JCCurrentConfiguration{<:AbstractFloat},
        history::JCConfigurationHistory)
    A   = jc.A
    B   = jc.B
    n   = jc.n
    C   = jc.C
    ϵ⁺  = jc.ϵ⁺
    θ⁺  = jc.θ⁺
    m   = jc.m
    # calculate the model stress-strain data
    # for (i, ϵ) ∈ zip(range(2, jc.N + 1), history.ϵ[2:end])
    #     history.σ[i] = johnsoncookstress(A, B, ϵ, n, C, ϵ⁺, θ⁺, m)
    # end
    for i ∈ range(2, jc.N + 1)
        jc.ϵ = jc.ϵ + jc.Δϵ
        jc.σ = johnsoncookstress(A, B, jc.ϵ, n, C, ϵ⁺, θ⁺, m)
        record!(history, i, jc)
    end
    return nothing
end

function jccalibration_kernel(test_data, test_cond, incnum, params, i)::NamedTuple
    emax        = maximum(test_data["Data_E"][i])
    # println("Setup: emax for set ", i, " = ", emax)
    jc_loading     = JCStrainControl(
        test_cond["Temp"][i], test_cond["StrainRate"][i],
        emax, incnum, params)
    jc_configuration    = referenceconfiguration(JC, jc_loading)
    jc_reference        = jc_configuration[1]
    jc_current          = jc_configuration[2]
    jc_history          = jc_configuration[3]
    solve!(jc_current, jc_history)
    # println("Solved: emax for set ", i, " = ", maximum(jc_history.ϵ))
    return (ϵ=jc_history.ϵ, σ=jc_history.σ, σvM=jc_history.σ)
end

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
function PlasticityCalibratinator.calibration_init(::Type{JC}, modelinputs::ModelInputs, params)::ModelData
    # files, incnum, params, Scale_MPa
    files = modelinputs.expdatasets
    incnum = modelinputs.incnum
    Scale_MPa = modelinputs.stressscale
    test_cond   = Dict(
        "StrainRate"    => [],
        "Temp"          => [],
        "Name"          => []
    )
    test_data   = Dict(
        "Data_E"        => [],
        "Data_S"        => [],
        "Model_E"       => [],
        "Model_S"       => [],
        "Model_VM"      => []
    )
    nsets = 0
    if first(files) != ""
        nsets = length(files)
        for (i, file) in enumerate(files)
            df_file = CSV.read(file, DataFrame; header=true, delim=',', types=[Float64, Float64, Float64, Float64, String])

            # add stress/strain data:
            strn = df_file[!, "Strain"]
            strs = df_file[!, "Stress"] .* Scale_MPa
            er   = df_file[!, "Strain Rate"]
            T    = df_file[!, "Temperature"]
            name = df_file[!, "Name"]
            # check data entered
            if length(strn) != length(strs)
                println("ERROR! Data from  '", file , "'  has bad stress-strain data lengths")
            end

            # store the stress-strain data
            push!(test_cond["StrainRate"],  (i, first(er)))
            push!(test_cond["Temp"],        (i, first(T)))
            push!(test_cond["Name"],        (i, first(name)))
            push!(test_data["Data_E"],      (i, strn))
            push!(test_data["Data_S"],      (i, strs))
        end
        for key in ("StrainRate", "Temp", "Name")
            for (i, x) in enumerate(sort(test_cond[key], by=x->first(x)))
                test_cond[key][i] = last(x)
            end
        end
        for key in ("Data_E", "Data_S")
            for (i, x) in enumerate(sort(test_data[key], by=x->first(x)))
                test_data[key][i] = last(x)
            end
        end
        @sync @distributed for i in range(1, nsets)
        # for i in range(1, nsets)
            sol = jccalibration_kernel(test_data, test_cond, incnum, params, i)
            # test_data[i][1] = [E,S,Al,kap,tot,SVM]             #Store model stress/strain data
            # push!(test_data["Model_E"],     E)
            # push!(test_data["Model_S"],     S)
            # push!(test_data["Model_alph"],  Al)
            # push!(test_data["Model_kap"],   κ)
            # push!(test_data["Model_tot"],   Tot)
            # push!(test_data["Model_VM"],    SVM)
            push!(test_data["Model_E"],     (i, sol.ϵ))
            push!(test_data["Model_S"],     (i, sol.σ .* Scale_MPa))
            push!(test_data["Model_VM"],    (i, sol.σvM))
        end
        for key in ("Model_E", "Model_S", "Model_VM")
            for (i, x) in enumerate(sort(test_data[key], by=x->first(x)))
                test_data[key][i] = last(x)
            end
        end
    end
    return ModelData{JC}(JC, modelinputs, nsets, test_data, test_cond, params, deepcopy(materialconstants(JC)), deepcopy(materialconstants(JC)), incnum, Scale_MPa)
end

function PlasticityCalibratinator.dataseries_init(::Type{JC}, nsets, test_data)
    dataseries = [[], []]
    if nsets > 0
        for i in range(1, nsets)
            push!(dataseries[1], Observable(DataFrame(x=test_data["Data_E"][i], y=test_data["Data_S"][i])))
            push!(dataseries[2], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_VM"][i])))
        end
    end
    return dataseries
end

function PlasticityCalibratinator.plot_sets!(::Type{JC}, modelcalibration)
    # ax, dataseries, Scale_MPa
    for i in range(1, modelcalibration[].modeldata.nsets)
        println(i)
        scatter!(modelcalibration[].ax,    @lift(Point2f.($(modelcalibration[].dataseries[1][i]).x, $(modelcalibration[].dataseries[1][i]).y)),
            color=i, colormap=:viridis, colorrange=(1, modelcalibration[].modeldata.nsets), label="Data - " * modelcalibration[].modeldata.test_cond["Name"][i])
        lines!(modelcalibration[].ax,      @lift(Point2f.($(modelcalibration[].dataseries[2][i]).x, $(modelcalibration[].dataseries[2][i]).y .* modelcalibration[].modeldata.stressscale)),
            color=i, colormap=:viridis, colorrange=(1, modelcalibration[].modeldata.nsets), label="VM Model - " * modelcalibration[].modeldata.test_cond["Name"][i])
    end
end

function PlasticityCalibratinator.calibration_update!(::Type{JC}, i, jc::ModelData)
    for (key, val) in jc.params
        jc.materialproperties[key] = val
    end
    sol = jccalibration_kernel(jc.test_data, jc.test_cond, jc.incnum, jc.materialproperties, i)
    jc.test_data["Model_S"][i]    .= sol.σ .* jc.stressscale
    jc.test_data["Model_VM"][i]   .= sol.σvM
    return nothing
end

function PlasticityCalibratinator.update!(::Type{JC}, modelcalibration)
    # dataseries, incnum, Scale_MPa
    @sync @distributed for i in range(1, modelcalibration[].modeldata.nsets)
    # for i in range(1, modelcalibration.modeldata.nsets)
        calibration_update!(JC, i, modelcalibration[].modeldata)
        modelcalibration[].dataseries[2][i][].y .= modelcalibration[].modeldata.test_data["Model_VM"][i]
        for ds in modelcalibration[].dataseries[2:end]
            notify(ds[i])
        end
    end
    return nothing
end