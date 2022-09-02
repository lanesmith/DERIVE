"""
    calculate_total_irradiance_profile(scenario, solar)

Calculates the irradiance as observed by the simulated solar photovoltaic (PV) system. 
Irradiance is based on weather data and the position of the PV array. Equations are 
obtained from 'Renewable and Efficient Electric Power Systems, 2nd Edition' by Masters.
"""
function calculate_total_irradiance_profile(scenario::Scenario, solar::Solar)
    # Create array of day numbers that correspond with each time stamp
    n = dayofyear.(scenario.weather_data[:, "timestamp"])

    # Calculate the solar declination angle
    δ = 23.45 .* sind.((360 / 365) .* (n .- 81))

    # Define local time meridians according to U.S. time zone
    ltm = Dict(
        "Eastern" => 75,
        "Central" => 90,
        "Mountain" => 105,
        "Pacific" => 120,
        "Alaskan" => 135,
        "Hawaiian" => 150,
    )

    # Create array of minutes that correspond with each time stamp for each day
    t = hour.(scenario.weather_data[:, "timestamp"]) .* 60

    # Convert clock time to solar time
    b = (360 / 364) .* (n .- 81)
    equation_of_time = 9.87 .* sind.(2 .* b) .- 7.53 .* cosd.(b) .- 1.5 .* sind.(b)
    solar_time =
        (
            t .+ 4 .* (ltm[titlecase(scenario.timezone)] - scenario.longitude) .+
            equation_of_time
        ) ./ 60

    # Calculate the hour angle
    hour_angle = 15 .* (12 .- solar_time)

    # Calculate the altitude angle of the Sun
    β =
        asind.(
            cosd(scenario.latitude) .* cosd.(δ) .* cosd.(hour_angle) .+
            sind(scenario.latitude) .* sind.(δ),
        )

    # Calculate the azimuth angle of the Sun
    ϕ_s = zeros(length(β))
    for i = 1:length(ϕ_s)
        ϕ_s[i] = asind((cosd(δ[i]) .* sind(hour_angle[i])) / cosd(β[i]))

        # Account for the ambiguity of arcsin: test if azimuth is greater or less than 90
        if cosd(hour_angle[i]) < (tand(δ[i]) / tand(scenario.latitude))
            ϕ_s[i] = 180 - ϕ_s[i]
        end
    end

    # Set the collector azimuth angle
    if solar.collector_azimuth == nothing
        # Defaults to due south, which is optimal assuming no complicating constraints
        ϕ_c = 0
    else
        ϕ_c = solar.collector_azimuth
    end

    # Set the tilt angle of the panels
    if solar.tilt_angle == nothing
        # Use third-order polynomial fit from fixed-tilt PVWatts simulations that relates 
        # latitude (Northern Hemisphere) and PV tilt angle; source: Jacobson et al., 'World 
        # estimates of PV optimal tilt angles and ratios of sunlight incident upon tilted 
        # and tracked PV panels relative to horizontal panels,' Solar Energy, 2018.
        Σ =
            1.3793 +
            scenario.latitude *
            (1.2011 + scenario.latitude * (-0.014404 + scenario.latitude * 0.000080509))
    else
        Σ = solar.tilt_angle
    end

    # Calculate the cosine of the incidence angle
    if solar.tracker == "fixed"
        cosθ = cosd.(β) .* cosd.(ϕ_s .- ϕ_c) .* sind(Σ) .+ sind.(β) .* cosd(Σ)
    elseif solar.tracker == "two-axis"
        cosθ = 1
    elseif solar.tracker == "one-axis, horizontal, north-south"
        cosθ = sqrt.(1 .- (cosd.(β) .* cosd.(ϕ_s)) .^ 2)
    elseif solar.tracker == "one-axis, horizontal, east-west"
        cosθ = sqrt.(1 .- (cosd.(β) .* sind.(ϕ_s)) .^ 2)
    elseif solar.tracker == "one-axis, polar-mount, north-south"
        cosθ = cosd.(δ)
    elseif solar.tracker == "one-axis, vertical-mount"
        cosθ = sind.(β .+ Σ)
    end

    # Correct for infeasible incidence angles
    replace!(x -> acosd(x) > 90 ? 0 : x, cosθ)

    # Calculate the beam insolation on the collector
    beam_insolation = scenario.weather_data[:, "DNI"] .* cosθ

    # Calculate the diffuse insolation on the collector
    if solar.tracker == "fixed"
        diffuse_insoltation = scenario.weather_data[:, "DHI"] .* ((1 + cosd(Σ)) / 2)
    elseif solar.tracker == "two-axis"
        diffuse_insoltation = scenario.weather_data[:, "DHI"] .* ((1 .+ sind.(β)) ./ 2)
    elseif solar.tracker == "one-axis, horizontal, north-south"
        diffuse_insoltation =
            scenario.weather_data[:, "DHI"] .* ((1 .+ (sind.(β) ./ cosθ)) ./ 2)
    elseif solar.tracker == "one-axis, horizontal, east-west"
        diffuse_insoltation =
            scenario.weather_data[:, "DHI"] .* ((1 .+ (sind.(β) ./ cosθ)) ./ 2)
    elseif solar.tracker == "one-axis, polar-mount, north-south"
        diffuse_insoltation = scenario.weather_data[:, "DHI"] .* ((1 .+ sind.(β .- δ)) ./ 2)
    elseif solar.tracker == "one-axis, vertical-mount"
        diffuse_insoltation = scenario.weather_data[:, "DHI"] .* ((1 + cosd(Σ)) / 2)
    end

    # Define the ground reflectance coefficient
    ρ = Dict("default" => 0.2, "fresh snow" => 0.8, "bituminous-and-gravel roof" => 0.1)

    # Calculate the reflected insolation on the collector
    if solar.tracker == "fixed"
        reflected_insolation =
            scenario.weather_data[:, "GHI"] .* ρ[lowercase(solar.ground_reflectance)] .*
            ((1 - cosd(Σ)) / 2)
    elseif solar.tracker == "two-axis"
        reflected_insolation =
            scenario.weather_data[:, "GHI"] .* ρ[lowercase(solar.ground_reflectance)] .*
            ((1 .- sind.(β)) ./ 2)
    elseif solar.tracker == "one-axis, horizontal, north-south"
        reflected_insolation =
            scenario.weather_data[:, "GHI"] .* ρ[lowercase(solar.ground_reflectance)] .*
            ((1 .- (sind.(β) ./ cosθ)) ./ 2)
    elseif solar.tracker == "one-axis, horizontal, east-west"
        reflected_insolation =
            scenario.weather_data[:, "GHI"] .* ρ[lowercase(solar.ground_reflectance)] .*
            ((1 .- (sind.(β) ./ cosθ)) ./ 2)
    elseif solar.tracker == "one-axis, polar-mount, north-south"
        reflected_insolation =
            scenario.weather_data[:, "GHI"] .* ρ[lowercase(solar.ground_reflectance)] .*
            ((1 .+ sind.(β .- δ)) ./ 2)
    elseif solar.tracker == "one-axis, vertical-mount"
        reflected_insolation =
            scenario.weather_data[:, "GHI"] .* ρ[lowercase(solar.ground_reflectance)] .*
            ((1 - cosd(Σ)) / 2)
    end

    # Return the total irradiance on the collector
    return beam_insolation .+ diffuse_insoltation .+ reflected_insolation
