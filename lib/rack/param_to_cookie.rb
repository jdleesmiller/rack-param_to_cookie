require 'rack/param_to_cookie/version'

module Rack
  #
  # Rack middleware. See README.
  #
  class ParamToCookie
    #
    # @param [Object] app
    #
    # @param [Hash<String, Hash>] param_cookies map from parameter names to
    #                             cookie options
    #
    def initialize app, param_cookies
      @app = app
      @param_cookies = param_cookies
      @param_cookies.each do |param, options|
        options[:cookie_name] ||= param
        options[:env_name] ||= param
        options[:ttl] ||= 60 * 60 * 24 * 30 # 30 days
        options[:set_cookie_options] ||= {}
      end
    end

    def call env
      req = Rack::Request.new(env)

      updated_cookies = {}
      @param_cookies.each do |param, options|
        # get the value from a previously set cookie
        cookie_value = req.cookies[options[:cookie_name]]

        # check whether there's a new value for the cookie with this request
        params_value = req.params[param] rescue nil

        if !params_value.nil? && params_value == options[:referral_value]
          params_value = req.params[options[:referral_saved]] rescue nil
        end

        value = params_value || cookie_value
        env[options[:env_name]] = value if value

        # once we handle the response, set the new cookie value
        if params_value
          updated_cookies[options[:cookie_name]] =
            options[:set_cookie_options].merge(
              value: params_value,
              expires: Time.now + options[:ttl])
        end
      end

      status, headers, body = @app.call(env)
      response = Rack::Response.new body, status, headers

      updated_cookies.each do |cookie, options|
        response.set_cookie cookie, options
      end

      response.finish
    end
  end
end
