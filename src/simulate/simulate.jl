"""
    create_sets(
        start_date::Dates.Date,
        last_date::Dates.Date,
        bes_initial_soc::Float64,
        scenario::Scenario,
        tariff::Tariff,
        demand::Demand,
        solar::Solar,
        storage::Storage,
    )::Sets

Create sets of useful quantities for use in the simulations. The sets created include 
reduced asset and price profiles, initial battery energy storage (BES) state of charge, and 
sets of time periods.
"""
function create_sets(
    start_date::Dates.Date,
    last_date::Dates.Date,
    bes_initial_soc::Float64,
    scenario::Scenario,
    tariff::Tariff,
    demand::Demand,
    solar::Solar,
    storage::Storage,
)::Sets
    # Initialize the parameters dictionary
    sets = Dict{String,Any}(
        "demand" => nothing,
        "solar_capacity_factor_profile" => nothing,
        "shift_up_capacity" => nothing,
        "shift_down_capacity" => nothing,
        "energy_prices" => nothing,
        "demand_prices" => nothing,
        "demand_mask" => nothing,
        "nem_prices" => nothing,
        "bes_initial_soc" => nothing,
        "num_time_steps" => nothing,
        "num_demand_charge_periods" => nothing,
    )

    # Create proper DateTime indices
    start_index = Dates.DateTime(
        Dates.year(start_date),
        Dates.month(start_date),
        Dates.day(start_date),
        0,
    )
    end_index = Dates.DateTime(
        Dates.year(last_date),
        Dates.month(last_date),
        Dates.day(last_date),
        23,
    )

    # Partition the demand profile accordingly
    sets["demand"] = filter(
        row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
        demand.demand_profile,
    )[
        !,
        "demand",
    ]

    # Partition the solar capacity factor profile accordingly
    if solar.enabled
        sets["solar_capacity_factor_profile"] = filter(
            row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
            solar.capacity_factor_profile,
        )[
            !,
            "capacity_factor",
        ]
    end

    # Partition the simple shiftable demand profiles accordingly
    if demand.simple_shift_enabled
        sets["shift_up_capacity"] = filter(
            row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
            demand.shift_up_capacity_profile,
        )[
            !,
            "demand",
        ]
        sets["shift_down_capacity"] = filter(
            row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
            demand.shift_down_capacity_profile,
        )[
            !,
            "demand",
        ]
    end

    # Partition the energy prices accordingly
    sets["energy_prices"] = filter(
        row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
        tariff.energy_prices,
    )[
        !,
        "rates",
    ]

    # Partition the demand prices and demand mask accordingly
    if !isnothing(tariff.demand_prices)
        sets["demand_prices"] = Dict{Int64,Any}()
        sets["demand_mask"] = Dict{Int64,Any}()
        period_counter = 1
        if scenario.optimization_horizon == "day"
            for k in keys(tariff.demand_prices)
                if occursin("monthly", k) & occursin(string(Dates.month(start_date)), k)
                    sets["demand_prices"][period_counter] = tariff.demand_prices[k]
                    sets["demand_mask"][period_counter] = filter(
                        row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
                        tariff.demand_mask,
                    )[
                        !,
                        k,
                    ]
                    period_counter += 1
                elseif occursin("daily", k) & occursin(
                    string(Dates.month(start_date)) * "_" * string(Dates.day(start_date)),
                    k,
                )
                    sets["demand_prices"][period_counter] = tariff.demand_prices[k]
                    sets["demand_mask"][period_counter] = filter(
                        row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
                        tariff.demand_mask,
                    )[
                        !,
                        k,
                    ]
                    period_counter += 1
                end
            end
        elseif scenario.optimization_horizon == "month"
            for k in keys(tariff.demand_prices)
                if occursin("monthly", k) & occursin(string(Dates.month(start_date)), k)
                    sets["demand_prices"][period_counter] = tariff.demand_prices[k]
                    sets["demand_mask"][period_counter] = filter(
                        row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
                        tariff.demand_mask,
                    )[
                        !,
                        k,
                    ]
                    period_counter += 1
                elseif occursin("daily", k) &
                       occursin("_" * string(Dates.month(start_date)) * "_", k)
                    sets["demand_prices"][period_counter] = tariff.demand_prices[k]
                    sets["demand_mask"][period_counter] = filter(
                        row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
                        tariff.demand_mask,
                    )[
                        !,
                        k,
                    ]
                    period_counter += 1
                end
            end
        elseif scenario.optimization_horizon == "year"
            for k in keys(tariff.demand_prices)
                sets["demand_prices"][period_counter] = tariff.demand_prices[k]
                sets["demand_mask"][period_counter] = tariff.demand_mask[!, k]
                period_counter += 1
            end
        end
    end

    # Partition the net energy metering sell prices accordingly
    if tariff.nem_enabled
        sets["nem_prices"] = filter(
            row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
            tariff.nem_prices,
        )[
            !,
            "rates",
        ]
    end

    # Set the initial state of charge for battery energy storage (BES)
    if storage.enabled
        sets["bes_initial_soc"] = bes_initial_soc
    end

    # Determine the number of time periods in the optimization horizon
    sets["num_time_steps"] = length(sets["energy_prices"])

    # Determine the number of time periods in which demand charges are levied
    if !isnothing(tariff.demand_prices)
        sets["num_demand_charge_periods"] = length(sets["demand_prices"])
    end

    # Convert Dict to NamedTuple
    sets = (; (Symbol(k) => v for (k, v) in sets)...)

    # Convert NamedTuple to Storage object
    sets = Sets(; sets...)

    return sets
end

"""
    load_and_preprocess_data(input_folder::String)

Loads and preprocesses the data needed to run a simulation. Returns data in the appropriate 
objects.
"""
function load_and_preprocess_data(input_folder::String)
    # Load all the simulation data
    scenario = read_scenario(input_folder)
    tariff = read_tariff(input_folder)
    market = read_market(input_folder)
    incentives = read_incentives(input_folder)
    demand = read_demand(input_folder)
    solar = read_solar(input_folder)
    storage = read_storage(input_folder)
    println("All data is loaded!")

    # Perform extra preprocessing of input data, as necessary
    tariff = create_rate_profiles(scenario, tariff)
    if isnothing(solar.capacity_factor_profile)
        solar = create_solar_capacity_factor_profile(scenario, solar)
    end
    println("All data preprocessing complete!")

    # Return the created objects
    return scenario, tariff, market, incentives, demand, solar, storage
end

"""
    solve_problem(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incentives,
        demand::Demand,
        solar::Solar,
        storage::Storage,
        output_folder::Union{String,Nothing}=nothing,
    )

Solve the specified optimization problem using one of the provided solution methods.
"""
function solve_problem(
    scenario::Scenario,
    tariff::Tariff,
    market::Market,
    incentives::Incentives,
    demand::Demand,
    solar::Solar,
    storage::Storage,
    output_folder::Union{String,Nothing}=nothing,
)
    # Perform the simulation, depending on the optimization horizon
    if scenario.optimization_horizon == "day"
        simulate_by_day(
            scenario,
            tariff,
            market,
            incentives,
            demand,
            solar,
            storage,
            output_folder,
        )
    elseif scenario.optimization_horizon == "month"
        simulate_by_month(
            scnario,
            tariff,
            market,
            incentives,
            demand,
            solar,
            storage,
            output_folder,
        )
    elseif scenario.optimization_horizon == "year"
        simulate_by_year(
            scenario,
            tariff,
            market,
            incentives,
            demand,
            solar,
            storage,
            output_folder,
        )
    end
end