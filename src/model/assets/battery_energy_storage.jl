"""
    define_battery_energy_storage_model!(
        m::JuMP.Model,
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
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
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Create variables related to battery energy storage (BES)
    define_bes_variables!(m, scenario, tariff, solar, storage, sets)

    # Update the expression for net demand
    JuMP.add_to_expression!.(m[:d_net], m[:p_cha])
    JuMP.add_to_expression!.(m[:d_net], -1 .* m[:p_dis_btm])

    # Update the expression for total exports, if net metering and BES exports are enabled
    if tariff.nem_enabled & solar.enabled & !storage.nonexport
        JuMP.add_to_expression!.(m[:p_exports], m[:p_dis_exp])
    end

    # Create constraints related to BES
    define_bes_soc_energy_conservation!(m, scenario, tariff, solar, storage, sets)
    define_bes_final_soc_constraint!(m, scenario, storage, sets)
    define_bes_charging_upper_bound!(m, scenario, storage, sets)
    define_bes_discharging_upper_bound!(m, scenario, tariff, solar, storage, sets)
    define_bes_soc_lower_bound!(m, scenario, storage, sets)
    define_bes_soc_upper_bound!(m, scenario, storage, sets)
    define_bes_export_upper_bound!(m, scenario, tariff, solar, storage, sets)
end

"""
    define_bes_variables!(
        m::JuMP.Model,
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
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
    tariff::Tariff,
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Set the BES charge and discharge variables for behind-the-meter (BTM) use
    JuMP.@variable(m, p_cha[t in 1:(sets.num_time_steps)] >= 0)
    JuMP.@variable(m, p_dis_btm[t in 1:(sets.num_time_steps)] >= 0)

    # Set the BES discharge variables for export use (e.g., for net metering)
    if tariff.nem_enabled & solar.enabled & !storage.nonexport
        JuMP.@variable(m, p_dis_exp[t in 1:(sets.num_time_steps)] >= 0)
    end

    # Set the BES state of charge variable
    JuMP.@variable(m, soc[t in 1:(sets.num_time_steps)])

    # Set the BES power and energy capacity variables, if performing capacity expansion
    if (scenario.problem_type == "CEM") & storage.make_investment
        # Set the BES power capacity to be unbounded or bounded, as specified
        if isnothing(storage.maximum_power_capacity)
            JuMP.@variable(m, bes_power_capacity >= 0)
        else
            JuMP.@variable(m, 0 <= bes_power_capacity <= storage.maximum_power_capacity)
        end
    end
end

"""
    define_bes_soc_energy_conservation!(
        m::JuMP.Model,
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
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
    tariff::Tariff,
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Determine whether or not the BES can export to the grid (i.e., is p_dis_exp included?)
    if tariff.nem_enabled & solar.enabled & !storage.nonexport
        # Set equality constraint to maintain BES state of charge for the first time step
        if (scenario.problem_type == "CEM") & storage.make_investment
            JuMP.@constraint(
                m,
                bes_soc_energy_conservation_initial,
                m[:soc][1] ==
                (1 - storage.loss_rate) *
                sets.bes_initial_soc *
                storage.duration *
                m[:bes_power_capacity] +
                (scenario.interval_length / 60) * (
                    storage.roundtrip_eff * m[:p_cha][1] -
                    (m[:p_dis_btm][1] + m[:p_dis_exp][1])
                )
            )
        else
            JuMP.@constraint(
                m,
                bes_soc_energy_conservation_initial,
                m[:soc][1] ==
                (1 - storage.loss_rate) *
                sets.bes_initial_soc *
                storage.duration *
                storage.power_capacity +
                (scenario.interval_length / 60) * (
                    storage.roundtrip_eff * m[:p_cha][1] -
                    (m[:p_dis_btm][1] + m[:p_dis_exp][1])
                )
            )
        end

        # Set equality constraint to maintain BES state of charge for all other time steps
        JuMP.@constraint(
            m,
            bes_soc_energy_conservation[t in 1:(sets.num_time_steps - 1)],
            m[:soc][t + 1] ==
            (1 - storage.loss_rate) * m[:soc][t] +
            (scenario.interval_length / 60) * (
                storage.roundtrip_eff * m[:p_cha][t + 1] -
                (m[:p_dis_btm][t + 1] + m[:p_dis_exp][t + 1])
            )
        )
    else
        # Set equality constraint to maintain BES state of charge for the first time step
        if (scenario.problem_type == "CEM") & storage.make_investment
            JuMP.@constraint(
                m,
                bes_soc_energy_conservation_initial,
                m[:soc][1] ==
                (1 - storage.loss_rate) *
                sets.bes_initial_soc *
                storage.duration *
                m[:bes_power_capacity] +
                (scenario.interval_length / 60) *
                (storage.roundtrip_eff * m[:p_cha][1] - m[:p_dis_btm][1])
            )
        else
            JuMP.@constraint(
                m,
                bes_soc_energy_conservation_initial,
                m[:soc][1] ==
                (1 - storage.loss_rate) *
                sets.bes_initial_soc *
                storage.duration *
                storage.power_capacity +
                (scenario.interval_length / 60) *
                (storage.roundtrip_eff * m[:p_cha][1] - m[:p_dis_btm][1])
            )
        end

        # Set equality constraint to maintain BES state of charge for all other time steps
        JuMP.@constraint(
            m,
            bes_soc_energy_conservation[t in 1:(sets.num_time_steps - 1)],
            m[:soc][t + 1] ==
            (1 - storage.loss_rate) * m[:soc][t] +
            (scenario.interval_length / 60) *
            (storage.roundtrip_eff * m[:p_cha][t + 1] - m[:p_dis_btm][t + 1])
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
    if (scenario.problem_type == "CEM") & storage.make_investment
        JuMP.@constraint(
            m,
            bes_final_soc_constraint,
            m[:soc][sets.num_time_steps] >=
            sets.bes_initial_soc * storage.duration * m[:bes_power_capacity]
        )
    else
        JuMP.@constraint(
            m,
            bes_final_soc_constraint,
            m[:soc][sets.num_time_steps] >=
            sets.bes_initial_soc * storage.duration * storage.power_capacity
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
    if (scenario.problem_type == "CEM") & storage.make_investment
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
        tariff::Tariff,
        solar::Solar,
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
    tariff::Tariff,
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Determine whether or not the BES can export to the grid (i.e., is p_dis_exp included?)
    if tariff.nem_enabled & solar.enabled & !storage.nonexport
        # Set the upper bound for the BES discharging power variable
        if (scenario.problem_type == "CEM") & storage.make_investment
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
    else
        # Set the upper bound for the BES discharging power variable
        if (scenario.problem_type == "CEM") & storage.make_investment
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
    if (scenario.problem_type == "CEM") & storage.make_investment
        JuMP.@constraint(
            m,
            bes_soc_lower_bound[t in 1:(sets.num_time_steps)],
            m[:soc][t] >= storage.soc_min * storage.duration * m[:bes_power_capacity]
        )
    else
        JuMP.@constraint(
            m,
            bes_soc_lower_bound[t in 1:(sets.num_time_steps)],
            m[:soc][t] >= storage.soc_min * storage.duration * storage.power_capacity
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
    if (scenario.problem_type == "CEM") & storage.make_investment
        JuMP.@constraint(
            m,
            bes_soc_upper_bound[t in 1:(sets.num_time_steps)],
            m[:soc][t] <= storage.soc_max * storage.duration * m[:bes_power_capacity]
        )
    else
        JuMP.@constraint(
            m,
            bes_soc_upper_bound[t in 1:(sets.num_time_steps)],
            m[:soc][t] <= storage.soc_max * storage.duration * storage.power_capacity
        )
    end
end

"""
    define_bes_export_upper_bound!(
        m::JuMP.Model,
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
        storage::Storage,
        sets::Sets,
    )

Constraint that sets an upper bound on the amount that storage can export in a given time 
step. This constraint is intended to help limit storage exports in scenarios where the 
net demand and exports linking constraint is relaxed and the consumer is exposed to export 
prices that may be greater than the energy price (e.g., NEM 3.0). Note that infeasibilities 
may occur if storage is not built or if an insufficient amount of storage is built, as the 
upper bound of the storage exports could interfere with the preestablished lower bound.
"""
function define_bes_export_upper_bound!(
    m::JuMP.Model,
    scenario::Scenario,
    tariff::Tariff,
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Determine whether or not the BES can export to the grid (i.e., is p_dis_exp 
    # included?), if the binary net demand and exports linkage is relaxed, and if a 
    # capacity expansion problem is being solved. Note that infeasibilities may occur if 
    # storage is not built or if an insufficient amount of storage is built (as the upper 
    # bound of the BES discharging power used for exports could interfere with its 
    # preestablished lower bound)
    if tariff.nem_enabled &
       solar.enabled &
       !storage.nonexport &
       !scenario.binary_net_demand_and_exports_linkage &
       (scenario.problem_type == "CEM") &
       storage.make_investment
        # Determine the time steps in which export prices are greater than energy prices
        time_steps_subset =
            filter(t -> sets.nem_prices[t] > sets.energy_prices[t], 1:(sets.num_time_steps))

        if !isempty(time_steps_subset)
            # Define the mapping between the indicator variable indices and the other 
            # time-related parameters
            time_mapping = Dict{Int64,Int64}(
                t => time_steps_subset[t] for t in eachindex(time_steps_subset)
            )

            # Set the upper bound on the amount of power the BES can discharge to the grid
            if solar.enabled
                JuMP.@constraint(
                    m,
                    bes_export_upper_bound[t in eachindex(time_steps_subset)],
                    m[:p_dis_exp][time_mapping[t]] <=
                    m[:bes_power_capacity] -
                    (sets.demand[time_mapping[t]] - m[:p_pv_btm][time_mapping[t]])
                )
            else
                JuMP.@constraint(
                    m,
                    bes_export_upper_bound[t in eachindex(time_steps_subset)],
                    m[:p_dis_exp][time_mapping[t]] <=
                    m[:bes_power_capacity] - sets.demand[time_mapping[t]]
                )
            end
        end
    end
end

"""
    define_bes_capital_cost_objective!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        scenario::Scenario,
        storage::Storage,
    )

