import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider, Button
from tkinter import Tk     
from tkinter.filedialog import askopenfilenames
from tkinter.filedialog import askopenfilename
from tkinter.filedialog import asksaveasfilename
import csv
import os

"""
 Daniel Kenney
 Summer 2023
 --------------------------------
- User editable variable 
- plotting parameters and layouts

- define JC-stress function

- read in props and data files
    - store initial parameters

- setup sliders and update plotting
- setup save and reset buttons
"""

# ----------------------------------------
# User input variables
# ----------------------------------------
de          = 0.01                              # strain increment
# Ask_Files   = False                             # ask vs auto find files
Ask_Files   = True
colors      = ['b','c','g','y','r','m','k']
colors      = colors + colors

# Manually set props/data paths: 
Autofile_props  = 'path/to/Data_4340_JC/Props_4340_2.csv'
Autofile_datas  = [
    'path/to/Data_4340_JC/Data_Tension_e002_T295.csv',
    'path/to/Data_4340_JC/Data_Tension_e570_T295.csv',
    'path/to/Data_4340_JC/Data_Tension_e604_T500.csv',
    'path/to/Data_4340_JC/Data_Tension_e650_T730.csv'
    ]

# ----------------------------------------
# Slider settings & formatting
# ----------------------------------------
#Ranges for parameters, centered on initial parameters
A_amp = 300.0
B_amp = 400.0
n_amp = 1.0
C_amp = 0.1
m_amp = 0.5
plotlayout = 1

if plotlayout == 1:          #sliders on left side
    plot_bot = 0.15
    plot_left = 0.5
    posA    = [0.05, 0.9, 0.35, 0.03]
    posB    = [0.05, 0.8, 0.35, 0.03]
    posn    = [0.05, 0.7, 0.35, 0.03]
    posC    = [0.05, 0.6, 0.35, 0.03]
    posm    = [0.05, 0.5, 0.35, 0.03]
    posreset= [0.10, 0.3, 0.1, 0.05]
    possave = [0.25, 0.3, 0.1, 0.05]
else:                       #default to sliders below plot
    plot_bot = 0.5
    plot_left = 0.1
    posA    = [0.1, 0.3, 0.8, 0.03]
    posB    = [0.1, 0.25, 0.8, 0.03]
    posn    = [0.1, 0.2, 0.8, 0.03]
    posC    = [0.1, 0.15, 0.8, 0.03]
    posm    = [0.1, 0.1, 0.8, 0.03]
    posreset= [0.6, 0.025, 0.15, 0.04]
    possave = [0.8, 0.025, 0.15, 0.04]

# ------------------------------------------------
# ------------------------------------------------
# ------------------------------------------------
# ------------------------------------------------

# JC stress function
def stress_JC(eps, epsr, T, A, B, n, C, m):
    # Using Tr, Tm, and er0
    estar = epsr / er0
    Tstar = (T-Tr)/(Tm-Tr)
    s = (A+B*eps**(n))*(1+C*np.log(estar))*(1-Tstar**(m))
    return s

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
else:
    propsfile = Autofile_props
    flz = Autofile_datas

# ------------------------------------------------
# Assign props values:
with open(propsfile,'r') as pfile:
    csvreader = csv.reader(pfile)
    for row in csvreader:
        if row[0]   == 'Tr': Tr = float(row[1])     # Does not change!
        elif row[0] == 'Tm': Tm = float(row[1])     # Does not change!
        elif row[0] == 'er0':er0= float(row[1])     # Does not change!
        elif row[0] == 'A':  A0 = float(row[1])
        elif row[0] == 'B':  B0 = float(row[1])
        elif row[0] == 'n':  n0 = float(row[1])
        elif row[0] == 'C':  C0 = float(row[1])
        elif row[0] == 'm':  m0 = float(row[1])
        elif row[0] == 'Comment': Com = row[1]
        else: print('WARNING: extra/incorrect row in props file.')
    # props = [A, B ,n ,C ,m , Tr, Tm, er0, Com]



# ------------------------------------------------
# Store stress-strain data and corresponding test conditions (temp and strain rate)
sets = len(flz)
test_cond   = []         # Used to store testing conditions (temp, strain rate)
test_data   = []         # Used to store data

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
            strs.append(float(col['Stress']))
            if j < 1:
                er.append(float(col['Strain Rate']))
                T.append(float(col['Temperature']))
                name.append(col['Name'])
                j += 1
        #check data entered
        if len(strn) != len(strs):
            print('ERROR!! data from  \'', file , '\'  has bad stress-strain data lengths')

        #store the stress-strain data
        test_cond.append([float(er[0]),float(T[0]),name[0]])
        test_data.append([[strn,strs],[],[]])
# -----------------------------------------------




# -----------------------------------------------------
# Calculate the model's initial stress-strain curve
# -----------------------------------------------------

