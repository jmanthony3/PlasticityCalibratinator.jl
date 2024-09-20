# # import numpy as np
# # import matplotlib.pyplot as plt
# # from matplotlib.widgets import Slider, Button
# # from tkinter import Tk
# # from tkinter.filedialog import askopenfilenames, askopenfilename, asksaveasfilename
# # import csv
# # import os
# # from BCJ_Basic_v2 import BCJ

using CSV
using DataFrames
using LaTeXStrings
# using Plots; gr()
using NativeFileDialog

# include("BammannChiesaJohnsons.jl")
# BCJ = BammannChiesaJohnsons

default(
    fontfamily="Computer Modern",
    linewidth=1,
    framestyle=:box,
    label=nothing,
    grid=false)

using GLMakie

# fig = Figure()

# ax = Axis(fig[1, 1])

# sg = SliderGrid(
#     fig[1, 2],
#     (label = "Voltage", range = 0:0.1:10, format = "{:.1f}V", startvalue = 5.3),
#     (label = "Current", range = 0:0.1:20, format = "{:.1f}A", startvalue = 10.2),
#     (label = "Resistance", range = 0:0.1:30, format = "{:.1f}Ω", startvalue = 15.9),
#     width = 350,
#     tellheight = false)

# sliderobservables = [s.value for s in sg.sliders]
# bars = lift(sliderobservables...) do slvalues...
#     [slvalues...]
# end

# barplot!(ax, bars, color = [:yellow, :orange, :red])
# ylims!(ax, 0, 30)

# fig

# """
#  Daniel Kenney
#  Summer 2023
#  --------------------------------
# - User editable variable 
#     - plotting parameters and layouts

# - read in props and data files
# - 

# - define sliders/buttons/layout
# - 
# - v2 - change data storage from list to dictionary
# """



# ------------------------------------------------
# ---------- User Modifiable Variables -----------
# ------------------------------------------------
incnum      = 200
istate      = 1      #1 = tension, 2 = torsion
Ask_Files   = true
Material    = "4340"
Plot_ISVs   = true


Scale_MPa   = 1000000           # Unit conversion from MPa to Pa from data
max_stress  = 3000 * 1000000

if Material == "4340"
    max_stress  = 2000 * 1000000
end



# ------------------------------------------------
# ------------------------------------------------
kS          = 0     # default tension component
if istate == 2
    kS      = 3     # select torsion component
end


# -------- Holding Variable Declarations --------
incnum1     = incnum + 1                    # +1 so that 100 increments between 0 and 1 are 0.01
Sₙ          = zeros(Float64, (6, incnum1))  # Total stress state
S           = zeros(Float64, (   incnum1))  # Stress in relevant direction
SVM         = zeros(Float64, (   incnum1))  # VM Stress
ϵₙ          = zeros(Float64, (6, incnum1))  # Total stress state
E           = zeros(Float64, (   incnum1))  # Stress in relevant direction
Al          = zeros(Float64, (   incnum1))  # Alphpa in relevant direction
ratio       = zeros(Float64, (   incnum1))  # Alphpa in relevant direction


# ------------ Plot Formatting ------------
colors      = palette(:viridis, 7)
lstyles     = [:solid, :dotted]





# ------------------------------------------------
# ----------- Slider Range Formatting ------------
# ------------------------------------------------
nsliders = 21       # Index with "s in range(1,nsliders):" so s corresponds with C#
posC    = fill(nothing, nsliders)
C_amp   = fill(nothing, nsliders)
C_0     = fill(nothing, nsliders)
posC    = fill(nothing, nsliders)
ax_C    = fill(nothing, nsliders)
Slider_C= fill(nothing, nsliders)


# +/- range on sliders
C_amp[1]    = 300.0
C_amp[2]    = 300.0
C_amp[3]    = 100.0
C_amp[4]    = 300.1
C_amp[5]    = 0.5
C_amp[6]    = 300.0

C_amp[7]    = 0.0001
C_amp[8]    = 300.0
C_amp[9]    = 600.0
C_amp[10]   = 10.0
C_amp[11]   = 3.0
C_amp[12]   = 300.0

C_amp[13]   = 1.0
C_amp[14]   = 300.0
C_amp[15]   = 600.0
C_amp[16]   = 10.0
C_amp[17]   = 3.0
C_amp[18]   = 300.0

