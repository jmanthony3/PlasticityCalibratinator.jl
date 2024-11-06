using CSV
using DataFrames
using Distributed
using GLMakie
using LaTeXStrings
using PlasticityBase
using PlasticityCalibratinator

using BammannChiesaJohnsonPlasticity

set_theme!(theme_latexfonts())

PlasticityBase.materialproperties(::Type{DK}) = Dict(
    # Comment,For Calibration with vumat
    "C01"       => 35016459.896579415,
    "C02"       => 323.93342698083165,
    "C03"       => 500340419.8337271,
    "C04"       => 143.08381901004486,
    "C05"       => 4.101775377562497,
    "C06"       => 271.0245526,
    "C07"       => 1.0834796217232945e-06,
    "C08"       => 1023.6278003945317,
    "C09"       => 2358205093.844017,
    "C10"       => 676421.9935474312,
    "C11"       => 1.3465080192134937e-10,
    "C12"       => 98.35671405000001,
    "C13"       => 2.533629073577668e-09,
    "C14"       => 403.2291451343492,
    "C15"       => 1159915808.5023918,
    "C16"       => 959557.0948847248,
    "C17"       => 6.204370386543724e-12,
    "C18"       => 203.95288011132806,
    "C19"       => 1e-10,
    "C20"       => 1e-10,
    "Bulk Mod"  => 159000000000.0,
    "Shear Mod" => 77000000000.0,
)
PlasticityBase.materialconstants(::Type{DK}) = Dict(
    "C01"       => 35016459.896579415,
    "C02"       => 323.93342698083165,
    "C03"       => 500340419.8337271,
    "C04"       => 143.08381901004486,
    "C05"       => 4.101775377562497,
    "C06"       => 271.0245526,
    "C07"       => 1.0834796217232945e-06,
    "C08"       => 1023.6278003945317,
    "C09"       => 2358205093.844017,
    "C10"       => 676421.9935474312,
    "C11"       => 1.3465080192134937e-10,
    "C12"       => 98.35671405000001,
    "C13"       => 2.533629073577668e-09,
    "C14"       => 403.2291451343492,
    "C15"       => 1159915808.5023918,
    "C16"       => 959557.0948847248,
    "C17"       => 6.204370386543724e-12,
    "C18"       => 203.95288011132806,
    "C19"       => 1e-10,
    "C20"       => 1e-10,
)
PlasticityBase.materialconstants_index(::Type{DK}) = [
    "C01",
    "C02",
    "C03",
    "C04",
    "C05",
    "C06",
    "C07",
    "C08",
    "C09",
    "C10",
    "C11",
    "C12",
    "C13",
    "C14",
    "C15",
    "C16",
    "C17",
    "C18",
    "C19",
    "C20",
]
constantsrange_max = [
    300.,   # A
    400.,   # B
    1.,     # n
    0.1,    # C
    0.5,    # m
]

