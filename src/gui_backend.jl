using Distributed
using GLMakie
using PlasticityBase
using NativeFileDialog

function update_observablevector!(obs, arr)
    u, v = length(obs[]), length(arr)
    if u > v
        for (i, x) in enumerate(arr)
            obs[][i] = x;                   notify(obs)
        end
        for i in range(u, v + 1; step=-1)
            deleteat!(obs[], i);            notify(obs)
        end
    elseif u < v
        for (i, file) in enumerate(arr[begin:u])
            obs[][i] = file;                notify(obs)
        end
        append!(obs[], arr[u + 1:end]);     notify(obs)
    else
        obs[] .= arr
    end; notify(obs)
    return nothing
end

function update_propsfile!(propsfile, propsfile_textbox)
    file = pick_file(; filterlist="csv")
    if file != ""
        propsfile[] = file; notify(propsfile)
        propsfile_textbox.displayed_string[] = file
    end
    return nothing
end

function update_experimentaldata_browse!(expdatasets, expdatasets_textbox)
    filelist = pick_multi_file(; filterlist="csv")
    if !isempty(filelist)
        # println(filelist)
        # expdatasets[] = filelist; notify(expdatasets)
        update_observablevector!(expdatasets, filelist)
        # u, v = length(expdatasets[]), length(filelist)
        # if u > v
        #     for (i, file) in enumerate(filelist)
        #         expdatasets[][i] = file;                    notify(expdatasets)
        #     end
        #     for i in range(u, v + 1; step=-1)
        #         deleteat!(expdatasets[], i);                notify(expdatasets)
        #     end
        # elseif u < v
        #     for (i, file) in enumerate(filelist[begin:u])
        #         expdatasets[][i] = file;                    notify(expdatasets)
        #     end
        #     append!(expdatasets[], filelist[u + 1:end]);    notify(expdatasets)
        # else
        #     expdatasets[] .= filelist
        # end;                                                notify(expdatasets)
        expdatasets_textbox.stored_string[] = join(filelist, "\n")
        expdatasets_textbox.displayed_string[] = join(filelist, "\n")
    end
    return nothing
end

function update_experimentaldata_draganddrop!(expdatasets, expdatasets_textbox, filedump)
    if !isempty(filedump)
        update_observablevector!(expdatasets, filelist)
        # u, v = length(expdatasets[]), length(filedump)
        # if u > v
        #     for (i, file) in enumerate(filedump)
        #         expdatasets[][i] = file;                    notify(expdatasets)
        #     end
        #     for i in range(u, v + 1; step=-1)
        #         deleteat!(expdatasets[], i);                notify(expdatasets)
        #     end
        # elseif u < v
        #     for (i, file) in enumerate(filedump[begin:u])
        #         expdatasets[][i] = file;                    notify(expdatasets)
        #     end
        #     append!(expdatasets[], filedump[u + 1:end]);    notify(expdatasets)
        # else
        #     expdatasets[] .= filedump
        # end;                                                notify(expdatasets)
        expdatasets_textbox.stored_string[] = join(filedump, "\n")
        expdatasets_textbox.displayed_string[] = join(filedump, "\n")
    end
    return nothing
end

function collectragged!(dest, src)
    for element = src
        issingleelement = try
            isempty(size(element))
        catch exc
            if isa(exc, MethodError)
                isa(element, SliderGrid)
            end
        end
        if issingleelement
            push!(dest, element)
        else
            collectragged!(dest, element)
        end
    end
    return nothing
end

@inline function collectragged(src)
    arr = []; collectragged!(arr, src)
    return arr
end

constructgrid_chareqlabel!(grid, eqstr) = Label(grid, eqstr; halign=:left)
constructgrid_depeqlabel!(grid, eqstr)  = constructgrid_chareqlabel!(grid, eqstr)
constructgrid_toggle!(grid)             = Toggle(grid; active=false)

