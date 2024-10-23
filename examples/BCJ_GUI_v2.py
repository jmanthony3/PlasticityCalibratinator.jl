import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider, Button
from tkinter import Tk     
from tkinter.filedialog import askopenfilenames, askopenfilename, asksaveasfilename
import csv
import os
from BCJ_Basic_v2 import BCJ

"""
 Daniel Kenney
 Summer 2023
 --------------------------------
- User editable variable 
    - plotting parameters and layouts

- read in props and data files
- 

- define sliders/buttons/layout
- 
- v2 - change data storage from list to dictionary
"""



# ------------------------------------------------
# ---------- User Modifiable Variables -----------
# ------------------------------------------------
incnum      = 200
istate      = 1      #1 = tension, 2 = torsion
Ask_Files   = True
Material    = "4340"
Plot_ISVs   = True


Scale_MPa   = 1000000           # Unit conversion from MPa to Pa from data
max_stress  = 3000 * 1000000

if Material == "4340":
    max_stress  = 2000 * 1000000



# ------------------------------------------------
# ------------------------------------------------
kS          = 0     # default tension component
if istate == 2:
    kS      = 3     # select torsion component


# -------- Holding Variable Declarations --------
incnum1     = incnum +1                          # +1 so that 100 increments between 0 and 1 are 0.01
SF          = np.zeros((6,incnum1)   , float)    # Total stress state
S           = np.zeros((  incnum1)   , float)    # Stress in relevant direction
SVM         = np.zeros((  incnum1)   , float)    # VM Stress
EF          = np.zeros((6,incnum1)   , float)    # Total stress state
E           = np.zeros((  incnum1)   , float)    # Stress in relevant direction
Al          = np.zeros((  incnum1)   , float)    # Alphpa in relevant direction
ratio       = np.zeros((  incnum1)   , float)    # Alphpa in relevant direction


# ------------ Plot Formatting ------------
colors      = ['b','c','g','y','r','m','k']
colors      = colors + colors
lstyles     = ['-']*7+[':']*7





# ------------------------------------------------
# ----------- Slider Range Formatting ------------
# ------------------------------------------------
nsliders = 21       # Index with "s in range(1,nsliders):" so s corresponds with C#
posC    = [None]*nsliders
C_amp   = [None]*nsliders
C_0     = [None]*nsliders
posC    = [None]*nsliders
ax_C    = [None]*nsliders
Slider_C= [None]*nsliders


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
if Ask_Files == True:
    Tk().withdraw()
    propsfile = askopenfilename(title = 'Select the props file for this material')
    print('Props file read in  : ', propsfile)
    filez = askopenfilenames(title='Select all experimental data sets')
    flz = list(filez)
    print('Data file(s) read in: ', flz)

# Manually paste file locations to avoid pop-up process
else:
    if Material == "4340":
        propsfile = 'path/to/4340 Data/Props_BCJ_4340temp.csv'
        flz = [
                'path/to/4340 Data/Data_Tension_e0002_T295.csv',
                'path/to/4340 Data/Data_Tension_e570_T295.csv',
                'path/to/4340 Data/Data_Tension_e604_T500.csv',
                'path/to/4340 Data/Data_Tension_e650_T730.csv
               ]
    elif Material == "A36":     # Not actual data - only used for comparing
        propsfile = 'path/to/A36 Data/Props_BCJ_A36.csv'
        flz = [
                'path/to/A36 Data/Data_Comp_Sim.csv'
        ]
