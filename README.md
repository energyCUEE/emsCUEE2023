<details>
<summary>Overview of this work</summary>
       
# Abstract: 
To enhance campus sustainability, implementing an Energy Management System (EMS) is essential. This study investigates Gewertz Square sandbox within the Department of Electrical Engineering, Chulalongkorn University. The system includes load consumption, solar generation, and a battery. Three EMS aspects are proposed, including economic, operational, and RE 100 EMS, formulated as Mixed-Integer Linear Programming (MILP). These EMS aspects are analyzed for their impact on energy policies of the desired components in the system. The economic EMS has a spe- cific purpose to minimize energy unit, energy cost, or maximize profit depending on users’ selection when total load consumption is considered, which can be treated as uncontrollable load. Meanwhile, the operational EMS considers the controllable load from Air Conditioning systems (ACs) in two rooms treated as controllable load, focusing on ACs activation while minimizing electricity costs and encouraging islanding EMS. The RE 100 EMS aims to achieve self-reliance regardless of electricity expenses. Forecasting models consisting of load and solar forecasting models from NeuralProphet models are used to predict future data, serving as parameters in the actual EMS operation. An example of EMS operation in Economic EMS is simulated. In this work, two time-scale optimizations are formulated, Day-Ahead (DA) EMS: horizon 3 days with 15-minute resolution, and Hour-Ahead (HA) EMS: horizon 1 hour with 5-minute resolution. The HA EMS is designed to account for both errors from the DA EMS and optimal planning over an HA period. Hence, HA EMS utilizes DA solution as a guided planing by aligning HA solutions with DA solutions as the absolute of difference of power relating to the battery. Simulation results illustrate that the decision-making process of the battery varies for each proposed EMS. The study concludes that EMS implementation offers significant advantages over not utilizing one.

**Keywords:** 
Energy Management System (EMS), Mixed-Integer Linear Programming (MILP), NeuralProphet models.

## Mathematical Formulation of Optimization Problem

**Objective:**

minimize Objective function = $J_{\text{cost}} + J_{\text{battery}}$


**Subject to:**

(i) **Power balance constraint**

(ii) **Battery dynamic constraint**

(iii) **Maximum and minimum charge constraint**

(iv) **Charging and discharging limitation constraint**

(v) **Non-simultaneous charge and discharge constraint**


---


| General parameter  | Unit |
| ------------- | ------------- |
| Resolution  | Minute |
| Horizon  | Minute |
| Buy rate  | THB/kWh |
| Sell rate*  | THB/kWh |
| Start_date* | No unit |
| PV | kW |
| PL | kW |


| Battery parameter  | Unit |
| ------------- | ------------- |
| Actual capacity  | kWh |
| Charge efficiency  | - |
| Discharge efficiency  | - |
| Charge rate | kW |
| Discharge rate | kW |
| min | % |
| initial | % |
| max  | % |


| AC parameter  | Unit |
| ------------- | ------------- |
| ACschedule*  | No unit |
| Puload* | kW |
| encourage_weight | THB |
| Paclab_rate | kW |
| Pacstudent_rate | kW |

Note : Start_date is in YYYY-MM-DD HH:MM:SS which must be converted using pd.to_datetime  <br />
       Buy/Sell rate is obtained from getBuySellrate <br />
       ACschedule rate is obtained from getSchedule <br />
       for Puload, currently, we used min() to extract uload from PL. 
</details>
<details>
<summary>Function in EMS.py</summary>
  
