"""
    read_demand(filepath::String)::Demand

Load demand profiles and parameters for both fixed and variable demand from .csv files 
and return them in a Demand struct.
"""
function read_demand(filepath::String)::Demand
    # Initialize demand struct
    demand = Dict{String,Any}(
        "simple_shift_enabled" => false,
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
            if !ismissing(demand_parameters[1, k])
                demand[k] = demand_parameters[1, k]
            else
                println(
                    "The " *
                    k *
                    " parameter is not defined. Will default to " *
                    string(demand[k]) *
                    ".",
                )
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
    if demand["simple_shift_enabled"]
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
            demand["simple_shift_enabled"] = false
        end
    end

    # Convert Dict to NamedTuple
    demand = (; (Symbol(k) => v for (k, v) in demand)...)

    # Convert NamedTuple to Demand object
    demand = Demand(; demand...)

    return demand
end
