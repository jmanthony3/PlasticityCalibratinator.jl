using CSV
using DataFrames
using GLMakie
using LaTeXStrings
using NativeFileDialog
using PlasticityBase

using InteractiveUtils

set_theme!(theme_latexfonts())

characteristicequations(::Type{<:Plasticity})::Vector{Union{Char, String, LaTeXString}} = [' ']
dependenceequations(::Type{<:Plasticity})::Vector{Union{Char, String, LaTeXString}} = [' ']
dependencesliders(::Type{<:Plasticity})::Vector{Any} = Any[]

mutable struct ModelInputs{T<:Plasticity}
    plasticmodelversion         ::Type{T}
    propsfile                   ::String
    expdatasets                 ::Vector{String}
    loading_axial               ::Bool
    loading_torsional           ::Bool
    incnum                      ::Integer
    stressscale                 ::AbstractFloat
    characteristic_equations    ::Vector{Union{Char, String, LaTeXString}}
    dependence_equations        ::Vector{Union{Char, String, LaTeXString}}
    dependence_sliders
end

mutable struct ModelData{T<:Plasticity}
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

mutable struct ModelCalibration{T<:Plasticity}
    modeldata::ModelData{T}
    ax
    dataseries
    leg
end



# browse for parameters dictionary
function update_propsfile!(propsfile, propsfile_textbox)
    file = pick_file(; filterlist="csv")
    if file != ""
        propsfile[] = file; notify(propsfile)
        propsfile_textbox.displayed_string[] = file
    end
    return nothing
end

# experimental data sets (browse)
function update_experimentaldata!(expdatasets, expdatasets_textbox)
    filelist = pick_multi_file(; filterlist="csv")
    if !isempty(filelist)
        println(filelist)
        # expdatasets[] = filelist; notify(expdatasets)
        u, v = length(expdatasets[]), length(filelist)
        if u > v
            for (i, file) in enumerate(filelist)
                expdatasets[][i] = file;                    notify(expdatasets)
            end
            for i in range(u, v + 1; step=-1)
                deleteat!(expdatasets[], i);                notify(expdatasets)
            end
        elseif u < v
            for (i, file) in enumerate(filelist[begin:u])
                expdatasets[][i] = file;                    notify(expdatasets)
            end
            append!(expdatasets[], filelist[u + 1:end]);    notify(expdatasets)
        else
            expdatasets[] .= filelist
        end;                                                notify(expdatasets)
        expdatasets_textbox.stored_string[] = join(filelist, "\n")
        expdatasets_textbox.displayed_string[] = join(filelist, "\n")
    end
    return nothing
end

# experimental data sets (drag-and-drop)
function update_experimentaldata_draganddrop!(expdatasets, expdatasets_textbox, filedump)
    if !isempty(filedump)
        u, v = length(expdatasets[]), length(filedump)
        if u > v
            for (i, file) in enumerate(filedump)
                expdatasets[][i] = file;                    notify(expdatasets)
            end
            for i in range(u, v + 1; step=-1)
                deleteat!(expdatasets[], i);                notify(expdatasets)
            end
        elseif u < v
            for (i, file) in enumerate(filedump[begin:u])
                expdatasets[][i] = file;                    notify(expdatasets)
            end
            append!(expdatasets[], filedump[u + 1:end]);    notify(expdatasets)
        else
            expdatasets[] .= filedump
        end;                                                notify(expdatasets)
        expdatasets_textbox.stored_string[] = join(filedump, "\n")
        expdatasets_textbox.displayed_string[] = join(filedump, "\n")
    end
    return nothing
end


chareq_label(grid, eqstr)   = Label(grid, eqstr; halign=:left)
depeq_label!(grid, eqstr)   = chareq_label(grid, eqstr)
toggle!(grid)               = Toggle(grid; active=false)
function sg_slider!(grid, labels)
    println(labels)
    if isa(labels, NamedTuple)
        println(@__LINE__, ", Returning...")
        return SliderGrid(grid[1, 1], labels)
    else
        return [begin
            println((i, label))
            sg_slider!(grid[ i,  1], label)
        end for (i, label) in enumerate(labels)]
    end
end
collectragged!(dest, src) = begin
    #= REPL[63]:1 =#
    for element = src
        #= REPL[63]:2 =#
        issingleelement = try
            isempty(size(element))
        catch exc
            if isa(exc, MethodError)
                isa(element, SliderGrid)
            end
        end
        if issingleelement
            #= REPL[63]:3 =#
            push!(dest, element)
        else
            #= REPL[63]:5 =#
            collectragged!(dest, element)
        end
        #= REPL[63]:7 =#
    end
