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
        update_observablevector!(expdatasets, filelist)
        expdatasets_textbox.stored_string[] = join(filelist, "\n")
        expdatasets_textbox.displayed_string[] = join(filelist, "\n")
    end
    return nothing
end

function update_experimentaldata_draganddrop!(expdatasets, expdatasets_textbox, filedump)
    if !isempty(filedump)
        update_observablevector!(expdatasets, filedump)
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

function constructgrid_slider!(grid, sliders)
    # println(labels)
    if isa(sliders, NamedTuple)
        # println(@__LINE__, ", Returning...")
        return SliderGrid(grid[1, 1], sliders)
    else
        return [begin
            # println((i, label))
            constructgrid_slider!(grid[ i,  1], slider)
        end for (i, slider) in enumerate(sliders)]
    end
end

function reset_sliders!(sg_sliders, dict, model_data, model_calibration)
    nsliders = length(collectragged(sg_sliders[]))
    # println(nsliders)
    println(dict)
    # for (i, (key, val), sgc) in zip(range(1, nsliders), dict, collectragged(sg_sliders[]))
    #     println((i, key, val))
    #     model_data[].params[key]                    = to_value(val); notify(model_data)
    #     model_calibration[].modeldata.params[key]   = to_value(val); notify(model_calibration)
    #     set_close_to!(sgc.sliders[1], val)
    #     sgc.sliders[1].value[]                      = to_value(val); notify(sgc.sliders[1].value)
    # end
    asyncmap((i, (key, val), sgc)->begin # attempt multi-threading
            println((i, key, val))
            model_data[].params[key]                    = to_value(val); notify(model_data)
            model_calibration[].modeldata.params[key]   = to_value(val); notify(model_calibration)
            set_close_to!(sgc.sliders[1], val)
            sgc.sliders[1].value[]                      = to_value(val); notify(sgc.sliders[1].value)
        end, range(1, nsliders), dict, collectragged(sg_sliders[]))
    return nothing
end

function clearplot!(model_calibration)
    empty!(model_calibration[].ax)
    if !isnothing(model_calibration[].leg)
        delete!(model_calibration[].leg); notify(model_calibration)
    end
    return nothing
end

# update input parameters to calibrate
function update_modelinputs!(fig_b, fig_d,
        plasticmodeltypeversion_menu, propsfile_textbox, expdatasets_textbox,
        loaddir_axial_toggle, loaddir_torsion_toggle,
        incnum_textbox, stressscale_textbox, model_inputs, model_data, model_calibration,
        sliders_grid, sliders_toggles, sliders_labels, sliders_sliders)
    clearplot!(model_calibration)
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
        constructgrid_slider!(sliders_grid[][i, 3], d) for (i, d) in enumerate(model_inputs[].dependence_sliders)])
    # reset_sliders!(sliders_sliders, model_data, model_calibration)
    model_calibration[].dataseries           = plotdata_initialize(model_inputs[].plasticmodelversion,
        model_calibration[].modeldata.nsets, model_calibration[].modeldata.test_data);                        notify(model_calibration)
    plotdata_insert!(model_inputs[].plasticmodelversion, model_calibration)
    first(model_calibration[].modeldata.modelinputs.expdatasets) != "" ? (model_calibration[].leg = axislegend(model_calibration[].ax, position=:rb)) : nothing; notify(model_calibration)
    return model_inputs, model_data, model_calibration, sliders_sliders
end

