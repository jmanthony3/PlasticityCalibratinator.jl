# gui.jl
using CSV
using DataFrames
using Distributed
using GLMakie
using LaTeXStrings
# using LsqFit
using NativeFileDialog
# using NLsolve
using Optim

import BammannChiesaJohnsonPlasticity as BCJ
import BCJCalibratinator as BCJinator


set_theme!(theme_latexfonts())



# default values
incnum      = Observable(200)
istate      = Observable(1)      #1 = tension, 2 = torsion
Ask_Files   = true
Material    = "4340"
BCJMetal    = Observable(BCJ.DK)
# Plot_ISVs   = Observable([BCJ.KinematicHardening{BCJMetal[]}, BCJ.IsotropicHardening{BCJMetal[]}])
Plot_ISVs   = Observable([:alpha, :kappa])
MPa         = 1e6           # Unit conversion from MPa to Pa from data
min_stress  = 0.
max_stress  = 3000 * MPa

if Material == "4340"
    max_stress  = 2000 * MPa
end

## sliders
nsliders    = Observable(0)       # Index with "s in range(1,nsliders):" so s corresponds with C#
nequations  = Observable(10)
C_0         = @lift Vector{Float64}(undef, $nsliders)


# material properties
include("filepaths.jl")
propsfile   = Observable(propsfile) # trying to switch over to observable
params      = @lift begin
    df          = CSV.read($propsfile, DataFrame; header=true, delim=',', types=[String, Float64])
    rowsofconstants = findall(occursin.(r"C\d{2}", df[!, "Comment"]))
    nsliders[] = length(rowsofconstants); notify(nsliders)
    C_0[] = Vector{Float64}(undef, nsliders[]); notify(C_0)
    C_0[][rowsofconstants] .= df[!, "For Calibration with vumat"][rowsofconstants]; notify(C_0)
    bulk_mod    = df[!, "For Calibration with vumat"][findfirst(occursin("Bulk Mod"), df[!, "Comment"])]
    shear_mod   = df[!, "For Calibration with vumat"][findfirst(occursin("Shear Mod"), df[!, "Comment"])]
    dict = Dict( # collect as dictionary
        "bulk_mod"  => bulk_mod,
        "shear_mod" => shear_mod)
    for (i, c) in enumerate(C_0[])
        dict[BCJinator.constant_string(i)] = c
    end
    dict
end
# ------------------------------------------------
# store stress-strain data and corresponding test conditions (temp and strain rate)
files       = Observable(files)     # trying to switch over to observable
joinfiles(fs) = join([fs...], "\n")
input_files = lift(joinfiles, files)
bcj         = Observable(BCJinator.bcjmetalcalibration_init(files[], incnum[], istate[], params[], MPa, BCJMetal[]))
# lines[1] = data
# lines[2] = model (to be updated)
# lines[3] = alpha model (to be updated)
# lines[4] = kappa model (to be updated)
dataseries  = Observable(BCJinator.dataseries_init(bcj[].nsets, bcj[].test_data, Plot_ISVs[]))



################################################################
#                   B E G I N   F I G U R E                    #
################################################################



# renew screens
GLMakie.closeall()
screen_main = GLMakie.Screen(; title="BCJ", fullscreen=true, focus_on_show=true)
# screen_sliders = GLMakie.Screen(; title="Sliders", focus_on_show=true)
# screen_isvs = GLMakie.Screen(; title="ISVs") # , focus_on_show=true)
## top-level figure
# figure_padding=(plot_left, plot_right, plot_bot, plot_top)
f = Figure(size=(900, 600), figure_padding=(30, 10, 10, 10), layout=GridLayout(2, 1)) # , tellheight=false, tellwidth=false)
g = Figure(size=(450, 600))
h = Figure(size=(600, 400))
# f = Figure(figure_padding=(0.5, 0.95, 0.2, 0.95), layout=GridLayout(3, 1))
w = @lift widths($(f.scene.viewport))[1]
# w = @lift widths($(f.scene))[1]

### sub-figure for input parameters of calibration study
a = GridLayout(f[ 1,  1], 1, 2)
aa = GridLayout(a[ 1,  1], 4, 3)
#### propsfile
propsfile_label       = Label(aa[ 1,  1], "Path to parameters dictionary:"; halign=:right)
propsfile_textbox   = Textbox(aa[ 1,  2], placeholder="path/to/dict",
    width=w[], stored_string=propsfile, displayed_string=propsfile)
propsfile_button     = Button(aa[ 1,  3], label="Browse")
#### experimental datasets
expdatasets_label     = Label(aa[ 2,  1], "Paths to experimental datasets:"; halign=:right)
expdatasets_textbox = Textbox(aa[ 2,  2], placeholder="path/to/experimental datasets",
    height=5f.scene.theme.fontsize[], width=w[], stored_string=input_files, displayed_string=input_files)
expdatasets_button   = Button(aa[ 2,  3], label="Browse")
#### loading direction toggles
loadingdirection_label= Label(aa[ 3,  1], "Loading directions in experiments:"; halign=:right)
aaa = GridLayout(aa[ 3,  2], 1, 2)
aaaa = GridLayout(aaa[ 1,  1], 1, 2)
loaddir_axial_label   = Label(aaaa[ 1,  1], "Tension/Compression:"; halign=:right)
loaddir_axial_toggle  = Toggle(aaaa[ 1,  2], active=true)
aaab = GridLayout(aaa[ 1,  2], 1, 2)
loaddir_torsion_label = Label(aaab[ 1,  1], "Torsion:"; halign=:right)
loaddir_torsion_toggle= Toggle(aaab[ 1,  2], active=false)
#### number of strain increments
aab = GridLayout(aa[4, :], 1, 2; halign=:left)
aaba = GridLayout(aab[1, 1], 1, 2; halign=:left)
incnum_label          = Label(aaba[ 1,  1], "Number of strain increments for model curves:"; halign=:right)
incnum_textbox      = Textbox(aaba[ 1,  2], placeholder="non-zero integer",
    width=5f.scene.theme.fontsize[], stored_string="200", displayed_string="200", validator=Int64, halign=:left)
