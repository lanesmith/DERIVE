"""
    read_scenario(filepath)

Load scenario parameters from .csv file and return them in a Scenario struct.
"""
function read_scenario(filepath::String)
    # Initialize scenario
    scenario = Dict{String,Any}(
        "problem_type" => "",
        "interval_length" => "",
        "payback_period" => nothing,
        "year" => 0,
    )

    # Try loading the scenario parameters
    try
        scenario_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "scenario_parameters.csv"); transpose=true),
        )
        println("...loading scenario parameters")

        # Try assigning the different scenario parameters from the file
        for k in keys(scenario)
            try
                scenario[k] = scenario_parameters[1, k]
            catch e
                if k in ("payback_period")
                    println(
                        "The " * k * " parameter is not defined. Will default to nothing.",
                    )
                else
                    throw(
                        ErrorException(
                            k * " not found in scenario_parameters.csv. Please try again.",
                        ),
                    )
                end
            end
        end
    catch e
        throw(
            ErrorException(
                "Scenario parameters not found in " * filepath * ". Please try again.",
            ),
        )
    end

    # Check the problem type
    if uppercase(scenario["problem_type"]) in ("PRODUCTION_COST", "PCM")
        scenario["problem_type"] = "PCM"
    elseif uppercase(scenario["problem_type"]) in ("CAPACITY_EXPANSION", "CEM")
        scenario["problem_type"] = "CEM"
    else
        throw(
            ErrorException(
                "The problem type must be either production_cost or " *
                "capacity_expansion. Please try again.",
            ),
        )
    end

    # Check the interval length
    if uppercase(scenario["interval_length"]) in ("DAY", "MONTH", "YEAR")
        scenario["interval_length"] = uppercase(scenario["interval_length"])
    else
        throw(
            ErrorException(
                "The interval length must be either day, month, or year. Please try " *
                "again.",
            ),
        )
    end

    # Convert Dict to NamedTuple
    scenario = (; (Symbol(k) => v for (k, v) in scenario)...)

    # Convert NamedTuple to Tariff object
    scenario = Scenario(; scenario...)

    return scenario
end

