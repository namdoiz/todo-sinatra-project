require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, '51d2deb7cc8bd1738a3cf4b899aeedc5bb509ab8b94161e9c51b8860f043ca59'
  set :erb, :escape_html => true
end

helpers do
  def list_complete?(list)
    list[:todos].size > 0 && list[:todos].all? { |todo| todo[:completed] }
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select {|todo| !todo[:completed]}.size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }
  
    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    
    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  else
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters."
  end
end

# Redirects to the lists page if an invalid list number is given
def load_list(index)
  list = session[:lists][index] if index && session[:lists][index]
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a single todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list
end

# Edit an existing todo list

get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list
end

# Update an existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post "/lists/:id/delete" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list
  else
    @list[:todos] << {name: params[:todo], completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post "/lists/:list_id/todos/:id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @list[:todos].delete_at todo_id
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end


# Update the status of the todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end