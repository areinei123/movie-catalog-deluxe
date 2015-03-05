require 'sinatra'
require 'erb'
require 'pg'

def get_page(page_param)
	if page_param && page_param.to_i >= 1
		page_param.to_i
	else
		1
	end
end

def get_order(order_param)
	if order_param && order_param != :title
		order_param
	else
		'title'
	end
end

def db_connection
	connection = PG.connect(dbname: "movies")
	yield(connection)
	ensure
  	connection.close
end

def get_actors(page)
	db_connection do |conn|
  	conn.exec_params("SELECT name, actors.id AS actor_id, COUNT " \
  		"(cast_members.id) FROM actors FULL OUTER JOIN cast_members ON " \
  		"cast_members.actor_id = actors.id GROUP BY actors.id ORDER BY name " \
  		"LIMIT 20 OFFSET $1", [(page-1)*20])
	end
end

def get_movies(sort_order, page)
	db_connection do |conn|
		sort_order != "title" ? desc = "DESC" : desc = ""
		sort_order == "rating" ? notnull = "WHERE rating IS NOT NULL" : notnull = ""
		sort_order = conn.quote_ident(sort_order)
		offset = (page.to_i-1)*20
  	conn.exec("SELECT title, id, year, rating FROM movies #{notnull} ORDER BY" \
  		" #{sort_order} #{desc} LIMIT 20 OFFSET #{offset.to_i}")
	end
end

def search_movies(search_term)
	db_connection do |conn|
		conn.exec("SELECT * FROM movies WHERE to_tsvector(title) " \
			"@@ plainto_tsquery('#{search_term}')")
	end
end

def search_actors(search_term)
	db_connection do |conn|
		conn.exec("SELECT actors.name, cast_members.character, movies.title, " \
			"actors.id AS actor_id, movies.id AS movie_id FROM actors FULL OUTER " \
			"JOIN cast_members ON cast_members.actor_id = actors.id FULL OUTER " \
			"JOIN movies ON cast_members.movie_id = movies.id WHERE " \
			"to_tsvector(actors.name) @@ plainto_tsquery('#{search_term}') OR" \
			" to_tsvector(cast_members.character) @@ " \
			"plainto_tsquery('#{search_term}')")
	end
end

def get_actor_id(actor_id)
	db_connection do |conn|
  	conn.exec_params("SELECT actors.id AS actor_id, movies.id AS movie_id, " \
  		"actors.name, movies.title, cast_members.character FROM movies FULL " \
  		"OUTER JOIN cast_members ON cast_members.movie_id = movies.id FULL " \
  		"OUTER JOIN actors ON actors.id = cast_members.actor_id WHERE actors.id" \
  		" = $1", [actor_id])
	end
end

def get_movie_id(movie_id)
	db_connection do |conn|
  	conn.exec_params("SELECT actors.id AS actor_id, movies.id AS movie_id, " \
  		"actors.name AS actor_name, movies.title, cast_members.character, " \
  		"genres.name AS genre_name, studios.name AS studio_name FROM movies " \
   		"FULL OUTER JOIN cast_members ON cast_members.movie_id = movies.id FULL" \
   		" OUTER JOIN actors ON actors.id = cast_members.actor_id FULL OUTER " \
   		"JOIN studios ON movies.studio_id = studios.id FULL OUTER JOIN genres " \
   		"ON movies.genre_id = genres.id WHERE movies.id = $1", [movie_id])
	end
end


get '/' do
  redirect '/home'
end

get '/home' do
  erb :home
end

get '/actors' do
	page = get_page(params[:page])
	searched_actors = search_actors(params[:query]) if params[:query]
	erb :actors, locals: { page: page, actors: get_actors(page),
		searched_actors: searched_actors }
end

get '/actors/' do
  redirect '/actors'
end

get "/actors/:id" do
	erb :actor_id, locals: { actor: get_actor_id(params[:id]) }
end

get '/movies' do
	page = get_page(params[:page])
	order = get_order(params[:order])
	searched_movies = search_movies(params[:query]) if params[:query]
	erb :movies, locals: { page: page, movies: get_movies(order, page),
		order: order, searched_movies: searched_movies }
end

get '/movies/' do
  redirect '/movies'
end

get "/movies/:id" do
	erb :movie_id, locals: { movie: get_movie_id(params[:id]) }
end
