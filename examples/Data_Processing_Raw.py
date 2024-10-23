from tkinter import Tk     # from tkinter import Tk for Python 3.x
from tkinter.filedialog import askopenfilename
from tkinter.filedialog import askopenfilenames
from tkinter.filedialog import asksaveasfilename
import pickle
import csv
import os
import numpy as np
import plotly.graph_objects as go
import matplotlib.pyplot as plt






# Daniel Kenney
# 
# For data processing
# - Reading data in from Instron files
# - Formatting and storing all data uniformly
# - Build dictionary 
# 
# 
# 
# Values in each data set:


# - Specimen_Name
# - Temperature
# - Strain_Rate
# - Orientation
#   - width
#   - thickness
#   - height
#   - final strain
# - Exp_stress      (READ FROM INSTRON)
# - Exp_strain      (READ FROM INSTRON)
# - ENGR_stress     (Corrected for compliance, interpolated to a given strain step)
# - ENGR_strain     (Corrected for compliance, specified to a specific strain step)
# - TRUE_stress
# - TRUE_stress

# ---------------------------------------------------
# ------------ USER MODIFIABLE VARIABLES ------------
# ---------------------------------------------------

Correct_Compliance  = True      #Linearize first part of curve


Strain_inc          = 0.0005    # (mm/mm)

Target_raw_quant    = 2000      #Approximate target size to reduce very large raw data sets before storing them.
Elas_S_range        = [ [30,60],
                        [30,60],
                        [20,50],
                        [30,40] ] #For each temperature/condition ()




BAD_SPECS = [
    #Bad Tension Tests
    'RDT01',
    'RDT04',
    'RDT07',
    'RDT10',
    'RDT11',
    'RDT15',
    'RDT17',
    'RDT18',

    'TDT03',
    'TDT06',
    'TDT09',
    #Bad Compression Tests
    'TDC01',
    'TDC02',
    'TDC01',
    'TDC02',
    'TDC03',
    'TDC04',
    'TDC05',
    'TDC06',
    'TDC07',
    'TDC08',
    'TDC09',
    'TDC10',
    'TDC11',
    'TDC12',
    'TDC13',
    'TDC14',
    'TDC15',
    'TDC16',
    'TDC17',
    'TDC18',
    'TDC19',
    'TDC20',
    'TDC23',
    'TDC24',
    'TDC26',
    'TDC27',
    'RDC09',
    'RDC10',
    'RDC16'
    ]


# ---------------------------------------------------
# ------------ Get list of Instron files ------------
# ---------------------------------------------------
    #Ask which existing dictionary
Tk().withdraw() 
filename_dict = askopenfilename(filetypes = [('.pkl','.pkl')], title='Existing Dictionary File') 

if filename_dict:                                       # Read in existing file to dict
    with open(filename_dict, 'rb') as  old_dict:
        spec_dict = pickle.load(old_dict)
else:                                                   # No existing file, -> create empty dict
    spec_dict = {}



# As for csv file of all relevant specimens
Tk().withdraw()
spec_filez = askopenfilenames(filetypes = [('.csv','.csv')],title='Specimen Data')


# --------------------------------------------------------------------------------
# --------------------------------------------------------------------------------
# --------------------------------------------------------------------------------
# --------------------------------------------------------------------------------


# Loop through every specimen evaluated
# Specimen will overwrite old dict entries

