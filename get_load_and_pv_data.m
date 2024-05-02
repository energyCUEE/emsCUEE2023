function [PL,PV] = get_load_and_pv_data(load_data,pv_data,start_date,time_horizon, desired_PVcapacity)
    
    start_date = datetime(start_date);                 % Convert type from (str=>datetime)
    end_datetime = start_date + minutes(time_horizon); % Calculate end datetime
    
   

    % Filter the data within the specific range
    filter_load_data = load_data(load_data.datetime >= start_date & load_data.datetime < end_datetime, :);
    filter_pv_data = pv_data(pv_data.datetime >= start_date & pv_data.datetime < end_datetime, :);

    % This solar profile is emulated from EE building which has the installtion capacity
    % of 8 kWp, the pv generation power is scaled up to the desired capacity
    source_capacity = 8;                           % kW PV installation capacity of source
    PV_scale_factor = desired_PVcapacity/source_capacity; % scale up from source to desired capacity (kW)
    PV = PV_scale_factor*filter_pv_data.PV_kW;
    PL = filter_load_data.Load_kW;
end