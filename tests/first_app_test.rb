ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms.rb"

class CMSTest < Minitest::Test
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def setup
    @files = @files = Dir.glob("../data/*").map do |path|
               File.basename(path)
             end.sort
  end
  
  def test_index # different from LS solution, which ran tests for each individual file manually
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert @files.all? { |filename| last_response.body.include?(filename) }
  end
  
  def test_file_retrieval
    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal last_response.body, File.read("../data/history.txt")
  end
  
  def test_file_does_not_exist
    fake_file_name = "notafile.txt"
    
    get "/#{fake_file_name}"
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "#{fake_file_name} does not exist."
    
    get "/"
    assert_equal 200, last_response.status
    refute_includes last_response.body, "#{fake_file_name} does not exist."
  end
  
  def test_rendering_markdown
    get "/about.md"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end
  
  def test_editing_document
    get "/changes.txt/edit"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_updating_document
    post "/changes.txt", content: "new content"
    
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    
    assert_includes last_response.body, "changes.txt has been updated"
    
    get "/changes.txt"
    asert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
end