aabb = GridLayout(aab[1, 2], 1, 2; halign=:right)
Plot_ISVs_label       = Label(aabb[ 1,  1], "Vector of ISV symbols to plot:"; halign=:right)
Plot_ISVs_textbox   = Textbox(aabb[ 1,  2], placeholder="non-zero integer",
    width=0.5w[], stored_string=":alpha, :kappa", displayed_string=":alpha, :kappa", halign=:left)
#### update calibration study
buttons_updateinputs = Button(a[ 1,  2], label="Update inputs", valign=:bottom)

### sub-figure for model selection, sliders, and plot
b = GridLayout(f[ 2,  1], 1, 2)
ba = GridLayout(b[ 1,  1], 3, 1)
baa = GridLayout(ba[1, 1], 1, 1)
modelselection_title_label  = Label(baa[ 1,  1], "Model Selection")
modelselection_menu         = Menu(baa[ 1,  2], options=zip(["Bammann1990Modeling", "DK"], [BCJ.Bammann1990Modeling, BCJ.DK]), default="DK")
characteristic_equations = Observable([
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
])
bab = @lift GridLayout(ba[2, 1], length($characteristic_equations), 1)
chareqs_labels = Observable([
    Label(bab[][ 1,  1], characteristic_equations[][1]; halign=:left)
    Label(bab[][ 2,  1], characteristic_equations[][2]; halign=:left)
    Label(bab[][ 3,  1], characteristic_equations[][3]; halign=:left)
    Label(bab[][ 4,  1], characteristic_equations[][4]; halign=:left)
    Label(bab[][ 5,  1], characteristic_equations[][5]; halign=:left)])
# grid_sliders    = GridLayout(ba[ 2,  1], 10, 3)
showsliders_button = Button(ba[3, 1], label="Show sliders")
grid_plot       = GridLayout(b[ 1,  2], 10, 9)
# Box(b[1, 1], color=(:red, 0.2), strokewidth=0)
# Box(b[1, 2], color=(:red, 0.2), strokewidth=0)
# # # # colsize!(f.layout, 1, Relative(0.45))
# # # # colsize!(f.layout, 2, Relative(0.45))
# # # colsize!(f.layout, 2, Aspect(1, 1.0))
# # rowsize!(f.layout, 1, Relative(0.3))
# # rowsize!(f.layout, 2, Relative(0.7))
# # rowsize!(b, 1, 3\2w[])
rowsize!(b, 1, Relative(0.8))

