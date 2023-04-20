"""
    create_sets(
        start_date::Dates.Date,
        end_date::Dates.Date,
        bes_initial_soc::Union{Float64,Nothing},
        scenario::Scenario,
        tariff::Tariff,
        demand::Demand,
        solar::Solar,
        storage::Storage;
        current_monthly_max_demand::Union{Dict,Nothing}=nothing,
    )::Sets

Create sets of useful quantities for use in the simulations. The sets created include 
reduced asset and price profiles, initial battery energy storage (BES) state of charge, and 
sets of time periods.
"""
function create_sets(
    start_date::Dates.Date,
    end_date::Dates.Date,
    bes_initial_soc::Union{Float64,Nothing},
    scenario::Scenario,
    tariff::Tariff,
    demand::Demand,
    solar::Solar,
    storage::Storage;
    current_monthly_max_demand::Union{Dict,Nothing}=nothing,
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
        "demand_charge_label_to_id" => nothing,
        "previous_monthly_max_demand" => nothing,
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
    end_index =
        Dates.DateTime(Dates.year(end_date), Dates.month(end_date), Dates.day(end_date), 23)

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

    # Set up demand prices, demand masks, demand charge label-ID map, and previous monthly 
    # maximum demands, if demand charges are considered
    if !isnothing(tariff.demand_prices)
        # Partition the demand prices and demand mask; set up demand charge label-ID mapping
        sets["demand_prices"] = Vector{Float64}()
        sets["demand_mask"] = Dict{Int64,Any}()
        sets["demand_charge_label_to_id"] = Dict{String,Any}()
        demand_charge_id = 1
        if scenario.optimization_horizon == "DAY"
            for k in keys(tariff.demand_prices)
                if occursin("monthly", k) &
                   occursin("_" * string(Dates.month(start_index)) * "_", k)
                    # If the optimization horizon is one day, weight monthly demand charges 
                    # according to the number of days that have already occurred in the 
                    # month. This is done to limit the prevalence of the demand charge, 
                    # relative to the energy charge, for days that occur early in the month.
                    push!(
                        sets["demand_prices"],
                        tariff.demand_prices[k] / Dates.daysinmonth(start_index),
                    )

                    # Add the corresponding demand mask; no change is needed
                    sets["demand_mask"][demand_charge_id] = filter(
                        row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
                        tariff.demand_mask,
                    )[
                        !,
                        k,
                    ]

                    # Add the corresponding demand charge ID and demand charge label pair
                    sets["demand_charge_label_to_id"][k] = demand_charge_id
                    demand_charge_id += 1
                elseif occursin("daily", k) & occursin(
                    "_" *
                    string(Dates.month(start_index)) *
                    "-" *
                    string(Dates.day(start_index)) *
                    "_",
                    k,
                )
                    push!(sets["demand_prices"], tariff.demand_prices[k])
                    sets["demand_mask"][demand_charge_id] = filter(
                        row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
                        tariff.demand_mask,
                    )[
                        !,
                        k,
                    ]
                    sets["demand_charge_label_to_id"][k] = demand_charge_id
                    demand_charge_id += 1
                end
            end
        elseif scenario.optimization_horizon == "MONTH"
            for k in keys(tariff.demand_prices)
                if occursin("monthly", k) &
                   occursin("_" * string(Dates.month(start_index)) * "_", k)
                    push!(sets["demand_prices"], tariff.demand_prices[k])
                    sets["demand_mask"][demand_charge_id] = filter(
                        row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
                        tariff.demand_mask,
                    )[
                        !,
                        k,
                    ]
                    sets["demand_charge_label_to_id"][k] = demand_charge_id
                    demand_charge_id += 1
                elseif occursin("daily", k) &
                       occursin("_" * string(Dates.month(start_index)) * "-", k)
                    push!(sets["demand_prices"], tariff.demand_prices[k])
                    sets["demand_mask"][demand_charge_id] = filter(
                        row -> row["timestamp"] in start_index:Dates.Hour(1):end_index,
                        tariff.demand_mask,
                    )[
                        !,
                        k,
                    ]
                    sets["demand_charge_label_to_id"][k] = demand_charge_id
                    demand_charge_id += 1
                end
            end
        elseif scenario.optimization_horizon == "YEAR"
            for k in keys(tariff.demand_prices)
                push!(sets["demand_prices"], tariff.demand_prices[k])
                sets["demand_mask"][demand_charge_id] = tariff.demand_mask[!, k]
                sets["demand_charge_label_to_id"][k] = demand_charge_id
                demand_charge_id += 1
            end
        end

        # Identify previous monthly maximum demand values for next pass from current values
        if scenario.optimization_horizon == "DAY"
            sets["previous_monthly_max_demand"] = zeros(length(sets["demand_prices"]))
            if !isnothing(current_monthly_max_demand)
                for k in keys(current_monthly_max_demand)
                    sets["previous_monthly_max_demand"][sets["demand_charge_label_to_id"][k]] =
                        current_monthly_max_demand[k]
                end
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
