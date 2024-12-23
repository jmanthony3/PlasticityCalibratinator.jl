using CSV
using DataFrames
using GLMakie
using InteractiveUtils: subtypes
using JSON
using LaTeXStrings
using PlasticityBase

const EquationLabel = Union{Char, String, LaTeXString}

include("gui_functions.jl")
include("gui_backend.jl")

set_theme!(theme_latexfonts())

mutable struct ModelInputs{T<:AbstractPlasticity}
    plasticmodelversion         ::Type{T}
    propsfile                   ::String
    expdatasets                 ::Vector{String}
    loading_axial               ::Bool
    loading_torsional           ::Bool
    incnum                      ::Integer
    stressscale                 ::AbstractFloat
    characteristic_equations    ::Vector{EquationLabel}
    dependence_equations        ::Vector{EquationLabel}
    dependence_sliders
end

mutable struct ModelData{T<:AbstractPlasticity}
    plasticmodelversion ::Type{T}
    modelinputs         ::ModelInputs{T}
    nsets               ::Int64
    test_data           ::Dict{String, Vector}
    test_cond           ::Dict{String, Vector}
    materialproperties  ::Dict{String, Float64}
    params              ::Dict{String, Float64}
    C_0                 ::Dict{String, Float64}
    incnum              ::Integer
    stressscale         ::AbstractFloat
end

mutable struct ModelCalibration{T<:AbstractPlasticity}
    modeldata::ModelData{T}
    ax
    dataseries
    leg
end

