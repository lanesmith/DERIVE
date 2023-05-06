"""
    define_tou_energy_charge_onjective!(m::JuMP.Model, obj::JuMP.AffExpr, sets::Sets)

TBW
"""
function define_tou_energy_charge_objective!(m::JuMP.Model, obj::JuMP.AffExpr, sets::Sets)
    # Add time-of-use (TOU) energy charges to the objective function
    JuMP.add_to_expression!(obj, sum(m[:d_net] .* sets.energy_prices))
end

"""
    define_demand_charge_objective!(m::JuMP.Model, obj::Jump.AffExpr, sets::Sets)

TBW
"""
function define_demand_charge_objective!(m::JuMP.Model, obj::JuMP.AffExpr, sets::Sets)
    # Add demand charges to the objective function
    JuMP.add_to_expression!(obj, sum(m[:d_max] .* sets.demand_prices))
end

"""
    define_net_energy_metering_revenue_objective!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        sets::Sets,
    )

TBW
"""
function define_net_energy_metering_revenue_objective!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    sets::Sets,
)
    # Add revenue from net energy metering (NEM) to the objective function
    JuMP.add_to_expression!(obj, -1 * sum(m[:p_exports] .* sets.nem_prices))
end
