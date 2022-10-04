"""
    read_storage(filepath::String)::Storage

Load battery energy storage (BES) parameters from .csv files and return them in a 
Storage struct.
"""
function read_storage(filepath::String)::Storage
    # Initialize storage struct
    storage = Dict{String,Any}(
        "enabled" => false,
        "power_capacity" => nothing,
        "energy_capacity" => nothing,
        "soc_min" => 0.0,
        "soc_max" => 1.0,
        "charge_eff" => nothing,
        "discharge_eff" => nothing,
        "loss rate" => nothing,
        "nonexport" => true,
        "nonimport" => false,
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
            if !ismissing(storage_parameters[1, k])
                storage[k] = storage_parameters[1, k]
            else
                println(
                    "The " *
                    k *
                    " parameter is not defined. Will default to " *
                    string(storage[k]) *
                    ".",
                )
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
    for k in ["soc_min", "soc_max", "charge_eff", "discharge_eff"]
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
