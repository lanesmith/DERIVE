"""
    define_solar_investment_tax_credit!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        scenario::Scenario,
        solar::Solar,
    )

Adds a "revenue" to the objective function to account for the solar investment tax credit. 
This "revenue" is determined by multiplying the solar investment tax credit percentage by 
the amortized capital cost of the solar photovoltaic (PV) system.
"""
function define_solar_investment_tax_credit!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    scenario::Scenario,
    solar::Solar,
)
    # Reduce the capital cost of the solar PV system by the specified investment tax credit
    if isnothing(scenario.real_discount_rate)
        if isnothing(scenario.nominal_discount_rate) | isnothing(scenario.inflation_rate)
            # Use a simple amortization if the necessary information is not provided
            JuMP.add_to_expression!(
                obj,
                -1 * solar.investment_tax_credit * solar.capital_cost * m[:pv_capacity] /
                solar.lifespan,
            )
        else
            # Calculate the real discount rate using the nominal discount rate and 
            # inflation rate
            real_discount_rate =
                (scenario.nominal_discount_rate - scenario.inflation_rate) /
                (1 + scenario.inflation_rate)

            # Use the calculated real discount rate
            JuMP.add_to_expression!(
                obj,
                -1 * (real_discount_rate * (1 + real_discount_rate)^solar.lifespan) /
                ((1 + real_discount_rate)^solar.lifespan - 1) *
                solar.investment_tax_credit *
                solar.capital_cost *
                m[:pv_capacity],
            )
        end
    else
        # Use the user-defined real discount rate
        JuMP.add_to_expression!(
            obj,
            -1 * (
                scenario.real_discount_rate *
                (1 + scenario.real_discount_rate)^solar.lifespan
            ) / ((1 + scenario.real_discount_rate)^solar.lifespan - 1) *
            solar.investment_tax_credit *
            solar.capital_cost *
            m[:pv_capacity],
        )
    end
end

"""
    define_storage_investment_tax_credit!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        scenario::Scenario,
        storage::Storage,
    )

Adds a "revenue" to the objective function to account for the storage investment tax 
credit. This "revenue" is determined by multiplying the storage investment tax credit 
percentage by the amortized capital cost of the battery energy storage system.
"""
function define_storage_investment_tax_credit!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    scenario::Scenario,
    storage::Storage,
)
    # Reduce the capital cost of the battery energy storage system by the specified 
    # investment tax credit
    if isnothing(scenario.real_discount_rate)
        if isnothing(scenario.nominal_discount_rate) | isnothing(scenario.inflation_rate)
            # Use a simple amortization if the necessary information is not provided
            JuMP.add_to_expression!(
                obj,
                -1 *
                storage.investment_tax_credit *
                storage.power_capital_cost *
                m[:bes_power_capacity] / storage.lifespan,
            )
        else
            # Calculate the real discount rate using the nominal discount rate and 
            # inflation rate
            real_discount_rate =
                (scenario.nominal_discount_rate - scenario.inflation_rate) /
                (1 + scenario.inflation_rate)

            # Use the calculated real discount rate
            JuMP.add_to_expression!(
                obj,
                -1 * (real_discount_rate * (1 + real_discount_rate)^storage.lifespan) /
                ((1 + real_discount_rate)^storage.lifespan - 1) *
                storage.investment_tax_credit *
                storage.power_capital_cost *
                m[:bes_power_capacity],
            )
        end
    else
        # Use the user-defined real discount rate
        JuMP.add_to_expression!(
            obj,
            -1 * (
                scenario.real_discount_rate *
                (1 + scenario.real_discount_rate)^storage.lifespan
            ) / ((1 + scenario.real_discount_rate)^storage.lifespan - 1) *
            storage.investment_tax_credit *
            storage.power_capital_cost *
            m[:bes_power_capacity],
        )
    end
end
