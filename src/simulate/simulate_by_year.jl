"""
    simulate_by_year(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incetives,
        demand::Demand,
        solar::Solar,
        storage::Storage,
        time_series_results::DataFrames.DataFrame,
        output_filepath::Union{String,Nothing}=nothing,
    )

Simulate the optimization problem using optimization horizons of one year. Store the 
necessary results.
"""
function simulate_by_year(
    scenario::Scenario,
    tariff::Tariff,
    market::Market,
    incentives::Incentives,
    demand::Demand,
    solar::Solar,
    storage::Storage,
    time_series_results::DataFrames.DataFrame,
    output_filepath::Union{String,Nothing}=nothing,
)
    # Identify the start and end dates
    start_date = Dates.Date(scenario.year, 1, 1)
    end_date = Dates.Date(scenario.year, 12, 31)

    # Create the sets of useful parameters
    sets = create_sets(
        start_date,
        end_date,
        storage.soc_initial,
        scenario,
        tariff,
        demand,
        solar,
        storage,
    )

    # Formulate the optimization problem
    m = build_optimization_model(
        scenario,
        tariff,
        market,
        incentives,
        demand,
        solar,
        storage,
        sets,
    )

    # Solve the optimization problem
    JuMP.optimize!(m)

    # Store the necessary time-series results
    store_time_series_results!(m, sets, time_series_results, start_date, end_date)

    # Store the time-series results, if desired
    if !isnothing(output_filepath)
        CSV(join(output_filepath, "time_series_results.csv"), time_series_results)
    end

    # Return the results
    return time_series_results
end
