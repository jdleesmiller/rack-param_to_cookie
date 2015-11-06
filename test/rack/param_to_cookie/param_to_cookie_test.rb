require 'minitest/autorun'
require 'rack/test'

require 'rack/param_to_cookie'

describe 'Rack::ParamToCookie' do
  include Rack::Test::Methods

  def make_app *param_cookies
    dummy_app = lambda do |env|
      [200, { 'Content-Type' => 'text/plain' }, ['hi']]
    end
    @app = Rack::ParamToCookie.new(dummy_app, *param_cookies)
  end

  def app
    @app
  end

  describe 'with defaults and a ref param' do
    before do
      make_app 'ref' => {}
      clear_cookies
    end

    it 'should do nothing when there is no ref parameter' do
      get '/'

      assert_equal nil, last_request.env['ref']
      assert_equal({}, rack_mock_session.cookie_jar.to_hash)
    end

    it 'should set a ref cookie if one is present' do
      # first request sets ref
      get '/', ref: 'abc'
      assert_equal 'abc', last_request.env['ref']
      assert_equal({ 'ref' => 'abc' }, rack_mock_session.cookie_jar.to_hash)
      assert_match(/abc/, last_response.headers['Set-Cookie'])

      # it should be remembered on the second request
      get '/'
      assert_equal 'abc', last_request.env['ref']
      assert_equal({ 'ref' => 'abc' }, rack_mock_session.cookie_jar.to_hash)
      assert_equal nil, last_response.headers['Set-Cookie']

      # if we set it again, it gets overwritten
      get '/', ref: '123'
      assert_equal '123', last_request.env['ref']
      assert_equal({ 'ref' => '123' }, rack_mock_session.cookie_jar.to_hash)
      assert_match(/123/, last_response.headers['Set-Cookie'])

      # ... and remembered
      get '/'
      assert_equal '123', last_request.env['ref']
      assert_equal({ 'ref' => '123' }, rack_mock_session.cookie_jar.to_hash)
      assert_equal nil, last_response.headers['Set-Cookie']
    end
  end

  describe 'with multiple parameters and custom names' do
    before do
      make_app \
        'ref' => { cookie_name: 'ref_cookie', env_name: 'ref.env', ttl: 10 },
        'aff' => { cookie_name: 'aff_cookie', env_name: 'aff.env', ttl: 20 }
      clear_cookies
    end

    it 'should set ref and aff' do
      # initially no cookies
      get '/'
      assert_equal nil, last_request.env['ref.env']
      assert_equal nil, last_request.env['aff.env']
      assert_equal({}, rack_mock_session.cookie_jar.to_hash)
    end

    it 'set both at the same time' do
      get '/', ref: 'foo', aff: 'bar'
      assert_equal 'foo', last_request.env['ref.env']
      assert_equal 'bar', last_request.env['aff.env']
      assert_equal({ 'ref_cookie' => 'foo', 'aff_cookie' => 'bar' },
                   rack_mock_session.cookie_jar.to_hash)

      # should have set cookies with expiry times ~10s and ~20s, resp.
      cookie_header = last_response.headers['Set-Cookie']
      expires = cookie_header.scan(/^(.+?)_cookie=.+?; expires=(.+?)$/)
      expires = Hash[expires.map { |cookie, date| [cookie, Time.parse(date)] }]
      assert expires['ref'] > Time.now + 9
      assert expires['ref'] <= Time.now + 11
      assert expires['aff'] > Time.now + 19
      assert expires['aff'] <= Time.now + 21
      assert_equal 2, expires.size

      # retreive both
      get '/'
      assert_equal 'foo', last_request.env['ref.env']
      assert_equal 'bar', last_request.env['aff.env']
      assert_equal({ 'ref_cookie' => 'foo', 'aff_cookie' => 'bar' },
                   rack_mock_session.cookie_jar.to_hash)
      assert_equal nil, last_response.headers['Set-Cookie']

      # update ref
      get '/', ref: 'baz'
      assert_equal 'baz', last_request.env['ref.env']
      assert_equal 'bar', last_request.env['aff.env']
      assert_equal({ 'ref_cookie' => 'baz', 'aff_cookie' => 'bar' },
                   rack_mock_session.cookie_jar.to_hash)
      assert_match(/baz/, last_response.headers['Set-Cookie'])
      assert(/bar/ !~ last_response.headers['Set-Cookie'])

      # retreive both
      get '/'
      assert_equal 'baz', last_request.env['ref.env']
      assert_equal 'bar', last_request.env['aff.env']
      assert_equal({ 'ref_cookie' => 'baz', 'aff_cookie' => 'bar' },
                   rack_mock_session.cookie_jar.to_hash)
      assert_equal nil, last_response.headers['Set-Cookie']

      # update aff
      get '/', aff: 'bat'
      assert_equal 'baz', last_request.env['ref.env']
      assert_equal 'bat', last_request.env['aff.env']
      assert_equal({ 'ref_cookie' => 'baz', 'aff_cookie' => 'bat' },
                   rack_mock_session.cookie_jar.to_hash)
      assert_match(/bat/, last_response.headers['Set-Cookie'])
      assert(/baz/ !~ last_response.headers['Set-Cookie'])

      # retreive both
      get '/'
      assert_equal 'baz', last_request.env['ref.env']
      assert_equal 'bat', last_request.env['aff.env']
      assert_equal({ 'ref_cookie' => 'baz', 'aff_cookie' => 'bat' },
                   rack_mock_session.cookie_jar.to_hash)
      assert_equal nil, last_response.headers['Set-Cookie']
    end
  end

  describe 'referral configuration' do
    before do
      make_app \
        'utm_campaign' => {
                  referral_value: 'affi-widget-nov15',
                  referral_saved: 'utm_referral',
                  cookie_name: 'ref_cookie',
                  env_name: 'ref.env' }
      clear_cookies
    end

    it 'set the cookie with the utm_referral param value' do
      get '/',
          utm_campaign: 'affi-widget-nov15',
          utm_referral: 'http://my-partner.com'
      assert_equal({ 'ref_cookie' => 'http://my-partner.com' }, rack_mock_session.cookie_jar.to_hash)
    end

    it 'doesnt create the cookie when no utm_referral' do
      get '/', utm_campaign: 'affi-widget-nov15'
      assert_equal(last_response.headers['Set-Cookie'], nil)
    end

    it 'set the cookie ttl at 30 days' do
      get '/',
          utm_campaign: 'affi-widget-nov15',
          utm_referral: 'http://my-partner.com'

      expires = last_response.headers['Set-Cookie'].scan(/^(.+?)_cookie=.+?; expires=(.+?)$/)
      expires = Hash[expires.map { |cookie, date| [cookie, Time.parse(date)] }]
      assert expires['ref'] > Time.now + 2592000 - 1
      assert expires['ref'] <= Time.now + 2592000 + 1
    end
  end
end
