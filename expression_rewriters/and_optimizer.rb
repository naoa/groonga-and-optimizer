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
          when Operator::NEAR, Operator::NEAR_NO_OFFSET, Operator::NEAR_PHRASE, Operator::ORDERED_NEAR_PHRASE, Operator::NEAR_PHRASE_PRODUCT, Operator::ORDERED_NEAR_PHRASE_PRODUCT, Operator::SIMILAR
            unsupported = true
          when Operator::PUSH
            case code.value
            when PatriciaTrie, VariableSizeColumn, FixedSizeColumn
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
        else
          node
        end
      end

      def node_estimate_size_for_query(table, node, query)
        case node
        when ExpressionTree::Variable
          estimated_costs = node.column.indexes.map do |info|
            info.index.estimate_size(query: query)
          end
          if estimated_costs.any?
            estimated_costs.max
          else
            node.estimate_size(table)
          end
        when ExpressionTree::Accessor
          estimated_costs = node.object.indexes.map do |info|
            info.index.estimate_size(query: query)
          end
          if estimated_costs.any?
            estimated_costs.max
          else
            node.estimate_size(table)
          end
        when ExpressionTree::IndexColumn
          node.object.estimate_size(query: query)
        when ExpressionTree::FunctionCall
          if node.procedure.object.scorer?
            estimated_costs = node.arguments.map do |argument|
              node_estimate_size_for_query(table, argument, query)
            end
            estimated_costs.max
            if estimated_costs.any?
              estimated_costs.max
            else
              node.estimate_size(table)
            end
          else
            node.estimate_size(table)
          end 
        else
          node.estimate_size(table)
        end
      end

      def sort_nodes(table, nodes)
        nodes.sort_by do |node|
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
                    case node
                    when ExpressionTree::BinaryOperation
                      node_estimate_size_for_query(table, node.left, query)
                    else
                      node_estimate_size_for_query(table, node, query)
                    end
                  end
                  estimated_costs.max
                when ExpressionTree::BinaryOperation
                  node_estimate_size_for_query(table, match_column_node.left, query)
                else
                  node_estimate_size_for_query(table, match_column_node, query)
                end
              else
                node_estimate_size_for_query(table, node.left, query)
              end
            else
              node.estimate_size(table)
            end
          when ExpressionTree::FunctionCall
            case node.procedure.object.name
            when "tag_search"
              column = node.arguments.first
              queries = node.arguments.select { |argument| argument.is_a?(ExpressionTree::Constant) }
              estimated_costs = queries.map do |query|
                node_estimate_size_for_query(table, column, query.value)
              end
              if estimated_costs.any?
                estimated_costs.max
              else
                node.estimate_size(table)
              end
            else
              node.estimate_size(table)
            end
          else
            node.estimate_size(table)
          end
        end
      end

      def optimize_and_sub_nodes(table, sub_nodes)
        optimized_nodes = []
        target_nodes = []
        while node = sub_nodes.shift
          case node
          when ExpressionTree::FunctionCall
            case node.procedure.object.name
            when "tag_search", "between"
              target_nodes.push(node)
            else
              optimized_nodes += sort_nodes(table, target_nodes)
              optimized_nodes.push(node)
              target_nodes = []
            end
          else
            target_nodes.push(node)
          end
        end
        if target_nodes.any?
          optimized_nodes += sort_nodes(table, target_nodes)
        end
        optimized_nodes
      end
    end
  end
end
