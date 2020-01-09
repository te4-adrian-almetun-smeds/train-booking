# frozen_string_literal: true

require 'sqlite3'

# A class handeling a databse object
class DBHandler # rubocop:disable Metrics/ClassLength
  attr_accessor :table, :tables
  # Initializes a new database handler and provices all arguments
  def initialize(db_path = nil)
    @db = if db_path.nil?
            connect('db/data.db')
          else
            connect(db_path)
          end
    @table = @@table unless defined?(@@table).nil?
    @table ||= self.class
    @tables = @@tables unless defined?(@@tables).nil?
    @tables ||= nil
  end

  #########################################################
  # PUBLIC METHODS
  # CONFIGURING / SET UP

  # Configures what to join and on what
  # Class wide
  
  # Class wide
  # Sets table
  def self.SET_TABLE(string)
    @@table = string
  end
  
  # Class wide
  # Sets joins
  def self.HAS_MANY(*tables)
    @@tables = tables
  end

  
  # Instance specific
  # Sets joins
  def has_many(*tables)
    @tables = tables
  end
  
  # Instance specific
  # Sets table
  def self.table(table)
    @table = table
  end

  # Connects to the database
  #
  # If a db already excists then return it
  #
  # Returns a database objekt
  def connect(path)
    @db ||= SQLite3::Database.new(path)
    @db.results_as_hash = true
    @db
  end
  ######################
  # FETCHING/UPDATING/INSERTING/CREATING

  # Acts as manager for construction of SQL queries
  #
  # Returns nothing - But it sends the data to the object constructor
  def self.sql_operator!(args)
    args = args.first
    join = ''
    where = ''
    selects = 'SELECT'
    values = []
    if args[:table].is_a? Array
      if args[:table].length > 1
        raise 'Only one table can be selected'
      else
        args[:table] = args[:table][0]
      end
  # Fetches all entries given a table (Alternative)
  def all
    fetch_all
  end

  # Fetches all entries given a table
  def fetch_all
    sql_operator(
      table: @table,
      join: @tables
    )
  end

  def fetch_first(num = nil)
    if num.nil?
      sql_operator(
        table: @table,
        join: @tables,
        limit: 1
      )
    else
      sql_operator(
        table: @table,
        join: @tables,
        limit: num
      )
    end
  end

  def fetch_last(num = nil)
    if num.nil?
      sql_operator(
        table: @table,
        join: @tables,
        limit: -1
      )
    else
      sql_operator(
        table: @table,
        join: @tables,
        limit: -num
      )
    end
  end

  # Decides if the provided argument has to be processed before execution
  # Public for use in special sql queries
  def sql_operator(*args)
    if args.is_a? String
      # TODO: execute
    else
      sql_operator!(args)
    end
  end

  #########################################################
  # PRIVATE METHODS

  ######################
  # VALIDATORS

  # Validates table "query"
  #
  # arg - Data to validate
  #
  # Returns the table unless ther is an error
  private def validate_table_input(arg)
    raise 'A hash is not a valid input format for table' if arg.is_a? Hash

    if arg.is_a? Array
      raise 'Only one table can be selected' if arg.flatten.length > 1

      arg.flatten[0].to_s
    else
      arg.to_s
    end
  end

  # Constructs selects
  #
  # Returns selects as SQL - Query (Partial string)
  private def select_constructor(value, table)
    selects = 'SELECT'
    if value.is_a?(Symbol) || value.is_a?(String)
      selects = "SELECT #{value} FROM #{table}"
    else
      value.each do |item|
        item = item.to_s.gsub(/\s+/, '_')
        selects += " #{item} AS '#{item}',"
      end
      selects = selects[0..-2] + " FROM #{table}"
    end
    selects
  end

  # Constructs wheres
  #
  # Reutrns a Array containing wheres as SQL - Query (Partial String), and associated values
  private def where_constructor(value)
    where = ' WHERE '
    values = []
    if value.is_a? String
      wheres = value.split('=')
      wheres.each_with_index do |temp, index|
        where += "#{temp} = ?" unless index.odd?
        values << temp if index.odd?
      end
    elsif value.is_a? Hash
      keys = value.keys
      keys.each_with_index do |key, index|
        if value[key].is_a?(String) || value[key].is_a?(Integer) ||
           value[key].is_a?(Symbol) || !!value[key] == value[key] # Boolean?
          temp = value[key]
          temp = temp.to_s if temp.is_a? Symbol
          where += if index.zero?
                     " #{key} = ?"
                   else
                     " AND #{key} = ?"
                   end
          values << temp
        elsif value[key].is_a? Array
          temp = value[key]
          where += " #{key} IN ("
          temp.each_with_index do |sav, i|
            where += if i.zero?
                       '?'
                     else
                       ',?'
                     end
            values << sav
          end
          where += ')'
        end
      end
    elsif value.is_a? Array
      value.each_with_index do |value, i|
        wheres = value.split('=')
        wheres.each_with_index do |temp, index|
          if index.odd?
            values << temp
          else
            where += if i.zero?
                       "#{temp} = ?"
                     else
                       " AND #{temp} = ?"
                     end
          end
        end
      end
    end
    [where, values]
  end

  # Consstructs joins
  #
  # Returns joins as SQL - query (Partial String)
  private def join_constructor(joins, table, type = 'LEFT')
    sql_join = ''
    if joins.is_a? String
      sql_join = " #{type} JOIN #{joins}" if joins.downcase.include?('on')
    elsif joins.is_a? Array
      joins.each_with_index do |join, index|
        if join.is_a?(Array)
          sql_join += if joins.is_a? Hash
                        join_constructor(join, joins.keys[index])
                      else
                        join_constructor(join, table)
                      end
        elsif join.is_a? String
          sql_join += join_constructor(join, nil)
        elsif join.is_a? Hash
          if join.keys.length > 1
            join.keys.each do |key|
              if key.to_s.downcase.include?('connector')
                sql_join += " #{type} JOIN #{key} ON #{table}.id = #{key}.#{table}_id"
                sql_join += join_constructor(join[key], key)
                # THIS MIGHT NEED THE LAST JOIN STATEMENT FROM BELOW
              else
                sql_join += " #{type} JOIN #{key} ON #{table}.#{key}_id = #{key}.id"
                sql_join += join_constructor(join[key], key)
                if join[key].is_a? Symbol
                  sql_join += " #{type} JOIN #{join[key]} ON #{key}.#{join[key]}_id = #{join[key]}.id"
                end
              end
            end
          else
            sql_join += if join.keys[0].to_s.downcase.include?('connector')
                          " #{type} JOIN #{join.keys[0]} ON #{table}.id = #{join.keys[0]}.#{table}_id"
                        else
                          " #{type} JOIN #{join.keys[0]} ON #{table}.#{join.keys[0]}_id " \
                            "= #{join.keys[0]}.id"
                        end
            sql_join += join_constructor(join[join.keys[0]], join.keys[0])
          end
        else # A symbol perhaps?
          sql_join += if join.to_s.downcase.include?('connector')
                        " #{type} JOIN #{join} ON #{table}.id = #{join}.#{table}_id"
                      else
                        " #{type} JOIN #{join} ON #{table}.#{join}_id = #{join}.id"
                      end
        end
      end
    elsif joins.is_a? Symbol
      sql_join += if joins.to_s.downcase.include?('connector')
                    " #{type} JOIN #{joins} ON #{table}.id = #{joins}.#{table}_id"
                  else
                    " #{type} JOIN #{joins} ON #{table}.#{joins}_id = #{joins}.id"
                  end
    end
    sql_join
  end

  # Executes given sql code like SQLite3 gem
  #
  # sql - String (SQL code)
  # values - Array containing a list of values (optional)
  #
  # Returns sqlresult as hash
  private def execute(sql, *values)
    if values == []
      @db.execute(sql)
    elsif values[0].is_a? Array
      @db.execute(sql, values[0][0..-1])
    else
      @db.execute(sql, values[0..-1])
    end
  end

  def self.with_condition(table, conditions, values)
    execute("SELECT * FROM #{table} #{conditions}", values)
  end

  # Retrives all data from a given table
  #
  # Returns database values as hash
  def self.all(table)
    execute("SELECT * FROM #{table}")
  end

  # Retrives data from database table from row with given id
  #
  # table - String (Name of table)
  # id = String/Integer (id of row in db)
  #
  # Returns database values as hash
  def self.with_id(table, id)
    execute("SELECT * FROM #{table} WHERE id = ?", id).first
  end

  # Retrives the last row from a given table
  #
  # table - String (Name of table)
  # amount - Integer (Optional, number of rows to retrive)
  #
  # Returns database values as hash
  def self.last(table, amount = 1)
    execute("SELECT * FROM #{table} ORDER BY ID DESC LIMIT ?", amount)
  end

  # Writes an object into a given table
  #
  # table - String (Name of table)
  # object - Object to be written to table
  #
  # Returns the id of the new record (most of the time)
  def self.write_to_db(table, object)
    z = object.instance_variables
    q = []
    k = []
    # Returns values and their table
    z.each_with_index do |_, i|
      q << object.instance_variable_get(z[i])
      k << z[i].to_s.gsub('@', '')
    end
    k = k.to_s.gsub('[', '')
    k = k.to_s.gsub(']', '')

    # Handles generation of SQLInjection protection
    x = '?'
    if z.length > 1
      (z.length - 1).times do
        x += ',?'
      end
    end

    execute("INSERT INTO #{table} (#{k}) VALUES (#{x})", q)
    last(table)
  end

  def save(table = nil, options = nil)
    p options
    object = if options.nil? || options['object'].nil?
               self
             else
               options['object']
             end
    q = []
    k = []
    if options.nil? || options[:params].nil?
      z = object.instance_variables
      z.each_with_index do |_, i|
        q << object.instance_variable_get(z[i]) unless z[i].to_s.gsub('@', '') == 'id'
        k << z[i].to_s.gsub('@', '') unless z[i].to_s.gsub('@', '') == 'id'
      end
      q << object.id
    else
      options[:params].each do |param|
        q << param[:value]
        k << param[:key]
      end
    end
    u = ''
    k.each_with_index do |_, i|
      u += "#{k[i]} = ?,"
    end
    q << options[:id] if !options.nil? && !options[:params].nil?

    u = u.chomp(',')
    DBHandler.execute("UPDATE #{table} SET #{u} WHERE id = ?", q)
    # TODO: Can this be made to self.save or similar?
  end
end

DBHandler.object_constructor([{ potatis: 'hey', 'This.string.contains.periods': 23_412 }])

# DBHandler.sql_operator(
#   select: ['bookings.id'],
#   table: :bookings,
#   join: [services: ['platforms AS dep ON services.departure_id = dep.id', 'platforms AS arr ON services.arrival_id = arr.id'], booking_connector: [:tickets]]
# )