C_amp[19]   = 10.0
C_amp[20]   = 300.0


# ------------------------------------------------
# ------------ GUI Layout Positioning ------------
# ------------------------------------------------

# Plot and Positions:
plot_bot    = 0.2
plot_left   = 0.5
plot_top    = 0.95
plot_right  = 0.95

Left_1 = 0.02
Left_2 = 0.16
Left_3 = 0.36
# Yield Parameter Positions:
pos_Vx      = Left_1
pos_Vy      = 0.91
posC[1]     = [Left_2, 0.92, Left_3-Left_2, 0.03]
posC[2]     = [Left_2, 0.89, Left_3-Left_2, 0.03]

pos_Yx      = Left_1
pos_Yy      = 0.82
posC[3]     = [Left_2, 0.83, Left_3-Left_2, 0.03]
posC[4]     = [Left_2, 0.80, Left_3-Left_2, 0.03]

pos_fx      = Left_1
pos_fy      = 0.73
posC[5]     = [Left_2, 0.74, Left_3-Left_2, 0.03]
posC[6]     = [Left_2, 0.71, Left_3-Left_2, 0.03]

# Kinematic Parameter Positons:
pos_rdx     = Left_1
pos_rdy     = 0.64
posC[7]     = [Left_2, 0.65, Left_3-Left_2, 0.03]
posC[8]     = [Left_2, 0.62, Left_3-Left_2, 0.03]

pos_hx      = Left_1
pos_hy      = 0.55
posC[9]     = [Left_2, 0.56, Left_3-Left_2, 0.03]
posC[10]    = [Left_2, 0.53, Left_3-Left_2, 0.03]

pos_rsx     = Left_1
pos_rsy     = 0.46
posC[11]    = [Left_2, 0.47, Left_3-Left_2, 0.03]
posC[12]    = [Left_2, 0.44, Left_3-Left_2, 0.03]

# Isotropic Hardening Positons:
pos_Rdx     = Left_1
pos_Rdy     = 0.37
posC[13]    = [Left_2, 0.38, Left_3-Left_2, 0.03]
posC[14]    = [Left_2, 0.35, Left_3-Left_2, 0.03]

pos_Hx      = Left_1
pos_Hy      = 0.28
posC[15]    = [Left_2, 0.29, Left_3-Left_2, 0.03]
posC[16]    = [Left_2, 0.26, Left_3-Left_2, 0.03]

pos_Rsx     = Left_1
pos_Rsy     = 0.19
posC[17]    = [Left_2, 0.20, Left_3-Left_2, 0.03]
posC[18]    = [Left_2, 0.17, Left_3-Left_2, 0.03]

# yield adjust parameters
pos_Yadjx   = Left_1
pos_Yadjy   = 0.10
posC[19]    = [Left_2, 0.11, Left_3-Left_2, 0.03]
posC[20]    = [Left_2, 0.08, Left_3-Left_2, 0.03]

posreset    = [0.50, 0.03, 0.1, 0.08]
possave     = [0.65, 0.03, 0.1, 0.08]
posexport   = [0.80, 0.03, 0.1, 0.08]


# ------------------------------------------------
# ------------------------------------------------
# ------------------------------------------------
# ------------------------------------------------

# ------------------------------------------------
# Read in Props and Data files from .csv files
# ------------------------------------------------
propsfile::String = ""
flz::Vector{String} = []
if Ask_Files == true
    # Tk().withdraw()
    # propsfile = askopenfilename(title="Select the props file for this material")
    # println("Props file read in  : ", propsfile)
    # filez = askopenfilenames(title="Select all experimental data nsets")
    # flz = list(filez)
    # println("Data file(s) read in: ", flz)
    propsfile_chooser = FileChooser(FILE_CHOOSER_ACTION_OPEN_FILE,
        "Select the props file for this material")
    filter = FileFilter("*.csv")
    add_allowed_suffix!(filter, "csv")
    add_filter!(propsfile_chooser, filter)
    on_accept!(propsfile_chooser) do self::FileChooser, files::Vector{FileDescriptor}
        println("User chose files at $files")
        propsfile = files
    end
    on_cancel!(propsfile_chooser) do self::FileChooser
        println("User canceled the dialog")
    end
    present!(propsfile_chooser)
    datafile_chooser = FileChooser(FILE_CHOOSER_ACTION_OPEN_MULTIPLE_FILES,
        "Select all experimental datasets")
    filter = FileFilter("*.csv")
    add_allowed_suffix!(filter, "csv")
    add_filter!(datafile_chooser, filter)
    on_accept!(datafile_chooser) do self::FileChooser, files::Vector{FileDescriptor}
        println("User chose files at $files")
        flz .= files
    end
    on_cancel!(datafile_chooser) do self::FileChooser
        println("User canceled the dialog")
    end
    present!(datafile_chooser)