# ------------------------------------------------
# Assign props values:
with open(propsfile,'r') as pfile:
    csvreader = csv.reader(pfile)
    for row in csvreader:
        if   row[0] == 'C01':  C_0[1] = float(row[1])
        elif row[0] == 'C02':  C_0[2] = float(row[1])
        elif row[0] == 'C03':  C_0[3] = float(row[1])
        elif row[0] == 'C04':  C_0[4] = float(row[1])
        elif row[0] == 'C05':  C_0[5] = float(row[1])
        elif row[0] == 'C06':  C_0[6] = float(row[1])
        elif row[0] == 'C07':  C_0[7] = float(row[1])
        elif row[0] == 'C08':  C_0[8] = float(row[1])
        elif row[0] == 'C09':  C_0[9] = float(row[1])
        elif row[0] == 'C10':  C_0[10] = float(row[1])
        elif row[0] == 'C11':  C_0[11] = float(row[1])
        elif row[0] == 'C12':  C_0[12] = float(row[1])
        elif row[0] == 'C13':  C_0[13] = float(row[1])
        elif row[0] == 'C14':  C_0[14] = float(row[1])
        elif row[0] == 'C15':  C_0[15] = float(row[1])
        elif row[0] == 'C16':  C_0[16] = float(row[1])
        elif row[0] == 'C17':  C_0[17] = float(row[1])
        elif row[0] == 'C18':  C_0[18] = float(row[1])
        elif row[0] == 'C19':  C_0[19] = float(row[1])
        elif row[0] == 'C20':  C_0[20] = float(row[1])
        elif row[0] == 'Bulk Mod':  bulk_mod = float(row[1])
        elif row[0] == 'Shear Mod':  shear_mod = float(row[1])
        elif row[0] == 'Comment': Com = row[1]
        else: print('WARNING: extra/incorrect row in props file: ', row)
    # props = [A, B ,n ,C ,m , Tr, Tm, er0, Com]

#assign params:
# params = Parameters()
# params.add('C01',C_0[1])
# params.add('C02',C_0[2])
# params.add('C03',C_0[3])
# params.add('C04',C_0[4])
# params.add('C05',C_0[5])
# params.add('C06',C_0[6])
# params.add('C07',C_0[7])
# params.add('C08',C_0[8])
# params.add('C09',C_0[9])
# params.add('C10',C_0[10])
# params.add('C11',C_0[11])
# params.add('C12',C_0[12])
# params.add('C13',C_0[13])
# params.add('C14',C_0[14])
# params.add('C15',C_0[15])
# params.add('C16',C_0[16])
# params.add('C17',C_0[17])
# params.add('C18',C_0[18])
# params.add('C19',C_0[19])
# params.add('C20',C_0[20])
# params.add('bulk_mod',bulk_mod)
# params.add('shear_mod',shear_mod)

params = {
    'C01' : C_0[1],
    'C02' : C_0[2],
    'C03' : C_0[3],
    'C04' : C_0[4],
    'C05' : C_0[5],
    'C06' : C_0[6],
    'C07' : C_0[7],
    'C08' : C_0[8],
    'C09' : C_0[9],
    'C10' : C_0[10],
    'C11' : C_0[11],
    'C12' : C_0[12],
    'C13' : C_0[13],
    'C14' : C_0[14],
    'C15' : C_0[15],
    'C16' : C_0[16],
    'C17' : C_0[17],
    'C18' : C_0[18],
    'C19' : C_0[19],
    'C20' : C_0[20],
    'bulk_mod' : bulk_mod,
    'shear_mod': shear_mod
}
# ------------------------------------------------
# Store stress-strain data and corresponding test conditions (temp and strain rate)
sets = len(flz)
# test_cond   = []         # Used to store testing conditions (temp, strain rate)
# test_data   = []         # Used to store data
test_cond   = {
    'StrainRate':[],
    'Temp': [],
    'Name': []
}
test_data   = {
    'Data_E':[],
    'Data_S':[],
    'Model_E':[],
    'Model_S':[],
    'Model_VM':[],
    'Model_alph':[],
    'Model_kap':[],
    'Model_tot':[]
}

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]