`getBuySellrate(Resolution,Horizon,TOU_CHOICE,start_time=datetime.timedelta(minutes=0))` <br />
 Parameters  <br />
 **Resolution** : integer <br />
 Time gap between each point of solution (Time resolution) <br />
 **Horizon** : integer <br />
 Optimization horizon
 **TOU_CHOICE** : str (choose either 'smart' or 'THcurrent') <br />
 The choice of TOU in which the function generate  <br />
 **start_time** : datetime.timedelta obj. <br />
 The number of minutes past from 00:00. It must be integer multiple of resolution. For example, if the resolution is 15 minute, then 5,10 are not allowed. <br />
 **Return** : DataFrame <br />
 Dataframe consists of 'time','buy', and 'sell' column which are buy and sell rate at the 'time'. <br />
 `getSchedule(start_date,Horizon,Resolution)` <br />
 Parameters  <br />
 **start_date** : datetime.datetime obj. <br />
 First point of datetime column <br />
 **Horizon** : integer <br />
 Optimization horizon <br />
 **Resolution** : integer <br />
 Time gap between each point of solution (Time resolution) <br />
 **Return** : DataFrame <br />
 DataFrame consists of 'datetime' and 'status' columns. The 'status' column is binary variable which 1 mean to use AC <br />
 ```
       # PARAMETER DICT FOR ECONOMIC AND RE EMS
       PARAM = {}
       # add length check with res & horizon
       PARAM['Horizon'] = 4*24*60        # horizon to optimize (min)
       PARAM['Resolution'] = 15    # sampling period(min)
       PARAM['PV_capacity'] = 50   # (kw) PV sizing for this EMS
       TOU = getBuySellrate(Resolution=PARAM['Resolution'],
                                           Horizon=PARAM['Horizon'],
                                           TOU_CHOICE='THcurrent',
                                           start_time=datetime.timedelta(minutes=0))
       PARAM['Buy_rate'] = TOU['buy'].to_numpy()
       PARAM['Sell_rate'] = TOU['sell'].to_numpy()
       PARAM['Start_date'] =  pd.to_datetime('2023-04-18 00:00:00')
       PARAM['battery'] = {}
       PARAM['battery']['charge_effiency'] = [0.95,0.95];              #  bes charge eff
       PARAM['battery']['discharge_effiency'] = [0.95*0.93,0.95*0.93]; #  bes discharge eff note inverter eff 0.93-0.96
       PARAM['battery']['discharge_rate'] = [30,30]; # kW max discharge rate
       PARAM['battery']['charge_rate'] = [30,30]; # kW max charge rate
       PARAM['battery']['actual_capacity'] = [125,125]; # kWh soc_capacity 
       PARAM['battery']['initial'] = [50,50]; # userdefined int 0-100 %
       PARAM['battery']['min'] = [20,20]; #min soc userdefined int 0-100 %
       PARAM['battery']['max'] = [80,80]; #max soc userdefined int 0-100 %
       PARAM['battery']['num_batt'] = len(PARAM['battery']['actual_capacity'])
       PARAM['PV'] = pv_data[ (pv_data['datetime'] >= PARAM['Start_date']) & (pv_data['datetime'] < PARAM['Start_date'] + pd.Timedelta(minutes=PARAM['Horizon'])) ]['Ptot (kW)'].to_numpy().flatten()
       PARAM['PL'] = load_data[ (load_data['datetime'] >= PARAM['Start_date']) & (load_data['datetime'] < PARAM['Start_date'] + pd.Timedelta(minutes=PARAM['Horizon']))]['Ptot (kW)'].to_numpy().flatten() 
 ```
 ```
       # PARAMETER DICT FOR AC EMS
       PARAM = {}
       # add length check with res & horizon
       PARAM['Horizon'] = 4*24*60        # horizon to optimize (min)
       PARAM['Resolution'] = 15    # sampling period(min)
       PARAM['PV_capacity'] = 50   # (kw) PV sizing for this EMS
       TOU = getBuySellrate(Resolution=PARAM['Resolution'],
                                           Horizon=PARAM['Horizon'],
                                           TOU_CHOICE='THcurrent',
                                           start_time=datetime.timedelta(minutes=0))
       PARAM['Buy_rate'] = TOU['buy'].to_numpy()
       PARAM['Sell_rate'] = TOU['sell'].to_numpy()
       PARAM['Start_date'] =  pd.to_datetime('2023-04-18 00:00:00')
       PARAM['battery'] = {}
       PARAM['battery']['charge_effiency'] = [0.95,0.95];              #  bes charge eff
       PARAM['battery']['discharge_effiency'] = [0.95*0.93,0.95*0.93]; #  bes discharge eff note inverter eff 0.93-0.96
       PARAM['battery']['discharge_rate'] = [30,30]; # kW max discharge rate
       PARAM['battery']['charge_rate'] = [30,30]; # kW max charge rate
       PARAM['battery']['actual_capacity'] = [125,125]; # kWh soc_capacity 
       PARAM['battery']['initial'] = [50,50]; # userdefined int 0-100 %
       PARAM['battery']['min'] = [20,20]; #min soc userdefined int 0-100 %
       PARAM['battery']['max'] = [80,80]; #max soc userdefined int 0-100 %
       PARAM['battery']['num_batt'] = len(PARAM['battery']['actual_capacity'])
       PARAM['PV'] = pv_data[ (pv_data['datetime'] >= PARAM['Start_date']) & (pv_data['datetime'] < PARAM['Start_date'] + pd.Timedelta(minutes=PARAM['Horizon'])) ]['Ptot (kW)'].to_numpy().flatten()
       PARAM['PL'] = load_data[ (load_data['datetime'] >= PARAM['Start_date']) & (load_data['datetime'] < PARAM['Start_date'] + pd.Timedelta(minutes=PARAM['Horizon']))]['Ptot (kW)'].to_numpy().flatten() 
       PARAM['AClab'] = {}
       PARAM['ACstudent'] = {}
       PARAM['AClab']['encourage_weight'] = 5 # (THB) weight for encourage lab ac usage
       PARAM['ACstudent']['encourage_weight'] = 2 #  (THB) weight for encourage student ac usage
       PARAM['AClab']['Paclab_rate'] = 3.71*3 # (kw) air conditioner input Power for lab
       PARAM['ACstudent']['Pacstudent_rate'] = 1.49*2 + 1.82*2 # (kw) air conditioner input Power for lab
       PARAM['Puload'] = PARAM['PL'].min() # (kW) power of uncontrollable load
       schedule = getSchedule(PARAM['Start_date'],PARAM['Horizon'],PARAM['Resolution'])
       PARAM['ACschedule']= schedule['status'].to_numpy() # schedule for AC
 ```
 
 `EMS_econ_opt(PARAM,energyfromgrid=0,energycost=0,profit=0,multibatt=1,chargebatt=0,smoothcharge=0)`
 Parameters  <br />
 **PARAM** : dict <br />
 Dictionary consists of parameters as shown above. See more example in demo. <br />
 Note : PV, PL, Buy_rate, Sell_rate must be numpy object and battery parameters must be list of length n (n is the number of batteries). <br />
 **energyfromgrid,energycost,profit** : int,float  <br />
 The weight for Jcost. Only one of these weight can be positive at a time, otherwise, the exception is raised.  <br />
 Note : when using `energyfromgrid`, TOU is not needed. <br />
 **multibatt,chargebatt,smoothcharge** : int,float  <br />
 The weight for Jbatt.   <br />
 **Return** : DataFrame <br />
 The solution is in pandas dataframe format. The dataframe consists of 'datetime','PARAM_PV','PARAM_PL' and all other variables use in optimization problem. <br />
 `EMS_AC_opt(PARAM,energycost=0,multibatt=1,chargebatt=0,smoothcharge=0)`  <br />
 Parameters  <br />
 **PARAM** : dict <br />
 Dictionary consists of parameters as shown above. See more example in demo. <br />
 **energycost** : int,float <br />
 The weight for buying energy from grid objective. If it is 0, then the problem is islanding. <br />
 Note : when islanding, TOU is not needed. <br />
 **multibatt,chargebatt,smoothcharge** : int,float  <br />
 The weight for Jbatt.   <br />
 **Return** : DataFrame <br />
 The solution is in pandas dataframe format. The dataframe consists of 'datetime','PARAM_PV','Puload' and all other variables use in optimization problem. <br />
 `EMS_RE_opt(PARAM,multibatt=1,chargebatt=0,smoothcharge=0)`
 Parameters  <br />
 **PARAM** : dict <br />
 Dictionary consists of parameters as shown above. See more example in demo. <br />
 **multibatt,chargebatt,smoothcharge** : int,float  <br />
 The weight for Jbatt.   <br />
 **Return** : DataFrame <br />
 The solution is in pandas dataframe format. The dataframe consists of 'datetime','PARAM_PV','PARAM_PL' and all other variables use in optimization problem. <br />
 `EMS_energycost_plot(PARAM,sol)`  <br />
 Parameters  <br />
 **PARAM** : dict <br />
 Dictionary consists of parameters as shown above. See more example in demo. <br />
 **sol** : DataFrame <br />
 Solution dataframe obtained from `EMS_econ_opt` when `energycost > 0` <br />
 **Return** : matplotlib figure <br />
 The figure object from matplotlib which plot solution and can be later save using `fig.savefig(path,bbox_inches='tight')` <br />
 `EMS_profit_plot(PARAM,sol)`  <br />
 Parameters  <br />
 **PARAM** : dict <br />
 Dictionary consists of parameters as shown above. See more example in demo. <br />
 **sol** : DataFrame <br />
 Solution dataframe obtained from `EMS_econ_opt` when `profit > 0` <br />
 **Return** : matplotlib figure <br />
 The figure object from matplotlib which plot solution and can be later save using `fig.savefig(path,bbox_inches='tight')` <br />
 `EMS_energyfromgrid_plot(PARAM,sol)`   <br />
 Parameters  <br />
 **PARAM** : dict <br />
 Dictionary consists of parameters as shown above. See more example in demo. <br />
 **sol** : DataFrame <br />
 Solution dataframe obtained from `EMS_econ_opt` when `energyfromgrid > 0` <br />
 **Return** : matplotlib figure <br />
 The figure object from matplotlib which plot solution and can be later save using `fig.savefig(path,bbox_inches='tight')` <br />
 `EMS_AC_plot(PARAM,sol)`  <br />
 Parameters  <br />
 **PARAM** : dict <br />
 Dictionary consists of parameters as shown above. See more example in demo. <br />
 **sol** : DataFrame <br />
 Solution dataframe obtained from `EMS_AC_opt` <br />
 **Return** : matplotlib figure <br />
 The figure object from matplotlib which plot solution and can be later save using `fig.savefig(path,bbox_inches='tight')` <br />
 `EMS_RE_plot(PARAM,sol)`   <br />
  Parameters  <br />
 **PARAM** : dict <br />
 Dictionary consists of parameters as shown above. See more example in demo. <br />
 **sol** : DataFrame <br />
 Solution dataframe obtained from `EMS_RE_opt` <br />
 **Return** : matplotlib figure <br />
 The figure object from matplotlib which plot solution and can be later save using `fig.savefig(path,bbox_inches='tight')` <br />