end
# ------------------------------------------------
# Assign props values:
df = CSV.read(propsfile, Dict; header=true, delim=',', types=String)
rowsofconstants = findall(occursin.(r"C\d{2}", df["Comment"].keys))
C_0[range(rowsofconstants)] .= [parse(Float64, val) for (key, val) in df["Comment"][rowsofconstants]]
bulk_mod = df["Comment"]["Bulk Mod"]
shear_mod = df["Comment"]["Shear Mod"]

# assign params:
params = {
    "C01"       => C_0[1],
    "C02"       => C_0[2],
    "C03"       => C_0[3],
    "C04"       => C_0[4],
    "C05"       => C_0[5],
    "C06"       => C_0[6],
    "C07"       => C_0[7],
    "C08"       => C_0[8],
    "C09"       => C_0[9],
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
}
# ------------------------------------------------
# store stress-strain data and corresponding test conditions (temp and strain rate)
nsets = length(flz)
# test_cond   = []         # Used to store testing conditions (temp, strain rate)
# test_data   = []         # Used to store data
test_cond   = {
    "StrainRate"    => [],
    "Temp"          => [],
    "Name"          => []
}
test_data   = {
    "Data_E"        => [],
    "Data_S"        => [],
    "Model_E"       => [],
    "Model_S"       => [],
    "Model_VM"      => [],
    "Model_alph"    => [],
    "Model_kap"     => [],
    "Model_tot"     => []
}

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]

for (i, file) in enumerate(flz)
    df = CSV.read(file, DataFrame; header=true, delim=',', types=Float64)

    # add stress/strain data:
    strn = df[!, "Strain"]
    strs = df[!, "Stress"] .* Scale_MPa
    er   = df[!, "Strain Rate"]
    T    = df[!, "Temperature"]
    name = df[!, "Name"]
    # check data entered
    if length(strn) != length(strs)
        println("ERROR! Data from  '", file , "'  has bad stress-strain data lengths")
    end

    #store the stress-strain data
    push!(test_cond["StrainRate"],  first(er))
    push!(test_cond["Temp"],        first(T))
    push!(test_cond["Name"],        firat(name))
    push!(test_data["Data_E"],      strn)
    push!(test_data["Data_S"],      strs)
end



# -----------------------------------------------




# -----------------------------------------------------
# Calculate the model's initial stress-strain curve 
# -----------------------------------------------------

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
# For each set, calculate the model curve and error
@sync @distributed for i in range(nsets)
    emax = max(test_data["Data_E"][i])
    # println('Setup: emax for set ',i,' = ', emax)
    bcj_ref = BCJ.BCJ_metal(test_cond["Temp"][i], test_cond["StrainRate"][i], emax, istate, params)
    bcj_current = BCJ.BCJ_metal_currentconfiguration_init(bcj_ref)
    BCJ.solve!(bcj_current)
    ϵₙ = bcj_current.ϵₜₒₜₐₗ
    Sₙ = bcj_current.S
    α = bcj_current.α
    κ = bcj_current.κ
    Tot = bcj_current.Tot

    # pull only the relevant (tension/torsion) strain being evaluated:
    E      .= ϵₙ[kS, :]
    S      .= Sₙ[kS, :]
    SVM    .= sum([Sₙ[1, :] - Sₙ[2, :], Sₙ[2, :] - Sₙ[3, :], Sₙ[3, :] - Sₙ[1, :]] .^ 2.) + (
        6sum(Sₙ[4:6, :] .^ 2.))
    SVM    .= sqrt.(SVM .* 0.5)
    Al     .= α[kS, :]
    # test_data[i][1] = [E,S,Al,kap,tot,SVM]             #Store model stress/strain data
    push!(test_data["Model_E"],     E)
    push!(test_data["Model_S"],     S)
    push!(test_data["Model_alph"],  Al)
    push!(test_data["Model_kap"],   κ)
    push!(test_data["Model_tot"],   Tot)
    push!(test_data["Model_VM"],    SVM)
