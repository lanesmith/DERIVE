"""
    create_energy_rate_profile(scenario, tariff)

Create the profiles that describe how consumers are exposed to energy charges.
"""
function create_energy_rate_profile(
    scenario::Scenario,
    tariff::Tariff,
)::DataFrames.DataFrame
    # Determine whether it is a leap year and create annual profile with hourly increments
    if scenario.year % 4 == 0
        profile = DataFrames.DataFrame(
            "timestamp" => collect(
                Dates.DateTime(scenario.year, 1, 1, 0):Dates.Hour(1):Dates.DateTime(
                    scenario.year,
                    12,
                    31,
                    23,
                ),
            ),
            "rates" => zeros(366 * 24),
        )
    else
        profile = DataFrames.DataFrame(
            "timestamp" => collect(
                Dates.DateTime(scenario.year, 1, 1, 0):Dates.Hour(1):Dates.DateTime(
                    scenario.year,
                    12,
                    31,
                    23,
                ),
            ),
            "rates" => zeros(365 * 24),
        )
    end

    # Create inverse mapping of seasons to months
    seasons_by_month = Dict(
        v => k for k in keys(tariff.months_by_season) for
        v in values(tariff.months_by_season[k])
    )

    # Determine whether there is a distinction between rates on a monthly basis
    if tariff.seasonal_month_split
        for m in sort!(reduce(vcat, values(tariff.months_by_season)))
            for h in sort!(
                collect(
                    keys(
                        tariff.energy_tou_rates[collect(keys(tariff.energy_tou_rates))[1]],
                    ),
                ),
            )
                # Set rates by hour and month
                profile[:, "rates"] .=
                    ifelse.(
                        (hour.(profile.timestamp) .== h) .&
                        (month.(profile.timestamp) .== m),
                        tariff.energy_tou_rates[seasons_by_month[m]][h]["rate"],
                        profile[:, "rates"],
                    )

                # Determine whether there is a distinction between weekdays and weekends
                if tariff.weekday_weekend_split
                    profile[:, "rates"] .= adjust_for_weekends(
                        profile,
                        m,
                        tariff.energy_tou_rates[seasons_by_month[m]][0]["rate"],
                        profile[:, "rates"],
                    )
                end

                # Determine whether or not there is a distinction between holidays
                if tariff.holiday_split
                    profile[:, "rates"] .= adjust_for_holidays(
                        profile,
                        m,
                        tariff.energy_tou_rates[seasons_by_month[m]][0]["rate"],
                        profile[:, "rates"],
                    )
                end
            end
        end
    else
        for h in sort!(
            collect(
                keys(tariff.energy_tou_rates[collect(keys(tariff.energy_tou_rates))[1]]),
            ),
        )
            # Set rates by hour
            profile[:, "rates"] .=
                ifelse.(
                    hour.(profile.timestamp) .== h,
                    tariff.energy_tou_rates["base"][h]["rates"],
                    profile[:, "rates"],
                )

            # Determine whether there is a distinction between weekdays and weekends
            if tariff.weekday_weekend_split
                profile[:, "rates"] .= adjust_for_weekends(
                    profile,
                    m,
                    tariff.energy_tou_rates["base"][0]["rate"],
                    profile[:, "rates"],
                )
            end

            # Determine whether or not there is a distinction between holidays
            if tariff.holiday_split
                profile[:, "rates"] .= adjust_for_holidays(
                    profile,
                    m,
                    tariff.energy_tou_rates["base"][0]["rate"],
                    profile[:, "rates"],
                )
            end
        end
    end

    # Return the profile for energy rates
    return profile
end

"""
    create_demand_rate_profile(scenario, tariff)

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
    seasons_by_month = Dict(
        v => k for k in keys(tariff.months_by_season) for
        v in values(tariff.months_by_season[k])
    )

    # Create masks and rates for monthly maximum demand charges
    if tariff.monthly_maximum_demand_rates != nothing
        for m in sort!(reduce(vcat, values(tariff.months_by_season)))
            # Initialize the mask and set the rate
            mask[:, "monthly_maximum_" * string(m)] = zeros(length(mask[:, "timestamp"]))
            rates["monthly_maximum_" * string(m)] =
                tariff.monthly_maximum_demand_rates[seasons_by_month[m]]["rate"]

            # Set the mask accordingly
            mask[:, "monthly_maximum_" * string(m)] =
                ifelse.(
                    month.(mask.timestamp) .== m,
                    1,
                    mask[:, "monthly_maximum_" * string(m)],
                )
        end
    end

    # Create masks and rates for monthly maximum time-of-use (TOU) demand charges
    if tariff.monthly_demand_tou_rates != nothing
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
                            string(m)
                        ) in names(mask)
                    )
                        mask[
                            :,
                            "monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                m,
                            ),
                        ] = zeros(length(mask[:, "timestamp"]))
                        rates["monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                            m,
                        )] = tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["rate"]
                    end

                    # Set the mask accordingly
                    mask[
                        :,
                        "monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                            m,
                        ),
                    ] =
                        ifelse.(
                            (month.(mask.timestamp) .== m) .& (hour.(mask.timestamp) .== h),
                            1,
                            mask[
                                :,
                                "monthly_" * tariff.monthly_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                    m,
                                ),
                            ],
                        )
                end
            end
        end
    end

    # Create masks and rates for daily maximum time-of-use (TOU) demand charges
    if tariff.daily_demand_tou_rates != nothing
        for m in sort!(reduce(vcat, values(tariff.months_by_season)))
            for d = 1:Dates.daysinmonth(Date(scenario.year, m))
                for h in sort!(
                    collect(
                        keys(
                            tariff.daily_demand_tou_rates[collect(
                                keys(tariff.daily_demand_tou_rates),
                            )][1],
                        ),
                    ),
                )
                    # Initialize the mask and set the rate
                    if tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] != ""
                        # Check if a particular demand charge has already been accounted for
                        if !(
                            (
                                "daily_" *
                                tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] *
                                "_" *
                                string(m) *
                                "_" *
                                string(d)
                            ) in names(mask)
                        )
                            mask[
                                :,
                                "daily_" * tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                    m,
                                ) * "_" * string(d),
                            ] = zeros(length(mask[:, "timestamp"]))
                            rates["daily_" * tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                m,
                            ) * "_" * string(d)] =
                                tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["rate"]
                        end

                        # Set the mask accordingly
                        mask[
                            :,
                            "daily_" * tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                m,
                            ) * "_" * string(d),
                        ] =
                            ifelse.(
                                (month.(mask.timestamp) .== m) .&
                                (day.(mask.timestep) .== d) .&
                                (hour.(mask.timestamp) .== h),
                                1,
                                mask[
                                    :,
                                    "daily_" * tariff.daily_demand_tou_rates[seasons_by_month[m]][h]["label"] * "_" * string(
                                        m,
                                    ) * "_" * string(d),
                                ],
                            )
                    end
                end
            end
        end
    end

    # Return the rates and mask for the demand rates
    return rates, mask
end

"""
    create_nem_rate_profile(tariff, energy_price_profile)