"""
    read_tariff(filepath)

Load tariff prices and parameters from .csv files and return them in a Tariff struct.
"""
function read_tariff(filepath::String)
    # Initialize tariff
    tariff = Dict{String,Any}(
        "utility_name" => nothing,
        "tariff_name" => nothing,
        "weekday_weekend_split" => false,
        "holiday_split" => false,
        "months_by_season" =>
            Dict("summer" => [6, 7, 8, 9], "winter" => [1, 2, 3, 4, 5, 10, 11, 12]),
        "energy_tou_rates" => nothing,
        "energy_tiered_rates" => nothing,
        "monthly_maximum_demand_rates" => nothing,
        "monthly_demand_tou_rates" => nothing,
        "daily_demand_tou_rates" => nothing,
        "nem_enabled" => false,
        "nem_non_bypassable_charge" => nothing,
        "customer_charge" => Dict("daily" => 0.0, "monthly" => 0.0),
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
        try
            tariff[k] = tariff_parameters[1, k]
        catch e
            if k in ("utility_name", "tariff_name")
                println("The " * k * " parameter is not defined. Will default to nothing.")
            else
                println("The " * k * " parameter is not defined. Will default to false.")
            end
        end
    end

    # Try assigning the months from the file
    for k in filter(x -> occursin("months", x), names(tariff_parameters))
        if length(tariff_parameters[tariff_parameters[:, k] .!= "missing", :][:, k]) > 0
            tariff["months_by_season"][chop(k; tail=length("_months"))] =
                tariff_parameters[tariff_parameters[:, k] .!= "missing", :][:, k]
        end
    end

    # Try assigning the customer charges from the file
    for k in filter(x -> occursin("customer_charge", x), names(tariff_parameters))
        if !all(x -> x == "missing", tariff_parameters[:, k])
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
        if !all(x -> x == "missing", tariff_parameters[:, k * "_values"])
            tariff[k * "_rates"] = Dict()
            for s in
                filter(x -> x != "missing", unique(tariff_parameters[:, k * "_seasons"]))
                tariff[k * "_rates"][s] = Dict()
                if k == "monthly_maximum_demand"
                    tariff[k * "_rates"][s]["rate"] =
                        tariff_parameters[tariff_parameters[:, k * "_seasons"] .== s, :][
                            :,
                            k * "_values",
                        ][1]
                else
                    for l in filter(
                        x -> x != "missing",
                        unique(tariff_parameters[:, k * "_labels"]),
                    )
                        if length(
                            tariff_parameters[
                                (tariff_parameters[
                                    :,
                                    k * "_seasons",
                                ] .== s) .& (tariff_parameters[:, k * "_labels"] .== l),
                                :,
                            ][
                                :,
                                k * "_values",
                            ],
                        ) > 0
                            tariff[k * "_rates"][s][l] = Dict()
                            tariff[k * "_rates"][s][l]["rates"] = tariff_parameters[
                                (tariff_parameters[
                                    :,
                                    k * "_seasons",
                                ] .== s) .& (tariff_parameters[:, k * "_labels"] .== l),
                                :,
                            ][
                                :,
                                k * "_values",
                            ][1]
                            tariff[k * "_rates"][s][l]["hours"] = Vector()
                            for h =
                                1:length(
                                    tariff_parameters[
                                        (tariff_parameters[
                                            :,
                                            k * "_seasons",
                                        ] .== s) .& (tariff_parameters[
                                            :,
                                            k * "_labels",
                                        ] .== l),
                                        :,
                                    ][
                                        :,
                                        k * "_start",
                                    ],
                                )
                                append!(
                                    tariff[k * "_rates"][s][l]["hours"],
                                    (tariff_parameters[
                                        (tariff_parameters[
                                            :,
                                            k * "_seasons",
                                        ] .== s) .& (tariff_parameters[
                                            :,
                                            k * "_labels",
                                        ] .== l),
                                        :,
                                    ][
                                        :,
                                        k * "_start",
                                    ][h] + 1):tariff_parameters[
                                        (tariff_parameters[
                                            :,
                                            k * "_seasons",
                                        ] .== s) .& (tariff_parameters[
                                            :,
                                            k * "_labels",
                                        ] .== l),
                                        :,
                                    ][
                                        :,
                                        k * "_end",
                                    ][h],
                                )
                            end
                            if all(
                                x in tariff[k * "_rates"][s][l]["hours"] for x in [2, 24]
                            )
                                append!(tariff[k * "_rates"][s][l]["hours"], 1)
                            end
                            sort!(tariff[k * "_rates"][s][l]["hours"])
                        end
                    end
                end
            end
        end
    end

    # Try assigning the tiered energy rate information from the file
    if !all(x -> x == "missing", tariff_parameters[:, "energy_tiered_levels"])
        tariff["energy_tiered_rates"] = Dict()
        for s in filter(
            x -> x != "missing",
            unique(tariff_parameters[:, "energy_tiered_seasons"]),
        )
            tariff["energy_tiered_rates"][s] = Dict()
            tariff["energy_tiered_rates"][s]["tiers"] =
                tariff_parameters[tariff_parameters[:, "energy_tiered_seasons"] .== s, :][
                    :,
                    "energy_tiered_levels",
                ]
            tariff["energy_tiered_rates"][s]["price_adders"] =
                tariff_parameters[tariff_parameters[:, "energy_tiered_seasons"] .== s, :][
                    :,
                    "energy_tiered_adders",
                ]
        end
    end

    # Convert Dict to NamedTuple
    tariff = (; (Symbol(k) => v for (k, v) in tariff)...)

    # Convert NamedTuple to Tariff object
    tariff = Tariff(; tariff...)

    return tariff
end

"""
    read_market(filepath)

Load market prices and parameters from .csv files and return them in a Market struct.
"""
function read_market(filepath::String)
    # Initialize market
    market = Dict{String,Any}(
        "iso_name" => nothing,
        "reg_up_enabled" => false,
        "reg_up_prices" => nothing,
        "reg_dn_enabled" => false,
        "reg_dn_prices" => nothing,
        "sp_res_enabled" => false,
        "sp_res_prices" => nothing,
        "ns_res_enabled" => false,
        "ns_res_prices" => nothing,
    )

    # Try loading the market parameters
    try
        market_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "market_parameters.csv"); transpose=true),
        )
        println("...loading market parameters")

        # Try assigning the different incentives parameters from the file
        for k in deleteat!(
            collect(keys(market)),
            findall(
                x -> x in
                ("reg_up_prices", "reg_dn_prices", "sp_res_prices", "ns_res_prices"),
                collect(keys(market)),
            ),
        )
            try
                market[k] = market_parameters[1, k]
            catch e
                if k in ("iso_name")
                    println(
                        "The " * k * " parameter is not defined. Will default to nothing.",
                    )
                else
                    println(
                        "The " * k * " parameter is not defined. Will default to false.",
                    )
                end
            end
        end
    catch e
        println(
            "Market parameters not found in " *
            filepath *
            ". Market parameters will default to not allowing incentives to be " *
            "considered.",
        )
    end

    # Try loading the market price profiles if they are enabled
    for market_product in ("reg_up", "reg_dn", "sp_res", "ns_res")
        if market[market_product * "_enabled"]
            try
                market[market_product * "_prices"] = DataFrames.DataFrame(
                    CSV.File(joinpath(filepath, market_product * "_price_profile.csv")),
                )
                println("...loading " * market_product * " prices")
            catch e
                println(
                    "The " *
                    market_product *
                    " prices are not found in " *
                    filepath *
                    ". The parameters related to the " *
                    market_product *
                    " market will default to not allowing it to be considered.",
                )
                market[market_product * "_enabled"] = false
            end
        end
    end

    # Convert Dict to NamedTuple
    market = (; (Symbol(k) => v for (k, v) in market)...)

    # Convert NamedTuple to Market object
    market = Market(; market...)

    return market