for i, file in enumerate(flz):
    with open(file,'r') as csvfile:
        csvreader = csv.DictReader(csvfile)

        #add stress/strain data:
        strn = []
        strs = []
        er   = []
        T    = []
        name = []
        j = 0
        for col in csvreader:
            strn.append(float(col['Strain']))
            strs.append(float(col['Stress'])*Scale_MPa)
            if j < 1:
                er.append(float(col['Strain Rate']))
                T.append(float(col['Temperature']))
                name.append(col['Name'])
                j += 1
        #check data entered
        if len(strn) != len(strs):
            print('ERROR!! data from  \'', file , '\'  has bad stress-strain data lengths')

        #store the stress-strain data
        test_cond['StrainRate'].append(float(er[0]))
        test_cond['Temp'].append(float(T[0]))
        test_cond['Name'].append(name[0])
        test_data['Data_E'].append(strn)
        test_data['Data_S'].append(strs)



# -----------------------------------------------




# -----------------------------------------------------
# Calculate the model's initial stress-strain curve
# -----------------------------------------------------

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
# For each set, calculate the model curve and error
for i in range(sets):
    emax = max(test_data['Data_E'][i])
    # print('Setup: emax for set ',i,' = ', emax)
    [EF, SF, alph, kap,tot] = BCJ(params, test_cond['Temp'][i], test_cond['StrainRate'][i],
                            emax, incnum, istate)

    #pull only the relevant (tension/torsion) strain being evaluated:
    for j in range(len(EF[kS])):
        E[j]    = EF[kS][j]
        S[j]    = SF[kS][j]
        SVM[j]  = (SF[0][j] - SF[1][j])**2 + (SF[1][j] - SF[2][j])**2 + (SF[2][j] - SF[0][j])**2 \
                 + (SF[3][j]**2 + SF[4][j]**2 + SF[5][j]**2)*6.
        SVM[j]  = np.sqrt(SVM[j]*0.5)
        Al[j]   = alph[kS][j]
        # ratio = tot[j] / SVM[j]
        # print('ratio:', ratio )
    # test_data[i][1] = [E,S,Al,kap,tot,SVM]             #Store model stress/strain data
    test_data['Model_E'].append(E.copy())
    test_data['Model_S'].append(S.copy())
    test_data['Model_alph'].append(Al.copy())
    test_data['Model_kap'].append(kap.copy())
    test_data['Model_tot'].append(tot.copy())
    test_data['Model_VM'].append(SVM.copy())

# print(test_data['Model_E'])
# print(test_data['Model_S'])




# -----------------------------------------------------

# Create the axes and the lines that we will manipulate

fig, ax = plt.subplots()
# lines[0] = data
# lines[1] = model (to be updated)
# lines[2] = alpha model (to be updated)
# lines[3] = kappa model (to be updated)
if Plot_ISVs:   lines = [[],[],[],[],[],[]]
else:           lines = [[],[]]

for i in range(sets):
    # print(test_data[i][1][0])
    # print(test_data[i][1][5])

    lobj1, = ax.plot(test_data['Data_E'][i], test_data['Data_S'][i], 'o', color = colors[i])  #, label='Data - '+test_cond[i][2]) 
    lobj2, = ax.plot(test_data['Model_E'][i], test_data['Model_VM'][i], ls = lstyles[i], color = colors[i] , label='VM Model - '+test_cond['Name'][i])
    lines[0].append(lobj1)
    lines[1].append(lobj2)

    if Plot_ISVs:
        lobj3, = ax.plot(test_data['Model_E'][i], test_data['Model_alph'][i],'--',color = colors[i] , label=r'$\alpha$ - '+test_cond['Name'][i])
        lobj4, = ax.plot(test_data['Model_E'][i], test_data['Model_kap'][i], '-.', color = colors[i] , label=r'$\kappa$ - '+test_cond['Name'][i])
        # lobj5, = ax.plot(test_data['Model_E'][i], test_data['Model_tot'][i], ':', color = colors[i] , label=r'$total$ - '+test_cond['Name'][i])
        # lobj6, = ax.plot(test_data['Model_E'][i], test_data['Model_S'][i], color = colors[i+1] , label=r'$S_{11}$ - '+test_cond['Name'][i])
        lines[2].append(lobj3)
        lines[3].append(lobj4)
        # lines[4].append(lobj5)
        # lines[5].append(lobj6)

