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
    tariff = create_rate_profiles(scenario, tariff)
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
    )

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
)
    # Initialize the results DateFrame
    time_series_results = initialize_time_series_results(tariff, solar, storage)

    # Perform the simulation, depending on the optimization horizon
    if scenario.optimization_horizon == "DAY"
        time_series_results = simulate_by_day(
            scenario,
            tariff,
            market,
            incentives,
            demand,
            solar,
            storage,
            time_series_results,
            output_filepath,
        )
    elseif scenario.optimization_horizon == "MONTH"
        time_series_results = simulate_by_month(
            scenario,
            tariff,
            market,
            incentives,
            demand,
            solar,
            storage,
            time_series_results,
            output_filepath,
        )
    elseif scenario.optimization_horizon == "YEAR"
        time_series_results = simulate_by_year(
            scenario,
            tariff,
            market,
            incentives,
            demand,
            solar,
            storage,
            time_series_results,
            output_filepath,
        )
    end

    # Return the time-series results
    return time_series_results
end