end

"""
    calculate_solar_generation_profile(scenario, solar)

Calculate the power generation profile for the specified PV system using the specified 
weather data and a supported solution method. The power generation profile is intended to 
be used in the determination of the capacity factor profile.
"""
function calculate_solar_generation_profile(
    scenario::Scenario,
    solar::Solar,
    irradiance::Vector,
)
    # Initialize a dictionary to hold the constants needed for calculating the I-V curve
    constants = Dict{String,Any}()

    # Define necessary scientific constants
    constants["boltzmanns"] = 1.380649e-23
    constants["electron_charge"] = 1.602176634e-19

    # Define band gaps and fitting parameters for different semiconductor materials. Data 
    # from 'Principles of Semiconductor Devices' by Van Zeghbroeck
    semiconductor_parameters = Dict(
        "Silicon" =>
            Dict("band_gap_0" => 1.166, "α_param" => 4.73e-4, "β_param" => 636),
        "Germanium" =>
            Dict("band_gap_0" => 0.7437, "α_param" => 4.77e-4, "β_param" => 235),
        "Gallium Aresenide" =>
            Dict("band_gap_0" => 1.519, "α_param" => 5.41e-4, "β_param" => 204),
    )
    constants["band_gap_data"] =
        semiconductor_parameters[titlecase(solar.module_cell_material)]

    # Define values associated with standard test conditions (STC)
    constants["nom_temp"] = 298.15
    constants["nom_irr"] = 1000

    # Calculate cell temperature and convert from Celsius to Kelvin
    temperature =
        scenario.weather_data[:, "Temperature"] .+
        ((solar.module_noct - 20) / 800) .* irradiance .+ 273.15

    # Calculate the PV module's power profile
    _, _, power_profile =
        desoto_iv_curve_method(scenario, solar, irradiance, temperature, constants)

    # Return the power generation profile
    return power_profile
