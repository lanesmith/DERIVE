"""
    simulate_by_day(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incetives,
        demand::Demand,
        solar::Solar,
        storage::Storage,
        output_folder::Union{String,Nothing}=nothing,
    )

Simulate the optimization problem using optimization horizons of one day. Store the 
necessary results.
"""
function simulate_by_day(
    scenario::Scenario,
    tariff::Tariff,
    market::Market,
    incentives::Incetives,
    demand::Demand,
    solar::Solar,
    storage::Storage,
    output_folder::Union{String,Nothing}=nothing,
)
    nothing
end
