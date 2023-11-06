"""
    load_and_preprocess_data(input_filepath::String)

Loads and preprocesses the data needed to run a simulation. Returns data in the appropriate 
objects.
"""
function load_and_preprocess_data(input_filepath::String)
    # Load all the simulation data
    scenario = read_scenario(input_filepath)
    tariff = read_tariff(input_filepath)
    market = read_market(input_filepath)
    incentives = read_incentives(input_filepath)
    demand = read_demand(input_filepath)
    solar = read_solar(input_filepath)
    storage = read_storage(input_filepath)
    println("All data is loaded!")

    # Perform extra preprocessing of input data, as necessary
    demand = adjust_demand_profiles(scenario, demand)
    tariff = create_rate_profiles(scenario, tariff, input_filepath)
    if solar.enabled & isnothing(solar.capacity_factor_profile)
        solar = create_solar_capacity_factor_profile(scenario, solar)
    end
    println("All data preprocessing complete!")

    # Return the created objects
    return scenario, tariff, market, incentives, demand, solar, storage
end

"""
    solve_problem(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incentives,
        demand::Demand,
        solar::Solar,
        storage::Storage,
        output_filepath::Union{String,Nothing}=nothing,
    )::Dict

Solve the specified optimization problem using one of the provided solution methods.
"""
function solve_problem(
    scenario::Scenario,
    tariff::Tariff,
    market::Market,
    incentives::Incentives,
    demand::Demand,
    solar::Solar,
    storage::Storage,
    output_filepath::Union{String,Nothing}=nothing,
)::Dict
    # Initialize results Dict; holds time-series results, investment results (if applicable)
    results = Dict{String,Union{DataFrames.DataFrame,Dict}}()

    # Initialize the time-series results DataFrame
    results["time-series"] = initialize_time_series_results(tariff, demand, solar, storage)

    # Perform the simulation, depending on problem type and optimization horizon
    if (scenario.problem_type == "PCM") &
       (scenario.optimization_horizon in ["DAY", "MONTH", "YEAR"])
        if scenario.optimization_horizon == "DAY"
            results["time-series"] = simulate_by_day(
                scenario,
                tariff,
                market,
                incentives,
                demand,
                solar,
                storage,
                results["time-series"],
                output_filepath,
            )
        elseif scenario.optimization_horizon == "MONTH"
            results["time-series"] = simulate_by_month(
                scenario,
                tariff,
                market,
                incentives,
                demand,
                solar,
                storage,
                results["time-series"],
                output_filepath,
            )
        elseif scenario.optimization_horizon == "YEAR"
            results["time-series"], _ = simulate_by_year(
                scenario,
                tariff,
                market,
                incentives,
                demand,
                solar,
                storage,
                results["time-series"],
                output_filepath,
            )
        end

        # Return the time-series results
        return results
    elseif (scenario.problem_type == "CEM") &
           (scenario.optimization_horizon in ["YEAR", "MULTIPLE_YEARS"])
        if scenario.optimization_horizon == "YEAR"
            results["time-series"], results["investment"] = simulate_by_year(
                scenario,
                tariff,
                market,
                incentives,
                demand,
                solar,
                storage,
                results["time-series"],
                output_filepath,
            )
        elseif scenario.optimization_horizon == "MULTIPLE_YEARS"
            results["time-series"], results["investment"] = simulate_over_multiple_years(
                scenario,
                tariff,
                market,
                incentives,
                demand,
                solar,
                storage,
                results["time-series"],
                output_filepath,
            )
        end

        # Return the time-series results and investment results
        return results
    else
        throw(
            ErrorException(
                "An optimization horizon of one " *
                lowercase(scnenario.optimization_horizon) *
                " is not supported for " *
                scenario.problem_type *
                " problems. Please try again.",
            ),
        )
    end
end
