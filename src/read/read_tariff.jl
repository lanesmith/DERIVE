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
        "months_by_season" =>
            Dict{String,Vector{Int64}}("summer" => [6, 7, 8, 9], "winter" => [1, 2, 3, 4, 5, 10, 11, 12]),
        "energy_tou_rates" => nothing,
        "energy_tiered_rates" => nothing,
        "monthly_maximum_demand_rates" => nothing,
        "monthly_demand_tou_rates" => nothing,
        "daily_demand_tou_rates" => nothing,
        "nem_enabled" => false,
        "nem_non_bypassable_charge" => nothing,
        "customer_charge" => Dict{String,Float64}("daily" => 0.0, "monthly" => 0.0),
        "energy_prices" => nothing,
        "demand_prices" => nothing,
        "demand_mask" => nothing,
        "nem_prices" => nothing,
    )

    # Try loading the tariff parameters
    tariff_parameters = DataFrames.DataFrame(
        CSV.File(joinpath(filepath, "tariff_parameters.csv"); transpose=true),
    )
    println("...loading tariff parameters")

    # Replace missing values in the loaded DataFrame
    tariff_parameters = coalesce.(tariff_parameters, "missing")

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

    # Try assigning the months from the file
    if tariff["seasonal_month_split"]
        for k in filter(x -> occursin("months", x), names(tariff_parameters))
            if length(tariff_parameters[tariff_parameters[!, k] .!= "missing", :][!, k]) > 0
                tariff["months_by_season"][chop(k; tail=length("_months"))] =
                    tariff_parameters[tariff_parameters[:, k] .!= "missing", :][!, k]
            end
        end
    else
        tariff["months_by_season"] = Dict{String,Vector{Int64}}("base" => [x for x = 1:12])
    end

    # Try assigning the customer charges from the file
    for k in filter(x -> occursin("customer_charge", x), names(tariff_parameters))
        if !all(x -> x == "missing", tariff_parameters[!, k])
            tariff["customer_charge"][chop(k; tail=length("_customer_charge"))] =
                tariff_parameters[1, k]
        end
    end

    # Try assigning the various energy and demand rates from the file
    for k in
        chop.(
        filter(x -> occursin("values", x), names(tariff_parameters)),
        tail=length("_values"),
    )
        if !all(x -> x == "missing", tariff_parameters[!, k * "_values"])
            tariff[k * "_rates"] = Dict{String,Dict}()
            for s in
                filter(x -> x != "missing", unique(tariff_parameters[!, k * "_seasons"]))
                if k == "monthly_maximum_demand"
                    tariff[k * "_rates"][s] = Dict{String,Float64}(
                        "rate" => tariff_parameters[
                            tariff_parameters[!, k * "_seasons"] .== s,
                            :,
                        ][
                            !,
                            k * "_values",
                        ][1],
                    )
                else
                    if length(
                        tariff_parameters[tariff_parameters[!, k * "_seasons"] .== s, :][
                            !,
                            k * "_values",
                        ],
                    ) > 0
                        tariff[k * "_rates"][s] =
                            Dict{Int64,Dict}(x => Dict{String,Any}("rate" => 0.0, "label" => "") for x = 0:23)
                        for r in eachrow(
                            tariff_parameters[
                                tariff_parameters[!, k * "_seasons"] .== s,
                                :,
                            ],
                        )
                            for h = (r[k * "_start"] + 1):r[k * "_end"]
                                if h == 24
                                    tariff[k * "_rates"][s][0]["rate"] = r[k * "_values"]
                                    tariff[k * "_rates"][s][0]["label"] = r[k * "_labels"]
                                else
                                    tariff[k * "_rates"][s][h]["rate"] = r[k * "_values"]
                                    tariff[k * "_rates"][s][h]["label"] = r[k * "_labels"]
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    # Try assigning the tiered energy rate information from the file
    if !all(x -> x == "missing", tariff_parameters[!, "energy_tiered_levels"])
        tariff["energy_tiered_rates"] = Dict{String,Dict}()
        for s in filter(
            x -> x != "missing",
            unique(tariff_parameters[!, "energy_tiered_seasons"]),
        )
            tariff["energy_tiered_rates"][s] = Dict{String,Any}()
            tariff["energy_tiered_rates"][s]["tiers"] =
                tariff_parameters[tariff_parameters[!, "energy_tiered_seasons"] .== s, !][
                    !,
                    "energy_tiered_levels",
                ]
            tariff["energy_tiered_rates"][s]["price_adders"] =
                tariff_parameters[tariff_parameters[!, "energy_tiered_seasons"] .== s, !][
                    !,
                    "energy_tiered_adders",
                ]
        end
    end

    # Check to make sure the energy charge is provided
    if isnothing(tariff["energy_tou_rates"])
        throw(ErrorException("No energy rates were provided. Please try again."))
    end

    # Convert Dict to NamedTuple
    tariff = (; (Symbol(k) => v for (k, v) in tariff)...)

    # Convert NamedTuple to Tariff object
    tariff = Tariff(; tariff...)

    return tariff
end
