"""
    read_solar(filepath::String)::Solar

Load solar photovoltaic (PV) generation profiles and parameters from .csv files and 
return them in a Solar struct.
"""
function read_solar(filepath::String)::Solar
    # Initialize solar struct
    solar = Dict{String,Any}(
        "enabled" => false,
        "capacity_factor_profile" => nothing,
        "power_capacity" => nothing,
        "maximum_system_capacity" => nothing,
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
        "nonexport" => false,
        "capital_cost" => nothing,
        "fixed_om_cost" => nothing,
        "collector_azimuth" => nothing,
        "tilt_angle" => nothing,
        "ground_reflectance" => "default",
        "tracker" => "fixed",
        "inverter_eff" => 1.0,
        "lifespan" => nothing,
        "investment_tax_credit" => 0.3,
    )

    # Try loading the solar parameters
    println("...loading solar parameters")
    try
        solar_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "solar_parameters.csv"); transpose=true),
        )

        # Try assigning the different solar parameters from the file
        for k in intersect(keys(solar), names(solar_parameters))
            if !ismissing(solar_parameters[1, k])
                solar[k] = solar_parameters[1, k]
            else
                println(
                    "The " *
                    k *
                    " parameter is not defined. Will default to " *
                    string(solar[k]) *
                    ".",
                )
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
        if isnothing(solar["capacity_factor_profile"]) & any(
            x -> isnothing(x),
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

    # Check the provided efficiency and investment tax credit parameters
    for k in ["inverter_eff", "investment_tax_credit"]
        if solar[k] > 1.0
            throw(
                ErrorException(
                    "The provided " *
                    k *
                    " parameter is greater than 1. Please only use values between 0 and " *
                    "1, inclusive.",
                ),
            )
        elseif solar[k] < 0.0
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
    solar = (; (Symbol(k) => v for (k, v) in solar)...)

    # Convert NamedTuple to Solar object
    solar = Solar(; solar...)

    return solar
end