function constructgrid_slider!(grid, labels)
    # println(labels)
    if isa(labels, NamedTuple)
        # println(@__LINE__, ", Returning...")
        return SliderGrid(grid[1, 1], labels)
    else
        return [begin
            # println((i, label))
            constructgrid_slider!(grid[ i,  1], label)
        end for (i, label) in enumerate(labels)]
    end
end

function reset_sliders!(sg_sliders, model_data, model_calibration)
    # nsliders = sum(length, modelinputs[].dependence_sliders)
    # nsliders = count(x->isa(x, NamedTuple), modelcalibration[].modeldata.modelinputs.dependence_sliders)
    # nsliders = count(x->isa(x, NamedTuple), collectragged(modelcalibration[].modeldata.modelinputs.dependence_sliders))
    nsliders = length(collectragged(sg_sliders[]))
    # println(nsliders)
    dict = materialconstants(model_calibration[].modeldata.plasticmodelversion) # sort(collect(modelcalibration[].modeldata.C_0), by=x->findfirst(x[1] .== materialconstants_index(modelcalibration[].modeldata.plasticmodelversion)))
    # println(dict)
    # for (i, key, (k, v), sgc) in zip(range(1, nsliders), materialconstants_index(modelcalibration[].modeldata.plasticmodelversion), dict, sg_sliders[])
    #     # println((i, key, dict[key]))
    #     modeldata[].params[key] = to_value(dict[key]); notify(modeldata)
    #     modelcalibration[].modeldata.params[key] = to_value(dict[key]);    notify(modelcalibration)
    #     set_close_to!(sgc.sliders[1], dict[key])
    #     sgc.sliders[1].value[] = to_value(dict[key]);   notify(sgc.sliders[1].value)
    # end
    asyncmap((i, key, (k, v), sgc)->begin # attempt multi-threading
            # println((i, key, dict[key]))
            model_data[].params[key] = to_value(dict[key]); notify(model_data)
            model_calibration[].modeldata.params[key] = to_value(dict[key]);    notify(model_calibration)
            set_close_to!(sgc.sliders[1], dict[key])
            sgc.sliders[1].value[] = to_value(dict[key]);   notify(sgc.sliders[1].value)
        end, range(1, nsliders), keys(materialconstants(model_calibration[].modeldata.plasticmodelversion)), dict, collectragged(sg_sliders[]))
    return nothing
end

