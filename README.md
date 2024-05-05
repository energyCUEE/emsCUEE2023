<details>
<summary>Unit for each parameters and variable</summary>

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