#### sliders
# label each slider with equation
dependence_equations = Observable([
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
])
grid_sliders = @lift GridLayout(g[1, 1], length($dependence_equations), 3)
# add toggles for which to calibrate
toggles     = Observable([ # collect toggles
    Toggle(grid_sliders[][ 1,  1], active=false), # V
    Toggle(grid_sliders[][ 2,  1], active=false), # Y
    Toggle(grid_sliders[][ 3,  1], active=false), # f
    Toggle(grid_sliders[][ 4,  1], active=false), # rd
    Toggle(grid_sliders[][ 5,  1], active=false), # h
    Toggle(grid_sliders[][ 6,  1], active=false), # rs
    Toggle(grid_sliders[][ 7,  1], active=false), # Rd
    Toggle(grid_sliders[][ 8,  1], active=false), # H
    Toggle(grid_sliders[][ 9,  1], active=false), # Rs
    Toggle(grid_sliders[][10,  1], active=false), # Yadj
])
depeqs_labels = Observable([
    Label(grid_sliders[][ 1,  2], dependence_equations[][ 1]; halign=:left)
    Label(grid_sliders[][ 2,  2], dependence_equations[][ 2]; halign=:left)
    Label(grid_sliders[][ 3,  2], dependence_equations[][ 3]; halign=:left)
    Label(grid_sliders[][ 4,  2], dependence_equations[][ 4]; halign=:left)
    Label(grid_sliders[][ 5,  2], dependence_equations[][ 5]; halign=:left)
    Label(grid_sliders[][ 6,  2], dependence_equations[][ 6]; halign=:left)
    Label(grid_sliders[][ 7,  2], dependence_equations[][ 7]; halign=:left)
    Label(grid_sliders[][ 8,  2], dependence_equations[][ 8]; halign=:left)
    Label(grid_sliders[][ 9,  2], dependence_equations[][ 9]; halign=:left)
    Label(grid_sliders[][10,  2], dependence_equations[][10]; halign=:left)
])
# make a slider for each constant
# # V
# sg_C01      = SliderGrid(grid_sliders[][ 1,  3][ 1,  1], (label=L"C_{ 1}", range=range(0., 5C_0[][ 1]; length=1_000), format="{:.3e}", startvalue=C_0[][ 1])) # , width=0.4w[]))
# sg_C02      = SliderGrid(grid_sliders[][ 1,  3][ 2,  1], (label=L"C_{ 2}", range=range(0., 5C_0[][ 2]; length=1_000), format="{:.3e}", startvalue=C_0[][ 2])) # , width=0.4w[]))
# # Y
# sg_C03      = SliderGrid(grid_sliders[][ 2,  3][ 1,  1], (label=L"C_{ 3}", range=range(0., 5C_0[][ 3]; length=1_000), format="{:.3e}", startvalue=C_0[][ 3])) # , width=0.4w[]))
# sg_C04      = SliderGrid(grid_sliders[][ 2,  3][ 2,  1], (label=L"C_{ 4}", range=range(0., 5C_0[][ 4]; length=1_000), format="{:.3e}", startvalue=C_0[][ 4])) # , width=0.4w[]))
# # f
# sg_C05      = SliderGrid(grid_sliders[][ 3,  3][ 1,  1], (label=L"C_{ 5}", range=range(0., 5C_0[][ 5]; length=1_000), format="{:.3e}", startvalue=C_0[][ 5])) # , width=0.4w[]))
# sg_C06      = SliderGrid(grid_sliders[][ 3,  3][ 2,  1], (label=L"C_{ 6}", range=range(0., 5C_0[][ 6]; length=1_000), format="{:.3e}", startvalue=C_0[][ 6])) # , width=0.4w[]))
# # rd
# sg_C07      = SliderGrid(grid_sliders[][ 4,  3][ 1,  1], (label=L"C_{ 7}", range=range(0., 5C_0[][ 7]; length=1_000), format="{:.3e}", startvalue=C_0[][ 7])) # , width=0.4w[]))
# sg_C08      = SliderGrid(grid_sliders[][ 4,  3][ 2,  1], (label=L"C_{ 8}", range=range(0., 5C_0[][ 8]; length=1_000), format="{:.3e}", startvalue=C_0[][ 8])) # , width=0.4w[]))
# # h
# sg_C09      = SliderGrid(grid_sliders[][ 5,  3][ 1,  1], (label=L"C_{ 9}", range=range(0., 5C_0[][ 9]; length=1_000), format="{:.3e}", startvalue=C_0[][ 9])) # , width=0.4w[]))
# sg_C10      = SliderGrid(grid_sliders[][ 5,  3][ 2,  1], (label=L"C_{10}", range=range(0., 5C_0[][10]; length=1_000), format="{:.3e}", startvalue=C_0[][10])) # , width=0.4w[]))
# # rs
# sg_C11      = SliderGrid(grid_sliders[][ 6,  3][ 1,  1], (label=L"C_{11}", range=range(0., 5C_0[][11]; length=1_000), format="{:.3e}", startvalue=C_0[][11])) # , width=0.4w[]))
# sg_C12      = SliderGrid(grid_sliders[][ 6,  3][ 2,  1], (label=L"C_{12}", range=range(0., 5C_0[][12]; length=1_000), format="{:.3e}", startvalue=C_0[][12])) # , width=0.4w[]))
# # Rd
# sg_C13      = SliderGrid(grid_sliders[][ 7,  3][ 1,  1], (label=L"C_{13}", range=range(0., 5C_0[][13]; length=1_000), format="{:.3e}", startvalue=C_0[][13])) # , width=0.4w[]))
# sg_C14      = SliderGrid(grid_sliders[][ 7,  3][ 2,  1], (label=L"C_{14}", range=range(0., 5C_0[][14]; length=1_000), format="{:.3e}", startvalue=C_0[][14])) # , width=0.4w[]))
# # H
# sg_C15      = SliderGrid(grid_sliders[][ 8,  3][ 1,  1], (label=L"C_{15}", range=range(0., 5C_0[][15]; length=1_000), format="{:.3e}", startvalue=C_0[][15])) # , width=0.4w[]))
# sg_C16      = SliderGrid(grid_sliders[][ 8,  3][ 2,  1], (label=L"C_{16}", range=range(0., 5C_0[][16]; length=1_000), format="{:.3e}", startvalue=C_0[][16])) # , width=0.4w[]))
# # Rs
# sg_C17      = SliderGrid(grid_sliders[][ 9,  3][ 1,  1], (label=L"C_{17}", range=range(0., 5C_0[][17]; length=1_000), format="{:.3e}", startvalue=C_0[][17])) # , width=0.4w[]))
# sg_C18      = SliderGrid(grid_sliders[][ 9,  3][ 2,  1], (label=L"C_{18}", range=range(0., 5C_0[][18]; length=1_000), format="{:.3e}", startvalue=C_0[][18])) # , width=0.4w[]))
# # Yadj
# sg_C19      = SliderGrid(grid_sliders[][10,  3][ 1,  1], (label=L"C_{19}", range=range(0., 5C_0[][19]; length=1_000), format="{:.3e}", startvalue=C_0[][19])) # , width=0.4w[]))
# sg_C20      = SliderGrid(grid_sliders[][10,  3][ 2,  1], (label=L"C_{20}", range=range(0., 5C_0[][20]; length=1_000), format="{:.3e}", startvalue=C_0[][20])) # , width=0.4w[]))
# sg_sliders  = [ # collect sliders
#     sg_C01, sg_C02, # V
#     sg_C03, sg_C04, # Y
#     sg_C05, sg_C06, # f
#     sg_C07, sg_C08, # rd
#     sg_C09, sg_C10, # h
#     sg_C11, sg_C12, # rs
#     sg_C13, sg_C14, # Rd
#     sg_C15, sg_C16, # H
#     sg_C17, sg_C18, # Rs
#     sg_C19, sg_C20  # Yadj
# ]
sg_sliders = Observable([
    # V
    SliderGrid(grid_sliders[][ 1,  3][ 1,  1], (label=L"C_{ 1}", range=range(0., 5C_0[][ 1]; length=1_000), format="{:.3e}", startvalue=C_0[][ 1])), # , width=0.4w[]))
    SliderGrid(grid_sliders[][ 1,  3][ 2,  1], (label=L"C_{ 2}", range=range(0., 5C_0[][ 2]; length=1_000), format="{:.3e}", startvalue=C_0[][ 2])), # , width=0.4w[]))
    # Y
    SliderGrid(grid_sliders[][ 2,  3][ 1,  1], (label=L"C_{ 3}", range=range(0., 5C_0[][ 3]; length=1_000), format="{:.3e}", startvalue=C_0[][ 3])), # , width=0.4w[]))
    SliderGrid(grid_sliders[][ 2,  3][ 2,  1], (label=L"C_{ 4}", range=range(0., 5C_0[][ 4]; length=1_000), format="{:.3e}", startvalue=C_0[][ 4])), # , width=0.4w[]))
    # f
    SliderGrid(grid_sliders[][ 3,  3][ 1,  1], (label=L"C_{ 5}", range=range(0., 5C_0[][ 5]; length=1_000), format="{:.3e}", startvalue=C_0[][ 5])), # , width=0.4w[]))
    SliderGrid(grid_sliders[][ 3,  3][ 2,  1], (label=L"C_{ 6}", range=range(0., 5C_0[][ 6]; length=1_000), format="{:.3e}", startvalue=C_0[][ 6])), # , width=0.4w[]))
    # rd
    SliderGrid(grid_sliders[][ 4,  3][ 1,  1], (label=L"C_{ 7}", range=range(0., 5C_0[][ 7]; length=1_000), format="{:.3e}", startvalue=C_0[][ 7])), # , width=0.4w[]))
    SliderGrid(grid_sliders[][ 4,  3][ 2,  1], (label=L"C_{ 8}", range=range(0., 5C_0[][ 8]; length=1_000), format="{:.3e}", startvalue=C_0[][ 8])), # , width=0.4w[]))
    # h
    SliderGrid(grid_sliders[][ 5,  3][ 1,  1], (label=L"C_{ 9}", range=range(0., 5C_0[][ 9]; length=1_000), format="{:.3e}", startvalue=C_0[][ 9])), # , width=0.4w[]))
    SliderGrid(grid_sliders[][ 5,  3][ 2,  1], (label=L"C_{10}", range=range(0., 5C_0[][10]; length=1_000), format="{:.3e}", startvalue=C_0[][10])), # , width=0.4w[]))
    # rs
    SliderGrid(grid_sliders[][ 6,  3][ 1,  1], (label=L"C_{11}", range=range(0., 5C_0[][11]; length=1_000), format="{:.3e}", startvalue=C_0[][11])), # , width=0.4w[]))
    SliderGrid(grid_sliders[][ 6,  3][ 2,  1], (label=L"C_{12}", range=range(0., 5C_0[][12]; length=1_000), format="{:.3e}", startvalue=C_0[][12])), # , width=0.4w[]))
    # Rd
    SliderGrid(grid_sliders[][ 7,  3][ 1,  1], (label=L"C_{13}", range=range(0., 5C_0[][13]; length=1_000), format="{:.3e}", startvalue=C_0[][13])), # , width=0.4w[]))
    SliderGrid(grid_sliders[][ 7,  3][ 2,  1], (label=L"C_{14}", range=range(0., 5C_0[][14]; length=1_000), format="{:.3e}", startvalue=C_0[][14])), # , width=0.4w[]))
    # H
    SliderGrid(grid_sliders[][ 8,  3][ 1,  1], (label=L"C_{15}", range=range(0., 5C_0[][15]; length=1_000), format="{:.3e}", startvalue=C_0[][15])), # , width=0.4w[]))
    SliderGrid(grid_sliders[][ 8,  3][ 2,  1], (label=L"C_{16}", range=range(0., 5C_0[][16]; length=1_000), format="{:.3e}", startvalue=C_0[][16])), # , width=0.4w[]))
    # Rs
    SliderGrid(grid_sliders[][ 9,  3][ 1,  1], (label=L"C_{17}", range=range(0., 5C_0[][17]; length=1_000), format="{:.3e}", startvalue=C_0[][17])), # , width=0.4w[]))
    SliderGrid(grid_sliders[][ 9,  3][ 2,  1], (label=L"C_{18}", range=range(0., 5C_0[][18]; length=1_000), format="{:.3e}", startvalue=C_0[][18])), # , width=0.4w[]))
    # Yadj
    SliderGrid(grid_sliders[][10,  3][ 1,  1], (label=L"C_{19}", range=range(0., 5C_0[][19]; length=1_000), format="{:.3e}", startvalue=C_0[][19])), # , width=0.4w[]))
    SliderGrid(grid_sliders[][10,  3][ 2,  1], (label=L"C_{20}", range=range(0., 5C_0[][20]; length=1_000), format="{:.3e}", startvalue=C_0[][20])), # , width=0.4w[]))
])