end
collectragged(src) = begin
    arr = []; collectragged!(arr, src); arr
end

function calibration_init(::Type{<:Plasticity}, args...; kwargs...) end
function dataseries_init(::Type{<:Plasticity}, args...; kwargs...) end
function calibration_update!(::Type{<:Plasticity}, args...; kwargs...) end
function plot_sets!(::Type{<:Plasticity}, args...; kwargs...) end
function update!(::Type{<:Plasticity}, args...; kwargs...) end

function reset_sliders!(sg_sliders, modeldata, modelcalibration)
    # nsliders = sum(length, modelinputs[].dependence_sliders)
    nsliders = count(x->isa(x, NamedTuple), modelcalibration[].modeldata.modelinputs.dependence_sliders)
    dict = materialconstants(modelcalibration[].modeldata.plasticmodelversion) # sort(collect(modelcalibration[].modeldata.C_0), by=x->findfirst(x[1] .== materialconstants_index(modelcalibration[].modeldata.plasticmodelversion)))
    println(dict)
    # for (i, key, (k, v), sgc) in zip(range(1, nsliders), materialconstants_index(modelcalibration[].modeldata.plasticmodelversion), dict, sg_sliders[])
    #     println((i, key, dict[key]))
    #     modeldata[].params[key] = to_value(dict[key]); notify(modeldata)
    #     modelcalibration[].modeldata.params[key] = to_value(dict[key]);    notify(modelcalibration)
    #     set_close_to!(sgc.sliders[1], dict[key])
    #     sgc.sliders[1].value[] = to_value(dict[key]);   notify(sgc.sliders[1].value)
    # end
    asyncmap((i, key, (k, v), sgc)->begin # attempt multi-threading
            println((i, key, dict[key]))
            modeldata[].params[key] = to_value(dict[key]); notify(modeldata)
            modelcalibration[].modeldata.params[key] = to_value(dict[key]);    notify(modelcalibration)
            set_close_to!(sgc.sliders[1], dict[key])
            sgc.sliders[1].value[] = to_value(dict[key]);   notify(sgc.sliders[1].value)
        end, range(1, nsliders), materialconstants_index(modelcalibration[].modeldata.plasticmodelversion), dict, collectragged(sg_sliders[]))
    return nothing
end

