# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
#
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
$:.unshift File.dirname(__FILE__)

require 'bundler/setup'
Bundler.require

require 'rspec'
require 'webmock/rspec'
require 'oddb2xml'

module ServerMockHelper
  def setup_server_mocks
    setup_bag_xml_server_mock
    setup_swiss_index_server_mock
    setup_swissmedic_server_mock
    setup_swissmedic_info_server_mock
    setup_epha_server_mock
    setup_bm_update_server_mock
    setup_lppv_server_mock
    setup_migel_server_mock
  end
  def setup_bag_xml_server_mock
    # zip
    stub_zip_url = 'http://bag.e-mediat.net/SL2007.Web.External/File.axd?file=XMLPublications.zip'
    stub_response = File.read(File.expand_path('../data/XMLPublications.zip', __FILE__))
    stub_request(:get, stub_zip_url).
      with(:headers => {
        'Accept'          => '*/*',
        'Accept-Encoding' => 'gzip,deflate,identity',
        'Host'            => 'bag.e-mediat.net',
      }).
      to_return(
        :status  => 200,
        :headers => {'Content-Type' => 'application/zip; charset=utf-8'},
        :body    => stub_response)
  end
  def setup_swiss_index_server_mock
    ['Pharma', 'NonPharma'].each do |type|
      # wsdl
      stub_wsdl_url = "https://index.ws.e-mediat.net/Swissindex/#{type}/ws_#{type}_V101.asmx?WSDL"
      stub_response = File.read(File.expand_path("../data/wsdl_#{type.downcase}.xml", __FILE__))
      stub_request(:get, stub_wsdl_url).
        with(:headers => {
          'Accept'     => '*/*',
          'User-Agent' => 'Ruby'}).
        to_return(
          :status  => 200,
          :headers => {'Content-Type' => 'text/xml; charset=utf-8'},
          :body    => stub_response)
      # soap (dummy)
      stub_soap_url = 'https://example.com/test'
      stub_response = File.read(File.expand_path("../data/swissindex_#{type.downcase}.xml", __FILE__))
      stub_request(:post, stub_soap_url).
        with(:headers => {
          'Accept'     => '*/*',
          'User-Agent' => 'Ruby'}).
        to_return(
          :status  => 200,
          :headers => {'Content-Type' => 'text/xml; chaprset=utf-8'},
          :body    => stub_response)
    end
  end
  def setup_swissmedic_server_mock
    host = 'www.swissmedic.ch'
    {
      :orphans => {:html => '/daten/00081/index.html?lang=de',       :xls => '/download'},
      :fridges => {:html => '/daten/00080/00254/index.html?lang=de', :xls => '/download'}
    }.each_pair do |type, urls|
      # html (dummy)
      stub_html_url = "http://#{host}" + urls[:html]
      stub_response = File.read(File.expand_path("../data/swissmedic_#{type.to_s}.html", __FILE__))
      stub_request(:get, stub_html_url).
        with(:headers => {
          'Accept' => '*/*',
          'Host'   => host,
        }).
        to_return(
          :status  => 200,
          :headers => {'Content-Type' => 'text/html; charset=utf-8'},
          :body    => stub_response)
      # xls
      stub_xls_url  = "http://#{host}" + urls[:xls] + "/swissmedic_#{type.to_s}.xls"
      stub_response = File.read(File.expand_path("../data/swissmedic_#{type.to_s}.xls", __FILE__))
      stub_request(:get, stub_xls_url).
        with(:headers => {
          'Accept'          => '*/*',
          'Accept-Encoding' => 'gzip,deflate,identity',
          'Host'            => host,
        }).
        to_return(
          :status  => 200,
          :headers => {'Content-Type' => 'application/octet-stream; charset=utf-8'},
          :body    => stub_response)
    end
  end
  def setup_swissmedic_info_server_mock
    # html (dummy)
    stub_html_url = "http://download.swissmedicinfo.ch/Accept.aspx?ReturnUrl=%2f"
    stub_response = File.read(File.expand_path("../data/swissmedic_info.html", __FILE__))
    stub_request(:get, stub_html_url).
      with(
        :headers => {
          'Accept' => '*/*',
          'Host'   => 'download.swissmedicinfo.ch',
        }).
      to_return(
        :status  => 200,
        :headers => {'Content-Type' => 'text/html; charset=utf-8'},
        :body    => stub_response)
    # html (dummy 2)
    stub_html_url = 'http://download.swissmedicinfo.ch/Accept.aspx?ctl00$MainContent$btnOK=1'
    stub_response = File.read(File.expand_path("../data/swissmedic_info_2.html", __FILE__))
    stub_request(:get, stub_html_url).
      with(
        :headers => {
          'Accept' => '*/*',
          'Host'   => 'download.swissmedicinfo.ch',
        }).
      to_return(
        :status  => 200,
        :headers => {'Content-Type' => 'text/html; charset=utf-8'},
        :body    => stub_response)
    # zip
    stub_zip_url = 'http://download.swissmedicinfo.ch/Accept.aspx?ctl00$MainContent$BtnYes=1'
    stub_response = File.read(File.expand_path('../data/swissmedic_info.zip', __FILE__))
    stub_request(:get, stub_zip_url).
      with(
        :headers => {
          'Accept'          => '*/*',
          'Accept-Encoding' => 'gzip,deflate,identity',
          'Host'            => 'download.swissmedicinfo.ch',
        }).
      to_return(
        :status  => 200,
        :headers => {'Content-Type' => 'application/zip; charset=utf-8'},
        :body    => stub_response)
  end
  def setup_epha_server_mock
    # csv
    stub_csv_url = 'http://community.epha.ch/interactions_de_utf8.csv'
    stub_response = File.read(File.expand_path('../data/epha_interactions.csv', __FILE__))
    stub_request(:get, stub_csv_url).
      with(:headers => {
        'Accept' => '*/*',
        'Host'   => 'community.epha.ch',
      }).
      to_return(
        :status  => 200,
        :headers => {'Content-Type' => 'text/csv; charset=utf-8'},
        :body    => stub_response)
  end
  def setup_bm_update_server_mock
    # txt
    stub_txt_url = 'https://raw.github.com/zdavatz/oddb2xml_files/master/BM_Update.txt'
    stub_response = File.read(File.expand_path('../data/oddb2xml_files_bm_update.txt', __FILE__))
    stub_request(:get, stub_txt_url).
      with(:headers => {
        'Accept' => '*/*',
        'Host'   => 'raw.github.com',
      }).
      to_return(
        :status  => 200,
        :headers => {'Content-Type' => 'text/plain; charset=utf-8'},
        :body    => stub_response)
  end
  def setup_lppv_server_mock
    # txt
    stub_txt_url = 'https://raw.github.com/zdavatz/oddb2xml_files/master/LPPV.txt'
    stub_response = File.read(File.expand_path('../data/oddb2xml_files_lppv.txt', __FILE__))
    stub_request(:get, stub_txt_url).
      with(:headers => {
        'Accept' => '*/*',
        'Host'   => 'raw.github.com',
      }).
      to_return(
        :status  => 200,
        :headers => {'Content-Type' => 'text/plain; charset=utf-8'},
        :body    => stub_response)
  end
  def setup_migel_server_mock
    # xls
    stub_xls_url = 'https://github.com/zdavatz/oddb2xml_files/raw/master/NON-Pharma.xls'
    stub_response = File.read(File.expand_path('../data/oddb2xml_files_nonpharma.xls', __FILE__))
    stub_request(:get, stub_xls_url).
      with(:headers => {
        'Accept' => '*/*',
        'Host'   => 'github.com',
      }).
      to_return(
        :status  => 200,
        :headers => {'Content-Type' => 'application/octet-stream; charset=utf-8'},
        :body    => stub_response)
  end
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.filter_run_excluding :slow
  #config.exclusion_filter = {:slow => true}

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  # Helper
  config.include(ServerMockHelper)
end
