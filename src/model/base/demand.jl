"""
    define_demand_variables!(m::JuMP.Model, tariff::Tariff, solar::Solar, sets::Sets)

Defines useful demand-related decision variables, namely the maximum net demand realized 
during different tariff-defined periods. Also creates an expression to define the behind-
the-meter net demand, which is updated in other functions to include the contributions of 
different included assets, and an expression to define the total power exported, which is 
updated in other functions to include the contributions of different included assets.
"""
function define_demand_variables!(m::JuMP.Model, tariff::Tariff, solar::Solar, sets::Sets)
    # Set the maximum net demand during different periods variables
    if !isnothing(sets.demand_prices)
        JuMP.@variable(m, d_max[p in 1:(sets.num_demand_charge_periods)] >= 0)
    end

    # Create expression for net demand; update according to program/resource participation
    JuMP.@expression(m, d_net[t in 1:(sets.num_time_steps)], JuMP.AffExpr(sets.demand[t]))

    # Create expression for total exports; update based on program/resource participation
    if tariff.nem_enabled & solar.enabled
        JuMP.@expression(m, p_exports[t in 1:(sets.num_time_steps)], JuMP.AffExpr())
    end
end

"""
    define_maximum_demand_during_periods_constraint!(m::JuMP.Model, sets::Sets)

Linear inequality constraint that further helps define the maximum net demand realized 
during different tariff-defined periods decision variable. Mathematically, the decision 
variable is greater than or equal to the product of the net demand and a demand charge 
period mask, which is one during time steps when a particular period is active and zero 
otherwise.
"""
function define_maximum_demand_during_periods_constraint!(m::JuMP.Model, sets::Sets)
    # Define the maximum net demand during different periods using an inequality constraint
    JuMP.@constraint(
        m,
        maximum_demand_during_periods_constraint[
            p in 1:(sets.num_demand_charge_periods),
            t in 1:(sets.num_time_steps),
        ],
        m[:d_max][p] >= sets.demand_mask[p][t] * m[:d_net][t]
    )
end

"""
    define_net_demand_nonexport_constraint!(m::JuMP.Model, sets::Sets)

Linear inequality constraint that prevents net demand from exporting to the grid. Exports 
from behind-the-meter solar photovoltaics (PVs), battery energy storage (BES), and flexible 
loads are handled separately from the net demand expression.
"""
function define_net_demand_nonexport_constraint!(m::JuMP.Model, sets::Sets)
    # Prevent net demand from exporting to the grid; exports are handled separately
    JuMP.@constraint(
        m,
        net_demand_nonexport_constraint[t in 1:(sets.num_time_steps)],
        m[:d_net][t] >= 0
    )
end

"""
    define_monthly_maximum_demand_under_daily_optimization_constraint!(
        m::JuMP.Model,
        sets::Sets,
    )

Linear inequality constraint applied only to scenarios in which the optimization horizon is 
equal to one day. This constraint ensures that the decision variables that describe monthly  
maximum demand values in the current optimization problem consider the corresponding 
monthly maximum demand values that were observed from the previous optimization problem 
(i.e., the previous day in the month). If considered in the scneario, daily maximum demand 
values from the previous optimization problem are set equal to zero (i.e., the maximum 
demand values from the previous day do not matter when computing daily maximum demand).
"""
function define_monthly_maximum_demand_under_daily_optimization_constraint!(
    m::JuMP.Model,
    sets::Sets,
)
    # Ensure that current monthly maximum demand considers previous monthly maximum demand
    JuMP.@constraint(
        m,
        monthly_maximum_demand_under_daily_optimization_constraint[p in 1:(sets.num_demand_charge_periods)],
        m[:d_max][p] >= sets.previous_monthly_max_demand[p]
    )
end
