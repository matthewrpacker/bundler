# frozen_string_literal: true
require "spec_helper"

describe "gemcutter's dependency API", :realworld => true do
  context "when Gemcutter API takes too long to respond" do
    before do
      require_rack

      port = find_unused_port
      @server_uri = "http://127.0.0.1:#{port}"

      require File.expand_path("../../support/artifice/endpoint_timeout", __FILE__)
      require "thread"
      @t = Thread.new do
        server = Rack::Server.start(:app       => EndpointTimeout,
                                    :Host      => "0.0.0.0",
                                    :Port      => port,
                                    :server    => "webrick",
                                    :AccessLog => [])
        server.start
      end
      @t.run

      wait_for_server("127.0.0.1", port)
    end

    after do
      @t.kill
      @t.join
    end

    it "times out and falls back on the modern index" do
      gemfile <<-G
        source "#{@server_uri}"
        gem "rack"

        old_v, $VERBOSE = $VERBOSE, nil
        Bundler::Fetcher.api_timeout = 1
        $VERBOSE = old_v
      G

      bundle :install
      expect(out).to include("Fetching source index from #{@server_uri}/")
      should_be_installed "rack 1.0.0"
    end
  end
end
