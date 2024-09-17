"""
    simulate_by_month(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incetives,
        demand::Demand,
        solar::Solar,
        storage::Storage;
        output_filepath::Union{String,Nothing}=nothing,
        save_optimizer_log::Bool=false,
    )::Tuple{DataFrames.DataFrame,Dict}

Simulate the optimization problem using optimization horizons of one month. Store the 
necessary results.
"""
function simulate_by_month(
    scenario::Scenario,
    tariff::Tariff,
    market::Market,
    incentives::Incentives,
    demand::Demand,
    solar::Solar,
    storage::Storage;
    output_filepath::Union{String,Nothing}=nothing,
    save_optimizer_log::Bool=false,
)::Tuple{DataFrames.DataFrame,Dict}
    # Initialize the time-series results DataFrame
    time_series_results = initialize_time_series_results(tariff, demand, solar, storage)

    # Set initial state of charge for the battery energy storage (BES) system, if enabled
    if storage.enabled
        bes_initial_soc = storage.soc_initial
    else
        bes_initial_soc = nothing
    end

    # Loop through the different months
    for i = 1:12
        # Identify the start and end dates
        start_date = Dates.Date(scenario.year, i, 1)
        end_date = Dates.Date(scenario.year, i, Dates.daysinmonth(scenario.year, i))

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

        # Allow the optimizer log to be saved, if desired
        if save_optimizer_log & !isnothing(output_filepath)
            if scenario.optimization_solver == "GUROBI"
                i_str = length(string(i)) > 1 ? string(i) : "0" * string(i)
                JuMP.set_optimizer_attribute(
                    m,
                    "LogFile",
                    joinpath(output_filepath, "optimizer_" * i_str * ".log"),
                )
            else
                throw(
                    ErrorException(
                        "The log file for the " *
                        scenario.optimization_solver *
                        " optimizer cannot be saved. Please try again.",
                    ),
                )
            end
        end

        # Solve the optimization problem
        JuMP.optimize!(m)

        # Check that the optimization problem was solved succesfully
        if JuMP.termination_status(m) != JuMP.MOI.OPTIMAL
            if JuMP.termination_status(m) == JuMP.MOI.TIME_LIMIT
                if JuMP.result_count(m) == 0
                    throw(
                        ErrorException(
                            "Optimization problem failed to yield a feasible solution " *
                            "within the allotted time. Please try again.",
                        ),
                    )
                end
            else
                throw(
                    ErrorException(
                        "Optimization problem failed to solve. Please try again.",
                    ),
                )
            end
        end

        # Store the necessary time-series results
        store_time_series_results!(
            m,
            scenario,
            sets,
            time_series_results,
            start_date,
            end_date,
        )

        # Pass final state of charge from this pass to initial state of charge of the next
        if storage.enabled
            if (storage.power_capacity == 0) | (storage.duration == 0)
                bes_initial_soc = storage.soc_initial
            else
                bes_initial_soc =
                    last(JuMP.value.(m[:soc])) / (storage.duration * storage.power_capacity)
            end
        else
            bes_initial_soc = nothing
        end
    end

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

    # Return the results
    return time_series_results, electricity_bill
end
