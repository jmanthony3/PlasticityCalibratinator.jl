# gui.jl
using CSV
using DataFrames
using Distributed
using GLMakie
using LaTeXStrings
using NativeFileDialog

import BammannChiesaJohnsons as BCJ


set_theme!(theme_latexfonts())



# default values
incnum      = Observable(200)
istate      = 1      #1 = tension, 2 = torsion
Ask_Files   = true
Material    = "4340"
Plot_ISVs   = false
MPa         = 1e6           # Unit conversion from MPa to Pa from data
min_stress  = 0.
max_stress  = 3000 * MPa

if Material == "4340"
    max_stress  = 2000 * MPa
end

## sliders
nsliders = 20       # Index with "s in range(1,nsliders):" so s corresponds with C#
C_amp   = Vector{Float64}(undef, nsliders)
C_0     = Vector{Float64}(undef, nsliders)
Slider_C= Vector{Float64}(undef, nsliders)

### amplitude range on sliders
# 
C_amp[1]    = 300.0
C_amp[2]    = 300.0
C_amp[3]    = 100.0
C_amp[4]    = 300.1
C_amp[5]    = 0.5
C_amp[6]    = 300.0
# 
C_amp[7]    = 0.0001
C_amp[8]    = 300.0
C_amp[9]    = 600.0
C_amp[10]   = 10.0
C_amp[11]   = 3.0
C_amp[12]   = 300.0
# 
C_amp[13]   = 1.0
C_amp[14]   = 300.0
C_amp[15]   = 600.0
C_amp[16]   = 10.0
C_amp[17]   = 3.0
C_amp[18]   = 300.0
# 
C_amp[19]   = 10.0
C_amp[20]   = 300.0


# material properties
include("filepaths.jl")
propsfile   = Observable(propsfile) # trying to switch over to observable
df          = CSV.read(propsfile[], DataFrame; header=true, delim=',', types=[String, Float64])
rowsofconstants = findall(occursin.(r"C\d{2}", df[!, "Comment"]))
C_0[rowsofconstants] .= df[!, "For Calibration with vumat"][rowsofconstants]
bulk_mod    = df[!, "For Calibration with vumat"][findfirst(occursin("Bulk Mod"), df[!, "Comment"])]
shear_mod   = df[!, "For Calibration with vumat"][findfirst(occursin("Shear Mod"), df[!, "Comment"])]
params      = Observable(Dict( # collect as dictionary
    "C01"       => C_0[ 1],
    "C02"       => C_0[ 2],
    "C03"       => C_0[ 3],
    "C04"       => C_0[ 4],
    "C05"       => C_0[ 5],
    "C06"       => C_0[ 6],
    "C07"       => C_0[ 7],
    "C08"       => C_0[ 8],
    "C09"       => C_0[ 9],
    "C10"       => C_0[10],
    "C11"       => C_0[11],
    "C12"       => C_0[12],
    "C13"       => C_0[13],
    "C14"       => C_0[14],
    "C15"       => C_0[15],
    "C16"       => C_0[16],
    "C17"       => C_0[17],
    "C18"       => C_0[18],
    "C19"       => C_0[19],
    "C20"       => C_0[20],
    "bulk_mod"  => bulk_mod,
    "shear_mod" => shear_mod
))
# ------------------------------------------------
# store stress-strain data and corresponding test conditions (temp and strain rate)
files       = Observable(files)     # trying to switch over to observable
joinfiles(fs) = join([fs...], "; ")
input_files = lift(joinfiles, files)
bcj         = Observable(BCJ.BCJ_metal_calibrate_init(files[], incnum[], istate, params[], MPa))
# lines[1] = data
# lines[2] = model (to be updated)
# lines[3] = alpha model (to be updated)
# lines[4] = kappa model (to be updated)
dataseries  = Observable(BCJ.dataseries_init(bcj[].nsets, bcj[].test_data, Plot_ISVs))



################################################################
#                   B E G I N   F I G U R E                    #
################################################################



# top-level figure
# figure_padding=(plot_left, plot_right, plot_bot, plot_top)
f = Figure(figure_padding=(0.5, 0.95, 0.2, 0.95), layout=GridLayout(1, 2))
# f = Figure(figure_padding=(0.5, 0.95, 0.2, 0.95), layout=GridLayout(3, 1))
w = @lift widths($(f.scene.viewport))[1]
# w = @lift widths($(f.scene))[1]

## sub-figure for input parameters of calibration study
a = GridLayout(f[ 1,  1], 1, 2)
aa = GridLayout(a[ 1,  1], 3, 3)
### propsfile
propsfile_label       = Label(aa[ 1,  1], "Path to parameters dictionary:")
propsfile_textbox   = Textbox(aa[ 1,  2], placeholder="path/to/dict",
    width=w[], stored_string=propsfile, displayed_string=propsfile)
