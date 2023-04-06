"""
    create_energy_rate_profile(scenario::Scenario, tariff::Tariff)::DataFrames.DataFrame

Create the profiles that describe how consumers are exposed to energy charges.
"""
function create_energy_rate_profile(
    scenario::Scenario,
    tariff::Tariff,
)::DataFrames.DataFrame
    # Create annual profile with hourly increments
    profile = DataFrames.DataFrame(
        "timestamp" => collect(
            Dates.DateTime(scenario.year, 1, 1, 0):Dates.Hour(1):Dates.DateTime(
                scenario.year,
                12,
                31,
                23,
            ),
        ),
        "rates" => zeros(Dates.daysinyear(scenario.year) * 24),
    )

    # Create inverse mapping of seasons to months
    seasons_by_month = Dict{Int64,String}(
        v => k for k in keys(tariff.months_by_season) for
        v in values(tariff.months_by_season[k])
    )

    # Iterate through months and hours to set energy rates
    for m in sort!(reduce(vcat, values(tariff.months_by_season)))
        for h in sort!(
            collect(
                keys(tariff.energy_tou_rates[collect(keys(tariff.energy_tou_rates))[1]]),
            ),
        )
            # Set rates by hour and month
            profile[!, "rates"] .=
                ifelse.(
                    (Dates.hour.(profile.timestamp) .== h) .&
                    (Dates.month.(profile.timestamp) .== m),
                    tariff.energy_tou_rates[seasons_by_month[m]][h]["rate"],
                    profile[!, "rates"],
                )

            # Update the profile if there is a distinction between weekdays and weekends
            if tariff.weekday_weekend_split
                profile[!, "rates"] .=
                    ifelse.(
                        identify_weekends(profile.timestamp, m),
                        tariff.energy_tou_rates[seasons_by_month[m]][0]["rate"],
                        profile[!, "rates"],
                    )
            end

            # Update the profile if there is a distinction between holidays and non-holidays
            if tariff.holiday_split
                profile[!, "rates"] .=
                    ifelse.(
                        identify_holidays(profile.timestamp, m),
                        tariff.energy_tou_rates[seasons_by_month[m]][0]["rate"],
                        profile[!, "rates"],
                    )
            end
        end
    end

    # Return the profile for energy rates
    return profile
end