# update input parameters to calibrate
function update_modelinputs!(fig_b, fig_d,
        plasticmodeltypeversion_menu, propsfile_textbox, expdatasets_textbox,
        loaddir_axial_toggle, loaddir_torsion_toggle,
        incnum_textbox, stressscale_textbox, model_inputs, model_data, model_calibration,
        sliders_grid, sliders_toggles, sliders_labels, sliders_sliders)
    empty!(model_calibration[].ax)
    if !isnothing(model_calibration[].leg)
        delete!(model_calibration[].leg); notify(model_calibration)
    end
    plasticmodelversion_temp       = plasticmodeltypeversion_menu.selection[]
    # println(plasticmodelversion_temp)
    propsfile_temp                 = if isnothing(propsfile_textbox.stored_string[])
        ""
    else
        propsfile_textbox.displayed_string[]
    end
    # println(model_inputs[].propsfile)
    expdatasets_temp = model_inputs[].expdatasets
    # println(model_inputs[].expdatasets)
    loading_axial_temp             = loaddir_axial_toggle.active[]
    loading_torsional_temp         = loaddir_torsion_toggle.active[]
    incnum_temp                    = parse(Int64, incnum_textbox.displayed_string[])
    stressscale_temp               = parse(Float64, stressscale_textbox.displayed_string[])
    characteristic_equations_temp  = characteristicequations(plasticmodelversion_temp)
    # println(characteristic_equations_temp)
    dependence_equations_temp      = dependenceequations(plasticmodelversion_temp)
    # println(dependence_equations_temp)
    dependence_sliders_temp        = dependencesliders(plasticmodelversion_temp)
    model_inputs                           = Observable(ModelInputs{plasticmodelversion_temp}(
        plasticmodelversion_temp, propsfile_temp, expdatasets_temp,
        loading_axial_temp, loading_torsional_temp,
        incnum_temp, stressscale_temp,
        characteristic_equations_temp,
        dependence_equations_temp,
        dependence_sliders_temp
    ))
    # println(model_inputs[].plasticmodelversion)
    # println(model_inputs[].characteristic_equations)

    model_data                       = Observable(modeldata(model_inputs[].plasticmodelversion, model_inputs[], materialproperties(model_inputs[].plasticmodelversion)))
    # println(model_data[].modelinputs.characteristic_equations)
    # notify(modeldata)
    # modeldataseries                 = Observable(dataseries_init(plasticmodelversion[], modeldata[].nsets, modeldata[].test_data))
    fig_axleg = try
        axislegend(model_calibration[].ax, position=:rb)
    catch exc
        nothing
    end
    # println(keys(model_data[].params))
    model_calibration                = Observable(ModelCalibration(
        model_data[], model_calibration[].ax, plotdata_initialize(model_data[].modelinputs.plasticmodelversion, model_data[].nsets, model_data[].test_data), fig_axleg))
    # println(model_calibration[].modeldata.modelinputs.characteristic_equations)
    # notify(modelcalibration)
    empty!(fig_d)
    sliders_grid[]    = GridLayout(fig_d[1, 1], length(model_inputs[].dependence_equations), 3); notify(sliders_grid)
    # println(@__LINE__, ", Made it here...")
    sliders_toggles[] = [ # add toggles for which to calibrate
        constructgrid_toggle!(sliders_grid[][i, 1]) for i in range(1, length(model_inputs[].dependence_equations))]
    notify(sliders_toggles)
    sliders_labels[]  = [ # label each slider with equation
        constructgrid_depeqlabel!(sliders_grid[][i, 2], eq) for (i, eq) in enumerate(model_inputs[].dependence_equations)]
    notify(sliders_labels)
    # println(@__LINE__, ", Made it here...")
    # println(typeof([
    #     sg_slider!(sliders_grid[][i, 3], modelinputs[].dependence_sliders[i]) for i in range(1, length(modelinputs[].dependence_sliders))]))
    sliders_sliders = Observable([
        constructgrid_slider!(sliders_grid[][i, 3], model_inputs[].dependence_sliders[i]) for i in range(1, length(model_inputs[].dependence_sliders))])
    reset_sliders!(sliders_sliders, model_data, model_calibration)
    model_calibration[].dataseries           = plotdata_initialize(model_inputs[].plasticmodelversion,
        model_calibration[].modeldata.nsets, model_calibration[].modeldata.test_data);                        notify(model_calibration)
    plotdata_insert!(model_inputs[].plasticmodelversion, model_calibration)
    first(model_calibration[].modeldata.modelinputs.expdatasets) != "" ? (model_calibration[].leg = axislegend(model_calibration[].ax, position=:rb)) : nothing; notify(model_calibration)
    return model_inputs, model_data, model_calibration, sliders_sliders
end