propsfile_button     = Button(aa[ 1,  3], label="Browse")
### experimental datasets
expdatasets_label     = Label(aa[ 2,  1], "Paths to experimental data:")
expdatasets_textbox = Textbox(aa[ 2,  2], placeholder="path/to/experimental datasets",
    width=w[], stored_string=input_files, displayed_string=input_files)
expdatasets_button   = Button(aa[ 2,  3], label="Browse")
### number of strain increments
incnum_label          = Label(aa[ 3,  1], "Number of strain increments:")
incnum_textbox      = Textbox(aa[ 3,  2], placeholder="non-zero integer",
    width=w[], stored_string="200", displayed_string="200", validator=Int64)
### update calibration study
buttons_updateinputs = Button(a[ 1,  2], label="Update inputs")

## sub-figure for sliders and plot
b = GridLayout(f[ 2,  1], 1, 2)
grid_sliders    = GridLayout(b[ 1,  1], 10,  1)
grid_plot       = GridLayout(b[ 1,  2])
Box(b[1, 1], color=(:red, 0.2), strokewidth=0)
Box(b[1, 2], color=(:red, 0.2), strokewidth=0)
# # colsize!(f.layout, 1, Relative(0.45))
# # colsize!(f.layout, 2, Relative(0.45))
# colsize!(f.layout, 2, Aspect(1, 1.0))

