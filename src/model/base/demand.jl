"""
    define_demand_variables!(m::JuMP.Model, tariff::Tariff, sets::Sets)

Defines useful demand-related decision variables, namely nonnegative net demand and the 
maximum net demand realized during different tariff-defined periods. Also creates an 
expression to define the behind-the-meter net demand, which is updated in other functions 
to include the contributions of different included assets, and an expression to define the 
total power exported, which is updated in other functions to include the contributions of 
different included assets.
"""
function define_demand_variables!(m::JuMP.Model, tariff::Tariff, sets::Sets)
    # Set the nonnegative net demand (i.e., grid imports) variables
    @variable(m, d_net_pos[t in 1:(sets.num_time_steps)] >= 0)

    # Set the maximum net demand during different periods variables
    @variable(m, d_max[p in 1:(sets.num_demand_charge_periods)] >= 0)

    # Create expression for net demand; update according to program/resource participation
    @expression(m, d_net[t in 1:(sets.num_time_steps)], AffExpr(sets.demand[t]))

    # Create expression for total exports; update based on program/resource participation
    if tariff.nem_enabled
        @expression(m, p_exports[t in 1:(sets.num_time_steps)], AffExpr())
    end
end

"""
    define_nonnegative_net_demand_constraint!(m::JuMP.Model, sets::Sets)

Linear inequality constraint that further helps define the nonnegative net demand decision 
variable. Mathematically, nonnegative net demand is the pointwise maximum of net demand at 
a given time step and zero. In a linear program, this is realized through two inequality 
constraints that make the nonnegative net demand decision variable greater than or equal to 
net demand and greater than or equal to zero at all time steps.
"""
function define_nonnegative_net_demand_constraint!(m::JuMP.Model, sets::Sets)
    # Define the nonnegative net demand variable using an inequality constraint
    @constraint(
        m,
        nonnegative_net_demand_constraint[t in 1:(sets.num_time_steps)],
        m[:d_net][t] <= m[:d_net_pos][t]
    )
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
    @constraint(
        m,
        maximum_demand_during_periods_constraint[
            p in 1:(sets.num_demand_charge_periods),
            t in 1:(sets.num_time_steps),
        ],
        sets.demand_mask[p][t] * m[:d_net][t] <= m[:d_max][p]
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
    @constraint(
        m,
        net_demand_nonexport_constraint[t in 1:(sets.num_time_steps)],
        m[:d_net][t] >= 0
    )
end
