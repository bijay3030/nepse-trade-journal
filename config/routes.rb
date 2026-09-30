Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  mount ActionCable.server => "/cable"

  devise_for :users,
             path: "",
             path_names: {
               sign_in: "login",
               sign_out: "logout"
             },
             controllers: {
               sessions: "users/sessions"
             },
             defaults: { format: :json }

  namespace :api do
    namespace :v1 do
      get "market/overview", to: "market#overview"
      get "screener", to: "screener#index"
      get "screener/:symbol", to: "screener#show"

      resources :stocks, only: [:index, :show] do
        collection do
          get :sectors
          get :current_prices
        end
        member do
          get :historical_prices
          get :financials
        end
      end

      post "data_imports/seed_master", to: "data_imports#seed_master"
      post "data_imports/sync_daily_prices", to: "data_imports#sync_daily_prices"
      post "data_imports/sync_market", to: "data_imports#sync_market"
      post "data_imports/import_csv", to: "data_imports#import_csv"

      resources :trade_plans, only: [:index, :create, :show, :destroy] do
        resource :trade_execution, only: :create
      end

      resources :trade_executions, only: [] do
        resource :trade_result, only: :create
      end

      resources :daily_journals, only: [:index, :create, :show] do
        get :version_history
        post "versions/:id/restore", to: "daily_journals#restore_version", as: :restore_version
      end

      get "data_management/trades_export_csv", to: "data_management#trades_export_csv"
      get "data_management/journal_export_markdown", to: "data_management#journal_export_markdown"
      get "data_management/analytics_export_report", to: "data_management#analytics_export_report"
      get "data_management/full_backup", to: "data_management#full_backup"
      get "data_management/import_template", to: "data_management#import_template"
      post "data_management/import_preview", to: "data_management#import_preview"
      post "data_management/import_commit", to: "data_management#import_commit"
      get "data_management/deleted_trades", to: "data_management#deleted_trades"
      post "data_management/restore_trade/:id", to: "data_management#restore_trade"
      get "data_management/audit_logs", to: "data_management#audit_logs"

      get "analytics/dashboard", to: "analytics#dashboard"
      get "analytics/trade_statistics", to: "analytics#trade_statistics"
    end
  end
end