### sliders
# label each slider with equation
textbox_V   = Label(grid_sliders[ 1,  1], L"V = C_{ 1} \mathrm{exp}(-C_{ 2} / \theta)")
textbox_Y   = Label(grid_sliders[ 2,  1], L"Y = C_{ 3} \mathrm{exp}( C_{ 4} / \theta)")
textbox_f   = Label(grid_sliders[ 3,  1], L"f = C_{ 5} \mathrm{exp}(-C_{ 6} / \theta)")
textbox_rd  = Label(grid_sliders[ 4,  1], L"r_{d} = C_{ 7} \mathrm{exp}(-C_{ 8} / \theta)")
textbox_h   = Label(grid_sliders[ 5,  1], L"h = C_{ 9} - C_{10}\theta")
textbox_rs  = Label(grid_sliders[ 6,  1], L"r_{s} = C_{11} \mathrm{exp}(-C_{12} / \theta)")
textbox_Rd  = Label(grid_sliders[ 7,  1], L"R_{d} = C_{13} \mathrm{exp}(-C_{14} / \theta)")
textbox_H   = Label(grid_sliders[ 8,  1], L"H = C_{15} - C_{16}\theta")
textbox_Rs  = Label(grid_sliders[ 9,  1], L"R_{s} = C_{17} \mathrm{exp}(-C_{18} / \theta)")
textbox_Yadj= Label(grid_sliders[10,  1], L"Y_{adj}")
# make a slider for each constant
# V
sg_C01      = SliderGrid(grid_sliders[ 1,  2][ 1,  1], (label=L"C_{ 1}", range=0.:10.:5C_0[ 1], format="{:.3e}", startvalue=C_0[ 1])) # , width=0.4w[]))
sg_C02      = SliderGrid(grid_sliders[ 1,  2][ 2,  1], (label=L"C_{ 2}", range=0.:10.:5C_0[ 2], format="{:.3e}", startvalue=C_0[ 2])) # , width=0.4w[]))
# Y
sg_C03      = SliderGrid(grid_sliders[ 2,  2][ 1,  1], (label=L"C_{ 3}", range=0.:10.:5C_0[ 3], format="{:.3e}", startvalue=C_0[ 3])) # , width=0.4w[]))
sg_C04      = SliderGrid(grid_sliders[ 2,  2][ 2,  1], (label=L"C_{ 4}", range=0.:10.:5C_0[ 4], format="{:.3e}", startvalue=C_0[ 4])) # , width=0.4w[]))
# f
sg_C05      = SliderGrid(grid_sliders[ 3,  2][ 1,  1], (label=L"C_{ 5}", range=0.:10.:5C_0[ 5], format="{:.3e}", startvalue=C_0[ 5])) # , width=0.4w[]))
sg_C06      = SliderGrid(grid_sliders[ 3,  2][ 2,  1], (label=L"C_{ 6}", range=0.:10.:5C_0[ 6], format="{:.3e}", startvalue=C_0[ 6])) # , width=0.4w[]))
# rd
sg_C07      = SliderGrid(grid_sliders[ 4,  2][ 1,  1], (label=L"C_{ 7}", range=0.:10.:5C_0[ 7], format="{:.3e}", startvalue=C_0[ 7])) # , width=0.4w[]))
sg_C08      = SliderGrid(grid_sliders[ 4,  2][ 2,  1], (label=L"C_{ 8}", range=0.:10.:5C_0[ 8], format="{:.3e}", startvalue=C_0[ 8])) # , width=0.4w[]))
# h
sg_C09      = SliderGrid(grid_sliders[ 5,  2][ 1,  1], (label=L"C_{ 9}", range=0.:10.:5C_0[ 9], format="{:.3e}", startvalue=C_0[ 9])) # , width=0.4w[]))
sg_C10      = SliderGrid(grid_sliders[ 5,  2][ 2,  1], (label=L"C_{10}", range=0.:10.:5C_0[10], format="{:.3e}", startvalue=C_0[10])) # , width=0.4w[]))
# rs
sg_C11      = SliderGrid(grid_sliders[ 6,  2][ 1,  1], (label=L"C_{11}", range=0.:10.:5C_0[11], format="{:.3e}", startvalue=C_0[11])) # , width=0.4w[]))
sg_C12      = SliderGrid(grid_sliders[ 6,  2][ 2,  1], (label=L"C_{12}", range=0.:10.:5C_0[12], format="{:.3e}", startvalue=C_0[12])) # , width=0.4w[]))
# Rd
sg_C13      = SliderGrid(grid_sliders[ 7,  2][ 1,  1], (label=L"C_{13}", range=0.:10.:5C_0[13], format="{:.3e}", startvalue=C_0[13])) # , width=0.4w[]))
sg_C14      = SliderGrid(grid_sliders[ 7,  2][ 2,  1], (label=L"C_{14}", range=0.:10.:5C_0[14], format="{:.3e}", startvalue=C_0[14])) # , width=0.4w[]))
# H
sg_C15      = SliderGrid(grid_sliders[ 8,  2][ 1,  1], (label=L"C_{15}", range=0.:10.:5C_0[15], format="{:.3e}", startvalue=C_0[15])) # , width=0.4w[]))
sg_C16      = SliderGrid(grid_sliders[ 8,  2][ 2,  1], (label=L"C_{16}", range=0.:10.:5C_0[16], format="{:.3e}", startvalue=C_0[16])) # , width=0.4w[]))
# Rs
sg_C17      = SliderGrid(grid_sliders[ 9,  2][ 1,  1], (label=L"C_{17}", range=0.:10.:5C_0[17], format="{:.3e}", startvalue=C_0[17])) # , width=0.4w[]))
sg_C18      = SliderGrid(grid_sliders[ 9,  2][ 2,  1], (label=L"C_{18}", range=0.:10.:5C_0[18], format="{:.3e}", startvalue=C_0[18])) # , width=0.4w[]))
# Yadj
sg_C19      = SliderGrid(grid_sliders[10,  2][ 1,  1], (label=L"C_{19}", range=0.:10.:5C_0[19], format="{:.3e}", startvalue=C_0[19])) # , width=0.4w[]))
sg_C20      = SliderGrid(grid_sliders[10,  2][ 2,  1], (label=L"C_{20}", range=0.:10.:5C_0[20], format="{:.3e}", startvalue=C_0[20])) # , width=0.4w[]))
sg_sliders  = [ # collect sliders
    sg_C01, sg_C02, # V
    sg_C03, sg_C04, # Y
    sg_C05, sg_C06, # f
    sg_C07, sg_C08, # rd
    sg_C09, sg_C10, # h
    sg_C11, sg_C12, # rs
    sg_C13, sg_C14, # Rd
    sg_C15, sg_C16, # H
    sg_C17, sg_C18, # Rs
    sg_C19, sg_C20  # Yadj
]

### plot
ax = Axis(grid_plot[ 1:  9,  1:  9],
    xlabel="True Strain (mm/mm)",
    ylabel="True Stress (Pa)",
    aspect=1.0, width=w[])
xlims!(ax, (0., nothing)); ylims!(ax, (min_stress, max_stress))
BCJ.plot_sets!(ax, dataseries[], bcj[], Plot_ISVs)
leg = Observable(axislegend(ax, position=:lt))
BCJ.update!(dataseries[], bcj[], incnum[], istate, Plot_ISVs)

### buttons below plot
buttons_grid = GridLayout(grid_plot[ 10,  :], 1, 3)
buttons_labels = ["Reset", "Save Props", "Export Curves"]
buttons = buttons_grid[1, :] = [Button(f, label=bl) for bl in buttons_labels]
buttons_resetparams   = buttons[1]
buttons_savecurves    = buttons[2]
buttons_exportcurves  = buttons[3]