end

"""
    read_incentives(filepath)

Load distributed energy resource (DER) incentive prices and parameters from .csv files 
and return them in an Incentives struct.
"""
function read_incentives(filepath::String)
    # Initialize incentives
    incentives = Dict{String,Any}(
        "itc_enabled" => false,
        "itc_rate" => nothing,
        "sgip_enabled" => false,
        "sgip_rate" => nothing,
    )

    # Try loading the incentives parameters
    try
        incentives_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "incentives_parameters.csv"); transpose=true),
        )
        println("...loading incentives parameters")

        # Try assigning the different incentives parameters from the file
        for k in keys(incentives)
            try
                incentives[k] = incentives_parameters[1, k]
            catch e
                if k in ("itc_enabled", "sgip_enabled")
                    println(
                        "The " * k * " parameter is not defined. Will default to false.",
                    )
                else
                    println(
                        "The " * k * " parameter is not defined. Will default to nothing.",
                    )
                end
            end
        end
    catch e
        println(
            "Incentives parameters not found in " *
            filepath *
            ". Incentives parameters will default to not allowing incentives to be " *
            "considered.",
        )
    end

    # Convert Dict to NamedTuple
    incentives = (; (Symbol(k) => v for (k, v) in incentives)...)

    # Convert NamedTuple to Incentives object
    incentives = Incentives(; incentives...)

    return incentives
end

"""
    read_demand(filepath)

Load demand profiles and parameters for both fixed and variable demand from .csv files 
and return them in a Demand struct.
"""
function read_demand(filepath::String)
    # Initialize demand
    demand = Dict{String,Any}(
        "shift_enabled" => false,
        "shift_capacity_profile" => nothing,
        "shift_duration" => nothing,
    )

    # Try loading the demand profile
    try
        demand["demand_profile"] =
            DataFrames.DataFrame(CSV.File(joinpath(filepath, "demand_profile.csv")))
        println("...loading demand profile")
    catch e
        @error("Demand profile not found in " * filepath * ". Please try again.")
        throw(ErrorException("See above."))
    end

    # Try loading the demand parameters
    try
        demand_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "demand_parameters.csv"); transpose=true),
        )
        println("...loading demand parameters")

        # Try assigning the different demand parameters from the file
        for k in deleteat!(
            collect(keys(demand)),
            findall(x -> x in ("shift_capacity_profile"), collect(keys(demand))),
        )
            try
                demand[k] = demand_parameters[1, k]
            catch e
                if k == "shift_enabled"
                    println(
                        "The " * k * " parameter is not defined. Will default to false.",
                    )
                else
                    println(
                        "The " * k * " parameter is not defined. Will default to nothing.",
                    )
                end
            end
        end
    catch e
        println(
            "Demand parameters not found in " *
            filepath *
            ". Demand parameters will default to not allowing demand to be " *
            "considered.",
        )
    end

    # Try loading the shiftable demand profile if shiftable demand is enabled
    if demand["shift_enabled"]
        try
            demand["shift_capacity_profile"] = DataFrames.DataFrame(
                CSV.File(joinpath(filepath, "shiftable_demand_profile.csv")),
            )
            println("...loading shiftable demand profile")
        catch e
            println(
                "Shiftable demand profile not found in " *
                filepath *
                ". Shiftable demand parameters will default to not allowing " *
                "shiftable demand to be considered.",
            )
            demand["shift_enabled"] = false
        end
    end

    # Convert Dict to NamedTuple
    demand = (; (Symbol(k) => v for (k, v) in demand)...)

    # Convert NamedTuple to Demand object
    demand = Demand(; demand...)

    return demand
