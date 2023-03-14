"""
    define_solar_photovoltaic_model!(
        m::JuMP.Model,
        scenario::Scenario,
        solar::Solar,
        sets::Sets,
    )

Sets the decision variables and constraints associated with the solar photovoltaic (PV) 
system model.
"""
function define_solar_photovoltaic_model!(
    m::JuMP.Model,
    scenario::Scenario,
    solar::Solar,
    sets::Sets,
)
    # Create variables related to a solar photovoltaic (PV) system
    define_solar_pv_variables!(m, scenario, solar, sets)

    # Update the expression for net demand
    add_to_expression!(m[:d_net], -1 .* m[:p_pv])

    # Create contraints related to solar PV
    define_solar_pv_generation_upper_bound!(m, scenario, solar, sets)
end

"""
    define_solar_pv_variables!(
        m::JuMP.Model,
        scenario::Scenario,
        solar::Solar,
        sets::Sets,
    )

Creates decision variables to determine the amount of solar photovoltaic (PV) generation 
that should be created during each time step and, for capacity expansion modeling, the size 
of the solar PV system.
"""
function define_solar_pv_variables!(
    m::JuMP.Model,
    scenario::Scenario,
    solar::Solar,
    sets::Sets,
)
    # Set the solar PV power generation variables
    @variable(m, p_pv[t in 1:(sets.num_time_steps)] >= 0)

    # Set the PV system capacity variable, if performing capacity expansion
    if scenario.problem_type == "CEM"
        if isnothing(solar.maximum_system_capacity)
            @variable(m, pv_capacity >= 0)
        else
            @variable(m, 0 <= pv_capacity <= solar.maximum_system_capacity)
        end
    end
end

"""
    define_solar_pv_generation_upper_bound!(
        m::JuMP.Model,
        scenario::Scenario,
        solar::Solar,
        sets::Sets,
    )

Linear inequality constraint that provides an upper bound on the amount of solar 
photovoltaic (PV) generation can be generated in each time step. For production cost 
modeling, the upper bound is the product of the solar capacity factor profile and the user-
specified solar PV system capacity. For capacity expansion modeling, the upper bound is the 
product of the solar capacity factor profile and the solar PV system capacity decision 
variable.
"""
function define_solar_pv_generation_upper_bound!(
    m::JuMP.Model,
    scenario::Scenario,
    solar::Solar,
    sets::Sets,
)
    # Set the upper bound for the PV power generation variable
    if scenario.problem_type == "CEM"
        @constraint(
            m,
            pv_upper_bound[t in 1:(sets.num_time_steps)],
            m[:p_pv][t] <= sets.solar_capacity_factor_profile[t] * m[:pv_capacity]
        )
    else
        @constraint(
            m,
            pv_upper_bound[t in 1:(sets.num_time_steps)],
            m[:p_pv][t] <= sets.solar_capacity_factor_profile[t] * solar.power_capacity
        )
    end
end