# update input parameters to calibrate
function update_inputs!(f, g,
        plasticmodeltypeversion_menu, propsfile_textbox, expdatasets_textbox,
        loaddir_axial_toggle, loaddir_torsion_toggle,
        incnum_textbox, stressscale_textbox, modelinputs, modeldata, modelcalibration,
        sliders_grid, sliders_toggles, sliders_labels, sliders_sliders)
    # fig, ax, leg, dataseries, modelinputs::ModelInputs, params
    # empty!(modelcalib.ax); !isnothing(modelcalib.leg[]) ? delete!(modelcalib.leg[]) : nothing; notify(modelcalib.leg)
    # BCJinator.reset_sliders!(params, sg_sliders, C_0, nsliders)
    # incnum = parse(Int64, modelinputs.incnum_textbox.displayed_string[])
    # stressscale = parse(Int64, modelinputs.stressscale_textbox.displayed_string[])
    # modelcalib = BCJinator.calibration_init(modelinputs.expdatasets_textbox[], incnum, params[], stressscale)
    # dataseries[] = BCJinator.dataseries_init(modelinputs.model[], modelcalib[].nsets, modelcalib[].test_data); notify(dataseries)
    # BCJinator.plot_sets!(ax, dataseries[], modelcalib, stressscale)
    # !isnothing(leg) ? (leg[] = axislegend(ax, position=:rb)) : nothing; notify(leg)

    empty!(modelcalibration[].ax)
    if !isnothing(modelcalibration[].leg)
        delete!(modelcalibration[].leg); notify(modelcalibration)
    end
    plasticmodelversion_temp       = plasticmodeltypeversion_menu.selection[]
    println(plasticmodelversion_temp)
    propsfile_temp                 = if isnothing(propsfile_textbox.stored_string[])
        ""
    else
        propsfile_textbox.displayed_string[]
    end
    println(modelinputs[].propsfile)
    # modelinputs[].expdatasets               = [if isnothing(expdatasets_textbox.stored_string[])
    #     ""
    # else
    #     expdatasets_textbox.displayed_string[]
    # end];                                                                                                   notify(modelinputs)
    expdatasets_temp = modelinputs[].expdatasets
    println(modelinputs[].expdatasets)
    loading_axial_temp             = loaddir_axial_toggle.active[]
    loading_torsional_temp         = loaddir_torsion_toggle.active[]
    incnum_temp                    = parse(Int64, incnum_textbox.displayed_string[])
    stressscale_temp               = parse(Float64, stressscale_textbox.displayed_string[])
    characteristic_equations_temp  = characteristicequations(plasticmodelversion_temp)
    println(characteristic_equations_temp)
    dependence_equations_temp      = dependenceequations(plasticmodelversion_temp)
    dependence_sliders_temp        = dependencesliders(plasticmodelversion_temp)
    modelinputs                           = Observable(ModelInputs{plasticmodelversion_temp}(
        plasticmodelversion_temp, propsfile_temp, expdatasets_temp,
        loading_axial_temp, loading_torsional_temp,
        incnum_temp, stressscale_temp,
        characteristic_equations_temp,
        dependence_equations_temp,
        dependence_sliders_temp
    ))
    println(modelinputs[].plasticmodelversion)
    println(modelinputs[].characteristic_equations)
    # notify(modelinputs)
    # plasticmodelversion[] = plasticmodelversion_temp; notify(plasticmodelversion)
    # propsfile[] = propsfile_temp; notify(propsfile)
    # expdatasets[] = expdatasets_temp; notify(expdatasets)
    # loading_axial[] = loading_axial_temp; notify(loading_axial)
    # loading_torsional[] = loading_torsional_temp; notify(loading_torsional)
    # incnum[] = incnum_temp; notify(incnum)
    # stressscale[] = stressscale_temp; notify(stressscale)
    # characteristic_equations[] = characteristic_equations_temp; notify(characteristic_equations)
    # dependence_equations[] = dependence_equations_temp; notify(dependence_equations)
    # dependence_sliders[] = dependence_sliders_temp; notify(dependence_sliders)
    # modeldata[]                             = calibration_init(modelinputs[].plasticmodelversion,
    #     modelinputs[], materialproperties(modelinputs[].plasticmodelversion));                              notify(modeldata)
    # modelcalibration[].modeldata            = modeldata[];                                                  notify(modelcalibration)
    modeldata                       = Observable(calibration_init(modelinputs[].plasticmodelversion, modelinputs[], materialproperties(modelinputs[].plasticmodelversion)))
    println(modeldata[].modelinputs.characteristic_equations)
    # notify(modeldata)
    # modeldataseries                 = Observable(dataseries_init(plasticmodelversion[], modeldata[].nsets, modeldata[].test_data))
    leg = try
        axislegend(modelcalibration[].ax, position=:rb)
    catch exc
        nothing
    end
    println(keys(modeldata[].params))
    modelcalibration                = Observable(ModelCalibration(
        modeldata[], modelcalibration[].ax, dataseries_init(modeldata[].modelinputs.plasticmodelversion, modeldata[].nsets, modeldata[].test_data), leg))
    println(modelcalibration[].modeldata.modelinputs.characteristic_equations)
    # notify(modelcalibration)
    empty!(g)
    sliders_grid[]    = GridLayout(g[1, 1], length(modelinputs[].dependence_equations), 3); notify(sliders_grid)
    println(@__LINE__, ", Made it here...")
    sliders_toggles[] = [ # add toggles for which to calibrate
        toggle!(sliders_grid[][i, 1]) for i in range(1, length(modelinputs[].dependence_equations))]
    notify(sliders_toggles)
    sliders_labels[]  = [ # label each slider with equation
        depeq_label!(sliders_grid[][i, 2], eq) for (i, eq) in enumerate(modelinputs[].dependence_equations)]
    notify(sliders_labels)
    println(@__LINE__, ", Made it here...")
    # println(typeof([
    #     sg_slider!(sliders_grid[][i, 3], modelinputs[].dependence_sliders[i]) for i in range(1, length(modelinputs[].dependence_sliders))]))
    sliders_sliders = Observable([
        sg_slider!(sliders_grid[][i, 3], modelinputs[].dependence_sliders[i]) for i in range(1, length(modelinputs[].dependence_sliders))])
    # notify(sliders_sliders)
    # empty!(sliders_sliders[]); notify(sliders_sliders)
    # u, v = length(sliders_sliders[]), length(modelinputs[].dependence_sliders)
    # println((u, v))
    # if u > v
    #     for (i, slider) in enumerate(modelinputs[].dependence_sliders)
    #         println(i)
    #         println(typeof(sg_slider!(sliders_grid[][i, 3], slider)))
    #         sliders_sliders[][i] = sg_slider!(sliders_grid[][i, 3], slider);                    notify(sliders_sliders)
    #     end
    #     for i in range(u, v + 1; step=-1)
    #         deleteat!(sliders_sliders[], i);                notify(sliders_sliders)
    #     end
    # elseif u < v
    #     for (i, slider) in enumerate(modelinputs[].dependence_sliders[begin:u])
    #         sliders_sliders[][i] = sg_slider!(sliders_grid[][i, 3], slider);                    notify(sliders_sliders)
    #     end
    #     append!(sliders_sliders[], [sg_slider!(sliders_grid[][i, 3], slider) for (i, slider) in enumerate(modelinputs[].dependence_sliders[u + 1:end])]);    notify(sliders_sliders)
    # else
    #     sliders_sliders[] .= modelinputs[].dependence_sliders
    # end;                                                notify(sliders_sliders)
    reset_sliders!(sliders_sliders, modeldata, modelcalibration)
    modelcalibration[].dataseries           = dataseries_init(modelinputs[].plasticmodelversion,
        modelcalibration[].modeldata.nsets, modelcalibration[].modeldata.test_data);                        notify(modelcalibration)
    plot_sets!(modelinputs[].plasticmodelversion, modelcalibration)
    !isnothing(modelcalibration[].leg) ? (modelcalibration[].leg = axislegend(modelcalibration[].ax, position=:rb)) : nothing; notify(modelcalibration)
    # return nothing
    return modelinputs, modeldata, modelcalibration, sliders_sliders
