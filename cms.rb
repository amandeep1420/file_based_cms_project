require 'bcrypt'
require 'redcarpet'
require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'yaml'

configure do
  enable :sessions
  set :session_secret, "this worked without a secret"
end

before do
  pattern = File.join(data_path, "*")
  
  @files = Dir.glob(pattern).map do |path|
             File.basename(path)
           end.sort
end

helpers do
  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
  end
  
  def render_document(path)
    extension = File.extname(path)
    content   = File.read(path)
    
    case extension
    when ".md"
      render_markdown(content)
    when ".txt"
      headers["Content-Type"] = "text/plain"
      content
    end
  end
  
  def user_signed_in?
    session.key?(:username)
  end
  
  def redirect_if_not_signed_in
    unless user_signed_in?
      session[:message] = "You must be signed in to do that."
      redirect "/"
    end
  end
end

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials
  
  if credentials.key?(username)
    secure_password = BCrypt::Password.create(password)
    secure_password == password
  else
    false
  end
end

def valid_filename?(name)
  File.extname(name) == ".md" || File.extname(name) == ".txt"
end

get "/" do
  erb :index
end

get "/new" do
  redirect_if_not_signed_in
  erb :new
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username = params[:username]
  password = params[:password]
  
  if valid_credentials?(username, password)
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/:filename" do
  file_path = File.join(data_path, File.basename(params[:filename]))
  
  if File.file?(file_path)
    render_document(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  redirect_if_not_signed_in
  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

post "/new" do
  redirect_if_not_signed_in
  name = params[:new_file].strip
  
  if valid_filename?(name)
    create_document(name)
    session[:message] = "#{name} was created."
    redirect "/"
  else
    session[:message] = "Please enter a valid file name."
    status 422
    erb :new
  end
end

post "/:filename" do
  redirect_if_not_signed_in
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  redirect_if_not_signed_in
  file_path = File.join(data_path, params[:filename])
  
  File.delete(file_path)
  
  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end