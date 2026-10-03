require "rails_helper"
require "rake"

RSpec.describe "users rake tasks" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("users:create") }

  def run(task, *args, stdin: "")
    Rake::Task[task].reenable
    allow($stdin).to receive_messages(tty?: false, gets: stdin)
    expect { Rake::Task[task].invoke(*args) }.to output.to_stdout
  end

  it "creates a user with a piped password and changes it, rotating the session" do
    run("users:create", "me@example.com", stdin: "a-long-password\n")
    user = User.find_by!(email: "me@example.com")
    expect(user.valid_password?("a-long-password")).to be(true)

    old_jti = user.jti
    run("users:set_password", "me@example.com", stdin: "another-long-one\n")
    expect(user.reload.valid_password?("another-long-one")).to be(true)
    expect(user.jti).not_to eq(old_jti)
  end

  it "refuses a short password" do
    Rake::Task["users:create"].reenable
    allow($stdin).to receive_messages(tty?: false, gets: "short\n")

    expect { Rake::Task["users:create"].invoke("me@example.com") }.to raise_error(SystemExit)
    expect(User.find_by(email: "me@example.com")).to be_nil
  end
end
