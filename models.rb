configure :test, :development do
  DataMapper.setup(:default, 'postgres://postgres:postgres@localhost/countrtest')
end

configure :production do
  DataMapper.setup(:default, 'postgres://postgres:postgres@localhost/countr')
end

DataMapper::Model.raise_on_save_failure = true

class Account
  include DataMapper::Resource
  property :id, Serial
  property :type, Integer, :default => 0 #0 - free, 1-payment
  property :paiduntil, Date
  
  has n, :users
  has n, :homes
end

class Home
  include DataMapper::Resource
  property :id, Serial
  property :title, String, :length => 500
  property :address, String, :length => 500
  
  has n, :channels
  has n, :counters
  belongs_to :account, :required => true
end

class User
  include DataMapper::Resource
  include BCrypt
  property :id, Serial
  property :name, String, :length => 2..50, :format => /^[а-яА-ЯёЁa-zA-Z- ]+$/,
    :messages => {
      :length  => "Имя пользователя должно быть от 2 и до 50 символов",
      :format  => "Имя пользователя может содержать только буквы и пробел"
    }
  property :email, String, :format => :email_address, :unique => true, :required => true,
    :messages => {
      :presence  => "Введите адрес электронной почты",
      :is_unique => "Данный адрес электронной почты уже зарегистрирован",
      :format    => "Неверный формат электронной почты"
    }
  property :password, BCryptHash
  property :phone, String, :format => /^((8|\+7)\d{10}$)/,
    :messages => {
      :format  => "Неверный формат мобильного номера. Номер должен начинатся с +7 или 8 и затем содержать 10 цифр"
    }
  property :lastlogon, DateTime

  has 1, :profile
  belongs_to :account, :required => true

  def authenticate(attempted_password)
    if self.password == attempted_password
      true
    else
      false
    end
  end
end

class Profile
  include DataMapper::Resource
  property :id, Serial
  property :created_at, DateTime, :default => DateTime.now
  property :active, Boolean, :default  => true
  property :sendnotification, Boolean
  property :notificationdate, DateTime
  property :notificationtype, String
  property :notificationemail, String, :format => :email_address,
    :messages => {
      :format    => "Неверный формат электронной почты"
    }
  property :notificationsms, String, :format => /^((8|\+7)\d{10}$)/,
    :messages => {
      :format  => "Неверный формат мобильного номера. Номер должен начинатся с +7 или 8 и затем содержать 10 цифр"
    }
  property :timezone, String
  property :editindication, Boolean, :default  => false
  property :resendindication, Boolean, :default  => false

  belongs_to :user, :required => true

  def notificationdateinlocaltime
    self.notificationdate.new_offset(self.timezone.to_i/24.0)
  end

  def notificationto
    case self.notificationtype
    when "sms"
      return self.notificationsms
    when "email"
      return self.notificationemail
    end
  end
end

class Channel
  include DataMapper::Resource
  property :id, Serial
  property :title, String, :length => 500
  property :type, String
  property :email, String, :format => :email_address,
    :messages => {
      :format  => "Неверный формат электронной почты"
    }
  property :phone, String, :format => /^((8|\+7)\d{10}$)/,
    :messages => {
      :format  => "Неверный формат мобильного номера. Номер должен начинатся с +7 или 8 и затем содержать 10 цифр"
    }
  property :pattern, Text
  property :emailtomyself, Boolean, :default  => false
  property :lastsenddate, DateTime
  
  def to
    case self.type
    when "sms"
      return self.phone
    when "email"
      return self.email
    end
  end

  def sentinthismonth
    startmonth = Date.new Date.today.year, Time.now.month, 1
    endmonth = startmonth >> 1
    if self.lastsenddate == nil
      return false
    elsif self.lastsenddate < startmonth
      return false
    else
      return true
    end
  end

  has n, :counters, :through => Resource
  belongs_to :home
end


class Counter
  include DataMapper::Resource
  property :id, Serial
  property :title, String, :length => 500, :required => true
  property :type, Integer, :required => true #11 - cold water, 12 - hot water, 20 - gas, 30 - electricity, 31 - electricity (one), 32 - electricity (two), 33 - electricity (three)
  property :account, String, :length => 500, :required => false, :format => /^\d+$/,
    :messages => {
      :format  => "Лицевой счет может содержать только цифры"
    }

  has n, :indications
  belongs_to :home, :required => true
  #belongs_to :channel, :required => false
  has n, :channels, :through => Resource

  def typestr
    case self.type
    when 11
      return "ХВС"
    when 12
      return "ГВС"
    when 20
      return "Газоснабжение"
    when 30
      return "Электроснабжение"
    when 31
      return "ЭЛЕКТРИЧЕСТВО (T1)"
    when 32
      return "ЭЛЕКТРИЧЕСТВО (Т2)"
    when 33
      return "ЭЛЕКТРИЧЕСТВО (Т3)"
    end
  end

  def currentindication
    startmonth = Date.new Date.today.year, Time.now.month, 1
    endmonth = startmonth >> 1
    indication = self.indications.all(:period => startmonth..endmonth)
    if indication.count == 0
      return nil
    else
      return indication[0]
    end
  end

  def allindications
    return self.indications.all
  end
end

class Indication
  include DataMapper::Resource
  property :id, Serial
  property :period, Date
  property :value, Integer, :format => /^\d+$/,
    :messages => {
      :format  => "Неверный формат значения счетчика. Введите целое число"
    }
  property :submited, Boolean, :default  => false

  belongs_to :counter
end

class ResetPasswords
  include DataMapper::Resource
  include BCrypt
  
  property :id, Serial
  property :email, String, :required => true, :format => :email_address,
    :messages => {
      :format => "Некорректный формат электронной почты",
      :presence => "Обязательно укажите адрес электронной почты"
    }
  property :myhash, BCryptHash
  property :td, DateTime
end

DataMapper.finalize
#DataMapper.auto_migrate! #recreate all table COUNTR.IO
DataMapper.auto_upgrade! #try to upgrade models COUNTR.IO

if User.count == 0
  admin = User.new(
    :email => "admin@countr.io",
    :password => "Neverfoget1",
    :name => "Администратор",
    :account => Account.new(),
    :profile => Profile.new()
    )
  begin
    admin.save
    puts "ADMIN WAS CREATED!\n"
  rescue
    puts admin.errors.values.join("; ")
  end
end