"""
    create_demand_rate_profile(scenario::Scenario, tariff::Tariff)

Create the mask profiles and corresponding rate references that describe how consumers 
are exposed to demand charges.
"""
function create_demand_rate_profile(scenario::Scenario, tariff::Tariff)
    # Initialize the demand mask
    mask = DataFrames.DataFrame(
        "timestamp" => collect(
            Dates.DateTime(scenario.year, 1, 1, 0):Dates.Hour(1):Dates.DateTime(
                scenario.year,
                12,
                31,
                23,
            ),
        ),
    )
    rates = Dict{String,Float64}()

    # Create inverse mapping of seasons to months
    seasons_by_month = Dict{Int64,String}(
        v => k for k in keys(tariff.months_by_season) for
        v in values(tariff.months_by_season[k])
    )

    # Create masks and rates for monthly maximum demand charges
    if !isnothing(tariff.monthly_maximum_demand_rates)
        for m in sort!(reduce(vcat, values(tariff.months_by_season)))
            # Initialize the mask and set the rate
            mask[!, "monthly_maximum_" * string(m) * "_"] =
                zeros(length(mask[!, "timestamp"]))
            rates["monthly_maximum_" * string(m) * "_"] =
                tariff.monthly_maximum_demand_rates[seasons_by_month[m]]["rate"]

            # Set the mask accordingly
            mask[!, "monthly_maximum_" * string(m) * "_"] =
                ifelse.(
                    Dates.month.(mask.timestamp) .== m,
                    1,
                    mask[!, "monthly_maximum_" * string(m) * "_"],
                )
        end
    end

    # Create masks and rates for monthly maximum time-of-use (TOU) demand charges
    if !isnothing(tariff.monthly_demand_tou_rates)
        for m in sort!(reduce(vcat, values(tariff.months_by_season)))
            for h in sort!(
                collect(
                    keys(
                        tariff.monthly_demand_tou_rates[collect(
                            keys(tariff.monthly_demand_tou_rates),
                        )[1]],
                    ),
                ),
            )
                # Initialize the mask and set the rate
                if tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] != ""
                    # Check if a particular demand charge has already been accounted for
                    if !(
                        (
                            "monthly_" *
                            tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] *
                            "_" *
                            string(m) *
                            "_"
                        ) in names(mask)
                    )
                        mask[
                            !,
                            "monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                m,
                            ) * "_",
                        ] = zeros(length(mask[!, "timestamp"]))
                        rates["monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                            m,
                        ) * "_"] =
                            tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["rate"]
                    end

                    # Set the mask accordingly
                    mask[
                        !,
                        "monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                            m,
                        ) * "_",
                    ] =
                        ifelse.(
                            (Dates.month.(mask.timestamp) .== m) .&
                            (Dates.hour.(mask.timestamp) .== h),
                            1,
                            mask[
                                !,
                                "monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                    m,
                                ) * "_",
                            ],
                        )

                    # Update the mask if there is a distinction between weekdays and weekends
                    if tariff.weekday_weekend_split
                        mask[
                            !,
                            "monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                m,
                            ) * "_",
                        ] =
                            ifelse.(
                                identify_weekends(mask.timestamp, m),
                                0,
                                mask[
                                    !,
                                    "monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                        m,
                                    ) * "_",
                                ],
                            )
                    end

                    # Update the mask if there is a distinction between holidays and non-holidays
                    if tariff.holiday_split
                        mask[
                            !,
                            "monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                m,
                            ) * "_",
                        ] =
                            ifelse.(
                                identify_holidays(mask.timestamp, m),
                                0,
                                mask[
                                    !,
                                    "monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                        m,
                                    ) * "_",
                                ],
                            )
                    end
                end
            end
        end
    end

    # Create masks and rates for daily maximum time-of-use (TOU) demand charges
    if !isnothing(tariff.daily_demand_tou_rates)
        for m in sort!(reduce(vcat, values(tariff.months_by_season)))
            for d = 1:Dates.daysinmonth(Dates.Date(scenario.year, m))
                # Skip mask, rate for relevant timestamps if holidays, weekends are considered
                if !(
                    (
                        tariff.weekday_weekend_split &
                        identify_weekends(Dates.Date(scenario.year, m, d), m)
                    ) | (
                        tariff.holiday_split &
                        identify_holidays(Dates.Date(scenario.year, m, d), m)
                    )
                )
                    for h in sort!(
                        collect(
                            keys(
                                tariff.daily_demand_tou_rates[collect(
                                    keys(tariff.daily_demand_tou_rates),
                                )[1]],
                            ),
                        ),
                    )
                        # Initialize the mask and set the rate
                        if tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] !=
                           ""
                            # Check if a particular demand charge has already been accounted for
                            if !(
                                (
                                    "daily_" *
                                    tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] *
                                    "_" *
                                    string(m) *
                                    "-" *
                                    string(d) *
                                    "_"
                                ) in names(mask)
                            )
                                mask[
                                    !,
                                    "daily_" * tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                        m,
                                    ) * "-" * string(d) * "_",
                                ] = zeros(length(mask[!, "timestamp"]))
                                rates["daily_" * tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                    m,
                                ) * "-" * string(d) * "_"] =
                                    tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["rate"]
                            end

                            # Set the mask accordingly
                            mask[
                                !,
                                "daily_" * tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                    m,
                                ) * "-" * string(d) * "_",
                            ] =
                                ifelse.(
                                    (Dates.month.(mask.timestamp) .== m) .&
                                    (Dates.day.(mask.timestamp) .== d) .&
                                    (Dates.hour.(mask.timestamp) .== h),
                                    1,
                                    mask[
                                        !,
                                        "daily_" * tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                            m,
                                        ) * "-" * string(d) * "_",
                                    ],
                                )
                        end
                    end
                end
            end
        end
    end

    # Return the rates and mask for the demand rates
    return rates, mask
end

"""
    create_nem_rate_profile(
        tariff::Tariff, 
        energy_price_profile::DataFrames.DataFrame,
    )::DataFrames.DataFrame

Create the profile that describes the rate at which consumers can sell excess solar 
generation via a net energy metering (NEM) program.
"""
function create_nem_rate_profile(
    tariff::Tariff,
    energy_price_profile::DataFrames.DataFrame,
)::DataFrames.DataFrame
    # Create profile of NEM sell prices depending on the NEM version
    if tariff.nem_version == 1
        # Under NEM 1.0, the sell rate is the same as the energy rate
        profile = deepcopy(energy_price_profile)
    elseif tariff.nem_version == 2
        # Under NEM 2.0, the sell rate is the energy rate minus the non-bypassable charge
        profile = deepcopy(energy_price_profile)
        profile[!, "rates"] .-= tariff.nem2_non_bypassable_charge
    elseif tariff.nem_version == 3
        # Under NEM 3.0, the sell rate is the value determined by avoided cost calculators
        profile = tariff.nem3_profile
    end

    # Return the profile for NEM sell rates
    return profile
