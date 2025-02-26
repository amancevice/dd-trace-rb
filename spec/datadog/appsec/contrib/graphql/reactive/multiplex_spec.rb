# frozen_literal_string: true

require 'datadog/tracing/contrib/graphql/test_helpers'
require 'datadog/tracing/contrib/graphql/support/application'

require 'datadog/appsec/spec_helper'
require 'datadog/appsec/contrib/graphql/gateway/multiplex'
require 'datadog/appsec/contrib/graphql/reactive/multiplex'
require 'datadog/appsec/reactive/engine'
require 'datadog/appsec/reactive/shared_examples'

RSpec.describe Datadog::AppSec::Contrib::GraphQL::Reactive::Multiplex do
  include_context 'with GraphQL multiplex'

  let(:engine) { Datadog::AppSec::Reactive::Engine.new }
  let(:expected_arguments) do
    {
      'user' => [{ 'id' => 1 }, { 'id' => 10 }],
      'userByName' => [{ 'name' => 'Caniche' }]
    }
  end

  describe '.publish' do
    it 'propagates multiplex attributes to the engine' do
      expect(engine).to receive(:publish).with('graphql.server.all_resolvers', expected_arguments)
      gateway_multiplex = Datadog::AppSec::Contrib::GraphQL::Gateway::Multiplex.new(multiplex)
      described_class.publish(engine, gateway_multiplex)
    end
  end

  describe '.subscribe' do
    let(:appsec_context) { instance_double(Datadog::AppSec::Context) }

    context 'not all addresses have been published' do
      it 'does not call the waf context' do
        expect(engine).to receive(:subscribe).with(
          'graphql.server.all_resolvers'
        ).and_call_original
        expect(appsec_context).to_not receive(:run_waf)
        described_class.subscribe(engine, appsec_context)
      end
    end

    context 'all addresses have been published' do
      let(:waf_result) do
        Datadog::AppSec::SecurityEngine::Result::Ok.new(
          events: [], actions: {}, derivatives: {}, timeout: false, duration_ns: 0, duration_ext_ns: 0
        )
      end

      it 'does call the waf context with the right arguments' do
        expect(engine).to receive(:subscribe).and_call_original
        expect(appsec_context).to receive(:run_waf)
          .with({ 'graphql.server.all_resolvers' => expected_arguments }, {}, Datadog.configuration.appsec.waf_timeout)
          .and_return(waf_result)

        described_class.subscribe(engine, appsec_context)
        gateway_multiplex = Datadog::AppSec::Contrib::GraphQL::Gateway::Multiplex.new(multiplex)

        expect(described_class.publish(engine, gateway_multiplex)).to be_nil
      end
    end

    it_behaves_like 'waf result' do
      let(:gateway) { Datadog::AppSec::Contrib::GraphQL::Gateway::Multiplex.new(multiplex) }
    end
  end
end
