"""
    calculate_total_irradiance_profile(scenario, solar)

Calculates the irradiance as observed by the simulated solar photovoltaic (PV) system. 
Irradiance is based on weather data and the position of the PV array. Equations are 
obtained from 'Renewable and Efficient Electric Power Systems, 2nd Edition' by Gilbert M. 
Masters.
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
        ϕ_s[i] = asind((cosd(δ) .* sind(hour_angle[i])) / cosd(β[i]))

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
        # latitude (Northern Hemisphere) and PV tilt angle; source: Jacobson et al., "World 
        # estimates of PV optimal tilt angles and ratios of sunlight incident upon tilted 
        # and tracked PV panels relative to horizontal panels," Solar Energy, 2018.
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


"""
function calculate_solar_generation_profile(scenario::Scenario, solar::Solar)
    
end

"""
    create_solar_capacity_factor_profile(scenario, solar)


"""
function create_solar_capacity_factor_profile(scenario::Scenario, solar::Solar)::Solar
    
end
