"""
    store_investment_cost_results!(
        m::JuMP.Model,
        sets::Sets,
        investment_cost_results::Dict{String,Any},
    )

Store and update the Dict of investment-cost results used in the simulation. Include values 
from the JuMP optimization model and the Sets object.
"""
function store_investment_cost_results!(
    m::JuMP.Model,
    sets::Sets,
    investment_cost_results::Dict{String,Any},
)
    return nothing
end