end

"""
    desoto_iv_curve_method(
        scenario, solar, irradiance, temperature, constants, num_iv_points
    )

Solve for the PV system's I-V curve, and subsequently the power generation profile, using 
the method outlined in De Soto et al., 'Improvement and validation of a model for 
photovoltaic array performance,' Solar Energy, 2006. Parameter estimates are determined 
using the method outlined in 'Power Electronics and Control Techniques for Maximum Energy 
Harvesting in Photovoltaic Systems' by Femia et al. Supporting equations are used from 
Villalva et al., 'Comprehensive Approach to Modeling and Simulation of Photovoltaic 
Arrays,' IEEE Transactions on Power Electronics, 2009.
"""
function desoto_iv_curve_method(
    scenario::Scenario,
    solar::Solar,
    irradiance::Vector,
    temperature::Vector,
    constants::Dict,
    num_iv_points::Int64=1000,
)
    # Calculate the photo-induced current
    nom_ipv = solar.module_sc_current
    ipv =
        nom_ipv .* (irradiance ./ constants["nom_irr"]) .*
        (1 .+ solar.module_current_temp_coeff .* (temperature .- constants["nom_temp"]))

    # Calculate the thermal voltage, which also considers the number of cells in series
    nom_vt =
        (solar.module_number_of_cells * constants["boltzmanns"] * constants["nom_temp"]) /
        constants["electron_charge"]
    vt =
        (solar.module_number_of_cells .* constants["boltzmanns"] .* temperature) ./
        constants["electron_charge"]

    # Determine the band gap energy using Varshni's empirical expression
    nom_eg =
        (
            constants["band_gap_data"]["band_gap_0"] - (
                (constants["band_gap_data"]["α_param"] * constants["nom_temp"]^2) /
                (constants["nom_temp"] + constants["band_gap_data"]["β_param"])
            )
        ) * constants["electron_charge"]
    eg =
        (
            constants["band_gap_data"]["band_gap_0"] .- (
                (constants["band_gap_data"]["α_param"] .* temperature .^ 2) ./
                (temperature .+ constants["band_gap_data"]["β_param"])
            )
        ) .* constants["electron_charge"]

    # Determine the diode ideality constant
    a =
        (
            solar.module_voltage_temp_coeff -
            (solar.module_oc_voltage / constants["nom_temp"])
        ) / (
            nom_vt * (
                (solar.module_current_temp_coeff / nom_ipv) - (3 / constants["nom_temp"]) -
                (nom_eg / (constants["boltzmanns"] * constants["nom_temp"]^2))
            )
        )

    # Calculate the saturation current
    nom_i0 = nom_ipv / (exp(solar.module_oc_voltage / (a * nom_vt)) - 1)
    i0 =
        nom_i0 .* (temperature ./ constants["nom_temp"]) .^ 3 .*
        exp.(
            ((nom_eg / constants["nom_temp"]) .- (eg ./ temperature)) ./
            constants["boltzmanns"],
        )

    # Create a change of variable to solve for the series and shunt resistances explicitly
    x =
        lambertw(
            solar.module_rated_voltage *
            (2 * solar.module_rated_current - nom_ipv - nom_i0) *
            exp(
                solar.module_rated_voltage *
                ((solar.module_rated_voltage - 2 * a * nom_vt) / (a^2 * nom_vt^2)),
            ) / (a * nom_i0 * nom_vt),
        ) + (2 * (solar.module_rated_voltage / (a * nom_vt))) -
        (solar.module_rated_voltage^2 / (a^2 * nom_vt^2))

    # Calculate the sreies and shunt resistances
    rs = (x * a * nom_vt - solar.module_rated_voltage) / solar.module_rated_current
    nom_rp =
        (x * a * nom_vt) / (nom_ipv - solar.module_rated_current - nom_i0 * (exp(x) - 1))
    rp = nom_rp .* (constants["nom_irr"] ./ irradiance)

    # Create I-V curves
    v = zeros(length(temperature), num_iv_points)
    θ = zeros(size(v))
    i = zeros(size(v))
    for j = 1:size(v)[1]
        # Initialize the voltage; account for the dependence of Voc on temperature
        voc =
            solar.module_oc_voltage +
            solar.module_voltage_temp_coeff * (temperature[j] - constants["nom_temp"])
        v[j, :] = collect(0:(voc / (num_iv_points - 1)):voc)

        # Create a change of variable to solve for the output current explicitly
        if (rp[j] == Inf) & (ipv[j] == 0)
            # Take the limit of θ[j, :] as rp[j] -> Inf
            θ[j, :] =
                ((rs .* i0[j]) ./ (a .* vt[j])) .*
                exp.((rs .* i0[j] .+ v[j, :]) ./ (a .* vt[j]))
        else
            θ[j, :] =
                (
                    rs .* rp[j] .* i0[j] .*
                    exp.(
                        (rp[j] .* (rs .* (ipv[j] + i0[j]) .+ v[j, :])) ./
                        (a * vt[j] * (rs + rp[j])),
                    )
                ) ./ ((rs + rp[j]) * a * vt[j])
        end

        # Calculate the output current
        if (rp[j] == Inf) & (ipv[j] == 0)
            # Take the limit of i[j, :] as rp[j] -> Inf
            i[j, :] = i0[j] .- ((a .* vt[j] .* lambertw.(θ[j, :])) ./ rs)
        else
            i[j, :] =
                ((rp[j] .* (ipv[j] + i0[j]) .- v[j, :]) ./ (rs + rp[j])) .-
                ((a .* vt[j] .* lambertw.(θ[j, :])) ./ rs)
        end
    end

    # Calculate the power (i.e., enable the creation of the P-V curves)
    p = i .* v

    # Return the current, voltage, and power values for each I-V curve at each time step
    return i, v, p