PlasticityCalibratinator.characteristicequations(::Type{DK}) = [
    # plasticstrainrate
    L"\dot{\epsilon}_{p} = f(\theta)\sinh\left[ \frac{ \{|\mathbf{\xi}| - \kappa - Y(\theta) \} }{ (1 - \phi)V(\theta) } \right]\frac{\mathbf{\xi}'}{|\mathbf{\xi}'|}\text{, let }\mathbf{\xi}' = \mathbf{\sigma}' - \mathbf{\alpha}'",
    # kinematic hardening
    L"\dot{\mathbf{\alpha}} = h(\theta)\dot{\epsilon}_{p} - [r_{d}(\theta)|\dot{\epsilon}_{p}| + r_{s}(\theta)]|\mathbf{\alpha}|\mathbf{\alpha}",
    # isotropic hardening
    L"\dot{\kappa} = H(\theta)\dot{\epsilon}_{p} - [R_{d}(\theta)|\dot{\epsilon}_{p}| + R_{s}(\theta)]\kappa^{2}",
    # flow rule
    L"F = |\sigma - \alpha| - \kappa - \beta(|\dot{\epsilon}_{p}|, \theta)",
    # initial yield stress beta
    L"\beta(\dot{\epsilon}_{p}, \theta) = Y(\theta) + V(\theta)\sinh^{-1}\left(\frac{|\dot{\epsilon}_{p}|}{f(\theta)}\right)"
]
PlasticityCalibratinator.dependenceequations(::Type{DK})     = [
    L"V = C_{ 1} \mathrm{exp}(-C_{ 2} / \theta)",       # V
    L"Y = C_{ 3} \mathrm{exp}( C_{ 4} / \theta)",       # Y
    L"f = C_{ 5} \mathrm{exp}(-C_{ 6} / \theta)",       # f
    L"r_{d} = C_{ 7} \mathrm{exp}(-C_{ 8} / \theta)",   # rd
    L"h = C_{ 9} - C_{10}\theta",                       # h
    L"r_{s} = C_{11} \mathrm{exp}(-C_{12} / \theta)",   # rs
    L"R_{d} = C_{13} \mathrm{exp}(-C_{14} / \theta)",   # Rd
    L"H = C_{15} - C_{16}\theta",                       # H
    L"R_{s} = C_{17} \mathrm{exp}(-C_{18} / \theta)",   # Rs
    L"Y_{adj}",                                         # Yadj
]
PlasticityCalibratinator.dependencesliders(::Type{DK})       = [
    # V
    [
        (label=L"C_{ 1}", range=range(0., 5materialconstants(DK)["C01"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C01"]), # , width=0.4w[]))
        (label=L"C_{ 2}", range=range(0., 5materialconstants(DK)["C02"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C02"]), # , width=0.4w[]))
    ],
    # Y
    [
        (label=L"C_{ 3}", range=range(0., 5materialconstants(DK)["C03"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C03"]), # , width=0.4w[]))
        (label=L"C_{ 4}", range=range(0., 5materialconstants(DK)["C04"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C04"]), # , width=0.4w[]))
    ],
    # f
    [
        (label=L"C_{ 5}", range=range(0., 5materialconstants(DK)["C05"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C05"]), # , width=0.4w[]))
        (label=L"C_{ 6}", range=range(0., 5materialconstants(DK)["C06"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C06"]), # , width=0.4w[]))
    ],
    # rd
    [
        (label=L"C_{ 7}", range=range(0., 5materialconstants(DK)["C07"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C07"]), # , width=0.4w[]))
        (label=L"C_{ 8}", range=range(0., 5materialconstants(DK)["C08"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C08"]), # , width=0.4w[]))
    ],
    # h
    [
        (label=L"C_{ 9}", range=range(0., 5materialconstants(DK)["C09"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C09"]), # , width=0.4w[]))
        (label=L"C_{10}", range=range(0., 5materialconstants(DK)["C10"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C10"]), # , width=0.4w[]))
    ],
    # rs
    [
        (label=L"C_{11}", range=range(0., 5materialconstants(DK)["C11"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C11"]), # , width=0.4w[]))
        (label=L"C_{12}", range=range(0., 5materialconstants(DK)["C12"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C12"]), # , width=0.4w[]))
    ],
    # Rd
    [
        (label=L"C_{13}", range=range(0., 5materialconstants(DK)["C13"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C13"]), # , width=0.4w[]))
        (label=L"C_{14}", range=range(0., 5materialconstants(DK)["C14"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C14"]), # , width=0.4w[]))
    ],
    # H
    [
        (label=L"C_{15}", range=range(0., 5materialconstants(DK)["C15"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C15"]), # , width=0.4w[]))
        (label=L"C_{16}", range=range(0., 5materialconstants(DK)["C16"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C16"]), # , width=0.4w[]))
    ],
    # Rs
    [
        (label=L"C_{17}", range=range(0., 5materialconstants(DK)["C17"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C17"]), # , width=0.4w[]))
        (label=L"C_{18}", range=range(0., 5materialconstants(DK)["C18"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C18"]), # , width=0.4w[]))
    ],
    # Yadj
    [
        (label=L"C_{19}", range=range(0., 5materialconstants(DK)["C19"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C19"]), # , width=0.4w[]))
        (label=L"C_{20}", range=range(0., 5materialconstants(DK)["C10"]; length=1_000), format="{:.3e}", startvalue=materialconstants(DK)["C10"]), # , width=0.4w[]))
    ],
]

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
function PlasticityCalibratinator.calibration_init(::Type{DK}, modelinputs::ModelInputs, params)::ModelData
    # files, incnum, params, Scale_MPa
    files = modelinputs.expdatasets
    incnum = modelinputs.incnum
    Scale_MPa = modelinputs.stressscale
    istate = Int(modelinputs.loading_axial)
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
        "Model_alph"    => [],
        "Model_kap"     => [],
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
            # test_data, test_cond, incnum, istate, params, i, ISV_Model
            sol = bcjmetalcalibration_kernel(test_data, test_cond, incnum, istate, params, i, DK)
            # test_data[i][1] = [E,S,Al,kap,tot,SVM]             #Store model stress/strain data
            # push!(test_data["Model_E"],     E)
            # push!(test_data["Model_S"],     S)
            # push!(test_data["Model_alph"],  Al)
            # push!(test_data["Model_kap"],   κ)
            # push!(test_data["Model_tot"],   Tot)
            # push!(test_data["Model_VM"],    SVM)
            push!(test_data["Model_E"],     (i, sol.ϵ))
            push!(test_data["Model_S"],     (i, sol.σ))
            push!(test_data["Model_alph"],  (i, sol.α))
            push!(test_data["Model_kap"],   (i, sol.κ))
            push!(test_data["Model_VM"],    (i, sol.σvM))
        end
        for key in ("Model_E", "Model_S", "Model_alph", "Model_kap", "Model_VM")
            for (i, x) in enumerate(sort(test_data[key], by=x->first(x)))
                test_data[key][i] = last(x)
            end
        end
    end
    return ModelData{DK}(DK, modelinputs, nsets, test_data, test_cond, params, deepcopy(materialconstants(DK)), deepcopy(materialconstants(DK)), incnum, Scale_MPa)
end

function PlasticityCalibratinator.dataseries_init(::Type{DK}, nsets, test_data)
    plot_isvs = []
    dataseries = if !isempty(plot_isvs)
        [[], [], [], []]
    else
        [[], []]
    end
    if nsets > 0
        for i in range(1, nsets)
            push!(dataseries[1], Observable(DataFrame(x=test_data["Data_E"][i], y=test_data["Data_S"][i])))
            push!(dataseries[2], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_VM"][i])))
            if !isempty(plot_isvs)
                push!(dataseries[3], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_alph"][i])))
                push!(dataseries[4], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_kap"][i])))
                # push!(dataseries[5], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_tot"][i])))
                # push!(dataseries[6], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_S"][i])))
            end
        end
    end
    return dataseries
end

function PlasticityCalibratinator.plot_sets!(::Type{DK}, modelcalibration)
    # ax, dataseries, Scale_MPa
    Plot_ISVs = []
    for i in range(1, modelcalibration[].modeldata.nsets)
        println(i)
        scatter!(modelcalibration[].ax,    @lift(Point2f.($(modelcalibration[].dataseries[1][i]).x, $(modelcalibration[].dataseries[1][i]).y)),
            color=i, colormap=:viridis, colorrange=(1, modelcalibration[].modeldata.nsets), label="Data - " * modelcalibration[].modeldata.test_cond["Name"][i])
        lines!(modelcalibration[].ax,      @lift(Point2f.($(modelcalibration[].dataseries[2][i]).x, $(modelcalibration[].dataseries[2][i]).y)),
            color=i, colormap=:viridis, colorrange=(1, modelcalibration[].modeldata.nsets), label="VM Model - " * modelcalibration[].modeldata.test_cond["Name"][i])
        if !isempty(Plot_ISVs)
            scatter!(modelcalibration[].ax_isv,    @lift(Point2f.($(modelcalibration[].dataseries[3][i]).x, $(modelcalibration[].dataseries[3][i]).y)),
                color=i, colormap=:viridis, colorrange=(1, modelcalibration[].modeldata.nsets), label=(s->L"$\alpha$ - %$(s)")(modelcalibration[].modeldata.test_cond["Name"][i]))
            lines!(modelcalibration[].ax_isv,      @lift(Point2f.($(modelcalibration[].dataseries[4][i]).x, $(modelcalibration[].dataseries[4][i]).y)),
                color=i, colormap=:viridis, colorrange=(1, modelcalibration[].modeldata.nsets), label=(s->L"$\kappa$ - %$(s)")(modelcalibration[].modeldata.test_cond["Name"][i]))
            # scatter(modelcalibration[].ax_isv,     @lift(Point2f.($(dataseries[5][i]).x, $(dataseries[5][i]).y)),
            #     color=i, colormap=:viridis , label="\$total\$ - " * bcj.test_cond["Name"][i]))
            # lines(modelcalibration[].ax_isv,       @lift(Point2f.($(dataseries[6][i]).x, $(dataseries[6][i]).y)),
            #     color=i, colormap=:viridis , label="\$S_{11}\$ - " * bcj.test_cond["Name"][i]))
        end
    end
end

function PlasticityCalibratinator.calibration_update!(::Type{DK}, i, BCJ::ModelData)
    for (key, val) in BCJ.params
        BCJ.materialproperties[key] = val
    end
    # sol = jccalibration_kernel(jc.test_data, jc.test_cond, jc.incnum, jc.materialproperties, i)
    sol = bcjmetalcalibration_kernel(BCJ.test_data, BCJ.test_cond, BCJ.incnum, Int64(BCJ.modelinputs.loading_axial), BCJ.materialproperties, i, DK)
    BCJ.test_data["Model_S"][i]    .= sol.σ
    BCJ.test_data["Model_VM"][i]   .= sol.σvM
    BCJ.test_data["Model_alph"][i] .= sol.α
    BCJ.test_data["Model_kap"][i]  .= sol.κ
    return nothing
end

function PlasticityCalibratinator.update!(::Type{DK}, modelcalibration)
    Plot_ISVs = []
    # dataseries, incnum, Scale_MPa
    @sync @distributed for i in range(1, modelcalibration[].modeldata.nsets)
    # for i in range(1, modelcalibration.modeldata.nsets)
        calibration_update!(DK, i, modelcalibration[].modeldata)
        modelcalibration[].dataseries[2][i][].y .= modelcalibration[].modeldata.test_data["Model_VM"][i]
        if !isempty(Plot_ISVs)
            modelcalibration[].dataseries[3][i][].y .= modelcalibration[].modeldata.test_data["Model_alph"][i]
            modelcalibration[].dataseries[4][i][].y .= modelcalibration[].modeldata.test_data["Model_kap"][i]
            # modelcalibration[].dataseries[5][i][].y .= modelcalibration[].modeldata.test_data["Model_tot"][i]
            # modelcalibration[].dataseries[6][i][].y .= modelcalibration[].modeldata.test_data["Model_S"][i]
        end
        for ds in modelcalibration[].dataseries[2:end]
            notify(ds[i])
        end
    end
    return nothing
end