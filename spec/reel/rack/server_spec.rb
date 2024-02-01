require 'spec_helper'
require 'net/http'
require 'rack/lint'
require 'rack/head'

module Reel
  module Rack
    describe Server do
      it "runs a basic Hello World app" do
        uri = URI("http://127.0.0.1:30000/")
        http = Net::HTTP.new(uri.host, uri.port)

        with_server(host: "127.0.0.1", port: 30000, response_body: "hello world") do
          expect(http.request_get(uri.path).body).to eq("hello world")
        end
      end

      it "success with basic HTTP methods" do
        uri = URI("http://127.0.0.1:30000/")
        http = Net::HTTP.new(uri.host, uri.port)

        server_options = { host: "127.0.0.1", port: 30000, response_body: "hello world" }

        with_server(**server_options) do
          expect(http.request_get(uri.path).body).to eq("hello world")
        end

        with_server(**server_options) do
          expect(http.request_head(uri.path).body).to eq(nil)
        end

        with_server(**server_options) do
          response = http.send_request("POST", uri.path, "test", { "content-type" => "text/plain" })

          expect(response.body).to eq("hello world")
        end

        with_server(**server_options) do
          response = http.send_request("PUT", uri.path, "test", { "content-type" => "text/plain" })

          expect(response.body).to eq("hello world")
        end

        with_server(**server_options) do
          response = http.send_request("PATCH", uri.path, "test", { "content-type" => "text/plain" })

          expect(response.body).to eq("hello world")
        end

        with_server(**server_options) do
          response = http.send_request("DELETE", uri.path, "test", { "content-type" => "text/plain" })

          expect(response.body).to eq("hello world")
        end
      end

      it "disables chunked transfer if a Content-Length header is set" do
        uri = URI("http://127.0.0.1:30000/")
        http = Net::HTTP.new(uri.host, uri.port)

        with_server(host: "127.0.0.1", port: 30000) do
          response = http.send_request("GET", uri.path, "test", { "content-type" => "text/plain" })

          expect(response["content-length"]).not_to eq(nil)
          expect(response["transfer-encoding"]).not_to eq("chunked")
        end
      end

      context "with no Content-Length header and the body is Enumerable" do
        it "sends a chunked transfer response if there is no Content-Length header and the body is Enumerable" do
          uri = URI("http://127.0.0.1:30000/")
          http = Net::HTTP.new(uri.host, uri.port)

          with_server(host: "127.0.0.1", port: 30000, response_headers: { "content-type" => "text/plain" }) do
            response = http.send_request("GET", uri.path, "test", { "content-type" => "text/plain" })

            expect(response["content-length"]).to eq(nil)
            expect(response["transfer-encoding"]).to eq("chunked")
          end
        end
      end

      context "works with Rack::Builder" do
        it "routes the requests both exact path and any path" do
          uri = URI("http://127.0.0.1:30000/")
          http = Net::HTTP.new(uri.host, uri.port)

          response_headers = {"content-type" => "text/plain"}
          rack_app = ::Rack::Builder.app {
            map("/path1") { run proc { [200, response_headers.merge("content-length"=>"5"), ["path1"]] } }
            run proc { [200, response_headers.merge("content-length"=>"3"), ["any"]] }
          }
          server_options = { host: "127.0.0.1", port: 30000, rack_app: }

          with_server(**server_options) do
            response = http.send_request('GET', "/path1", 'test', { "content-type" => "text/plain" })
            expect(response.body).to eq("path1")
          end

          with_server(**server_options) do
            response = http.send_request('GET', "/", 'test', { "content-type" => "text/plain" })
            expect(response.body).to eq("any")
          end

          with_server(**server_options) do
            response = http.send_request('GET', "/path2", 'test', { "content-type" => "text/plain" })
            expect(response.body).to eq("any")
          end
        end
      end

      def with_server(**options, &block)
        server = initialize_server(**options)
        block.call
        server.terminate
      end

      def initialize_server(**options)
        response_body = options.fetch(:response_body) {  "hello world" }
        response_headers = options.fetch(:response_headers, {"content-type" => "text/plain", "content-length" => response_body.length.to_s} )
        rack_app = options.fetch(:rack_app) { proc { [200, response_headers, [response_body]] } }
        host = options.fetch(:host, "127.0.0.1")
        port = options.fetch(:port, 30000)

        Server.new(
          ::Rack::Lint.new(::Rack::Head.new(rack_app)), :Host => host, :Port => port
        )
      end
    end
  end
end
