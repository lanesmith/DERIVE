"""
    read_optimizer_attributes(filepath::String)::Dict{String,Any}

Load optimizer attributes from .csv file.
"""
function read_optimizer_attributes(filepath::String)::Dict{String,Any}
    # Initialize a Dict to hold the specified optimizer attributes
    optimizer_attributes = Dict{String,Any}()

    # Try loading the optimizer attributes
    try
        optimizer_attributes_ = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "optimizer_attributes.csv"); transpose=true),
        )

        # Assign the optimizer attributes to the Dict
        for n in names(optimizer_attributes_)[2:end]
            optimizer_attributes[n] = optimizer_attributes_[1, n]
        end
    catch e
        throw(
            ErrorException(
                "Optimizer attributes not found in " * filepath * ". Please try again.",
            ),
        )
    end

    # Return the specified optimizer attributes
    return optimizer_attributes
end
