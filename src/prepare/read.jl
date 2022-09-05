"""
    read_scenario(filepath)

Load scenario parameters from .csv file and return them in a Scenario struct.
"""
function read_scenario(filepath::String)::Scenario
    # Initialize scenario struct
    scenario = Dict{String,Any}(
        "problem_type" => "",
        "interval_length" => "hour",
        "optimization_horizon" => "month",
        "weather_data" => nothing,
        "latitude" => nothing,
        "longitude" => nothing,
        "timezone" => nothing,
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
        for k in intersect(keys(scenario), names(scenario_parameters))
            if !ismissing(scenario_parameters[1, k])
                scenario[k] = scenario_parameters[1, k]
            else
                if k in ["latitude", "longitude", "timezone", "payback_period"]
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

    # Try to access the specified weather data
    try
        # Get the file name of the desired weather data
        weather_file_name =
            DataFrames.DataFrame(
                CSV.File(joinpath(filepath, "scenario_parameters.csv"); transpose=true),
            )[
                1,
                "weather_file_name",
            ] * ".csv"

        # Access the weather data from the specified location; silencewarnings set to true 
        # to avoid excessive missing data warnings
        weather_data = DataFrames.DataFrame(
            CSV.File(
                joinpath(filepath, "weather_data", weather_file_name);
                silencewarnings=true,
            ),
        )

        # Try to populate the latitiude and longitude data
        for k in ["latitude", "longitude"]
            if scenario[k] == nothing
                try
                    scenario[k] = abs(parse(Float64, weather_data[1, titlecase(k)]))
                catch e
                    throw(
                        ErrorException(
                            "The " *
                            k *
                            " parameter is not provided in the weather data. Please try again.",
                        ),
                    )
                end
            elseif floor(abs(parse(Float64, weather_data[1, titlecase(k)])); digits=1) !=
                   floor(scenario[k]; digits=1)
                throw(
                    ErrorException(
                        "User-defined " *
                        k *
                        " does not match that listed in the weather data. Please try again.",
                    ),
                )
            end
        end

        # Create mapping between UTC offset and time zone name
        utc_offset_to_timezone = Dict(
            -5 => "Eastern",
            -6 => "Central",
            -7 => "Mountain",
            -8 => "Pacific",
            -9 => "Alaskan",
            -10 => "Hawaiian",
        )

        # Try to populate the time zone data
        if scenario["timezone"] == nothing
            try
                scenario["timezone"] =
                    utc_offset_to_timezone[parse(Int64, weather_data[1, "Time Zone"])]
            catch e
                throw(
                    ErrorException(
                        "The timezone parameter is not provided in the weather data. Please try again",
                    ),
                )
            end
        elseif utc_offset_to_timezone[parse(Int64, weather_data[1, "Time Zone"])] !=
               scenario["timezone"]
            throw(
                ErrorException(
                    "User-defined time zone does not match that listed in the weather " *
                    "data. Please try again.",
                ),
            )
        end

        # Trim weather_data to only include the weather data; exclude location information
        weather_data = weather_data[2:end, all.(!ismissing, eachcol(weather_data))]
        weather_data = rename!(weather_data, Symbol.(Vector(weather_data[1, :])))[2:end, :]

        # Try to populate the weather data
        try
            # Initialize the DataFrame with time stamps
            scenario["weather_data"] = DataFrames.DataFrame(
                "timestamp" => collect(
                    Dates.DateTime(scenario["year"], 1, 1, 0):Dates.Hour(1):Dates.DateTime(
                        scenario["year"],
                        12,
                        31,
                        23,
                    ),
                ),
            )

            # Check that the user-defined year is as long as the provided weather data
            if length(scenario["weather_data"][:, "timestamp"]) !=
               length(weather_data[:, "DNI"])
                throw(
                    ErrorException(
                        "The user-defined year and weather data have a length mismatch. " *
                        "Please try again.",
                    ),
                )
            end

            # Add the weather data to the appropriate DataFrame
            insertcols!(
                scenario["weather_data"],
                "timestamp",
                "DNI" => parse.(Float64, weather_data[:, "DNI"]),
                "DHI" => parse.(Float64, weather_data[:, "DHI"]),
                "GHI" => parse.(Float64, weather_data[:, "GHI"]),
                "Temperature" => parse.(Float64, weather_data[:, "Temperature"]),
                "Wind Speed" => parse.(Float64, weather_data[:, "Wind Speed"]),
                after=true,
            )
        catch e
            throw(
                ErrorException(
                    "The provided weather data does not contain the expected " *
                    "information. Please try again.",
                ),
            )
        end
    catch e
        throw(
            ErrorException(
                "Weather data not found in the specified location. Please try again.",
            ),
        )
    end

    # Check the problem type
    if lowercase(scenario["problem_type"]) in ["production_cost", "pcm"]
        scenario["problem_type"] = "pcm"
    elseif lowercase(scenario["problem_type"]) in ["capacity_expansion", "cem"]
        scenario["problem_type"] = "cem"
    else
        throw(
            ErrorException(
                "The problem type must be either production_cost or " *
                "capacity_expansion. Please try again.",
            ),
        )
    end

    # Check the interval length
    if lowercase(scenario["interval_length"]) in ["hour"]
        scenario["interval_length"] = uppercase(scenario["interval_length"])
    else
        throw(
            ErrorException(
                "Only interval lengths of one hour are supported at this time. Please " *
                "try again.",
            ),
        )
    end

    # Check the optimization horizon
    if lowercase(scenario["optimization_horizon"]) in ["day", "month", "year"]
        scenario["optimization_horizon"] = uppercase(scenario["optimization_horizon"])
    else
        throw(
            ErrorException(
                "The optimization horizon must be either a day, month, or year. Please " *
                "try again.",
            ),
        )
    end

    # Convert Dict to NamedTuple
    scenario = (; (Symbol(k) => v for (k, v) in scenario)...)

    # Convert NamedTuple to Scenario object
    scenario = Scenario(; scenario...)

    return scenario
end

"""
    read_tariff(filepath)

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
            Dict("summer" => [6, 7, 8, 9], "winter" => [1, 2, 3, 4, 5, 10, 11, 12]),
        "energy_tou_rates" => nothing,
        "energy_tiered_rates" => nothing,
        "monthly_maximum_demand_rates" => nothing,
        "monthly_demand_tou_rates" => nothing,
        "daily_demand_tou_rates" => nothing,
        "nem_enabled" => false,
        "nem_non_bypassable_charge" => nothing,
        "customer_charge" => Dict("daily" => 0.0, "monthly" => 0.0),
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
        if tariff_parameters[1, k] != "missing"
            tariff[k] = tariff_parameters[1, k]
        else
            if k in ["utility_name", "tariff_name"]
                println("The " * k * " parameter is not defined. Will default to nothing.")
            else
                println("The " * k * " parameter is not defined. Will default to false.")
            end
        end
    end

    # Try assigning the months from the file
    if tariff["seasonal_month_split"]
        for k in filter(x -> occursin("months", x), names(tariff_parameters))
            if length(tariff_parameters[tariff_parameters[:, k] .!= "missing", :][:, k]) > 0
                tariff["months_by_season"][chop(k; tail=length("_months"))] =
                    tariff_parameters[tariff_parameters[:, k] .!= "missing", :][:, k]
            end
        end
    else
        tariff["months_by_season"] = Dict("base" => [x for x = 1:12])
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
                if k == "monthly_maximum_demand"
                    tariff[k * "_rates"][s] = Dict(
                        "rate" => tariff_parameters[
                            tariff_parameters[:, k * "_seasons"] .== s,
                            :,
                        ][
                            :,
                            k * "_values",
                        ][1],
                    )
                else
                    if length(
                        tariff_parameters[tariff_parameters[:, k * "_seasons"] .== s, :][
                            :,
                            k * "_values",
                        ],
                    ) > 0
                        tariff[k * "_rates"][s] =
                            Dict(x => Dict("rate" => 0.0, "label" => "") for x = 0:23)
                        for r in eachrow(
                            tariff_parameters[
                                tariff_parameters[:, k * "_seasons"] .== s,
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

    # Check to make sure the energy charge is provided
    if tariff["energy_tou_rates"] == nothing
        throw(ErrorException("No energy rates were provided. Please try again."))
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
function read_market(filepath::String)::Market
    # Initialize market struct
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
                if k in ["iso_name"]
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
    for market_product in ["reg_up", "reg_dn", "sp_res", "ns_res"]
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
function read_incentives(filepath::String)::Incentives
    # Initialize incentives struct
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
                if k in ["itc_enabled", "sgip_enabled"]
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
function read_demand(filepath::String)::Demand
    # Initialize demand struct
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
        throw(
            ErrorException(
                "Demand profile not found in " * filepath * ". Please try again.",
            ),
        )
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
function read_solar(filepath::String)::Solar
    # Initialize solar struct
    solar = Dict{String,Any}(
        "enabled" => false,
        "capacity_factor_profile" => nothing,
        "power_capacity" => nothing,
        "module_manufacturer" => nothing,
        "module_name" => nothing,
        "module_nominal_power" => nothing,
        "module_rated_voltage" => nothing,
        "module_rated_current" => nothing,
        "module_oc_voltage" => nothing,
        "module_sc_current" => nothing,
        "module_voltage_temp_coeff" => nothing,
        "module_current_temp_coeff" => nothing,
        "module_noct" => nothing,
        "module_number_of_cells" => nothing,
        "module_cell_material" => nothing,
        "pv_capital_cost" => nothing,
        "collector_azimuth" => nothing,
        "tilt_angle" => nothing,
        "ground_reflectance" => "default",
        "tracker" => "fixed",
        "tracker_capital_cost" => nothing,
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
        for k in intersect(keys(solar), names(solar_parameters))
            if !ismissing(solar_parameters[1, k])
                solar[k] = solar_parameters[1, k]
            else
                if k in ["enabled"]
                    println(
                        "The " * k * " parameter is not defined. Will default to false.",
                    )
                elseif k in ["ground_reflectance"]
                    println(
                        "The " *
                        k *
                        " parameter is not defined. Will default to 'default'.",
                    )
                elseif k in ["tracker"]
                    println(
                        "The " * k * " parameter is not defined. Will default to 'fixed'.",
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

    # Try loading the capacity factor profile if solar is enabled
    if solar["enabled"]
        capacity_factor_file_path = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "solar_parameters.csv"); transpose=true),
        )[
            1,
            "capacity_factor_file_path",
        ]
        if !ismissing(capacity_factor_file_path)
            try
                solar["capacity_factor_profile"] = DataFrames.DataFrame(
                    CSV.File(joinpath(filepath, capacity_factor_file_path)),
                )
            catch e
                println(
                    "Capacity factor profile not found in " *
                    filepath *
                    ". Please try again.",
                )
                solar["enabled"] = false
            end
        end

        # Check that PV module specifications or a capacity factor profile are provided
        if (solar["capacity_factor_profile"] == nothing) & any(
            x -> x == nothing,
            [
                solar["module_nominal_power"],
                solar["module_rated_voltage"],
                solar["module_rated_current"],
                solar["module_oc_voltage"],
                solar["module_sc_current"],
                solar["module_voltage_temp_coeff"],
                solar["module_current_temp_coeff"],
                solar["module_noct"],
                solar["module_number_of_cells"],
                solar["module_cell_material"],
            ],
        )
            throw(
                ErrorException(
                    "Solar is enabled, but not enough information is provided to build " *
                    "the capacity factor profile. Please try again.",
                ),
            )
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
function read_storage(filepath::String)::Storage
    # Initialize storage struct
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
    for k in ["charge_eff", "discharge_eff"]
        if storage[k] > 1.0
            throw(
                ErrorException(
                    "The provided " *
                    k *
                    " parameter is greater than 1. Please only use values between 0 and " *
                    "1, inclusive.",
                ),
            )
        elseif storage[k] < 0.0
            throw(
                ErrorException(
                    "The provided " *
                    k *
                    " parameter is less than 0. Please only use values between 0 and 1, " *
                    "inclusive.",
                ),
            )
        end
    end

    # Convert Dict to NamedTuple
    storage = (; (Symbol(k) => v for (k, v) in storage)...)

    # Convert NamedTuple to Storage object
    storage = Storage(; storage...)

    return storage
end
