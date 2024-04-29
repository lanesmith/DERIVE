"""
    store_investment_cost_results(
        m::JuMP.Model,
        solar::Solar,
        storage::Storage,
        output_filepath::Union{String,Nothing}=nothing,
    )::Dict{String,Any}

Store and update the Dict of investment cost results used in the simulation. Include values 
from the JuMP optimization model and the Solar and Storage objects. Allows results to be 
saved, if desired.
"""
function store_investment_cost_results(
    m::JuMP.Model,
    solar::Solar,
    storage::Storage,
    output_filepath::Union{String,Nothing}=nothing,
)::Dict{String,Any}
    # Initialize the investment cost results
    investment_cost_results = Dict{String,Any}()

    if solar.enabled
        # Store the solar photovoltaic (PV) capacity
        investment_cost_results["solar_capacity"] = JuMP.value(m[:pv_capacity])

        # Store the solar unit cost (i.e., $/kW cost)
        investment_cost_results["solar_unit_cost"] = solar.capital_cost

        # Store the total capital cost (not including fixed O&M cost) of the solar PV system
        investment_cost_results["solar_capital_cost"] =
            JuMP.value(m[:pv_capacity]) * solar.capital_cost
    end

    if storage.enabled
        # Store the total battery energy sotrage (BES) power capacity
        investment_cost_results["storage_capacity"] = JuMP.value(m[:bes_power_capacity])

        # Store the BES duration (in hours)
        investment_cost_results["storage_duration"] = storage.duration

        # Store the storage unit cost (i.e., $/kW cost for a specific duration)
        investment_cost_results["storage_unit_cost"] = storage.power_capital_cost

        # Store the total capital cost (not including fixed O&M cost) of the BES system
        investment_cost_results["storage_capital_cost"] =
            JuMP.value(m[:bes_power_capacity]) * storage.power_capital_cost
    end

    # Save the electricity bill results, if desired
    if !isnothing(output_filepath)
        CSV.write(
            joinpath(output_filepath, "investment_cost_results.csv"),
            investment_cost_results;
            header=["parameter", "value"],
        )
    end

    # Return the investment cost results
    return investment_cost_results
end
