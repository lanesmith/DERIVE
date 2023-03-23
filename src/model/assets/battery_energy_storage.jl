"""
    define_battery_energy_storage_model!(
        m::JuMP.Model,
        scenario::Scenario,
        tariff::Tariff,
        storage::Storage,
        sets::Sets,
    )

Sets the decision variables and constraints associated with the battery energy storage 
(BES) model.
"""
function define_battery_energy_storage_model!(
    m::JuMP.Model,
    scenario::Scenario,
    tariff::Tariff,
    storage::Storage,
    sets::Sets,
)
    # Create variables related to battery energy storage (BES)
    define_bes_variables!(m, scenario, storage, sets)

    # Update the expression for net demand
    JuMP.add_to_expression!.(m[:d_net], m[:p_cha])
    JuMP.add_to_expression!.(m[:d_net], -1 .* m[:p_dis_btm])

    # Update the expression for total exports, if net metering and BES exports are enabled
    if tariff.nem_enabled & !storage.nonexport
        JuMP.add_to_expression!.(m[:p_exports], m[:p_dis_exp])
    end

    # Create constraints related to BES
    define_bes_soc_energy_conservation!(m, scenario, storage, sets)
    define_bes_final_soc_constraint!(m, scenario, storage, sets)
    define_bes_charging_upper_bound!(m, scenario, storage, sets)
    define_bes_discharging_upper_bound!(m, scenario, storage, sets)
    define_bes_soc_lower_bound!(m, scenario, storage, sets)
    define_bes_soc_upper_bound!(m, scenario, storage, sets)
end

"""
    define_bes_variables!(
        m::JuMP.Model,
        scenario::Scenario,
        storage::Storage,
        sets::Sets,
    )

Creates decision variables to determine the charging power, discharging power, and state of 
charge of the battery energy storage (BES) model. For capacity expansion, decision 
variables that determine the BES power capacity and energy capacity are created. If the 
duration parameter is provided for BES, the energy capacity decision variable is not 
created. Instead, the product of the duration parameter and the power capacity decision 
variable are used to emulate the BES energy capacity.
"""
function define_bes_variables!(
    m::JuMP.Model,
    scenario::Scenario,
    storage::Storage,
    sets::Sets,
)
    # Set the BES charge and discharge variables for behind-the-meter (BTM) use
    JuMP.@variable(m, p_cha[t in 1:(sets.num_time_steps)] >= 0)
    JuMP.@variable(m, p_dis_btm[t in 1:(sets.num_time_steps)] >= 0)

    # Set the BES discharge variables for export use (e.g., for net metering)
    if !storage.nonexport
        JuMP.@variable(m, p_dis_exp[t in 1:(sets.num_time_steps)] >= 0)
    end

    # Set the BES state of charge variable
    JuMP.@variable(m, soc[t in 1:(sets.num_time_steps)])

    # Set the BES power and energy capacity variables, if performing capacity expansion
    if scenario.problem_type == "CEM"
        # Set the BES power capacity to be unbounded or bounded, as specified
        if isnothing(storage.maximum_power_capacity)
            JuMP.@variable(m, bes_power_capacity >= 0)
        else
            JuMP.@variable(m, 0 <= bes_power_capacity <= storage.maximum_power_capacity)
        end

        # Check if duration parameter is provided to see if bes_energy_capacity is needed
        if isnothing(storage.duration)
            # Set the BES energy capacity to be unbounded or bounded, as specified
            if isnothing(storage.maximum_energy_capacity)
                JuMP.@variable(m, bes_energy_capacity >= 0)
            else
                JuMP.@variable(
                    m,
                    0 <= bes_energy_capacity <= storage.maximum_energy_capacity
                )
            end
        end
    end
end

