ENV["RACK_ENV"] = "test"

require "fileutils"
require "minitest/autorun"
require "rack/test"

require_relative "../cms.rb"

class CMSTest < Minitest::Test
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def setup
    FileUtils.mkdir_p(data_path)
  end
  
  def teardown
    FileUtils.rm_rf(data_path)
  end
  
  def session
    last_request.env["rack.session"]
  end
  
  def admin_session
    { "rack.session" => { username: "admin" } }
  end
  
  def test_index # different from LS solution, which ran tests for each individual file manually
    create_document("about.md")
    create_document("changes.txt")
  
    get "/"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes(last_response.body, "about.md")
    assert_includes(last_response.body, "changes.txt")
  end
  
  def test_file_retrieval
    create_document("history.txt", "This is a test string")
  
    get "/history.txt"
    
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal last_response.body, "This is a test string"
  end
  
  def test_file_does_not_exist
    fake_file_name = "notafile.txt"
    
    get "/#{fake_file_name}"
    assert_equal 302, last_response.status
    assert_equal "#{fake_file_name} does not exist.", session[:message]
  end
  
  def test_rendering_markdown
    create_document("about.md", "<h1>Ruby is...</h1>")
    
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end
  
  def test_editing_document
    create_document("changes.txt")
    
    get "/changes.txt/edit"
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
    
    get "/changes.txt/edit", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_updating_document
    post "/changes.txt", content: "new content"
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
    
    post "/changes.txt", {content: "new content"}, admin_session
    
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]
    
    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
  
  def test_view_new_document_form
    get "/new"
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
    
    get "/new", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_create_new_document
    post "/new", new_file: "test.txt"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
    
    post "/new", {new_file: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt was created.", session[:message]
    
    get "/"
    assert_includes last_response.body, "test.txt"
  end
  
  def test_create_new_document_with_empty_filename_and_invalid_filename
    post "/new", new_file: ""
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
    
    post "/new", new_file: "test.pdf"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
    
    post "/new", {new_file: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Please enter a valid file name."
    
    post "/new", {new_file: "test.pdf"}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Please enter a valid file name."
  end
  
  def test_deleting_a_document
    create_document("test.txt")
    
    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
    
    post "/test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:message]
    
    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end
  
  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "admin", session[:username]
    assert_equal "Welcome!", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    post "/users/signin", username: "admin", password: "secret"
    assert_equal "Welcome!", session[:message]

    post "/users/signout"
    assert_equal "You have been signed out.", session[:message]
    
    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end
end