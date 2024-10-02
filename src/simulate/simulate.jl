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
    if solar.enabled
        if isnothing(solar.capacity_factor_profile)
            solar = create_solar_capacity_factor_profile(scenario, solar)
        else
            solar = adjust_solar_capacity_factor_profile(scenario, solar)
        end
    end
    tariff = create_rate_profiles(scenario, tariff, solar, input_filepath)
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
        storage::Storage;
        output_filepath::Union{String,Nothing}=nothing,
        save_optimizer_log::Bool=false,
    )::Dict{String,Union{DataFrames.DataFrame,Dict}}

Solve the specified optimization problem using one of the provided solution methods.
"""
function solve_problem(
    scenario::Scenario,
    tariff::Tariff,
    market::Market,
    incentives::Incentives,
    demand::Demand,
    solar::Solar,
    storage::Storage;
    output_filepath::Union{String,Nothing}=nothing,
    save_optimizer_log::Bool=false,
)::Dict{String,Union{DataFrames.DataFrame,Dict}}
    # Create a directory that corresponds to the specified output filepath, if applicable
    if !isnothing(output_filepath)
        if !isdir(output_filepath)
            mkpath(output_filepath)
        end
    end

    # Initialize results Dict; holds time-series results, electricity bill results, and 
    # investment results (if applicable)
    results = Dict{String,Union{DataFrames.DataFrame,Dict}}()

    # Perform the simulation, depending on problem type and optimization horizon
    if (scenario.problem_type == "PCM") &
       (scenario.optimization_horizon in ["DAY", "MONTH", "YEAR"])
        if scenario.optimization_horizon == "DAY"
            results["time-series"], results["electricity_bill"] = simulate_by_day(
                scenario,
                tariff,
                market,
                incentives,
                demand,
                solar,
                storage;
                output_filepath=output_filepath,
                save_optimizer_log=save_optimizer_log,
            )
        elseif scenario.optimization_horizon == "MONTH"
            results["time-series"], results["electricity_bill"] = simulate_by_month(
                scenario,
                tariff,
                market,
                incentives,
                demand,
                solar,
                storage;
                output_filepath=output_filepath,
                save_optimizer_log=save_optimizer_log,
            )
        elseif scenario.optimization_horizon == "YEAR"
            results["time-series"], results["electricity_bill"], _ = simulate_by_year(
                scenario,
                tariff,
                market,
                incentives,
                demand,
                solar,
                storage;
                output_filepath=output_filepath,
                save_optimizer_log=save_optimizer_log,
            )
        end
    elseif (scenario.problem_type == "CEM") & (scenario.optimization_horizon in ["YEAR"])
        if scenario.optimization_horizon == "YEAR"
            results["time-series"], results["electricity_bill"], results["investment"] =
                simulate_by_year(
                    scenario,
                    tariff,
                    market,
                    incentives,
                    demand,
                    solar,
                    storage;
                    output_filepath=output_filepath,
                    save_optimizer_log=save_optimizer_log,
                )
        end
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

    # Return the time-series results, electricity bill results, and investment results (if 
    # applicable)
    return results
end