end
# println(test_data['Model_E'])
# println(test_data['Model_S'])




# -----------------------------------------------------

# create the axes and the lines that we will manipulate

# fig, ax = plt.subplots()
f = Figure(figure_padding=(plot_left, plot_right, plot_bot, plot_top))

# ------------------------------------------------
# Add textboxes for clarity
textbox_V   = Label(f[ 1,  1], L"V = C_{ 1} \mathrm{exp}(-C_{ 2} / \theta)")
textbox_Y   = Label(f[ 2,  1], L"Y = C_{ 3} \mathrm{exp}( C_{ 4} / \theta)")
textbox_f   = Label(f[ 3,  1], L"f = C_{ 5} \mathrm{exp}(-C_{ 6} / \theta)")
textbox_rd  = Label(f[ 4,  1], L"r_{d} = C_{ 7} \mathrm{exp}(-C_{ 8} / \theta)")
textbox_h   = Label(f[ 5,  1], L"h = C_{ 9} - C_{10}\theta")
textbox_rs  = Label(f[ 6,  1], L"r_{s} = C_{11} \mathrm{exp}(-C_{12} / \theta)")
textbox_Rd  = Label(f[ 7,  1], L"R_{d} = C_{13} \mathrm{exp}(-C_{14} / \theta)")
textbox_H   = Label(f[ 8,  1], L"H = C_{15} - C_{16}\theta")
textbox_Rs  = Label(f[ 9,  1], L"R_{s} = C_{17} \mathrm{exp}(-C_{18} / \theta)")
textbox_Yadj= Label(f[10,  1], L"Y_{adj}")

# ------------------------------------------------
# make a slider for each variable
sg_C01      = SliderGrid(f[ 1,  2][ 1,  1], (label=L"C_{ 1}", range=0.:10.:5C_0[ 1], format="{:.3e}", startvalue=C_0[ 1]))
sg_C02      = SliderGrid(f[ 1,  2][ 2,  1], (label=L"C_{ 2}", range=0.:10.:5C_0[ 2], format="{:.3e}", startvalue=C_0[ 2]))

sg_C03      = SliderGrid(f[ 2,  2][ 1,  1], (label=L"C_{ 3}", range=0.:10.:5C_0[ 3], format="{:.3e}", startvalue=C_0[ 3]))
sg_C04      = SliderGrid(f[ 2,  2][ 2,  1], (label=L"C_{ 4}", range=0.:10.:5C_0[ 4], format="{:.3e}", startvalue=C_0[ 4]))

sg_C05      = SliderGrid(f[ 3,  2][ 1,  1], (label=L"C_{ 5}", range=0.:10.:5C_0[ 5], format="{:.3e}", startvalue=C_0[ 5]))
sg_C06      = SliderGrid(f[ 3,  2][ 2,  1], (label=L"C_{ 6}", range=0.:10.:5C_0[ 6], format="{:.3e}", startvalue=C_0[ 6]))

sg_C07      = SliderGrid(f[ 4,  2][ 1,  1], (label=L"C_{ 7}", range=0.:10.:5C_0[ 7], format="{:.3e}", startvalue=C_0[ 7]))
sg_C08      = SliderGrid(f[ 4,  2][ 2,  1], (label=L"C_{ 8}", range=0.:10.:5C_0[ 8], format="{:.3e}", startvalue=C_0[ 8]))

sg_C09      = SliderGrid(f[ 5,  2][ 1,  1], (label=L"C_{ 9}", range=0.:10.:5C_0[ 9], format="{:.3e}", startvalue=C_0[ 9]))
sg_C10      = SliderGrid(f[ 5,  2][ 2,  1], (label=L"C_{10}", range=0.:10.:5C_0[10], format="{:.3e}", startvalue=C_0[10]))