#### plot
ax = Axis(grid_plot[ 1:  9,  1:  9],
    xlabel="True Strain (mm/mm)",
    ylabel="True Stress (Pa)",
    aspect=1.0, tellheight=true, tellwidth=true) # , height=3\2w[], width=w[])
ax_isv = Axis(h[1, 1],
    xlabel="True Strain (mm/mm)",
    ylabel="True Stress (Pa)")
xlims!(ax, (0., nothing)); ylims!(ax, (min_stress, max_stress))
# xlims!(ax_isv, (0., nothing)); ylims!(ax_isv, (min_stress, max_stress))
BCJinator.plot_sets!(ax, ax_isv, dataseries[], bcj[], Plot_ISVs[])
leg = Observable(axislegend(ax, position=:rb))
leg_isv = Observable(axislegend(ax_isv, position=:lt))
BCJinator.update!(dataseries[], bcj[], incnum[], istate[], Plot_ISVs[], BCJMetal[])

#### buttons below plot
buttons_grid = GridLayout(grid_plot[ 10,  :], 1, 5)
buttons_labels = ["Calibrate", "Reset", "Show ISVs", "Save Props", "Export Curves"]
buttons = buttons_grid[1, :] = [Button(f, label=bl) for bl in buttons_labels]
buttons_calibrate       = buttons[1]
buttons_resetparams     = buttons[2]
buttons_showisvs        = buttons[3]
buttons_savecurves      = buttons[4]
buttons_exportcurves    = buttons[5]



