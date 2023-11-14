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
    demand::Demand,
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Initialize an expression for the objective function
    JuMP.@expression(m, obj, JuMP.AffExpr())

    # Add in time-of-use energy charges
    define_tou_energy_charge_objective!(m, obj, scenario, sets)

    # Add in demand charges, if applicable
    if !isnothing(sets.demand_prices)
        define_demand_charge_objective!(m, obj, sets)
    end

    # Add in revenue from net energy metering, if applicable
    if tariff.nem_enabled
        define_net_energy_metering_revenue_objective!(m, obj, scenario, sets)
    end

    # Add in variable cost associated with the simple shiftable demand model, if applicable
    if demand.simple_shift_enabled
        define_shiftable_demand_variable_cost_objective!(m, obj, demand)
    end

    # Add in capacity expansion model-specific charges and incentives
    if scenario.problem_type == "CEM"
        # Add in capital costs associated with solar photovoltaics (PVs), if applicable
        if solar.enabled
            define_solar_pv_capital_cost_objective!(m, obj, solar)

            # Add in solar PV investment tax credit (ITC), if applicable
            define_solar_investment_tax_credit!(m, obj, solar)
        end

        # Add in capital costs associated with battery energy storage (BES), if applicable
        if storage.enabled
            define_bes_capital_cost_objective!(m, obj, storage)

            # Add in BES ITC, if applicable
            define_storage_investment_tax_credit!(m, obj, storage)
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
        define_simple_shiftable_demand_model!(m, scenario, demand, sets)
    end

    # Define demand-related constraints
    if !isnothing(sets.demand_prices)
        define_maximum_demand_during_periods_constraint!(m, sets)
        if scenario.optimization_horizon == "DAY"
            define_monthly_maximum_demand_under_daily_optimization_constraint!(m, sets)
        end
    end
    define_net_demand_nonexport_constraint!(m, sets)

    # Define the non-import constraint for BES, if enabled and applicable
    if storage.enabled & storage.nonimport
        define_bes_nonimport_constraint!(m, solar, sets)
    end

    # Define the objective function of the optimization model
    define_objective_function!(
        m,
        scenario,
        tariff,
        incentives,
        demand,
        solar,
        storage,
        sets,
    )

    # Return the created JuMP model
    return m
end
