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
        :country=>"US",
        :phone=>3175555555
                          })
  end

  def test_ship
    assert_nothing_raised do
      #email, name, and phone number are required
      response = @carrier.ship(Location.new(:email=>"john@aol.com", :name=>"John Smith",:address1=>"101 Developer Way",:city => 'Richmond', :country => 'US', :zip => '23224', :state=>"VA", :company_name=>"Developer Test 1",:phone=>3175555555),
                                     Location.new(:address1=>"1000 Consignee Street", :city => 'Allanton', :country => 'US', :zip => '63025', :state=>"MO", :company_name=>"Consignee Test 1"),
                                     Package.new(1500*16, [48, 48, 48], {:units=>:imperial}),
                                     @payer,
                                     {
                                         :test => true,
                                         :nmfc_code=>"116030",
                                         :nmfc_subcode=>"1",
                                         :freight_class=>"92.5",
                                         :shipper_number=>@options[:shipper_number],
                                         :imperial=>true,
                                         :pickup_date=>Date.commercial(Date.today.year, 1+Date.today.cweek, 1).to_time.strftime("%Y%m%d"),
                                         :latest_time_ready => "2000",
                                         :earliest_time_ready => "0900"
                                     }
      )
      assert_respond_to(response,'labels', 'Labels Method Does not throw err')
    end

  end
  def test_ship_multiple_pkgs
    assert_nothing_raised do
      #email, name, and phone number are required
      response = @carrier.ship(Location.new(:email=>"john@aol.com", :name=>"John Smith",:address1=>"101 Developer Way",:city => 'Richmond', :country => 'US', :zip => '23224', :state=>"VA", :company_name=>"Developer Test 1",:phone=>3175555555),
                               Location.new(:address1=>"1000 Consignee Street", :city => 'Allanton', :country => 'US', :zip => '63025', :state=>"MO", :company_name=>"Consignee Test 1"),
                               [Package.new(1500*16, [48, 48, 48], {:units=>:imperial}),Package.new(1500*16, [48, 48, 48], {:units=>:imperial})],
                               @payer,
                               {
                                   :test => true,
                                   :nmfc_code=>"116030",
                                   :nmfc_subcode=>"1",
                                   :freight_class=>"92.5",
                                   :shipper_number=>@options[:shipper_number],
                                   :imperial=>true,
                                   :pickup_date=>Date.commercial(Date.today.year, 1+Date.today.cweek, 1).to_time.strftime("%Y%m%d"),
                                   :latest_time_ready => "2000",
                                   :earliest_time_ready => "0900"
                               }
      )
      assert_respond_to(response,'labels', 'Labels Method Does not throw err')
      assert_match "800.82", response.params.to_s, "Response must have correct price - 800.82"
    end
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
  def test_find_rates_mltpl_pkgs
    assert_nothing_raised do
      response = @carrier.find_rates(Location.new(:address1=>"101 Developer Way",:city => 'Richmond', :country => 'US', :zip => '23224', :state=>"VA", :company_name=>"Developer Test 1"),
                                     Location.new(:address1=>"1000 Consignee Street", :city => 'Allanton', :country => 'US', :zip => '63025', :state=>"MO", :company_name=>"Consignee Test 1"),
                                     [Package.new(1500*16, [48, 48, 48], {:units=>:imperial}),Package.new(1500*16, [48, 48, 48], {:units=>:imperial})],
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
  def test_find_rates_residential_pickup
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
                                         :residential_pickup => 1,
                                         :imperial=>true
                                     })
      response_string = response.xml.to_s
      assert_match  "570.74", response_string, "Must include Correct Price - 562.74"
    end
  end
  def test_find_rates_lift_gate_delivery

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
                                         :lift_gate_required_on_delivery => 1,
                                         :imperial=>true
                                     })
      response_string = response.xml.to_s
      assert_match  "575.74", response_string, "Must include Correct Price - 570.74"
    end
  end

end