end

"""
    create_solar_capacity_factor_profile(scenario, solar, power_profile)

Determine the capacity factor profile of the specified PV system with the given weather 
data. The capacity factor profile is determined by taking the power generation profile for 
a single PV module and normalizing it by the rated capacity of the PV module.
"""
function create_solar_capacity_factor_profile(scenario::Scenario, solar::Solar)::Solar
    # Initialize the updated Solar struct object
    solar_ = Dict(string(i) => getfield(solar, i) for i in fieldnames(Solar))
    println("...preparing solar profiles")

    # Determine the total irradiance profile
    irradiance = calculate_total_irradiance_profile(scenario, solar)

    # Determine the solar generation profile
    power_profile = calculate_solar_generation_profile(scenario, solar, irradiance)

    # Calculate the capacity factor profile
    solar_["capacity_factor_profile"] = DataFrames.DataFrame(
        "timestamp" => collect(
            Dates.DateTime(scenario.year, 1, 1, 0):Dates.Hour(1):Dates.DateTime(
                scenario.year,
                12,
                31,
                23,
            ),
        ),
        "capacity_factor" =>
            vec(maximum(power_profile, dims=2) ./ solar.module_nominal_power),
    )

    # Convert Dict to NamedTuple
    solar_ = (; (Symbol(k) => v for (k, v) in solar_)...)

    # Convert NamedTuple to Solar object
    solar_ = Solar(; solar_...)

    return solar_
end

"""
    lambertw(z, tol)

Solve the principal branch of the Lambert W function using Halley's method. Assume that 
the input, z, is real and sufficiently greater than the branch point of -1/e. Equations 
are obtained from Corless et. al, 'On the Lambert W Function,' Advances in Computational 
Mathematics, 1996.
"""
function lambertw(z::Union{Float64,Int64}, tol::Float64=1e-6)
    # Check that the input, z, is sufficiently greater than the branch point
    if z < -1 / exp(1)
        throw(
            ErrorException(
                "The input value to the Lambert W function is less than the branch " *
                "point for the principal branch. Other branches of the Lambert W " *
                "function are not supported by this solver. Please try again.",
            ),
        )
    end

    # Check if the input equals infinity and return infinity according to the limit
    if z == Inf
        return Inf
    end

    # Provide an initial guess of the error
    if z > 2.5
        w_ = log(z) - log(log(z))
    elseif z <= -0.3
        # Used as z -> -1 / exp(1), which is the branch point
        w_ = -1 + sqrt(2 * (exp(1) * z + 1))
    else
        # Used for z near 0, derived from a (3, 2)-Pade approximation for W_0(z) around 0
        w_ = (60 * z + 114 * z^2 + 17 * z^3) / (60 + 174 * z + 101 * z^2)
    end

    # Perform Halley's method
    for i = 1:1000
        w =
            w_ - (
                (w_ - z * exp(-w_)) /
                (w_ + 1 - (((w_ + 2) * (w_ - z * exp(-w_))) / (2 * w_ + 2)))
            )
        if abs(w - w_) < tol
            # Return the solution to the Lambert W function
            return w
        end
        w_ = w
    end

    # Throw error because the algorithm did not converge
    throw(
        ErrorException(
            "For the value input to the Lambert W function, Halley's method did not " *
            "converge in a sufficient number of steps. Please try again.",
        ),
    )
end
