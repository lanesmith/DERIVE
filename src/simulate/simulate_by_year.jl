"""
    simulate_by_year(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incetives,
        demand::Demand,
        solar::Solar,
        storage::Storage,
        output_folder::Union{String,Nothing}=nothing,
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
    output_folder::Union{String,Nothing}=nothing,
)
    # Create the sets of useful parameters
    sets = create_sets(
        Dates.Date(scenario.year, 1, 1),
        Dates.Date(scenario.year, 12, 31),
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
end