Adds the capital costs and fixed operation and maintenance (O&M) costs associated with 
building battery energy storage to the objective function. Captial costs associated with 
the power capacity of the battery energy storage are required. Capital costs associated 
with the energy capacity of the battery energy storage are required if storage duration is 
not provided. Including fixed O&M costs is not required.
"""
function define_bes_capital_cost_objective!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    scenario::Scenario,
    storage::Storage,
)
    # Add the amortized capital cost associated with the power rating of building the 
    # determined battery energy storage system to the objective function
    if isnothing(storage.power_capital_cost)
        throw(
            ErrorException(
                "No capital cost is specified for the power capacity of battery " *
                "energy storage. Please try again.",
            ),
        )
    else
        # Establish the amortization period
        if isnothing(scenario.amortization_period)
            amortization_period = storage.lifespan
        else
            amortization_period = scenario.amortization_period
        end

        # Determine the amortized capital cost
        if isnothing(scenario.real_discount_rate)
            if isnothing(scenario.nominal_discount_rate) |
               isnothing(scenario.inflation_rate)
                # Use a simple amortization if the necessary information is not provided
                JuMP.add_to_expression!(
                    obj,
                    storage.linked_cost_scaling *
                    storage.power_capital_cost *
                    m[:bes_power_capacity] / amortization_period,
                )
            else
                # Calculate the real discount rate using the nominal discount rate and 
                # inflation rate
                real_discount_rate =
                    (scenario.nominal_discount_rate - scenario.inflation_rate) /
                    (1 + scenario.inflation_rate)

                # Use the calculated real discount rate
                JuMP.add_to_expression!(
                    obj,
                    (
                        (
                            real_discount_rate *
                            (1 + real_discount_rate)^amortization_period
                        ) / ((1 + real_discount_rate)^amortization_period - 1)
                    ) *
                    storage.linked_cost_scaling *
                    storage.power_capital_cost *
                    m[:bes_power_capacity],
                )
            end
        else
            # Use the user-defined real discount rate
            JuMP.add_to_expression!(
                obj,
                (
                    (
                        scenario.real_discount_rate *
                        (1 + scenario.real_discount_rate)^amortization_period
                    ) / ((1 + scenario.real_discount_rate)^amortization_period - 1)
                ) *
                storage.linked_cost_scaling *
                storage.power_capital_cost *
                m[:bes_power_capacity],
            )
        end
    end

    # Add the annual fixed operation and maintenance (O&M) cost associated with building 
    # the determined battery energy storage system to the objective function; assume there 
    # are no variable O&M costs
    if !isnothing(storage.fixed_om_cost)
        JuMP.add_to_expression!(
            obj,
            storage.linked_cost_scaling * storage.fixed_om_cost * m[:bes_power_capacity],
        )
    end
end