for spec_file in spec_filez:

    # ---------------------------------------------------
    # ------------ Add Specimen data to dict ------------
    # ---------------------------------------------------
    # Adding:
    #   - Specimen_Name 
    #   - Temperature
    #   - Strain_Rate
    #   - Orientation
    #   - width
    #   - thickness
    #   - height
    #   - final strain
    #   - Strain (raw)
    #   - Stress (raw)

    with open(spec_file,'r') as table_csv:
        csvreader = csv.reader(table_csv)

        #default/initializing values
        comment     = 'Length units: (mm) \n' + \
                      'Force  units: (Kn) \n' + \
                      'Strain units: (mm/mm) \n' + \
                      'Stress units: (MPa) \n' + \
                      'Temp units: (C)'
        width       = 0.0
        thick       = 0.0
        orient      = 'None'
        temp        = 0.0
        height      = 0.0
        fin_strain  = 0.0
        strain_rate = 0.001
        strs_data_full = []
        strn_data_full = []
        strs_data      = []     #reasonably reduced from X_full
        strn_data      = []     #reasonably reduced from X_full


        read_data = False
        for row in csvreader:
            if len(row) == 0:   #just to skip over empty rows that don't have row[0]
                a=1
            elif read_data == False:

                if     ('specimen id' in row[0].lower()) or ('specimen name' in row[0].lower()):
                    Spec_name = row[2]

                    #reformat XD## into XDT## for tension
                    if len(Spec_name) == 4:
                        Spec_name = Spec_name[:2] + 'T' + Spec_name[-2:]


                elif 'temp' in row[0].lower():
                    if   'RT'    in   row[2]  : temp = 20.0
                    elif '300'   in   row[2]  : temp = 300.0
                    elif '200'   in   row[2]  : temp = 200.0
                    elif '100'   in   row[2]  : temp = 100.0
                    elif '20'    in   row[2]  : temp = 20.0




                elif  ('orientation' in row[0].lower()) or ('direction' in row[0].lower()):
                    if   'RD' in row[2] : orient = 'RD'
                    elif 'ND' in row[2] : orient = 'ND'
                    elif 'TD' in row[2] : orient = 'TD'

                    if   'DC' in row[2] : orient += 'C'
                    elif 'DS' in row[2] : orient += 'S'
                    else                : orient += 'T'

                elif 'thick' in row[0].lower():
                    thick = float(row[2])

                elif 'width' in row[0].lower():
                    width = float(row[2])

                elif 'height' in row[0].lower():
                    height = float(row[2])

                elif 'final strain' in row[0].lower():
                    fin_strain = float(row[2])

                elif 'strain rate' in row[0].lower():
                    strain_rate = float(row[2])

                #Flag to begin reading raw data
                elif row[0] == 'Time':
                    for i in range(len(row)):
                        header = row[i]
                        if ('stress' in header.lower()):
                            col_stress = i
                        if ('strain 1' in header.lower()) or ('strain (exten)' in header.lower()):
                            col_strain = i
            
                #skip line for units and trigger data reading
                elif row[0] == '(s)':
                    read_data = True

            else :      #Now read data
                if (len(strn_data_full)==0):
                    strn_data_full.append(float(row[col_strain])*0.01)  # Convert (%) -> (mm/mm)
                    strs_data_full.append(float(row[col_stress]))

                elif (strn_data_full[-1] <= float(row[col_strain])*0.01):             # only add data if strain is increasing.(sorts issues with messy extensometer removal)
                    strn_data_full.append(float(row[col_strain])*0.01)  # Convert (%) -> (mm/mm)
                    strs_data_full.append(float(row[col_stress]))

    #Now all the data is stored nicely in our variables

    # Count and proportionally reduce the quantity of stress-strain data
    red = len(strs_data_full) // Target_raw_quant    # how many times larger data is than target
    print(Spec_name)
    # print(len(strs_data_full))

    j = red   #counter
    for i in range(len(strs_data_full)):
        if j == red : 
            strs_data.append(strs_data_full[i])
            strn_data.append(strn_data_full[i])
        else:
            j += 1

    if ('DS' in orient) or ('DC' in orient):  #Correction for extensometer measurements on compression platens
        for i in range(len(strn_data)):
            strn_data[i] = strn_data[i]*(25.4/height)

    #Store all parameters in a new specimen dictionary
    new_spec = {
        'Specimen_Name' : Spec_name,
        'Temperature'   : temp,
        'Orientation'   : orient,
        'Thick'         : thick,
        'Width'         : width,
        'Height'        : height,
        'Comment'       : comment,
        'EXP_stress'    : strs_data,
        'EXP_strain'    : strn_data,
        'Fin_strain'    : fin_strain,
        'Strain_rate'   : strain_rate
    }




    # ---------------------------------------------------
    # --------- Correct shifting and interpolate --------
    # ---------------------------------------------------
    # Adding:
    #   - ENGR_strain
    #   - ENGR_stress

    cor_strn    = []    # holding value for corrected stress
    cor_strs    = []    # holding value for corrected strain


    # -----------------------------------------------------------------------------


    if   temp == 20 : s_l, s_u = Elas_S_range[0]
    elif temp == 100: s_l, s_u = Elas_S_range[1]
    elif temp == 200: s_l, s_u = Elas_S_range[2]
    elif temp == 300: s_l, s_u = Elas_S_range[3]

    #interpolating to get lower strain from lower stress
    i = 0
    print('current spec: ', new_spec['Specimen_Name'])
    while s_l > strs_data[i]:
        i += 1 
    S_1 = strs_data[i]
    S_2 = strs_data[i+1]
    E_1 = strn_data[i]
    E_2 = strn_data[i+1]
    e_l =  E_1 + (s_l - S_1)*(E_2-E_1)/(S_2-S_1)

    #interpolating to get upper strain from upper stress
    i = 0
    while s_u > strs_data[i]:
        i += 1 
    S_1 = strs_data[i]
    S_2 = strs_data[i+1]
    E_1 = strn_data[i]
    E_2 = strn_data[i+1]
    e_u = E_1 + (s_u - S_1)*(E_2-E_1)/(S_2-S_1)
    # print('lower strain: ',e_l, '   upper strain: ',e_u)

    # Calculating strain correction
    E_Mod   = (s_u - s_l) / (e_u - e_l)
    s_mid   = (s_u + s_l) * 0.5
    e_mid   = (e_u + e_l) * 0.5
    shift   = e_mid - s_mid/E_Mod
    # print(' specimen: ',new_spec['Specimen_Name'],'  Temp: ',new_spec['Temperature'], '\n  S_l, S_u: ',s_l,s_u, '  Emod: ',E_Mod,'  Shift: ',shift)


    Elastic = True
    for i in range(len(strs_data)):
        if strs_data[i] > s_u :    Elastic = False        

        if Elastic == True:                 # elastic linear region:
            cor_strs.append(strs_data[i])
            cor_strn.append(strs_data[i]/E_Mod)

        if Elastic == False:                # shifted plastic region:
            cor_strs.append(strs_data[i])
            cor_strn.append(strn_data[i] - shift)
    # print('len cor:  ', len(cor_strs),', ', len(cor_strn))
    # -----------------------------------------------------------------------------
    # Removing the last part of data which corresponds to extensometer removal and failure
    max_strain = max(cor_strn) - 0.001
    # for i in range(len())

    # -----------------------------------------------------------------------------
    #Now interpolating between data points to normlaize strain

    engr_strn   = [0.0]    # corrected and incrementalized 
    engr_strs   = [0.0]    # corrected and incrementalized

    max_strain = max(cor_strn) - 0.001
    print('max strain:  ', max_strain)

    j = 0   #incrementing for faster looping
    while (engr_strn[-1] < max_strain):
        engr_strn.append(engr_strn[-1] + Strain_inc)

        #interpolate for the engr_stress
        stress_interp = np.interp(engr_strn[-1],cor_strn,cor_strs)
        engr_strs.append(stress_interp)

    # print('size engr_strs_temp:    ', len(engr_strs))
    new_spec.update({
        # 'ENGR_strain'   : cor_strn,
        # 'ENGR_stress'   : cor_strs
        'ENGR_strain'   : engr_strn,
        'ENGR_stress'   : engr_strs
        })

    # ---------------------------------------------------
    # ----------- Calculate True Stress/Strain ----------
    # ---------------------------------------------------
    # Adding:
    #   - TRUE_strain
    #   - TRUE_stress

    # "_temp" for strain that is in irrational increments
    true_strn_temp = []
    true_strs_temp = []
    if 'dt' in new_spec['Specimen_Name'].lower():       #tension (XDT##)
        for i in range (len(engr_strn)):
            true_strn_temp.append(np.log(1.0+engr_strn[i]))
            true_strs_temp.append(engr_strs[i]*(1.0+engr_strn[i]))

    else:                                               #compression (XDC##) or (XDS##)
        for i in range(len(engr_strn)):
            true_strn_temp.append(-np.log(1.0-engr_strn[i]))
            true_strs_temp.append(engr_strs[i]*(1.0-engr_strn[i]))
    # print(new_spec['Specimen_Name'])
    # print('size true_strn_temp:   ',len(true_strn_temp))
    # print('size true_strs_temp:   ',len(true_strs_temp))

    # Interpolate so that true strain is in clean increments
    true_strn   = [0.0]    # incrementalized 
    true_strs   = [0.0]    # incrementalized
    max_strain = max(true_strn_temp)

    while (true_strn[-1] < max_strain ):
        true_strn.append(true_strn[-1] + Strain_inc)

        #interpolate for the true_stress
        stress_interp = np.interp(true_strn[-1],true_strn_temp,true_strs_temp)
        true_strs.append(stress_interp)
    # print('size true_strn:        ',len(true_strn))
    # print('size true_strs:        ',len(true_strs))


    new_spec.update({
        'TRUE_strain'   : true_strn,
        'TRUE_stress'   : true_strs
        })



    # ---------------------------------------------------
    # -------- store specimen to full dictionary --------
    # ---------------------------------------------------

    #store this new specimen dictionary into the comprehensive dictionary

    #Condition for what samples should be added to this set:
    if 'NDS' or 'TDS' in new_spec['Orientation']:
        if (strain_rate == 0.001) or (strain_rate == 0.01) or (strain_rate == 0.1):
            spec_dict.update({Spec_name : new_spec})
        else: print( new_spec['Specimen_Name'],'  - exculded due to strain rate')
    else: print( new_spec['Specimen_Name'],'  - exculded due to orientation')