ax.set_xlabel('True Strain (mm/mm)')
ax.set_ylabel('True Stress (Pa)')
ax.legend()
ax.set_ylim(bottom = 0.0, top = max_stress)
ax.set_ylim(bottom = 0.0)
ax.set_xlim(left=0.0)
fig.subplots_adjust(bottom=plot_bot , top = plot_top,
                    left = plot_left, right = plot_right)




# ------------------------------------------------
# Make a slider for each variable.
for i in range(1,nsliders):
    ax_C[i] = fig.add_axes(posC[i])
    Slider_C[i] = Slider(
        ax      = ax_C[i],
        label   = 'C'+str(i),
        # valmin  = C_0[i] - C_amp[i],
        # valmax  = C_0[i] + C_amp[i],
        valmin  = 0.0,
        # valmax  = max(2.0*C_0[i],1.),
        valmax  = 5.0*C_0[i] ,
        valinit = C_0[i]
        )

# ------------------------------------------------
# Add textboxes for clarity
fig.text(pos_Vx  , pos_Vy    , r'$V  =C_{1 } \mathrm{exp} (-C_{2 }/ \theta ) $')
fig.text(pos_Yx  , pos_Yy    , r'$Y  =C_{3 } \mathrm{exp} ( C_{4 }/ \theta ) $')
fig.text(pos_fx  , pos_fy    , r'$f  =C_{5 } \mathrm{exp} (-C_{6 }/ \theta ) $')

fig.text(pos_rdx , pos_rdy   , r'$r_d=C_{7 } \mathrm{exp} (-C_{8 }/ \theta ) $')
fig.text(pos_hx  , pos_hy    , r'$h  =C_{9 } - C_{10}  \theta  $')
fig.text(pos_rsx , pos_rsy   , r'$r_s=C_{11} \mathrm{exp} (-C_{12}/ \theta ) $')

fig.text(pos_Rdx , pos_Rdy   , r'$R_d=C_{13} \mathrm{exp} (-C_{14}/ \theta ) $')
fig.text(pos_Hx  , pos_Hy    , r'$H  =C_{15} - C_{16}  \theta  $')
fig.text(pos_Rsx , pos_Rsy   , r'$R_s=C_{17} \mathrm{exp} (-C_{18}/ \theta ) $')

fig.text(pos_Yadjx,pos_Yadjy , r'$Y_{adj}$')


# ------------------------------------------------

# The function to be called anytime a slider's value changes
def update(val):

    # redefine params with new slider values
    for g in range(1,nsliders):
        num = str(g)
        if len(num)==1: num = '0'+num
        num='C'+num
        params[num] = Slider_C[g].val

    for i in range(sets):
        emax = max(test_data['Data_E'][i])
        # print('Updat: emax for set ',i,' = ', emax)

        [EF, SF, alph, kap, tot] = BCJ(params, test_cond['Temp'][i], test_cond['StrainRate'][i],
                                emax, incnum, istate)

        #take only the relevant (tension/torsion) strain being evaluated:
        for j in range(len(EF[kS])):
            E[j] = EF[kS][j]
            S[j] = SF[kS][j]
            # SVM[j]  = SF[0][j]**2 + SF[1][j]**2 + SF[2][j]**2
            # SVM[j]  = np.sqrt(SVM[j])

            SVM[j]  = (SF[0][j] - SF[1][j])**2 + (SF[1][j] - SF[2][j])**2 + (SF[2][j]-SF[0][j])**2 \
                + (SF[3][j]**2 + SF[4][j]**2 + SF[5][j]**2)*6.
            SVM[j]  = np.sqrt(SVM[j]/2.)
            Al[j]   = alph[kS][j]

        lines[1][i].set_ydata(SVM)
        if Plot_ISVs:
            lines[2][i].set_ydata(Al)
            lines[3][i].set_ydata(kap)
            # lines[4][i].set_ydata(tot)
            # lines[5][i].set_ydata(S)

    fig.canvas.draw_idle()