</details>

<details>
<summary>EMS function for MATLAB</summary>
       
`[Buy_rate,Sell_rate] = getBuySellrate(start_date,resolution,time_horizon,TOU_CHOICE)`
 Parameters  <br />
 **start_date** : datetime object  <br />
 start time of optimization. For example, "2023-05-13 05:00:00"  <br />
 **resolution** : integer <br />
 Time gap between each point of solution (Time resolution) <br />
 **time_horizon** : integer <br />
 Optimization horizon <br />
 **TOU_CHOICE** : str (choose either 'smart' or 'THcurrent') <br />
 The choice of TOU in which the function generate  <br />
 
 **Return** : vector <br />
 Buy_rate, Sell_rate in interested period  [start_date,start_date + time_horizon) <br />
 `function [PL,PV] = get_load_and_pv_data(load_data,pv_data,start_date,time_horizon, desired_PVcapacity)`
 Parameters  <br />
 **load_data** : datetime object  <br />
 Table of historical load consumption <br />
 **pv_data** : integer <br />
 Table of historical solar generation <br />
 **start_date** : datetime object  <br />
 start time of optimization. For example, "2023-05-13 05:00:00"  <br />
 **time_horizon** : integer <br />
 Optimization horizon <br />
 **desired_PVcapacity** : Real number <br />
 The size of PV <br />
 **Return** : vector <br />
 PL, PV in interested period  [start_date,start_date + time_horizon) <br />
 
 **Return** : vector <br />
 Buy_rate, Sell_rate in interested period  [start_date,start_date + time_horizon) <br />
       
       ```%   PARAMETER FOR ECON and RE EMS
              ---- get load&pv data and buy&sell rate ----
              [PARAM.PL,PARAM.PV] = get_load_and_pv_data(load_data,pv_data,start_date, time_horizon, pv_capacity);
              [PARAM.Buy_rate,PARAM.Sell_rate] = getBuySellrate(start_date,resolution,time_horizon,TOU_CHOICE);
              
              % ---- save parameters ----
              PARAM.start_date  = start_date;
              PARAM.Resolution  = resolution;
              PARAM.Horizon     = time_horizon; 
              PARAM.PV_capacity = pv_capacity;
              PARAM.TOU_CHOICE  = TOU_CHOICE;
              PARAM.weight_energyfromgrid = 0;
              PARAM.weight_energycost = 1;
              PARAM.weight_profit = 0;
              PARAM.weight_multibatt = 1;
              PARAM.weight_chargebatt = 1;
              PARAM.weight_smoothcharge  = 2;   
              % Battery parameters
              PARAM.battery.charge_effiency = [0.95 0.95]; %bes charge eff
              PARAM.battery.discharge_effiency = [0.95*0.93 0.95*0.93]; %  bes discharge eff note inverter eff 0.93-0.96
              PARAM.battery.discharge_rate = [30 30]; % kW max discharge rate
              PARAM.battery.charge_rate = [30 30]; % kW max charge rate
              PARAM.battery.actual_capacity = [125 125]; % kWh soc_capacity 
              PARAM.battery.initial = [50 50]; % userdefined int 0-100 %
              PARAM.battery.min = [20 20]; %min soc userdefined int 0-100 %
              PARAM.battery.max = [80 80]; %max soc userdefined int 0-100 %
              %end of batt
              
              PARAM.battery.num_batt = length(PARAM.battery.actual_capacity);
       ```
       ```    PARAMETER FOR AC EMS
              % ---- get load&pv data and buy&sell rate ----
              [PARAM.PL,PARAM.PV] = get_load_and_pv_data(load_data,pv_data,start_date, time_horizon, pv_capacity);
              [PARAM.Buy_rate,PARAM.Sell_rate] = getBuySellrate(start_date,resolution,time_horizon,TOU_CHOICE);
              
              % ---- save parameters ----
              PARAM.start_date  = start_date;
              PARAM.Resolution  = resolution;
              PARAM.Horizon     = time_horizon; 
              PARAM.PV_capacity = pv_capacity;
              PARAM.TOU_CHOICE  = TOU_CHOICE;
              % ----- weight for each objective if weight_energycost = 0 then it is islanding;
              PARAM.weight_energycost = 0;
              PARAM.weight_multibatt = 1;
              PARAM.weight_chargebatt = 1;
              PARAM.weight_smoothcharge  = 0.3; 
              %parameter part
              % battery(s)
              PARAM.battery.charge_effiency = [0.95 0.95]; %bes charge eff
              PARAM.battery.discharge_effiency = [0.95*0.93 0.95*0.93]; %  bes discharge eff note inverter eff 0.93-0.96
              PARAM.battery.discharge_rate = [30 30]; % kW max discharge rate
              PARAM.battery.charge_rate = [30 30]; % kW max charge rate
              PARAM.battery.actual_capacity = [125 125]; % kWh soc_capacity 
              PARAM.battery.initial = [50 50]; % userdefined int 0-100 %
              PARAM.battery.min = [20 20]; %min soc userdefined int 0-100 %
              PARAM.battery.max = [80 80]; %max soc userdefined int 0-100 %
              PARAM.battery.num_batt = length(PARAM.battery.actual_capacity);
              % AC parameters
              PARAM.AClab.encourage_weight = 5; %(THB) weight for encourage lab ac usage
              PARAM.ACstudent.encourage_weight = 2; %(THB) weight for encourage student ac usage
              PARAM.AClab.Paclab_rate = 3.71*3; % (kw) air conditioner input Power for lab
              PARAM.ACstudent.Pacstudent_rate = 1.49*2 + 1.82*2; % (kw) air conditioner input Power for lab
              PARAM.Puload = min(PARAM.PL) ;% (kW) power of uncontrollable load
              
              
              % end of parameter part
       ```