end

function screenmain_inputs!(fig, f, w,
        plasticmodelversion, propsfile, expdatasets,
        loading_axial, loading_torsional,
        incnum, stressscale,
        characteristic_equations,
        dependence_equations,
        dependence_sliders)
    figfontsize = fig.scene.theme.fontsize[]
    # sub-figure for input parameters of calibration study
    f_a = GridLayout(f[ 1,  1], 4, 3)
    ## model selection
    f_aa = GridLayout(f_a[1, :], 2, 3)
    modelclass_label        = Label(f_aa[ 1,  1], "Model Class")
    modelclass_types        = Observable(subtypes(Plasticity))
    modelclass_default      = @lift first($modelclass_types)
    modelclass_menu         = Menu(f_aa[ 2,  1],
        options=zip(repr.(modelclass_types[]), modelclass_types[]),
        default=repr(modelclass_default[]), width=32figfontsize)
    println(@__LINE__, ", ", repr.(modelclass_types[]))
    println(@__LINE__, ", ", repr(modelclass_default[]))

    modeltype_label         = Label(f_aa[ 1,  2], "Model Type")
    modeltype_types         = Observable(subtypes(modelclass_default[]))
    if isempty(modeltype_types[])
        modeltype_types[] = [modelclass_default[]]; notify(modeltype_types)
    end
    modeltype_default       = @lift first($modeltype_types)
    modeltype_menu          = Menu(f_aa[ 2,  2],
        options=zip(repr.(modeltype_types[]), modeltype_types[]),
        default=repr(modeltype_default[]), width=32figfontsize)
    println(@__LINE__, ", ", repr.(modeltype_types[]))
    println(@__LINE__, ", ", repr(modeltype_default[]))

    modelversion_label      = Label(f_aa[ 1,  3], "Model Version")
    modelversion_types      = Observable(subtypes(modeltype_default[]))
    if isempty(modelversion_types[])
        modelversion_types[] = [modeltype_default[]]; notify(modelversion_types)
    end
    modelversion_default    = @lift first($modelversion_types)
    modelversion_menu       = Menu(f_aa[ 2,  3],
        options=zip(repr.(modelversion_types[]), modelversion_types[]),
        default=repr(modelversion_default[]), width=32figfontsize)
    println(@__LINE__, ", ", repr.(modelversion_types[]))
    println(@__LINE__, ", ", repr(modelversion_default[]))
    on(modelclass_menu.selection) do s
        modelclass_default[] = s; notify(modelclass_default)
        println(@__LINE__, ", ", modelclass_default[])

        modeltype_types_temp = subtypes(modelclass_default[])
        modeltype_types[] = if isempty(modeltype_types_temp)
            [modelclass_default[]]
        else
            modeltype_types_temp
        end; notify(modeltype_types)
        modeltype_default[] = first(modeltype_types[]); notify(modeltype_default)
        modeltype_menu.options[] = zip(repr.(modeltype_types[]), modeltype_types[])
        modeltype_menu.selection[] = modeltype_default[]
        modeltype_menu.i_selected[] = 1
        notify(modeltype_menu.options)
        notify(modeltype_menu.selection)
        notify(modeltype_menu.i_selected)
        println(@__LINE__, ", ", modeltype_default[])

        modelversion_types_temp = subtypes(modeltype_default[])
        modelversion_types[] = if isempty(modelversion_types_temp)
            [modeltype_default[]]
        else
            modelversion_types_temp
        end; notify(modelversion_types)
        modelversion_default[] = first(modelversion_types[]); notify(modelversion_default)
        modelversion_menu.options[] = zip(repr.(modelversion_types[]), modelversion_types[])
        modelversion_menu.selection[] = modelversion_default[]
        modelversion_menu.i_selected[] = 1
        notify(modelversion_menu.options)
        notify(modelversion_menu.selection)
        notify(modelversion_menu.i_selected)
        println(@__LINE__, ", ", modelversion_default[])
    end
    # on(modeltype_menu.selection) do s
    #     modeltype_default[] = s; notify(modeltype_default)
    #     println(@__LINE__, ", ", modeltype_default[])

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
    #     println(@__LINE__, ", ", modelversion_default[])
    # end
    # on(modelversion_menu.selection) do s
    #     modelversion_default[] = s; notify(modelversion_default)
    #     println(@__LINE__, ", ", modelversion_default[])
    # end
    ## propsfile
    propsfile_label                 = Label(f_a[ 2,  1], "Path to parameters dictionary:"; halign=:right)
    propsfile_textbox               = Textbox(f_a[ 2,  2], placeholder="path/to/dict",
        width=w[]) # , stored_string=propsfile, displayed_string=propsfile)
    propsfile_button                = Button(f_a[ 2,  3], label="Browse")
    # propsfile                       = Observable("")
    ## experimental datasets
    expdatasets_label               = Label(f_a[ 3,  1], "Paths to experimental datasets:"; halign=:right)
    expdatasets_textbox             = Textbox(f_a[ 3,  2], placeholder="path/to/experimental datasets",
        height=5fig.scene.theme.fontsize[], width=w[]) # , stored_string=input_files, displayed_string=input_files)
    expdatasets_button              = Button(f_a[ 3,  3], label="Browse")
    # expdatasets                     = Observable([""])
    ## loading direction toggles
    loadingdirection_label          = Label(f_a[ 4,  1], "Loading directions in experiments:"; halign=:right)
    ## loading conditions
    f_ab = GridLayout(f_a[ 4,  2], 1, 2)
    f_aba = GridLayout(f_ab[ 1,  1], 1, 2)
    loaddir_axial_label             = Label(f_aba[ 1,  1], "Tension/Compression:"; halign=:right)
    loaddir_axial_toggle            = Toggle(f_aba[ 1,  2], active=true)
    f_abb = GridLayout(f_ab[ 1,  2], 1, 2)
    loaddir_torsion_label           = Label(f_abb[ 1,  1], "Torsion:"; halign=:right)
    loaddir_torsion_toggle          = Toggle(f_abb[ 1,  2], active=false)
    ## number of strain increments
    f_ac = GridLayout(f_a[5, :], 1, 2; halign=:left)
    f_aca = GridLayout(f_ac[1, 1], 1, 2; halign=:left)
    incnum_label                    = Label(f_aca[ 1,  1], "Number of strain increments for model curves:"; halign=:right)
    incnum_textbox                  = Textbox(f_aca[ 1,  2], placeholder="non-zero integer",
        width=5fig.scene.theme.fontsize[], stored_string="200", displayed_string="200", validator=Int64, halign=:left)
    f_acb = GridLayout(f_ac[1, 2], 1, 2; halign=:left)
    stressscale_label               = Label(f_acb[ 1,  1], "Scale of stress axis:"; halign=:right)
    stressscale_textbox             = Textbox(f_acb[ 1,  2], placeholder="non-zero integer",
            width=5fig.scene.theme.fontsize[], stored_string="1.0", displayed_string="1.0", validator=Float64, halign=:left)
    # aacb = GridLayout(aac[1, 2], 1, 2; halign=:right)
    # Plot_ISVs_label       = Label(aacb[ 1,  1], "Vector of ISV symbols to plot:"; halign=:right)
    # Plot_ISVs_textbox   = Textbox(aacb[ 1,  2], placeholder="non-zero integer",
    #     width=0.5w[], stored_string=":alpha, :kappa", displayed_string=":alpha, :kappa", halign=:left)

    plasticmodelversion[]       = modelversion_default[];                            notify(plasticmodelversion)
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
    characteristic_equations  = characteristicequations(plasticmodelversion[]) # ;           notify(characteristic_equations)
    dependence_equations      = dependenceequations(plasticmodelversion[]) # ;               notify(dependence_equations)
    dependence_sliders[]        = dependencesliders(plasticmodelversion[]);                 notify(dependence_sliders)

    # dynamic backend functions
    ## browse for parameters dictionary
    on(propsfile_button.clicks) do click
        update_propsfile!(propsfile, propsfile_textbox)
    end
    ## experimental datasets (browse)
    on(expdatasets_button.clicks) do click
        update_experimentaldata!(expdatasets, expdatasets_textbox)
    end
    ## experimental datasets (drag-and-drop)
    on(events(fig.scene).dropped_files) do filedump
        println(filedump)
        update_experimentaldata_draganddrop!(expdatasets, expdatasets_textbox, filedump)
    end

    return (modelversion_menu,
        propsfile_textbox, expdatasets_textbox,
        loaddir_axial_toggle, loaddir_torsion_toggle,
        incnum_textbox, stressscale_textbox,
        characteristic_equations, dependence_equations)