function doratheexplorer_sliders(fig_d, model_calibration, model_data, sliders_sliders, dora_sliders)
    fig = Figure(size=(450, 600), layout=GridLayout(2, 1))
    # temperature_strainrate_sliders = SliderGrid(fig[1, 1],
    #     (label=L"T",                range=range(0,  1000; length=1_000),    format="{:.3e}", startvalue=300),
    #     (label=L"\dot{\epsilon}",   range=range(10^-6, 10^9; length=1_000), format="{:.3e}", startvalue=1),
    #     (label=L"\epsilon_{final}", range=range(0, 100; length=1_000), format="{:.3e}", startvalue=1),
    # )
    temperature_strainrate_grid = GridLayout(fig[1, 1], 3, 2; tellwidth=false)
    temperature_label           = Label(temperature_strainrate_grid[1, 1], L"T")
    temperature_textbox       = Textbox(temperature_strainrate_grid[1, 2], placeholder="300",
        width=5fig.scene.theme.fontsize[], stored_string="300", displayed_string="300", halign=:left)
    strainrate_label            = Label(temperature_strainrate_grid[2, 1], L"\dot{\epsilon}")
    strainrate_textbox        = Textbox(temperature_strainrate_grid[2, 2], placeholder="1",
        width=5fig.scene.theme.fontsize[], stored_string="1", displayed_string="1", halign=:left)
    finalstrain_label           = Label(temperature_strainrate_grid[3, 1], L"\epsilon_{n}")
    finalstrain_textbox       = Textbox(temperature_strainrate_grid[3, 2], placeholder="1",
        width=5fig.scene.theme.fontsize[], stored_string="1", displayed_string="1", halign=:left)

    collectrangefromstring(str) = begin
        try
            [parse(Float64, str)]
        catch exc
            try
                parse.(Float64, split(match(r"[^\{\[\(].+[^\}\]\)]", str), ','))
            catch exc
                try
                    abstract_range = parse.(Float64, split(str, ':'))
                    if length(abstract_range) == 2
                        collect(abstract_range[1]:abstract_range[2])
                    elseif length(abstract_range) == 3
                        collect(abstract_range[1]:abstract_range[2]:abstract_range[3])
                    end
                catch exc
                    # println(exc)
                end
            end
        end
    end
    temperatures    = Observable(collectrangefromstring(temperature_textbox.displayed_string[]))
    on(temperature_textbox.displayed_string) do s
        update_observablevector!(temperatures, collectrangefromstring(s))
        # expdatasets_textbox.stored_string[] = join(filedump, "\n")
        # expdatasets_textbox.displayed_string[] = join(filedump, "\n")
    end
    # println(temperatures)
    strainrates     = Observable(collectrangefromstring(strainrate_textbox.displayed_string[]))
    on(strainrate_textbox.displayed_string) do s
        update_observablevector!(strainrates, collectrangefromstring(s))
    end
    # println(strainrates)
    finalstrains    = Observable(collectrangefromstring(finalstrain_textbox.displayed_string[]))
    on(finalstrain_textbox.displayed_string) do s
        update_observablevector!(finalstrains, collectrangefromstring(s))
    end
    # println(finalstrains)
    nsets = @lift mapreduce(length, *, ($temperatures, $strainrates, $finalstrains))
    # println(nsets)

    model_data = @lift modeldora($model_data.modelinputs.plasticmodelversion, $model_data.modelinputs, materialproperties($model_data.modelinputs.plasticmodelversion), $temperatures, $strainrates, $finalstrains)
    dataseries = plotdora_initialize(model_data[].plasticmodelversion, model_data[].nsets, model_data[].test_data)
    # model_data[].nsets = nsets; notify(model_data)
    # model_data[].test_data = test_data; notify(model_data)
    # model_data[].test_cond = test_cond; notify(model_data)
    model_calibration[].modeldata = model_data[]; notify(model_calibration)
    model_calibration[].dataseries = dataseries; notify(model_calibration)

    plotdora_insert!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
    model_calibration[].leg = try
        axislegend(model_calibration[].ax, position=:rb)
    catch exc
        nothing
    end; notify(model_calibration)
    # update!(dataseries[], bcj[], incnum[], istate[], Plot_ISVs[], BCJMetal[])
    # plotdora_update!(model_calibration[].modeldata.plasticmodelversion, model_calibration)

    dora_equations = @lift doraequations($(model_calibration).modeldata.plasticmodelversion)
    sliders_griddora    = @lift GridLayout(fig[2, 1], length($dora_equations), 3)
    sliders_togglesdora = Observable([ # add toggles for which to calibrate
        constructgrid_toggle!(sliders_griddora[][i, 1]) for i in range(1, length(dora_equations[]))])
    sliders_labelsdora  = Observable([ # label each slider with equation
        constructgrid_depeqlabel!(sliders_griddora[][i, 2], eq) for (i, eq) in enumerate(dora_equations[])])
    sliders_slidersdora = Observable([
        constructgrid_slider!(sliders_griddora[][i, 3], dora_sliders[i]) for i in range(1, length(dora_sliders))])
    # df_Tension_e002_295 = CSV.read("Data_Tension_e0002_T295.csv", DataFrame;
    #     header=true, delim=',', types=[Float64, Float64, Float64, Float64, String])
    # bcj_loading_Tension_e002_295 = BCJMetalStrainControl(295., 2e-3, 1., 200, 1, params)
    # # bcj_loading = BCJ_metal(295., 570., 0.15, 200, 1, params)
    # bcj_conf_Tension_e002_295 = referenceconfiguration(DK, bcj_loading_Tension_e002_295)
    # bcj_ref_Tension_e002_295        = bcj_conf_Tension_e002_295[1]
    # bcj_current_Tension_e002_295    = bcj_conf_Tension_e002_295[2]
    # bcj_history_Tension_e002_295    = bcj_conf_Tension_e002_295[3]
    # solve!(bcj_current_Tension_e002_295, bcj_history_Tension_e002_295)
    # σvM = symmetricvonMises(bcj_history_Tension_e002_295.σ__)
    # idx = []
    # for t in df_Tension_e002_295[!, "Strain"]
    #     j = findlast(bcj_history_Tension_e002_295.ϵ__[1, :] .<= t)
    #     push!(idx, !isnothing(j) ? j : findfirst(bcj_history_Tension_e002_295.ϵ__[1, :] .>= t))
    # end
    # temperature_slider  = temperature_strainrate_sliders.sliders[1]
    # strainrate_slider   = temperature_strainrate_sliders.sliders[2]
    # finalstrain_slider  = temperature_strainrate_sliders.sliders[3]
    # on(temperature_slider.value) do val
    #     # redefine materialproperties with new slider values
    #     model_data[].params[key] = to_value(val); notify(model_data)
    #     model_calibration[].modeldata.params[key] = to_value(val); notify(model_calibration)
    #     plotdata_update!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
    # end
    # on(temperature_slider.value) do val
    #     # redefine materialproperties with new slider values
    #     model_data[].params[key] = to_value(val); notify(model_data)
    #     model_calibration[].modeldata.params[key] = to_value(val); notify(model_calibration)
    #     plotdata_update!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
    # end
    # on(temperature_slider.value) do val
    #     # redefine materialproperties with new slider values
    #     model_data[].params[key] = to_value(val); notify(model_data)
    #     model_calibration[].modeldata.params[key] = to_value(val); notify(model_calibration)
    #     plotdata_update!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
    # end
    # for (key, sgs) in zip(keys(materialdora(model_calibration[].modeldata.plasticmodelversion)), temperature_strainrate_sliders.sliders)
    @lift for (key, sgs) in zip(keys(materialdora(model_calibration[].modeldata.plasticmodelversion)), collectragged($sliders_slidersdora))
        # on(sgs.value) do val
        on(only(sgs.sliders).value) do val
            # redefine materialproperties with new slider values
            model_data[].params[key] = to_value(val); notify(model_data)
            model_calibration[].modeldata.params[key] = to_value(val); notify(model_calibration)
            plotdora_update!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
        end
    end
    display(GLMakie.Screen(; title="Sliders", focus_on_show=true), fig)
    # screen_sliders(fig_d, model_calibration, model_data, sliders_sliders)
    ### update curves from sliders
    @lift for (key, sgs) in zip(keys(materialconstants(model_calibration[].modeldata.plasticmodelversion)), collectragged($sliders_sliders))
        on(only(sgs.sliders).value) do val
            # redefine materialproperties with new slider values
            model_data[].params[key] = to_value(val); notify(model_data)
            model_calibration[].modeldata.params[key] = to_value(val); notify(model_calibration)
            plotdora_update!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
        end
    end
    display(GLMakie.Screen(; title="Sliders", focus_on_show=true), fig_d)
end