sg_C11      = SliderGrid(f[ 6,  2][ 1,  1], (label=L"C_{11}", range=0.:10.:5C_0[11], format="{:.3e}", startvalue=C_0[11]))
sg_C12      = SliderGrid(f[ 6,  2][ 2,  1], (label=L"C_{12}", range=0.:10.:5C_0[12], format="{:.3e}", startvalue=C_0[12]))

sg_C13      = SliderGrid(f[ 7,  2][ 1,  1], (label=L"C_{13}", range=0.:10.:5C_0[13], format="{:.3e}", startvalue=C_0[13]))
sg_C14      = SliderGrid(f[ 7,  2][ 2,  1], (label=L"C_{14}", range=0.:10.:5C_0[14], format="{:.3e}", startvalue=C_0[14]))

sg_C15      = SliderGrid(f[ 8,  2][ 1,  1], (label=L"C_{15}", range=0.:10.:5C_0[15], format="{:.3e}", startvalue=C_0[15]))
sg_C16      = SliderGrid(f[ 8,  2][ 2,  1], (label=L"C_{16}", range=0.:10.:5C_0[16], format="{:.3e}", startvalue=C_0[16]))

sg_C17      = SliderGrid(f[ 9,  2][ 1,  1], (label=L"C_{17}", range=0.:10.:5C_0[17], format="{:.3e}", startvalue=C_0[17]))
sg_C18      = SliderGrid(f[ 9,  2][ 2,  1], (label=L"C_{18}", range=0.:10.:5C_0[18], format="{:.3e}", startvalue=C_0[18]))

sg_C19      = SliderGrid(f[10,  2][ 1,  1], (label=L"C_{19}", range=0.:10.:5C_0[19], format="{:.3e}", startvalue=C_0[19]))
sg_C20      = SliderGrid(f[10,  2][ 2,  1], (label=L"C_{20}", range=0.:10.:5C_0[20], format="{:.3e}", startvalue=C_0[20]))

sg_constants = [
    sg_C01, sg_C02, sg_C03, sg_C04, sg_C05,
    sg_C06, sg_C07, sg_C08, sg_C09, sg_C10,
    sg_C11, sg_C12, sg_C13, sg_C14, sg_C15,
    sg_C16, sg_C17, sg_C18, sg_C19, sg_C20
]
sg_observables = [sgc.value for sgc in sg_constants.sliders]
sg_constants_values = lift(sg_observables...) do sgcvalues...
    [sgcvalues...]
end

# lines[1] = data
# lines[2] = model (to be updated)
# lines[3] = alpha model (to be updated)
# lines[4] = kappa model (to be updated)
dataseries = if Plot_ISVs
    [[],[],[],[],[],[]]
else
    [[],[]]
end

ax = Axis(f[ 1,  3],
    xlim=(0., Inf),
    xlabel="True Strain (mm/mm)",
    ylim=(0., max_stress),
    ylabel="True Stress (Pa)")

for i in range(nsets)
    # println(test_data[i][1][0])
    # println(test_data[i][1][5])

    push!(dataseries[1], (x=test_data["Data_E"][i], y=test_data["Data_S"][i]))
    push!(dataseries[2], (x=test_data["Model_E"][i], y=test_data["Model_VM"][i]))

    if Plot_ISVs
        push!(dataseries[3], (x=test_data["Data_E"][i], y=test_data["MOdel_alph"][i]))
        push!(dataseries[4], (x=test_data["Model_E"][i], y=test_data["Model_kap"][i]))
        # push!(dataseries[5], (x=test_data["Data_E"][i], y=test_data["Model_tot"][i]))
        # push!(dataseries[6], (x=test_data["Model_E"][i], y=test_data["Model_S"][i]))
    end
end

dataseries_observables = Observable(dataseries)

for (i, ds) in zip(range(nsets), dataseries_observables)
    # println(test_data[i][1][0])
    # println(test_data[i][1][5])

    scatter(ax, ds[:x], ds[:y], "o", color=colors[i])  #, label="Data - " * test_cond[i][2])
    lines(ax, ds[:x], ds[:y], ls=lstyles[i], color=colors[i], label="VM Model - " * test_cond["Name"][i])
    if Plot_ISVs
        scatter(ax, ds[:x], ds[:y], "--", color=colors[i], label="\$\\alpha\$ - " * test_cond["Name"][i])
        lines(ax, ds[:x], ds[:y], "-.", color=colors[i], label="\$\\kappa\$ - " * test_cond["Name"][i])
        # scatter(ax, ds[:x], ds[:y], ':', color = colors[i] , label=r'$total$ - '+test_cond['Name'][i]))
        # lines(ax, ds[:x], ds[:y], color = colors[i+1] , label=r'$S_{11}$ - '+test_cond['Name'][i]))
    end
