module Groonga
  module ExpressionRewriters
    class AndOptimizer < ExpressionRewriter
      register "and_optimizer"

      def rewrite
        return nil if check_unsupported_code

        builder = ExpressionTreeBuilder.new(@expression)
        root_node = builder.build
        # p @expression

        variable = @expression[0]
        table = context[variable.domain]
        optimized_root_node = optimize_node(table, root_node)

        rewritten = Expression.create(table)
        optimized_root_node.build(rewritten)
        # p rewritten
        rewritten
      end

      private
      def check_unsupported_code
        unsupported = false
        stack = []
        codes = @expression.codes
        codes.each do |code|
          case code.op
          when Operator::NEAR, Operator::SIMILAR
            unsupported = true
          when Operator::PUSH
            case code.value
            when PatriciaTrie, VariableSizeColumn
              unsupported = true
            end
          end
        end
        unsupported
      end

      def optimize_node(table, node)
        case node
        when ExpressionTree::LogicalOperation
          optimized_sub_nodes = node.nodes.collect do |sub_node|
            optimize_node(table, sub_node)
          end
          case node.operator
          when Operator::AND
            optimized_sub_nodes =
              optimize_and_sub_nodes(table, optimized_sub_nodes)
          end
          ExpressionTree::LogicalOperation.new(node.operator,
                                               optimized_sub_nodes)
        when ExpressionTree::BinaryOperation
          optimized_left = optimize_node(table, node.left)
          optimized_right = optimize_node(table, node.right)
          if optimized_left.is_a?(ExpressionTree::Constant) and
              optimized_right.is_a?(ExpressionTree::Variable)
            ExpressionTree::BinaryOperation.new(node.operator,
                                                optimized_right,
                                                optimized_left)
          elsif node.left == optimized_left and node.right == optimized_right
            node
          else
            ExpressionTree::BinaryOperation.new(node.operator,
                                                optimized_left,
                                                optimized_right)
          end
        else
          node
        end
      end

      def node_estimate_size_for_query(node, query)
        case node
        when ExpressionTree::Variable
          estimated_costs = node.column.indexes.map do |info|
            info.index.estimate_size(query: query)
          end
          estimated_costs.max
        when ExpressionTree::Accessor
          estimated_costs = node.object.indexes.map do |info|
            info.index.estimate_size(query: query)
          end
          estimated_costs.max
        when ExpressionTree::IndexColumn
          node.object.estimate_size(query: query)
        when ExpressionTree::FunctionCall
          estimated_costs = node.arguments.map do |argument|
            node_estimate_size_for_query argument, query
          end
          estimated_costs.max
        else
          0
        end
      end

      def optimize_and_sub_nodes(table, sub_nodes)
        n_func = 0
        optimized_nodes = sub_nodes.sort_by do |node|
          estimated_cost = 0
          case node
          when ExpressionTree::BinaryOperation
            if node.right.is_a?(ExpressionTree::Constant)
              query = node.right.value
              if node.left.is_a?(ExpressionTree::Variable) and
                 node.left.column.is_a?(Expression)
                match_builder = ExpressionTreeBuilder.new(node.left.column)
                match_column_node = match_builder.build

                case match_column_node
                when ExpressionTree::LogicalOperation
                  estimated_costs = match_column_node.nodes.map do |node|
                    node_estimate_size_for_query(node, query)
                  end
                  estimated_cost = estimated_costs.max
                when ExpressionTree::BinaryOperation
                  estimated_cost = node_estimate_size_for_query(match_column_node.left, query)
                else
                  estimated_cost = node_estimate_size_for_query(match_column_node, query)
                end
              else
                estimated_cost = node_estimate_size_for_query(node.left, query)
              end
            end
          when ExpressionTree::FunctionCall
            estimated_cost = ID::MAX + n_func
            n_func += 1
          end
          if estimated_cost > 0
            estimated_cost
          else
            node.estimate_size(table)
          end
        end
      end
    end
  end
end
