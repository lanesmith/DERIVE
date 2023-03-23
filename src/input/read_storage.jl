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
        "duration" => nothing,
        "maximum_power_capacity" => nothing,
        "maximum_energy_capacity" => nothing,
        "soc_min" => 0.0,
        "soc_max" => 1.0,
        "soc_initial" => 0.5,
        "charge_eff" => 1.0,
        "discharge_eff" => 1.0,
        "loss_rate" => 0.0,
        "nonexport" => true,
        "nonimport" => false,
        "capital_cost" => nothing,
        "lifespan" => nothing,
    )

    # Try loading the storage parameters
    println("...loading storage parameters")
    try
        storage_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "storage_parameters.csv"); transpose=true),
        )

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

    # Check if both the energy_capacity and duration parameters have been provided
    if !isnothing(storage["duration"])
        if !isnothing(storage["energy_capacity"])
            @warn(
                "Both the energy_capacity and duration parameters have been provided. " *
                "Will default to using the energy_capacity parameter."
            )
        else
            # If only duration is provided, set energy_capacity accordingly
            storage["energy_capacity"] = storage["duration"] * storage["power_capacity"]
        end
    end

    # Check the provided state-of-charge and efficiency parameters
    for k in
        ["soc_min", "soc_max", "soc_initial", "charge_eff", "discharge_eff", "loss_rate"]
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