################################################################
#                     E N D   F I G U R E                      #
################################################################



# dynamic backend functions
## inputs
### browse for parameters dictionary
on(propsfile_button.clicks) do click
    file = pick_file(; filterlist="csv")
    if file != ""
        propsfile[] = file;                                     notify(propsfile)
    end
end
### experimental data sets (browse)
on(expdatasets_button.clicks) do click
    filelist = pick_multi_file(; filterlist="csv")
    if !isempty(filelist)
        files[] = filelist;                                     notify(files)
    end
end
### experimental data sets (drag-and-drop)
on(events(f.scene).dropped_files) do filedump
    if !isempty(filedump)
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
### update input parameters to calibrate
on(buttons_updateinputs.clicks) do click
    empty!(ax); !isnothing(leg[]) ? delete!(leg[]) : nothing;   notify(leg)
    empty!(ax_isv); !isnothing(leg_isv[]) ? delete!(leg_isv[]) : nothing; notify(leg_isv)
    BCJinator.reset_sliders!(params, sg_sliders, C_0, nsliders)
    Plot_ISVs[] = begin
        [Symbol(s[2:end]) for s in split(Plot_ISVs_textbox.displayed_string[], r"(,|;|\s)")]
    end;                                                        notify(Plot_ISVs)
    incnum[] = parse(Int64, incnum_textbox.displayed_string[]); notify(incnum)
    istate[] = begin
        if loaddir_axial_toggle.active[]
            1
        elseif loaddir_torsion_toggle.active[]
            2
        else
            error("'Tension/Compression' or 'Torsion' needs to be toggled on.")
        end
    end;                                                        notify(istate)
    bcj[] = BCJinator.bcjmetalcalibration_init(files[], incnum[], istate[], params[], MPa, BCJMetal[]); notify(bcj)
    dataseries[] = BCJinator.dataseries_init(bcj[].nsets, bcj[].test_data, Plot_ISVs[]); notify(dataseries)
    BCJinator.plot_sets!(ax, ax_isv, dataseries[], bcj[], Plot_ISVs[])
    !isnothing(leg) ? (leg[] = axislegend(ax, position=:rb)) : nothing; notify(leg)
    !isnothing(leg_isv) ? (leg_isv[] = axislegend(ax_isv, position=:lt)) : nothing; notify(leg_isv)
end

