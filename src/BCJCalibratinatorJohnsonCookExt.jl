struct JCExperimentalData
    nsets       ::Int64
    test_data   ::Dict{String, Vector}
    test_cond   ::Dict{String, Vector}
    params      ::Dict{String, Float64}
end

function dataseries_init(::Type{JC}, nsets, test_data)
    dataseries = [[],[]]
    for i in range(1, nsets)
        push!(dataseries[1], Observable(DataFrame(x=test_data["Data_E"][i], y=test_data["Data_S"][i])))
        push!(dataseries[2], Observable(DataFrame(x=test_data["Model_E"][i], y=test_data["Model_VM"][i])))
    end
    return dataseries
end

function jccalibration_kernel(test_data, test_cond, incnum, params, i)::NamedTuple
    emax        = maximum(test_data["Data_E"][i])
    # println("Setup: emax for set ", i, " = ", emax)
    jc_loading     = JCStrainControl(
        test_cond["Temp"][i], test_cond["StrainRate"][i],
        emax, incnum, params)
    jc_configuration    = jcreferenceconfiguration(JC, jc_loading)
    jc_reference        = jc_configuration[1]
    jc_current          = jc_configuration[2]
    jc_history          = jc_configuration[3]
    solve!(jc_current, jc_history)
    # println("Solved: emax for set ", i, " = ", maximum(jc_history.ϵ))
    return (ϵ=jc_history.ϵ, σ=jc_history.σ, σvM=jc_history.σ)
end

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
function jccalibration_init(files, incnum, params, Scale_MPa)::JCExperimentalData
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



    # -----------------------------------------------




    # -----------------------------------------------------
    # Calculate the model's initial stress-strain curve 
    # -----------------------------------------------------

    # FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
    # For each set, calculate the model curve and error
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
    return JCExperimentalData(nsets, test_data, test_cond, params)
end

function jccalibration_update!(JC::JCExperimentalData, incnum, i, Scale_MPa)
    sol = jccalibration_kernel(JC.test_data, JC.test_cond, incnum, JC.params, i)
    JC.test_data["Model_S"][i]    .= sol.σ .* Scale_MPa
    JC.test_data["Model_VM"][i]   .= sol.σvM
    return nothing
end

function plot_sets!(ax, dataseries, JC::JCExperimentalData, Scale_MPa)
    for i in range(1, JC.nsets)
        scatter!(ax,    @lift(Point2f.($(dataseries[1][i]).x, $(dataseries[1][i]).y)),
            color=i, colormap=:viridis, colorrange=(1, JC.nsets), label="Data - " * JC.test_cond["Name"][i])
        lines!(ax,      @lift(Point2f.($(dataseries[2][i]).x, $(dataseries[2][i]).y .* Scale_MPa)),
            color=i, colormap=:viridis, colorrange=(1, JC.nsets), label="VM Model - " * JC.test_cond["Name"][i])
    end
end

function update!(dataseries, JC::JCExperimentalData, incnum, Scale_MPa)
    @sync @distributed for i in range(1, JC.nsets)
    # for i in range(1, nsets)
        jccalibration_update!(JC, incnum, i, Scale_MPa)
        dataseries[2][i][].y .= JC.test_data["Model_VM"][i]
        for ds in dataseries[2:end]
            notify(ds[i])
        end
    end
    return nothing
end