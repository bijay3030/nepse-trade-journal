# Accounts are created here, not through a public sign-up. Passwords are typed at a
# hidden prompt (or piped in), never passed as arguments that land in shell history.
namespace :users do
  def read_password(prompt)
    if $stdin.tty?
      require "io/console"
      print prompt
      password = $stdin.noecho(&:gets).to_s.chomp
      puts
      password
    else
      $stdin.gets.to_s.chomp
    end
  end

  def ask_new_password
    password = read_password("New password (at least 10 characters): ")
    abort "Password must be at least 10 characters" if password.length < 10
    abort "Passwords don't match" if $stdin.tty? && read_password("Repeat password: ") != password
    password
  end

  desc "Create a user. Usage: bin/rails 'users:create[me@example.com]'"
  task :create, [ :email ] => :environment do |_t, args|
    abort "Usage: bin/rails 'users:create[me@example.com]'" if args[:email].blank?
    user = User.create!(email: args[:email], password: ask_new_password, jti: SecureRandom.uuid)
    puts "Created #{user.email}"
  end

  desc "Set a user's password (signs them out everywhere). Usage: bin/rails 'users:set_password[me@example.com]'"
  task :set_password, [ :email ] => :environment do |_t, args|
    user = User.find_by!(email: args[:email])
    user.update!(password: ask_new_password, jti: SecureRandom.uuid)
    puts "Password updated for #{user.email}"
  end

  desc "Change a user's email. Usage: bin/rails 'users:rename[old@example.com,new@example.com]'"
  task :rename, %i[from to] => :environment do |_t, args|
    user = User.find_by!(email: args[:from])
    user.update!(email: args[:to])
    puts "Renamed to #{user.email}"
  end

  desc "List users"
  task list: :environment do
    User.order(:id).each { puts "#{_1.id}\t#{_1.email}" }
  end
end
