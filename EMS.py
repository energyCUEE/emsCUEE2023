from mip import *
import datetime
import pandas as pd
import numpy as np
from matplotlib.dates import DateFormatter
import matplotlib.pyplot as plt

def getBuySellrate(Resolution,Horizon,TOU_CHOICE,start_time=datetime.timedelta(minutes=0)) :
    #Resolution  (min)
    #Horizon  (min)
    #TOU_CHOICE 'THcurrent' or 'smart'
    #start_time_index timedelta obj [0,24 - Resolution]
    if Horizon % Resolution != 0 :
        raise Exception('k must be integer (Horizon / Resolution)')
    k = int(Horizon/Resolution)
    start_date = datetime.datetime(2000,1,1) + start_time # just a dummy day for starting point

    TOU = pd.DataFrame([start_date + i*datetime.timedelta(minutes=Resolution)
                         for i in range(k)],columns=['time'])
    # 5.8 during 9.00 - 23.00 , 2.8 otherwise
    if TOU_CHOICE == 'THcurrent' :
        TOU.loc[:,'sell'] =  2
        TOU.loc[:,'buy'] =  2.6
        TOU.loc[(TOU['time'].dt.hour >= 9 ) & 
                (TOU['time'].dt.hour < 23 ),'buy'] = 5.8
        TOU.loc[(TOU['time'].dt.hour == 23 ) &  
                (TOU['time'].dt.minute == 0 ),'buy'] = 5.8
    #  buy_rate = [0-10:00)     2THB, 
    #                 [10:00-14:00] 3THB,
    #                (14:00-18:00) 5THB,
    #                 [18:00-22:00] 7THB,
    #                (22:00-24:00) 2THB
    #    sell_rate = [18:00-22:00] 2.5THB and 2THB all other times        
    elif TOU_CHOICE == 'smart' :
        TOU.loc[:,'buy'] =  2
        TOU.loc[(TOU['time'].dt.hour >= 10 ) & 
                (TOU['time'].dt.hour < 14 ),'buy'] = 3
        TOU.loc[(TOU['time'].dt.hour == 14 ) &  
                (TOU['time'].dt.minute == 0 ),'buy'] = 3
        TOU.loc[(TOU['time'].dt.hour >= 14 ) & 
                (TOU['time'].dt.hour < 18 ),'buy'] = 5
        TOU.loc[(TOU['time'].dt.hour == 18 ) &  
                (TOU['time'].dt.minute == 0 ),'buy'] = 5
        TOU.loc[(TOU['time'].dt.hour >= 18 ) & 
                (TOU['time'].dt.hour < 22 ),'buy'] = 7
        TOU.loc[(TOU['time'].dt.hour == 22 ) &  
                (TOU['time'].dt.minute == 0 ),'buy'] = 7
        
        TOU.loc[:,'sell'] =  2
        TOU.loc[(TOU['time'].dt.hour >= 18 ) & 
                (TOU['time'].dt.hour < 22 ),'sell'] = 2.5
        TOU.loc[(TOU['time'].dt.hour == 22 ) &  
                (TOU['time'].dt.minute == 0 ),'sell'] = 2.5
    
    
    return TOU

def getSchedule(start,end,Resolution) :
    # return schedule w/ 1 means on 0 means off
    span = pd.date_range(start,end,freq=str(Resolution) +'min' ) #datetime in [start,end] 
    schedule = pd.DataFrame({'datetime':span[:-1],'status':0})
    schedule.loc[(schedule['datetime'].dt.hour >= 12) & (schedule['datetime'].dt.hour < 18) ,'status'] = 1
    schedule.loc[(schedule['datetime'].dt.hour == 18) & (schedule['datetime'].dt.minute == 0)] = 1
    return schedule


