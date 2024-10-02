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
        "start_date" => start_date,
        "end_date" => end_date,
        "demand" => nothing,
        "solar_capacity_factor_profile" => nothing,
        "shift_up_capacity" => nothing,
        "shift_down_capacity" => nothing,
        "energy_prices" => nothing,
        "tiered_energy_rates" => nothing,
        "num_tiered_energy_rates_tiers" => nothing,
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
        0,
    )
    end_index = Dates.DateTime(
        Dates.year(end_date),
        Dates.month(end_date),
        Dates.day(end_date),
        23,
        45,
    )

    # Partition the demand profile accordingly
    sets["demand"] = filter(
        row -> row["timestamp"] in
        start_index:Dates.Minute(scenario.interval_length):end_index,
        demand.demand_profile,
    )[
        !,
        "demand",
    ]

    # Partition the solar capacity factor profile accordingly
    if solar.enabled
        sets["solar_capacity_factor_profile"] = filter(
            row -> row["timestamp"] in
            start_index:Dates.Minute(scenario.interval_length):end_index,
            solar.capacity_factor_profile,
        )[
            !,
            "capacity_factor",
        ]
    end

    # Partition the simple shiftable demand profiles accordingly
    if demand.simple_shift_enabled
        sets["shift_up_capacity"] = filter(
            row -> row["timestamp"] in
            start_index:Dates.Minute(scenario.interval_length):end_index,
            demand.shift_up_capacity_profile,
        )[
            !,
            "demand",
        ]
        sets["shift_down_capacity"] = filter(
            row -> row["timestamp"] in
            start_index:Dates.Minute(scenario.interval_length):end_index,
            demand.shift_down_capacity_profile,
        )[
            !,
            "demand",
        ]
    end

    # Determine the time-of-use energy charge scaling
    tou_energy_charge_scaling = filter(
        row -> row["timestamp"] in
        start_index:Dates.Minute(scenario.interval_length):end_index,
        tariff.tou_energy_charge_scaling_indicator,
    )[
        !,
        "indicators",
    ]
    for i in eachindex(tou_energy_charge_scaling)
        if tou_energy_charge_scaling[i] == 1.0
            tou_energy_charge_scaling[i] *= tariff.tou_energy_charge_scaling
        elseif tou_energy_charge_scaling[i] in
               range(2.0, length(tariff.months_by_season) + 1.0)
            if tariff.tou_energy_charge_scaling == 1.0
                tou_energy_charge_scaling[i] = 1.0
            else
                # Get the season name
                season_name = sort(collect(keys(tariff.months_by_season)))[floor(
                    Int64,
                    tou_energy_charge_scaling[i] - 1.0,
                )]

                # Find the relevant peak, partial-peak, and off-peak energy prices
                p = retrieve_tou_price(tariff, season_name, "peak")
                pp = retrieve_tou_price(tariff, season_name, "partial-peak")
                op = retrieve_tou_price(tariff, season_name, "off-peak")

                # Find the relative placement of the partial-peak price between the peak 
                # and off-peak prices
                r = (pp - op) / (p - op)

                # Find the related partial-peak scaling term
                tou_energy_charge_scaling[i] =
                    (r * (tariff.tou_energy_charge_scaling * p - op) + op) / pp
            end
        else
            tou_energy_charge_scaling[i] = 1.0
        end
    end

    # Partition the energy prices accordingly
    sets["energy_prices"] =
        tariff.all_charge_scaling .* tariff.energy_charge_scaling .*
        tou_energy_charge_scaling .* filter(
            row -> row["timestamp"] in
            start_index:Dates.Minute(scenario.interval_length):end_index,
            tariff.energy_prices,
        )[
            !,
            "rates",
        ]

    # Partition the tiered energy rate information accordingly
    if !isnothing(tariff.energy_tiered_rates)
        # Access the month(s) of the tiered energy rates that are needed
        sets["tiered_energy_rates"] = Dict{Int64,Any}()
        for m = Dates.month(start_index):Dates.month(end_index)
            for tier in keys(tariff.energy_tiered_rates[m])
                sets["tiered_energy_rates"][tier] = Dict{String,Any}()
                for k in keys(tariff.energy_tiered_rates[m][tier])
                    if k == "bounds"
                        if scenario.optimization_horizon == "DAY"
                            if tariff.energy_tiered_baseline_type == "daily"
                                sets["tiered_energy_rates"][tier][k] =
                                    tariff.energy_tiered_rates[m][tier][k]
                            elseif tariff.energy_tiered_baseline_type == "monthly"
                                sets["tiered_energy_rates"][tier][k] =
                                    tariff.energy_tiered_rates[m][tier][k] /
                                    Dates.daysinmonth(scenario.year, m)
                            end
                        elseif scenario.optimization_horizon == "MONTH"
                            if tariff.energy_tiered_baseline_type == "daily"
                                sets["tiered_energy_rates"][tier][k] =
                                    Dates.daysinmonth(scenario.year, m) *
                                    tariff.energy_tiered_rates[m][tier][k]
                            elseif tariff.energy_tiered_baseline_type == "monthly"
                                sets["tiered_energy_rates"][tier][k] =
                                    tariff.energy_tiered_rates[m][tier][k]
                            end
                        elseif scenario.optimization_horizon == "YEAR"
                            throw(
                                ErrorException(
                                    "Considering tiered energy rates with an " *
                                    "optimization horizon of one year is not currently " *
                                    "supported. Please try again.",
                                ),
                            )
                        end
                    else
                        sets["tiered_energy_rates"][tier][k] =
                            tariff.energy_tiered_rates[m][tier][k]
                    end
                end
                sets["tiered_energy_rates"][tier]["month"] = m
            end
        end

        # Determine the total number of tiers, including across different months
        sets["num_tiered_energy_rates_tiers"] = length(sets["tiered_energy_rates"])
    end

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
                    # according to the number of days total that occur in the month. This 
                    # is done to limit the prevalence of the demand charge relative to the 
                    # energy charge, which is evaluated daily instead of monthly under this 
                    # optimization horizon.
                    push!(
                        sets["demand_prices"],
                        tariff.all_charge_scaling *
                        tariff.demand_charge_scaling *
                        tariff.demand_prices[k] / Dates.daysinmonth(start_index),
                    )

                    # Add the corresponding demand mask; no change is needed
                    sets["demand_mask"][demand_charge_id] = filter(
                        row -> row["timestamp"] in
                        start_index:Dates.Minute(scenario.interval_length):end_index,
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
                    push!(
                        sets["demand_prices"],
                        tariff.all_charge_scaling *
                        tariff.demand_charge_scaling *
                        tariff.demand_prices[k],
                    )
                    sets["demand_mask"][demand_charge_id] = filter(
                        row -> row["timestamp"] in
                        start_index:Dates.Minute(scenario.interval_length):end_index,
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
                    push!(
                        sets["demand_prices"],
                        tariff.all_charge_scaling *
                        tariff.demand_charge_scaling *
                        tariff.demand_prices[k],
                    )
                    sets["demand_mask"][demand_charge_id] = filter(
                        row -> row["timestamp"] in
                        start_index:Dates.Minute(scenario.interval_length):end_index,
                        tariff.demand_mask,
                    )[
                        !,
                        k,
                    ]
                    sets["demand_charge_label_to_id"][k] = demand_charge_id
                    demand_charge_id += 1
                elseif occursin("daily", k) &
                       occursin("_" * string(Dates.month(start_index)) * "-", k)
                    push!(
                        sets["demand_prices"],
                        tariff.all_charge_scaling *
                        tariff.demand_charge_scaling *
                        tariff.demand_prices[k],
                    )
                    sets["demand_mask"][demand_charge_id] = filter(
                        row -> row["timestamp"] in
                        start_index:Dates.Minute(scenario.interval_length):end_index,
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
                push!(
                    sets["demand_prices"],
                    tariff.all_charge_scaling *
                    tariff.demand_charge_scaling *
                    tariff.demand_prices[k],
                )
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
    if tariff.nem_enabled & solar.enabled
        if tariff.nem_version == 1
            sets["nem_prices"] =
                tariff.all_charge_scaling .* tariff.energy_charge_scaling .*
                tou_energy_charge_scaling .* filter(
                    row -> row["timestamp"] in
                    start_index:Dates.Minute(scenario.interval_length):end_index,
                    tariff.nem_prices,
                )[
                    !,
                    "rates",
                ]
        elseif tariff.nem_version == 2
            if scenario.optimization_horizon == "YEAR"
                sets["nem_prices"] =
                    tariff.all_charge_scaling .* tariff.energy_charge_scaling .*
                    tou_energy_charge_scaling .* filter(
                        row -> row["timestamp"] in
                        start_index:Dates.Minute(scenario.interval_length):end_index,
                        tariff.nem_prices,
                    )[
                        !,
                        "rates",
                    ]
            else
                sets["nem_prices"] =
                    tariff.all_charge_scaling .* tariff.energy_charge_scaling .*
                    tou_energy_charge_scaling .* (
                        filter(
                            row -> row["timestamp"] in
                            start_index:Dates.Minute(scenario.interval_length):end_index,
                            tariff.nem_prices,
                        )[
                            !,
                            "rates",
                        ] .+ tariff.non_bypassable_charge
                    ) .- tariff.non_bypassable_charge
            end
        else
            sets["nem_prices"] = filter(
                row -> row["timestamp"] in
                start_index:Dates.Minute(scenario.interval_length):end_index,
                tariff.nem_prices,
            )[
                !,
                "rates",
            ]
        end
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
    retrieve_tou_price(
        tariff::Tariff,
        season_name::String,
        tou_period_name::String,
    )::Float64

Returns the energy price associated with a specified time-of-use period in a specified 
season.
"""
function retrieve_tou_price(
    tariff::Tariff,
    season_name::String,
    tou_period_name::String,
)::Float64
    # Look for the energy price associated with the specified time-of-use period and month
    for hour_dict in values(tariff.energy_tou_rates[season_name])
        if hour_dict["label"] == tou_period_name
            return hour_dict["rate"]
        end
    end

    # Throw an error if the specified time-of-use period does not exist in the specified 
    # month
    throw(
        ErrorException(
            "The " *
            tou_period_name *
            " period does not exist for the " *
            season_name *
            " season within the provided tariff information. Please try again.",
        ),
    )
end
