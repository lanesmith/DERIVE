"""
    simulate_by_month(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incetives,
        demand::Demand,
        solar::Solar,
        storage::Storage,
        output_folder::Union{String,Nothing}=nothing,
    )

Simulate the optimization problem using optimization horizons of one month. Store the 
necessary results.
"""
function simulate_by_month(
    scenario::Scenario,
    tariff::Tariff,
    market::Market,
    incentives::Incetives,
    demand::Demand,
    solar::Solar,
    storage::Storage,
    output_folder::Union{String,Nothing}=nothing,
)
    # Set the initial state of charge for the battery energy storage (BES) system
    bes_initial_soc = storage.soc_initial

    # Loop through the different months
    for i = 1:12
        # Identify the start and end dates
        start_date = Dates.Date(scenario.year, i, 1)
        last_date = Dates.Date(scenario.year, i, Dates.daysinmonth(scenario.year, i))

        # Create the sets of useful parameters
        sets = create_sets(
            start_date,
            last_date,
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
    end
end
