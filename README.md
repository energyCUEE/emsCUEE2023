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
 
 **TOU_CHOICE** : str (choose either 'smart' or 'THcurrent') <br />
 The choice of TOU in which the function generate  <br />
 **start_time** : datetime.timedelta obj. <br />
 The number of minutes past from 00:00. It must consistent with resolution. For example, if the resolution is 15 minute, then 5,10 are not allowed. <br />
 Return <br />
 **TOU** :
</details>


