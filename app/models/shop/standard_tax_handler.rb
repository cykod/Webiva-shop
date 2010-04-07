

class Shop::StandardTaxHandler

  def initialize(region)
    @region = region
  end

  def calculate_tax(cart,address)
    # Tax rate is in %
    calculate_tax_rate(address) * calculate_taxable_amount(cart) / 100.0
  end

  def calculate_tax_rate(address)
    tax = @region.tax
    if @region.has_subregions?
      @subregion = @region.subregions.find_by_abr(address[:state])
      if @subregion && !@subregion.tax.nil?
        tax = @subregion.tax
      end
    end
    tax
  end

  def calculate_taxable_amount(cart)
    taxable_amount = cart.taxable_total

    tax_on = @region.tax_calc
    if @subregion && @subregion.tax_calc != 'inherit'
      tax_on = @subregion.tax_calc
    end

    if tax_on == 'shipping'
      taxable_amount += cart.shipping
    end

    taxable_amount
  end
end
