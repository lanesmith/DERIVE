"""
    simulate_by_day(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incetives,
        demand::Demand,
        solar::Solar,
        storage::Storage,
        time_series_results::DataFrames.DataFrame,
        output_filepath::Union{String,Nothing}=nothing,
    )::DataFrames.DataFrame

Simulate the optimization problem using optimization horizons of one day. Store the 
necessary results.
"""
function simulate_by_day(
    scenario::Scenario,
    tariff::Tariff,
    market::Market,
    incentives::Incentives,
    demand::Demand,
    solar::Solar,
    storage::Storage,
    time_series_results::DataFrames.DataFrame,
    output_filepath::Union{String,Nothing}=nothing,
)::DataFrames.DataFrame
    # Set initial state of charge for the battery energy storage (BES) system, if enabled
    if storage.enabled
        bes_initial_soc = storage.soc_initial
    else
        bes_initial_soc = nothing
    end

    # Loop through the different months
    for i = 1:12
        # Set the current relevant monthly maximum demand values
        current_monthly_max_demand = nothing

        # Loop through the different days in the given month
        for j = 1:Dates.daysinmonth(scenario.year, i)
            # Identify the start and end dates
            start_date = Dates.Date(scenario.year, i, j)
            end_date = Dates.Date(scenario.year, i, j)

            # Create the sets of useful parameters
            sets = create_sets(
                start_date,
                end_date,
                bes_initial_soc,
                scenario,
                tariff,
                demand,
                solar,
                storage;
                current_monthly_max_demand=current_monthly_max_demand,
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
                throw(
                    ErrorException(
                        "Optimization problem failed to solve. Please try again.",
                    ),
                )
            end

            # Store the necessary time-series results
            store_time_series_results!(m, sets, time_series_results, start_date, end_date)

            # Pass final state of charge (SOC) from this pass to the initial SOC of the next
            if storage.enabled
                bes_initial_soc = last(JuMP.value.(m[:soc])) / storage.energy_capacity
            else
                bes_initial_soc = nothing
            end

            # Pass the relevant monthly maximum demand values from this pass to the next
            if (j != Dates.daysinmonth(scenario.year, i)) & !isnothing(sets.demand_prices)
                current_monthly_max_demand = Dict{String,Any}()
                for (k, v) in sets.demand_charge_label_to_id
                    if occursin("monthly", k)
                        current_monthly_max_demand[k] = JuMP.value.(m[:d_max])[v]
                    end
                end
            end
        end
    end

    # Save the time-series results, if desired
    if !isnothing(output_filepath)
        CSV(join(output_filepath, "time_series_results.csv"), time_series_results)
    end

    # Return the results
    return time_series_results
end