end

"""
    read_solar(filepath)

Load solar photovoltaic (PV) generation profiles and parameters from .csv files and 
return them in a Solar struct.
"""
function read_solar(filepath::String)
    # Initialize solar
    solar = Dict{String,Any}(
        "enabled" => false,
        "generation_profile" => nothing,
        "power_capacity" => nothing,
        "pv_capital_cost" => nothing,
        "inverter_eff" => nothing,
        "inverter_capital_cost" => nothing,
        "lifespan" => nothing,
    )

    # Try loading the solar parameters
    try
        solar_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "solar_parameters.csv"); transpose=true),
        )
        println("...loading solar parameters")

        # Try assigning the different solar parameters from the file
        for k in deleteat!(
            collect(keys(solar)),
            findall(x -> x == "generation_profile", collect(keys(solar))),
        )
            try
                solar[k] = solar_parameters[1, k]
            catch e
                if k == "enabled"
                    println(
                        "The " * k * " parameter is not defined. Will default to false.",
                    )
                else
                    println(
                        "The " * k * " parameter is not defined. Will default to nothing.",
                    )
                end
            end
        end
    catch e
        println(
            "Solar parameters not found in " *
            filepath *
            ". Solar parameters will default to not allowing solar to be considered.",
        )
    end

    # Try loading the solar profile if solar is enabled
    if solar["enabled"]
        try
            solar["generation_profile"] =
                DataFrames.DataFrame(CSV.File(joinpath(filepath, "solar_profile.csv")))
            println("...loading solar profile")
        catch e
            println(
                "Solar profile not found in " *
                filepath *
                ". Solar parameters will default to not allowing solar to be " *
                "considered.",
            )
            solar["enabled"] = false
        end
    end

    # Convert Dict to NamedTuple
    solar = (; (Symbol(k) => v for (k, v) in solar)...)

    # Convert NamedTuple to Solar object
    solar = Solar(; solar...)

    return solar
end

"""
    read_storage(filepath)

Load battery energy storage (BES) parameters from .csv files and return them in a 
Storage struct.
"""
function read_storage(filepath::String)
    # Initialize storage
    storage = Dict{String,Any}(
        "enabled" => false,
        "power_capacity" => nothing,
        "energy_capacity" => nothing,
        "charge_eff" => nothing,
        "discharge_eff" => nothing,
        "capital_cost" => nothing,
        "lifespan" => nothing,
    )

    # Try loading the storage parameters
    try
        storage_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "storage_parameters.csv"); transpose=true),
        )
        println("...loading storage parameters")

        # Try assigning the different storage parameters from the file
        for k in keys(storage)
            try
                storage[k] = storage_parameters[1, k]
            catch e
                if k == "enabled"
                    println(
                        "The " * k * " parameter is not defined. Will default to false.",
                    )
                else
                    println(
                        "The " * k * " parameter is not defined. Will default to nothing.",
                    )
                end
            end
        end
    catch e
        println(
            "Storage parameters not found in " *
            filepath *
            ". Storage parameters will default to not allowing storage to be " *
            "considered.",
        )
    end

    # Check the provided efficiencies
    for k in ("charge_eff", "discharge_eff")
        if storage[k] > 1.0
            @error(
                "The provided " *
                k *
                " parameter is greater than 1. Please only use values between 0 and " *
                "1, inclusive."
            )
            throw(ErrorException("See above."))
        elseif storage[k] < 0.0
            @error(
                "The provided " *
                k *
                " parameter is less than 0. Please only use values between 0 and 1, " *
                "inclusive."
            )
            throw(ErrorException("See above."))
        end
    end

    # Convert Dict to NamedTuple
    storage = (; (Symbol(k) => v for (k, v) in storage)...)

    # Convert NamedTuple to Storage object
    storage = Storage(; storage...)

    return storage
end
