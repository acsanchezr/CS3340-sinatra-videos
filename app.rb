require "sinatra"
require_relative "authentication.rb"
require 'stripe'


set :publishable_key, "pk_test_Y19q4uOMtZL9rfgh3uHTtEo5"
set :secret_key, "sk_test_aTWBdKlOMVvvoJtaz7xjfFIg"

Stripe.api_key = settings.secret_key

# need install dm-sqlite-adapter
# if on heroku, use Postgres database
# if not use sqlite3 database I gave you
if ENV['DATABASE_URL']
  DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
else
  DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/app.db")
end

class Video
	include DataMapper::Resource

	property :id, Serial
	property :title, Text
	property :description, Text
	property :video_url, Text
	property :pro, Boolean, :default => false
end

DataMapper.finalize
User.auto_upgrade!
Video.auto_upgrade!

#make an admin user if one doesn't exist!
if User.all(administrator: true).count == 0
	u = User.new
	u.email = "admin@admin.com"
	u.password = "admin"
	u.administrator = true
	u.save
end

#the following urls are included in authentication.rb
# GET /login
# GET /logout
# GET /sign_up

# authenticate! will make sure that the user is signed in, if they are not they will be redirected to the login page
# if the user is signed in, current_user will refer to the signed in user object.
# if they are not signed in, current_user will be nil

def youtube_embed(youtube_url)
  if youtube_url[/youtu\.be\/([^\?]*)/]
    youtube_id = $1
  else
    # Regex from # http://stackoverflow.com/questions/3452546/javascript-regex-how-to-get-youtube-video-id-from-url/4811367#4811367
    youtube_url[/^.*((v\/)|(embed\/)|(watch\?))\??v?=?([^\&\?]*).*/]
    youtube_id = $5
  end
	%Q{<iframe title="YouTube video player" width="640" height="390" src="https://www.youtube.com/embed/#{ youtube_id }" frameborder="0" allowfullscreen></iframe>}
end



get "/" do
	erb :index
end

get "/videos" do #displays all videos
	authenticate!
	if (pro? || admin?)
		@videos = Video.all
		erb :videos
	else
		@videos = Video.all(pro: false)
		erb :videos
	end
end

post "/videos/create" do
	#get parameters
	i_title = params["title"]
	i_desc = params["description"]
	i_url = params["video_url"]
	i_pro = params["pro"]
	
	#create video - free users
	if(admin? && i_title && i_desc && i_url )
		newvid = Video.new
		newvid.title = i_title
		newvid.description = i_desc
		newvid.video_url = i_url
		#pro users
		newvid.pro = true if i_pro == "on"
		newvid.save
		"Successfully added new video!"
	#else
	#	redirect "/"
	end
end

get "/videos/new" do
	authenticate!
	if (admin?) 
		erb :new_video
	else
		"not an administrator!"
		redirect "/"
	end
end


get "/upgrade" do
	authenticate!

	if (current_user.administrator == false && pro? == false)
		erb :pay_form
	else
		redirect "/"
	end
end 

post "/charge" do
	authenticate!
 	cu=current_user
 	cu.pro = true
 	cu.save

 	 # Amount in cents
  @amount = 500

  customer = Stripe::Customer.create(
    :email => 'customer@example.com',
    :source  => params[:stripeToken]
  )

  charge = Stripe::Charge.create(
    :amount      => @amount,
    :description => 'Sinatra Charge',
    :currency    => 'usd',
    :customer    => customer.id
  )

  erb :charge

  "Success!"
end
