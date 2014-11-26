module ActiveMerchant #:nodoc:
  module Shipping
    # This is UPS specific for now; the hash is not at all generic
    # or common between carriers.

    class LabelResponse < Response
      attr :params # maybe?

      def initialize(success, message, params = {}, options = {})
        @params = params
        super
      end

      def labels
        return @labels if @labels
        packages = params["ShipmentResults"]["PackageResults"]
        packages = [packages] if Hash === packages
        @labels  = packages.map do |package|
          { :tracking_number => package["TrackingNumber"],
            :image           => package["LabelImage"] }
        end
      end
    end

    class LTLLabelResponse < LabelResponse
      def bill_of_lading
        documents("BOL")
      end

      def labels
        documents("LABEL")
      end

      private

      # types
      # BOL - Bill of Lading
      # LABEL - labels
      def documents(type)
        packages = params["ShipmentResults"]["Documents"]
        packages = [packages] if Hash === packages
        thelabels = []
        bill_of_lading = ""
        packages.map do |package|
          package["Image"].each_with_index do |image,index|
            if index == 0
              bill_of_lading = image["GraphicImage"]
              if type == "BOL"
                return bill_of_lading
              end
            else
              thelabels << {:image => image["GraphicImage"] }
            end
          end
        end
        thelabels
      end
    end
  end
end
