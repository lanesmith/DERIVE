"""
    read_tariff(filepath::String)::Tariff

Load tariff prices and parameters from .csv files and return them in a Tariff struct.
"""
function read_tariff(filepath::String)::Tariff
    # Initialize tariff struct
    tariff = Dict{String,Any}(
        "utility_name" => nothing,
        "tariff_name" => nothing,
        "weekday_weekend_split" => false,
        "holiday_split" => false,
        "seasonal_month_split" => true,
        "months_by_season" => Dict{String,Vector{Int64}}(
            "summer" => [6, 7, 8, 9],
            "winter" => [1, 2, 3, 4, 5, 10, 11, 12],
        ),
        "energy_tou_rates" => nothing,
        "energy_tiered_rates" => nothing,
        "energy_tiered_baseline_type" => nothing,
        "monthly_maximum_demand_rates" => nothing,
        "monthly_demand_tou_rates" => nothing,
        "daily_demand_tou_rates" => nothing,
        "nem_enabled" => false,
        "nem_version" => 2,
        "non_bypassable_charge" => nothing,
        "average_nem_3_over_years" => false,
        "nem_3_year" => nothing,
        "customer_charge" => Dict{String,Float64}("daily" => 0.0, "monthly" => 0.0),
        "energy_prices" => nothing,
        "demand_prices" => nothing,
        "demand_mask" => nothing,
        "nem_prices" => nothing,
        "energy_charge_scaling" => 1.0,
        "demand_charge_scaling" => 1.0,
        "tou_energy_charge_scaling" => 1.0,
        "tou_energy_charge_scaling_period" => nothing,
        "tou_energy_charge_scaling_indicator" => nothing,
        "all_charge_scaling" => 1.0,
    )

    # Try loading the tariff parameters
    println("...loading tariff parameters")
    tariff_parameters = DataFrames.DataFrame(
        CSV.File(joinpath(filepath, "tariff_parameters.csv"); transpose=true),
    )

    # Try assigning the similar tariff parameters from the file
    for k in intersect(keys(tariff), names(tariff_parameters))
        if !ismissing(tariff_parameters[1, k])
            tariff[k] = tariff_parameters[1, k]
        else
            println(
                "The " *
                k *
                " parameter is not defined. Will default to " *
                string(tariff[k]) *
                ".",
            )
        end
    end

    # Try loading the tariff information
    tariff_information = DataFrames.DataFrame(
        CSV.File(
            joinpath(
                filepath,
                "tariff_data",
                tariff_parameters[1, "tariff_file_name"] * ".csv",
            );
            transpose=true,
        ),
    )

    # Replace missing values in the loaded tariff information DataFrame
    tariff_information = coalesce.(tariff_information, "missing")

    # Try assigning the similar tariff information from the file
    for k in intersect(keys(tariff), names(tariff_information))
        if !ismissing(tariff_information[1, k])
            tariff[k] = tariff_information[1, k]
        else
            println(
                "The " *
                k *
                " parameter is not defined. Will default to " *
                string(tariff[k]) *
                ".",
            )
        end
    end

    # Try assigning the months from the file
    if tariff["seasonal_month_split"]
        for k in filter(x -> occursin("months", x), names(tariff_information))
            if length(tariff_information[tariff_information[!, k] .!= "missing", :][!, k]) >
               0
                tariff["months_by_season"][chop(k; tail=length("_months"))] =
                    tariff_information[tariff_information[:, k] .!= "missing", :][!, k]
            end
        end
    else
        tariff["months_by_season"] = Dict{String,Vector{Int64}}("base" => [x for x = 1:12])
    end

    # Try assigning the customer charges from the file
    for k in filter(x -> occursin("customer_charge", x), names(tariff_information))
        if !all(x -> x == "missing", tariff_information[!, k])
            tariff["customer_charge"][chop(k; tail=length("_customer_charge"))] =
                tariff_information[1, k]
        end
    end

    # Try assigning the various energy and demand rates from the file
    for k in
        chop.(
        filter(x -> occursin("values", x), names(tariff_information)),
        tail=length("_values"),
    )
        if !all(x -> x == "missing", tariff_information[!, k * "_values"])
            tariff[k * "_rates"] = Dict{String,Dict}()
            for s in
                filter(x -> x != "missing", unique(tariff_information[!, k * "_seasons"]))
                if k == "monthly_maximum_demand"
                    tariff[k * "_rates"][s] = Dict{String,Float64}(
                        "rate" => tariff_information[
                            tariff_information[!, k * "_seasons"] .== s,
                            :,
                        ][
                            !,
                            k * "_values",
                        ][1],
                    )
                else
                    if length(
                        tariff_information[tariff_information[!, k * "_seasons"] .== s, :][
                            !,
                            k * "_values",
                        ],
                    ) > 0
                        tariff[k * "_rates"][s] = Dict{Int64,Dict}(
                            x => Dict{String,Any}("rate" => 0.0, "label" => "") for
                            x = 0:23
                        )
                        for r in eachrow(
                            tariff_information[
                                tariff_information[!, k * "_seasons"] .== s,
                                :,
                            ],
                        )
                            for h = (r[k * "_start"]):(r[k * "_end"] - 1)
                                tariff[k * "_rates"][s][h]["rate"] = r[k * "_values"]
                                tariff[k * "_rates"][s][h]["label"] = r[k * "_labels"]
                            end
                        end
                    end
                end
            end
        end
    end

    # Try assigning the tiered energy rate information from the file
    if !all(x -> x == "missing", tariff_information[!, "energy_tiered_lower_bounds"])
        tariff["energy_tiered_rates"] = Dict{Int64,Dict}()
        for s in filter(
            x -> x != "missing",
            unique(tariff_information[!, "energy_tiered_seasons"]),
        )
            energy_tiered_seasons_ids =
                findall(x -> x == s, tariff_information[!, "energy_tiered_seasons"])
            for m in tariff["months_by_season"][s]
                tariff["energy_tiered_rates"][m] = Dict{Int64,Any}()
                for i in eachindex(energy_tiered_seasons_ids)
                    tariff["energy_tiered_rates"][m][i] = Dict{String,Any}()
                    if i == length(energy_tiered_seasons_ids)
                        tariff["energy_tiered_rates"][m][i]["bounds"] = [
                            tariff_information[
                                energy_tiered_seasons_ids[i],
                                "energy_tiered_lower_bounds",
                            ],
                            Inf,
                        ]
                    else
                        tariff["energy_tiered_rates"][m][i]["bounds"] = [
                            tariff_information[
                                energy_tiered_seasons_ids[i],
                                "energy_tiered_lower_bounds",
                            ],
                            tariff_information[
                                energy_tiered_seasons_ids[i + 1],
                                "energy_tiered_lower_bounds",
                            ],
                        ]
                    end
                    tariff["energy_tiered_rates"][m][i]["price"] = tariff_information[
                        energy_tiered_seasons_ids[i],
                        "energy_tiered_adders",
                    ]
                end
            end
        end
    end
    if tariff_information[1, "energy_tiered_daily_or_monthly_usage"] != "missing"
        tariff["energy_tiered_baseline_type"] =
            tariff_information[1, "energy_tiered_daily_or_monthly_usage"]
    end

    # Check to make sure the energy charge is provided
    if isnothing(tariff["energy_tou_rates"])
        throw(ErrorException("No energy rates were provided. Please try again."))
    end

    # Check on the information provided for the tiered energy rate
    if isnothing(tariff["energy_tiered_baseline_type"])
        # Make sure the usage indicator is provided if tiered energy rate information is 
        # provided
        if !isnothing(tariff["energy_tiered_rates"])
            throw(
                ErrorException(
                    "A usage indicator must be provided to consider tiered energy " *
                    "rates. Please try again.",
                ),
            )
        end
    else
        # Make sure the usage indicator is either daily or monthly
        if !(tariff["energy_tiered_baseline_type"] in ["daily", "monthly"])
            throw(
                ErrorException(
                    "The usage indicator for the tiered energy rate was not for a daily " *
                    "or monthly baseline. Please try again.",
                ),
            )
        end
    end

    # Check to make sure the necessary net energy metering (NEM) information is provided
    if tariff["nem_enabled"]
        if tariff["nem_version"] == 2
            # Check that a non-bypassable charge is provided under NEM 2.0
            if isnothing(tariff["non_bypassable_charge"])
                throw(
                    ErrorException(
                        "No non-bypassable charge, which is needed under NEM 2.0, was " *
                        "provided. Please try again.",
                    ),
                )
            end
        elseif tariff["nem_version"] == 3
            # Check that the directory of NEM 3.0 component prices exists
            if isdir(joinpath(filepath, "nem_3_data"))
                if length(readdir(joinpath(filepath, "nem_3_data"))) == 0
                    throw(
                        ErrorException(
                            "There are no NEM 3.0 component price data files located in " *
                            "the expected directory. Please try again.",
                        ),
                    )
                end
            else
                throw(
                    ErrorException(
                        "There is no directory containing NEM 3.0 component price data. " *
                        "Please try again.",
                    ),
                )
            end
        end
    end

    # Check that the scaling terms are not less than or equal to zero
    for p in [
        "energy_charge_scaling",
        "demand_charge_scaling",
        "tou_energy_charge_scaling",
        "all_charge_scaling",
    ]
        if tariff[p] < 0.0
            throw(
                ErrorException(
                    "The provided " *
                    p *
                    " parameter is negative, which does not make sense for price-based " *
                    "terms. Please try again.",
                ),
            )
        end
    end

    # Update the scaling terms depending on the all_charge_scaling term
    if tariff["all_charge_scaling"] != 1.0
        for p in
            ["energy_charge_scaling", "demand_charge_scaling", "tou_energy_charge_scaling"]
            tariff[p] = 1.0
        end
    end

    # Check that the time-of-use energy charge scaling period is valid
    if !isnothing(tariff["tou_energy_charge_scaling_period"]) & !(
        tariff["tou_energy_charge_scaling_period"] in
        tariff_information[:, "energy_tou_labels"]
    )
        throw(
            ErrorException(
                "The provided time-of-use energy charge scaling period is not valid " *
                "based on the provided tariff. Please try again.",
            ),
        )
    end

    # Convert Dict to NamedTuple
    tariff = (; (Symbol(k) => v for (k, v) in tariff)...)

    # Convert NamedTuple to Tariff object
    tariff = Tariff(; tariff...)

    return tariff
end