# register the update function with each slider
# for s in range(1,nsliders):
#     Slider_C[s].on_changed(update)
Slider_C[1].on_changed(update)
Slider_C[2].on_changed(update)
Slider_C[3].on_changed(update)
Slider_C[4].on_changed(update)
Slider_C[5].on_changed(update)
Slider_C[6].on_changed(update)
Slider_C[7].on_changed(update)
Slider_C[8].on_changed(update)
Slider_C[9].on_changed(update)
Slider_C[10].on_changed(update)
Slider_C[11].on_changed(update)
Slider_C[12].on_changed(update)
Slider_C[13].on_changed(update)
Slider_C[14].on_changed(update)
Slider_C[15].on_changed(update)
Slider_C[16].on_changed(update)
Slider_C[17].on_changed(update)
Slider_C[18].on_changed(update)
Slider_C[19].on_changed(update)
Slider_C[20].on_changed(update)


# ------------------------------------------------
# Add buttons
# ------------------------------------------------

resetax = fig.add_axes(posreset)
buttonres = Button(resetax, 'Reset', hovercolor='0.975')

saveax = fig.add_axes(possave)
buttonsav = Button(saveax, 'Save Props', hovercolor='0.975')

exportax = fig.add_axes(posexport)
buttonexport = Button(exportax, 'Export Curves', hovercolor='0.975')


#reset the plot to the original props parameters
def reset(event):
    for i in range(1,nsliders):
        Slider_C[i].reset()
buttonres.on_clicked(reset)

#save the current props to a new props file next to old file
def saveprops(event):
    Tk().withdraw()
    pdir, pname = os.path.split(propsfile)
    newpropsfile = asksaveasfilename(filetypes = [('.csv','.csv')],title = 'Save new props file',
                                     initialdir = pdir, initialfile = pname)

    with open(newpropsfile, 'w',newline = '') as pfile:
        writer = csv.writer(pfile)
        writer.writerows(
            [['Comment',Com],
            ['C01',Slider_C[1].val],
            ['C02',Slider_C[2].val],
            ['C03',Slider_C[3].val],
            ['C04',Slider_C[4].val],
            ['C05',Slider_C[5].val],
            ['C06',Slider_C[6].val],
            ['C07',Slider_C[7].val],
            ['C08',Slider_C[8].val],
            ['C09',Slider_C[9].val],
            ['C10',Slider_C[10].val],
            ['C11',Slider_C[11].val],
            ['C12',Slider_C[12].val],
            ['C13',Slider_C[13].val],
            ['C14',Slider_C[14].val],
            ['C15',Slider_C[15].val],
            ['C16',Slider_C[16].val],
            ['C17',Slider_C[17].val],
            ['C18',Slider_C[18].val],
            ['C19',Slider_C[19].val],
            ['C20',Slider_C[20].val],
            ['Bulk Mod',bulk_mod],
            ['Shear Mod',shear_mod]
            ]
        )
    print('New props file written to : ', newpropsfile)
buttonsav.on_clicked(saveprops)

#Export the model curves for plotting/comparing in other programs
def exportcurves(event):
    Tk().withdraw()
    pdir, pname = os.path.split(propsfile)
    newcurvefile = asksaveasfilename(filetypes = [('.csv','.csv')],title = 'Save Model Curves As',
                                     initialdir = pdir, initialfile = 'Model_Curves.csv')

    with open(newcurvefile, 'w',newline = '') as pfile:
        writer = csv.writer(pfile)
        # for each data set write the data and the model
        header = []
        for i in range(sets):
            header.append('strain-'+test_cond['Name'][i])
            header.append('VMstress-'+test_cond['Name'][i])
        writer.writerow(header)

        for j in range(len(test_data['Model_E'][i])):       #only works because each line has same number of increments!
            nextline = []
            for i in range(sets):
                nextline.append(test_data['Model_E'][i][j])
                nextline.append(test_data['Model_VM'][i][j])
            writer.writerow(nextline)

    print('Model curves written to : ', newcurvefile)
buttonexport.on_clicked(exportcurves)


plt.show()