Create the profile that describes the rate at which consumers can sell excess solar 
generation via a net energy metering (NEM) program.
"""
function create_nem_rate_profile(
    tariff::Tariff,
    energy_price_profile::DataFrame,
)::DataFrames.DataFrame
    # Create profile of NEM sell prices using the profile of energy prices
    profile = deepcopy(energy_price_profile)
    profile[:, "rates"] .-= tariff.nem_non_bypassable_charge

    # Return the profile for NEM sell rates
    return profile
end

"""
    create_rate_profiles(scenario, tariff)

Create the profiles that describe how consumers are exposed to demand charges, energy 
charges, and net metering sell rates.
"""
function create_rate_profiles(scenario::Scenario, tariff::Tariff)::Prices
    # Initialize prices struct
    prices = Dict{String,Any}(
        "energy" => nothing,
        "demand_rates" => nothing,
        "demand_mask" => nothing,
        "nem" => nothing,
    )

    # Create the energy charge profile
    prices["energy"] = create_energy_rate_profile(scenario, tariff)

    # Create the demand charge profile
    if (tariff.monthly_demand_tou_rates != nothing) |
       (tariff.daily_demand_tou_rates != nothing)
        prices["demand_rates"], prices["demand_mask"] =
            create_demand_rate_profile(scenario, tariff)
    end

    # Create the net energy metering (NEM) sell price profile
    if tariff.nem_enabled
        prices["nem"] = create_nem_rate_profile(tariff, prices["energy"])
    end

    # Convert Dict to NamedTuple
    prices = (; (Symbol(k) => v for (k, v) in prices)...)

    # Convert NamedTuple to Tariff object
    prices = Prices(; prices...)

    return prices
end

"""
    adjust_for_weekends(profile, month_id, weekend_value, original_value)

Adjust a provided profile according to the weekend dates.
"""
function adjust_for_weekends(
    profile::DataFrames.DataFrame,
    month_id::Int64,
    weekend_value::Float64,
    original_value::Vector{Float64},
)
    return ifelse.(
        (
            (dayofweek.(profile.timestamp) .== Saturday) .|
            (dayofweek.(profile.timestamp) .== Sunday)
        ) .& (month.(profile.timestamp) .== month_id),
        weekend_value,
        original_value,
    )
end

"""
    adjust_for_holidays(profile, month_id, holiday_value, original_value)

Adjust a provided profile according to the following holidays: New Years Day, Prsidents' 
Day, Memorial Day, Independence Day, Labor Day, Veterans Day, Thanksgiving Day, and 
Christmas Day.
"""
function adjust_for_holidays(
    profile::DataFrames.DataFrame,
    month_id::Int64,
    holiday_value::Float64,
    original_value::Vector{Float64},
)
    return ifelse.(
        (
            ((month.(profile.timestamp) .== 1) .& (day.(profile.timestamp) .== 1)) .|
            (
                (month.(profile.timestamp) .== 2) .&
                (dayofweek.(profile.timestamp) .== Monday) .&
                (dayofweekofmonth.(profile.timestamp) .== 3)
            ) .|
            (
                (month.(profile.timestamp) .== 5) .&
                (dayofweek.(profile.timestamp) .== Monday) .&
                (
                    dayofweekofmonth.(profile.timestamp) .==
                    daysofweekinmonth.(profile.timestamp)
                )
            ) .|
            ((month.(profile.timestamp) .== 7) .& (day.(profile.timestamp) .== 4)) .|
            (
                (month.(profile.timestamp) .== 9) .&
                (dayofweek.(profile.timestamp) .== Monday) .&
                (dayofweekofmonth.(profile.timestamp) .== 1)
            ) .|
            ((month.(profile.timestamp) .== 11) .& (day.(profile.timestamp) .== 11)) .|
            (
                (month.(profile.timestamp) .== 11) .&
                (dayofweek.(profile.timestamp) .== Thursday) .&
                (dayofweekofmonth.(profile.timestamp) .== 4)
            ) .|
            ((month.(profile.timestamp) .== 12) .& (day.(profile.timestamp) .== 25))
        ) .& (month.(profile.timestamp) .== month_id),
        holiday_value,
        original_value,
    )
end
