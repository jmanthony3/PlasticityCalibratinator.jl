using CSV
using DataFrames
using Distributed
using GLMakie
using LaTeXStrings
using PlasticityBase
using PlasticityCalibratinator

set_theme!(theme_latexfonts())

abstract type JC <: AbstractPlasticity end

materialprops_JC = Dict(
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
materialconsts_JC = collect(
    "A"     => 835.014717457143,
    "B"     => 810.9199208476191,
    "n"     => 0.5152083333333339,
    "C"     => 0.004992526238095374,
    "m"     => 1.1721130952380956,
)
constantsrange_max = Dict(
    "A"     => 300.,
    "B"     => 400.,
    "n"     => 1.,
    "C"     => 0.1,
    "m"     => 0.5,
)

PlasticityCalibratinator.materialproperties(::Type{JC}) = materialprops_JC
PlasticityCalibratinator.materialconstants(::Type{JC}) = materialconsts_JC

PlasticityCalibratinator.characteristicequations(::Type{JC}) = [
    L"\sigma = (A + B\mathrm{exp}(n)) * (1 + C*\log(\epsilon^{*})) * (1 - (T^{*})^{m}))"]
PlasticityCalibratinator.dependenceequations(::Type{JC})     = [L"A", L"B", L"n", L"C", L"m"]
PlasticityCalibratinator.dependencesliders(::Type{JC})       = [
    (label=L"A", range=range(materialconsts_JC["A"] - constantsrange_max["A"], materialconsts_JC["A"] + constantsrange_max["A"]; length=1_000), format="{:.3e}", startvalue=materialconsts_JC["A"]),
    (label=L"B", range=range(materialconsts_JC["B"] - constantsrange_max["B"], materialconsts_JC["B"] + constantsrange_max["B"]; length=1_000), format="{:.3e}", startvalue=materialconsts_JC["B"]),
    (label=L"n", range=range(materialconsts_JC["n"] - constantsrange_max["n"], materialconsts_JC["n"] + constantsrange_max["n"]; length=1_000), format="{:.3e}", startvalue=materialconsts_JC["n"]),
    (label=L"C", range=range(materialconsts_JC["C"] - constantsrange_max["C"], materialconsts_JC["C"] + constantsrange_max["C"]; length=1_000), format="{:.3e}", startvalue=materialconsts_JC["C"]),
    (label=L"m", range=range(materialconsts_JC["m"] - constantsrange_max["m"], materialconsts_JC["m"] + constantsrange_max["m"]; length=1_000), format="{:.3e}", startvalue=materialconsts_JC["m"]),
]

doramat = collect(
    "Tr"    => 295.0,
    "Tm"    => 1793.0,
    "er0"   => 1.0,
)
PlasticityCalibratinator.materialdora(::Type{JC}) = doramat
dorarange_max = collect([
    "Tr"    => 100.,
    "Tm"    => 1e3,
    "er0"   => 1e3,
])
PlasticityCalibratinator.doraequations(::Type{JC})     = [L"T_{ref}", L"T_{m}", L"\dot{\epsilon}_{ref}"]
PlasticityCalibratinator.dorasliders(::Type{JC})       = [
    (label=L"T_{ref}",              range=range(doramat["Tr"] - dorarange_max["Tr"],   doramat["Tr"] + dorarange_max["Tr"];   length=1_000), format="{:.3e}", startvalue=doramat["Tr"]),
    (label=L"T_{m}",                range=range(doramat["Tm"] - dorarange_max["Tm"],   doramat["Tm"] + dorarange_max["Tm"];   length=1_000), format="{:.3e}", startvalue=doramat["Tm"]),
    (label=L"\dot{\epsilon}_{ref}", range=logrange(1e-3, 1e6; length=1_000), format="{:.3e}", startvalue=doramat["er0"]),
]

struct JCStrainControl{T<:AbstractFloat} <: AbstractLoading
    θ       ::T
    ϵ_dot   ::T
    ϵₙ      ::T
    N       ::Integer
    params  ::Dict{String, T}
end

mutable struct JCConfigurationCurrent{T<:AbstractFloat} <: AbstractConfigurationCurrent
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

mutable struct JCConfigurationHistory{T<:AbstractFloat} <: AbstractConfigurationHistory
    σ::Vector{T}
    ϵ::Vector{T}
end

function Base.:+(x::T, y::T) where {T<:JCConfigurationHistory}
    return JCConfigurationHistory{eltype(x.σ)}(
        hcat(x.σ, y.σ),
        hcat(x.ϵ, y.ϵ .+ x.ϵ[:, end])
    )
end

function Base.copyto!(reference::JCConfigurationCurrent, history::JCConfigurationHistory)
    reference.σ = history.σ[:, end]
    return nothing
end

function record!(history::JCConfigurationHistory, i::Integer, current::JCConfigurationCurrent)
    history.σ[i] = current.σ
    history.ϵ[i] = current.ϵ
    return nothing
end

function PlasticityBase.referenceconfiguration(::Type{JC}, jc::JCStrainControl)::ConfigurationTuple
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
    current = JCConfigurationCurrent{T}(N, θ, 0., ϵ_dot, Δϵ,
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

function PlasticityBase.solve!(jc::JCConfigurationCurrent{<:AbstractFloat},
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
        # println((i, (A, B, jc.ϵ, jc.Δϵ, n, C, ϵ⁺, θ⁺, m)))
        jc.ϵ = jc.ϵ + jc.Δϵ
        jc.σ = johnsoncookstress(A, B, jc.ϵ, n, C, ϵ⁺, θ⁺, m)
        record!(history, i, jc)
    end
    return nothing
end

################################################################
#  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  #
# PlasticityBase
#  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  #
# PlasticityCalibratinator
#  v  v  v  v  v  v  v  v  v  v  v  v  v  v  v  v  v  v  v  v  #
################################################################

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
function PlasticityCalibratinator.modeldata(::Type{JC}, model_inputs::ModelInputs, params)::ModelData
    # files, incnum, params, Scale_MPa
    files = model_inputs.expdatasets
    incnum = model_inputs.incnum
    Scale_MPa = model_inputs.stressscale
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
                # println("ERROR! Data from  '", file , "'  has bad stress-strain data lengths")
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
            sol = plotdata_updatekernel(JC, test_data, test_cond, incnum, params, i)
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
    return ModelData{JC}(JC, model_inputs, nsets, test_data, test_cond, params, deepcopy(materialconstants(JC)), deepcopy(materialconstants(JC)), incnum, Scale_MPa)
end

function PlasticityCalibratinator.plotdata_initialize(::Type{JC}, nsets, test_data)
    dataseries = [[], []]
    if nsets > 0
        for i in range(1, nsets)
            push!(dataseries[1], Observable(DataFrame(x=test_data["Data_E"][i], y=test_data["Data_S"][i])))
            push!(dataseries[2], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_VM"][i])))
        end
    end
    return dataseries
end

function PlasticityCalibratinator.plotdata_insert!(::Type{JC}, model_calibration)
    # ax, dataseries, Scale_MPa
    for i in range(1, model_calibration[].modeldata.nsets)
        # println(i)
        scatter!(model_calibration[].ax,    @lift(Point2f.($(model_calibration[].dataseries[1][i]).x, $(model_calibration[].dataseries[1][i]).y)),
            color=i, colormap=:viridis, colorrange=(1, model_calibration[].modeldata.nsets), label="Data - " * model_calibration[].modeldata.test_cond["Name"][i])
        lines!(model_calibration[].ax,      @lift(Point2f.($(model_calibration[].dataseries[2][i]).x, $(model_calibration[].dataseries[2][i]).y .* model_calibration[].modeldata.stressscale)),
            color=i, colormap=:viridis, colorrange=(1, model_calibration[].modeldata.nsets), label="VM Model - " * model_calibration[].modeldata.test_cond["Name"][i])
    end
end

function PlasticityCalibratinator.plotdata_straincontrolkernel(::Type{JC}, temp, epsrate, emax, incnum, params)::NamedTuple
    # println("Setup: emax for set ", i, " = ", emax)
    # println("θ=", temp, ", ϵ̇=", epsrate, ", ϵₙ=", emax, ", N=", incnum)
    loading = JCStrainControl(temp, epsrate, emax, incnum, params)
    history = kernel(JC, loading)[3]
    # println("Solved: emax for set ", i, " = ", maximum(jc_history.ϵ))
    return (ϵ=history.ϵ, σ=history.σ, σvM=history.σ)
end

@inline function PlasticityCalibratinator.plotdata_updatekernel(::Type{JC}, test_data, test_cond, incnum, params, i)::NamedTuple
    return plotdata_straincontrolkernel(JC,
        test_cond["Temp"][i], test_cond["StrainRate"][i],
        maximum(test_data["Data_E"][i]), incnum, params)
end

function PlasticityCalibratinator.plotdata_update!(::Type{JC}, modelcalibration)
    # dataseries, incnum, Scale_MPa
    for (key, val) in modelcalibration[].modeldata.params
        modelcalibration[].modeldata.materialproperties[key] = val
    end
    @sync @distributed for i in range(1, modelcalibration[].modeldata.nsets)
    # for i in range(1, modelcalibration.modeldata.nsets)
        sol = plotdata_updatekernel(JC, modelcalibration[].modeldata.test_data, modelcalibration[].modeldata.test_cond, modelcalibration[].modeldata.incnum, modelcalibration[].modeldata.materialproperties, i)
        modelcalibration[].modeldata.test_data["Model_S"][i]    .= sol.σ .* modelcalibration[].modeldata.stressscale
        modelcalibration[].modeldata.test_data["Model_VM"][i]   .= sol.σvM
        modelcalibration[].dataseries[2][i][].y .= modelcalibration[].modeldata.test_data["Model_VM"][i]
        for ds in modelcalibration[].dataseries[2:end]
            notify(ds[i])
        end
    end
    return nothing
end

# dora

function PlasticityCalibratinator.modeldora(::Type{JC}, model_inputs::ModelInputs, params, temperatures, strainrates, finalstrains)::ModelData
    # files, incnum, params, Scale_MPa
    nsets = mapreduce(length, *, (temperatures, strainrates, finalstrains))
    incnum = model_inputs.incnum
    Scale_MPa = model_inputs.stressscale
    for (key, value) in materialdora(JC)
        params[key] = value
    end
    test_cond   = Dict(
        "StrainRate"    => [],
        "StrainFinal"   => [],
        "Temp"          => [],
        "Name"          => []
    )
    test_data   = Dict(
        "Data_E"        => [],
        "Model_E"       => [],
        "Model_S"       => [],
        "Model_VM"      => []
    )
    i = 1
    for temp in temperatures
        for strainrate in strainrates
            for finalstrain in finalstrains
                # store the stress-strain data
                name = "$finalstrain @ ($temp, $strainrate)"
                push!(test_cond["StrainRate"],  (i, strainrate))
                push!(test_cond["StrainFinal"], (i, finalstrain))
                push!(test_cond["Temp"],        (i, temp))
                push!(test_cond["Name"],        (i, name))
                push!(test_data["Data_E"],      (i, range(0, finalstrain; length=incnum+1)))
                println((i, strainrate, finalstrain, temp, name))
                i += 1
            end
        end
    end
    for key in ("StrainRate", "StrainFinal", "Temp", "Name")
        for (i, x) in enumerate(sort(test_cond[key], by=x->first(x)))
            test_cond[key][i] = last(x)
        end
    end
    for key in ("Data_E",)
        for (i, x) in enumerate(sort(test_data[key], by=x->first(x)))
            test_data[key][i] = last(x)
        end
    end
    @sync @distributed for i in range(1, nsets)
    # for i in range(1, nsets)
        sol = plotdata_straincontrolkernel(JC, test_cond["Temp"][i], test_cond["StrainRate"][i], test_cond["StrainFinal"][i], incnum, params)
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
    return ModelData{JC}(JC, model_inputs, nsets, test_data, test_cond, params, deepcopy(materialconstants(JC)), deepcopy(materialconstants(JC)), incnum, Scale_MPa)
end

function PlasticityCalibratinator.plotdora_initialize(::Type{JC}, nsets, test_data)
    dataseries = [[]]
    if nsets > 0
        for i in range(1, nsets)
            push!(dataseries[1], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_VM"][i])))
        end
    end
    return dataseries
end

function PlasticityCalibratinator.plotdora_insert!(::Type{JC}, model_calibration)
    # ax, dataseries, Scale_MPa
    for i in range(1, model_calibration[].modeldata.nsets)
        # println(i)
        lines!(model_calibration[].ax,      @lift(Point2f.($(model_calibration[].dataseries[1][i]).x, $(model_calibration[].dataseries[1][i]).y .* model_calibration[].modeldata.stressscale)),
            color=i, colormap=:viridis, colorrange=(0, model_calibration[].modeldata.nsets), label="VM Model - " * model_calibration[].modeldata.test_cond["Name"][i])
    end
end

function PlasticityCalibratinator.plotdora_update!(::Type{JC}, model_calibration)
    # dataseries, incnum, Scale_MPa
    # println(modelcalibration[].modeldata.nsets)
    for (key, val) in model_calibration[].modeldata.params
        model_calibration[].modeldata.materialproperties[key] = val
    end
    @sync @distributed for i in range(1, model_calibration[].modeldata.nsets)
    # for i in range(1, modelcalibration.modeldata.nsets)
        # sol = plotdata_updatekernel(JC, modelcalibration[].modeldata.test_data, modelcalibration[].modeldata.test_cond, modelcalibration[].modeldata.incnum, modelcalibration[].modeldata.materialproperties, i)
        sol = plotdata_straincontrolkernel(JC, model_calibration[].modeldata.test_cond["Temp"][i], model_calibration[].modeldata.test_cond["StrainRate"][i], model_calibration[].modeldata.test_cond["StrainFinal"][i], model_calibration[].modeldata.incnum, model_calibration[].modeldata.materialproperties)
        model_calibration[].modeldata.test_data["Model_S"][i]    .= sol.σ .* model_calibration[].modeldata.stressscale
        model_calibration[].modeldata.test_data["Model_VM"][i]   .= sol.σvM
        model_calibration[].dataseries[1][i][].y .= model_calibration[].modeldata.test_data["Model_VM"][i]
        for ds in model_calibration[].dataseries
            notify(ds[i])
        end
    end
    return nothing
end