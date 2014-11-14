# encoding: utf-8
require 'rubygems'
require 'bundler'
require 'sinatra'
require 'haml'
#require 'omniauth-gplus'
require 'data_mapper'
require 'bcrypt'
require 'pony'
require 'json'
require 'warden'
#require 'sinatra/r18n'
require 'russian'

require './models.rb'

class CountrIOApp < Sinatra::Application
  configure do
    set :logging, true
    #ENV['TZ'] = 'Europe/Moscow'
    #set :root, File.dirname(__FILE__)
    use Rack::Session::Cookie, :key => "rack.session", :expire_after => 31557600, :secret => "supasecretphrasefotcountrio"
    I18n.default_locale = :ru
    I18n.enforce_available_locales = false
  end

  Pony.options = {
    :from => 'Countr.IO <robot@countr.io>',
    :charset => 'utf-8',
    :via => :sendmail
  }

  use OmniAuth::Builder do
    provider :gplus, '2030779216-coi7emsv6c5kir3msr7m35nj5sojm7kt.apps.googleusercontent.com', 'YlLCQTrsEexKFfciIfgQRZM7', :redirect_uri => '/auth/gplus/callback'
    #provider :att, 'client_id', 'client_secret', :callback_url => (ENV['BASE_DOMAIN'] 
  end

  use Warden::Manager do |config|
    config.failure_app = self
    config.serialize_into_session{|user| user.id }
    config.serialize_from_session{|id| User.get(id) }

    config.scope_defaults :default,
      strategies: [:password],
      action: '/auth/unauthenticated'
  
    config.scope_defaults :social,
      strategies: [:social],
      action: '/auth/unauthenticated'
  end

  Warden::Manager.before_failure do |env,opts|
    env['REQUEST_METHOD'] = 'POST'
  end

  Warden::Strategies.add(:password) do
    def valid?
      params[:login] && params[:password]
    end

    def authenticate!
      user = User.first(:email => params[:login])
      if user.nil?
        session[:messagetodisplay]= @@text["notifications"]["wronguserorpassword"]
      elsif user.authenticate(params[:login])
        begin
          user.update(:lastlogon => DateTime.now)
        rescue
          #puts "Error on logon time updating:", user.errors.values
        end
        success!(user)
        #puts "Авторизация по паролю!"
      else
        session[:messagetodisplay]= @@text["notifications"]["wronguserorpassword"]
      end
    end
  end
  
  Warden::Strategies.add(:social) do
    def authenticate!
      #puts "WARDEN SOCIAIL STRATEGY BEGINS"
      user = User.first(:email => env['omniauth.auth'][:info][:email])
      if user.nil?
        #puts "NO USER"
        session[:messagetodisplay]= @@text["notifications"]["wronguser"]
      else
        begin
          user.update(:lastlogon => DateTime.now)
        rescue
          #puts "Error on logon time updating:", user.errors.values
        end
        success!(user)
        #puts "WARDEN SOCIAIL STRATEGY WAS SUCCESSFULL :)"
      end
    end
  end

  @@text = YAML.load_file("public/texts.yml")
 
  helpers do
    def navbar
      haml_tag :nav, :class=>"tm-navbar uk-navbar uk-navbar-attached" do
        haml_tag :div, :class=>"uk-container uk-container-center" do
          haml_tag :div, :class=>"uk-navbar-flip" do
            haml_tag :ul, :class=>"uk-navbar-nav" do
              haml_tag :li do
                haml_tag :a, :href=>"/" do
                  haml_tag :i, :class=>"uk-icon-home"
                  haml_concat "Главная"
                end
              end
              if !logged_in?
                haml_tag :li do
                  haml_tag :a, :href=>"#wtf" do
                    haml_tag :i, :class=>"uk-icon-question-circle"
                    haml_concat "Что это и зачем?"
                  end
                end
                haml_tag :li do
                  haml_tag :a, :href=>"#happy" do
                    haml_tag :i, :class=>"uk-icon-thumbs-up"
                    haml_concat "Жить стало лучше!"
                  end
                end
                haml_tag :li do
                  haml_tag :a, :href=>"#price" do
                    haml_tag :i, :class=>"uk-icon-rub"
                    haml_concat "Стоимость"
                  end
                end
                haml_tag :li do
                  haml_tag :a, :href=>"#signin" do
                    haml_tag :i, :class=>"uk-icon-unlock-alt"
                    haml_concat "Войти или зарегистрироваться"
                  end
                end
              else
                haml_tag :li do
                  haml_tag :a, :href=>"/profile" do
                    haml_tag :i, :class=>"uk-icon-user"
                    haml_concat current_user.name
                  end
                end
                if !paid_account?
                  haml_tag :li do
                    haml_tag :a, :href=>"/upgrade", :class=>"highlighted" do
                      haml_tag :i, :class=>"uk-icon-arrow-up"
                      haml_concat "Купить полный функционал"
                    end
                  end
                end
                haml_tag :li do
                  haml_tag :a, :href=>"/logout" do
                    haml_tag :i, :class=>"uk-icon-sign-out"
                    haml_concat "Выход"
                  end
                end
              end
            end
          end
        end
      end
    end

    def brand
      haml_concat "Countr.IO"
    end

    def patternpanel
      @homes = []
      @counters = []
      current_user.account.homes.all.each do |h|
        @homes << h
      end
      haml_tag :ul do
        haml_tag :h3, :class=>"uk-text-bold" do
          haml_concat "Пользователь"
        end
        haml_tag :li do
          haml_tag :span, "data-uk-tooltip" => "", :title => current_user.name do
            haml_tag :code, :class=>"draggable" do
              haml_concat "ИМЯ_ПОЛЬЗОВАТЕЛЯ"
            end
          end
        end
      end
      haml_tag :hr
      haml_tag :ul do
        @homes.each_with_index do |h, i|
          haml_tag :h3, :class=>"uk-text-bold" do
            haml_concat "Помещение #{i+1}"
          end
          haml_tag :li do
            haml_tag :span, "data-uk-tooltip" => "", :title => h.title do
              haml_tag :code, :class=>"draggable" do
                haml_concat "ИМЯ_ПОМЕЩЕНИЯ_#{i+1}"
              end
            end
          end
          haml_tag :li do
            haml_tag :span, "data-uk-tooltip" => "", :title => h.address do
              haml_tag :code, :class=>"draggable" do
                haml_concat "АДРЕС_ПОМЕЩЕНИЯ_#{i+1}"
              end
            end
          end
          @c = h.counters.all
          @c.each do |counter|
            @counters << counter
          end
          haml_tag :p do
            haml_tag :h4, :class=>"uk-text-bold" do
              haml_concat "Счетчики"
            end
            @counters.each_with_index do |c, j|
              haml_tag :li do
                #haml_concat "Счетчик #{j+1}"
                haml_concat c.title + " (" + c.typestr + ")"
                haml_tag :ul do
                  haml_tag :li do
                    haml_tag :span, "data-uk-tooltip" => "", :title => c.title do
                      haml_tag :code, :class=>"draggable" do
                        haml_concat "НАЗВАНИЕ_СЧЕТЧИКА_#{i+1}_#{j+1}"
                      end
                    end
                  end
                end
                haml_tag :ul do
                  haml_tag :li do
                    haml_tag :span, "data-uk-tooltip" => "", :title => c.typestr do
                      haml_tag :code, :class=>"draggable" do
                        haml_concat "ТИП_СЧЕТЧИКА_#{i+1}_#{j+1}"
                      end
                    end
                  end
                end
                if c.type < 31
                  haml_tag :ul do
                    haml_tag :li do
                      haml_tag :span, "data-uk-tooltip" => "", :title => "В это поле будет подставляться показания счетчика" do
                        haml_tag :code, :class=>"draggable" do
                          haml_concat "ПОКАЗАНИЕ_СЧЕТЧИКА_#{i+1}_#{j+1}"
                        end
                      end
                    end
                  end
                else
                  (31..(c.type)).each do |cn|
                    tarif = cn - 30
                    haml_tag :ul do
                      haml_tag :li do
                        haml_tag :span, "data-uk-tooltip" => "", :title => "В это поле будет подставляться показания счетчика" do
                          haml_tag :code, :class=>"draggable" do
                            haml_concat "ПОКАЗАНИЕ_СЧЕТЧИКА_#{i+1}_#{j+1}_(ТАРИФ#{tarif})"
                          end
                        end
                      end
                    end
                  end
                end
                if c.account.size>0
                  haml_tag :ul do
                    haml_tag :li do
                      haml_tag :span, "data-uk-tooltip" => "", :title => c.account do
                        haml_tag :code, :class=>"draggable" do
                          haml_concat "ЛИЦЕВОЙ_СЧЕТ_СЧЕТЧИКА_#{i+1}_#{j+1}"
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
      haml_tag :hr
      haml_tag :ul do
        haml_tag :h3, :class=>"uk-text-bold" do
          haml_concat "Отчетный период"
        end
        haml_tag :li do
          haml_tag :span, "data-uk-tooltip" => "", :title => DateTime.now.strftime("%d.%m.%Y") do
            haml_tag :code, :class=>"draggable" do
              haml_concat "ТЕКУЩАЯ_ДАТА"
            end
          end
        end
        haml_tag :li do
          haml_tag :span, "data-uk-tooltip" => "", :title => Russian::strftime(DateTime.now, "%B") do
            haml_tag :code, :class=>"draggable" do
              haml_concat "ТЕКУЩИЙ_МЕСЯЦ"
            end
          end
        end
        haml_tag :li do
          haml_tag :span, "data-uk-tooltip" => "", :title => Russian::strftime(DateTime.now.prev_month, "%B") do
            haml_tag :code, :class=>"draggable" do
              haml_concat "ПРОШЛЫЙ_МЕСЯЦ"
            end
          end
        end
      end
    end

    def compare
      haml_tag :div, :class=>"uk-grid", "data-uk-grid-margin"=>"" do
        haml_tag :div, :class=>"uk-width-medium-1-1" do
          haml_tag :table, :class=>"uk-table" do
            haml_tag :tbody do
              haml_tag :tr, :class=>"uk-table-middle" do
                haml_tag :td, :class=>"uk-width-1-2" do
                  haml_concat "Неограниченное количество счетчиков"
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-check-square-o"
                  end
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center uk-badge-success" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-check-square-o"
                  end
                end
              end
              haml_tag :tr, :class=>"uk-table-middle" do
                haml_tag :td, :class=>"uk-width-1-2" do
                  haml_concat "Отправка показаний по email"
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-check-square-o"
                  end
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center uk-badge-success" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-check-square-o"
                  end
                end
              end
              haml_tag :tr, :class=>"uk-table-middle" do
                haml_tag :td, :class=>"uk-width-1-2" do
                  haml_concat "Получение напоминаний на email"
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-check-square-o"
                  end
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center uk-badge-success" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-check-square-o"
                  end
                end
              end
              haml_tag :tr, :class=>"uk-table-middle" do
                haml_tag :td, :class=>"uk-width-1-2" do
                  haml_concat "Отправка показаний по SMS"
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-square-o"
                  end
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center uk-badge-success" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-check-square-o"
                  end
                end
              end
              haml_tag :tr, :class=>"uk-table-middle" do
                haml_tag :td, :class=>"uk-width-1-2" do
                  haml_concat "Получение напоминаний по SMS"
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-square-o"
                  end
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center uk-badge-success" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-check-square-o"
                  end
                end
              end
              haml_tag :tr, :class=>"uk-table-middle" do
                haml_tag :td, :class=>"uk-width-1-2" do
                  haml_concat "Поддержка нескольких помещений"
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-square-o"
                  end
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center uk-badge-success" do
                  haml_tag :h2 do
                    haml_tag :i, :class=>"uk-icon-check-square-o"
                  end
                end
              end
              haml_tag :tr, :class=>"uk-table-middle" do
                haml_tag :td, :class=>"uk-width-1-2" do
                  haml_concat "Стоимость"
                end
                haml_tag :td, :class=>"uk-width-1-4" do
                  haml_tag :h2, :class=>"uk-text-center" do
                    haml_concat "БЕСПЛАТНО"
                  end
                end
                haml_tag :td, :class=>"uk-width-1-4 uk-text-center uk-badge-success" do
                  haml_tag :h2 do
                    haml_concat "10 руб. в месяц"
                  end
                  haml_tag :span do
                    haml_concat "или"
                  end
                  haml_tag :h2 do
                    haml_concat "100 руб. в год"
                  end
                end
              end
            end
          end
        end
      end
    end

    def clearflashmessage
      session[:messagetodisplay] = nil
    end

    def current_user
      if env['warden'].authenticated?
        @current_user = env['warden'].user
        return @current_user
      end
    end

    def current_account
      if env['warden'].authenticated?
        @current_user = env['warden'].user
        @current_account = Account.get(@current_user.account_id)
        return @current_account
      end
    end

    def logged_in?
      current_user
    end

    def paid_account?
      if current_user.account.type == 1
        return true
      else
        return false
      end
    end

    def decodepattern(pattern, mode)
      patterns = ["{ИМЯ_ПОЛЬЗОВАТЕЛЯ}", "{ИМЯ_ПОМЕЩЕНИЯ}", "{АДРЕС_ПОМЕЩЕНИЯ}", "{НАЗВАНИЕ_СЧЕТЧИКА}", "{ТИП_СЧЕТЧИКА}", "{ПОКАЗАНИЕ_СЧЕТЧИКА}", "{ЛИЦЕВОЙ_СЧЕТ_СЧЕТЧИКА}", "{ТЕКУЩАЯ_ДАТА}", "{ТЕКУЩИЙ_МЕСЯЦ}", "{ПРОШЛЫЙ_МЕСЯЦ}"]
      patterns.each do |p|
        case p
        when "{ИМЯ_ПОЛЬЗОВАТЕЛЯ}"
          pattern.gsub!("{ИМЯ_ПОЛЬЗОВАТЕЛЯ}", current_user.name)
        when "{ИМЯ_ПОМЕЩЕНИЯ}"
         pattern.scan(/{ИМЯ_ПОМЕЩЕНИЯ_\d+}/).each do |t|
           n = t.scan(/\d+/)[0].to_i
           h = current_user.account.homes.all
           pattern.gsub!(t, h[n-1].title)
         end
        when "{АДРЕС_ПОМЕЩЕНИЯ}"
         pattern.scan(/{АДРЕС_ПОМЕЩЕНИЯ_\d+}/).each do |t|
           n = t.scan(/\d+/)[0].to_i
           h = current_user.account.homes.all
           pattern.gsub!(t, h[n-1].address)
         end
        when "{НАЗВАНИЕ_СЧЕТЧИКА}"
         pattern.scan(/{НАЗВАНИЕ_СЧЕТЧИКА_\d+_\d+}/).each do |t|
           nh = t.scan(/\d+/)[0].to_i
           nc = t.scan(/\d+/)[1].to_i
           h = (current_user.account.homes.all)[nh-1]
           c = (h.counters.all)[nc-1]
           pattern.gsub!(t, c.title)
         end
        when "{ТИП_СЧЕТЧИКА}"
         pattern.scan(/{ТИП_СЧЕТЧИКА_\d+_\d+}/).each do |t|
           nh = t.scan(/\d+/)[0].to_i
           nc = t.scan(/\d+/)[1].to_i
           h = (current_user.account.homes.all)[nh-1]
           c = (h.counters.all)[nc-1]
           pattern.gsub!(t, c.typestr)
         end
        when "{ПОКАЗАНИЕ_СЧЕТЧИКА}"
         error = 1
         meters = pattern.scan(/{ПОКАЗАНИЕ_СЧЕТЧИКА_\d+_\d+}|{ПОКАЗАНИЕ_СЧЕТЧИКА_\d+_\d+_\(ТАРИФ\d+\)}/)
         if meters.size != 0
           error = 0
           meters.each do |t|
             numbers = t.scan(/\d+/)
             nh = numbers[0].to_i
             nc = numbers[1].to_i
             nt = numbers[2].to_i
             h = (current_user.account.homes.all)[nh-1]
             c = (h.counters.all)[nc-1]
             if mode == "test"
               pattern.gsub!(t, "##")
             else
               indications = c.indications.all(:submited => false)
               if indications.count == 0
                 val = "##"
               else
                 val = indications[-1].value
               end
               pattern.gsub!(t, val.to_s)
             end
           end
         end
         # meters = pattern.scan(/{ПОКАЗАНИЕ_СЧЕТЧИКА_\d+_\d+_\(ТАРИФ\d+\)}/)
         # if meters.size != 0
         #   error = 0
         #   meters.each do |t|
         #     numbers = t.scan(/\d+/)
         #     nh = numbers[0].to_i
         #     nc = numbers[1].to_i
         #     nt = numbers[2].to_i
         #     h = (current_user.account.homes.all)[nh-1]
         #     c = (h.counters.all)[nc-1]
         #     if mode == "test"
         #       pattern.gsub!(t, "##")
         #     else
         #       pattern.gsub!(t, "#REALVALUE")
         #     end
         #   end
         # end
         if error == 1
           pattern = "СООБЩЕНИЕ НЕ СОДЕРЖИТ ПОКАЗАНИЯ СЧЕТЧИКОВ! ПРОВЕРЬТЕ ФОРМАТ ШАБЛОНА!\n\n" + pattern
         end
        when "{ЛИЦЕВОЙ_СЧЕТ_СЧЕТЧИКА}"
         pattern.scan(/{ЛИЦЕВОЙ_СЧЕТ_СЧЕТЧИКА_\d+_\d+}/).each do |t|
           nh = t.scan(/\d+/)[0].to_i
           nc = t.scan(/\d+/)[1].to_i
           h = (current_user.account.homes.all)[nh-1]
           c = (h.counters.all)[nc-1]
           pattern.gsub!(t, c.account)
         end
        when "{ТЕКУЩАЯ_ДАТА}"
          pattern.gsub!("{ТЕКУЩАЯ_ДАТА}", DateTime.now.strftime("%d.%m.%Y"))
        when "{ТЕКУЩИЙ_МЕСЯЦ}"
          pattern.gsub!("{ТЕКУЩИЙ_МЕСЯЦ}", Russian::strftime(DateTime.now, "%B"))
        when "{ПРОШЛЫЙ_МЕСЯЦ}"
          pattern.gsub!("{ПРОШЛЫЙ_МЕСЯЦ}", Russian::strftime(DateTime.now.prev_month, "%B"))
        end
      end
      return pattern
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end

  end  # END OF HELPERS

  get '/' do
    if logged_in?
      @user = current_user
      @profile = @user.profile
      @account = @user.account
      @environment = Hash.new
      #@homes = current_user.account.homes.all
      @account.homes.all.each do |h|
        @environment[h] = {}
      end
      if @environment.size > 0
        err = 1
        @environment.each_key do |h|
          @channels = h.channels.all
          @counters = h.counters.all
          @environment[h][:channels] = @channels
          @environment[h][:counters] = @counters
          if @environment[h][:channels].size > 0
            err = 0
          end
          @channels.each do |ch|
            @countersinchannel = ch.counters.all
          end
        end
        #hh = @env.keys[0]
        #puts @env, "****************"
        #puts hh.title, @env[hh][:channels][0].pattern, @env[hh][:counters][0].type
        #puts @env
        #puts "BEFORE DISPLAYING PROFILE"
        if err == 1
          haml :plsaddchannels
        else
          haml :home
        end
      else
        haml :plssetup
      end
    else
      haml :index
    end
  end


  get '/setup' do
    if logged_in?
      if current_user.account.homes.all.count == 0
        haml :setup
      else
        haml :configure
      end
    else
      session[:messagetodisplay] = @@text["notifications"]["plslogin"]
      redirect '/'
    end
  end
  
  post '/setup' do
    ##puts params.keys
    @user = current_user
    @home = current_user.account.homes.new(:title => params[:homename], :address => params[:homeaddress])
    z = 1
    @counters = []
    params.keys.map do |c|
      if c.start_with?("countername")
        t = "countertype" + z.to_s
        a = "counteraccount" + z.to_s
        #puts ">>>", params[c.to_sym], params[t.to_sym], params[a.to_sym], "<<<"
        counter = @home.counters.new(:title => params[c.to_sym], :type => params[t.to_sym], :account => params[a.to_sym])
        @counters << counter
        z+=1
      end
    end
    begin
      @home.save
    rescue
      #puts "ERRORS IN SAVING HOME AND COUNTERS"
      session[:messagetodisplay] = @home.errors.values.join("; ")
      redirect '/setup'
    else
      #puts "HOME AND COUNTERS WERE SAVED"
      #session[:messagetodisplay] = @@text["notifications"]["homeandcountersweresaved"]
      #@homes = current_user.account.homes.all
      if logged_in?
        haml :configure
      else
        session[:messagetodisplay] = @@text["notifications"]["plslogin"]
        redirect '/'
      end
    end
  end
  
  post '/configure' do
    z = 1
    params.keys.map do |p|
      if p.start_with?("channelpattern")
        pattern = params[p.to_sym]
        meters = pattern.scan(/{ПОКАЗАНИЕ_СЧЕТЧИКА_\d+_\d+}/)
        if meters.size == 0
          session[:messagetodisplay] = @@text["notifications"]["badpattern"]
        else
          meters.each do |t|
            nh = t.scan(/\d+/)[0].to_i
            nc = t.scan(/\d+/)[1].to_i
            h = (current_user.account.homes.all)[nh-1]
            c = (h.counters.all)[nc-1]
            t = "channeltype" + z.to_s
            n = "channelname" + z.to_s
            e = "channelemail" + z.to_s
            s = "channelsms" + z.to_s
            case params[t.to_sym]
            when "sms"
              #puts ">SMS>", params[n.to_sym], params[t.to_sym], params[s.to_sym], params[p.to_sym], "<SMS<"
              channel = h.channels.first_or_new(:title=>params[n.to_sym], :type=>"sms", :phone=>params[s.to_sym], :pattern=>h(params[p.to_sym]))
            when "email"
              #puts ">EMAIL>", params[n.to_sym], params[t.to_sym], params[e.to_sym], params[p.to_sym], "<EMAIL<"
              channel = h.channels.first_or_new(:title=>params[n.to_sym], :type=>"email", :email=>params[e.to_sym], :pattern=>h(params[p.to_sym]))
            end
            begin
              #puts "TRYING TO ADD COUNTER", c, "TO", channel
              channel.counters << c
              #puts "TRYING TO SAVE CHANNEL"
              channel.save
            rescue 
              session[:messagetodisplay] = channel.errors.values.join("; ")
              redirect '/setup'
            else
              #puts "CHANNEL WAS SAVED"
            end
          end
        end
        z+=1
      end
    end
    p = current_user.profile
    if params[:notificationtype] == "sms"
      nday = params[:notificationdate].to_i
      nmonth = DateTime.now.month
      nyear = DateTime.now.year
      nhour = params[:notificationtime].to_i
      ntz = params[:notificationtimezone]
      ndatetime = DateTime.new(nyear, nmonth, nday, nhour, 0, 0, ntz)
      puts ndatetime
      p.attributes = {:sendnotification=>true, :notificationsms=>params[:notificationsms], :notificationdate=>ndatetime.to_time, :notificationtype=>params[:notificationtype], :timezone=>ntz}
    elsif params[:notificationtype] == "email"
      nday = params[:notificationdate].to_i
      nmonth = DateTime.now.month
      nyear = DateTime.now.year
      nhour = params[:notificationtime].to_i
      ntz = params[:notificationtimezone]
      ndatetime = DateTime.new(nyear, nmonth, nday, nhour, 0, 0, ntz)
      p.attributes = {:sendnotification=>true, :notificationemail=>params[:notificationemail], :notificationdate=>ndatetime.to_time, :notificationtype=>params[:notificationtype], :timezone=>ntz}
      puts ndatetime
    end
    begin
      p.save
    rescue
      session[:messagetodisplay] = p.errors.values.join("; ")
    else
      #puts "NOTIFICATION WAS SAVED"
      session[:messagetodisplay] = @@text["notifications"]["setupfinished"]
      #puts "BEFORE CALLING /PROFILE"
      redirect '/profile'
    end
  end  

  get '/profile' do
    if logged_in?
      @user = current_user
      @profile = @user.profile
      @account = @user.account
      @environment = Hash.new
      #@homes = current_user.account.homes.all
      @account.homes.all.each do |h|
        @environment[h] = {}
      end
      if @environment.size > 0
        @environment.each_key do |h|
          @channels = h.channels.all
          @counters = h.counters.all
          @environment[h][:channels] = @channels
          @environment[h][:counters] = @counters
          @channels.each do |ch|
            @countersinchannel = ch.counters.all
          end
        end
        #hh = @env.keys[0]
        #puts @env, "****************"
        #puts hh.title, @env[hh][:channels][0].pattern, @env[hh][:counters][0].type
        #puts @env
        #puts "BEFORE DISPLAYING PROFILE"
        haml :profile
      else
        haml :plssetup
      end
    else
      session[:messagetodisplay] = @@text["notifications"]["plslogin"]
      redirect '/'
    end
  end

  get '/home/new' do
    if logged_in?
      @user = current_user
      @profile = @user.profile
      @account = @user.account
      if paid_account?
        haml :newhome
      else
        haml :plsupgrade
      end
    else
      session[:messagetodisplay] = @@text["notifications"]["plslogin"]
      redirect '/'
    end
  end

  post '/home/new' do
    @home = current_user.account.homes.new(:title => params[:homename], :address => params[:homeaddress])
    begin
      @home.save
    rescue
      session[:messagetodisplay] = @home.errors.values.join("; ")
      redirect '/setup'
    else
      if logged_in?
        redirect '/profile'
      else
        session[:messagetodisplay] = @@text["notifications"]["plslogin"]
        redirect '/'
      end
    end
  end

  delete '/home/:home/delete' do
    user = current_user
    account = user.account
    home = account.homes.all[params[:home].to_i-1]
    counters = home.counters.all
    channels = home.channels.all
    channels.each do |ch|
      ch.counters.all.each do |c|
        link = ChannelCounter.get(ch.id, c.id)
        link.destroy
      end
      ch.destroy
    end
    counters.each do |c|
      indications = c.indications.all
      indications.destroy
    end
    counters.destroy
    channels.destroy
    if home.destroy
      session[:messagetodisplay] = @@text["notifications"]["homewasdeleted"]
    else
      session[:messagetodisplay] = @@text["notifications"]["homewasnotdeleted"]
    end
    #redirect '/profile'
  end
  
  get '/home/:home/counter/new' do
    if logged_in?
      @user = current_user
      @profile = @user.profile
      @account = @user.account
      @home = @account.homes.all[params[:home].to_i-1]
      if @home
        @home_index = params[:home].to_i
        haml :newcounter
      else
        session[:messagetodisplay] = @@text["notifications"]["error"]
        redirect '/profile'
      end
    else
      session[:messagetodisplay] = @@text["notifications"]["plslogin"]
      redirect '/'
    end
  end

  post '/home/:home/counter/new' do
    @user = current_user
    @profile = @user.profile
    @account = @user.account
    @home = @account.homes.all[params[:home].to_i-1]
    #puts @home
    z = 1
    params.keys.map do |c|
      if c.start_with?("countername")
        t = "countertype" + z.to_s
        a = "counteraccount" + z.to_s
        counter = @home.counters.new(:title => params[c.to_sym], :type => params[t.to_sym], :account => params[a.to_sym])
        @home.counters << counter
        puts "***", counter
        z+=1
      end
    end
    begin
      puts @home
      @home.save
    rescue
      session[:messagetodisplay] = @@text["notifications"]["error"]
      redirect '/profile'
    else
      if logged_in?
        redirect '/profile'
      else
        session[:messagetodisplay] = @@text["notifications"]["plslogin"]
        redirect '/'
      end
    end
  end
  
  delete '/home/:home/counter/:counter/delete' do
    user = current_user
    account = user.account
    home = account.homes.all[params[:home].to_i-1]
    counter = home.counters.all[params[:counter].to_i-1]
    counter.indications.all.destroy
    channels = counter.channels.all
    channels.each do |ch|
      link = ChannelCounter.get(ch.id, counter.id)
      link.destroy
      ch.destroy
    end
    indications = counter.indications.all
    indications.destroy
    if counter.destroy
      session[:messagetodisplay] = @@text["notifications"]["counterwasdeleted"]
    else
      session[:messagetodisplay] = @@text["notifications"]["counterwasnotdeleted"]
    end
    #redirect '/profile'
  end
  
  get '/home/:home/channel/new' do
    if logged_in?
      @user = current_user
      @profile = @user.profile
      @account = @user.account
      @home = @account.homes.all[params[:home].to_i-1]
      if @home
        @home_index = params[:home].to_i
        haml :newchannel
      else
        session[:messagetodisplay] = @@text["notifications"]["error"]
        redirect '/profile'
      end
    else
      session[:messagetodisplay] = @@text["notifications"]["plslogin"]
      redirect '/'
    end
  end

  post '/home/:home/channel/new' do
    z = 1
    params.keys.map do |p|
      if p.start_with?("channelpattern")
        pattern = params[p.to_sym]
        meters = pattern.scan(/{ПОКАЗАНИЕ_СЧЕТЧИКА_\d+_\d+}|{ПОКАЗАНИЕ_СЧЕТЧИКА_\d+_\d+_\(ТАРИФ\d+\)}/)
        if meters.size == 0
          session[:messagetodisplay] = @@text["notifications"]["badpattern"]
        else
          meters.each do |t|
            nh = t.scan(/\d+/)[0].to_i
            nc = t.scan(/\d+/)[1].to_i
            nt = t.scan(/\d+/)[3].to_i
            h = (current_user.account.homes.all)[nh-1]
            c = (h.counters.all)[nc-1]
            t = "channeltype" + z.to_s
            n = "channelname" + z.to_s
            e = "channelemail" + z.to_s
            s = "channelsms" + z.to_s
            case params[t.to_sym]
            when "sms"
              #puts ">SMS>", params[n.to_sym], params[t.to_sym], params[s.to_sym], params[p.to_sym], "<SMS<"
              channel = h.channels.first_or_new(:title=>params[n.to_sym], :type=>"sms", :phone=>params[s.to_sym], :pattern=>h(params[p.to_sym]))
            when "email"
              #puts ">EMAIL>", params[n.to_sym], params[t.to_sym], params[e.to_sym], params[p.to_sym], "<EMAIL<"
              channel = h.channels.first_or_new(:title=>params[n.to_sym], :type=>"email", :email=>params[e.to_sym], :pattern=>h(params[p.to_sym]))
            end
            begin
              #puts "TRYING TO ADD COUNTER", c, "TO", channel
              channel.counters << c
              #puts "TRYING TO SAVE CHANNEL"
              channel.save
            rescue 
              session[:messagetodisplay] = channel.errors.values.join("; ")
              redirect '/setup'
            else
              #puts "CHANNEL WAS SAVED"
            end
          end
        end
        z+=1
      end
    end
    redirect '/profile'
  end

  delete '/home/:home/channel/:channel/delete' do
    user = current_user
    account = user.account
    home = account.homes.all[params[:home].to_i-1]
    channel = home.channels.all[params[:channel].to_i-1]
    counters = home.counters.all(:channel => channel)
    counters.each do |c|
      link = ChannelCounter.get(channel.id, c.id)
      link.destroy
    end
    if channel.destroy
      session[:messagetodisplay] = @@text["notifications"]["channelwasdeleted"]
    else
      session[:messagetodisplay] = @@text["notifications"]["channelwasnotdeleted"]
    end
  end

  post '/nameupdate' do
    content_type :json
    user = current_user
    user.attributes = {:name=>params[:value]}
    begin
      user.save
    rescue
      f={:success=>false, :msg=>user.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Имя пользователя успешно обновлено"}
      f.to_json
    end
  end

  post '/hometitleupdate' do
    content_type :json
    user = current_user
    account = user.account
    home = account.homes.all[params[:pk].to_i-1]
    home.attributes = {:title=>params[:value]}
    begin
      home.save
    rescue
      f={:success=>false, :msg=>home.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Наименование помещения успешно обновлено"}
      f.to_json
    end
  end

  post '/homeaddressupdate' do
    content_type :json
    user = current_user
    account = user.account
    home = account.homes.all[params[:pk].to_i-1]
    home.attributes = {:address=>params[:value]}
    begin
      home.save
    rescue
      f={:success=>false, :msg=>home.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Адрес помещения успешно обновлен"}
      f.to_json
    end
  end

  post '/home/:home/countertitleupdate' do
    content_type :json
    user = current_user
    account = user.account
    home = account.homes.all[params[:home].to_i-1]
    counter = home.counters.all[params[:pk].to_i-1]
    counter.attributes = {:title=>params[:value]}
    begin
      counter.save
    rescue
      f={:success=>false, :msg=>counter.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Наименование счетчика успешно обновлено"}
      f.to_json
    end
  end

  post '/home/:home/countertypeupdate' do
    content_type :json
    user = current_user
    account = user.account
    home = account.homes.all[params[:home].to_i-1]
    counter = home.counters.all[params[:pk].to_i-1]
    counter.attributes = {:type=>params[:value]}
    begin
      counter.save
    rescue
      f={:success=>false, :msg=>counter.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Тип счетчика успешно обновлен"}
      f.to_json
    end
  end

  post '/home/:home/counteraccountupdate' do
    content_type :json
    user = current_user
    account = user.account
    home = account.homes.all[params[:home].to_i-1]
    counter = home.counters.all[params[:pk].to_i-1]
    counter.attributes = {:account=>params[:value]}
    begin
      counter.save
    rescue
      f={:success=>false, :msg=>counter.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Лицевой счет счетчика успешно обновлен"}
      f.to_json
    end
  end

  post '/home/:home/channeltitleupdate' do
    content_type :json
    user = current_user
    account = user.account
    home = account.homes.all[params[:home].to_i-1]
    channel = home.channels.all[params[:pk].to_i-1]
    channel.attributes = {:title=>params[:value]}
    begin
      channel.save
    rescue
      f={:success=>false, :msg=>channel.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Наименование канала успешно обновлено"}
      f.to_json
    end
  end

  post '/home/:home/channelreceiverupdate' do
    content_type :json
    user = current_user
    account = user.account
    home = account.homes.all[params[:home].to_i-1]
    channel = home.channels.all[params[:pk].to_i-1]
    if channel.type == 'sms'
      channel.attributes = {:phone=>params[:value]}
    else
      channel.attributes = {:email=>params[:value]}
    end
    begin
      channel.save
    rescue
      f={:success=>false, :msg=>channel.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Получатель успешно обновлен"}
      f.to_json
    end
  end

  post '/notificationtypeupdate' do
    content_type :json
    p = current_user.profile
    if params[:value] == 'sms'
      p.attributes = {:notificationtype=>params[:value], :notificationemail=>nil}
    elsif params[:value] == 'email'
      p.attributes = {:notificationtype=>params[:value], :notificationsms=>nil}
    end
    begin
      p.save
    rescue
      f={:success=>false, :msg=>p.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true}
      if params[:value] == 'sms'
        session[:messagetodisplay] = "Способ передачи уведомлений успешно обновлен. Укажите мобильный номер получателя уведомлений"
        #f={:success=>true, :msg=>"Способ передачи уведомлений успешно обновлен. Укажите мобильный номер получателя уведомлений"}
      elsif params[:value] == 'email'
        session[:messagetodisplay] = "Способ передачи уведомлений успешно обновлен. Укажите адрес электронной почты получателя уведомлений"
        #f={:success=>true, :msg=>"Способ передачи уведомлений успешно обновлен. Укажите адрес электронной почты получателя уведомлений"}
      end
      f.to_json
      #redirect '/profile'
    end
  end

  post '/notificationtoupdate' do
    content_type :json
    p = current_user.profile
    if p.notificationtype == 'sms'
      p.attributes = {:notificationsms=>params[:value]}
    elsif p.notificationtype == 'email'
      p.attributes = {:notificationemail=>params[:value]}
    end
    begin
      p.save
    rescue
      f={:success=>false, :msg=>p.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Получатель уведомлений успешно обновлен"}
      f.to_json
    end
  end

  post '/notificationdateupdate' do
    content_type :json
    p = current_user.profile
    nday = params[:value].to_i
    nmonth = p.notificationdateinlocaltime.month
    nyear = p.notificationdateinlocaltime.year
    nhour = p.notificationdateinlocaltime.hour
    ntz = p.timezone
    ndatetime = DateTime.new(nyear, nmonth, nday, nhour, 0, 0, ntz)
    p.attributes = {:notificationdate=>ndatetime.to_time}
    begin
      p.save
    rescue
      f={:success=>false, :msg=>p.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Дата отправки уведомлений успешно обновлена"}
      f.to_json
    end
  end

  get '/setnotification' do
    if logged_in?
      haml :newnotification
    else
      session[:messagetodisplay] = @@text["notifications"]["plslogin"]
      redirect '/'
    end
  end

  post '/setnotification' do
    p = current_user.profile
    if params[:notificationtype] == "sms"
      nday = params[:notificationdate].to_i
      nmonth = DateTime.now.month
      nyear = DateTime.now.year
      nhour = params[:notificationtime].to_i
      ntz = params[:notificationtimezone]
      ndatetime = DateTime.new(nyear, nmonth, nday, nhour, 0, 0, ntz)
      puts ndatetime
      p.attributes = {:sendnotification=>true, :notificationsms=>params[:notificationsms], :notificationdate=>ndatetime.to_time, :notificationtype=>params[:notificationtype], :timezone=>ntz}
    elsif params[:notificationtype] == "email"
      nday = params[:notificationdate].to_i
      nmonth = DateTime.now.month
      nyear = DateTime.now.year
      nhour = params[:notificationtime].to_i
      ntz = params[:notificationtimezone]
      ndatetime = DateTime.new(nyear, nmonth, nday, nhour, 0, 0, ntz)
      p.attributes = {:sendnotification=>true, :notificationemail=>params[:notificationemail], :notificationdate=>ndatetime.to_time, :notificationtype=>params[:notificationtype], :timezone=>ntz}
      puts ndatetime
    end
    begin
      p.save
    rescue
      session[:messagetodisplay] = p.errors.values.join("; ")
    else
      session[:messagetodisplay] = @@text["notifications"]["notificationwassaved"]
      redirect '/profile'
    end
  end

  
  post '/home/:home/counter/:counter/setvalue' do
    content_type :json
    account = current_user.account
    home = account.homes.all[params[:home].to_i-1]
    counter = home.counters.all[params[:counter].to_i-1]
    startmonth = Date.new Date.today.year, Time.now.month, 1
    endmonth = startmonth >> 1
    indications = counter.indications.all(:period => startmonth..endmonth)
    if indications.count == 0
      puts "NO INDICATION WAS BEFORE"
      counter.indications.new(:period => Date.today, :value => params[:value])
      begin
        counter.save
      rescue
        f={:success=>false, :msg=>counter.errors.values.join("; ")}
        f.to_json
      else
        f={:success=>true, :msg=>"Показание счетчика записано, но не отправлено"}
        f.to_json
      end
    else
      puts "THERE IS INDICATION"
      indication = indications[0]
      if indication.submited == true
        puts "AND IT WAS SUBMITED"
        #f={:success=>false, :msg=>"Нельзя изменить уже переданное значение счетчика"}
        #f.to_json
        halt 200, {'Content-Type' => 'application/json'}, '{"success":false, "msg":"Нельзя изменить уже переданное значение счетчика"}'
      else
        puts "AND IT WAS NOT SUBMITED"
        indication.attributes = {:period => Date.today, :value => params[:value]}
        begin
          indication.save
        rescue
          f={:success=>false, :msg=>indication.errors.values.join("; ")}
          f.to_json
        else
          f={:success=>true, :msg=>"Показание счетчика обновлено, но не отправлено"}
          f.to_json
        end
      end
    end
  end

  post '/notificationtimeupdate' do
    content_type :json
    p = current_user.profile
    nday = p.notificationdateinlocaltime.day
    nmonth = p.notificationdateinlocaltime.month
    nyear = p.notificationdateinlocaltime.year
    nhour = params[:value].to_i
    ntz = p.timezone
    ndatetime = DateTime.new(nyear, nmonth, nday, nhour, 0, 0, ntz)
    puts "WAS >>>", p.notificationdateinlocaltime
    puts "WILL BE >>>", ndatetime
    p.attributes = {:notificationdate=>ndatetime.to_time}
    begin
      p.save
    rescue
      f={:success=>false, :msg=>p.errors.values.join("; ")}
      f.to_json
    else
      f={:success=>true, :msg=>"Время отправки уведомлений успешно обновлено"}
      f.to_json
    end
  end

  get '/home/:home/channel/:channel/updatepattern' do
    if logged_in?
      account = current_user.account
      home = account.homes.all[params[:home].to_i-1]
      channel = home.channels.all[params[:channel].to_i-1]
      @channelpattern = channel.pattern
      @home_index = params[:home]
      @channel_index = params[:channel]
      haml :updatechannelpattern
    else
      session[:messagetodisplay] = @@text["notifications"]["plslogin"]
      redirect '/'
    end
  end

  post '/home/:home/channel/:channel/updatepattern' do
    account = current_user.account
    home = account.homes.all[params[:home].to_i-1]
    channel = home.channels.all[params[:channel].to_i-1]
    channel.attributes = {:pattern=>h(params[:channelpattern])}
    begin
      channel.save
    rescue
      session[:messagetodisplay] = channel.errors.values.join("; ")
    else
      session[:messagetodisplay] = "Шаблон сообщения успешно обновлен"
    end
    redirect '/profile'
  end

  post '/auth/login' do
    env['warden'].authenticate!(:password)
    redirect '/profile'
  end

  get '/auth/:provider/callback' do
    auth = request.env['omniauth.auth']
    ##puts auth[:info][:first_name], auth[:info][:last_name], auth[:info][:email]
    if !User.first(:email=>auth[:info][:email])
      user = User.new(
        :email => auth[:info][:email],
        :name => auth[:info][:first_name] + " " + auth[:info][:last_name],
        :profile => Profile.new(),
        :account => Account.new(:type=>0))
      begin
        user.save
      rescue
        #puts "ERROR!!!! USER WAS NOT CREATED"
        session[:messagetodisplay] = user.errors.values.join("; ")
        redirect '/'
      else
        #puts "USER WAS CREATED"
        session[:messagetodisplay] = @@text["notifications"]["reguser"]
        env['warden'].authenticate!(:social)
        redirect '/setup'
      end
    else
      #puts "USER ALREADY EXISTS"
      env['warden'].authenticate!(:social)
      redirect '/profile'
    end
  end

  ["/sign_out/?", "/signout/?", "/log_out/?", "/logout/?"].each do |path|
    get path do
      env['warden'].logout
      #puts "LOGOUT!!!"
      session[:user_id] = nil
      session[:messagetodisplay] = @@text["notifications"]["logout"]
      redirect '/'
    end
  end

  get '/auth/failure' do
    redirect '/'
  end

  get '/auth/unauthenticated' do
    redirect '/'
  end

  post '/ajax/checkemail' do
    if params[:email].nil?
      '"Введите адрес электронной почты"'
    elsif User.first(:email=>params[:email])
      '"Данный адрес электронной почты уже зарегистрирован"'
    else
      "true"
    end
  end
  
  post '/ajax/checkname' do
    if params[:name].nil?
      '"Введите полное имя"'
    elsif (params[:name].match(/^[а-яА-ЯёЁa-zA-Z- ]+$/)).nil?
      '"Имя может содержать только буквы"'
    else
      "true"
    end
  end

  post '/ajax/checkphone' do
    params.keys.map do |c|
      if c.start_with?("channelsms")
        if params[c.to_sym].nil?
          '"Введите мобильный телефонный номер"'
        elsif (params[c.to_sym].match(/^((8|\+7)\d{10}$)/)).nil?
          '"Номер должен начинатся с +7 или 8 и затем содержать 10 цифр"'
        else
          "true"
        end
       end
    end
  end

  post '/ajax/checkphone2' do
    if params[:notificationsms].nil?
      '"Введите мобильный телефонный номер"'
    elsif (params[:notificationsms].match(/^((8|\+7)\d{10}$)/)).nil?
      '"Номер должен начинатся с +7 или 8 и затем содержать 10 цифр"'
    else
      "true"
    end
  end


  post '/ajax/testpattern' do
    decodepattern(params[:pattern], "test")
  end

  post '/ajax/testpattern2' do
    account = current_user.account
    channel = Channel.get(params[:channelid].to_i)
    decodepattern(channel.pattern, "real")
  end

  get '/test' do
    ndatetime = current_user.profile.notificationdate
    puts ndatetime.class, ndatetime, ndatetime.zone
    puts "******"
    puts ndatetime.to_time.utc
  end
  
end # END OF APP CLASS