function screen_main_inputs!(fig, fig_a, fig_width,
        plasticmodelversion, propsfile, expdatasets,
        loading_axial, loading_torsional,
        incnum, stressscale,
        characteristic_equations,
        dependence_equations,
        dependence_sliders)
    fig_fontsize = fig.scene.theme.fontsize[]
    material_dict = JSON.parsefile("../data/plasticityconstants.json")
    material_dictkeys = keys(material_dict)

    # sub-figure for input parameters of calibration study
    f = GridLayout(fig_a[1, 1], 4, 3)

    ## model selection
    f_a = GridLayout(f[1, :], 2, 4)
    colsize!(f_a, 1, Relative(0.24))
    colsize!(f_a, 2, Relative(0.24))
    colsize!(f_a, 3, Relative(0.24))
    colsize!(f_a, 4, Relative(0.24))
    ### model class
    modelclass_label        = Label(f_a[1, 1], "Model Class")
    modelclass_types        = Observable(subtypes(AbstractPlasticity))
    modelclass_default      = @lift first($modelclass_types)
    modelclass_matdict      = material_dict[repr(modelclass_default[])]
    modelclass_matdictkeys  = keys(modelclass_matdict)
    modelclass_menu         = Menu(f_a[2, 1],
        options=zip(repr.(modelclass_types[]), modelclass_types[]),
        default=repr(modelclass_default[])) # , width=32figfontsize)
    # println(@__LINE__, ", ", repr.(modelclass_types[]))
    # println(@__LINE__, ", ", repr(modelclass_default[]))
    # println(@__LINE__, ", ", modelclass_matdictkeys)
    ### model type
    modeltype_label         = Label(f_a[1, 2], "Model Type")
    modeltype_types         = Observable(subtypes(modelclass_default[]))
    if isempty(modeltype_types[])
        modeltype_types[] = [modelclass_default[]]; notify(modeltype_types)
    end
    modeltype_default       = @lift first($modeltype_types)
    modeltype_matdict       = try
        modelclass_matdict[repr(modeltype_default[])]
    catch exc
        modelclass_matdict
    end
    modeltype_matdictkeys   = keys(modeltype_matdict)
    if isempty(modeltype_matdictkeys)
        modeltype_matdict = modelclass_matdict
    end
    modeltype_menu          = Menu(f_a[2, 2],
        options=zip(repr.(modeltype_types[]), modeltype_types[]),
        default=repr(modeltype_default[])) # , width=32figfontsize)
    # println(@__LINE__, ", ", repr.(modeltype_types[]))
    # println(@__LINE__, ", ", repr(modeltype_default[]))
    # println(@__LINE__, ", ", modeltype_matdictkeys)
    ### model version
    modelversion_label      = Label(f_a[1, 3], "Model Version")
    modelversion_types      = Observable(subtypes(modeltype_default[]))
    if isempty(modelversion_types[])
        modelversion_types[] = [modeltype_default[]]; notify(modelversion_types)
    end
    modelversion_default    = @lift first($modelversion_types)
    modelversion_matdict    = try
        modeltype_matdict[repr(modelversion_default[])]
    catch exc
        modeltype_matdict
    end
    modelversion_matdictkeys= keys(modelversion_matdict)
    if isempty(modelversion_matdictkeys)
        modelversion_matdict = modeltype_matdict
    end
    modelversion_menu       = Menu(f_a[2, 3],
        options=zip(repr.(modelversion_types[]), modelversion_types[]),
        default=repr(modelversion_default[])) # , width=32figfontsize)
    # println(@__LINE__, ", ", repr.(modelversion_types[]))
    # println(@__LINE__, ", ", repr(modelversion_default[]))
    # println(@__LINE__, ", ", modelversion_matdictkeys)
    ### model material
    modelmaterial_label     = Label(f_a[1, 4], "Material")
    modelmaterial_types     = Observable(modelversion_matdictkeys)
    modelmaterial_default   = @lift first($modelmaterial_types)
    modelmaterial_menu      = Menu(f_a[2, 4],
        options=zip(modelmaterial_types[], modelmaterial_types[]),
        default=modelmaterial_default[])
    # println(@__LINE__, ", ", repr.(material_types[]))
    # println(@__LINE__, ", ", repr(material_default[]))

    ## other inputs
    ### widgets
    #### propsfile
    propsfile_label                 = Label(f[2, 1], "Path to parameters dictionary:"; halign=:right)
    propsfile_textbox             = Textbox(f[2, 2], placeholder="path/to/dict",
        width=512)
    propsfile_button               = Button(f[2, 3], label="Browse")
    #### experimental datasets
    expdatasets_label               = Label(f[3, 1], "Paths to experimental datasets:"; halign=:right)
    expdatasets_textbox           = Textbox(f[3, 2], placeholder="path/to/experimental datasets",
        width=512, height=5fig.scene.theme.fontsize[])
    expdatasets_button             = Button(f[3, 3], label="Browse")
    #### loading direction toggles
    loadingdirection_label          = Label(f[4, 1], "Loading directions in experiments:"; halign=:right)
    #### loading conditions
    f_b = GridLayout(f[4, 2], 1, 2)
    f_ba = GridLayout(f_b[1, 1], 1, 2)
    loaddir_axial_label             = Label(f_ba[1, 1], "Tension/Compression:"; halign=:right)
    loaddir_axial_toggle           = Toggle(f_ba[1, 2], active=true)
    f_bb = GridLayout(f_b[1, 2], 1, 2)
    loaddir_torsion_label           = Label(f_bb[1, 1], "Torsion:"; halign=:right)
    loaddir_torsion_toggle         = Toggle(f_bb[1, 2], active=false)
    #### model calibration increment and stress scale
    f_c = GridLayout(f[5, :], 1, 2; halign=:left)
    ##### number of strain increments
    f_ca = GridLayout(f_c[1, 1], 1, 2; halign=:left)
    incnum_label                    = Label(f_ca[1, 1], "Number of strain increments for model curves:"; halign=:right)
    incnum_textbox                = Textbox(f_ca[1, 2], placeholder="positive, non-zero integer",
        width=5fig.scene.theme.fontsize[], stored_string="200", displayed_string="200", validator=Int64, halign=:left)
    ##### stress scale
    f_cb = GridLayout(f_c[1, 2], 1, 2; halign=:left)
    stressscale_label               = Label(f_cb[1, 1], "Scale of stress axis:"; halign=:right)
    stressscale_textbox           = Textbox(f_cb[1, 2], placeholder="positive, non-zero float",
        width=5fig.scene.theme.fontsize[], stored_string="1.0", displayed_string="1.0", validator=Float64, halign=:left)

    ### values
    plasticmodelversion[]       = modelversion_default[];                                   notify(plasticmodelversion)
    propsfile[]                 = if isnothing(propsfile_textbox.stored_string[])
        ""
    else
        propsfile_textbox.displayed_string[]
    end; notify(propsfile)
    expdatasets[]               = [if isnothing(expdatasets_textbox.stored_string[])
        ""
    else
        expdatasets_textbox.displayed_string[]
    end]; notify(expdatasets)
    loading_axial[]             = loaddir_axial_toggle.active[];                            notify(loading_axial)
    loading_torsional[]         = loaddir_torsion_toggle.active[];                          notify(loading_torsional)
    incnum[]                    = parse(Int64, incnum_textbox.displayed_string[]);          notify(incnum)
    stressscale[]               = parse(Float64, stressscale_textbox.displayed_string[]);   notify(stressscale)
    characteristic_equations    = characteristicequations(plasticmodelversion[]) # ;           notify(characteristic_equations)
    dependence_equations        = dependenceequations(plasticmodelversion[]) # ;               notify(dependence_equations)
    dependence_sliders[]        = dependencesliders(plasticmodelversion[]);                 notify(dependence_sliders)



    # listener functions
    ## drop-down menu functions
    on(modelclass_menu.selection) do s
        ### model class
        modelclass_default[] = s; notify(modelclass_default)
        modelclass_matdict = material_dict[repr(modelclass_default[])]
        # println(@__LINE__, ", ", modelclass_default[])
        ### model type
        modeltype_types_temp = subtypes(modelclass_default[])
        modeltype_types[] = if isempty(modeltype_types_temp)
            [modelclass_default[]]
        else
            modeltype_types_temp
        end; notify(modeltype_types)
        modeltype_default[] = first(modeltype_types[]); notify(modeltype_default)
        modeltype_matdict = try
            modelclass_matdict[repr(modeltype_default[])]
        catch exc
            modelclass_matdict
        end
        modeltype_menu.options[] = zip(repr.(modeltype_types[]), modeltype_types[])
        modeltype_menu.selection[] = modeltype_default[]
        modeltype_menu.i_selected[] = 1
        notify(modeltype_menu.options)
        notify(modeltype_menu.selection)
        notify(modeltype_menu.i_selected)
        # println(@__LINE__, ", ", modeltype_default[])
        ### model version
        modelversion_types_temp = subtypes(modeltype_default[])
        modelversion_types[] = if isempty(modelversion_types_temp)
            [modeltype_default[]]
        else
            modelversion_types_temp
        end; notify(modelversion_types)
        modelversion_default[] = first(modelversion_types[]); notify(modelversion_default)
        modelversion_matdict = try
            modeltype_matdict[repr(modelversion_default[])]
        catch exc
            modeltype_matdict
        end
        modelversion_menu.options[] = zip(repr.(modelversion_types[]), modelversion_types[])
        modelversion_menu.selection[] = modelversion_default[]
        modelversion_menu.i_selected[] = 1
        notify(modelversion_menu.options)
        notify(modelversion_menu.selection)
        notify(modelversion_menu.i_selected)
        # println(@__LINE__, ", ", modelversion_default[])
        ### model material
        modelmaterial_types_temp = keys(modelversion_matdict)
        modelmaterial_types[] = modelmaterial_types_temp; notify(modelmaterial_types)
        modelmaterial_default[] = first(modelmaterial_types[]); notify(modelmaterial_default)
        modelmaterial_menu.options[] = zip(modelmaterial_types[], modelmaterial_types[])
        modelmaterial_menu.selection[] = modelmaterial_default[]
        modelmaterial_menu.i_selected[] = 1
        notify(modelmaterial_menu.options)
        notify(modelmaterial_menu.selection)
        notify(modelmaterial_menu.i_selected)
        # println(@__LINE__, ", ", material_default[])
    end
    # on(modeltype_menu.selection) do s
    #     modeltype_default[] = s; notify(modeltype_default)
    #     # println(@__LINE__, ", ", modeltype_default[])

    #     modelversion_types_temp = subtypes(modeltype_default[])
    #     modelversion_types[] = if isempty(modelversion_types_temp)
    #         [modeltype_default[]]
    #     else
    #         modelversion_types_temp
    #     end; notify(modelversion_types)
    #     modelversion_default[] = first(modelversion_types[]); notify(modelversion_default)
    #     modelversion_menu.options[] = zip(repr.(modelversion_types[]), modelversion_types[])
    #     modelversion_menu.selection[] = modelversion_default[]
    #     modelversion_menu.i_selected[] = 1
    #     notify(modelversion_menu.options)
    #     notify(modelversion_menu.selection)
    #     notify(modelversion_menu.i_selected)
    #     # println(@__LINE__, ", ", modelversion_default[])
    # end
    # on(modelversion_menu.selection) do s
    #     modelversion_default[] = s; notify(modelversion_default)
    #     # println(@__LINE__, ", ", modelversion_default[])
    # end

    ## dynamic backend functions
    on(propsfile_button.clicks) do click                # browse for parameters dictionary
        update_propsfile!(propsfile, propsfile_textbox)
    end
    on(expdatasets_button.clicks) do click              # experimental datasets (browse)
        update_experimentaldata_browse!(expdatasets, expdatasets_textbox)
    end
    on(events(fig.scene).dropped_files) do filedump     # experimental datasets (drag-and-drop)
        update_experimentaldata_draganddrop!(expdatasets, expdatasets_textbox, filedump)
    end

    return (modelversion_menu,
        propsfile_textbox, expdatasets_textbox,
        loaddir_axial_toggle, loaddir_torsion_toggle,
        incnum_textbox, stressscale_textbox,
        characteristic_equations, dependence_equations)
