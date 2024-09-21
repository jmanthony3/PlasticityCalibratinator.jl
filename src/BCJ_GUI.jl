using CSV
using DataFrames
using Distributed
using GLMakie
using LaTeXStrings
using NativeFileDialog

import BammannChiesaJohnsons as BCJ



# ------------------------------------------------
# ---------- User Modifiable Variables -----------
# ------------------------------------------------
incnum      = 200
istate      = 1      #1 = tension, 2 = torsion
Ask_Files   = true
Material    = "4340"
Plot_ISVs   = false


Scale_MPa   = 1000000           # Unit conversion from MPa to Pa from data
max_stress  = 3000 * 1000000

if Material == "4340"
    max_stress  = 2000 * 1000000
end



# ------------------------------------------------
# ------------------------------------------------
kS          = 1     # default tension component
if istate == 2
    kS      = 4     # select torsion component
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
# colors      = :viridis
# lstyles     = [:solid, :dotted]





# ------------------------------------------------
# ----------- Slider Range Formatting ------------
# ------------------------------------------------
nsliders = 21       # Index with "s in range(1,nsliders):" so s corresponds with C#
C_amp   = Vector{Float64}(undef, nsliders)
C_0     = Vector{Float64}(undef, nsliders)
Slider_C= Vector{Float64}(undef, nsliders)


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


# ------------------------------------------------
# ------------------------------------------------
# ------------------------------------------------
# ------------------------------------------------


# ------------------------------------------------
# Read in Props and Data files from .csv files
# ------------------------------------------------
propsfile::String = ""
flz::Vector{String} = []
# if Ask_Files == true
#     # Tk().withdraw()
#     # propsfile = askopenfilename(title="Select the props file for this material")
#     # println("Props file read in  : ", propsfile)
#     # filez = askopenfilenames(title="Select all experimental data nsets")
#     # flz = list(filez)
#     # println("Data file(s) read in: ", flz)

#     # props_dir, props_name = dirname(propsfile), basename(propsfile)
#     # curvefile_new = save_file(props_dir, filterlist=".csv")
#     # header, df = [], DataFrame()
#     # for (i, test_name, test_strain, test_stress) in zip(range(1, nsets), test_cond["Name"], test_data["Model_E"], test_data["Model_VM"])
#     #     push!(header, "strain-" * test_name)
#     #     push!(header, "VMstress" * test_name)
#     #     DataFrames.hcat!(df, test_strain, test_stress)
#     # end
#     # CSV.write(curvefile_new, df, header=header)
#     # println("Model curves written to: \"", curvefile_new, "\"")
#     propsfile = pick_file(pwd(); filterlist="csv")
#     flz = pick_multi_file(pwd(); filterlist="csv")
# end
propsfile = "path/to.csv"
flz = [
    "path/to1.csv",
    "path/to2.csv"
]
# ------------------------------------------------
# Assign props values:
df = CSV.read(propsfile, DataFrame; header=true, delim=',', types=[String, Float64])
rowsofconstants = findall(occursin.(r"C\d{2}", df[!, "Comment"]))
C_0[rowsofconstants] .= df[!, "For Calibration with vumat"][rowsofconstants]
bulk_mod = df[!, "For Calibration with vumat"][findfirst(occursin("Bulk Mod"), df[!, "Comment"])]
shear_mod = df[!, "For Calibration with vumat"][findfirst(occursin("Shear Mod"), df[!, "Comment"])]

