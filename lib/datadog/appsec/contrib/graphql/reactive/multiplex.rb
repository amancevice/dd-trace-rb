# frozen_string_literal: true

module Datadog
  module AppSec
    module Contrib
      module GraphQL
        module Reactive
          # Dispatch data from a GraphQL resolve query to the WAF context
          module Multiplex
            ADDRESSES = [
              'graphql.server.all_resolvers'
            ].freeze
            private_constant :ADDRESSES

            def self.publish(engine, gateway_multiplex)
              catch(:block) do
                engine.publish('graphql.server.all_resolvers', gateway_multiplex.arguments)

                nil
              end
            end

            def self.subscribe(engine, context)
              engine.subscribe(*ADDRESSES) do |*values|
                Datadog.logger.debug { "reacted to #{ADDRESSES.inspect}: #{values.inspect}" }
                arguments = values[0]

                persistent_data = {
                  'graphql.server.all_resolvers' => arguments
                }

                waf_timeout = Datadog.configuration.appsec.waf_timeout
                result = context.run_waf(persistent_data, {}, waf_timeout)

                next unless result.match?

                yield result
                throw(:block, true) unless result.actions.empty?
              end
            end
          end
        end
      end
    end
  end
end
