# -*- encoding: utf-8 -*-

module ActiveMerchant
  module Shipping
    class UPSLTL < UPS
      require 'nokogiri'

      TEST_URL = 'https://wwwcie.ups.com'
      LIVE_URL = 'https://onlinetools.ups.com'
      WSDL_DIR = 'lib/active_shipping/shipping/carriers/support/ups/wsdl/'

      WSDL_RESOURCES = {
          :rates => 'FreightRate.wsdl'
      }
      RESOURCES = {
          :rates => 'webservices/FreightRate'
      }
      DEFAULT_SERVICES = {
          "LTL Ground" => 308,
      }

      REFERENCE_NUMBERS = {
          :purchase_order => 28,
          :bill_of_lading => 57
      }


      def find_rates(origin, destination, packages, payer, options = {})
        origin, destination = upsified_location(origin), upsified_location(destination)
        options = @options.merge(options)
        packages = Array(packages)
        rate_request = build_rate_request(origin, destination, packages, payer, options)
        response = commit(:rates, save_request(rate_request), (options[:test] || false))
        @origin = origin
        @desination = destination
        @packages = packages
        @payer = payer
        @options = options
        #parse_rate_response(origin, destination, packages, response, options)
        parse(response)
      end

      protected

      def response_message(xml)
        xml.at('Response > ResponseStatus > Description').text
      end

      def parse(xml)
        response_options = {}
        response_options[:xml] = xml
        response_options[:request] = last_request
        response_options[:test] = test_mode?

        document = Nokogiri::XML(xml)
        document.remove_namespaces!
        child_element = document.css('Body > *').first
        parse_method = 'parse_' + child_element.name.underscore
        if respond_to?(parse_method, true)
          send(parse_method, child_element, response_options)
        else
          Response.new(false, "Unknown response object #{child_element.name}", response_options)
        end
      end

      def parse_success_response?(xml)
        xml.at('Response > ResponseStatus > Code').text == '1'
      end
      alias_method :response_success?, :parse_success_response?

      def parse_fault_response(xml,options)
        if respond_to?(Rails.logger.debug,true)
          Rails.logger.debug(xml.to_s)
        else
          puts xml.to_s
        end
      end
      def parse_freight_rate_response(xml, options)
        success = parse_success_response?(xml)
        message = response_message(xml)

        if success
          rate_estimates = []
          total_charge = xml.at('TotalShipmentCharge > MonetaryValue').text
          service_description = "LTL Ground"
          service_code = 308
          rate_estimates << RateEstimate.new(@origin, @destination, @@name,
                                             service_name_for(@origin, service_code),
                                             :total_price => total_charge.to_f,
                                             :currency => xml.at('TotalShipmentCharge > CurrencyCode').text,
                                             :service_code => service_code,
                                             :packages => @packages)
        end
        RateResponse.new(success, message, Hash.from_xml(xml.to_xml).values.first, :rates => rate_estimates, :xml => xml, :request => options[:request])
      end
      def parse_rate_response(origin, destination, packages, response, options = {})
        rates = []
        xml = Nokogiri::XML(response)
        success = response_success?(xml)
        message = response_message(xml)

        if success
          rate_estimates = []

          xml.elements.each('/*/TotalShipmentCharge') do |rated_shipment|
            service_code = rated_shipment.get_text('Service/Code').to_s.to_i
            #days_to_delivery = nil if days_to_delivery == 0
            rate_estimates << RateEstimate.new(origin, destination, @@name,
                                               service_name_for(origin, service_code),
                                               :total_price => rated_shipment.get_text('TotalShipmentCharge/MonetaryValue').to_s.to_f,

                                               :currency => rated_shipment.get_text('TotalCharges/CurrencyCode').to_s,
                                               :service_code => service_code,
                                               :packages => packages,
                                               #:negotiated_rate =>                              rated_shipment.get_text('NegotiatedRates/NetSummaryCharges/GrandTotal/MonetaryValue').to_s.to_f
            )
          end
        end
        RateResponse.new(success, message, Hash.from_xml(response).values.first, :rates => rate_estimates, :xml => response, :request => last_request)
      end

      def commit(action, request, test = false)
        ssl_post("#{test ? TEST_URL : LIVE_URL}/#{RESOURCES[action]}", request, 'Content-Type' => 'text/xml')#, 'SOAPAction' => "http://www.ups.com/XMLSchema/XOLTWS/UPSS/v1.0#UPSSecurity")
      end

      def build_header
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.soap(:Envelope,
                 'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
                 'xmlns:req'=>"http://www.ups.com/XMLSchema/XOLTWS/Common/v1.0",
                 'xmlns:frt'=>"http://www.ups.com/XMLSchema/XOLTWS/FreightRate/v1.0",
                 'xmlns:upss'=>"http://www.ups.com/XMLSchema/XOLTWS/UPSS/v1.0"
        ) do
          xml.soap :Header do
            xml << build_access_request
          end

          xml.soap :Body do
            yield(xml)
          end
        end
      end

      def build_access_request
        xml = Builder::XmlMarkup.new