def EMS_1_opt(PARAM,energyfromgrid=0,energycost=0,profit=0,multibatt=1,chargebatt=0,smoothcharge=0):
    
    # input Resolution (min)
    # input Horizon (min)
    if energyfromgrid < 0 or energycost < 0 or profit < 0 or multibatt < 0 or chargebatt < 0 or smoothcharge < 0 :
        raise Exception('Weight must > 0')
    elif PARAM['Horizon'] % PARAM['Resolution'] != 0 :
        raise Exception('variables length must be integer')
    elif energyfromgrid*energycost + profit*energycost + energyfromgrid*profit != 0 :
        raise Exception('You can only choose one of the three energy objectives')
    elif multibatt > 0 and PARAM['battery']['num_batt'] == 1 :
        raise Exception('The number of battery must >= 2 to use this objective')
    #------------ change unit
    fs = 1/PARAM['Resolution'] #sampling freq(1/min)
    h = PARAM['Horizon'] #optimization horizon(min)
    k = int(h*fs) #length of variable
    Resolution_HR = PARAM['Resolution'] /60 # resolution in Hr
    
    #------------------------------- variables -----------------------
    model = Model(solver_name=CBC)
    Pnet = model.add_var_tensor((k,),name = 'Pnet',lb = -float('inf'),ub = float('inf'),var_type = CONTINUOUS)
    
    
    Pdchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'Pdchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    xdchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'xdchg',lb = 0,ub = 1,var_type = INTEGER)
    Pchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'Pchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    xchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'xchg',lb = 0,ub = 1,var_type = INTEGER)
    soc =       model.add_var_tensor((k+1,PARAM['battery']['num_batt']),name = 'soc',lb = PARAM['battery']['min'][0],ub = PARAM['battery']['max'][0],var_type = CONTINUOUS)
    
    
    if energyfromgrid > 0 :
        u1 =     model.add_var_tensor((k,),name = 'u1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        obj_fcn = energyfromgrid*xsum(u1)
        model += Resolution_HR*(-np.eye(k) @ Pnet) <= u1
    if energycost > 0 :
        u1 =     model.add_var_tensor((k,),name = 'u1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        obj_fcn = energycost*xsum(u1) 
        model += (-Resolution_HR*PARAM['Buy_rate']*np.eye(k) @ Pnet) <= u1
    if profit > 0 :
        u1 =     model.add_var_tensor((k,),name = 'u1',lb = -float('inf'),ub = float('inf'),var_type = CONTINUOUS)
        obj_fcn = profit*xsum(u1)
        model += (-Resolution_HR*PARAM['Buy_rate']*np.eye(k) @ Pnet) <= u1
        model += (-Resolution_HR*PARAM['Sell_rate']*np.eye(k) @ Pnet) <= u1
    if multibatt > 0 :
        if PARAM['battery']['num_batt'] == 2: #just use soc1 - soc2
            s1 =     model.add_var_tensor((k,),name = 's1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
            obj_fcn += multibatt*xsum(s1)
            # force soc
            model += soc[1:,0] - soc[1:,1] <= s1
            model += -s1 <= soc[1:,0] - soc[1:,1]
        elif PARAM['battery']['num_batt'] >= 3: #use central variable
            s1 =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 's1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
            central_soc = model.add_var_tensor((k,),name = 'central_soc',lb = 0,ub = float('inf'),var_type = CONTINUOUS)  
            
            for i in range(PARAM['battery']['num_batt']) :
                obj_fcn += multibatt*xsum(s1[:,i])
                model += central_soc - soc[1:,i] <= s1[:,i]
                model += -s1[:,i] <= central_soc - soc[1:,i]
        
    if chargebatt > 0 :
        for i in range(PARAM['battery']['num_batt']) :    
            obj_fcn += chargebatt*xsum((PARAM['battery']['max'][i] - soc[:,i])/(PARAM['battery']['max'][i] - PARAM['battery']['min'][i]))
    
    if smoothcharge > 0 :
        upper_bound_Pchg = model.add_var_tensor((k-1,PARAM['battery']['num_batt']),name = 'upper_bound_Pchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        upper_bound_Pdchg = model.add_var_tensor((k-1,PARAM['battery']['num_batt']),name = 'upper_bound_Pdchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        for i in range(PARAM['battery']['num_batt']) :
            obj_fcn += smoothcharge*( xsum(upper_bound_Pchg[:,i]) + xsum(upper_bound_Pdchg[:,i]) )
            model += Pchg[1:,i] - Pchg[:-1,i] <= upper_bound_Pchg[:,i]
            model += -upper_bound_Pchg[:,i] <= Pchg[1:,i] - Pchg[:-1,i]
            model += Pdchg[1:,i] - Pdchg[:-1,i] <= upper_bound_Pdchg[:,i]
            model += -upper_bound_Pdchg[:,i] <= Pdchg[1:,i] - Pdchg[:-1,i] 
    
    model.objective = minimize(obj_fcn)
    #------------------------------ constraint ----------------------  
   
    # battery constraint
    model += Pchg <= xchg*PARAM['battery']['charge_rate']
    model += Pdchg <= xdchg*PARAM['battery']['discharge_rate']
    model += xchg + xdchg <= 1
    model += 0 <= xchg + xdchg
    # Pnet constraint
    Pnet_string = "model += Pnet == PARAM['PV'] - PARAM['PL']"
    for i in range(PARAM['battery']['num_batt']) :
        Pnet_string += f" + Pdchg[:,{i}] - Pchg[:,{i}]"
    exec(Pnet_string) # assign Pnet constraint
    
    

    # battery dynamic constraint
    model += soc[0,:] == PARAM['battery']['initial']
    for i in range(PARAM['battery']['num_batt']) :
        model += soc[1:k+1,i] == (soc[0:k,i] 
        + (PARAM['battery']['charge_effiency'][i]*100*Resolution_HR / PARAM['battery']['actual_capacity'][i])*Pchg[0:k,i]
        - (Resolution_HR*100/(PARAM['battery']['discharge_effiency'][i]*PARAM['battery']['actual_capacity'][i]))*Pdchg[0:k,i])
    
    
    #model.optimize(max_seconds_same_incumbent=2*60) # if feasible solution is found and not improve for 2 mins, terminates with that solution
    model.threads = -1 # use all available CPU threads
    model.preprocess = 1 # enable preprocess
    model.optimize()
    #----------------------------- solution ------------------
       
    sol = {}
    sol['datetime'] = pd.date_range(PARAM['Start_date'],PARAM['Start_date'] + datetime.timedelta(minutes=PARAM['Horizon']),freq=str(PARAM['Resolution']) +'min' )[:-1]
    # PARAMETER
    sol['PARAM_PV'] = PARAM['PV']
    sol['PARAM_PL'] = PARAM['PL']
    if energycost > 0 or profit > 0 :
        sol['Buy_rate'] = PARAM['Buy_rate']
        sol['Sell_rate'] = PARAM['Sell_rate']
    # VARIABLE
    sol['Pnet'] = [e.x for e in model.vars if  e.name[:4] == 'Pnet']
    sol['u1'] = [e.x for e in model.vars if  e.name[:2] == 'u1']
    for i in range(PARAM['battery']['num_batt']) :
        if PARAM['battery']['num_batt'] == 1 :
            sol['Pchg_0'] = [e.x for e in model.vars if  e.name[:4] == 'Pchg']
            sol['Pdchg_0'] = [e.x for e in model.vars if e.name[:5] == 'Pdchg' ]
            sol['xchg_0'] = [e.x for e in model.vars if e.name[:4] == 'xchg']
            sol['xdchg_0'] = [e.x for e in model.vars if e.name[:5] == 'xdchg']
            sol['soc_0'] = [e.x for e in model.vars if e.name[:3] == 'soc'][:-1] 
              
        elif PARAM['battery']['num_batt'] >= 2 :
            if multibatt > 0:
                if PARAM['battery']['num_batt'] == 2 :
                    sol[f's1'] = [e.x for e in model.vars if  e.name[:2] == 's1']
                elif PARAM['battery']['num_batt'] >= 3 :    
                    sol[f's1_{i}'] = [e.x for e in model.vars if  e.name[:2] == 's1' and e.name[-1] == str(i)]
            
            sol[f'Pchg_{i}'] = [e.x for e in model.vars if  e.name[:4] == 'Pchg' and e.name[-1] == str(i)]
            sol[f'Pdchg_{i}'] = [e.x for e in model.vars if e.name[:5] == 'Pdchg' and e.name[-1] == str(i)]
            sol[f'xchg_{i}'] = [e.x for e in model.vars if e.name[:4] == 'xchg' and e.name[-1] == str(i)]
            sol[f'xdchg_{i}'] = [e.x for e in model.vars if e.name[:5] == 'xdchg' and e.name[-1] == str(i)]
            sol[f'soc_{i}'] = [e.x for e in model.vars if e.name[:3] == 'soc' and e.name[-1] == str(i)][:-1]        
            if smoothcharge > 0 :
                sol[f'upper_bound_Pchg_{i}'] = [e.x for e in model.vars if  e.name[:16] == 'upper_bound_Pchg' and e.name[-1] == str(i)] + [0]
                sol[f'upper_bound_Pdchg_{i}'] = [e.x for e in model.vars if  e.name[:17] == 'upper_bound_Pdchg' and e.name[-1] ==  str(i)] + [0]
        
    return pd.DataFrame(sol)

 


def EMS_rolling(PARAM,minute,energyfromgrid=0,energycost=0,profit=0,multibatt=1,chargebatt=0,smoothcharge=0,Pnet_diff=1,Pchg_diff=1,Pdchg_diff=1) :
    
    # input Resolution (min)
    # input Horizon (min)
    # minute -> minute of HA schedule starting time (in RT this will be replace by clock)
    
    #------------ change unit
    fs = 1/PARAM['Resolution'] #sampling freq(1/min)
    h = PARAM['Horizon'] #optimization horizon(min)
    k = int(h*fs) #length of variable
    Resolution_HR = PARAM['Resolution'] /60 # resolution in Hr
    #------------------------------- variables -----------------------
    model = Model(solver_name=CBC)
    Pnet = model.add_var_tensor((k,),name = 'Pnet',lb = -float('inf'),ub = float('inf'),var_type = CONTINUOUS)
    
    Pdchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'Pdchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    xdchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'xdchg',lb = 0,ub = 1,var_type = INTEGER)
    Pchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'Pchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    xchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'xchg',lb = 0,ub = 1,var_type = INTEGER)
    soc =       model.add_var_tensor((k+1,PARAM['battery']['num_batt']),name = 'soc',lb = PARAM['battery']['min'][0],ub = PARAM['battery']['max'][0],var_type = CONTINUOUS)
    #upper bound for Power diff between HA and DA solution
    uPnet = model.add_var_tensor((k,),name = 'uPnet',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    uPchg = model.add_var_tensor((k,),name = 'uPchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    uPdchg =  model.add_var_tensor((k,),name = 'uPdchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    obj_fcn = Pnet_diff*xsum(uPnet) + Pchg_diff*xsum(uPchg) + Pdchg_diff*xsum(uPdchg)
    if energyfromgrid > 0 :
        u1 =     model.add_var_tensor((k,),name = 'u1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        obj_fcn += energyfromgrid*xsum(u1)
        model +=  Resolution_HR*(-np.eye(k) @ Pnet) <= u1
    if energycost > 0 :
        u1 =     model.add_var_tensor((k,),name = 'u1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        obj_fcn += energycost*xsum(u1) 
        model += (-Resolution_HR*PARAM['Buy_rate']*np.eye(k) @ Pnet) <= u1
    if profit > 0 :
        u1 =     model.add_var_tensor((k,),name = 'u1',lb = -float('inf'),ub = float('inf'),var_type = CONTINUOUS)
        obj_fcn += profit*xsum(u1)
        model += (-Resolution_HR*PARAM['Buy_rate']*np.eye(k) @ Pnet) <= u1
        model += (-Resolution_HR*PARAM['Sell_rate']*np.eye(k) @ Pnet) <= u1
    if multibatt > 0 :
        if PARAM['battery']['num_batt'] == 2: #just use soc1 - soc2
            s1 =     model.add_var_tensor((k,),name = 's1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
            obj_fcn += multibatt*xsum(s1)
            # force soc
            model += soc[1:,0] - soc[1:,1] <= s1
            model += -s1 <= soc[1:,0] - soc[1:,1]
        elif PARAM['battery']['num_batt'] >= 3: #use central variable
            s1 =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 's1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
            central_soc = model.add_var_tensor((k,),name = 'central_soc',lb = 0,ub = float('inf'),var_type = CONTINUOUS)  
            
            for i in range(PARAM['battery']['num_batt']) :
                obj_fcn += multibatt*xsum(s1[:,i])
                model += central_soc - soc[1:,i] <= s1[:,i]
                model += -s1[:,i] <= central_soc - soc[1:,i]  
    
    if smoothcharge > 0 :
        upper_bound_Pchg = model.add_var_tensor((k-1,PARAM['battery']['num_batt']),name = 'upper_bound_Pchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        upper_bound_Pdchg = model.add_var_tensor((k-1,PARAM['battery']['num_batt']),name = 'upper_bound_Pdchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        for i in range(PARAM['battery']['num_batt']) :
            obj_fcn += smoothcharge*( xsum(upper_bound_Pchg[:,i]) + xsum(upper_bound_Pdchg[:,i]) )
            model += Pchg[1:,i] - Pchg[:-1,i] <= upper_bound_Pchg[:,i]
            model += -upper_bound_Pchg[:,i] <= Pchg[1:,i] - Pchg[:-1,i]
            model += Pdchg[1:,i] - Pdchg[:-1,i] <= upper_bound_Pdchg[:,i]
            model += -upper_bound_Pdchg[:,i] <= Pdchg[1:,i] - Pdchg[:-1,i]
    if chargebatt > 0 :
        for i in range(PARAM['battery']['num_batt']) :    
            obj_fcn += chargebatt*xsum((PARAM['battery']['max'][i] - soc[:,i])/(PARAM['battery']['max'][i] - PARAM['battery']['min'][i]))
    # -------------------- assign objective function
    model.objective = minimize(obj_fcn)
    #------------------------------ constraint ----------------------
    # Power diff between HA and DA constraint    
    if minute % 15 == 10 :
        for i in range(4) : # there is 4 point of planning from day ahead plan
            model += Pchg[3*i:3*(i+1),0] - PARAM['Pchg'][i] <= uPchg[3*i:3*(i+1)]
            model += -uPchg[3*i:3*(i+1)] <= Pchg[3*i:3*(i+1),0] - PARAM['Pchg'][i]
            model += Pdchg[3*i:3*(i+1),0] - PARAM['Pdchg'][i] <= uPdchg[3*i:3*(i+1)]
            model += -uPdchg[3*i:3*(i+1)] <= Pdchg[3*i:3*(i+1),0] - PARAM['Pdchg'][i]
            model += Pnet[3*i:3*(i+1)] - PARAM['Pnet'][i] <= uPnet[3*i:3*(i+1)]
            model += -uPnet[3*i:3*(i+1)] <= Pnet[3*i:3*(i+1)] - PARAM['Pnet'][i]
    elif minute % 15 == 0 :
        # add constraint to first 10 minutes
        model += Pchg[:2,0] - PARAM['Pchg'][0] <= uPchg[:2]
        model += -uPchg[:2] <= Pchg[:2,0] - PARAM['Pchg'][0]
        model += Pdchg[:2,0] - PARAM['Pdchg'][0] <= uPdchg[:2]
        model += -uPdchg[:2] <= Pdchg[:2,0] - PARAM['Pdchg'][0]
        model += Pnet[:2] - PARAM['Pnet'][0] <= uPnet[:2]
        model += -uPnet[:2] <= Pnet[:2] - PARAM['Pnet'][0]
        # add constraint to last 5 minutes
        model += Pchg[-1,0] - PARAM['Pchg'][-1] <= uPchg[-1]
        model += -uPchg[-1] <= Pchg[-1,0] - PARAM['Pchg'][-1]
        model += Pdchg[-1,0] - PARAM['Pdchg'][-1] <= uPdchg[-1]
        model += -uPdchg[-1] <= Pdchg[-1,0] - PARAM['Pdchg'][-1]
        model += Pnet[-1] - PARAM['Pnet'][-1] <= uPnet[-1]
        model += -uPnet[-1] <= Pnet[-1] - PARAM['Pnet'][-1]
        for i in range(3) :
            model += Pchg[(3*i+2):(3*(i+1)+2),0] - PARAM['Pchg'][i+1] <= uPchg[(3*i+2):(3*(i+1)+2)]
            model += -uPchg[(3*i+2):(3*(i+1)+2)] <= Pchg[(3*i+2):(3*(i+1)+2),0] - PARAM['Pchg'][i+1]
            model += Pdchg[(3*i+2):(3*(i+1)+2),0] - PARAM['Pdchg'][i+1] <= uPdchg[(3*i+2):(3*(i+1)+2)]
            model += -uPdchg[(3*i+2):(3*(i+1)+2)] <= Pdchg[(3*i+2):(3*(i+1)+2),0] - PARAM['Pdchg'][i+1]
            model += Pnet[(3*i+2):(3*(i+1)+2)] - PARAM['Pnet'][i+1] <= uPnet[(3*i+2):(3*(i+1)+2)]
            model += -uPnet[(3*i+2):(3*(i+1)+2)] <= Pnet[(3*i+2):(3*(i+1)+2)] - PARAM['Pnet'][i+1]
    elif minute % 15 == 5 :
        # add constraint to first 5 minutes
        model += Pchg[0,0] - PARAM['Pchg'][0] <= uPchg[0]
        model += -uPchg[0] <= Pchg[0,0] - PARAM['Pchg'][0]
        model += Pdchg[0,0] - PARAM['Pdchg'][0] <= uPdchg[0]
        model += -uPdchg[0] <= Pdchg[0,0] - PARAM['Pdchg'][0]
        model += Pnet[0] - PARAM['Pnet'][0] <= uPnet[0]
        model += -uPnet[0] <= Pnet[0] - PARAM['Pnet'][0]        
        # add constraint to last 10 minutes
        model += Pchg[-2:,0] - PARAM['Pchg'][-1] <= uPchg[-2:]
        model += -uPchg[-2:] <= Pchg[-2:,0] - PARAM['Pchg'][-1]
        model += Pdchg[-2:,0] - PARAM['Pdchg'][-1] <= uPdchg[-2:]
        model += -uPdchg[-2:] <= Pdchg[-2:,0] - PARAM['Pdchg'][-1]
        model += Pnet[-2:] - PARAM['Pnet'][-1] <= uPnet[-2:]
        model += -uPnet[-2:] <= Pnet[-2:] - PARAM['Pnet'][-1]
        for i in range(3) :
            model += Pchg[(3*i+1):(3*(i+1)+1),0] - PARAM['Pchg'][i+1] <= uPchg[(3*i+1):(3*(i+1)+1)]
            model += -uPchg[(3*i+1):(3*(i+1)+1)] <= Pchg[(3*i+1):(3*(i+1)+1),0] - PARAM['Pchg'][i+1]
            model += Pdchg[(3*i+1):(3*(i+1)+1),0] - PARAM['Pdchg'][i+1] <= uPdchg[(3*i+1):(3*(i+1)+1)]
            model += -uPdchg[(3*i+1):(3*(i+1)+1)] <= Pdchg[(3*i+1):(3*(i+1)+1),0] - PARAM['Pdchg'][i+1]
            model += Pnet[(3*i+1):(3*(i+1)+1)] - PARAM['Pnet'][i+1] <= uPnet[(3*i+1):(3*(i+1)+1)]
            model += -uPnet[(3*i+1):(3*(i+1)+1)] <= Pnet[(3*i+1):(3*(i+1)+1)] - PARAM['Pnet'][i+1]

    # battery constraint
    model += Pchg <= xchg*PARAM['battery']['charge_rate']
    model += Pdchg <= xdchg*PARAM['battery']['discharge_rate']
    model += xchg + xdchg <= 1
    model += 0 <= xchg + xdchg
    # Pnet constraint
    Pnet_string = "model += Pnet == PARAM['PV'] - PARAM['PL']"
    for i in range(PARAM['battery']['num_batt']) :
        Pnet_string += f" + Pdchg[:,{i}] - Pchg[:,{i}]"
    exec(Pnet_string) # assign Pnet constraint
    # battery dynamic constraint
    model += soc[0,:] == PARAM['battery']['initial']
    for i in range(PARAM['battery']['num_batt']) :
        model += soc[1:k+1,i] == (soc[0:k,i] 
        + (PARAM['battery']['charge_effiency'][i]*100*Resolution_HR / PARAM['battery']['actual_capacity'][i])*Pchg[0:k,i]
        - (Resolution_HR*100/(PARAM['battery']['discharge_effiency'][i]*PARAM['battery']['actual_capacity'][i]))*Pdchg[0:k,i])
    
    
    model.threads = -1 # use all available CPU threads
    model.preprocess = 1 # enable preprocess
    model.optimize()
    #-----------------------------append solution ------------------
    sol = {}
    sol['datetime'] = pd.date_range(PARAM['Start_date'],PARAM['Start_date'] + datetime.timedelta(minutes=PARAM['Horizon']),freq=str(PARAM['Resolution']) +'min' )[:-1]
    # PARAMETER
    sol['PARAM_PV'] = PARAM['PV']
    sol['PARAM_PL'] = PARAM['PL']
    if energycost > 0 or profit > 0 :
        sol['Buy_rate'] = PARAM['Buy_rate']
        sol['Sell_rate'] = PARAM['Sell_rate']
    # VARIABLE
    sol['Pnet'] = [e.x for e in model.vars if  e.name[:4] == 'Pnet']
    sol['u1'] = [e.x for e in model.vars if  e.name[:2] == 'u1']
    for i in range(PARAM['battery']['num_batt']) :
        if PARAM['battery']['num_batt'] == 1 :
            sol['Pchg_0'] = [e.x for e in model.vars if  e.name[:4] == 'Pchg']
            sol['Pdchg_0'] = [e.x for e in model.vars if e.name[:5] == 'Pdchg']
            sol['xchg_0'] = [e.x for e in model.vars if e.name[:4] == 'xchg']
            sol['xdchg_0'] = [e.x for e in model.vars if e.name[:5] == 'xdchg']
            sol['soc_0'] = [e.x for e in model.vars if e.name[:3] == 'soc'][:-1] 
              
        elif PARAM['battery']['num_batt'] >= 2 :
            if multibatt > 0:
                if PARAM['battery']['num_batt'] == 2 :
                    sol[f's1'] = [e.x for e in model.vars if  e.name[:2] == 's1']
                elif PARAM['battery']['num_batt'] >= 3 :    
                    sol[f's1_{i}'] = [e.x for e in model.vars if  e.name[:2] == 's1' and e.name[-1] == str(i)]
            
            sol[f'Pchg_{i}'] = [e.x for e in model.vars if  e.name[:4] == 'Pchg' and e.name[-1] == str(i)]
            sol[f'Pdchg_{i}'] = [e.x for e in model.vars if e.name[:5] == 'Pdchg' and e.name[-1] == str(i)]
            sol[f'xchg_{i}'] = [e.x for e in model.vars if e.name[:4] == 'xchg' and e.name[-1] == str(i)]
            sol[f'xdchg_{i}'] = [e.x for e in model.vars if e.name[:5] == 'xdchg' and e.name[-1] == str(i)]
            sol[f'soc_{i}'] = [e.x for e in model.vars if e.name[:3] == 'soc' and e.name[-1] == str(i)][:-1]        
            if smoothcharge > 0 :
                sol[f'upper_bound_Pchg_{i}'] = [e.x for e in model.vars if  e.name[:16] == 'upper_bound_Pchg' and e.name[-1] == str(i)] + [0]
                sol[f'upper_bound_Pdchg_{i}'] = [e.x for e in model.vars if  e.name[:17] == 'upper_bound_Pdchg' and e.name[-1] ==  str(i)] + [0]


    sol['uPnet'] = [e.x for e in model.vars if e.name[:5] == 'uPnet' ]
    sol['uPchg'] = [e.x for e in model.vars if e.name[:5] == 'uPchg' ]
    sol['uPdchg'] = [e.x for e in model.vars if e.name[:6] == 'uPdchg' ]    
    return pd.DataFrame(sol)

def EMS_AC_opt(PARAM,energycost=0,multibatt=1,chargebatt=0,smoothcharge=0):
    # input Resolution (min)
    # input Horizon (min)
    if  energycost < 0 or multibatt < 0 or chargebatt < 0 or smoothcharge < 0 :
        raise Exception('Weight must > 0')
    elif PARAM['Horizon'] % PARAM['Resolution'] != 0 :
        raise Exception('variables length must be integer')    
    elif multibatt > 0 and PARAM['battery']['num_batt'] == 1 :
        raise Exception('The number of battery must >= 2 to use this objective')
    #------------ change unit
    fs = 1/PARAM['Resolution'] #sampling freq(1/min)
    h = PARAM['Horizon'] #optimization horizon(min)
    k = int(h*fs) #length of variable
    Resolution_HR = PARAM['Resolution'] /60 # resolution in Hr
    
    #------------------------------- variables -----------------------
    model = Model(solver_name=CBC)
    Pnet = model.add_var_tensor((k,),name = 'Pnet',lb = -float('inf'),ub = float('inf'),var_type = CONTINUOUS)    
    Pdchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'Pdchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    xdchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'xdchg',lb = 0,ub = 1,var_type = INTEGER)
    Pchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'Pchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    xchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'xchg',lb = 0,ub = 1,var_type = INTEGER)
    soc =       model.add_var_tensor((k+1,PARAM['battery']['num_batt']),name = 'soc',lb = PARAM['battery']['min'][0],ub = PARAM['battery']['max'][0],var_type = CONTINUOUS)
    Pac_lab = model.add_var_tensor((k,),name='Pac_lab',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    Pac_student = model.add_var_tensor((k,),name='Pac_student',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    Xac_lab =     model.add_var_tensor((k,4),name='Xac_lab',lb = 0,ub = 1,var_type = INTEGER)
    Xac_student =     model.add_var_tensor((k,4),name='Xac_student',lb = 0,ub = 1,var_type = INTEGER)
    obj_fcn = -PARAM['AClab']['encourage_weight']*xsum(PARAM['ACschedule'] @ Xac_lab) - PARAM['ACstudent']['encourage_weight']*xsum(PARAM['ACschedule'] @ Xac_student)
    if energycost > 0 :
        u1 =     model.add_var_tensor((k,),name = 'u1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        obj_fcn += energycost*xsum(u1) 
        model += (-Resolution_HR*PARAM['Buy_rate']*np.eye(k) @ Pnet) <= u1 
    if multibatt > 0 :
        if PARAM['battery']['num_batt'] == 2: #just use soc1 - soc2
            s1 =     model.add_var_tensor((k,),name = 's1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
            obj_fcn += multibatt*xsum(s1)
            # force soc
            model += soc[1:,0] - soc[1:,1] <= s1
            model += -s1 <= soc[1:,0] - soc[1:,1]
        elif PARAM['battery']['num_batt'] >= 3: #use central variable
            s1 =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 's1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
            central_soc = model.add_var_tensor((k,),name = 'central_soc',lb = 0,ub = float('inf'),var_type = CONTINUOUS)              
            for i in range(PARAM['battery']['num_batt']) :
                obj_fcn += multibatt*xsum(s1[:,i])
                model += central_soc - soc[1:,i] <= s1[:,i]
                model += -s1[:,i] <= central_soc - soc[1:,i]        
    if chargebatt > 0 :
        for i in range(PARAM['battery']['num_batt']) :    
            obj_fcn += chargebatt*xsum((PARAM['battery']['max'][i] - soc[:,i])/(PARAM['battery']['max'][i] - PARAM['battery']['min'][i]))    
    if smoothcharge > 0 :
        upper_bound_Pchg = model.add_var_tensor((k-1,PARAM['battery']['num_batt']),name = 'upper_bound_Pchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        upper_bound_Pdchg = model.add_var_tensor((k-1,PARAM['battery']['num_batt']),name = 'upper_bound_Pdchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        for i in range(PARAM['battery']['num_batt']) :
            obj_fcn += smoothcharge*( xsum(upper_bound_Pchg[:,i]) + xsum(upper_bound_Pdchg[:,i]) )
            model += Pchg[1:,i] - Pchg[:-1,i] <= upper_bound_Pchg[:,i]
            model += -upper_bound_Pchg[:,i] <= Pchg[1:,i] - Pchg[:-1,i]
            model += Pdchg[1:,i] - Pdchg[:-1,i] <= upper_bound_Pdchg[:,i]
            model += -upper_bound_Pdchg[:,i] <= Pdchg[1:,i] - Pdchg[:-1,i] 
    # add encourage AC
    
    
    model.objective = minimize(obj_fcn)
    #------------------------------ constraint ----------------------  
    # AC constraint
    model += Pac_lab == PARAM['AClab']['Paclab_rate']*(Xac_lab[:,0] + 0.5*Xac_lab[:,1] + 0.7*Xac_lab[:,2] + 0.8*Xac_lab[:,3])
    model += Xac_lab[:,0] + Xac_lab[:,1] + Xac_lab[:,2] + Xac_lab[:,3] <= 1
    model += Xac_lab[:,0] + Xac_lab[:,1] + Xac_lab[:,2] + Xac_lab[:,3] >= 0
    model += Pac_student == PARAM['ACstudent']['Pacstudent_rate']*(Xac_student[:,0] + 0.5*Xac_student[:,1] + 0.7*Xac_student[:,2] + 0.8*Xac_student[:,3])
    model += Xac_student[:,0] + Xac_lab[:,1] + Xac_lab[:,2] + Xac_lab[:,3] <= 1
    model += Xac_student[:,0] + Xac_lab[:,1] + Xac_lab[:,2] + Xac_lab[:,3] >= 0 
    
    # battery constraint
    model += Pchg <= xchg*PARAM['battery']['charge_rate']
    model += Pdchg <= xdchg*PARAM['battery']['discharge_rate']
    model += xchg + xdchg <= 1
    model += 0 <= xchg + xdchg 
    
    
    # Pnet constraint
    Pnet_string = "model += Pnet == PARAM['PV'] - PARAM['Puload'] - Pac_lab - Pac_student"
    for i in range(PARAM['battery']['num_batt']) :
        Pnet_string += f" + Pdchg[:,{i}] - Pchg[:,{i}]"
    exec(Pnet_string) # assign Pnet constraint
    
    # if energycost = 0 then it is islanding mode
    if energycost == 0:
        model += Pnet == 0

    # battery dynamic constraint
    model += soc[0,:] == PARAM['battery']['initial']
    for i in range(PARAM['battery']['num_batt']) :
        model += soc[1:k+1,i] == (soc[0:k,i] 
        + (PARAM['battery']['charge_effiency'][i]*100*Resolution_HR / PARAM['battery']['actual_capacity'][i])*Pchg[0:k,i]
        - (Resolution_HR*100/(PARAM['battery']['discharge_effiency'][i]*PARAM['battery']['actual_capacity'][i]))*Pdchg[0:k,i])
    
    
    #model.optimize(max_seconds_same_incumbent=2*60) # if feasible solution is found and not improve for 2 mins, terminates with that solution
    model.threads = -1 # use all available CPU threads
    model.preprocess = 1 # enable preprocess
    status = model.optimize()
    
    if status == OptimizationStatus.NO_SOLUTION_FOUND :
        print('No solution')
        return
    if status == OptimizationStatus.INFEASIBLE :
        print('Infeasible')
        return
    #----------------------------- solution ------------------
       
    sol = {}
    sol['datetime'] = pd.date_range(PARAM['Start_date'],PARAM['Start_date'] + datetime.timedelta(minutes=PARAM['Horizon']),freq=str(PARAM['Resolution']) +'min' )[:-1]
    # PARAMETER
    sol['PARAM_PV'] = PARAM['PV']
    sol['Puload'] = PARAM['Puload']*np.ones((k,))
    if energycost > 0  :
        sol['Buy_rate'] = PARAM['Buy_rate']
        sol['Sell_rate'] = PARAM['Sell_rate']
    sol['ACschedule'] = PARAM['ACschedule']
    sol['Pac_student'] = [e.x for e in model.vars if  e.name[:11] == 'Pac_student']   
    sol['Pac_lab'] = [e.x for e in model.vars if  e.name[:7] == 'Pac_lab']          
    sol['Xac_student_0'] = [e.x for e in model.vars if  e.name[:11] == 'Xac_student' and e.name[-1] == '0']
    sol['Xac_student_1'] = [e.x for e in model.vars if  e.name[:11] == 'Xac_student' and e.name[-1] == '1']
    sol['Xac_student_2'] = [e.x for e in model.vars if  e.name[:11] == 'Xac_student' and e.name[-1] == '2']
    sol['Xac_student_3'] = [e.x for e in model.vars if  e.name[:11] == 'Xac_student' and e.name[-1] == '3']
    sol['Xac_lab_0'] = [e.x for e in model.vars if  e.name[:7] == 'Xac_lab' and e.name[-1] == '0']
    sol['Xac_lab_1'] = [e.x for e in model.vars if  e.name[:7] == 'Xac_lab' and e.name[-1] == '1']
    sol['Xac_lab_2'] = [e.x for e in model.vars if  e.name[:7] == 'Xac_lab' and e.name[-1] == '2']
    sol['Xac_lab_3'] = [e.x for e in model.vars if  e.name[:7] == 'Xac_lab' and e.name[-1] == '3']

    # VARIABLE
    sol['Pnet'] = [e.x for e in model.vars if  e.name[:4] == 'Pnet']
    sol['u1'] = [e.x for e in model.vars if  e.name[:2] == 'u1']
    for i in range(PARAM['battery']['num_batt']) :
        if PARAM['battery']['num_batt'] == 1 :
            sol['Pchg_0'] = [e.x for e in model.vars if  e.name[:4] == 'Pchg']
            sol['Pdchg_0'] = [e.x for e in model.vars if e.name[:5] == 'Pdchg' ]
            sol['xchg_0'] = [e.x for e in model.vars if e.name[:4] == 'xchg']
            sol['xdchg_0'] = [e.x for e in model.vars if e.name[:5] == 'xdchg']
            sol['soc_0'] = [e.x for e in model.vars if e.name[:3] == 'soc'][:-1] 
              
        elif PARAM['battery']['num_batt'] >= 2 :
            if multibatt > 0:
                if PARAM['battery']['num_batt'] == 2 :
                    sol[f's1'] = [e.x for e in model.vars if  e.name[:2] == 's1']
                elif PARAM['battery']['num_batt'] >= 3 :    
                    sol[f's1_{i}'] = [e.x for e in model.vars if  e.name[:2] == 's1' and e.name[-1] == str(i)]
            
            sol[f'Pchg_{i}'] = [e.x for e in model.vars if  e.name[:4] == 'Pchg' and e.name[-1] == str(i)]
            sol[f'Pdchg_{i}'] = [e.x for e in model.vars if e.name[:5] == 'Pdchg' and e.name[-1] == str(i)]
            sol[f'xchg_{i}'] = [e.x for e in model.vars if e.name[:4] == 'xchg' and e.name[-1] == str(i)]
            sol[f'xdchg_{i}'] = [e.x for e in model.vars if e.name[:5] == 'xdchg' and e.name[-1] == str(i)]
            sol[f'soc_{i}'] = [e.x for e in model.vars if e.name[:3] == 'soc' and e.name[-1] == str(i)][:-1]        
            if smoothcharge > 0 :
                sol[f'upper_bound_Pchg_{i}'] = [e.x for e in model.vars if  e.name[:16] == 'upper_bound_Pchg' and e.name[-1] == str(i)] + [0]
                sol[f'upper_bound_Pdchg_{i}'] = [e.x for e in model.vars if  e.name[:17] == 'upper_bound_Pdchg' and e.name[-1] ==  str(i)] + [0]
        
    return pd.DataFrame(sol)
def EMS_RE_opt(PARAM,multibatt=1,chargebatt=0,smoothcharge=0):
    # input Resolution (min)
    # input Horizon (min)
    if  multibatt < 0 or chargebatt < 0 or smoothcharge < 0 :
        raise Exception('Weight must > 0')
    elif PARAM['Horizon'] % PARAM['Resolution'] != 0 :
        raise Exception('variables length must be integer')    
    elif multibatt > 0 and PARAM['battery']['num_batt'] == 1 :
        raise Exception('The number of battery must >= 2 to use this objective')
    #------------ change unit
    fs = 1/PARAM['Resolution'] #sampling freq(1/min)
    h = PARAM['Horizon'] #optimization horizon(min)
    k = int(h*fs) #length of variable
    Resolution_HR = PARAM['Resolution'] /60 # resolution in Hr
    Horizon_day = int(PARAM['Horizon']/(24*60)  )# optimization horizon(day)
    Npoint1day =  int(60*24/PARAM['Resolution'])                               # Number of solution point in 1 day
    #------------------------------- variables -----------------------
    model = Model(solver_name=CBC)
    Pnet = model.add_var_tensor((k,),name = 'Pnet',lb = -float('inf'),ub = float('inf'),var_type = CONTINUOUS)    
    Pdchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'Pdchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    xdchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'xdchg',lb = 0,ub = 1,var_type = INTEGER)
    Pchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'Pchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    xchg =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 'xchg',lb = 0,ub = 1,var_type = INTEGER)
    soc =       model.add_var_tensor((k+1,PARAM['battery']['num_batt']),name = 'soc',lb = PARAM['battery']['min'][0],ub = PARAM['battery']['max'][0],var_type = CONTINUOUS)
    maxPnet1day = model.add_var_tensor((Horizon_day,),name='maxPnet1day',lb=0,ub=float('inf'))
    u1 =     model.add_var_tensor((k,),name = 'u1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
    obj_fcn = xsum(maxPnet1day)
    
    if multibatt > 0 :
        if PARAM['battery']['num_batt'] == 2: #just use soc1 - soc2
            s1 =     model.add_var_tensor((k,),name = 's1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
            obj_fcn += multibatt*xsum(s1)
            # force soc
            model += soc[1:,0] - soc[1:,1] <= s1
            model += -s1 <= soc[1:,0] - soc[1:,1]
        elif PARAM['battery']['num_batt'] >= 3: #use central variable
            s1 =     model.add_var_tensor((k,PARAM['battery']['num_batt']),name = 's1',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
            central_soc = model.add_var_tensor((k,),name = 'central_soc',lb = 0,ub = float('inf'),var_type = CONTINUOUS)              
            for i in range(PARAM['battery']['num_batt']) :
                obj_fcn += multibatt*xsum(s1[:,i])
                model += central_soc - soc[1:,i] <= s1[:,i]
                model += -s1[:,i] <= central_soc - soc[1:,i]        
    if chargebatt > 0 :
        for i in range(PARAM['battery']['num_batt']) :    
            obj_fcn += chargebatt*xsum((PARAM['battery']['max'][i] - soc[:,i])/(PARAM['battery']['max'][i] - PARAM['battery']['min'][i]))    
    if smoothcharge > 0 :
        upper_bound_Pchg = model.add_var_tensor((k-1,PARAM['battery']['num_batt']),name = 'upper_bound_Pchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        upper_bound_Pdchg = model.add_var_tensor((k-1,PARAM['battery']['num_batt']),name = 'upper_bound_Pdchg',lb = 0,ub = float('inf'),var_type = CONTINUOUS)
        for i in range(PARAM['battery']['num_batt']) :
            obj_fcn += smoothcharge*( xsum(upper_bound_Pchg[:,i]) + xsum(upper_bound_Pdchg[:,i]) )
            model += Pchg[1:,i] - Pchg[:-1,i] <= upper_bound_Pchg[:,i]
            model += -upper_bound_Pchg[:,i] <= Pchg[1:,i] - Pchg[:-1,i]
            model += Pdchg[1:,i] - Pdchg[:-1,i] <= upper_bound_Pdchg[:,i]
            model += -upper_bound_Pdchg[:,i] <= Pdchg[1:,i] - Pdchg[:-1,i] 
    
    
    
    model.objective = minimize(obj_fcn)
    #------------------------------ constraint ----------------------  
    # RE100 constraint
    for i in range(Horizon_day) :
        model += -Pnet[(Npoint1day*i):(Npoint1day*(i+1))] <= u1[(Npoint1day*i):(Npoint1day*(i+1))]
        model += u1[(Npoint1day*i):(Npoint1day*(i+1))] <= maxPnet1day[i]
    
   
    
    # battery constraint
    model += Pchg <= xchg*PARAM['battery']['charge_rate']
    model += Pdchg <= xdchg*PARAM['battery']['discharge_rate']
    model += xchg + xdchg <= 1
    model += 0 <= xchg + xdchg   
    
    # Pnet constraint
    Pnet_string = "model += Pnet == PARAM['PV'] - PARAM['PL']"
    for i in range(PARAM['battery']['num_batt']) :
        Pnet_string += f" + Pdchg[:,{i}] - Pchg[:,{i}]"
    exec(Pnet_string) # assign Pnet constraint

    # battery dynamic constraint
    model += soc[0,:] == PARAM['battery']['initial']
    for i in range(PARAM['battery']['num_batt']) :
        model += soc[1:k+1,i] == (soc[0:k,i] 
        + (PARAM['battery']['charge_effiency'][i]*100*Resolution_HR / PARAM['battery']['actual_capacity'][i])*Pchg[0:k,i]
        - (Resolution_HR*100/(PARAM['battery']['discharge_effiency'][i]*PARAM['battery']['actual_capacity'][i]))*Pdchg[0:k,i])
    
    
    #model.optimize(max_seconds_same_incumbent=2*60) # if feasible solution is found and not improve for 2 mins, terminates with that solution
    model.threads = -1 # use all available CPU threads
    model.preprocess = 1 # enable preprocess
    status = model.optimize()
    
    if status == OptimizationStatus.NO_SOLUTION_FOUND :
        print('No solution')
        return
    if status == OptimizationStatus.INFEASIBLE :
        print('Infeasible')
        return
    #----------------------------- solution ------------------
       
    sol = {}
    sol['datetime'] = pd.date_range(PARAM['Start_date'],PARAM['Start_date'] + datetime.timedelta(minutes=PARAM['Horizon']),freq=str(PARAM['Resolution']) +'min' )[:-1]
    # PARAMETER
    sol['PARAM_PV'] = PARAM['PV']
    sol['PARAM_PL'] = PARAM['PL']  

    # VARIABLE
    sol['Pnet'] = [e.x for e in model.vars if  e.name[:4] == 'Pnet']
    sol['u1'] = [e.x for e in model.vars if  e.name[:2] == 'u1']
    sol['maxPnet1day'] = np.array([e.x*np.ones((Npoint1day,)) for e in model.vars if  e.name[:11] == 'maxPnet1day']).flatten()
    for i in range(PARAM['battery']['num_batt']) :
        if PARAM['battery']['num_batt'] == 1 :
            sol['Pchg_0'] = [e.x for e in model.vars if  e.name[:4] == 'Pchg']
            sol['Pdchg_0'] = [e.x for e in model.vars if e.name[:5] == 'Pdchg' ]
            sol['xchg_0'] = [e.x for e in model.vars if e.name[:4] == 'xchg']
            sol['xdchg_0'] = [e.x for e in model.vars if e.name[:5] == 'xdchg']
            sol['soc_0'] = [e.x for e in model.vars if e.name[:3] == 'soc'][:-1] 
              
        elif PARAM['battery']['num_batt'] >= 2 :
            if multibatt > 0:
                if PARAM['battery']['num_batt'] == 2 :
                    sol[f's1'] = [e.x for e in model.vars if  e.name[:2] == 's1']
                elif PARAM['battery']['num_batt'] >= 3 :    
                    sol[f's1_{i}'] = [e.x for e in model.vars if  e.name[:2] == 's1' and e.name[-1] == str(i)]
            
            sol[f'Pchg_{i}'] = [e.x for e in model.vars if  e.name[:4] == 'Pchg' and e.name[-1] == str(i)]
            sol[f'Pdchg_{i}'] = [e.x for e in model.vars if e.name[:5] == 'Pdchg' and e.name[-1] == str(i)]
            sol[f'xchg_{i}'] = [e.x for e in model.vars if e.name[:4] == 'xchg' and e.name[-1] == str(i)]
            sol[f'xdchg_{i}'] = [e.x for e in model.vars if e.name[:5] == 'xdchg' and e.name[-1] == str(i)]
            sol[f'soc_{i}'] = [e.x for e in model.vars if e.name[:3] == 'soc' and e.name[-1] == str(i)][:-1]        
            if smoothcharge > 0 :
                sol[f'upper_bound_Pchg_{i}'] = [e.x for e in model.vars if  e.name[:16] == 'upper_bound_Pchg' and e.name[-1] == str(i)] + [0]
                sol[f'upper_bound_Pdchg_{i}'] = [e.x for e in model.vars if  e.name[:17] == 'upper_bound_Pdchg' and e.name[-1] ==  str(i)] + [0]
        
    return pd.DataFrame(sol)

def EMS_energycost_plot(PARAM,sol) :
    
    #------------ change unit
    k = sol.shape[0] #length of variable
    Resolution_min = abs(sol['datetime'].dt.minute[0] - sol['datetime'].dt.minute[1]) # Resolution in minute
    Resolution_HR = Resolution_min/60 # resolution in Hr   
    excess_gen = sol['PARAM_PV'] - sol['PARAM_PL']
    expense = -np.minimum(0,sol['Pnet'])*Resolution_HR*sol['Buy_rate']
    expense_noems = -np.minimum(0,excess_gen)*Resolution_HR*sol['Buy_rate']
    start_date = sol['datetime'][0]  
    end_date = sol['datetime'].iloc[-1]
    date = sol['datetime']    
    tick = pd.date_range(start_date,end_date,freq='3H')
    fig,ax = plt.subplots(4,2,figsize=(20,20)) 
    

    #cell (0,0)
    ax[0,0].step(date,sol['Buy_rate'],'-m',label='Buy rate',where='post')
    ax[0,0].set_ylabel('TOU (THB)')
    ax[0,0].set_ylim([0,8])
    ax[0,0].set_title('TOU')
    ax[0,0].legend()


    #cell (0,1)
    ax[0,1].step(date,sol['soc_0'],'-k',label='SoC',where='post')
    ax[0,1].set_ylabel('SoC (%)')
    ax[0,1].set_ylim([PARAM['battery']['min'][0] - 5,PARAM['battery']['max'][0] + 5])
    ax[0,1].set_title('Battery 1 charge/discharge status and SoC')
    ax[0,1].plot(date,PARAM['battery']['min'][0]*np.ones(k,),'--m')
    ax[0,1].plot(date,PARAM['battery']['max'][0]*np.ones(k,),'--m')
    ax01r = ax[0,1].twinx()
    ax01r.step(date,sol['Pchg_0'],'-b',label = 'Pchg',where='post')
    ax01r.step(date,sol['Pdchg_0'],'-r',label = 'Pdchg',where='post')
    ax01r.set_ylabel('Power (kW)')
    ax01r.set_ylim([0,PARAM['battery']['discharge_rate'][0]+5])
    lines_left,labels_left =  ax[0,1].get_legend_handles_labels()
    lines_right,labels_right =  ax01r.get_legend_handles_labels()
    ax[0,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)


    # cell (1,0)
    ax[1,0].step(date,PARAM['PV'],label='Solar',where='post')
    ax[1,0].step(date,PARAM['PL'],label='Load',where='post')
    ax[1,0].set_ylabel('Power (kW)')    
    ax[1,0].set_title('Load consumption and solar generation')
    ax[1,0].legend()

    # cell (1,1)
    ax[1,1].step(date,np.maximum(0,sol['Pnet']),'-g',label='Pnet > 0 (Curtail)',where='post')
    ax[1,1].step(date,np.minimum(0,sol['Pnet']),'-r',label='Pnet < 0 (Bought from grid)',where='post')
    ax[1,1].set_ylabel('Power (kW)')
    ax[1,1].set_ylim([-100,50])
    ax[1,1].set_title('Pnet = PV + Pdchg - Pchg - Pload')
    ax[1,1].legend()

    #cell (2,0)
    ax[2,0].step(date,excess_gen,'-k',label='Excess power',where='post')
    ax[2,0].set_ylabel('Power (kW)')
    ax[2,0].set_ylim([-30 ,30])
    ax[2,0].set_title('Excess gen = PV - PL and battery charge/discharge status')
    ax20r = ax[2,0].twinx()
    ax20r.step(date,sol['xchg_0'],'-b',label = 'xchg',where='post')
    ax20r.step(date,-sol['xdchg_0'],'-r',label = 'xdchg',where='post')
    ax20r.set_ylim([-1.5,1.5])
    ax20r.set_yticks([-1,0,1])
    lines_left,labels_left =  ax[2,0].get_legend_handles_labels()
    lines_right,labels_right =  ax20r.get_legend_handles_labels()
    ax[2,0].legend(lines_left + lines_right,labels_left + labels_right,loc=0)

    #cell(2,1)
    ax[2,1].step(date,expense,'-k',label='Expense',where='post')
    ax[2,1].set_ylabel('Expense (THB)')
    ax[2,1].set_ylim([0 ,50])
    ax[2,1].set_yticks(range(0,60,10))
    ax[2,1].set_title('Cumulative expense when using EMS 1')
    ax21r = ax[2,1].twinx()
    ax21r.step(date,expense.cumsum(),'-b',label = 'Cumulative expense',where='post')
    ax21r.set_ylim([0,4000])
    ax21r.set_ylabel('Cumulative expense (THB)')
    lines_left,labels_left =  ax[2,1].get_legend_handles_labels()
    lines_right,labels_right =  ax21r.get_legend_handles_labels()
    ax[2,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)


    #cell(3,0)
    ax[3,0].step(date,sol['Buy_rate'],'-m',label='Buy rate',where='post')
    ax[3,0].set_ylabel('Buy rate (THB)')
    ax[3,0].set_ylim([0 ,10])
    ax[3,0].set_yticks(range(0,10,2))
    ax[3,0].set_title('Pchg, Pdchg and TOU')
    ax30r = ax[3,0].twinx()
    ax30r.step(date,sol['Pchg_0'],'-b',label = 'Pchg',where='post')
    ax30r.step(date,sol['Pdchg_0'],'-r',label = 'Pdchg',where='post')
    ax30r.set_ylim([0,35])
    ax30r.set_ylabel('Power (kW)')
    lines_left,labels_left =  ax[3,0].get_legend_handles_labels()
    lines_right,labels_right =  ax30r.get_legend_handles_labels()
    ax[3,0].legend(lines_left + lines_right,labels_left + labels_right,loc=0)

    #cell(3,1)
    ax[3,1].step(date,expense_noems,'-k',label='Expense',where='post')
    ax[3,1].set_ylabel('Expense (THB)')
    ax[3,1].set_ylim([0 ,50])
    ax[3,1].set_yticks(range(0,60,10))
    ax[3,1].set_title('Cumulative expense without EMS 1')
    ax31r = ax[3,1].twinx()
    ax31r.step(date,expense_noems.cumsum(),'-b',label = 'Cumulative expense',where='post')
    ax31r.set_ylim([0,4000])
    ax31r.set_ylabel('Cumulative expense (THB)')
    lines_left,labels_left =  ax[3,1].get_legend_handles_labels()
    lines_right,labels_right =  ax31r.get_legend_handles_labels()
    ax[3,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)



    for i in range(4) :
        for j in range(2) :
            ax[i,j].xaxis.set_major_formatter(DateFormatter('%H'))
            ax[i,j].set_xticks(tick)
            #ax[i,j].legend()
            ax[i,j].grid()
            ax[i,j].set_xlim([start_date,end_date])
    return fig

def EMS_profit_plot(PARAM,sol) :    
    #------------ change unit
    k = sol.shape[0] #length of variable
    Resolution_min = abs(sol['datetime'].dt.minute[0] - sol['datetime'].dt.minute[1]) # Resolution in minute
    Resolution_HR = Resolution_min/60 # resolution in Hr   
    excess_gen = sol['PARAM_PV'] - sol['PARAM_PL']
    expense = np.minimum(0,sol['Pnet'])*Resolution_HR*sol['Buy_rate']
    expense_noems = np.minimum(0,excess_gen)*Resolution_HR*sol['Buy_rate']
    revenue = np.maximum(0,sol['Pnet'])*Resolution_HR*sol['Sell_rate']
    revenue_noems = np.maximum(0,excess_gen)*Resolution_HR*sol['Sell_rate']
    profit = revenue + expense
    profit_noems = revenue_noems + expense_noems
    start_date = sol['datetime'][0]  
    end_date = sol['datetime'].iloc[-1]
    date = sol['datetime']    
    tick = pd.date_range(start_date,end_date,freq='3H')
    fig,ax = plt.subplots(4,2,figsize=(20,20)) 
    

    #cell (0,0)
    ax[0,0].step(date,sol['Buy_rate'],'-m',label='Buy rate',where='post')
    ax[0,0].step(date,sol['Sell_rate'],'-k',label='Sell rate',where='post')
    ax[0,0].set_ylabel('TOU (THB)')
    ax[0,0].set_ylim([0,8])
    ax[0,0].set_title('TOU')
    ax[0,0].legend()


    #cell (0,1)
    ax[0,1].step(date,sol['soc_0'],'-k',label='SoC',where='post')
    ax[0,1].set_ylabel('SoC (%)')
    ax[0,1].set_ylim([PARAM['battery']['min'][0] - 5,PARAM['battery']['max'][0] + 5])
    ax[0,1].set_title('Battery 1 charge/discharge status and SoC')
    ax[0,1].plot(date,PARAM['battery']['min'][0]*np.ones(k,),'--m')
    ax[0,1].plot(date,PARAM['battery']['max'][0]*np.ones(k,),'--m')
    ax01r = ax[0,1].twinx()
    ax01r.step(date,sol['Pchg_0'],'-b',label = 'Pchg',where='post')
    ax01r.step(date,sol['Pdchg_0'],'-r',label = 'Pdchg',where='post')
    ax01r.set_ylabel('Power (kW)')
    ax01r.set_ylim([0,PARAM['battery']['discharge_rate'][0]+5])
    lines_left,labels_left =  ax[0,1].get_legend_handles_labels()
    lines_right,labels_right =  ax01r.get_legend_handles_labels()
    ax[0,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)


    # cell (1,0)
    ax[1,0].step(date,PARAM['PV'],label='Solar',where='post')
    ax[1,0].step(date,PARAM['PL'],label='Load',where='post')
    ax[1,0].set_ylabel('Power (kW)')    
    ax[1,0].set_title('Load consumption and solar generation')
    ax[1,0].legend()

    # cell (1,1)
    ax[1,1].step(date,np.maximum(0,sol['Pnet']),'-g',label='Pnet > 0 (Sold to grid)',where='post')
    ax[1,1].step(date,np.minimum(0,sol['Pnet']),'-r',label='Pnet < 0 (Bought from grid)',where='post')
    ax[1,1].set_ylabel('Power (kW)')
    ax[1,1].set_title('Pnet = PV + Pdchg - Pchg - Pload')
    ax[1,1].legend()

    #cell (2,0)
    ax[2,0].step(date,excess_gen,'-k',label='Excess power',where='post')
    ax[2,0].set_ylabel('Power (kW)')
    ax[2,0].set_ylim([-30 ,30])
    ax[2,0].set_title('Excess gen = PV - PL and battery charge/discharge status')
    ax20r = ax[2,0].twinx()
    ax20r.step(date,sol['xchg_0'],'-b',label = 'xchg',where='post')
    ax20r.step(date,-sol['xdchg_0'],'-r',label = 'xdchg',where='post')
    ax20r.set_ylim([-1.5,1.5])
    ax20r.set_yticks([-1,0,1])
    lines_left,labels_left =  ax[2,0].get_legend_handles_labels()
    lines_right,labels_right =  ax20r.get_legend_handles_labels()
    ax[2,0].legend(lines_left + lines_right,labels_left + labels_right,loc=0)

    #cell(2,1)
    ax[2,1].step(date,revenue,'-r',label='Revenue',where='post')
    ax[2,1].step(date,expense,'-b',label='Expense',where='post')
    ax[2,1].set_ylabel('Expense/Revenue (THB)')
    ax[2,1].set_ylim([-60,30])
    ax[2,1].set_yticks(range(-60,60,20))
    ax[2,1].set_title('With EMS 1')
    ax21r = ax[2,1].twinx()
    ax21r.step(date,profit.cumsum(),'-k',label = 'Cumulative profit',where='post')
    ax21r.set_ylim([-3500,1000])
    ax21r.set_ylabel('Cumulative profit (THB)')
    lines_left,labels_left =  ax[2,1].get_legend_handles_labels()
    lines_right,labels_right =  ax21r.get_legend_handles_labels()
    ax[2,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)


    #cell(3,0)
    ax[3,0].step(date,sol['Buy_rate'],'-m',label='Buy rate',where='post')
    ax[3,0].step(date,sol['Sell_rate'],'-k',label='Sell rate',where='post')
    ax[3,0].set_ylabel('TOU (THB)')
    ax[3,0].set_ylim([0 ,10])
    ax[3,0].set_yticks(range(0,10,2))
    ax[3,0].set_title('Pchg, Pdchg and TOU')
    ax30r = ax[3,0].twinx()
    ax30r.step(date,sol['Pchg_0'],'-b',label = 'Pchg',where='post')
    ax30r.step(date,sol['Pdchg_0'],'-r',label = 'Pdchg',where='post')
    ax30r.set_ylim([0,35])
    ax30r.set_ylabel('Power (kW)')
    lines_left,labels_left =  ax[3,0].get_legend_handles_labels()
    lines_right,labels_right =  ax30r.get_legend_handles_labels()
    ax[3,0].legend(lines_left + lines_right,labels_left + labels_right,loc=0)

    #cell(3,1)
    ax[3,1].step(date,revenue_noems,'-r',label='Revenue',where='post')
    ax[3,1].step(date,expense_noems,'-b',label='Expense',where='post')    
    ax[3,1].set_ylabel('Expense/Revenue (THB)')
    ax[3,1].set_ylim([-60 ,30])
    ax[3,1].set_yticks(range(-60,60,20))
    ax[3,1].set_title('Without EMS 1')
    ax31r = ax[3,1].twinx()
    ax31r.step(date,profit_noems.cumsum(),'-k',label = 'Cumulative profit',where='post')
    ax31r.set_ylim([-3500,1000])
    ax31r.set_ylabel('Cumulative profit (THB)')
    lines_left,labels_left =  ax[3,1].get_legend_handles_labels()
    lines_right,labels_right =  ax31r.get_legend_handles_labels()
    ax[3,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)



    for i in range(4) :
        for j in range(2) :
            ax[i,j].xaxis.set_major_formatter(DateFormatter('%H'))
            ax[i,j].set_xticks(tick)
            #ax[i,j].legend()
            ax[i,j].grid()
            ax[i,j].set_xlim([start_date,end_date])
    return fig

def EMS_energyfromgrid_plot(PARAM,sol) :    
    #------------ change unit
    k = sol.shape[0] #length of variable
    Resolution_min = abs(sol['datetime'].dt.minute[0] - sol['datetime'].dt.minute[1]) # Resolution in minute
    Resolution_HR = Resolution_min/60 # resolution in Hr   
    excess_gen = sol['PARAM_PV'] - sol['PARAM_PL']
    start_date = sol['datetime'][0]  
    end_date = sol['datetime'].iloc[-1]
    date = sol['datetime']    
    tick = pd.date_range(start_date,end_date,freq='3H')
    fig,ax = plt.subplots(2,2,figsize=(20,20)) 
    
    # cell (0,0)
    ax[0,0].step(date,PARAM['PV'],label='Solar',where='post')
    ax[0,0].step(date,PARAM['PL'],label='Load',where='post')
    ax[0,0].set_ylabel('Power (kW)')    
    ax[0,0].set_title('Load consumption and solar generation')
    ax[0,0].legend()
    
    #cell (0,1)
    ax[0,1].step(date,sol['soc_0'],'-k',label='SoC',where='post')
    ax[0,1].set_ylabel('SoC (%)')
    ax[0,1].set_ylim([PARAM['battery']['min'][0] - 5,PARAM['battery']['max'][0] + 5])
    ax[0,1].set_title('Battery 1 charge/discharge status and SoC')
    ax[0,1].plot(date,PARAM['battery']['min'][0]*np.ones(k,),'--m')
    ax[0,1].plot(date,PARAM['battery']['max'][0]*np.ones(k,),'--m')
    ax01r = ax[0,1].twinx()
    ax01r.step(date,sol['Pchg_0'],'-b',label = 'Pchg',where='post')
    ax01r.step(date,sol['Pdchg_0'],'-r',label = 'Pdchg',where='post')
    ax01r.set_ylabel('Power (kW)')
    ax01r.set_ylim([0,PARAM['battery']['discharge_rate'][0]+5])
    lines_left,labels_left =  ax[0,1].get_legend_handles_labels()
    lines_right,labels_right =  ax01r.get_legend_handles_labels()
    ax[0,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)
  

    # cell (1,0)
    ax[1,0].step(date,np.maximum(0,sol['Pnet'])*Resolution_HR,'-g',label='Curtailed energy',where='post')
    ax[1,0].step(date,np.minimum(0,sol['Pnet'])*Resolution_HR,'-r',label='Energy drew from grid',where='post')
    ax[1,0].set_ylabel('Energy (kWh)')
    ax[1,0].set_title('Energy = Pnet*Resolution')
    ax10r = ax[1,0].twinx()
    ax10r.step(date,np.minimum(0,sol['Pnet']).cumsum()*Resolution_HR,'-k',label='Cumulative energy draw from grid',where='post')
    ax10r.set_ylabel('Cumulative energy (kWh)')
    lines_left,labels_left =  ax[1,0].get_legend_handles_labels()
    lines_right,labels_right =  ax10r.get_legend_handles_labels()
    ax[1,0].legend(lines_left + lines_right,labels_left + labels_right,loc=0)

    #cell (1,1)
    ax[1,1].step(date,excess_gen,'-k',label='Excess power',where='post')
    ax[1,1].set_ylabel('Power (kW)')
    ax[1,1].set_ylim([-30 ,30])
    ax[1,1].set_title('Excess gen = PV - PL and battery charge/discharge status')
    ax11r = ax[1,1].twinx()
    ax11r.step(date,sol['xchg_0'],'-b',label = 'xchg',where='post')
    ax11r.step(date,-sol['xdchg_0'],'-r',label = 'xdchg',where='post')
    ax11r.set_ylim([-1.5,1.5])
    ax11r.set_yticks([-1,0,1])
    lines_left,labels_left =  ax[1,1].get_legend_handles_labels()
    lines_right,labels_right =  ax11r.get_legend_handles_labels()
    ax[1,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)

    for i in range(2) :
        for j in range(2) :
            ax[i,j].xaxis.set_major_formatter(DateFormatter('%H'))
            ax[i,j].set_xticks(tick)
            #ax[i,j].legend()
            ax[i,j].grid()
            ax[i,j].set_xlim([start_date,end_date])
    return fig
def EMS_AC_plot(PARAM,sol) :    
    #------------ change unit
    k = sol.shape[0] #length of variable
    Resolution_min = abs(sol['datetime'].dt.minute[0] - sol['datetime'].dt.minute[1]) # Resolution in minute
    Resolution_HR = Resolution_min/60 # resolution in Hr  
    Pload = sol['Puload'] + sol['Pac_lab'] + sol['Pac_student']
    excess_gen = sol['PARAM_PV'] - Pload    
    start_date = sol['datetime'][0]  
    end_date = sol['datetime'].iloc[-1]
    date = sol['datetime']    
    tick = pd.date_range(start_date,end_date,freq='3H')
    fig,ax = plt.subplots(3,2,figsize=(20,20)) 
    
    # cell (0,0)
    ax[0,0].step(date,PARAM['PV'],'-b',label='Solar',where='post')
    ax[0,0].step(date,Pload,'-r',label='Load',where='post')
    ax[0,0].set_ylabel('Power (kW)')    
    ax[0,0].set_title('Solar generation and load consumption (Pload = Puload + Pac,s + Pac,m) ')
    ax[0,0].legend()
    
    #cell (0,1)
    ax[0,1].step(date,sol['soc_0'],'-k',label='SoC',where='post')
    ax[0,1].set_ylabel('SoC (%)')
    ax[0,1].set_ylim([PARAM['battery']['min'][0] - 5,PARAM['battery']['max'][0] + 5])
    ax[0,1].set_title('SoC and load consumption (Pload = Puload + Pac,s + Pac,m)')
    ax[0,1].plot(date,PARAM['battery']['min'][0]*np.ones(k,),'--m')
    ax[0,1].plot(date,PARAM['battery']['max'][0]*np.ones(k,),'--m')
    ax01r = ax[0,1].twinx()
    ax01r.step(date,Pload,'-r',label = 'Load',where='post')    
    ax01r.set_ylabel('Load (kW)')
    lines_left,labels_left =  ax[0,1].get_legend_handles_labels()
    lines_right,labels_right =  ax01r.get_legend_handles_labels()
    ax[0,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)
  
   
    #cell (1,0)
    ax[1,0].step(date,excess_gen,'-k',label='Excess power',where='post')
    ax[1,0].set_ylabel('Power (kW)')
    ax[1,0].set_ylim([-30 ,30])
    ax[1,0].set_title('Excess gen = PV - PL and battery charge/discharge status')
    ax10r = ax[1,0].twinx()
    ax10r.step(date,sol['xchg_0'],'-b',label = 'xchg',where='post')
    ax10r.step(date,-sol['xdchg_0'],'-r',label = 'xdchg',where='post')
    ax10r.set_ylim([-1.5,1.5])
    ax10r.set_yticks([-1,0,1])
    lines_left,labels_left =  ax[1,0].get_legend_handles_labels()
    lines_right,labels_right =  ax10r.get_legend_handles_labels()
    ax[1,0].legend(lines_left + lines_right,labels_left + labels_right,loc=0)

    #cell (1,1)
    ax[1,1].step(date,sol['Pac_lab']*100/PARAM['AClab']['Paclab_rate'],'-r',label='AC level',where='post')
    ax[1,1].set_ylabel('Power (kW)')
    ax[1,1].set_ylim([0,100])
    ax[1,1].set_yticks([0, 50, 70, 80, 100])
    ax[1,1].set_title('Lab AC level')
    ax11r = ax[1,1].twinx()
    ax11r.step(date,PARAM['ACschedule'],'-.k',label = 'ACschedule',where='post')    
    ax11r.set_ylim([0,1.5])
    ax11r.set_yticks([0,1])
    lines_left,labels_left =  ax[1,1].get_legend_handles_labels()
    lines_right,labels_right =  ax11r.get_legend_handles_labels()
    ax[1,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)



    # cell (2,0)
    ax[2,0].step(date,np.maximum(0,sol['Pnet']),'-r',label='Pnet > 0 (Curtailed)',where='post')
    ax[2,0].step(date,np.minimum(0,sol['Pnet']),'-b',label='Pnet < 0 (Bought from grid)',where='post')
    ax[2,0].set_ylabel('Power (kW)')
    ax[2,0].set_title('Pnet = PV + Pdchg - Pchg - Pload')
    ax[2,0].legend()

    #cell (2,1)
    ax[2,1].step(date,sol['Pac_student']*100/PARAM['ACstudent']['Pacstudent_rate'],'-r',label='AC level',where='post')
    ax[2,1].set_ylabel('Power (kW)')
    ax[2,1].set_ylim([0,100])
    ax[2,1].set_yticks([0, 50, 70, 80, 100])
    ax[2,1].set_title('Student AC level')
    ax21r = ax[2,1].twinx()
    ax21r.step(date,PARAM['ACschedule'],'-.k',label = 'ACschedule',where='post')    
    ax21r.set_ylim([0,1.5])
    ax21r.set_yticks([0,1])
    lines_left,labels_left =  ax[2,1].get_legend_handles_labels()
    lines_right,labels_right =  ax21r.get_legend_handles_labels()
    ax[2,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)

    for i in range(3) :
        for j in range(2) :
            ax[i,j].xaxis.set_major_formatter(DateFormatter('%H'))
            ax[i,j].set_xticks(tick)
            #ax[i,j].legend()
            ax[i,j].grid()
            ax[i,j].set_xlim([start_date,end_date])
    return fig

def EMS_RE_plot(PARAM,sol) :    
    #------------ change unit
    k = sol.shape[0] #length of variable
    Resolution_min = abs(sol['datetime'].dt.minute[0] - sol['datetime'].dt.minute[1]) # Resolution in minute
    Resolution_HR = Resolution_min/60 # resolution in Hr   
    excess_gen = sol['PARAM_PV'] - sol['PARAM_PL']
    start_date = sol['datetime'][0]  
    end_date = sol['datetime'].iloc[-1]
    date = sol['datetime']    
    tick = pd.date_range(start_date,end_date,freq='3H')
    fig,ax = plt.subplots(2,2,figsize=(20,20)) 
    
    # cell (0,0)
    ax[0,0].step(date,PARAM['PV'],label='Solar',where='post')
    ax[0,0].step(date,PARAM['PL'],label='Load',where='post')
    ax[0,0].set_ylabel('Power (kW)')    
    ax[0,0].set_title('Load consumption and solar generation')
    ax[0,0].legend()
    
    #cell (0,1)
    ax[0,1].step(date,sol['soc_0'],'-k',label='SoC',where='post')
    ax[0,1].set_ylabel('SoC (%)')
    ax[0,1].set_ylim([PARAM['battery']['min'][0] - 5,PARAM['battery']['max'][0] + 5])
    ax[0,1].set_title('Battery 1 charge/discharge status and SoC')
    ax[0,1].plot(date,PARAM['battery']['min'][0]*np.ones(k,),'--m')
    ax[0,1].plot(date,PARAM['battery']['max'][0]*np.ones(k,),'--m')
    ax01r = ax[0,1].twinx()
    ax01r.step(date,sol['Pchg_0'],'-b',label = 'Pchg',where='post')
    ax01r.step(date,sol['Pdchg_0'],'-r',label = 'Pdchg',where='post')
    ax01r.set_ylabel('Power (kW)')
    ax01r.set_ylim([0,PARAM['battery']['discharge_rate'][0]+5])
    lines_left,labels_left =  ax[0,1].get_legend_handles_labels()
    lines_right,labels_right =  ax01r.get_legend_handles_labels()
    ax[0,1].legend(lines_left + lines_right,labels_left + labels_right,loc=0)
  

    
    #cell (1,0)
    ax[1,0].step(date,excess_gen,'-k',label='Excess power',where='post')
    ax[1,0].set_ylabel('Power (kW)')
    ax[1,0].set_ylim([-30 ,30])
    ax[1,0].set_title('Excess gen = PV - PL and battery charge/discharge status')
    ax10r = ax[1,0].twinx()
    ax10r.step(date,sol['xchg_0'],'-b',label = 'xchg',where='post')
    ax10r.step(date,-sol['xdchg_0'],'-r',label = 'xdchg',where='post')
    ax10r.set_ylim([-1.5,1.5])
    ax10r.set_yticks([-1,0,1])
    lines_left,labels_left =  ax[1,0].get_legend_handles_labels()
    lines_right,labels_right =  ax10r.get_legend_handles_labels()
    ax[1,0].legend(lines_left + lines_right,labels_left + labels_right,loc=0)

    # cell (1,1)
    ax[1,1].step(date,np.maximum(0,sol['Pnet']),'-g',label='Pnet > 0 (Curtail)',where='post')
    ax[1,1].step(date,np.minimum(0,sol['Pnet']),'-r',label='Pnet < 0 (Bought from grid)',where='post')
    ax[1,1].step(date,sol['maxPnet1day'],'-b',label='Upper bound of Pnet < 0',where='post')
    ax[1,1].set_ylabel('Power (kW)')
    ax[1,1].set_ylim([-100,50])
    ax[1,1].set_title('Pnet = PV + Pdchg - Pchg - Pload')
    ax[1,1].legend()

    for i in range(2) :
        for j in range(2) :
            ax[i,j].xaxis.set_major_formatter(DateFormatter('%H'))
            ax[i,j].set_xticks(tick)
            #ax[i,j].legend()
            ax[i,j].grid()
            ax[i,j].set_xlim([start_date,end_date])
    return fig