"""
    define_bes_soc_energy_conservation!(
        m::JuMP.Model,
        scenario::Scenario,
        storage::Storage,
        sets::Sets,
    )

Linear equality constraints that maintain the battery energy storage (BES) state of charge. 
Separate constraints are provided for the first time step, which requires either a user-
defined initial state of charge or the final state of charge from a previous simulation, 
and the remaining time steps.
"""
function define_bes_soc_energy_conservation!(
    m::JuMP.Model,
    scenario::Scenario,
    storage::Storage,
    sets::Sets,
)
    # Determine whether or not the BES can export to the grid (i.e., is p_dis_exp included?)
    if storage.nonexport
        # Set equality constraint to maintain BES state of charge for the first time step
        if scenario.problem_type == "CEM"
            if isnothing(storage.duration)
                JuMP.@constraint(
                    m,
                    bes_soc_energy_conservation_initial,
                    m[:soc][1] ==
                    (1 - storage.loss_rate) *
                    sets.bes_initial_soc *
                    m[:bes_energy_capacity] + storage.charge_eff * m[:p_cha][1] -
                    (1 / storage.discharge_eff) * m[:p_dis_btm][1]
                )
            else
                JuMP.@constraint(
                    m,
                    bes_soc_energy_conservation_initial,
                    m[:soc][1] ==
                    (1 - storage.loss_rate) *
                    sets.bes_initial_soc *
                    storage.duration *
                    m[:bes_power_capacity] + storage.charge_eff * m[:p_cha][1] -
                    (1 / storage.discharge_eff) * m[:p_dis_btm][1]
                )
            end
        else
            JuMP.@constraint(
                m,
                bes_soc_energy_conservation_initial,
                m[:soc][1] ==
                (1 - storage.loss_rate) * sets.bes_initial_soc * storage.energy_capacity +
                storage.charge_eff * m[:p_cha][1] -
                (1 / storage.discharge_eff) * m[:p_dis_btm][1]
            )
        end

        # Set equality constraint to maintain BES state of charge for all other time steps
        JuMP.@constraint(
            m,
            bes_soc_energy_conservation[t in 1:(sets.num_time_steps - 1)],
            m[:soc][t + 1] ==
            (1 - storage.loss_rate) * m[:soc][t] + storage.charge_eff * m[:p_cha][t + 1] -
            (1 / storage.discharge_eff) * m[:p_dis_btm][t + 1]
        )
    else
        # Set equality constraint to maintain BES state of charge for the first time step
        if scenario.problem_type == "CEM"
            if isnothing(storage.duration)
                JuMP.@constraint(
                    m,
                    bes_soc_energy_conservation_initial,
                    m[:soc][1] ==
                    (1 - storage.loss_rate) *
                    sets.bes_initial_soc *
                    m[:bes_energy_capacity] + storage.charge_eff * m[:p_cha][1] -
                    (1 / storage.discharge_eff) * (m[:p_dis_btm][1] + m[:p_dis_exp][1])
                )
            else
                JuMP.@constraint(
                    m,
                    bes_soc_energy_conservation_initial,
                    m[:soc][1] ==
                    (1 - storage.loss_rate) *
                    sets.bes_initial_soc *
                    storage.duration *
                    m[:bes_power_capacity] + storage.charge_eff * m[:p_cha][1] -
                    (1 / storage.discharge_eff) * (m[:p_dis_btm][1] + m[:p_dis_exp][1])
                )
            end
        else
            JuMP.@constraint(
                m,
                bes_soc_energy_conservation_initial,
                m[:soc][1] ==
                (1 - storage.loss_rate) * sets.bes_initial_soc * storage.energy_capacity +
                storage.charge_eff * m[:p_cha][1] -
                (1 / storage.discharge_eff) * (m[:p_dis_btm][1] + m[:p_dis_exp][1])
            )
        end

        # Set equality constraint to maintain BES state of charge for all other time steps
        JuMP.@constraint(
            m,
            bes_soc_energy_conservation[t in 1:(sets.num_time_steps - 1)],
            m[:soc][t + 1] ==
            (1 - storage.loss_rate) * m[:soc][t] + storage.charge_eff * m[:p_cha][t + 1] -
            (1 / storage.discharge_eff) * (m[:p_dis_btm][t + 1] + m[:p_dis_exp][t + 1])
        )
    end
end

"""
    define_bes_final_soc_constraint!(
        m::JuMP.Model,
        scenario::Scenario,
        storage::Storage,
        sets::Sets,
    )

Linear inequality constraint that prevents the final state of charge from being less than 
the initial state of charge for battery energy storage (BES). This is established so the 
optimization problem does not completely discharge the BES by the end of the simulation, 
thereby unrealistically failing to recognize future optimization horizons, unless the 
initial state of charge was originally set to zero.
"""
function define_bes_final_soc_constraint!(
    m::JuMP.Model,
    scenario::Scenario,
    storage::Storage,
    sets::Sets,
)
    # Prevent BES final state of charge from being less than BES initial state of charge
    if scenario.problem_type == "CEM"
        if isnothing(storage.duration)
            JuMP.@constraint(
                m,
                bes_final_soc_constraint,
                m[:soc][sets.num_time_steps] >=
                sets.bes_initial_soc * m[:bes_energy_capacity]
            )
        else
            JuMP.@constraint(
                m,
                bes_final_soc_constraint,
                m[:soc][sets.num_time_steps] >=
                sets.bes_initial_soc * storage.duration * m[:bes_power_capacity]
            )
        end
    else
        JuMP.@constraint(
            m,
            bes_final_soc_constraint,
            m[:soc][sets.num_time_steps] >= sets.bes_initial_soc * storage.energy_capacity
        )
    end
end