function doratheexplorer_sliders(model_calibration, model_data, dora_sliders) # (fig_d, model_calibration, model_data, sliders_sliders, dora_sliders)
    fig = Figure(size=(450, 600), layout=GridLayout(2, 1))
    temperature_strainrate_grid = GridLayout(fig[1, 1], 4, 2; tellwidth=false)
    temperature_label           = Label(temperature_strainrate_grid[1, 1], L"T")
    temperature_textbox       = Textbox(temperature_strainrate_grid[1, 2], placeholder="300",
        width=5fig.scene.theme.fontsize[], stored_string="300", displayed_string="300", halign=:left)
    strainrate_label            = Label(temperature_strainrate_grid[2, 1], L"\dot{\epsilon}")
    strainrate_textbox        = Textbox(temperature_strainrate_grid[2, 2], placeholder="1",
        width=5fig.scene.theme.fontsize[], stored_string="1", displayed_string="1", halign=:left)
    finalstrain_label           = Label(temperature_strainrate_grid[3, 1], L"\epsilon_{n}")
    finalstrain_textbox       = Textbox(temperature_strainrate_grid[3, 2], placeholder="1",
        width=5fig.scene.theme.fontsize[], stored_string="1", displayed_string="1", halign=:left)
    updateinputs_button        = Button(temperature_strainrate_grid[1, 4][1, 1], label="Update Inputs")
    resetsliders_button        = Button(temperature_strainrate_grid[1, 4][2, 1], label="Reset Sliders")

    collectrangefromstring(str) = begin
        try
            [parse(Float64, str)]
        catch exc
            try
                parse.(Float64, split(match(r"[^\{\[\(].+[^\}\]\)]", str).match, ','))
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
    # println(temperatures)
    strainrates     = Observable(collectrangefromstring(strainrate_textbox.displayed_string[]))
    # println(strainrates)
    finalstrains    = Observable(collectrangefromstring(finalstrain_textbox.displayed_string[]))
    # println(finalstrains)
    nsets = @lift mapreduce(length, *, ($temperatures, $strainrates, $finalstrains))
    # println(nsets)

    model_data = @lift modeldora($model_data.modelinputs.plasticmodelversion, $model_data.modelinputs, materialproperties($model_data.modelinputs.plasticmodelversion), $temperatures, $strainrates, $finalstrains)
    dataseries = @lift plotdora_initialize($model_data.plasticmodelversion, $model_data.nsets, $model_data.test_data)
    # model_data[].nsets = nsets; notify(model_data)
    # model_data[].test_data = test_data; notify(model_data)
    # model_data[].test_cond = test_cond; notify(model_data)
    model_calibration[].modeldata = model_data[]; notify(model_calibration)
    model_calibration[].dataseries = dataseries[]; notify(model_calibration)

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

    on(updateinputs_button.clicks) do click
        clearplot!(model_calibration)
        update_observablevector!(temperatures, collectrangefromstring(temperature_textbox.displayed_string[]))
        update_observablevector!(strainrates, collectrangefromstring(strainrate_textbox.displayed_string[]))
        update_observablevector!(finalstrains, collectrangefromstring(finalstrain_textbox.displayed_string[]))
        # println(finalstrains)
        nsets = @lift mapreduce(length, *, ($temperatures, $strainrates, $finalstrains))
        # println(nsets)

        model_data = @lift modeldora($model_data.modelinputs.plasticmodelversion, $model_data.modelinputs, materialproperties($model_data.modelinputs.plasticmodelversion), $temperatures, $strainrates, $finalstrains)
        # fig_axleg = try
        #     axislegend(model_calibration[].ax, position=:rb)
        # catch exc
        #     nothing
        # end
        dataseries = @lift plotdora_initialize($model_data.plasticmodelversion, $model_data.nsets, $model_data.test_data)
        # model_data[].nsets = nsets; notify(model_data)
        # model_data[].test_data = test_data; notify(model_data)
        # model_data[].test_cond = test_cond; notify(model_data)
        model_calibration[].modeldata = model_data[]; notify(model_calibration)
        model_calibration[].dataseries = dataseries[]; notify(model_calibration)

        plotdora_insert!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
        model_calibration[].leg = try
            axislegend(model_calibration[].ax, position=:rb)
        catch exc
            nothing
        end; notify(model_calibration)
        # update!(dataseries[], bcj[], incnum[], istate[], Plot_ISVs[], BCJMetal[])
        plotdora_update!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
    end
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
    display(GLMakie.Screen(; title="[Explorer Mode] Test Conditions", focus_on_show=true), fig)
    # screen_sliders(fig_d, model_calibration, model_data, sliders_sliders)
    # empty!(fig_d)
    fig_d = Figure(size=(450, 600))
    sliders_grid    = GridLayout(fig_d[1, 1], length(model_data[].modelinputs.dependence_equations), 3)
    # println(@__LINE__, ", Made it here...")
    sliders_toggles = [ # add toggles for which to calibrate
        constructgrid_toggle!(sliders_grid[i, 1]) for i in range(1, length(model_data[].modelinputs.dependence_equations))]
    # notify(sliders_toggles)
    sliders_labels  = [ # label each slider with equation
        constructgrid_depeqlabel!(sliders_grid[i, 2], eq) for (i, eq) in enumerate(model_data[].modelinputs.dependence_equations)]
    # notify(sliders_labels)
    # println(@__LINE__, ", Made it here...")
    # println(typeof([
    #     sg_slider!(sliders_grid[][i, 3], modelinputs[].dependence_sliders[i]) for i in range(1, length(modelinputs[].dependence_sliders))]))
    sliders_sliders = Observable([
        constructgrid_slider!(sliders_grid[i, 3], model_data[].modelinputs.dependence_sliders[i]) for i in range(1, length(model_data[].modelinputs.dependence_sliders))])
    ### update curves from sliders
    @lift for (key, sgs) in zip(keys(materialconstants(model_calibration[].modeldata.plasticmodelversion)), collectragged($sliders_sliders))
        on(only(sgs.sliders).value) do val
            # redefine materialproperties with new slider values
            model_data[].params[key] = to_value(val); notify(model_data)
            model_calibration[].modeldata.params[key] = to_value(val); notify(model_calibration)
            plotdora_update!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
        end
    end
    on(resetsliders_button.clicks) do click
        # # for (i, c, sgc) in zip(range(1, nsliders), C_0, sg_sliders)
        # #     params[][BCJinator.constant_string(i)] = to_value(c);         notify(params)
        # #     set_close_to!(sgc.sliders[1], c)
        # #     sgc.sliders[1].value[] = to_value(c);                   notify(sgc.sliders[1].value)
        # # end
        # asyncmap((i, c, sgc)->begin # attempt multi-threading
        #         params[][BCJinator.constant_string(i)] = to_value(c);     notify(params)
        #         set_close_to!(sgc.sliders[1], c)
        #         sgc.sliders[1].value[] = to_value(c);               notify(sgc.sliders[1].value)
        #     end, range(1, nsliders), C_0, sg_sliders)
        reset_sliders!(sliders_slidersdora, materialdora(model_calibration[].modeldata.plasticmodelversion), model_data, model_calibration)
        reset_sliders!(sliders_sliders, materialconstants(model_calibration[].modeldata.plasticmodelversion), model_data, model_calibration)
    end
    display(GLMakie.Screen(; title="[Explorer Mode] Sliders", focus_on_show=true), fig_d)
end