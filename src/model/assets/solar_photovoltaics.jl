"""
    define_solar_photovoltaic_model!(
        m::JuMP.Model,
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
        sets::Sets,
    )

Sets the decision variables and constraints associated with the solar photovoltaic (PV) 
system model.
"""
function define_solar_photovoltaic_model!(
    m::JuMP.Model,
    scenario::Scenario,
    tariff::Tariff,
    solar::Solar,
    sets::Sets,
)
    # Create variables related to a solar photovoltaic (PV) system
    define_solar_pv_variables!(m, scenario, tariff, solar, sets)

    # Update the expression for net demand
    JuMP.add_to_expression!.(m[:d_net], -1 .* m[:p_pv_btm])

    # Update the expression for total exports, if net energy metering is enabled
    if tariff.nem_enabled & !solar.nonexport
        JuMP.add_to_expression!.(m[:p_exports], m[:p_pv_exp])
    end

    # Create contraints related to solar PV
    define_solar_pv_generation_upper_bound!(m, scenario, tariff, solar, sets)
end

"""
    define_solar_pv_variables!(
        m::JuMP.Model,
        scenario::Scenario,
        solar::Solar,
        sets::Sets,
    )

Creates decision variables to determine the amount of solar photovoltaic (PV) generation 
that should be generated during each time step and, for capacity expansion modeling, the 
size of the solar PV system. PV generation is separated into the amount that is used to 
meet behind-the-meter (BTM) demand (i.e., considered in net demand) and the amount that is 
exported to the grid (e.g., through a net metering program).
"""
function define_solar_pv_variables!(
    m::JuMP.Model,
    scenario::Scenario,
    tariff::Tariff,
    solar::Solar,
    sets::Sets,
)

    # Set the solar PV power generation variables for behind-the-meter (BTM) use
    JuMP.@variable(m, p_pv_btm[t in 1:(sets.num_time_steps)] >= 0)

    # Set the solar PV power generation variables for export use (e.g., for net metering)
    if tariff.nem_enabled & !solar.nonexport
        JuMP.@variable(m, p_pv_exp[t in 1:(sets.num_time_steps)] >= 0)
    end

    # Set the PV system capacity variable, if performing capacity expansion
    if scenario.problem_type == "CEM"
        if isnothing(solar.maximum_system_capacity)
            JuMP.@variable(m, pv_capacity >= 0)
        else
            JuMP.@variable(m, 0 <= pv_capacity <= solar.maximum_system_capacity)
        end
    end
end

"""
    define_solar_pv_generation_upper_bound!(
        m::JuMP.Model,
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
        sets::Sets,
    )

Linear inequality constraint that provides an upper bound on the amount of solar 
photovoltaic (PV) generation that can be generated in each time step. For production cost 
modeling, the upper bound is the product of the solar capacity factor profile and the user-
specified solar PV system capacity. For capacity expansion modeling, the upper bound is the 
product of the solar capacity factor profile and the solar PV system capacity decision 
variable.
"""
function define_solar_pv_generation_upper_bound!(
    m::JuMP.Model,
    scenario::Scenario,
    tariff::Tariff,
    solar::Solar,
    sets::Sets,
)
    # Set the upper bound for the PV power generation variable
    if scenario.problem_type == "CEM"
        if tariff.nem_enabled & !solar.nonexport
            JuMP.@constraint(
                m,
                pv_upper_bound[t in 1:(sets.num_time_steps)],
                m[:p_pv_btm][t] + m[:p_pv_exp][t] <=
                sets.solar_capacity_factor_profile[t] *
                m[:pv_capacity] *
                solar.inverter_eff
            )
        else
            JuMP.@constraint(
                m,
                pv_upper_bound[t in 1:(sets.num_time_steps)],
                m[:p_pv_btm][t] <=
                sets.solar_capacity_factor_profile[t] *
                m[:pv_capacity] *
                solar.inverter_eff
            )
        end
    else
        if tariff.nem_enabled & !solar.nonexport
            JuMP.@constraint(
                m,
                pv_upper_bound[t in 1:(sets.num_time_steps)],
                m[:p_pv_btm][t] + m[:p_pv_exp][t] <=
                sets.solar_capacity_factor_profile[t] *
                solar.power_capacity *
                solar.inverter_eff
            )
        else
            JuMP.@constraint(
                m,
                pv_upper_bound[t in 1:(sets.num_time_steps)],
                m[:p_pv_btm][t] <=
                sets.solar_capacity_factor_profile[t] *
                solar.power_capacity *
                solar.inverter_eff
            )
        end
    end
end

"""
    define_solar_pv_capital_cost_objective!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        solar::Solar,
    )

Adds the capital costs and fixed operation and maintenance (O&M) costs associated with 
building a solar photovoltaic (PV) system to the objective function. Captial costs 
associated with the power capacity of the PV system are required. Including fixed O&M costs 
is not required.
"""
function define_solar_pv_capital_cost_objective!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    solar::Solar,
)
    # Add the amortized capital cost of building the determined PV system to the objective 
    # function
    if isnothing(solar.capital_cost)
        throw(
            ErrorException(
                "No capital cost is specified for the generation capacity of " *
                "solar PVs. Please try again.",
            ),
        )
    else
        JuMP.add_to_expression!(obj, solar.capital_cost * m[:pv_capacity] / solar.lifespan)
    end

    # Add the annual fixed operation and maintenance (O&M) cost associated with building 
    # the determined PV system to the objective function
    if !isnothing(solar.fixed_om_cost)
        JuMP.add_to_expression!(obj, solar.fixed_om_cost * m[:pv_capacity])
    end
end