# ---------------------------------------------------
# ------- Save full dictionary to pickle file -------
# ---------------------------------------------------

if filename_dict:       # Default to save in the previous location/name of the existing file
    pdir, pname = os.path.split(filename_dict)
    newfile = asksaveasfilename(filetypes = [('.pkl','.pkl')], title = 'New Dictionary File',
                      initialdir = pdir, initialfile = pname)

else:
    newfile = asksaveasfilename(filetypes = [('.pkl','.pkl')], title = 'New Dictionary File')

if not newfile.endswith('.pkl'): newfile = newfile+'.pkl'
with open(newfile, 'wb') as file:
    pickle.dump(spec_dict,file)




# ---------------------------------------------------
# ----- Plot raw data and corrected data (check) ----
# ---------------------------------------------------

MPL = True
Plotly = False

if Plotly:
    fig1 = go.Figure()
    # fig2 = go.Figure()
    # fig3 = go.Figure()
if MPL:
    fig,ax = plt.subplots(figsize=(6,4))

for key, spec in spec_dict.items():
    temp    = spec['Temperature']
    orient  = spec['Orientation']
    name    = spec['Specimen_Name']
    erate   = spec['Strain_rate']
    rstrain = spec['EXP_strain']
    rstress = spec['EXP_stress']
    estrain = spec['ENGR_strain']
    estress = spec['ENGR_stress']
    tstrain = spec['TRUE_strain']
    tstress = spec['TRUE_stress']


    # Line Formatting based on Specimen conditions
    if   temp == 20     : col = 'darkblue'
    elif temp == 100    : col = 'darkorange'
    elif temp == 200    : col = 'orangered'
    elif temp == 300    : col = 'darkred'
    else                : print('ERROR READING TEMP')

    if   'RD' in orient : ls = 'solid'
    elif 'TD' in orient : ls = 'dashed'
    elif 'ND' in orient : ls = 'dotted'

    if   erate == 0.001 : marker = 'o'
    elif erate == 0.05  : marker = 's'
    elif erate == 1.0   : marker = '^'


    if (name not in BAD_SPECS):
        iden = name+'-'+str(erate)+'-'+str(temp)
        if Plotly:
            fig1.add_trace(go.Scatter(x=rstrain,y=rstress,mode = 'lines', name = iden, line=dict(color=col,dash=ls))) 
            # fig2.add_trace(go.Scatter(x=tstrain,y=tstress,mode = 'lines', name = iden, line=dict(color=col))) 
            # fig3.add_trace(go.Scatter(x=estrain,y=estress,mode = 'lines', name = iden, line=dict(color=col))) 

            fig1.update_layout(title=dict(text='Raw Data'))
            # fig2.update_layout(title=dict(text='TRUE'))
            # fig3.update_layout(title=dict(text='ENGR'))

        if MPL:
            #Plot line and add marker to end of line to distinguish strain rate
            plotx = rstrain
            ploty = rstress
            ax.plot(plotx,ploty,label=None,linestyle=ls,color = col)
            ax.plot(plotx[-1],ploty[-1], label = iden, linestyle = ls, color = col, marker = marker)
    else:
        print('WARNING: Specimen \"', name,'\" is excluded for being in list BAD_SPECS.')

if Plotly:
    # fig1.show()
    # fig2.show()
    # fig3.show()

    # As for csv file of all relevant specimens
    Tk().withdraw()
    save_file = asksaveasfilename(filetypes = [('.html','.html')],title='Save Plotly Figure')
    if not save_file.endswith('.html'): save_file = save_file+'.html'

    fig1.write_html(save_file)

if MPL:
    plt.rcParams['font.family'] = 'Times New Roman'  # only formats legend?
    plt.rcParams['font.size'] = 11  # Adjust font size 
    
    tfont = {'fontname':'Times New Roman'}
    afont = {'fontname':'Times New Roman'}

    ax.set_title('Stress-Strain AZ31',tfont, fontsize=16)
    ax.set_xlabel('Strain (mm/mm)'   ,afont, fontsize=14)
    ax.set_ylabel('Stress (MPa)'     ,afont, fontsize=14)
    ax.legend(loc='best', fontsize=8)  # Add a legend


    # plt.savefig('official_plot.eps', format='eps', dpi=300, bbox_inches='tight')
    plt.show()