`function sol = ems_econ_opt(PARAM)`    <br />
Parameters  <br />
**PARAM** : MATLAB struct <br />
MATLAB structure object consists of parameters as shown above. See more example in ems_econ_main.m. <br />
**Return** : MATLAB struct <br />
MATLAB structure object consists of input PARAM struct and solution return form intlinprog function <br />
`function sol = EMS_AC_opt(PARAM)`     <br />
Parameters  <br />
**PARAM** :  MATLAB struct <br />
MATLAB structure object consists of parameters as shown above. See more example in ems_AC_main.m. <br />
**Return** : MATLAB struct <br />
MATLAB structure object consists of input PARAM struct and solution return form intlinprog function <br />
`function sol = EMS_RE_opt(PARAM)`     <br />
Parameters  <br />
**PARAM** :  MATLAB struct <br />
MATLAB structure object consists of parameters as shown above. See more example in ems_RE_main.m. <br />
**Return** : MATLAB struct <br />
MATLAB structure object consists of input PARAM struct and solution return form intlinprog function <br />
**NOTE** : For MATLAB, All parameters are included in solution structure object. <br />
`function [f,t] = EMS_energycost_plot(sol)`
Parameters  <br />
**sol** :  MATLAB struct <br />
Solution struct obtained from ems_econ_opt when using **energycost** as cost function. <br />
`function [f,t] = EMS_energyfromgrid_plot(sol)`
Parameters  <br />
**sol** :  MATLAB struct <br />
Solution struct obtained from ems_econ_opt when using **energyfromgrid** as cost function. <br />
`function [f,t] = EMS_profit_plot(sol)`
Parameters  <br />
**sol** :  MATLAB struct <br />
Solution struct obtained from ems_econ_opt when using **profit** as cost function. <br />
`function [f,t] = EMS_AC_plot(sol)`
Parameters  <br />
**sol** :  MATLAB struct <br />
Solution struct obtained from ems_AC_opt. <br />
`function [f,t] = EMS_RE_plot(sol)`
Parameters  <br />
**sol** :  MATLAB struct <br />
Solution struct obtained from ems_RE_opt. <br />

**Return from plot function** <br />
**f**   : MATLAB figure <br />
Figure contained plotted solution.  <br />
**t**   : MATLAB tiledlayout <br />
Tiledlayout object used for plotted in figure <br />



       
</details>