end

function screenmain_interactions!(f, g, h,
        plasticmodeltypeversion_menu, propsfile_textbox, expdatasets_textbox,
        loaddir_axial_toggle, loaddir_torsion_toggle,
        incnum_textbox, stressscale_textbox, modelinputs, modeldata, modelcalibration,
        sliders_grid, sliders_toggles, sliders_labels, sliders_sliders)
    characteristic_equations    = modelinputs[].characteristic_equations
    # dependence_equations        = modelinputs[].dependence_equations
    # dependence_sliders          = modelinputs[].dependence_sliders
    # screenmain_plot!(f, g, modelinputs, modeldata, modelcalibration, sliders_sliders)
    println(sliders_sliders)
    ### sub-figure for model selection, sliders, and plot
    f_b = GridLayout(f[ 1,  1], 3, 1)
    f_ba = GridLayout(f_b[1, 1], 1, 1)
    buttons_updateinputs = Button(f_ba[ 1,  1], label="Update inputs", valign=:bottom)

    f_bb = @lift GridLayout(f_b[2, 1], length($modelinputs.characteristic_equations), 1)
    chareqs_labels = Observable([
        chareq_label(f_bb[][i, 1], eq) for (i, eq) in enumerate(characteristic_equations)])
    # grid_sliders    = GridLayout(ba[ 2,  1], 10, 3)
    showsliders_button = Button(f_b[3, 1], label="Show sliders")

    # h = Figure(size=(600, 400))
    #### plot
    plot_sets!(modelcalibration[].modeldata.plasticmodelversion, modelcalibration)
    modelcalibration[].leg = try
        axislegend(modelcalibration[].ax, position=:rb)
    catch exc
        nothing
    end; notify(modelcalibration)
    # update!(dataseries[], bcj[], incnum[], istate[], Plot_ISVs[], BCJMetal[])
    update!(modelcalibration[].modeldata.plasticmodelversion, modelcalibration)

    #### buttons below plot
    buttons_grid = GridLayout(g[ 10,  :], 1, 5)
    buttons_labels = ["Calibrate", "Reset", "Show ISVs", "Save Props", "Export Curves"]
    buttons = [Button(buttons_grid[1, i], label=bl) for (i, bl) in enumerate(buttons_labels)]
    buttons_calibrate       = buttons[1]
    buttons_resetparams     = buttons[2]
    buttons_showisvs        = buttons[3]
    buttons_savecurves      = buttons[4]
    buttons_exportcurves    = buttons[5]

    # backend functions
    ## update input parameters to calibrate
    on(buttons_updateinputs.clicks) do click
        modelinputs, modeldata, modelcalibration, sliders_sliders = update_inputs!(f, h,
            plasticmodeltypeversion_menu, propsfile_textbox, expdatasets_textbox,
            loaddir_axial_toggle, loaddir_torsion_toggle,
            incnum_textbox, stressscale_textbox, modelinputs, modeldata, modelcalibration,
            sliders_grid, sliders_toggles, sliders_labels, sliders_sliders)
        for c in contents(f_bb[])
            delete!(c)
        end; trim!(f_bb[])
        f_bb[] = GridLayout(f_b[2, 1], 1, 1); notify(f_bb)
        println(modelcalibration[].modeldata.modelinputs.characteristic_equations)
        chareqs_labels[] = [
            chareq_label(f_bb[][i, 1], eq) for (i, eq) in enumerate(modelcalibration[].modeldata.modelinputs.characteristic_equations)]
        notify(chareqs_labels)
        println(sliders_sliders)
        # screenmain_plot!(f, g, modelinputs, modeldata, modelcalibration, sliders_sliders)
    end
    ## show sliders
    on(showsliders_button.clicks) do click
        println(sliders_sliders)
        main_sliders(h, modelcalibration, modeldata, sliders_sliders)
    end
    ## buttons
    ### calibrate parameters
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
            println(result)
            q = Optim.minimizer(result)
            println((p, q))
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
    ### reset sliders/parameters
    on(buttons_resetparams.clicks) do click
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
        reset_sliders!(sliders_sliders, modeldata, modelcalibration)
    end
    ### show isv plot
    on(buttons_showisvs.clicks) do click
        screen_isvs = GLMakie.Screen(; title="ISVs") # , focus_on_show=true)
        display(screen_isvs, h)
    end
    ### save parameters
    on(buttons_savecurves.clicks) do click
        # propsfile = modelcalibration[].modeldata.modelinputs.propsfile
        # props_dir, props_name = dirname(propsfile), basename(propsfile)
        # "Save new props file"
        propsfile_new = save_file(; filterlist="csv")
        dict = modelcalibration[].modeldata.materialproperties
        for (key, val) in modelcalibration[].modeldata.params
            dict[key] = val
        end
        CSV.write(propsfile_new, DataFrame(dict))
        println("New props file written to: \"", propsfile_new, "\"")
    end
    ### export curves
    on(buttons_exportcurves.clicks) do click
        # props_dir, props_name = dirname(propsfile[]), basename(propsfile[])
        curvefile_new = save_file(; filterlist="csv")
        println([curvefile_new])
        if !isempty(curvefile_new) || curvefile_new != ""
            header, df = [], DataFrame()
            for (i, test_name, test_strain, test_stress) in zip(range(1, modelcalibration[].modeldata.nsets), modelcalibration[].modeldata.test_cond["Name"], modelcalibration[].modeldata.test_data["Model_E"], modelcalibration[].modeldata.test_data["Model_VM"])
                push!(header, "strain-" * test_name)
                push!(header, "VMstress" * test_name)
                DataFrames.hcat!(df, DataFrame(
                    "strain-" * test_name   => test_strain,
                    "VMstress" * test_name  => test_stress))
            end
            CSV.write(curvefile_new, df, header=header)
            println("Model curves written to: \"", curvefile_new, "\"")
        end
    end

    return nothing
