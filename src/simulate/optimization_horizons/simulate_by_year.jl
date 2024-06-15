"""
    simulate_by_year(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incetives,
        demand::Demand,
        solar::Solar,
        storage::Storage,
        output_filepath::Union{String,Nothing}=nothing,
    )::Tuple{DataFrames.DataFrame,Dict}

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
    output_filepath::Union{String,Nothing}=nothing,
)::Tuple{DataFrames.DataFrame,Dict,Union{Dict,Nothing}}
    # Initialize the time-series results DataFrame
    time_series_results = initialize_time_series_results(tariff, demand, solar, storage)

    # Set initial state of charge for the battery energy storage (BES) system, if enabled
    if storage.enabled
        bes_initial_soc = storage.soc_initial
    else
        bes_initial_soc = nothing
    end

    # Identify the start and end dates
    start_date = Dates.Date(scenario.year, 1, 1)
    end_date = Dates.Date(scenario.year, 12, 31)

    # Create the sets of useful parameters
    sets = create_sets(
        start_date,
        end_date,
        bes_initial_soc,
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

    # Check that the optimization problem was solved succesfully
    if JuMP.termination_status(m) != JuMP.MOI.OPTIMAL
        throw(ErrorException("Optimization problem failed to solve. Please try again."))
    end

    # Store the necessary time-series results
    store_time_series_results!(m, scenario, sets, time_series_results, start_date, end_date)

    # Save the time-series results, if desired
    if !isnothing(output_filepath)
        CSV.write(joinpath(output_filepath, "time_series_results.csv"), time_series_results)
    end

    # Caluclate the electricity bill components
    electricity_bill = calculate_electricity_bill(
        scenario,
        tariff,
        solar,
        time_series_results,
        output_filepath,
    )

    # Store the investment-cost results, if applicable
    if scenario.problem_type == "CEM"
        investment_cost_results =
            store_investment_cost_results(m, scenario, solar, storage, output_filepath)
    else
        investment_cost_results = nothing
    end

    # Return the results
    return time_series_results, electricity_bill, investment_cost_results
end