end

function screen_sliders(fig, model_calibration, model_data, sg_sliders)
    ### update curves from sliders
    @lift for (key, sgs) in zip(keys(model_calibration[].modeldata.params), collectragged($sg_sliders))
        on(only(sgs.sliders).value) do val
            # redefine materialproperties with new slider values
            model_data[].params[key] = to_value(val);                   notify(model_data)
            model_calibration[].modeldata.params[key] = to_value(val);  notify(model_calibration)
            plotdata_update!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
        end
    end
    display(GLMakie.Screen(; title="Sliders", focus_on_show=true), fig)
    return nothing
end

function screen_main_interactions!(fig_b, fig_c, fig_d,
        plasticmodeltypeversion_menu, propsfile_textbox, expdatasets_textbox,
        loaddir_axial_toggle, loaddir_torsion_toggle,
        incnum_textbox, stressscale_textbox, model_inputs, model_data, model_calibration,
        sliders_grid, sliders_toggles, sliders_labels, sliders_sliders)
    characteristic_equations    = model_inputs[].characteristic_equations
    # dependence_equations        = modelinputs[].dependence_equations
    # dependence_sliders          = modelinputs[].dependence_sliders

    # sub-figure for model selection, sliders, and plot
    f                       = GridLayout(fig_b[ 1, 1], 3, 1)

    ## update inputs, set mode, and show sliders
    ### update inputs
    f_a                     = GridLayout(f[1, 1], 1, 1)
    buttons_updateinputs        = Button(f_a[1, 1], label="Update inputs", valign=:bottom)
    ### characteristic equations
    f_b = @lift GridLayout(f[2, 1], length($model_inputs.characteristic_equations), 1)
    chareqs_labels = Observable([
        constructgrid_chareqlabel!(f_b[][i, 1], eq) for (i, eq) in enumerate(characteristic_equations)])
    ### calibration/exploration/reset buttons
    f_c                     = GridLayout(f[3, 1], 2, 1)
    #### toggles
    f_ca                    = GridLayout(f_c[1, 1], 1, 3)
    calibrationmode_label        = Label(f_ca[1, 1], "Calibration Mode?"; halign=:right)
    explorermode_toggle         = Toggle(f_ca[1, 2]; active=false)
    # rotate!(explorermode_toggle.blockscene, pi/2)
    explorermode_label           = Label(f_ca[1, 3], "Explorer Mode?"; halign=:left)
    calibrationexplorermode = Observable(explorermode_toggle.active[])
    #### buttons
    f_cb                    = GridLayout(f_c[2, 1], 1, 2)
    showsliders_button          = Button(f_cb[1, 1], label="Show sliders")
    resetsliders_button         = Button(f_cb[1, 2], label="Reset sliders")

    ## plot axis and buttons
    ### plot
    plotdata_insert!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
    model_calibration[].leg = try
        axislegend(model_calibration[].ax, position=:rb)
    catch exc
        nothing
    end; notify(model_calibration)
    plotdata_update!(model_calibration[].modeldata.plasticmodelversion, model_calibration)
    ### buttons below plot
    buttons_grid            = GridLayout(fig_c[ 2,  1], 1, 4)
    buttons_labels = ["Calibrate", "Macro", "Save Props", "Export Curves"]
    buttons = [Button(buttons_grid[1, i], label=bl) for (i, bl) in enumerate(buttons_labels)]
    buttons_calibrate       = buttons[1]
    buttons_macro           = buttons[2]
    buttons_savecurves      = buttons[3]
    buttons_exportcurves    = buttons[4]



    # listener functions
    ## update input parameters to calibrate
    on(buttons_updateinputs.clicks) do click
        model_inputs, model_data, model_calibration, sliders_sliders = update_modelinputs!(fig_b, fig_d,
            plasticmodeltypeversion_menu, propsfile_textbox, expdatasets_textbox,
            loaddir_axial_toggle, loaddir_torsion_toggle,
            incnum_textbox, stressscale_textbox, model_inputs, model_data, model_calibration,
            sliders_grid, sliders_toggles, sliders_labels, sliders_sliders)
        for c in contents(f_b[])
            delete!(c)
        end; trim!(f_b[])
        f_b[] = GridLayout(f[2, 1], 1, 1); notify(f_b)
        # println(model_calibration[].modeldata.modelinputs.characteristic_equations)
        chareqs_labels[] = [
            constructgrid_chareqlabel!(f_b[][i, 1], eq) for (i, eq) in enumerate(model_calibration[].modeldata.modelinputs.characteristic_equations)]
        notify(chareqs_labels)
    end
    on(explorermode_toggle.active) do toggle
        calibrationexplorermode[] = toggle; notify(calibrationexplorermode)
    end
    ## show sliders
    on(showsliders_button.clicks) do click
        # println(sliders_sliders)
        # screen_sliders(fig_d, model_calibration, model_data, sliders_sliders)
        if calibrationexplorermode[]
            # println(dorasliders(model_calibration[].modeldata.plasticmodelversion))
            clearplot!(model_calibration)
            doratheexplorer_sliders(model_calibration, model_data, dorasliders(model_calibration[].modeldata.plasticmodelversion)) # (fig_d, model_calibration, model_data, sliders_sliders, dorasliders(model_calibration[].modeldata.plasticmodelversion))
        else
            screen_sliders(fig_d, model_calibration, model_data, sliders_sliders)
        end
    end
    ## reset sliders/parameters
    on(resetsliders_button.clicks) do click
        reset_sliders!(sliders_sliders, materialconstants(model_calibration[].modeldata.plasticmodelversion), model_data, model_calibration)
    end
    ## calibrate parameters
    on(buttons_calibrate.clicks) do click
        calibratingtoggles_indices = findall(t->t.active[], toggles[])
        if !isempty(calibratingtoggles_indices)
            constantstocalibrate_indices = []
            constantstocalibrate = Float64[]
            for i in calibratingtoggles_indices
                if      i ==  1
                    append!(constantstocalibrate_indices,   [ 1,  2])
                    append!(constantstocalibrate,           [params[]["C01"], params[]["C02"]])
                elseif  i ==  2
                    append!(constantstocalibrate_indices,   [ 3,  4])
                    append!(constantstocalibrate,           [params[]["C03"], params[]["C04"]])
                elseif  i ==  3
                    append!(constantstocalibrate_indices,   [ 5,  6])
                    append!(constantstocalibrate,           [params[]["C05"], params[]["C06"]])
                elseif  i ==  4
                    append!(constantstocalibrate_indices,   [ 7,  8])
                    append!(constantstocalibrate,           [params[]["C07"], params[]["C08"]])
                elseif  i ==  5
                    append!(constantstocalibrate_indices,   [ 9, 10])
                    append!(constantstocalibrate,           [params[]["C09"], params[]["C10"]])
                elseif  i ==  6
                    append!(constantstocalibrate_indices,   [11, 12])
                    append!(constantstocalibrate,           [params[]["C11"], params[]["C12"]])
                elseif  i ==  7
                    append!(constantstocalibrate_indices,   [13, 14])
                    append!(constantstocalibrate,           [params[]["C13"], params[]["C14"]])
                elseif  i ==  8
                    append!(constantstocalibrate_indices,   [15, 16])
                    append!(constantstocalibrate,           [params[]["C15"], params[]["C16"]])
                elseif  i ==  9
                    append!(constantstocalibrate_indices,   [17, 18])
                    append!(constantstocalibrate,           [params[]["C17"], params[]["C18"]])
                elseif  i == 10
                    append!(constantstocalibrate_indices,   [19, 20])
                    append!(constantstocalibrate,           [params[]["C19"], params[]["C20"]])
                end
            end
            p = constantstocalibrate # creaty local copy of params[] and modify
            # # function multimodel(x, p)
            # function multimodel(p)
            #     # BCJ_metal_calibrate_kernel(bcj[].test_data, bcj[].test_cond,
            #     #     incnum[], istate[], p[1], p[2]).S
            #     kS          = 1     # default tension component
            #     if istate[] == 2
            #         kS      = 4     # select torsion component
            #     end
            #     r = params[]
            #     for (i, j) in enumerate(constantstocalibrate_indices)
            #         r[BCJinator.constant_string(j)] = p[i]
            #     end
            #     ret_x = Float64[]
            #     ret_y = Float64[] # zeros(Float64, length(x))
            #     for i in range(1, bcj[].nsets)
            #         emax        = maximum(bcj[].test_data["Data_E"][i])
            #         # println('Setup: emax for set ',i,' = ', emax)
            #         bcj_ref     = BCJ.BCJ_metal(
            #             bcj[].test_cond["Temp"][i], bcj[].test_cond["StrainRate"][i],
            #             emax, incnum[], istate[], r)
            #         bcj_current = BCJ.BCJ_metal_currentconfiguration_init(bcj_ref, BCJ.DK)
            #         BCJ.solve!(bcj_current)
            #         idx = []
            #         for t in bcj[].test_data["Data_E"][i]
            #             j = findlast(t .<= bcj_current.ϵₜₒₜₐₗ[kS, :])
            #             push!(idx, if !isnothing(j)
            #                 j
            #             else
            #                 findfirst(t .>= bcj_current.ϵₜₒₜₐₗ[kS, :])
            #             end)
            #         end
            #         append!(ret_x, bcj_current.ϵₜₒₜₐₗ[kS, :][idx])
            #         append!(ret_y, bcj[].test_data["Data_S"][i] - bcj_current.S[kS, :][idx])
            #     end
            #     return ret_y
            # end
            # x = Float64[] # zeros(Float64, (bcj[].nsets, length(bcj[].test_data["Data_E"][1])))
            # y = Float64[] # zeros(Float64, (bcj[].nsets, length(bcj[].test_data["Data_S"][1])))
            # for i in range(1, bcj[].nsets)
            #     # println((size(x[i, :]), size(bcj[].test_data["Data_E"][i])))
            #     # x[i, :] .= bcj[].test_data["Data_E"][i]
            #     # y[i, :] .= bcj[].test_data["Data_S"][i]
            #     append!(x, bcj[].test_data["Data_E"][i])
            #     append!(y, bcj[].test_data["Data_S"][i])
            # end
            # # q = curve_fit(multimodel, x, y, p).param
            # q = nlsolve(multimodel, p).zero
            function fnc2min(p)
                # r = params[]
                # for (i, j) in enumerate(constantstocalibrate_indices)
                #     r[BCJinator.constant_string(j)] = p[i]
                # end
                # err = 0.
                # for i in range(1, bcj[].nsets)
                #     err += sum((bcj[].test_data["Data_S"][i] - BCJinator.BCJ_metal_calibrate_kernel(bcj[].test_data, bcj[].test_cond,
                #         incnum[], istate[], r, i).S) .^ 2.)
                # end
                # return err
                kS          = 1     # default tension component
                if istate[] == 2
                    kS      = 4     # select torsion component
                end
                r = params[]
                for (i, j) in enumerate(constantstocalibrate_indices)
                    r[BCJinator.constant_string(j)] = p[i]
                end
                ret_x = Float64[]
                ret_y = Float64[] # zeros(Float64, length(x))
                # err = 0. # zeros(Float64, length(x))
                for i in range(1, bcj[].nsets)
                    emax        = maximum(bcj[].test_data["Data_E"][i])
                    # println('Setup: emax for set ',i,' = ', emax)
                    bcj_loading     = BCJ.BCJMetalStrainControl(
                        bcj[].test_cond["Temp"][i], bcj[].test_cond["StrainRate"][i],
                        emax, incnum[], istate[], r)
                    bcj_configuration = BCJ.bcjmetalreferenceconfiguration(bcj_loading, BCJ.DK)
                    bcj_reference   = bcj_configuration[1]
                    bcj_current     = bcj_configuration[2]
                    bcj_history     = bcj_configuration[3]
                    BCJ.solve!(bcj_current, bcj_history)
                    idx = []
                    for t in bcj[].test_data["Data_E"][i]
                        j = findlast(t .<= bcj_history.ϵₜₒₜₐₗ[kS, :])
                        push!(idx, if !isnothing(j)
                            j
                        else
                            findfirst(t .>= bcj_history.ϵₜₒₜₐₗ[kS, :])
                        end)
                    end
                    append!(ret_x, bcj_history.ϵₜₒₜₐₗ[kS, :][idx])
                    append!(ret_y, bcj[].test_data["Data_S"][i] - bcj_history.S[kS, :][idx])
                    # err += sum((bcj[].test_data["Data_S"][i] - bcj_current.S[kS, :][idx]) .^ 2.)
                    # # err += sum((bcj[].test_data["Data_S"][i] - BCJinator.bcjmetalcalibration_kernel(bcj[].test_data, bcj[].test_cond,
                    # #     incnum[], istate[], r, i).S[idx]) .^ 2.)
                end
                return ret_y
                # return err
            end
            function fnc2min_grad(p)
                # r = params[]
                # for (i, j) in enumerate(constantstocalibrate_indices)
                #     r[BCJinator.constant_string(j)] = p[i]
                # end
                # err = 0.
                # for i in range(1, bcj[].nsets)
                #     err += sum((bcj[].test_data["Data_S"][i] - BCJinator.bcjmetalcalibration_kernel(bcj[].test_data, bcj[].test_cond,
                #         incnum[], istate[], r, i).S) .^ 2.)
                # end
                # return err
                kS          = 1     # default tension component
                if istate[] == 2
                    kS      = 4     # select torsion component
                end
                r = params[]
                for (i, j) in enumerate(constantstocalibrate_indices)
                    r[BCJinator.constant_string(j)] = p[i]
                end
                stress_rate = Float64[]
                for i in range(1, bcj[].nsets)
                    emax        = maximum(bcj[].test_data["Data_E"][i])
                    # println('Setup: emax for set ',i,' = ', emax)
                    bcj_loading     = BCJ.BCJMetalStrainControl(
                        bcj[].test_cond["Temp"][i], bcj[].test_cond["StrainRate"][i],
                        emax, incnum[], istate[], r)
                    bcj_configuration = BCJ.bcjmetalreferenceconfiguration(bcj_loading, BCJ.DK)
                    bcj_reference   = bcj_configuration[1]
                    bcj_current     = bcj_configuration[2]
                    bcj_history     = bcj_configuration[3]
                    BCJ.solve!(bcj_current, bcj_history)
                    idx = []
                    for t in bcj[].test_data["Data_E"][i]
                        j = findlast(t .<= bcj_history.ϵₜₒₜₐₗ[kS, :])
                        push!(idx, if !isnothing(j)
                            j
                        else
                            findfirst(t .>= bcj_history.ϵₜₒₜₐₗ[kS, :])
                        end)
                    end
                    # append!(ret_x, bcj_current.ϵₜₒₜₐₗ[kS, :][idx])
                    append!(stress_rate, 200e9 .* (bcj_history.ϵ_dot_effective .- bcj_history.ϵ_dot_plastic__[kS, :][idx]))
                end
                return stress_rate
            end
            result = optimize(fnc2min, fnc2min_grad, p, BFGS())
            # println(result)
            q = Optim.minimizer(result)
            # println((p, q))
            r = params[]
            for (i, j) in enumerate(constantstocalibrate_indices)
                r[BCJinator.constant_string(j)] = max(0., q[i])
            end
            for i in calibratingtoggles_indices
                toggles[][i].active[] = false;                          notify(toggles[][i].active)
                if      i ==  1
                    params[]["C01"] = r["C01"];                         notify(params)
                    set_close_to!(sg_sliders[][ 1].sliders[1], r["C01"])
                    sg_sliders[][ 1].sliders[1].value[] = r["C01"];     notify(sg_sliders[][ 1].sliders[1].value)
                    params[]["C02"] = r["C02"];                         notify(params)
                    set_close_to!(sg_sliders[][ 2].sliders[1], r["C02"])
                    sg_sliders[][ 2].sliders[1].value[] = r["C02"];     notify(sg_sliders[][ 2].sliders[1].value)
                elseif  i ==  2
                    params[]["C03"] = r["C03"];                         notify(params)
                    set_close_to!(sg_sliders[][ 3].sliders[1], r["C03"])
                    sg_sliders[][ 3].sliders[1].value[] = r["C03"];     notify(sg_sliders[][ 3].sliders[1].value)
                    params[]["C04"] = r["C04"];                         notify(params)
                    set_close_to!(sg_sliders[][ 4].sliders[1], r["C04"])
                    sg_sliders[][ 4].sliders[1].value[] = r["C04"];     notify(sg_sliders[][ 4].sliders[1].value)
                elseif  i ==  3
                    params[]["C05"] = r["C05"];                         notify(params)
                    set_close_to!(sg_sliders[][ 5].sliders[1], r["C05"])
                    sg_sliders[][ 5].sliders[1].value[] = r["C05"];     notify(sg_sliders[][ 5].sliders[1].value)
                    params[]["C06"] = r["C06"];                         notify(params)
                    set_close_to!(sg_sliders[][ 6].sliders[1], r["C06"])
                    sg_sliders[][ 6].sliders[1].value[] = r["C06"];     notify(sg_sliders[][ 6].sliders[1].value)
                elseif  i ==  4
                    params[]["C07"] = r["C07"];                         notify(params)
                    set_close_to!(sg_sliders[][ 7].sliders[1], r["C07"])
                    sg_sliders[][ 7].sliders[1].value[] = r["C07"];     notify(sg_sliders[][ 7].sliders[1].value)
                    params[]["C08"] = r["C08"];                         notify(params)
                    set_close_to!(sg_sliders[][ 8].sliders[1], r["C08"])
                    sg_sliders[][ 8].sliders[1].value[] = r["C08"];     notify(sg_sliders[][ 8].sliders[1].value)
                elseif  i ==  5
                    params[]["C09"] = r["C09"];                         notify(params)
                    set_close_to!(sg_sliders[][ 9].sliders[1], r["C09"])
                    sg_sliders[][ 9].sliders[1].value[] = r["C09"];     notify(sg_sliders[][ 9].sliders[1].value)
                    params[]["C10"] = r["C10"];                         notify(params)
                    set_close_to!(sg_sliders[][10].sliders[1], r["C10"])
                    sg_sliders[][10].sliders[1].value[] = r["C10"];     notify(sg_sliders[][10].sliders[1].value)
                elseif  i ==  6
                    params[]["C11"] = r["C11"];                         notify(params)
                    set_close_to!(sg_sliders[][11].sliders[1], r["C11"])
                    sg_sliders[][11].sliders[1].value[] = r["C11"];     notify(sg_sliders[][11].sliders[1].value)
                    params[]["C12"] = r["C12"];                         notify(params)
                    set_close_to!(sg_sliders[][12].sliders[1], r["C12"])
                    sg_sliders[][12].sliders[1].value[] = r["C12"];     notify(sg_sliders[][12].sliders[1].value)
                elseif  i ==  7
                    params[]["C13"] = r["C13"];                         notify(params)
                    set_close_to!(sg_sliders[][13].sliders[1], r["C13"])
                    sg_sliders[][13].sliders[1].value[] = r["C13"];     notify(sg_sliders[][13].sliders[1].value)
                    params[]["C14"] = r["C14"];                         notify(params)
                    set_close_to!(sg_sliders[][14].sliders[1], r["C14"])
                    sg_sliders[][14].sliders[1].value[] = r["C14"];     notify(sg_sliders[][14].sliders[1].value)
                elseif  i ==  8
                    params[]["C15"] = r["C15"];                         notify(params)
                    set_close_to!(sg_sliders[][15].sliders[1], r["C15"])
                    sg_sliders[][15].sliders[1].value[] = r["C15"];     notify(sg_sliders[][15].sliders[1].value)
                    params[]["C16"] = r["C16"];                         notify(params)
                    set_close_to!(sg_sliders[][16].sliders[1], r["C16"])
                    sg_sliders[][16].sliders[1].value[] = r["C16"];     notify(sg_sliders[][16].sliders[1].value)
                elseif  i ==  9
                    params[]["C17"] = r["C17"];                         notify(params)
                    set_close_to!(sg_sliders[][17].sliders[1], r["C17"])
                    sg_sliders[][17].sliders[1].value[] = r["C17"];     notify(sg_sliders[][17].sliders[1].value)
                    params[]["C18"] = r["C18"];                         notify(params)
                    set_close_to!(sg_sliders[][18].sliders[1], r["C18"])
                    sg_sliders[][18].sliders[1].value[] = r["C18"];     notify(sg_sliders[][18].sliders[1].value)
                elseif  i == 10
                    params[]["C19"] = r["C19"];                         notify(params)
                    set_close_to!(sg_sliders[][19].sliders[1], r["C19"])
                    sg_sliders[][19].sliders[1].value[] = r["C19"];     notify(sg_sliders[][19].sliders[1].value)
                    params[]["C20"] = r["C20"];                         notify(params)
                    set_close_to!(sg_sliders[][20].sliders[1], r["C20"])
                    sg_sliders[][20].sliders[1].value[] = r["C20"];     notify(sg_sliders[][20].sliders[1].value)
                end
            end
        end
    end
    ## perform user-macro
    on(buttons_macro.clicks) do click
        screen_isvs = GLMakie.Screen(; title="ISVs") # , focus_on_show=true)
        display(screen_isvs, fig_d)
    end
    ## save parameters
    on(buttons_savecurves.clicks) do click
        propsfile_new = save_file(; filterlist="csv")
        if propsfile_new != ""
            dict = model_calibration[].modeldata.materialproperties
            for (key, val) in model_calibration[].modeldata.params
                dict[key] = val
            end
            CSV.write(propsfile_new, dict)
        end
    end
    ## export curves
    on(buttons_exportcurves.clicks) do click
        # props_dir, props_name = dirname(propsfile[]), basename(propsfile[])
        curvefile_new = save_file(; filterlist="csv")
        if curvefile_new != ""
            header, df = [], DataFrame()
            for (i, test_name, test_strain, test_stress) in zip(range(1, model_calibration[].modeldata.nsets), model_calibration[].modeldata.test_cond["Name"], model_calibration[].modeldata.test_data["Model_E"], model_calibration[].modeldata.test_data["Model_VM"])
                push!(header, "strain-" * test_name)
                push!(header, "VMstress" * test_name)
                DataFrames.hcat!(df, DataFrame(
                    "strain-" * test_name   => test_strain,
                    "VMstress" * test_name  => test_stress))
            end
            CSV.write(curvefile_new, df, header=header)
        end
    end

    return nothing