end

function main_sliders(fig, modelcalibration, modeldata, sg_sliders)
    ### update curves from sliders
    @lift for (key, sgs) in zip(materialconstants_index(modelcalibration[].modeldata.plasticmodelversion), collectragged($sg_sliders))
        on(only(sgs.sliders).value) do val
            # redefine materialproperties with new slider values
            modeldata[].params[key] = to_value(val); notify(modeldata)
            modelcalibration[].modeldata.params[key] = to_value(val); notify(modelcalibration)
            update!(modelcalibration[].modeldata.plasticmodelversion, modelcalibration)
        end
    end
    display(GLMakie.Screen(; title="Sliders", focus_on_show=true), fig)
    return nothing
end

function main()
    screen_main = GLMakie.Screen(; title="PlasticityCalibratinator.jl", fullscreen=true, focus_on_show=true)
    fig = Figure(size=(900, 600), figure_padding=(30, 10, 10, 10), layout=GridLayout(2, 1)) # , tellheight=false, tellwidth=false)
    # f = Figure(figure_padding=(0.5, 0.95, 0.2, 0.95), layout=GridLayout(3, 1))
    w = @lift widths($(fig.scene.viewport))[1]
    # w = @lift widths($(f.scene))[1]

    # sub-figure for input parameters of calibration study
    a = GridLayout(fig[ 1,  1], 2, 1)
    # sub-figure for model selection, sliders, and plot
    b = GridLayout(fig[ 2,  1], 1, 2)
    c = GridLayout(b[ 1,  2], 10, 9)
    # Box(b[1, 1], color=(:red, 0.2), strokewidth=0)
    # Box(b[1, 2], color=(:red, 0.2), strokewidth=0)
    # # # # colsize!(f.layout, 1, Relative(0.45))
    # # # # colsize!(f.layout, 2, Relative(0.45))
    # # # colsize!(f.layout, 2, Aspect(1, 1.0))
    # # rowsize!(f.layout, 1, Relative(0.3))
    # # rowsize!(f.layout, 2, Relative(0.7))
    # # rowsize!(b, 1, 3\2w[])
    rowsize!(b, 1, Relative(0.8))

    # plasticmodelversion         ::Type{<:Plasticity}    = Plasticity
    # propsfile                   ::String                = ""
    # expdatasets                 ::Vector{String}        = [""]
    # loading_axial               ::Bool                  = true
    # loading_torsional           ::Bool                  = false
    # incnum                      ::Integer               = 200
    # stressscale                 ::AbstractFloat         = 1e6
    # characteristic_equations    ::Vector{String}        = [""]
    # dependence_equations        ::Vector{String}        = [""]
    # dependence_sliders                                  = []
    plasticmodelversion         = Observable(Plasticity)    # ::Type{<:Plasticity}
    propsfile                   = Observable("")            # ::String
    expdatasets                 = Observable([""])          # ::Vector{String}
    loading_axial               = Observable(true)          # ::Bool
    loading_torsional           = Observable(false)         # ::Bool
    incnum                      = Observable(200)           # ::Integer
    stressscale                 = Observable(1e6)           # ::AbstractFloat
    characteristic_equations    = [' ']          # ::Vector{String}
    dependence_equations        = [' ']          # ::Vector{String}
    dependence_sliders          = Observable([])            # ::Any
    inputobjects                = screenmain_inputs!(fig, a, w,
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
    modelinputs                 = Observable(ModelInputs{plasticmodelversion[]}(
        plasticmodelversion[], propsfile[], expdatasets[],
        loading_axial[], loading_torsional[],
        incnum[], stressscale[],
        characteristic_equations,
        dependence_equations,
        dependence_sliders[]
    ))

    ax = Axis(c[ 1:  9,  1:  9],
        xlabel="True Strain (mm/mm)",
        ylabel="True Stress (Pa)",
        aspect=1.0, tellheight=true, tellwidth=true) # , height=3\2w[], width=w[])
    # xlims!(ax, (0., nothing)); ylims!(ax, (min_stress, max_stress))
    # xlims!(ax_isv, (0., nothing)); ylims!(ax_isv, (min_stress, max_stress))
    # BCJinator.plot_sets!(ax, ax_isv, dataseries[], bcj[], Plot_ISVs[])
    # leg = Observable(axislegend(ax, position=:rb))
    # BCJinator.update!(dataseries[], bcj[], incnum[], istate[], Plot_ISVs[], BCJMetal[])

    # modeldata                       = Observable(ModelData(
    #     plasticmodelversion, materialproperties{plasticmodelversion},
    #     incnum, stressscale,
    # ))
    modeldata                       = Observable(calibration_init(modelinputs[].plasticmodelversion, modelinputs[], materialproperties(modelinputs[].plasticmodelversion)))
    # modeldataseries                 = Observable(dataseries_init(plasticmodelversion[], modeldata[].nsets, modeldata[].test_data))
    leg = try
        axislegend(ax, position=:rb)
    catch exc
        nothing
    end
    println(keys(modeldata[].params))
    modelcalibration                = Observable(ModelCalibration(
        modeldata[], ax, dataseries_init(modeldata[].modelinputs.plasticmodelversion, modeldata[].nsets, modeldata[].test_data), leg))

    d = Figure(size=(450, 600))
    sliders_grid    = @lift GridLayout(d[1, 1], length($modelinputs.dependence_equations), 3)
    sliders_toggles = Observable([ # add toggles for which to calibrate
        toggle!(sliders_grid[][i, 1]) for i in range(1, length(modelinputs[].dependence_equations))])
    sliders_labels  = Observable([ # label each slider with equation
        depeq_label!(sliders_grid[][i, 2], eq) for (i, eq) in enumerate(modelinputs[].dependence_equations)])
    sliders_sliders = Observable([
        sg_slider!(sliders_grid[][i, 3], modelinputs[].dependence_sliders[i]) for i in range(1, length(modelinputs[].dependence_sliders))])
    println(sliders_sliders[])

    screenmain_interactions!(b, c, d,
        plasticmodeltypeversion_menu, propsfile_textbox, expdatasets_textbox,
        loaddir_axial_toggle, loaddir_torsion_toggle,
        incnum_textbox, stressscale_textbox, modelinputs, modeldata, modelcalibration,
        sliders_grid, sliders_toggles, sliders_labels, sliders_sliders)
    #### plot
    # screenmain_plot!(fig, c, modelinputs, modeldata, modelcalibration, sliders_sliders)
    display(screen_main, fig) # that's all folks!
    return nothing
end