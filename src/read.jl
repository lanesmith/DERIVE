"""
    read_scenario(filepath)

Load scenario parameters from .csv file and return them in a Scenario struct.
"""
function read_scenario(filepath::String)
    # Initialize scenario
    scenario = Dict()

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
    tariff = Dict()

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
    market = Dict()

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
    incentives = Dict()

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
    demand = Dict(
        "shift_enabled" => false,
        "shift_capacity_profile" => nothing,
        "shift_duration" => nothing,
    )

    # Try loading the demand profile
    try
        demand["demand_profile"] = CSV.File(
            joinpath(filepath, "demand_profile.csv")
        ) |> DataFrames.DataFrame
        println("...loading demand profile")
    catch e
        @error("Demand profile not found in " * filepath * ". Please try again.")
        throw(ErrorException("See above."))
    end

    # Try loading the demand parameters
    try
        demand_parameters = CSV.File(
            joinpath(filepath, "demand_parameters.csv")
        ) |> DataFrames.DataFrame
        println("...loading demand parameters")

        # Try assigning the different demand parameters from the file
        for k in deleteat!(
            collect(keys(demand)), 
            findall(
                x -> x in ("demand_profile", "shift_capacity_profile"), 
                collect(keys(demand)),
            ),
        )
            try
                demand[k] = demand_parameters[1, k]
            catch e
                if k == "shift_enabled"
                    println(
                        "The " * k * " parameter is not defined. Will default to false."
                    )
                else
                    println(
                        "The " 
                        * k 
                        * " parameter is not defined. Will default to nothing."
                    )
                end
            end
        end
    catch e
        println(
            "Demand parameters not found in " 
            * filepath 
            * ". Demand parameters will default to not allowing demand to be " 
            * "considered."
        )
    end

    # Try loading the shiftable demand profile if shiftable demand is enabled
    if demand["shift_enabled"]
        try
            demand["shift_capacity_profile"] = CSV.File(
                joinpath(filepath, "shiftable_demand_profile.csv")
            ) |> DataFrames.DataFrame
            println("...loading shiftable demand profile")
        catch e
            println(
                "Shiftable demand profile not found in " 
                * filepath 
                * ". Shiftable demand parameters will default to not allowing "
                * "shiftable demand to be considered."
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
    solar = Dict(
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
        solar_parameters = CSV.File(
            joinpath(filepath, "solar_parameters.csv")
        ) |> DataFrames.DataFrame
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
                        "The " * k * " parameter is not defined. Will default to false."
                    )
                else
                    println(
                        "The " 
                        * k 
                        * " parameter is not defined. Will default to nothing."
                    )
                end
            end
        end
    catch e
        println(
            "Solar parameters not found in " 
            * filepath 
            * ". Solar parameters will default to not allowing solar to be considered."
        )
    end

    # Try loading the solar profile if solar is enabled
    if solar["enabled"]
        try
            solar["generation_profile"] = CSV.File(
                joinpath(filepath, "solar_profile.csv")
            ) |> DataFrames.DataFrame
            println("...loading solar profile")
        catch e
            println(
                "Solar profile not found in " 
                * filepath 
                * ". Solar parameters will default to not allowing solar to be " 
                * "considered."
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
    storage = Dict(
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
        storage_parameters = CSV.File(
            joinpath(filepath, "storage_parameters.csv")
        ) |> DataFrames.DataFrame
        println("...loading storage parameters")

        # Try assigning the different storage parameters from the file
        for k in keys(storage)
            try
                storage[k] = storage_parameters[1, k]
            catch e
                if k == "enabled"
                    println(
                        "The " * k * " parameter is not defined. Will default to false."
                    )
                else
                    println(
                        "The " 
                        * k 
                        * " parameter is not defined. Will default to nothing."
                    )
                end
            end
        end
    catch e
        println(
            "Storage parameters not found in " 
            * filepath 
            * ". Storage parameters will default to not allowing storage to be "
            * "considered."
        )
    end

    # Check the provided efficiencies
    for k in ("charge_eff", "discharge_eff")
        if storage[k] > 1.0
            @error(
                "The provided " 
                * k 
                * " parameter is greater than 1. Please only use values between 0 and "
                * "1, inclusive."
            )
            throw(ErrorException("See above."))
        elseif storage[k] < 0.0
            @error(
                "The provided " 
                * k 
                * " parameter is less than 0. Please only use values between 0 and 1, "
                * "inclusive."
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
