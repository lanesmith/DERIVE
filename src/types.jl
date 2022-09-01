"""
    Scenario

A struct to hold information about the specific scenario under investigation.
"""
Base.@kwdef struct Scenario
    problem_type::String
    interval_length::String
    optimization_horizon::String
    weather_data::Union{DataFrames.DataFrame,Nothing}
    latitude::Union{Float64,Nothing}
    longitude::Union{Float64,Nothing}
    timezone::Union{String,Nothing}
    payback_period::Union{Int64,Nothing}
    year::Int64
end

"""
    Tariff

A struct to hold information about the different prices and characteristics of the 
electricity tariff offered by a utility.
"""
Base.@kwdef struct Tariff
    utility_name::Union{String,Nothing}
    tariff_name::Union{String,Nothing}
    weekday_weekend_split::Bool
    holiday_split::Bool
    seasonal_month_split::Bool
    months_by_season::Dict
    energy_tou_rates::Union{Dict,Nothing}
    energy_tiered_rates::Union{Dict,Nothing}
    monthly_maximum_demand_rates::Union{Dict,Nothing}
    monthly_demand_tou_rates::Union{Dict,Nothing}
    daily_demand_tou_rates::Union{Dict,Nothing}
    nem_enabled::Bool
    nem_non_bypassable_charge::Union{Float64,Nothing}
    customer_charge::Dict
    energy_prices::Union{DataFrames.DataFrame,Nothing}
    demand_prices::Union{Dict,Nothing}
    demand_mask::Union{DataFrames.DataFrame,Nothing}
    nem_prices::Union{DataFrames.DataFrame,Nothing}
end

"""
    Market

A struct to hold information about the different prices and characteristics of different 
market products offered by an independent system operator (ISO).
"""
Base.@kwdef struct Market
    iso_name::Union{String,Nothing}
    reg_up_enabled::Bool
    reg_up_prices::Union{DataFrames.DataFrame,Nothing}
    reg_dn_enabled::Bool
    reg_dn_prices::Union{DataFrames.DataFrame,Nothing}
    sp_res_enabled::Bool
    sp_res_prices::Union{DataFrames.DataFrame,Nothing}
    ns_res_enabled::Bool
    ns_res_prices::Union{DataFrames.DataFrame,Nothing}
end

"""
    Incentives

A struct to hold information about the different prices and characteristics of different 
distributed energy resource (DER) incentive programs.
"""
Base.@kwdef struct Incentives
    itc_enabled::Bool
    itc_rate::Union{Float64,Nothing}
    sgip_enabled::Bool
    sgip_rate::Union{Float64,Nothing}
end

"""
    Demand

A struct to hold information about the consumer's base demand profile and any relevant 
characteristics about the consumer's base demand.
"""
Base.@kwdef struct Demand
    demand_profile::DataFrames.DataFrame
    shift_enabled::Bool
    shift_capacity_profile::Union{DataFrames.DataFrame,Nothing}
    shift_duration::Union{Int64,Nothing}
end

"""
    Solar

A struct to hold information about the photovoltaic (PV) generation profile and any 
necessary PV module and array specifications.
"""
Base.@kwdef struct Solar
    enabled::Bool
    capacity_factor_profile::Union{DataFrames.DataFrame,Nothing}
    power_capacity::Union{Float64,Nothing}
    module_manufacturer::Union{String,Nothing}
    module_name::Union{String,Nothing}
    module_nominal_power::Union{Float64,Nothing}
    module_rated_voltage::Union{Float64,Nothing}
    module_rated_current::Union{Float64,Nothing}
    module_oc_voltage::Union{Float64,Nothing}
    module_sc_current::Union{Float64,Nothing}
    module_voltage_temp_coeff::Union{Float64,Nothing}
    module_current_temp_coeff::Union{Float64,Nothing}
    module_noct::Union{Float64,Nothing}
    module_number_of_cells::Union{Int64,Nothing}
    module_cell_material::Union{String,Nothing}
    iv_curve_method::Union{String,Nothing}
    pv_capital_cost::Union{Float64,Nothing}
    collector_azimuth::Union{Float64,Nothing}
    tilt_angle::Union{Float64,Nothing}
    ground_reflectance::String
    tracker::String
    tracker_capital_cost::Union{Float64,Nothing}
    inverter_eff::Union{Float64,Nothing}
    inverter_capital_cost::Union{Float64,Nothing}
    lifespan::Union{Int64,Nothing}
end

"""
    Storage

A struct to hold information about the specifications of the battery energy storage 
(BES) system.
"""
Base.@kwdef struct Storage
    enabled::Bool
    power_capacity::Union{Int64,Nothing}
    energy_capacity::Union{Int64,Nothing}
    charge_eff::Union{Float64,Nothing}
    discharge_eff::Union{Float64,Nothing}
    capital_cost::Union{Float64,Nothing}
    lifespan::Union{Int64,Nothing}
end

"""
    Grid

A struct to hold information about the specifications of the electric power grid system 
to which consumers are connected.
"""
Base.@kwdef struct Grid
    nodes::Union{Array{Int64,1},Nothing}
    branches::Union{Array{Int64,1},Nothing}
    branches_from::Union{Array{Int64,1},Nothing}
    branches_to::Union{Array{Int64,1},Nothing}
    branch_capacity::Union{Array{Float64,1},Nothing}
end
