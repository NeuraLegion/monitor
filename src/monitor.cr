require "http"
require "tallboy"
require "clim"
require "wafalyzer"
require "colorize"

module Monitor
  VERSION = "0.1.0"

  class Run < Clim
    PROBLOMATIC_STATUS_CODES = {
      400 => "Bad Request - The server could not understand the request due to invalid syntax.",
      401 => "Unauthorized - The request requires user authentication.",
      403 => "Forbidden - The server understood the request, but is refusing to fulfill it.",
      405 => "Method Not Allowed - The request method is not supported by the target resource.",
      408 => "Request Timeout - The client did not produce a request within the time that the server was prepared to wait.",
      410 => "Gone - The target resource is no longer available at the origin server and is no longer expected to be available.",
      411 => "Length Required - The server requires the Content-Length header field to be present in the request.",
      415 => "Unsupported Media Type - The server is refusing to service the request because the payload is in a format not supported by the target resource.",
      429 => "Too Many Requests - The client has sent too many requests in a given amount of time.",
      500 => "Internal Server Error - The server encountered an unexpected condition that prevented it from fulfilling the request.",
      501 => "Not Implemented - The server does not support the functionality required to fulfill the request.",
      502 => "Bad Gateway - The server received an invalid response from an upstream server while attempting to fulfill the request.",
      503 => "Service Unavailable - The server is currently unable to handle the request due to maintenance or capacity issues.",
      504 => "Gateway Timeout - The server did not receive a timely response from an upstream server while attempting to fulfill the request.",
    }

    WORDPRESS_INDICATOR = {
      "wp-content",
      "wp-includes",
      "wp-json",
      "wp-login.php",
      "wp-admin",
      "wp-content/plugins",
      "wp-content/themes",
      "wp-content/uploads",
      "wp-content/cache",
      "wp-content/upgrade",
      "wp-content/languages",
    }

    main do
      desc <<-DESC
        ██████╗ ██████╗ ██╗ ██████╗ ██╗  ██╗████████╗███████╗███████╗ ██████╗              ███╗   ███╗ ██████╗ ███╗   ██╗██╗████████╗ ██████╗ ██████╗
        ██╔══██╗██╔══██╗██║██╔════╝ ██║  ██║╚══██╔══╝██╔════╝██╔════╝██╔════╝              ████╗ ████║██╔═══██╗████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗
        ██████╔╝██████╔╝██║██║  ███╗███████║   ██║   ███████╗█████╗  ██║         █████╗    ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝
        ██╔══██╗██╔══██╗██║██║   ██║██╔══██║   ██║   ╚════██║██╔══╝  ██║         ╚════╝    ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗
        ██████╔╝██║  ██║██║╚██████╔╝██║  ██║   ██║   ███████║███████╗╚██████╗              ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║
        ╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚══════╝ ╚═════╝              ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
        DESC
      usage "monitor --url <url>"
      version "Version 0.1.0"
      option "-u URL", "--url=URL", type: String, desc: "Target URL.", required: true
      option "-c CONCURRENCY", "--concurrency=CONCURRENCY", type: Int32, desc: "Number of concurrent requests to make.", default: 10
      option "-t TOTAL_REQUESTS", "--total-requests=TOTAL_REQUESTS", type: Int32, desc: "Total number of requests to make.", default: 1000
      option "-a", "--attack", desc: "Adds <script>alert(1)</script> to the end of the URL.", default: false, type: Bool
      @files_created : Atomic(Int32) = Atomic(Int32).new(0)

      run do |opts, args|
        uri = URI.parse(opts.url)
        if opts.attack
          if uri.query
            uri.query = "#{uri.query}&id=<script>alert(1)</script>"
          else
            uri.query = "id=<script>alert(1)</script>"
          end
          puts "Adding attack to URL: #{uri.to_s}"
        end
        Dir.mkdir("#{Dir.tempdir}/#{uri.host}") unless Dir.exists?("#{Dir.tempdir}/#{uri.host}")
        puts "Debug files will be saved to #{Dir.tempdir}/#{uri.host}"
        sleep 3.seconds
        unless uri.host && uri.scheme
          raise "Error: URL Is Malformed"
        end
        response_channel = Channel(Int32 | Exception).new(opts.total_requests)
        uri_channel = Channel(URI).new(opts.total_requests)
        opts.concurrency.times do
          spawn do
            request_handlers(uri_channel, response_channel)
          end
        end
        spawn do
          opts.total_requests.times do
            uri_channel.send(uri)
          end
        end

        responses = Hash(String | Int32, Int32).new(0)
        exception_messages = Hash(String, String).new
        wafs = Array(Wafalyzer::Waf).new
        begin
          wafs = Wafalyzer.detect(url: uri.to_s)
        rescue Exception
        end

        wordpress = detect_wordpress(uri)
        random_200 = random_url_give_200(uri)
        potential_subdomains = detect_potential_subdomains(uri)

        opts.total_requests.times do |i|
          response = response_channel.receive
          print "\r#{i + 1}/#{opts.total_requests} requests complete"
          if response.is_a?(Exception)
            unless exception_messages[response]?
              exception_messages[response.class.to_s] = response.message.to_s
            end
            responses[response.class.to_s] += 1
          else
            responses[response] += 1
          end
        end
        table = Tallboy.table do
          columns do
            add "Responses"
            add "Count"
            add "Description"
          end
          header
          responses.each do |code, count|
            case code
            when Int32
              row [code, count, PROBLOMATIC_STATUS_CODES[code]? || "OK"]
            when String
              row [code, count, exception_messages[code]]
            end
          end
        end
        puts "\n#{table}"
        puts "• External IP: #{get_external_ip}".colorize(:white).mode(:bold)
        puts "• Debug Files Created: #{@files_created.get}" if @files_created.get > 0
        puts "• WAFs detected: #{wafs.map(&.to_s).join(", ")}".colorize(:red).mode(:bold) unless wafs.empty?
        puts "• Random URL gave 200, this will make finding protected resource harder, it's advised to use an API EP".colorize(:red).mode(:bold) if random_200
        puts "• WordPress detected, it's advised to run a WordPress scan".colorize(:red).mode(:bold) if wordpress
        unless potential_subdomains.empty?
          print "• Found potential subdomains: ".colorize(:red).mode(:bold)
          print potential_subdomains.join(", ")
          puts " It's advised to include these in your scan, otherwise you may miss some resources.".colorize(:red).mode(:bold)
        end
      end

      def request_handlers(uri_channel : Channel(URI), response_channel : Channel(Int32 | Exception))
        loop do
          uri = uri_channel.receive
          response = HTTP::Client.get(uri.to_s)
          unless response.status.success?
            File.tempfile(prefix: "#{uri.host}", suffix: ".html", dir: "#{Dir.tempdir}/#{uri.host}") do |file|
              file.print(response.body)
            end
            @files_created.add(1)
          end
          response_channel.send(response.status_code)
        rescue e : Exception
          response_channel.send(e)
        end
      end

      def detect_wordpress(uri : URI) : Bool
        body = HTTP::Client.get(uri.to_s).body
        WORDPRESS_INDICATOR.any? { |indicator| body.includes?(indicator) }
      rescue
        false
      end

      def random_url_give_200(uri : URI) : Bool
        random_uri = URI.parse(uri.to_s)
        random_path = "/#{Random::Secure.hex}"
        random_uri.path = random_path
        response = HTTP::Client.get(random_uri.to_s)
        response.status_code == 200
      rescue
        false
      end

      def get_external_ip : String
        HTTP::Client.get("https://api.ipify.org").body.to_s
      rescue
        ""
      end

      def detect_potential_subdomains(uri : URI) : Array(String)
        resp = HTTP::Client.get(uri.to_s)
        main_host = URI.parse(uri.to_s).host.to_s
        potential_subdomains = Array(String).new
        if content_header = resp.headers["content-security-policy"]?
          content_header.split(" ").each do |url|
            url = url.strip
            if url.starts_with?("https://") || url.starts_with?("http://")
              host = URI.parse(url).host.to_s
              if host.includes?(main_host) && host.includes?("api") && host.size > main_host.size
                potential_subdomains << host
              end
            end
          end
        end
        potential_subdomains.uniq
      rescue
        Array(String).new
      end
    end
  end
end

Monitor::Run.start(ARGV)
