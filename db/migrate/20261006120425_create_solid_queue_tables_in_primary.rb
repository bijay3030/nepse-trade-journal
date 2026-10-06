# Solid Queue's tables in the primary database, for hosting on a single database
# (DATABASE_URL): the queue then needs no database of its own. Taken from
# db/queue_schema.rb, which still sets up the separate queue database elsewhere.
class CreateSolidQueueTablesInPrimary < ActiveRecord::Migration[8.0]
  def up
    return if table_exists?(:solid_queue_jobs)

    schema = Rails.root.join("db/queue_schema.rb").read
    body = schema[/\.define\(version: [\d_]+\) do\n(.*)\nend\s*\z/m, 1] or raise "Couldn't read db/queue_schema.rb"
    instance_eval(body.gsub(", force: :cascade", ""))
  end

  def down
    tables.select { _1.start_with?("solid_queue_") }.each { drop_table _1, force: :cascade }
  end
end