# assign params:
params = Observable(Dict(
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
nsets = length(flz)
# test_cond   = []         # Used to store testing conditions (temp, strain rate)
# test_data   = []         # Used to store data
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

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]

for (i, file) in enumerate(flz)
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
    push!(test_cond["StrainRate"],  first(er))
    push!(test_cond["Temp"],        first(T))
    push!(test_cond["Name"],        first(name))
    push!(test_data["Data_E"],      strn)
    push!(test_data["Data_S"],      strs)
end



# -----------------------------------------------




# -----------------------------------------------------
# Calculate the model's initial stress-strain curve 
# -----------------------------------------------------

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
# For each set, calculate the model curve and error
@sync @distributed for i in range(1, nsets)
# for i in range(1, nsets)
    emax = maximum(test_data["Data_E"][i])
    # println('Setup: emax for set ',i,' = ', emax)
    bcj_ref = BCJ.BCJ_metal(
        test_cond["Temp"][i], test_cond["StrainRate"][i],
        emax, incnum, istate, params[])
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
    SVM    .= sum(map.(x->x^2., [Sₙ[1, :] - Sₙ[2, :], Sₙ[2, :] - Sₙ[3, :], Sₙ[3, :] - Sₙ[1, :]])) + (
        6sum(map.(x->x^2., [Sₙ[4, :], Sₙ[5, :], Sₙ[6, :]])))
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
f = Figure(layout=GridLayout(1, 2), figure_padding=(plot_left, plot_right, plot_bot, plot_top))
# w = @lift widths($(f.scene.px_area))[1]
grid_sliders    = GridLayout(f[ 1,  1])
grid_plot       = GridLayout(f[ 1,  2])
# colsize!(f.layout, 1, Relative(0.5))
# colsize!(f.layout, 2, Relative(0.5))

# ------------------------------------------------
# add textboxes for clarity
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

# ------------------------------------------------
# make a slider for each variable
sg_C01      = SliderGrid(grid_sliders[ 1,  2][ 1,  1], (label=L"C_{ 1}", range=0.:10.:5C_0[ 1], format="{:.3e}", startvalue=C_0[ 1])) # , width=0.4w[]))
sg_C02      = SliderGrid(grid_sliders[ 1,  2][ 2,  1], (label=L"C_{ 2}", range=0.:10.:5C_0[ 2], format="{:.3e}", startvalue=C_0[ 2])) # , width=0.4w[]))

sg_C03      = SliderGrid(grid_sliders[ 2,  2][ 1,  1], (label=L"C_{ 3}", range=0.:10.:5C_0[ 3], format="{:.3e}", startvalue=C_0[ 3])) # , width=0.4w[]))
sg_C04      = SliderGrid(grid_sliders[ 2,  2][ 2,  1], (label=L"C_{ 4}", range=0.:10.:5C_0[ 4], format="{:.3e}", startvalue=C_0[ 4])) # , width=0.4w[]))

sg_C05      = SliderGrid(grid_sliders[ 3,  2][ 1,  1], (label=L"C_{ 5}", range=0.:10.:5C_0[ 5], format="{:.3e}", startvalue=C_0[ 5])) # , width=0.4w[]))
sg_C06      = SliderGrid(grid_sliders[ 3,  2][ 2,  1], (label=L"C_{ 6}", range=0.:10.:5C_0[ 6], format="{:.3e}", startvalue=C_0[ 6])) # , width=0.4w[]))

sg_C07      = SliderGrid(grid_sliders[ 4,  2][ 1,  1], (label=L"C_{ 7}", range=0.:10.:5C_0[ 7], format="{:.3e}", startvalue=C_0[ 7])) # , width=0.4w[]))
sg_C08      = SliderGrid(grid_sliders[ 4,  2][ 2,  1], (label=L"C_{ 8}", range=0.:10.:5C_0[ 8], format="{:.3e}", startvalue=C_0[ 8])) # , width=0.4w[]))

sg_C09      = SliderGrid(grid_sliders[ 5,  2][ 1,  1], (label=L"C_{ 9}", range=0.:10.:5C_0[ 9], format="{:.3e}", startvalue=C_0[ 9])) # , width=0.4w[]))
sg_C10      = SliderGrid(grid_sliders[ 5,  2][ 2,  1], (label=L"C_{10}", range=0.:10.:5C_0[10], format="{:.3e}", startvalue=C_0[10])) # , width=0.4w[]))

sg_C11      = SliderGrid(grid_sliders[ 6,  2][ 1,  1], (label=L"C_{11}", range=0.:10.:5C_0[11], format="{:.3e}", startvalue=C_0[11])) # , width=0.4w[]))
sg_C12      = SliderGrid(grid_sliders[ 6,  2][ 2,  1], (label=L"C_{12}", range=0.:10.:5C_0[12], format="{:.3e}", startvalue=C_0[12])) # , width=0.4w[]))

sg_C13      = SliderGrid(grid_sliders[ 7,  2][ 1,  1], (label=L"C_{13}", range=0.:10.:5C_0[13], format="{:.3e}", startvalue=C_0[13])) # , width=0.4w[]))
sg_C14      = SliderGrid(grid_sliders[ 7,  2][ 2,  1], (label=L"C_{14}", range=0.:10.:5C_0[14], format="{:.3e}", startvalue=C_0[14])) # , width=0.4w[]))

sg_C15      = SliderGrid(grid_sliders[ 8,  2][ 1,  1], (label=L"C_{15}", range=0.:10.:5C_0[15], format="{:.3e}", startvalue=C_0[15])) # , width=0.4w[]))
sg_C16      = SliderGrid(grid_sliders[ 8,  2][ 2,  1], (label=L"C_{16}", range=0.:10.:5C_0[16], format="{:.3e}", startvalue=C_0[16])) # , width=0.4w[]))

sg_C17      = SliderGrid(grid_sliders[ 9,  2][ 1,  1], (label=L"C_{17}", range=0.:10.:5C_0[17], format="{:.3e}", startvalue=C_0[17])) # , width=0.4w[]))
sg_C18      = SliderGrid(grid_sliders[ 9,  2][ 2,  1], (label=L"C_{18}", range=0.:10.:5C_0[18], format="{:.3e}", startvalue=C_0[18])) # , width=0.4w[]))

sg_C19      = SliderGrid(grid_sliders[10,  2][ 1,  1], (label=L"C_{19}", range=0.:10.:5C_0[19], format="{:.3e}", startvalue=C_0[19])) # , width=0.4w[]))
sg_C20      = SliderGrid(grid_sliders[10,  2][ 2,  1], (label=L"C_{20}", range=0.:10.:5C_0[20], format="{:.3e}", startvalue=C_0[20])) # , width=0.4w[]))

sg_constants = [
    sg_C01, sg_C02, sg_C03, sg_C04, sg_C05,
    sg_C06, sg_C07, sg_C08, sg_C09, sg_C10,
    sg_C11, sg_C12, sg_C13, sg_C14, sg_C15,
    sg_C16, sg_C17, sg_C18, sg_C19, sg_C20
]
sg_observables = [sgcs.value for sgcs in [only(sgc.sliders) for sgc in sg_constants]]

# lines[1] = data
# lines[2] = model (to be updated)
# lines[3] = alpha model (to be updated)
# lines[4] = kappa model (to be updated)
dataseries = if Plot_ISVs
    [[],[],[],[],[],[]]
else
    [[],[]]
end

ax = Axis(grid_plot[ 1: 9,  1],
    xlabel="True Strain (mm/mm)",
    ylabel="True Stress (Pa)") # ,
    # width=0.5w[])
xlims!(ax, (0., nothing))
ylims!(ax, (0., max_stress))

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

for (i, ds) in zip(range(1, nsets), dataseries)
    # println(test_data[i][1][0])
    # println(test_data[i][1][5])

    scatter!(ax,    @lift(Point2f.($(ds[1]).x, $(ds[1]).y)), color=[i], colormap=:viridis, colorrange=(1, nsets), label="Data - " * test_cond["Name"][i])
    lines!(ax,      @lift(Point2f.($(ds[2]).x, $(ds[2]).y)), color=[i], colormap=:viridis, colorrange=(1, nsets), label="VM Model - " * test_cond["Name"][i])
    if Plot_ISVs
        scatter!(ax,    @lift(Point2f.($(ds[3]).x, $(ds[3]).y)), color=i, colormap=:viridis, colorrange=(1, nsets), label="\$\\alpha\$ - " * test_cond["Name"][i])
        lines!(ax,      @lift(Point2f.($(ds[4]).x, $(ds[4]).y)), color=i, colormap=:viridis, colorrange=(1, nsets), label="\$\\kappa\$ - " * test_cond["Name"][i])
        # scatter(ax,     @lift(Point2f.($(ds[5]).x, $(ds[5]).y)), color = i, colormap=:viridis , label="\$total\$ - " * test_cond["Name"][i]))
        # lines(ax,       @lift(Point2f.($(ds[6]).x, $(ds[6]).y)), color = i, colormap=:viridis , label="\$S_{11}\$ - " * test_cond["Name"][i]))
    end
end

axislegend(ax, position=:lt)

buttons_grid = GridLayout(grid_plot[10,  1], 1, 3)
buttons_labels = ["Reset", "Save Props", "Export Curves"]
buttons = buttons_grid[1, :] = [Button(f, label=bl) for bl in buttons_labels]
buttons_resetbutton     = buttons[1]
buttons_savebutton      = buttons[2]
buttons_exportbutton    = buttons[3]


# ------------------------------------------------

# The function to be called anytime a slider's value changes
for (i, sgo) in enumerate(sg_observables)
    on(sgo) do n
        # redefine params with new slider values
        key = i <= 9 ? "C0$i" : "C$i"
        params[][key] = to_value(sgo)
        notify(params)
        update(params)
    end
end

function update(params)
    # @sync @distributed for i in range(1, nsets)
    for i in range(1, nsets)
        emax = maximum(test_data["Data_E"][i])
        # println('Setup: emax for set ',i,' = ', emax)
        bcj_ref = BCJ.BCJ_metal(
            test_cond["Temp"][i], test_cond["StrainRate"][i],
            emax, incnum, istate, params[])
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
        SVM    .= sum(map.(x->x^2., [Sₙ[1, :] - Sₙ[2, :], Sₙ[2, :] - Sₙ[3, :], Sₙ[3, :] - Sₙ[1, :]])) + (
            6sum(map.(x->x^2., [Sₙ[4, :], Sₙ[5, :], Sₙ[6, :]])))
        SVM    .= sqrt.(SVM .* 0.5)
        Al     .= α[kS, :]

        dataseries[2][i][].y .= SVM
        if Plot_ISVs
            dataseries[3][i][].y .= Al
            dataseries[4][i][].y .= kap
            # dataseries[5][i][].y .= tot
            # dataseries[6][i][].y .= S
        end
        for ds in dataseries[2:end]
            notify(ds[i])
        end
    end
    return nothing
end


# ------------------------------------------------
# Add buttons
# ------------------------------------------------

# for i in range(1, length(buttons))
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
            "Constants" => [[i <= 9 ? "C0$i" : "C$i" for i in range(1, C_0)]..., "Bulk Mod", "Shear Mod"],
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
    for (i, test_name, test_strain, test_stress) in zip(range(1, nsets), test_cond["Name"], test_data["Model_E"], test_data["Model_VM"])
        push!(header, "strain-" * test_name)
        push!(header, "VMstress" * test_name)
        DataFrames.hcat!(df, test_strain, test_stress)
    end
    CSV.write(curvefile_new, df, header=header)
    println("Model curves written to: \"", curvefile_new, "\"")
end


display(f)