# FORMATTING: test_data[i][[e_data,s_data] , [e_model,s_model] , [e_err, s_err]]
# For each set, calculate the model curve and error
for i in range(sets):
    emax = max(test_data[i][0][0])
    e = np.linspace(0,emax,int(emax/de))
    s = np.zeros_like(e)
    e_data = test_data[i][0][0]
    s_data = test_data[i][0][1]
    s_err  = np.zeros_like(s_data)
    # Calcualte the model stress-strai data
    for j in range(len(e)):
        s[j] = stress_JC(e[j], test_cond[i][0], test_cond[i][1] ,
                         A0, B0, n0, C0, m0)

    test_data[i][1] = [e,s]             #Store model stress/strain data

    # Calculate the error between model and data
    for j in range(len(e_data)):
        s_model  = np.interp(e_data[j],e,s)  #get the corresponding model stress for the given strain
        s_err[j] = s_data[j] - s_model

    test_data[i][2] = [e_data,s_err]    #Store error 




# -----------------------------------------------------
# GUI Plot Definition / formatting
# -----------------------------------------------------

# Create the axes and the lines that we will manipulate

fig, ax = plt.subplots()
# lines[0] = data
# lines[1] = model (to be updated)
lines = [[],[]]
for i in range(sets):
    lobj1, = ax.plot(test_data[i][0][0], test_data[i][0][1], 'o', color = colors[i])  #, label='Data - '+test_cond[i][2])
    lobj2, = ax.plot(test_data[i][1][0], test_data[i][1][1], color = colors[i] , label='Model - '+test_cond[i][2])
    lines[0].append(lobj1)
    lines[1].append(lobj2)

ax.set_xlabel('True Strain (mm/mm)')
ax.set_ylabel('True Stress (MPa)')
ax.legend()
ax.set_ylim(bottom = 0.0)
ax.set_xlim(left=0.0)
fig.subplots_adjust(bottom=plot_bot ,left = plot_left)




# ------------------------------------------------
# GUI Slider Assignments
# ------------------------------------------------

ax_A = fig.add_axes(posA)
A_slider = Slider(
    ax=ax_A,
    label='A:',
    valmin=A0 - A_amp,
    valmax=A0 + A_amp,
    valinit=A0,
)
ax_B = fig.add_axes(posB)
B_slider = Slider(
    ax=ax_B,
    label="B:",
    valmin= B0 - B_amp,
    valmax= B0 + B_amp,
    valinit= B0,
)
ax_n = fig.add_axes(posn)
n_slider = Slider(
    ax=ax_n,
    label="n:",
    valmin= n0 - n_amp,
    valmax= n0 + n_amp,
    valinit= n0,
)
ax_C = fig.add_axes(posC)
C_slider = Slider(
    ax=ax_C,
    label="C:",
    valmin= C0 - C_amp,
    valmax= C0 + C_amp,
    valinit= C0,
)
ax_m = fig.add_axes(posm)
m_slider = Slider(
    ax=ax_m,
    label="m:",
    valmin= m0 - m_amp,
    valmax= m0 + m_amp,
    valinit= m0,
)

# ------------------------------------------------
# Slider values to update plot automatically

# The function to be called anytime a slider's value changes
def update(val):
    for i in range(sets):
        er = test_cond[i][0]
        T  = test_cond[i][1]
        em = test_data[i][1][0]
        s = np.zeros_like(em)
        for j, e in enumerate(em):
            # print('individual strain val: ',test_data[i][1][0][j])
            s[j] = stress_JC(e, er ,T , A_slider.val, B_slider.val,
                             n_slider.val,C_slider.val,m_slider.val)
        lines[1][i].set_ydata(s)
    fig.canvas.draw_idle()

# register the update function with each slider
A_slider.on_changed(update)
B_slider.on_changed(update)
n_slider.on_changed(update)
C_slider.on_changed(update)
m_slider.on_changed(update)


# Create a `matplotlib.widgets.Button` to reset the sliders to initial values.


# ------------------------------------------------
# Add buttons for 'reset' and 'save props'
# ------------------------------------------------
resetax = fig.add_axes(posreset)
buttonres = Button(resetax, 'Reset', hovercolor='0.975')

saveax = fig.add_axes(possave)
buttonsav = Button(saveax, 'Save Props', hovercolor='0.975')

#reset the plot to the original props parameters
def reset(event):
    A_slider.reset()
    B_slider.reset()
    n_slider.reset()
    C_slider.reset()
    m_slider.reset()
buttonres.on_clicked(reset)

#save the current props to a new props file next to old file
def saveprops(event):
    Tk().withdraw()
    newpropsfile = asksaveasfilename(filetypes = [('.csv','.csv')],title = 'Save new props file')
    
    with open(newpropsfile, 'w',newline = '') as pfile:
        writer = csv.writer(pfile)
        writer.writerows(
            [['Comment',Com],
            ['A',A_slider.val],
            ['B',B_slider.val],
            ['n',n_slider.val],
            ['C',C_slider.val],
            ['m',m_slider.val],
            ['Tr',Tr],
            ['Tm',Tm],
            ['er0',er0]]
        )
    print('New props file written to : ', newpropsfile)
buttonsav.on_clicked(saveprops)

plt.show()