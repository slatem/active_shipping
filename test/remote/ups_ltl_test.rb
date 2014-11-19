require 'test_helper'

class UPSLTLTest < Test::Unit::TestCase
  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @options   = fixtures(:ups).merge(:test => true)
    @carrier   = UPSLTL.new(@options)
    @payer = Location.new({
        :company_name => "Developer Test 1",
        :address1=>"101 Developer Way",
        :city=>"Richmond",
        :state=>"VA",
        :zip=>"23224",
        :country=>"US"
                          })
  end
  
  def test_find_rates
    assert_nothing_raised do
      response = @carrier.find_rates(Location.new(:address1=>"101 Developer Way",:city => 'Richmond', :country => 'US', :zip => '23224', :state=>"VA", :company_name=>"Developer Test 1"),
                                     Location.new(:address1=>"1000 Consignee Street", :city => 'Allanton', :country => 'US', :zip => '63025', :state=>"MO", :company_name=>"Consignee Test 1"),
                                             Package.new(1500*16, [48, 48, 48], {:units=>:imperial}),
                                             @payer,
                                             {
                                                 :test => true,
                                                 :nmfc_code=>"116030",
                                                 :nmfc_subcode=>"1",
                                                 :freight_class=>"92.5",
                                                 :imperial=>true
                                             }
      )
    end
  end

end