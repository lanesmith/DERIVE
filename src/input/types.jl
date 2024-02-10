"""
    Scenario

A struct to hold information about the specific scenario under investigation.
"""
Base.@kwdef struct Scenario
    problem_type::String
    interval_length::Int64
    optimization_horizon::String
    optimization_solver::String
    weather_data::Union{DataFrames.DataFrame,Nothing}
    latitude::Union{Float64,Nothing}
    longitude::Union{Float64,Nothing}
    timezone::Union{String,Nothing}
    payback_period::Union{Int64,Nothing}
    real_discount_rate::Union{Float64,Nothing}
    nominal_discount_rate::Union{Float64,Nothing}
    inflation_rate::Union{Float64,Nothing}
    year::Int64
    binary_net_demand_and_exports_linkage::Bool
    binary_pv_capacity_and_exports_linkage::Bool
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
    nem_version::Int64
    nem_2_non_bypassable_charge::Union{Float64,Nothing}
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
    simple_shift_enabled::Bool
    shed_enabled::Bool
    shift_up_capacity_profile::Union{DataFrames.DataFrame,Nothing}
    shift_down_capacity_profile::Union{DataFrames.DataFrame,Nothing}
    shift_percent::Union{Float64,Nothing}
    shift_duration::Union{Int64,Nothing}
    shift_up_cost::Float64
    shift_down_cost::Float64
    value_of_lost_load::Float64
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
    maximum_power_capacity::Union{Float64,Nothing}
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
    nonexport::Bool
    capital_cost::Union{Float64,Nothing}
    fixed_om_cost::Union{Float64,Nothing}
    collector_azimuth::Union{Float64,Nothing}
    tilt_angle::Union{Float64,Nothing}
    ground_reflectance::String
    tracker::String
    inverter_eff::Float64
    lifespan::Union{Int64,Nothing}
    investment_tax_credit::Union{Float64,Nothing}
end

"""
    Storage

A struct to hold information about the specifications of the battery energy storage 
(BES) system.
"""
Base.@kwdef struct Storage
    enabled::Bool
    power_capacity::Union{Float64,Nothing}
    maximum_power_capacity::Union{Float64,Nothing}
    duration::Union{Float64,Nothing}
    soc_min::Float64
    soc_max::Float64
    soc_initial::Float64
    roundtrip_eff::Float64
    loss_rate::Float64
    nonexport::Bool
    nonimport::Bool
    power_capital_cost::Union{Float64,Nothing}
    fixed_om_cost::Union{Float64,Nothing}
    lifespan::Union{Int64,Nothing}
    investment_tax_credit::Union{Float64,Nothing}
end

"""
    Sets

A struct to hold information on the useful sets and reduced profiles being used in the 
simulation at a given time.
"""
Base.@kwdef struct Sets
    start_date::Dates.Date
    end_date::Dates.Date
    demand::Vector{Float64}
    solar_capacity_factor_profile::Union{Vector{Float64},Nothing}
    shift_up_capacity::Union{Vector{Float64},Nothing}
    shift_down_capacity::Union{Vector{Float64},Nothing}
    energy_prices::Union{Vector{Float64},Nothing}
    tiered_energy_rates::Union{Dict,Nothing}
    num_tiered_energy_rates_tiers::Union{Int64,Nothing}
    demand_prices::Union{Vector{Float64},Nothing}
    demand_mask::Union{Dict,Nothing}
    demand_charge_label_to_id::Union{Dict,Nothing}
    previous_monthly_max_demand::Union{Vector{Float64},Nothing}
    nem_prices::Union{Vector{Float64},Nothing}
    bes_initial_soc::Union{Float64,Nothing}
    num_time_steps::Int64
    num_demand_charge_periods::Int64
end