## interactivity
# ### scroll experimental datasets textbox
# on(events(expdatasets_textbox).scroll) do scroll
#     translate!(Accum, expdatasets_textbox.scene, 2 .* map(-, scroll))
# end
### model selection (menu)
on(modelselection_menu.selection) do s
    closedsliders = try
        GLMakie.close(screen_sliders[])
        true
    catch exc
        if isa(exc, AssertionError)
            false
        else
            true
        end
    end
    BCJMetal[] = s; notify(BCJMetal)
    if s == BCJ.DK
        nequations[] = 10; notify(nequations)
        characteristic_equations[] = [
            # plasticstrainrate
            L"\dot{\epsilon}_{p} = f(\theta)\sinh\left[ \frac{ \{|\mathbf{\xi}| - \kappa - Y(\theta) \} }{ (1 - \phi)V(\theta) } \right]\frac{\mathbf{\xi}'}{|\mathbf{\xi}'|}\text{, let }\mathbf{\xi}' = \mathbf{\sigma}' - \mathbf{\alpha}'",
            # kinematichardening
            L"\dot{\mathbf{\alpha}} = h(\theta)\dot{\epsilon}_{p} - [r_{d}(\theta)|\dot{\epsilon}_{p}| + r_{s}(\theta)]|\mathbf{\alpha}|\mathbf{\alpha}",
            # isotropichardening
            L"\dot{\kappa} = H(\theta)\dot{\epsilon}_{p} - [R_{d}(\theta)|\dot{\epsilon}_{p}| + R_{s}(\theta)]\kappa^{2}",
            # flowrule
            L"F = |\sigma - \alpha| - \kappa - \beta(|\dot{\epsilon}_{p}|, \theta)",
            # initialyieldstressbeta
            L"\beta(\dot{\epsilon}_{p}, \theta) = Y(\theta) + V(\theta)\sinh^{-1}\left(\frac{|\dot{\epsilon}_{p}|}{f(\theta)}\right)",
        ]; notify(characteristic_equations)
        for (lab, eq) in zip(chareqs_labels[], characteristic_equations[])
            lab.text[] = eq
        end; notify(chareqs_labels)
        empty!(g); grid_sliders[] = GridLayout(g[1, 1], length(dependence_equations[]), 3); notify(grid_sliders)
        dependence_equations[] = [
            L"V = C_{ 1} \mathrm{exp}(-C_{ 2} / \theta)", # textbox_V
            L"Y = C_{ 3} \mathrm{exp}( C_{ 4} / \theta)", # textbox_Y
            L"f = C_{ 5} \mathrm{exp}(-C_{ 6} / \theta)", # textbox_f
            L"r_{d} = C_{ 7} \mathrm{exp}(-C_{ 8} / \theta)", # textbox_rd
            L"h = C_{ 9} - C_{10}\theta", # textbox_h
            L"r_{s} = C_{11} \mathrm{exp}(-C_{12} / \theta)", # textbox_rs
            L"R_{d} = C_{13} \mathrm{exp}(-C_{14} / \theta)", # textbox_Rd
            L"H = C_{15} - C_{16}\theta", # textbox_H
            L"R_{s} = C_{17} \mathrm{exp}(-C_{18} / \theta)", # textbox_Rs
            L"Y_{adj}", # textbox_Yadj
        ]; notify(dependence_equations)
        # for (lab, eq) in zip(depeqs_labels[], dependence_equations[])
        #     lab.text[] = eq
        # end; notify(depeqs_labels)
        depeqs_labels[] = [
            Label(grid_sliders[][ 1,  2], dependence_equations[][ 1]; halign=:left)
            Label(grid_sliders[][ 2,  2], dependence_equations[][ 2]; halign=:left)
            Label(grid_sliders[][ 3,  2], dependence_equations[][ 3]; halign=:left)
            Label(grid_sliders[][ 4,  2], dependence_equations[][ 4]; halign=:left)
            Label(grid_sliders[][ 5,  2], dependence_equations[][ 5]; halign=:left)
            Label(grid_sliders[][ 6,  2], dependence_equations[][ 6]; halign=:left)
            Label(grid_sliders[][ 7,  2], dependence_equations[][ 7]; halign=:left)
            Label(grid_sliders[][ 8,  2], dependence_equations[][ 8]; halign=:left)
            Label(grid_sliders[][ 9,  2], dependence_equations[][ 9]; halign=:left)
            Label(grid_sliders[][10,  2], dependence_equations[][10]; halign=:left)
        ]; notify(depeqs_labels)
        toggles[]     = [ # collect toggles
            Toggle(grid_sliders[][ 1,  1], active=false), # V
            Toggle(grid_sliders[][ 2,  1], active=false), # Y
            Toggle(grid_sliders[][ 3,  1], active=false), # f
            Toggle(grid_sliders[][ 4,  1], active=false), # rd
            Toggle(grid_sliders[][ 5,  1], active=false), # h
            Toggle(grid_sliders[][ 6,  1], active=false), # rs
            Toggle(grid_sliders[][ 7,  1], active=false), # Rd
            Toggle(grid_sliders[][ 8,  1], active=false), # H
            Toggle(grid_sliders[][ 9,  1], active=false), # Rs
            Toggle(grid_sliders[][10,  1], active=false), # Yadj
        ]; notify(toggles)
        sg_sliders[] = [
            # V
            SliderGrid(grid_sliders[][ 1,  3][ 1,  1], (label=L"C_{ 1}", range=range(0., 5C_0[][ 1]; length=1_000), format="{:.3e}", startvalue=C_0[][ 1])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 1,  3][ 2,  1], (label=L"C_{ 2}", range=range(0., 5C_0[][ 2]; length=1_000), format="{:.3e}", startvalue=C_0[][ 2])), # , width=0.4w[]))
            # Y
            SliderGrid(grid_sliders[][ 2,  3][ 1,  1], (label=L"C_{ 3}", range=range(0., 5C_0[][ 3]; length=1_000), format="{:.3e}", startvalue=C_0[][ 3])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 2,  3][ 2,  1], (label=L"C_{ 4}", range=range(0., 5C_0[][ 4]; length=1_000), format="{:.3e}", startvalue=C_0[][ 4])), # , width=0.4w[]))
            # f
            SliderGrid(grid_sliders[][ 3,  3][ 1,  1], (label=L"C_{ 5}", range=range(0., 5C_0[][ 5]; length=1_000), format="{:.3e}", startvalue=C_0[][ 5])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 3,  3][ 2,  1], (label=L"C_{ 6}", range=range(0., 5C_0[][ 6]; length=1_000), format="{:.3e}", startvalue=C_0[][ 6])), # , width=0.4w[]))
            # rd
            SliderGrid(grid_sliders[][ 4,  3][ 1,  1], (label=L"C_{ 7}", range=range(0., 5C_0[][ 7]; length=1_000), format="{:.3e}", startvalue=C_0[][ 7])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 4,  3][ 2,  1], (label=L"C_{ 8}", range=range(0., 5C_0[][ 8]; length=1_000), format="{:.3e}", startvalue=C_0[][ 8])), # , width=0.4w[]))
            # h
            SliderGrid(grid_sliders[][ 5,  3][ 1,  1], (label=L"C_{ 9}", range=range(0., 5C_0[][ 9]; length=1_000), format="{:.3e}", startvalue=C_0[][ 9])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 5,  3][ 2,  1], (label=L"C_{10}", range=range(0., 5C_0[][10]; length=1_000), format="{:.3e}", startvalue=C_0[][10])), # , width=0.4w[]))
            # rs
            SliderGrid(grid_sliders[][ 6,  3][ 1,  1], (label=L"C_{11}", range=range(0., 5C_0[][11]; length=1_000), format="{:.3e}", startvalue=C_0[][11])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 6,  3][ 2,  1], (label=L"C_{12}", range=range(0., 5C_0[][12]; length=1_000), format="{:.3e}", startvalue=C_0[][12])), # , width=0.4w[]))
            # Rd
            SliderGrid(grid_sliders[][ 7,  3][ 1,  1], (label=L"C_{13}", range=range(0., 5C_0[][13]; length=1_000), format="{:.3e}", startvalue=C_0[][13])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 7,  3][ 2,  1], (label=L"C_{14}", range=range(0., 5C_0[][14]; length=1_000), format="{:.3e}", startvalue=C_0[][14])), # , width=0.4w[]))
            # H
            SliderGrid(grid_sliders[][ 8,  3][ 1,  1], (label=L"C_{15}", range=range(0., 5C_0[][15]; length=1_000), format="{:.3e}", startvalue=C_0[][15])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 8,  3][ 2,  1], (label=L"C_{16}", range=range(0., 5C_0[][16]; length=1_000), format="{:.3e}", startvalue=C_0[][16])), # , width=0.4w[]))
            # Rs
            SliderGrid(grid_sliders[][ 9,  3][ 1,  1], (label=L"C_{17}", range=range(0., 5C_0[][17]; length=1_000), format="{:.3e}", startvalue=C_0[][17])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 9,  3][ 2,  1], (label=L"C_{18}", range=range(0., 5C_0[][18]; length=1_000), format="{:.3e}", startvalue=C_0[][18])), # , width=0.4w[]))
            # Yadj
            SliderGrid(grid_sliders[][10,  3][ 1,  1], (label=L"C_{19}", range=range(0., 5C_0[][19]; length=1_000), format="{:.3e}", startvalue=C_0[][19])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][10,  3][ 2,  1], (label=L"C_{20}", range=range(0., 5C_0[][20]; length=1_000), format="{:.3e}", startvalue=C_0[][20])), # , width=0.4w[]))
        ]; notify(sg_sliders)
    elseif s == BCJ.Bammann1990Modeling
        nequations[] = 9; notify(nequations)
        characteristic_equations[] = [
            # plasticstrainrate
            L"\dot{\epsilon}_{p} = f(\theta)\sinh\left[ \frac{ \{|\mathbf{\xi}| - \kappa - Y(\theta) \} }{ V(\theta) } \right]\frac{\mathbf{\xi}'}{|\mathbf{\xi}'|}\text{, let }\mathbf{\xi}' = \mathbf{\sigma}' - \mathbf{\alpha}'"
            # kinematichardening
            L"\dot{\mathbf{\alpha}} = h\mu(\theta)\dot{\epsilon}_{p} - [r_{d}(\theta)|\dot{\epsilon}_{p}| + r_{s}(\theta)]|\mathbf{\alpha}|\mathbf{\alpha}"
            # isotropichardening
            L"\dot{\kappa} = H\mu(\theta)\dot{\epsilon}_{p} - [R_{d}(\theta)|\dot{\epsilon}_{p}| + R_{s}(\theta)]\kappa^{2}"
            # flowrule
            L"F = |\sigma - \alpha| - \kappa - \beta(|\dot{\epsilon}_{p}|, \theta)"
            # initialyieldstressbeta
            L"\beta(\dot{\epsilon}_{p}, \theta) = Y(\theta) + V(\theta)\sinh^{-1}\left(\frac{|\dot{\epsilon}_{p}|}{f(\theta)}\right)"
        ]; notify(characteristic_equations)
        for (lab, eq) in zip(chareqs_labels[], characteristic_equations[])
            lab.text[] = eq
        end; notify(chareqs_labels)
        empty!(g); grid_sliders[] = GridLayout(g[1, 1], length(dependence_equations[]), 3); notify(grid_sliders)
        dependence_equations[] = [
            L"V = C_{ 1} \mathrm{exp}(-C_{ 2} / \theta)", # textbox_V
            L"Y = C_{ 3} \mathrm{exp}( C_{ 4} / \theta)", # textbox_Y
            L"f = C_{ 5} \mathrm{exp}(-C_{ 6} / \theta)", # textbox_f
            L"r_{d} = C_{ 7} \mathrm{exp}(-C_{ 8} / \theta)", # textbox_rd
            L"h = C_{ 9} \mathrm{exp}( C_{10} / \theta)", # textbox_h
            L"r_{s} = C_{11} \mathrm{exp}(-C_{12} / \theta)", # textbox_rs
            L"R_{d} = C_{13} \mathrm{exp}(-C_{14} / \theta)", # textbox_Rd
            L"H = C_{15} \mathrm{exp}( C_{16} / \theta)", # textbox_H
            L"R_{s} = C_{17} \mathrm{exp}(-C_{18} / \theta)", # textbox_Rs
        ]; notify(dependence_equations)
        # for (lab, eq) in zip(depeqs_labels[], dependence_equations[])
        #     lab.text[] = eq
        # end; notify(depeqs_labels)
        depeqs_labels[] = [
            Label(grid_sliders[][ 1,  2], dependence_equations[][ 1]; halign=:left)
            Label(grid_sliders[][ 2,  2], dependence_equations[][ 2]; halign=:left)
            Label(grid_sliders[][ 3,  2], dependence_equations[][ 3]; halign=:left)
            Label(grid_sliders[][ 4,  2], dependence_equations[][ 4]; halign=:left)
            Label(grid_sliders[][ 5,  2], dependence_equations[][ 5]; halign=:left)
            Label(grid_sliders[][ 6,  2], dependence_equations[][ 6]; halign=:left)
            Label(grid_sliders[][ 7,  2], dependence_equations[][ 7]; halign=:left)
            Label(grid_sliders[][ 8,  2], dependence_equations[][ 8]; halign=:left)
            Label(grid_sliders[][ 9,  2], dependence_equations[][ 9]; halign=:left)
        ]; notify(depeqs_labels)
        toggles[]     = [ # collect toggles
            Toggle(grid_sliders[][ 1,  1], active=false), # V
            Toggle(grid_sliders[][ 2,  1], active=false), # Y
            Toggle(grid_sliders[][ 3,  1], active=false), # f
            Toggle(grid_sliders[][ 4,  1], active=false), # rd
            Toggle(grid_sliders[][ 5,  1], active=false), # h
            Toggle(grid_sliders[][ 6,  1], active=false), # rs
            Toggle(grid_sliders[][ 7,  1], active=false), # Rd
            Toggle(grid_sliders[][ 8,  1], active=false), # H
            Toggle(grid_sliders[][ 9,  1], active=false), # Rs
        ]; notify(toggles)
        sg_sliders[] = [
            # V
            SliderGrid(grid_sliders[][ 1,  3][ 1,  1], (label=L"C_{ 1}", range=range(0., 5C_0[][ 1]; length=1_000), format="{:.3e}", startvalue=C_0[][ 1])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 1,  3][ 2,  1], (label=L"C_{ 2}", range=range(0., 5C_0[][ 2]; length=1_000), format="{:.3e}", startvalue=C_0[][ 2])), # , width=0.4w[]))
            # Y
            SliderGrid(grid_sliders[][ 2,  3][ 1,  1], (label=L"C_{ 3}", range=range(0., 5C_0[][ 3]; length=1_000), format="{:.3e}", startvalue=C_0[][ 3])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 2,  3][ 2,  1], (label=L"C_{ 4}", range=range(0., 5C_0[][ 4]; length=1_000), format="{:.3e}", startvalue=C_0[][ 4])), # , width=0.4w[]))
            # f
            SliderGrid(grid_sliders[][ 3,  3][ 1,  1], (label=L"C_{ 5}", range=range(0., 5C_0[][ 5]; length=1_000), format="{:.3e}", startvalue=C_0[][ 5])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 3,  3][ 2,  1], (label=L"C_{ 6}", range=range(0., 5C_0[][ 6]; length=1_000), format="{:.3e}", startvalue=C_0[][ 6])), # , width=0.4w[]))
            # rd
            SliderGrid(grid_sliders[][ 4,  3][ 1,  1], (label=L"C_{ 7}", range=range(0., 5C_0[][ 7]; length=1_000), format="{:.3e}", startvalue=C_0[][ 7])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 4,  3][ 2,  1], (label=L"C_{ 8}", range=range(0., 5C_0[][ 8]; length=1_000), format="{:.3e}", startvalue=C_0[][ 8])), # , width=0.4w[]))
            # h
            SliderGrid(grid_sliders[][ 5,  3][ 1,  1], (label=L"C_{ 9}", range=range(0., 5C_0[][ 9]; length=1_000), format="{:.3e}", startvalue=C_0[][ 9])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 5,  3][ 2,  1], (label=L"C_{10}", range=range(0., 5C_0[][10]; length=1_000), format="{:.3e}", startvalue=C_0[][10])), # , width=0.4w[]))
            # rs
            SliderGrid(grid_sliders[][ 6,  3][ 1,  1], (label=L"C_{11}", range=range(0., 5C_0[][11]; length=1_000), format="{:.3e}", startvalue=C_0[][11])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 6,  3][ 2,  1], (label=L"C_{12}", range=range(0., 5C_0[][12]; length=1_000), format="{:.3e}", startvalue=C_0[][12])), # , width=0.4w[]))
            # Rd
            SliderGrid(grid_sliders[][ 7,  3][ 1,  1], (label=L"C_{13}", range=range(0., 5C_0[][13]; length=1_000), format="{:.3e}", startvalue=C_0[][13])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 7,  3][ 2,  1], (label=L"C_{14}", range=range(0., 5C_0[][14]; length=1_000), format="{:.3e}", startvalue=C_0[][14])), # , width=0.4w[]))
            # H
            SliderGrid(grid_sliders[][ 8,  3][ 1,  1], (label=L"C_{15}", range=range(0., 5C_0[][15]; length=1_000), format="{:.3e}", startvalue=C_0[][15])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 8,  3][ 2,  1], (label=L"C_{16}", range=range(0., 5C_0[][16]; length=1_000), format="{:.3e}", startvalue=C_0[][16])), # , width=0.4w[]))
            # Rs
            SliderGrid(grid_sliders[][ 9,  3][ 1,  1], (label=L"C_{17}", range=range(0., 5C_0[][17]; length=1_000), format="{:.3e}", startvalue=C_0[][17])), # , width=0.4w[]))
            SliderGrid(grid_sliders[][ 9,  3][ 2,  1], (label=L"C_{18}", range=range(0., 5C_0[][18]; length=1_000), format="{:.3e}", startvalue=C_0[][18])), # , width=0.4w[]))
        ]; notify(sg_sliders)
    end
    if closedsliders
        screen_sliders[] = GLMakie.Screen(; title="Sliders", focus_on_show=true); notify(screen_sliders)
        display(screen_sliders[], g)
    end
