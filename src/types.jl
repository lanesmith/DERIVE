"""
    Scenario

A struct to hold information about the specific scenario under investigation.
"""
Base.@kwdef struct Scenario
    problem_type::String
    interval_length::Int32
end


"""
    Tariff

A struct to hold information about the different prices and characteristics of the 
electricity tariff offered by a utility.
"""
Base.@kwdef struct Tariff
    utility_name::Union{String, Nothing}
    tariff_name::Union{String, Nothing}
    demand_price::DataFrames.DataFrame
    energy_price::DataFrames.DataFrame
    nem_enabled::Bool
    nem_rate::Union{DataFrames.DataFrame, Nothing}
end


"""
    Market

A struct to hold information about the different prices and characteristics of different 
market products offered by an independent system operator (ISO).
"""
Base.@kwdef struct Market
    iso_name::Union{String, Nothing}
    reg_up_enabled::Bool
    reg_up_price::Union{DataFrames.DataFrame, Nothing}
    reg_dn_enabled::Bool
    reg_dn_price::Union{DataFrames.DataFrame, Nothing}
    sp_res_enabled::Bool
    sp_res_price::Union{DataFrames.DataFrame, Nothing}
    ns_res_enabled::Bool
    ns_res_price::Union{DataFrames.DataFrame, Nothing}
end


"""
    Incentives

A struct to hold information about the different prices and characteristics of different 
distributed energy resource (DER) incentive programs.
"""
Base.@kwdef struct Incentives
    itc_enabled::Bool
    itc_rate::Union{Float64, Nothing}
    sgip_enabled::Bool
    sgip_rate::Union{Float64, Nothing}
end


"""
    Demand

A struct to hold information about the consumer's base demand profile and any relevant 
characteristics about the consumer's base demand.
"""
Base.@kwdef struct Demand
    demand_profile::DataFrames.DataFrame
    shift_enabled::Bool
    shift_percentage::Union{Float64, Nothing}
    shift_duration::Union{Int32, Nothing}
end


"""
    Solar

A struct to hold information about the photovoltaic (PV) generation profile and any 
necessary PV module and array specifications.
"""
Base.@kwdef struct Solar
    enabled::Bool
    generation_profile::Union{DataFrames.DataFrame, Nothing}
    power_capacity::Union{Int32, Nothing}
    pv_capital_cost::Union{Float64, Nothing}
    inverter_eff::Union{Float64, Nothing}
    inverter_capital_cost::Union{Float64, Nothing}
end


"""
    Storage

A struct to hold information about the specifications of the battery energy storage 
(BES) system.
"""
Base.@kwdef struct Storage
    enabled::Bool
    power_capacity::Union{Int32, Nothing}
    energy_capacity::Union{Int32, Nothing}
    charge_eff::Union{Float64, Nothing}
    discharge_eff::Union{Float64, Nothing}
    capital_cost::Union{Float64, Nothing}
    lifespan::Union{Int32, Nothing}
end
