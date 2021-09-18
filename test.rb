require 'bcrypt'

pass = BCrypt::Password.create('secret')

p pass