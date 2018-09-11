require 'sinatra'
require 'sinatra/cookies'
require 'uri'
require 'sqlite3'
require 'sequel'

ADMIN_KEY = "aKR1-\\\\u5"
DC = Sequel.connect("sqlite://datacent.sql")
DC.create_table? :visits do
	String	:ip
	String	:timestamp
	String	:lang
	String	:word
	String	:answer
	String	:correct
end
DC.create_table? :contributions do
	String	:id
	String	:word
	String	:answer
	String	:lang
end
DB = Sequel.connect("sqlite://database.sql")
DB.create_table? :words do
	String	:word
	String	:answer
	String	:lang
end

URL = ''
enable :sessions
set :server, 'webrick'
set :erb, :layout => :_default
set :port, 2575

get '/start' do
	session['score'] = nil
	erb :start
end
get '/play' do
	query = DB.from(:words).where(:lang => params['lang'].to_s).all
	if query.empty?
		query = DB.from(:words).all
	end
	question = query.sample
	answers = []
	until answers.length == 4
		(4).times do |time|
			if time > 0
				answers.push query.sample[:answer]
			else
				answers.push question[:answer]
			end
		end
		answers = answers.uniq
	end
	answers = answers.shuffle
	if session['score'].nil?
		session['score'] = 0
	end
	session['answer'] = question[:answer]
	erb :play, :locals => {
		:question => question,
		:answers => answers
	}
end
get '/check' do
	if session['score'].nil?
		redirect URL+'/start'
	else
		query = DB.from(:words).where(:lang => params['lang'], :word => params['word'], :answer => params['answer']).all
		DC.from(:visits).insert({
			:ip => request.ip,
			:timestamp => "i" + (Time.now.to_i).to_s,
			:correct => query.empty?.to_s,
			:lang => params['lang'],
			:word => params['word'],
			:answer => params['answer']
		})
		if session['word'] != params['word']
			session['word'] = params['word']
			if query.empty?
				session['score'] = session['score'] - 1
				erb :answer_wrong, :layout => :_empty, :locals => {:answer => session['answer']}
			else
				session['score'] = session['score'] + 1
				erb :answer_right, :layout => :_empty, :locals => {:answer => session['answer']}
			end
		else
			session['score'] = session['score'] - 1
			erb :answer_wrong, :layout => :_empty, :locals => {:answer => session['answer']}
		end
	end
end
get '/time' do
	if session['score'].nil?
		redirect URL+'/start'
	else
		session['score'] = session['score'] - 1
		erb :answer_timeout, :layout => :_empty, :locals => {:answer => session['answer']}
	end
end
get '/suggest' do
	erb :suggest
end
get '/contribute' do
	word = params['word']
	answer = params['answer']
	lang = params['lang']
	if lang.nil? or answer.nil? or lang.nil?
	else
		DC.from(:contributions).insert({
			:id => "i" + (rand * 8999999999999 + 1000000000000).to_s,
			:word => word,
			:answer => answer,
			:lang => lang
		})
	end
	erb :suggest
end
get '/review' do
	if session.key? 'auth'
		erb :review
	else
		redirect URL+'/login'
	end
end
get '/login' do
	erb :login
end

# API pathway.
get '/authorize' do
	puts params['key'].inspect + " to " + ADMIN_KEY.inspect
	if params['key'].eql? ADMIN_KEY
		session['auth'] = true
		redirect URL+'/review'
	else
		redirect URL+'/login'
	end
end
get '/approve' do
	if session.key? 'auth'
		contribs = DC.from(:contributions).where(:id => params['id']).all
		contribs.each do |contrib|
			DB.from(:words).insert({
				:word => contrib[:word],
				:answer => contrib[:answer],
				:lang => contrib[:lang]
			})
			
		end
		DC.from(:contributions).where(:id => params['id']).delete
		redirect URL+'/review'
	else
		redirect URL+'/login'
	end
end
get '/reject' do
	if session.key? 'auth'
		DC.from(:contributions).where(:id => params['id']).delete
		redirect URL+'/review'
	else
		redirect URL+'/login'
	end
end
get '/' do
	redirect URL+'/start'
end
not_found do
	erb :notfound
end