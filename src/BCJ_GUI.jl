using CSV
using DataFrames
using Distributed
using GLMakie

struct BCJ_metal_calibrate
    nsets       ::Int64
    test_data   ::Dict{String, Vector}
    test_cond   ::Dict{String, Vector}
    params      ::Dict{String, Float64}
end

constant_string(i) = (i <= 9 ? "C0$i" : "C$i")

# lines[1] = data
# lines[2] = model (to be updated)
# lines[3] = alpha model (to be updated)
# lines[4] = kappa model (to be updated)
function dataseries_init(nsets, test_data, Plot_ISVs)
    dataseries = if Plot_ISVs
        [[],[],[],[],[],[]]
    else
        [[],[]]
    end

    for i in range(1, nsets)
        # println(test_data[i][1][0])
        # println(test_data[i][1][5])

        push!(dataseries[1], Observable(DataFrame(x=test_data["Data_E"][i], y=test_data["Data_S"][i])))
        push!(dataseries[2], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_VM"][i])))

        if Plot_ISVs
            push!(dataseries[3], Observable(DataFrame(x=test_data["Data_E"][i], y=test_data["Model_alph"][i])))
            push!(dataseries[4], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_kap"][i])))
            # push!(dataseries[5], Observable(DataFrame(x=test_data["Data_E"][i], y=test_data["Model_tot"][i])))
            # push!(dataseries[6], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_S"][i])))
        end
    end
    return dataseries
end

function BCJ_metal_calibrate_kernel(test_data, test_cond, incnum, istate, params, i)::NamedTuple
    kS          = 1     # default tension component
    if istate == 2
        kS      = 4     # select torsion component
    end
    emax        = maximum(test_data["Data_E"][i])
    # println('Setup: emax for set ',i,' = ', emax)
    bcj_ref     = BCJ_metal(
        test_cond["Temp"][i], test_cond["StrainRate"][i],
        emax, incnum, istate, params)
    bcj_current = BCJ_metal_currentconfiguration_init(bcj_ref)
    solve!(bcj_current)
    ϵₙ          = bcj_current.ϵₜₒₜₐₗ
    Sₙ          = bcj_current.S
    α           = bcj_current.α
    κ           = bcj_current.κ
    Tot         = bcj_current.Tot

    # pull only the relevant (tension/torsion) strain being evaluated:
    E       = ϵₙ[kS, :]
    S       = Sₙ[kS, :]
    SVM     = sum(map.(x->x^2., [Sₙ[1, :] - Sₙ[2, :], Sₙ[2, :] - Sₙ[3, :], Sₙ[3, :] - Sₙ[1, :]])) + (
        6sum(map.(x->x^2., [Sₙ[4, :], Sₙ[5, :], Sₙ[6, :]])))
    SVM     = sqrt.(SVM .* 0.5)
    Al      = α[kS, :]
    return (E=E, S=S, SVM=SVM, Al=Al, κ=κ, Tot=Tot)
end

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
function BCJ_metal_calibrate_init(files, incnum, istate, params, Scale_MPa)::BCJ_metal_calibrate
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
        "Model_VM"      => [],
        "Model_alph"    => [],
        "Model_kap"     => [],
        "Model_tot"     => []
    )
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

        #store the stress-strain data
        # push!(test_cond["StrainRate"],  first(er))
        # push!(test_cond["Temp"],        first(T))
        # push!(test_cond["Name"],        first(name))
        # push!(test_data["Data_E"],      strn)
        # push!(test_data["Data_S"],      strs)
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



    # -----------------------------------------------




    # -----------------------------------------------------
    # Calculate the model's initial stress-strain curve 
    # -----------------------------------------------------

    # FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
    # For each set, calculate the model curve and error
    @sync @distributed for i in range(1, nsets)
    # for i in range(1, nsets)
        sol = BCJ_metal_calibrate_kernel(test_data, test_cond, incnum, istate, params, i)
        # test_data[i][1] = [E,S,Al,kap,tot,SVM]             #Store model stress/strain data
        # push!(test_data["Model_E"],     E)
        # push!(test_data["Model_S"],     S)
        # push!(test_data["Model_alph"],  Al)
        # push!(test_data["Model_kap"],   κ)
        # push!(test_data["Model_tot"],   Tot)
        # push!(test_data["Model_VM"],    SVM)
        push!(test_data["Model_E"],     (i, sol.E))
        push!(test_data["Model_S"],     (i, sol.S))
        push!(test_data["Model_alph"],  (i, sol.Al))
        push!(test_data["Model_kap"],   (i, sol.κ))
        push!(test_data["Model_tot"],   (i, sol.Tot))
        push!(test_data["Model_VM"],    (i, sol.SVM))
    end
    for key in ("Model_E", "Model_S", "Model_alph", "Model_kap", "Model_tot", "Model_VM")
        for (i, x) in enumerate(sort(test_data[key], by=x->first(x)))
            test_data[key][i] = last(x)
        end
    end
    return BCJ_metal_calibrate(nsets, test_data, test_cond, params)
end

function BCJ_metal_calibrate_update!(BCJ::BCJ_metal_calibrate, incnum, istate, i)
    sol = BCJ_metal_calibrate_kernel(BCJ.test_data, BCJ.test_cond, incnum, istate, BCJ.params, i)
    BCJ.test_data["Model_VM"][i]   .= sol.SVM
    BCJ.test_data["Model_alph"][i] .= sol.Al
    BCJ.test_data["Model_kap"][i]  .= sol.κ
    BCJ.test_data["Model_tot"][i]  .= sol.Tot
    BCJ.test_data["Model_S"][i]    .= sol.S
    return nothing
end

function plot_sets!(ax, dataseries, BCJ::BCJ_metal_calibrate, Plot_ISVs)
    for i in range(1, BCJ.nsets)
        scatter!(ax,    @lift(Point2f.($(dataseries[1][i]).x, $(dataseries[1][i]).y)),
            colormap=:viridis, colorrange=(1, BCJ.nsets), label="Data - " * BCJ.test_cond["Name"][i])
        lines!(ax,      @lift(Point2f.($(dataseries[2][i]).x, $(dataseries[2][i]).y)),
            colormap=:viridis, colorrange=(1, BCJ.nsets), label="VM Model - " * BCJ.test_cond["Name"][i])
        if Plot_ISVs
            scatter!(ax,    @lift(Point2f.($(dataseries[3][i]).x, $(dataseries[3][i]).y)),
                colormap=:viridis, colorrange=(1, BCJ.nsets), label="\$\\alpha\$ - " * BCJ.test_cond["Name"][i])
            lines!(ax,      @lift(Point2f.($(dataseries[4][i]).x, $(dataseries[4][i]).y)),
                colormap=:viridis, colorrange=(1, BCJ.nsets), label="\$\\kappa\$ - " * BCJ.test_cond["Name"][i])
            # scatter(ax,     @lift(Point2f.($(dataseries[5][i]).x, $(dataseries[5][i]).y)),
            #     colormap=:viridis , label="\$total\$ - " * bcj.test_cond["Name"][i]))
            # lines(ax,       @lift(Point2f.($(dataseries[6][i]).x, $(dataseries[6][i]).y)),
            #     colormap=:viridis , label="\$S_{11}\$ - " * bcj.test_cond["Name"][i]))
        end
    end
end

function update!(ax, leg, dataseries, BCJ::BCJ_metal_calibrate, incnum, istate, Plot_ISVs)
    @sync @distributed for i in range(1, BCJ.nsets)
    # for i in range(1, nsets)
        BCJ_metal_calibrate_update!(BCJ, incnum, istate, i)
        dataseries[2][i][].y .= BCJ.test_data["Model_VM"][i]
        if Plot_ISVs
            dataseries[3][i][].y .= BCJ.test_data["Model_alph"][i]
            dataseries[4][i][].y .= BCJ.test_data["Model_kap"][i]
            # dataseries[5][i][].y .= BCJ.test_data["Model_tot"][i]
            # dataseries[6][i][].y .= BCJ.test_data["Model_S"][i]
        end
        for ds in dataseries[2:end]
            notify(ds[i])
        end
    end
    return nothing
end