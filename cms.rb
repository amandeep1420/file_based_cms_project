require 'redcarpet'
require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'


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
  def data_path
    if ENV["RACK_ENV"] == "test"
      File.expand_path("../test/data", __FILE__)
    else
      File.expand_path("../data", __FILE__)
    end
  end
  
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
end

get "/" do
  
  erb :index
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])
  
  if File.file?(file_path)
    render_document(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

post "/:filename" do
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end