#        xml.instruct!
        xml.upss :UPSSecurity do
          xml.upss :UsernameToken do
            xml.upss :Username, @options[:login]
            xml.upss :Password, @options[:password]
          end
          xml.upss :ServiceAccessToken do
            xml.upss :AccessLicenseNumber, @options[:key]
          end
        end
        xml
      end

      def build_payment_node(xml, node, payer, options = {})
        xml.frt node.to_sym do
          xml.frt :Payer do
            xml.frt :Name, payer.company_name
            xml.frt :Address do
              xml.frt :AddressLine, payer.address1
              if payer.address2.present?
                xml.frt :AddressLine, payer.address2
              end
              if payer.address3.present?
                xml.frt :AddressLine, payer.address3
              end
              xml.frt :City, payer.city
              xml.frt :StateProvinceCode, payer.state
              xml.frt :PostalCode, payer.postal_code
              xml.frt :CountryCode, payer.country_code
            end
            if options[:shipper_number]
              xml.frt :ShipperNumber, options[:shipper_number]
            end
          end
          xml.frt :ShipmentBillingOption do
            xml.frt :Code, 10
          end
        end
      end

      def build_service_node(xml, node, options={})
        xml.frt node.to_sym do
          xml.frt :Code,DEFAULT_SERVICES["LTL Ground"]
          xml.frt :Description,"LTL Ground"
        end
      end

      def build_quantity_node(xml, node, packages, options={})
        xml.frt node.to_sym do
          xml.frt :Quantity, packages.map{|s| s.quantity}.reduce(0,:+)
          xml.frt :Type do
            xml.frt :Code, 'PLT'
            xml.frt :Description, 'Pallet'
          end
        end
      end



      def build_weight_node(xml, node, package, options)
        xml.frt node.to_sym do
          xml.frt :Value, options[:imperial] ? package.pounds.round(0) : package.kgs
          xml.frt :UnitOfMeasurement do
            xml.frt :Code, options[:imperial] ? 'LBS' : 'KGS'
          end
        end
      end

      def build_number_pieces_node(xml, node, package, options={})
        xml.frt node.to_sym, package.quantity
      end

      def build_packaging_type_node(xml, node, options={})
        xml.frt node.to_sym do
          xml.frt :Code, "PLT"
        end
      end

      def build_commodity_value_node(xml, node,options={})
        xml.frt node.to_sym do
          xml.frt :CurrencyCode, "US"
          xml.frt :MonetaryValue, options[:total_value].nil? ? "500" : options[:total_value]
        end
      end

      def build_dimensions_node(xml, node,package,options={})
        xml.frt node.to_sym do
          xml.frt :UnitOfMeasurement do
            xml.frt :Code, options[:imperial] ? 'IN' : 'CM'
          end
          [:length, :width, :height].each do |axis|
            value = ((options[:imperial] ? package.inches(axis) : package.cm(axis)).to_f * 1000).round / 1000.0 # 3 decimals
            xml.frt axis.to_sym.capitalize, [value, 0.1].max.round(0)
          end
        end
      end

      def build_freight_class_node(xml, node, options={})
        xml.frt node.to_sym, options[:freight_class]
      end

      def build_nmfc_commodity_node(xml, node, options) #28160 nmfc code shoes
        xml.frt node.to_sym do
          xml.frt :PrimeCode, options[:nmfc_code]
          if options[:nmfc_subcode].present?
            xml.frt :SubCode, options[:nmfc_subcode]
          end
        end
      end

      def build_commodity_node(xml, package, options={})
          xml.frt :Description, "Consumer Goods"
          build_weight_node(xml, 'Weight', package, options)
          build_number_pieces_node(xml, 'NumberOfPieces', package, options)
          build_packaging_type_node(xml, 'PackagingType', options)
          build_commodity_value_node(xml, 'CommodityValue', options)
          build_dimensions_node(xml,'Dimensions', package, options)
          build_freight_class_node(xml, 'FreightClass', options)
          build_nmfc_commodity_node(xml, 'NMFCCommodity', options)
      end

      def build_request_node(xml, options={})
        xml.req :Request do
          xml.req :RequestOption, 1
        end
      end

      def build_rate_request(origin, destination, packages, payer, options = {})
        packages = Array(packages)
        build_header do |xml|
          xml.frt :FreightRateRequest do
            build_request_node(xml,options)
            build_location_node(xml,'ShipFrom', origin, options)
            build_location_node(xml, 'ShipTo', destination, options)
            build_payment_node(xml, 'PaymentInformation', payer, options)
            build_service_node(xml, 'Service', options)
            build_quantity_node(xml, 'HandlingUnitOne', packages, options)
            packages.each do |package|
              xml.frt :Commodity do
                build_commodity_node(xml, package, options)
              end
            end
          end
        end
      end
      def build_location_node(xml, name, location, options = {})
        # not implemented:  * Shipment/Shipper/Name element
        #                   * Shipment/(ShipTo|ShipFrom)/CompanyName element
        #                   * Shipment/(Shipper|ShipTo|ShipFrom)/AttentionName element
        #                   * Shipment/(Shipper|ShipTo|ShipFrom)/TaxIdentificationNumber element
        xml.frt name.to_sym do
          # You must specify the shipper name when creating labels.

          xml.frt :Name, location.company_name unless location.company_name.blank?
          xml.frt :PhoneNumber, location.phone.gsub(/[^\d]/, '') unless location.phone.blank?
          xml.frt :FaxNumber, location.fax.gsub(/[^\d]/, '') unless location.fax.blank?

          if name == 'Shipper' and (origin_account = options[:origin_account] || @options[:origin_account])
            xml.frt :ShipperNumber, origin_account
          elsif name == 'ShipTo' and (destination_account = options[:destination_account] || @options[:destination_account])
            xml.frt :ShipperAssignedIdentificationNumber, destination_account
          end

          if phone = location.phone
            xml.frt :PhoneNumber, phone
          end

          if attn = location.name
            xml.frt :AttentionName, attn
          end

          xml.frt :Address do
            xml.frt :AddressLine, location.address1 unless location.address1.blank?
            xml.frt :AddressLine2, location.address2 unless location.address2.blank?
            xml.frt :AddressLine3, location.address3 unless location.address3.blank?
            xml.frt :City, location.city unless location.city.blank?
            xml.frt :StateProvinceCode, location.province unless location.province.blank?
            # StateProvinceCode required for negotiated rates but not otherwise, for some reason
            xml.frt :PostalCode, location.postal_code unless location.postal_code.blank?
            xml.frt :CountryCode, location.country_code(:alpha2) unless location.country_code(:alpha2).blank?
            #xml.frt :ResidentialAddressIndicator, true) unless location.commercial? # the default should be that UPS returns residential rates for destinations that it doesn't know about
            # not implemented: Shipment/(Shipper|ShipTo|ShipFrom)/Address/ResidentialAddressIndicator element
          end
        end
      end
    end
  end
end