################################################################
#                     E N D   F I G U R E                      #
################################################################



# dynamic backend functions
## browse for parameters dictionary
on(propsfile_button.clicks) do click
    file = pick_file(; filterlist="csv")
    if file != ""
        propsfile[] = file;                                     notify(propsfile)
    end
end
## experimental data sets (browse)
on(expdatasets_button.clicks) do click
    filelist = pick_multi_file(; filterlist="csv")
    if !isempty(filelist)
        files[] = filelist;                                     notify(files)
    end
end
## experimental data sets (drag-and-drop)
on(events(f.scene).dropped_files) do filedump
    if !isempty(filedump)
        println(filedump)
        u, v = length(files[]), length(filedump)
        if u > v
            for (i, file) in enumerate(filedump)
                files[][i] = file;                              notify(files)
            end
            for i in range(u, v + 1; step=-1)
                deleteat!(files[], i);                          notify(files)
            end
        elseif u < v
            for (i, file) in enumerate(filedump[begin:u])
                files[][i] = file;                              notify(files)
            end
            append!(files[], filedump[u + 1:end]);              notify(files)
        else
            files[] .= filedump
        end;                                                    notify(files)
    end
end
## update input parameters to calibrate
on(buttons_updateinputs.clicks) do click
    empty!(ax); !isnothing(leg[]) ? delete!(leg[]) : nothing; notify(leg)
    incnum[] = parse(Int64, incnum_textbox.displayed_string[]); notify(incnum)
    bcj[] = BCJ.BCJ_metal_calibrate_init(files[], incnum[], istate, params[], MPa); notify(bcj)
    dataseries[] = BCJ.dataseries_init(bcj[].nsets, bcj[].test_data, Plot_ISVs); notify(dataseries)
    BCJ.plot_sets!(ax, dataseries[], bcj[], Plot_ISVs)
    !isnothing(leg) ? (leg[] = axislegend(ax, position=:lt)) : nothing; notify(leg)
end
## update curves from sliders
for (i, sgs) in enumerate(sg_sliders)
    on(only(sgs.sliders).value) do val
        # redefine params with new slider values
        params[][BCJ.constant_string(i)] = to_value(val);       notify(params)
        BCJ.update!(dataseries[], bcj[], incnum[], istate, Plot_ISVs)
    end
end
## reset sliders/parameters
on(buttons_resetparams.clicks) do click
    # for (i, c, sgc) in zip(range(1, nsliders), C_0, sg_sliders)
    #     params[][BCJ.constant_string(i)] = to_value(c);         notify(params)
    #     set_close_to!(sgc.sliders[1], c)
    #     sgc.sliders[1].value[] = to_value(c);                   notify(sgc.sliders[1].value)
    # end
    asyncmap((i, c, sgc)->begin # attempt multi-threading
            params[][BCJ.constant_string(i)] = to_value(c);     notify(params)
            set_close_to!(sgc.sliders[1], c)
            sgc.sliders[1].value[] = to_value(c);               notify(sgc.sliders[1].value)
        end, range(1, nsliders), C_0, sg_sliders)
end
## save parameters
on(buttons_savecurves.clicks) do click
    props_dir, props_name = dirname(propsfile), basename(propsfile)
    # "Save new props file"
    propsfile_new = save_file(; filterlist="csv")
    df = DataFrame(
        "Constants" => [BCJ.constant_string.(range(1, nsliders))..., "Bulk Mod", "Shear Mod"],
        "Values"    => [[only(sgc.sliders).value[] for sgc in sg_sliders]..., bulk_mod, shear_mod]
    )
    CSV.write(propsfile_new, df)
    println("New props file written to: \"", propsfile_new, "\"")
end
## export curves
on(buttons_exportcurves.clicks) do click
    props_dir, props_name = dirname(propsfile), basename(propsfile)
    curvefile_new = save_file(; filterlist="csv")
    header, df = [], DataFrame()
    for (i, test_name, test_strain, test_stress) in zip(range(1, bcj[].nsets), bcj[].test_cond["Name"], bcj[].test_data["Model_E"], bcj[].test_data["Model_VM"])
        push!(header, "strain-" * test_name)
        push!(header, "VMstress" * test_name)
        DataFrames.hcat!(df, DataFrame(
            "strain-" * test_name   => test_strain,
            "VMstress" * test_name  => test_stress))
    end
    CSV.write(curvefile_new, df, header=header)
    println("Model curves written to: \"", curvefile_new, "\"")
end



display(f) # that's all folks!