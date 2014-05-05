class Message < EmailArchiveBase

  @@per_page = 25

  cattr_reader :per_page

  has_many   :recipients,  primary_key: 'id',          foreign_key: 'message_id'
  belongs_to :employee,    primary_key: 'ID'
  belongs_to :entity,      primary_key: 'EntityID'
  belongs_to :file_email,  primary_key: 'message_id',  foreign_key: 'id'

  def self.search(params = {})
    # TODO
  end

  # This is a container class used to hold a collection of SearchClause
  # instances or just "clauses" that are peers, meaning they are combined using
  # the same logical operator (-OR- or -AND-) and are optionally negated as a
  # whole group.
  #
  # The group must have at least two members to be legit. Groups may also hold
  # other groups in addition to or in place of clauses.
  #
  class ClauseGroup

    def initialize(*members_and_options)
      options   = {}
      options   = members_and_options.pop if members_and_options.last.is_a?(Hash)
      @negated  = false
      @operator = :or
      @members  = []
      if options[:operator]
        raise ArgumentError, "invalid clause group operator: #{options[:operator]}" unless [:or, :and].include?(options[:operator])
        @operator = options[:operator]
      end
      @negated = true if options[:negated] or options[:negate] or options[:not]
      add(members_and_options)
    end

    def add(*members)
      members.flatten.each do |m|
        raise ArgumentError, "invalid clause type: #{m.class}" unless m.is_a?(ClauseGroup) or m.is_a?(SearchClause)
        @members << m
      end
    end

    attr_reader :negated, :operator
    def negated? ; @negated          end
    def or?      ; @operator == :or  end
    def and?     ; @operator == :and end

    def clause
      tmp = @members.map { |m| m.clause }.compact
      return nil if tmp.empty?
      return tmp.first unless tmp.length > 1 or @negated
      tmp = tmp.join(" #{@operator.to_s.upcase} ")
      "#{@negated ? "NOT " : ""}(#{tmp})"
    end
  end

  # This is the base class for all the following "search clause" helper classes
  # that are used by callers of the Message.search method to define their search
  # conditions.
  #
  class SearchClause

    def initialize(table, column, value, negate = false)
      raise ArgumentError, "table isn't a class object: #{table.class}"                unless table.is_a?(Class)
      raise ArgumentError, "table isn't an ActiveRecord::Base derived class: #{table}" unless table.ancestors.include?(ActiveRecord::Base)
      raise ArgumentError, "column isn't an ActiveRecord::ConnectionAdapters::Column " +
                           "instance: #{column.class}" unless column.is_a?(ActiveRecord::ConnectionAdapters::Column)
      @table   = table
      @column  = column
      @value   = value.dup rescue value
      @negated = !!negate
    end

    # get string form of this single search clause
    def clause
      raise "#{self.class} hasn't yet implemented the #clause method"
    end

    attr_reader :table, :column, :value, :negated
    def negated? ; @negated end
    def field
      c = @table.connection
      "#{c.quote_table_name(@table.table_name)}.#{c.quote_column_name(@column.name)}"
    end

    private

    def quote(str, col = nil)
      col ? @table.connection.quote(str, col) : @table.connection.quote(str)
    end
  end

  #
  # This is a base class that describes all search clauses that match against a
  # boolean data field (VB-style MySQL: -1 == true, 0 is false). The provided
  # value may be nil, true, or false. All other values will be converted to
  # true.
  #
  # You may optionally set the second, optional parameger "negate" to true to
  # negate the meaning of the expression. Since booleans are really tri-state
  # fields, allowing for true, false, and NULL, this allows you to have more
  # control (all non-true values include both NULL and false, etc.)
  #
  class BoolClause < SearchClause

    def initialize(table, column, value, negate = false)
      value = !!value unless value.nil?
      super(table, column, value, negate)
    end

    def clause
      if @value.nil?
        "#{field} IS #{@negated ? "NOT " : ""}NULL"
      else
        "#{field} #{@negated ? "<>" : "="} #{@value ? "-1" : "0"}"
      end
    end

  end

  #
  # This is a base class that describes all search clauses that match against a
  # numeric data field. The provided value may be nil or a numeric value.
  #
  # The optional options hash further defines what kind of search clause we're
  # dealing with. The default, if not explicitely specified by options in the
  # options hash, is one of the following (depending on the provided value):
  #
  # value == nil     => check if field is NULL
  # value == Numeric => check if field equals the specified number
  #
  # The following options, if provided in the optional options hash have the
  # following effect:
  #
  #   :not              => boolean : whether to negate meaning of clause
  #   :negate           => synonym for :not
  #   :negated          => synonym for :not
  #   :less             => boolean : match where field <  value
  #   :greater          => boolean : match where field >  value
  #   :equal            => boolean : match where field  = value
  #   :less_or_equal    => boolean : match where field <= value
  #   :greater_or_equal => boolean : match where field >= value
  #   :between          => numeric : match where field on or between values
  #
  class NumericClause < SearchClause

    def initialize(table, column, value, options = nil)
      value = value.to_i if value.is_a?(String) and value =~ /^-?\d+$/
      raise ArgumentError, "search clause for numeric field isn't a number: #{value.class}" unless value.is_a?(Numeric) or value.nil?
      @equal     = true  # include where field equals value
      @less      = false # include where field is less than value
      @greater   = false # include where field is greater than value
      @range     = nil   # include where field w/in numeric range (inclusive)
      negated    = false
      options  ||= {}
      negated    = options[:negated] if options.has_key?(:negated)
      negated    = options[:negate ] if options.has_key?(:negate )
      negated    = options[:not    ] if options.has_key?(:not    )
      super(table, column, value, negated)
      raise ArgumentError, "no number provided while attempting to create range clause" if @value.nil? and options[:between]
      if options[:equal]
        # no-op, just override other possible settings
      elsif options[:between]
        raise ArgumentError, "search clause for numeric 'between' value isn't a number: #{options[:between].class}" unless
          options[:between].is_a?(Numeric)
        initialize_range(@value, options[:between])
      elsif options[:less]
        @equal   = false
        @less    = true
      elsif options[:greater]
        @equal   = false
        @greater = true
      elsif options[:less_or_equal]
        @less    = true
      elsif options[:greater_or_equal]
        @greater = true
      end
    end

    attr_reader :equal, :less, :greater, :range
    def less?             ; @value and !@equal and !@range and  @less               end
    def greater?          ; @value and !@equal and !@range and             @greater end
    def equal?            ; @value and  @equal and !@range and !@less and !@greater end
    def less_or_equal?    ; @value and  @equal and !@range and  @less               end
    def greater_or_equal? ; @value and  @equal and !@range and             @greater end
    def range?            ; @value and         !!@range                             end
    def blank?            ; @value.nil?                                             end

    def clause
      if blank?
        "#{field} IS #{@negated ? "NOT " : ""}NULL"
      elsif range?
        "#{field} #{@negated ? "NOT " : ""}BETWEEN #{@value} AND #{@range}"
      else # equality comparison
        "#{field} #{equal_sign} #{@value}"
      end
    end

    private
    def initialize_range(x, y)
      @equal = false
      if x < y
        @value = x
        @range = y
      else
        @value = y
        @range = x
      end
    end
    def equal_sign
      if equal?
        @negated ? "<>" : "="
      else
        ((@negated ^ @greater) ? ">" : "<") + ((@negated ^ @equal) ? "=" : "")
      end
    end
  end

  #
  # This is a base class that describes all search clauses that match against a
  # string data field. The provided pattern is assumed to be a tainted, user-
  # supplied match string or the special value nil.
  #
  # The optional options hash further defines what kind of search clause we're
  # dealing with. The default, if not explicitely specified by options in the
  # options hash, is one of the following (depending on the value of pattern):
  #
  # pattern == nil   => check if field is blank (IS NULL -or- = "")
  # pattern == ""    => check if field is empty string (= "")
  # pattern == "txt" => check if field contains provided text (LIKE "%txt%")
  #
  # Pattern matches are case-insensitive by default. The following options, if
  # provided in the optional options hash have the following effect:
  #
  #   :not         => boolean : whether to negate meaning of clause (or not)
  #   :negate      => synonym for :not
  #   :negated     => synonym for :not
  #   :contains    => boolean : force pattern-matching check
  #   :equals      => boolean : force equality check
  #   :sensitive   => boolean : force comparison to be case-(in)sensitive
  #
  class StringClause < SearchClause

    ESCAPE = "\\".freeze # the escape character we'll use in sql "LIKE" clauses

    def initialize(table, column, pattern, options = nil)
      raise ArgumentError, "search clause for string field isn't a string: #{pattern.class}" unless pattern.nil? or pattern.is_a?(String)
      @sensitive = false # case-insensitive searching by default
      @contains  = true  # do pattern-matching by default
      @blank     = false # don't do simple check if field is "blank" by default
      negated    = false
      options  ||= {}
      negated    = options[:negated] if options.has_key?(:negated)
      negated    = options[:negate ] if options.has_key?(:negate )
      negated    = options[:not    ] if options.has_key?(:not    )
      super(table, column, pattern, negated)
      if pattern.nil?
        @blank = true
      elsif pattern == ""
        @contains = false
      else
        @sensitive = true  if options[:sensitive]
        @contains  = false if options[:equals] or (options.has_key?(:contains) and !options[:contains])
      end
    end

    def pattern ; @value end
    attr_reader :sensitive, :contains, :blank
    def sensitive? ;  @sensitive end
    def contains?  ;  @contains  end
    def equals?    ; !@contains  end
    def blank?     ;  @blank     end

    def clause
      if @blank
        "(#{field} IS #{@negated ? "NOT NULL AND" : "NULL OR"} #{field} #{equal_sign} #{quote("")})"
      elsif @contains
        "#{field} #{@negated ? "NOT " : ""}LIKE #{@sensitive ? "BINARY " : ""}#{contained_value} ESCAPE #{quote(ESCAPE)}"
      else # equality match
        "#{field} #{equal_sign} #{equaled_value}"
      end
    end

    private
    def contained_value
      quote("%#{@value.gsub(/([%_#{Regexp::escape(ESCAPE)}])/) { "#{ESCAPE}#{$1}" }}%", @column)
    end
    def equaled_value
      quote(@value, @column)
    end
    def equal_sign
      @negated ? "<>" : (@sensitive ? @table.connection.case_sensitive_equality_operator : "=")
    end
  end

  #
  # This is a base class that describes all search clauses that match against a
  # DATETIME or TIMESTAMP field. The supplied timestamp "ts" is assumed to be a
  # Time or DateTime instance or nil.
  #
  # The optional options hash further defines what kind of search clause we're
  # dealing with. The default, if not explicitely specified by options in the
  # options hash, is one of the following (depending on the value of "ts"):
  #
  # ts == nil        => check if field is NULL
  # ts == [Date]Time => check if field equals the specified timestamp
  #
  # The following options, if provided in the optional options hash have the
  # following effect:
  #
  #   :not          => boolean : whether to negate meaning of clause (or not)
  #   :negate       => synonym for :not
  #   :negated      => synonym for :not
  #   :before       => boolean : match where field <  ts
  #   :after        => boolean : match where field >  ts
  #   :on           => boolean : match where field  = ts
  #   :on_or_before => boolean : match where field <= ts
  #   :on_or_after  => boolean : match where field >= ts
  #   :between      => [Date]Time : match where field on or between ts and value
  #   :minute / :hour / :day / :week / :month / :year
  #                 => boolean : these are shorthand for defining a time range
  #                    where the provided ts is within the time range of the
  #                    specified size; matches where field also w/in range
  #
  class TimeClause < SearchClause

    def initialize(table, column, ts, options = nil)
      raise ArgumentError, "search clause for datetime field isn't a Time or DateTime: #{ts.class}" unless ts.nil? or ts.is_a?(Time) or ts.is_a?(DateTime)
      @on        = true  # include where field equals ts
      @before    = false # include where field is before ts
      @after     = false # include where field is after ts
      @range     = nil   # include where field w/in time range (inclusive)
      negated    = false
      options  ||= {}
      negated    = options[:negated] if options.has_key?(:negated)
      negated    = options[:negate ] if options.has_key?(:negate )
      negated    = options[:not    ] if options.has_key?(:not    )
      super(table, column, ts ? ts.to_datetime : nil, negated)
      raise ArgumentError, "no [Date]Time provided while attempting to create range clause" if @value.nil? and (
        options[:between] or options[:minute] or options[:hour] or options[:day] or
        options[:week]    or options[:month]  or options[:year]
        )
      if options[:on]
        # no-op, just override other possible settings
      elsif options[:between]
        raise ArgumentError, "search clause for datetime 'between' value isn't a Time or DateTime: #{options[:between].class}" unless
          options[:between].is_a?(Time) or options[:between].is_a?(DateTime)
        initialize_range(@value, options[:between].to_datetime)
      elsif options[:minute]
        initialize_range(@value.ago(@value.sec), @value.in(60 - @value.sec - 1))
      elsif options[:hour]
        initialize_range(@value.ago(@value.min * 60 + @value.sec), @value.in((60 - @value.min - 1) * 60 + (60 - @value.sec - 1)))
      elsif options[:day]
        initialize_range(@value.beginning_of_day, @value.end_of_day)
      elsif options[:week]
        initialize_range(@value.beginning_of_week, @value.end_of_week.end_of_day)
      elsif options[:month]
        initialize_range(@value.beginning_of_month, @value.end_of_month.end_of_day)
      elsif options[:year]
        initialize_range(@value.beginning_of_year, @value.end_of_year.end_of_day)
      elsif options[:before]
        @on     = false
        @before = true
      elsif options[:after]
        @on     = false
        @after  = true
      elsif options[:on_or_before]
        @before = true
      elsif options[:on_or_after]
        @after  = true
      end
    end

    def ts ; @value end
    attr_reader :on, :before, :after, :range
    def before?       ; @value and !@on and !@range and  @before             end
    def after?        ; @value and !@on and !@range and               @after end
    def on?           ; @value and  @on and !@range and !@before and !@after end
    def on_or_before? ; @value and  @on and !@range and  @before             end
    def on_or_after?  ; @value and  @on and !@range and               @after end
    def range?        ; @value and         !!@range                          end
    def blank?        ; @value.nil?                                          end

    def clause
      if blank?
        "#{field} IS #{@negated ? "NOT " : ""}NULL"
      elsif range?
        "#{field} #{@negated ? "NOT " : ""}BETWEEN #{quote(@value, @column)} AND #{quote(@range, @column)}"
      else # equality comparison
        "#{field} #{equal_sign} #{quote(@value, @column)}"
      end
    end

    private
    def initialize_range(x, y)
      @on = false
      if x < y
        @value = x
        @range = y
      else
        @value = y
        @range = x
      end
    end
    def equal_sign
      if on?
        @negated ? "<>" : "="
      else
        ((@negated ^ @after) ? ">" : "<") + ((@negated ^ @on) ? "=" : "")
      end
    end
  end

  #
  # Describes a search clause against the "subject" field of an email message
  #
  class Subject < StringClause
    def initialize(pattern, contains = true)
      super(table, column, pattern, options)
      raise ArgumentError, "subject search pattern isn't a string: #{pattern.class}" unless pattern.is_a?(String)
      super(pattern)
      @pattern  = pattern.dup.freeze
      @contains = !!contains
    end
    attr_reader :pattern, :contains
  end

  #
  # Describes search condition for either a sub-string, equality, or blank-ness
  # (NULL or ""). Blankness is checked when pattern is nil. If pattern is ""
  # then only the empty string will be explicitely searched for.
  #
  class Attachments
    def initialize(pattern, contains = true)
      raise ArgumentError, "attachment(s) search pattern not nil or a string" unless pattern.nil? or pattern.is_a?(String)
      raise ArgumentError, "attachment(s) search pattern nil when 'contains' is true" if pattern.nil? and contains
      @pattern  = pattern.nil? ? nil : pattern.dup.freeze
      @contains = !!contains
    end
    attr_reader :pattern, :contains
    def blank?
      @pattern.nil?
    end
  end

  #
  # Just describes search condition of equality
  #
  class MsgId
    def initialize(pattern)
      raise ArgumentError, "message id search pattern not a string" unless pattern.is_a?(String)
      @pattern = pattern.dup.freeze
    end
    attr_reader :pattern
  end

  #
  # Just describes search condition of equality
  #
  class MD5
    def initialize(pattern)
      raise ArgumentError, "md5 search pattern not a string" unless pattern.is_a?(String)
      @pattern = pattern.dup.freeze
    end
    attr_reader :pattern
  end
end
