require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

helpers do
  def completed?(list)
    list[:todos].all? { |todo| todo[:completed] } && list[:todos].count >= 1
  end
  
  def completed_ratio(list)
    completed = list[:todos].select { |todo| !todo[:completed] }.count
    total = list[:todos].count
    
    "#{completed} / #{total}"
  end
  
  def list_class(list)
    'complete' if completed?(list)
  end
  
  def sort_lists(lists, &block)
    incomplete = {}
    complete = {}
    
    lists.each_with_index do |list, ind|
      if completed?(list)
        complete[list] = ind
      else
        incomplete[list] = ind
      end
    end
    
    incomplete.each(&block)
    complete.each(&block)
  end
  
  def sort_todos(todos, &block)
    incomplete = {}
    complete = {}
    
    todos.each_with_index do |todo, ind|
      if todo[:completed]
        complete[todo] = ind
      else
        incomplete[todo] = ind
      end
    end
    
    incomplete.each(&block)
    complete.each(&block)
  end
end

# Return an error if list name is invalid. Return nil if valid.
def check_for_error(list_name)
  error = if !(1..100).cover?(list_name.size)
            'The list name must be between 1 and 100 characters.'
          elsif session[:lists].any? { |list| list[:name] == list_name }
            'The list name must be unique.'
          end

  error
end

# Return an error if todo name is invalid. Return nil if valid.
def check_todo_error(todo)
  unless (1..100).cover?(todo.length)
    return "Todo must be between 1 and 100 characters."
  end
end

get '/' do
  redirect '/lists'
end

# GET   /lists                    -> view all lists
# GET   /lists/new                -> new list form
# POST  /lists                    -> create new list
# GET   /lists/1                  -> view a single list
# GET   /lists/1/edit             -> edit existing todo list name
# POST  /lists/1                  -> rename an existing list
# POST  /lists/1/destroy          -> delete an existing list
# POST  /lists/1/todos            -> add a todo to a list
# POST  /lists/1/todos/1/destroy  -> delete a todo from a list
# POST  /lists/1/todos/1          -> update status of todo
# POST  /lists/1/complete_all     -> complete all todos in a list    

# View all the lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = check_for_error(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been successfully created.'
    redirect '/lists'
  end
end

# View a single list
get '/lists/:number' do
  @num = params[:number].to_i
  @list = session[:lists][@num]
  @todos = session[:lists][@num][:todos]

  erb :list, layout: :layout
end

# Edit existing todo list name
get '/lists/:number/edit' do
  @num = params[:number].to_i
  @list = session[:lists][@num][:name]
  
  erb :edit_list
end

# Rename an existing list
post '/lists/:number' do
  list_name = params[:list_name].strip
  @num = params[:number].to_i
  @list = session[:lists][@num][:name]

  error = check_for_error(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    session[:lists][@num][:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@num}"
  end
end

# Delete an existing list
post '/lists/:number/destory' do
  num = params[:number].to_i
  session[:lists].delete_at(num)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a todo to a list
post '/lists/:list_num/todos' do
  @num = params[:list_num].to_i
  todo = params[:todo].strip
  @list = session[:lists][@num][:name]
  @todos = session[:lists][@num][:todos]
  
  error = check_todo_error(todo)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    session[:lists][@num][:todos] << { name: todo, completed: false }
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@num}"
  end
end

# Delete a todo from a list
post '/lists/:list_num/todos/:todo_num/destroy' do
  todo_num = params[:todo_num].to_i
  list_num = params[:list_num].to_i
  
  session[:lists][list_num][:todos].delete_at(todo_num)
  session[:success] = 'The todo has been deleted.'
  redirect "/lists/#{list_num}"
end

# Update status of todo
post '/lists/:list_num/todos/:todo_num' do
  list_num = params[:list_num].to_i
  todo_num = params[:todo_num].to_i
  todo = session[:lists][list_num][:todos][todo_num]
  
  is_completed = params[:completed] == 'true'
  todo[:completed] = is_completed
  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{list_num}"
end

# Mark all todos on a list complete
post '/lists/:num/complete_all' do
  num = params[:num].to_i
  todos = session[:lists][num][:todos]
  
  todos.each { |todo| todo[:completed] = true }
  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{num}"
end