end

"""
    create_rate_profiles(scenario::Scenario, tariff::Tariff)::Tariff

Create the profiles that describe how consumers are exposed to demand charges, energy 
charges, and net metering sell rates.
"""
function create_rate_profiles(scenario::Scenario, tariff::Tariff)::Tariff
    # Initialize the updated Tariff struct object
    tariff_ = Dict{String,Any}(string(i) => getfield(tariff, i) for i in fieldnames(Tariff))
    println("...preparing price profiles")

    # Create the energy charge profile
    tariff_["energy_prices"] = create_energy_rate_profile(scenario, tariff)

    # Create the demand charge profile
    if !isnothing(tariff.monthly_maximum_demand_rates) |
       !isnothing(tariff.monthly_demand_tou_rates) |
       !isnothing(tariff.daily_demand_tou_rates)
        tariff_["demand_prices"], tariff_["demand_mask"] =
            create_demand_rate_profile(scenario, tariff)
    end

    # Create the net energy metering (NEM) sell price profile
    if tariff.nem_enabled
        tariff_["nem_prices"] = create_nem_rate_profile(tariff, tariff_["energy_prices"])
    end

    # Convert Dict to NamedTuple
    tariff_ = (; (Symbol(k) => v for (k, v) in tariff_)...)

    # Convert NamedTuple to Tariff object
    tariff_ = Tariff(; tariff_...)

    return tariff_
end

"""
    identify_weekends(timestamp::Union{Vector{Dates.Date},Dates.Date}, month_id::Int64)

Indicates whether a provided timestamp is a weekend day. Can consider a DataFrame of 
timestamps (evaluated pointwise) or a single timestamp.
"""
function identify_weekends(
    timestamp::Union{Vector{Dates.DateTime},Dates.Date},
    month_id::Int64,
)
    return (
        (Dates.dayofweek.(timestamp) .== Saturday) .|
        (Dates.dayofweek.(timestamp) .== Sunday)
    ) .& (Dates.month.(timestamp) .== month_id)
end

"""
    identify_holidays(timestamp::Union{Vector{Dates.Date},Dates.Date}, month_id::Int64)

Indicates whether a provided timestamp is one of the following holidays: New Years Day, 
Presidents' Day, Memorial Day, Independence Day, Labor Day, Veterans Day, Thanksgiving Day, 
and Christmas Day. Can consider a DataFrame of timestamps (evaluated pointwise) or a single 
timestamp.
"""
function identify_holidays(
    timestamp::Union{Vector{Dates.DateTime},Dates.Date},
    month_id::Int64,
)
    return (
        ((Dates.month.(timestamp) .== 1) .& (Dates.day.(timestamp) .== 1)) .|
        (
            (Dates.month.(timestamp) .== 2) .&
            (Dates.dayofweek.(timestamp) .== Monday) .&
            (Dates.dayofweekofmonth.(timestamp) .== 3)
        ) .|
        (
            (Dates.month.(timestamp) .== 5) .&
            (Dates.dayofweek.(timestamp) .== Monday) .&
            (Dates.dayofweekofmonth.(timestamp) .== Dates.daysofweekinmonth.(timestamp))
        ) .|
        ((Dates.month.(timestamp) .== 7) .& (Dates.day.(timestamp) .== 4)) .|
        (
            (Dates.month.(timestamp) .== 9) .&
            (Dates.dayofweek.(timestamp) .== Monday) .&
            (Dates.dayofweekofmonth.(timestamp) .== 1)
        ) .|
        ((Dates.month.(timestamp) .== 11) .& (Dates.day.(timestamp) .== 11)) .|
        (
            (Dates.month.(timestamp) .== 11) .&
            (Dates.dayofweek.(timestamp) .== Thursday) .&
            (Dates.dayofweekofmonth.(timestamp) .== 4)
        ) .|
        ((Dates.month.(timestamp) .== 12) .& (Dates.day.(timestamp) .== 25))
    ) .& (Dates.month.(timestamp) .== month_id)
end
