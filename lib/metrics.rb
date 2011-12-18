require 'metrics/version'
require 'metrics/railtie' if defined?(Rails)

module Metrics
  
  class << self
    attr_accessor :config

    def init(host, port, db, config = {})
      self.config = config

      AARRR.connection = Mongo::Connection.new host, port
      AARRR::Config.cookie_expiration = 3600*24*999
      AARRR::Config.database_name = db

      puts "Metrics initialized: #{host}:#{port}@#{db} [#{config}]" if config[:log_delays]

      # Patch AARRR
      patch = <<-PATCH
      module ::AARRR
        class Session
          def set_data(data)
            update({"data" => data})
          end
        end
      end
      PATCH

      eval patch
    end
  end

end