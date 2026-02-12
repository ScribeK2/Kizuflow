# Shared utility for negating workflow conditions.
# Used by WorkflowGraphConverter and WorkflowParsers::BaseParser.
module ConditionNegation
  # Negate a condition string by swapping == and != operators.
  # For other operators, wraps with NOT logic.
  def negate_condition(condition)
    return nil if condition.blank?

    if condition.include?('==')
      condition.gsub('==', '!=')
    elsif condition.include?('!=')
      condition.gsub('!=', '==')
    else
      "!(#{condition})"
    end
  end
end