end

function screen_main(x_label, y_label)
    screen_main = GLMakie.Screen(; title="PlasticityCalibratinator.jl", fullscreen=true, focus_on_show=true)
    fig_layout = GridLayout(2, 1)
    # main figure
    fig = Figure(size=(900, 600), figure_padding=(30, 10, 10, 10), layout=fig_layout) # , tellheight=false, tellwidth=false)
    # Box(fig[1, 1], color=(:red, 0.2), strokewidth=0)
    # Box(fig[2, 1], color=(:red, 0.2), strokewidth=0)
    fig_width = @lift first(widths($(fig.scene.viewport)))

    ## sub-figure for input parameters of calibration study
    fig_a = GridLayout(fig[ 1,  1], 1, 1)
    # Box(a[1, 1], color=(:red, 0.2), strokewidth=0)

    ## sub-figure for model selection, sliders, and plot
    fig_b = GridLayout(fig[ 2,  1], 1, 2)
    fig_c = GridLayout(fig_b[ 1,  2], 2, 1)
    # Box(b[1, 1], color=(:red, 0.2), strokewidth=0)
    # Box(b[1, 2], color=(:red, 0.2), strokewidth=0)
    # Box(c[1, 1], color=(:red, 0.2), strokewidth=0)
    rowsize!(fig_b, 1, Relative(0.8))

    # model observables
    plasticmodelversion         = Observable(AbstractPlasticity)    # ::Type{<:AbstractPlasticity}
    propsfile                   = Observable("")                    # ::String
    expdatasets                 = Observable([""])                  # ::Vector{String}
    loading_axial               = Observable(true)                  # ::Bool
    loading_torsional           = Observable(false)                 # ::Bool
    incnum                      = Observable(200)                   # ::Integer
    stressscale                 = Observable(1e6)                   # ::AbstractFloat
    characteristic_equations    = [' ']                             # ::Vector{String}
    dependence_equations        = [' ']                             # ::Vector{String}
    dependence_sliders          = Observable([])                    # ::Vector{Any}

    # construct input widgets
    inputobjects                = screen_main_inputs!(fig, fig_a, fig_width,
        plasticmodelversion, propsfile, expdatasets,
        loading_axial, loading_torsional,
        incnum, stressscale,
        characteristic_equations,
        dependence_equations,
        dependence_sliders)
    plasticmodeltypeversion_menu= inputobjects[1]
    propsfile_textbox           = inputobjects[2]
    expdatasets_textbox         = inputobjects[3]
    loaddir_axial_toggle        = inputobjects[4]
    loaddir_torsion_toggle      = inputobjects[5]
    incnum_textbox              = inputobjects[6]
    stressscale_textbox         = inputobjects[7]
    characteristic_equations    = inputobjects[8]
    dependence_equations        = inputobjects[9]

    # construct model inputs
    model_inputs                = Observable(ModelInputs{plasticmodelversion[]}(
        plasticmodelversion[], propsfile[], expdatasets[],
        loading_axial[], loading_torsional[],
        incnum[], stressscale[],
        characteristic_equations,
        dependence_equations,
        dependence_sliders[]
    ))

    fig_ax = Axis(fig_c[ 1,  1], xlabel=x_label, ylabel=y_label,
        aspect=1.0, tellheight=true, tellwidth=true) # , height=3\2w[], width=w[])
    # xlims!(ax, (0., nothing)); ylims!(ax, (min_stress, max_stress))
    # leg = Observable(axislegend(ax, position=:rb))

    # construct model data
    model_data                       = Observable(modeldata(model_inputs[].plasticmodelversion, model_inputs[], materialproperties(model_inputs[].plasticmodelversion)))
    # modeldataseries                 = Observable(dataseries_init(plasticmodelversion[], modeldata[].nsets, modeldata[].test_data))
    fig_axleg = try
        axislegend(fig_ax, position=:rb)
    catch exc
        nothing
    end
    # println(keys(model_data[].params))

    # construct model calibration
    model_calibration                = Observable(ModelCalibration(
        model_data[], fig_ax, plotdata_initialize(model_data[].modelinputs.plasticmodelversion, model_data[].nsets, model_data[].test_data), fig_axleg))



    # setup the layout and widgets for the lower-half of the main figure and additional screens
    ## sliders screen
    fig_d = Figure(size=(450, 600))
    sliders_grid    = @lift GridLayout(fig_d[1, 1], length($model_inputs.dependence_equations), 3)
    sliders_toggles = Observable([ # add toggles for which to calibrate
        constructgrid_toggle!(sliders_grid[][i, 1]) for i in range(1, length(model_inputs[].dependence_equations))])
    sliders_labels  = Observable([ # label each slider with equation
        constructgrid_depeqlabel!(sliders_grid[][i, 2], eq) for (i, eq) in enumerate(model_inputs[].dependence_equations)])
    sliders_sliders = Observable([
        constructgrid_slider!(sliders_grid[][i, 3], model_inputs[].dependence_sliders[i]) for i in range(1, length(model_inputs[].dependence_sliders))])
    # println(sliders_sliders[])

    ## populate and instantiate model interactions
    screen_main_interactions!(fig_b, fig_c, fig_d,
        plasticmodeltypeversion_menu, propsfile_textbox, expdatasets_textbox,
        loaddir_axial_toggle, loaddir_torsion_toggle,
        incnum_textbox, stressscale_textbox, model_inputs, model_data, model_calibration,
        sliders_grid, sliders_toggles, sliders_labels, sliders_sliders)



    display(screen_main, fig) # that's all folks!
    return nothing
end

function main(; x_label="True Strain (mm/mm)", y_label="True Stress (Pa)")
    screen_main(x_label, y_label)
end