module Api
  module V1
    class WatchlistItemsController < BaseController
      LEVEL_FIELDS = %i[entry_zone_low entry_zone_high invalidation_price stop_loss_price target_price pivot_price].freeze
      SETUP_LABELS = { "vcp" => "VCP breakout", "pullback" => "Pullback to support" }.freeze

      before_action :set_item, only: %i[update destroy trade_plan]

      def index
        items = current_user.watchlist_items.includes(:stock).order(updated_at: :desc)
        items = items.tracked unless ActiveModel::Type::Boolean.new.cast(params[:include_archived])
        render json: items, each_serializer: WatchlistItemSerializer, context: Watchlist::MarketContext.call
      end

      # Previews suggested levels before adding a stock.
      def suggestion
        stock = Stock.active.find_by!(symbol: params[:symbol].to_s.upcase)
        result = Watchlist::EntryZoneSuggester.call(stock, params[:setup_type].presence || "vcp")
        render json: result.merge(symbol: stock.symbol, current_price: stock.last_price.to_f),
               status: result[:success] ? :ok : :unprocessable_entity
      end

      def create
        stock = Stock.active.find_by!(symbol: params[:symbol].to_s.upcase)
        setup_type = params[:setup_type].presence || "vcp"
        suggestion = Watchlist::EntryZoneSuggester.call(stock, setup_type)
        manual = level_params.to_h.symbolize_keys.compact_blank

        if manual.empty? && !suggestion[:success]
          return render json: { error: suggestion[:error] }, status: :unprocessable_entity
        end

        suggested = suggestion[:success] ? suggestion[:levels].slice(*LEVEL_FIELDS) : {}
        item = current_user.watchlist_items.build(
          stock: stock,
          setup_type: setup_type,
          notes: params[:notes],
          price_at_add: stock.last_price,
          setup_snapshot: suggestion[:success] ? suggestion[:snapshot] : {},
          **suggested.merge(manual)
        )

        if item.save
          Watchlist::AlertEvaluator.initial_state!(item)
          render json: item, serializer: WatchlistItemSerializer, status: :created
        else
          render json: { error: item.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def update
        @item.assign_attributes(level_params)
        @item.notes = params[:notes] if params.key?(:notes)
        restoring = %w[watching].include?(params[:status])
        @item.status = params[:status] if params[:status].in?(%w[watching archived])

        if @item.save
          # Re-evaluate from scratch when levels change or the item is restored.
          Watchlist::AlertEvaluator.initial_state!(@item) if restoring || level_params.present?
          render json: @item.reload, serializer: WatchlistItemSerializer
        else
          render json: { error: @item.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy
        @item.destroy!
        render json: { deleted: true, id: @item.id }
      end

      # Creates a trade plan from the setup and marks the item as planned.
      def trade_plan
        strategy = TradingStrategy.find_by(name: params[:strategy]) if params[:strategy].present?
        plan = current_user.trade_plans.build(
          stock: @item.stock,
          trading_strategy: strategy,
          status: "planned",
          entry_strategy: SETUP_LABELS.fetch(@item.setup_type),
          analysis_type: "technical",
          planned_entry_price: params[:planned_entry_price].presence || @item.entry_zone_low,
          stop_loss_price: params[:stop_loss_price].presence || @item.stop_loss_price || @item.invalidation_price,
          target_price: params[:target_price].presence || @item.target_price,
          planned_quantity: params[:planned_quantity].presence,
          entry_trigger_description: params[:thesis].presence || default_thesis,
          market_condition_at_entry: @item.setup_snapshot["market_regime"]
        )

        TradePlan.transaction do
          plan.save!
          @item.update!(trade_plan: plan, status: "planned")
        end
        render json: { trade_plan_id: plan.id, watchlist_item: WatchlistItemSerializer.new(@item.reload).as_json }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      private

      def set_item
        @item = current_user.watchlist_items.includes(:stock).find(params[:id])
      end

      def level_params
        params.permit(*LEVEL_FIELDS)
      end

      def default_thesis
        zone = "#{format('%.2f', @item.entry_zone_low)}-#{format('%.2f', @item.entry_zone_high)}"
        "#{SETUP_LABELS.fetch(@item.setup_type)} on #{@item.stock.symbol}: entry zone #{zone}, " \
          "invalidated below #{format('%.2f', @item.invalidation_price)}."
      end
    end
  end
end
