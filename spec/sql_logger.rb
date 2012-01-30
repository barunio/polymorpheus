module Polymorpheus
  module SqlLogger

    def sql_statements
      @sql_statements ||= []
    end

    def clear_sql_history
      @sql_statements = nil
    end

    private

    def execute(sql, name = nil)
      sql_statements << sql
      sql
    end

  end
end