"""
    define_bes_charging_upper_bound!(
        m::JuMP.Model,
        scenario::Scenario,
        storage::Storage,
        sets::Sets,
    )

Linear inequality constraint that sets an upper bound on the amount that battery energy 
storage (BES) can charge during a given time step. The upper bound is the BES power 
capacity.
"""
function define_bes_charging_upper_bound!(
    m::JuMP.Model,
    scenario::Scenario,
    storage::Storage,
    sets::Sets,
)
    # Set the upper bound for the BES charging power variable
    if scenario.problem_type == "CEM"
        JuMP.@constraint(
            m,
            bes_charging_upper_bound[t in 1:(sets.num_time_steps)],
            m[:p_cha][t] <= m[:bes_power_capacity]
        )
    else
        JuMP.@constraint(
            m,
            bes_charging_upper_bound[t in 1:(sets.num_time_steps)],
            m[:p_cha][t] <= storage.power_capacity
        )
    end
end

"""
    define_bes_discharging_upper_bound!(
        m::JuMP.Model,
        scenario::Scenario,
        storage::Storage,
        sets::Sets,
    )

Linear inequality constraint that sets an upper bound on the amount that battery energy 
storage (BES) can discharge during a given time step. The upper bound is the BES power 
capacity.
"""
function define_bes_discharging_upper_bound!(
    m::JuMP.Model,
    scenario::Scenario,
    storage::Storage,
    sets::Sets,
)
    # Determine whether or not the BES can export to the grid (i.e., is p_dis_exp included?)
    if storage.nonexport
        # Set the upper bound for the BES discharging power variable
        if scenario.problem_type == "CEM"
            JuMP.@constraint(
                m,
                bes_discharging_upper_bound[t in 1:(sets.num_time_steps)],
                m[:p_dis_btm][t] <= m[:bes_power_capacity]
            )
        else
            JuMP.@constraint(
                m,
                bes_discharging_upper_bound[t in 1:(sets.num_time_steps)],
                m[:p_dis_btm][t] <= storage.power_capacity
            )
        end
    else
        # Set the upper bound for the BES discharging power variable
        if scenario.problem_type == "CEM"
            JuMP.@constraint(
                m,
                bes_discharging_upper_bound[t in 1:(sets.num_time_steps)],
                m[:p_dis_btm][t] + m[:p_dis_exp][t] <= m[:bes_power_capacity]
            )
        else
            JuMP.@constraint(
                m,
                bes_discharging_upper_bound[t in 1:(sets.num_time_steps)],
                m[:p_dis_btm][t] + m[:p_dis_exp][t] <= storage.power_capacity
            )
        end
    end
end

"""
    define_bes_soc_lower_bound!(
        m::JuMP.Model,
        scenario::Scenario,
        storage::Storage,
        sets::Sets,
    )

Linear inequality constraint that sets a lower bound on the battery energy storage (BES) 
state of charge. The lower bound is the product of the BES energy capacity and the user-
defined minimum state of charge percentage.
"""
function define_bes_soc_lower_bound!(
    m::JuMP.Model,
    scenario::Scenario,
    storage::Storage,
    sets::Sets,
)
    # Set the lower bound for the BES state of charge variable
    if scenario.problem_type == "CEM"
        if isnothing(storage.duration)
            JuMP.@constraint(
                m,
                bes_soc_lower_bound[t in 1:(sets.num_time_steps)],
                m[:soc][t] >= storage.soc_min * m[:bes_energy_capacity]
            )
        else
            JuMP.@constraint(
                m,
                bes_soc_lower_bound[t in 1:(sets.num_time_steps)],
                m[:soc][t] >= storage.soc_min * storage.duration * m[:bes_power_capacity]
            )
        end
    else
        JuMP.@constraint(
            m,
            bes_soc_lower_bound[t in 1:(sets.num_time_steps)],
            m[:soc][t] >= storage.soc_min * storage.energy_capacity
        )
    end
end

"""
    define_bes_soc_upper_bound!(
        m::JuMP.Model,
        scenario::Scenario,
        storage::Storage,
        sets::Sets,
    )

Linear inequality constraint that sets an upper bound on the battery energy storage (BES) 
state of charge. The upper bound is the product of the BES energy capacity and the user-
defined maximum state of charge percentage.
"""
function define_bes_soc_upper_bound!(
    m::JuMP.Model,
    scenario::Scenario,
    storage::Storage,
    sets::Sets,
)
    # Set the upper bound for the BES state of charge variable
    if scenario.problem_type == "CEM"
        if isnothing(storage.duration)
            JuMP.@constraint(
                m,
                bes_soc_upper_bound[t in 1:(sets.num_time_steps)],
                m[:soc][t] <= storage.soc_max * m[:bes_energy_capacity]
            )
        else
            JuMP.@constraint(
                m,
                bes_soc_upper_bound[t in 1:(sets.num_time_steps)],
                m[:soc][t] <= storage.soc_max * storage.duration * m[:bes_power_capacity]
            )
        end
    else
        JuMP.@constraint(
            m,
            bes_soc_upper_bound[t in 1:(sets.num_time_steps)],
            m[:soc][t] <= storage.soc_max * storage.energy_capacity
        )
    end
end