end
### show sliders
on(showsliders_button.clicks) do click
    screen_sliders[] = GLMakie.Screen(; title="Sliders", focus_on_show=true); notify(screen_sliders)
    display(screen_sliders[], g)
end
### scroll sliders window
on(events(g).scroll) do scroll
    translate!(Accum, g.scene, 2 .* map(-, scroll))
end
### update curves from sliders
@lift for (i, sgs) in enumerate($sg_sliders)
    on(only(sgs.sliders).value) do val
        # redefine params with new slider values
        params[][BCJinator.constant_string(i)] = to_value(val);       notify(params)
        BCJinator.update!(dataseries[], bcj[], incnum[], istate[], Plot_ISVs[], BCJMetal[])
    end
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
    BCJinator.reset_sliders!(params, sg_sliders, C_0, nsliders)
end
### show isv plot
on(buttons_showisvs.clicks) do click
    screen_isvs = GLMakie.Screen(; title="ISVs") # , focus_on_show=true)
    display(screen_isvs, h)
end
### save parameters
on(buttons_savecurves.clicks) do click
    props_dir, props_name = dirname(propsfile[]), basename(propsfile[])
    # "Save new props file"
    propsfile_new = save_file(; filterlist="csv")
    df = DataFrame(
        "Comment" => [BCJinator.constant_string.(range(1, nsliders))..., "Bulk Mod", "Shear Mod"],
        "For Calibration with vumat"    => [[only(sgc.sliders).value[] for sgc in sg_sliders[]]..., bulk_mod, shear_mod]
    )
    CSV.write(propsfile_new, df)
    println("New props file written to: \"", propsfile_new, "\"")
end
### export curves
on(buttons_exportcurves.clicks) do click
    props_dir, props_name = dirname(propsfile[]), basename(propsfile[])
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



display(screen_main, f) # that's all folks!