end

axislegend(ax, position=:lt)

f[ 2,  3] = buttons_grid = GridLayout(tellwidth=false)
buttons_labels = ["Reset", "Save Props", "Export Curves"]
buttons = buttons_grid[1, :] = [Button(f, label=bl) for bl in buttons_labels]
buttons_resetbutton     = buttons[1]
buttons_savebutton      = buttons[2]
buttons_exportbutton    = buttons[3]


# ------------------------------------------------

# The function to be called anytime a slider's value changes
for (i, sgcv) in enumerate(sg_constants_values)
    on(sgcv) do n
        update(i, to_value(sgcv))
    end
end

function update(i, val)
    # redefine params with new slider values
    key = i <= 9 ? "C0$i" : "C$i"
    params[key] = val

    @sync @distributed for i in range(nsets)
        emax = max(test_data["Data_E"][i])
        # println('Setup: emax for set ',i,' = ', emax)
        bcj_ref = BCJ.BCJ_metal(test_cond["Temp"][i], test_cond["StrainRate"][i], emax, istate, params)
        bcj_current = BCJ.BCJ_metal_currentconfiguration_init(bcj_ref)
        BCJ.solve!(bcj_current)
        ϵₙ = bcj_current.ϵₜₒₜₐₗ
        Sₙ = bcj_current.S
        α = bcj_current.α
        κ = bcj_current.κ
        Tot = bcj_current.Tot

        # pull only the relevant (tension/torsion) strain being evaluated:
        E      .= ϵₙ[kS, :]
        S      .= Sₙ[kS, :]
        SVM    .= sum([Sₙ[1, :] - Sₙ[2, :], Sₙ[2, :] - Sₙ[3, :], Sₙ[3, :] - Sₙ[1, :]] .^ 2.) + (
            6sum(Sₙ[4:6, :] .^ 2.))
        SVM    .= sqrt.(SVM .* 0.5)
        Al     .= α[kS, :]

        dataseries[][1][i] .= (SVM)
        if Plot_ISVs
            dataseries[][2][i] .= (Al)
            dataseries[][3][i] .= (kap)
            # dataseries[][4][i] .= (tot)
            # dataseries[][5][i] .= (S)
        end
        notify(dataseries)
    end
end


# ------------------------------------------------
# Add buttons
# ------------------------------------------------

# for i in range(length(buttons))
#     on(buttons[i].clicks) do n
#         counts[][i] += 1
#         notify(counts)
#     end
# end
on(buttons_resetbutton.clicks) do click
    for (sg, c) in zip(sg_constants, C_0)
        set_close_to!(sg, c)
    end
end

on(buttons_savebutton.clicks) do click
    props_dir, props_name = dirname(propsfile), basename(propsfile)
    propsfile_new = save_file(props_dir, filterlist=".csv")
    df = DataFrame(
        (
            "Constants" => [[i <= 9 ? "C0$i" : "C$i" for i in range(C_0)]..., "Bulk Mod", "Shear Mod"],
            "Values"    => [[sgc.value for sgc in sg_constants]..., bulk_mod, shear_mod]
        )
    )
    CSV.write(propsfile_new, df)
    println("New props file written to: \"", propsfile_new, "\"")
end

on(buttons_exportbutton.clicks) do click
    props_dir, props_name = dirname(propsfile), basename(propsfile)
    curvefile_new = save_file(props_dir, filterlist=".csv")
    header, df = [], DataFrame()
    for (i, test_name, test_strain, test_stress) in zip(range(nsets), test_cond["Name"], test_data["Model_E"], test_data["Model_VM"])
        push!(header, "strain-" * test_name)
        push!(header, "VMstress" * test_name)
        DataFrames.hcat!(df, test_strain, test_stress)
    end
    CSV.write(curvefile_new, df, header=header)
    println("Model curves written to: \"", curvefile_new, "\"")
end


display(f)