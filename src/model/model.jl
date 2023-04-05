"""
    define_objective_function!(
        m::JuMP.Model,
        scenario::Scenario,
        tariff::Tariff,
        incentives::Incentives,
        solar::Solar,
        storage::Storage,
        sets::Sets,
    )

Creates the objective function for the production cost and capacity expansion problems. For 
production cost, the objective function is comprised of costs associated with energy 
charges and demand charges and 'revenue' associated with net energy metering (NEM). The 
objective function for the capacity expansion model builds on that of the production cost 
model by adding costs associated with asset investment and 'revenues' associated with 
different incentive programs.
"""
function define_objective_function!(
    m::JuMP.Model,
    scenario::Scenario,
    tariff::Tariff,
    incentives::Incentives,
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Initialize an expression for the objective function
    JuMP.@expression(m, obj, AffExpr())

    # Add in demand charges, if applicable
    if !isnothing(sets.demand_prices)
        JuMP.add_to_expression!(obj, sum(m[:d_max] .* sets.demand_prices))
    end

    # Add in time-of-use energy charges
    JuMP.add_to_expression!(obj, sum(m[:d_net] .* sets.energy_prices))

    # Add in revenue from net energy metering, if applicable
    if tariff.nem_enabled
        JuMP.add_to_expression!(obj, -1 * sum(m[:p_exports] .* sets.nem_prices))
    end

    # Add in capacity expansion model-specific charges and incentives
    if scenario.problem_type == "CEM"
        # Add in capital costs associated with solar photovoltaics (PVs), if applicable
        if solar.enabled
            if isnothing(solar.pv_capital_cost)
                throw(
                    ErrorException(
                        "No capital cost is specified for the generation capacity of " *
                        "solar PVs. Please try again.",
                    ),
                )
            else
                JuMP.add_to_expression!(
                    obj,
                    solar.pv_capital_cost * m[:pv_capacity] / solar.lifespan,
                )
            end
        end

        # Add in capital costs associated with battery energy storage (BES), if applicable
        if storage.enabled
            if isnothing(storage.power_capacity_cost)
                throw(
                    ErrorException(
                        "No capital cost is specified for the power capacity of battery " *
                        "energy storage. Please try again.",
                    ),
                )
            else
                JuMP.add_to_expression!(
                    obj,
                    storage.power_capital_cost * m[:bes_power_capacity] / storage.lifespan,
                )
            end

            if isnothing(storage.duration)
                if isnothing(storage.energy_capital_cost)
                    throw(
                        ErrorException(
                            "No capital cost is specified for the energy capacity of " *
                            "battery energy storage. Please try again.",
                        ),
                    )
                else
                    JuMP.add_to_expression!(
                        obj,
                        storage.energy_capital_cost * m[:bes_energy_capacity] /
                        storage.lifespan,
                    )
                end
            end
        end
    end

    # Create the objective function
    JuMP.@objective(m, Min, obj)
end

"""
    build_optimization_model(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incentives,
        demand::Demand,
        solar::Solar,
        storage::Storage,
        sets::Sets,
    )::JuMP.Model

Creates an optimization using JuMP. Includes an objective function depending on the problem 
type (i.e., production cost or capacity expansion) and constraints associated with 
different assets, incentives, and tariff programs.
"""
function build_optimization_model(
    scenario::Scenario,
    tariff::Tariff,
    market::Market,
    incentives::Incentives,
    demand::Demand,
    solar::Solar,
    storage::Storage,
    sets::Sets,
)::JuMP.Model
    # Determine the solver
    if scenario.optimization_solver == "GLPK"
        s = GLPK.Optimizer
    elseif scenario.optimization_solver == "GUROBI"
        s = Gurobi.Optimizer
    elseif scenario.optimization_solver == "HIGHS"
        s = HiGHS.Optimizer
    end

    # Build initial JuMP optimization model
    m = JuMP.Model(s)

    # Define demand-related variables and expressions
    define_demand_variables!(m, tariff, sets)

    # Add the solar photovoltaic (PV) model, if enabled
    if solar.enabled
        define_solar_photovoltaic_model!(m, scenario, tariff, solar, sets)
    end

    # Add the battery energy storage (BES) model, if enabled
    if storage.enabled
        define_battery_energy_storage_model!(m, scenario, tariff, storage, sets)
    end

    # Add the simplified shiftable demand (SSD) model, if enabled
    if demand.simple_shift_enabled
        define_simple_shiftable_demand_model!(m, demand, sets)
    end

    # Define demand-related constraints
    define_maximum_demand_during_periods_constraint!(m, sets)
    define_net_demand_nonexport_constraint!(m, sets)

    # Define the non-import constraint for BES, if enabled and applicable
    if storage.nonimport & storage.enabled
        define_bes_nonimport_constraint!(m, solar, sets)
    end

    # Define the objective function of the optimization model
    define_objective_function!(m, scenario, tariff, incentives, solar, storage, sets)

    # Return the created JuMP model
    return m
end
