Atom::Application.routes.draw do

  # Modules
  mount ShipmentsModule::Engine, at: "/shipments", as: "shipments_module"
  mount RateCalculatorModule::Engine, at: "/rate_calculator", as: "rate_calculator_module"

  resources :overlays do
    member do
      get :file_entities
      get :new_file_note
      get :new_entity_note
      get :close_note
      get :fatco_rate_request
      get :cpl_new
      get :cpl
      get :cpl_request
      get :cpl_close
      get :cpl_cancel
      get :cpl_show
      get :manage_signatures
      get :add_affiliations
      get :show_resend_confirmation
      get :file_disbursements
      get :payments # Proof of Concept
      get :cell_attributes
      get :change_line_type
      get :insert_line
      get :balance_sheet
      get :tax_proration_calculator
      get :hoa_proration_calculator
      get :merge_disbursements
      get :confirm_payment_change
      get :confirm_destroy_check_working
    end
    collection do
      get :add_file_entities_new_order
      get :new_site_preference
      get :manage_signature_block
      get :edit_address
      get :choose_side
      get :choose_doc_entity
      get :file_properties
      get :show_overlay
      get :new_file_entity
      get :bug_report
      get :feature_request
      get :new_order
      get :new_contact
      get :doc_lookup
      get :new_entity
      get :new_user
      get :new_rule
      get :payment_disbursement_info
    end
  end

  resources :file_notes do
    member do
      get :current_notes
    end
    collection do
      get :search
      get :add_to_view
    end
  end

  # Disbursements
  resources :check_workings do
    collection do
      post :view_check
      get :update_file
      get :show_type
      get :add_payee
      get :change_purpose
      get :update_summary
      get :calculate_wire
      post :create_receipt
      get :destroy_receipt
      get :create_receipt_overlay
      get :split
      get :show_merge
      post :merge
      get :get_check_file_number
      get :print_receipt
      get :display_receipt
      get :display_confirmation
    end
    member do
      get :view_check
      get :view_printed_check
      get :remove_payee
      get :associate_with_hud_line
      get :get_printed_confirmation
    end
  end

  resources :template_settlement_statements
  resources :settlement_statements do
    member do
      post :update_tax_proration
      post :update_hoa_proration
    end
  end

  resources :ss_lines do
    member do
      put :change_line_type
      put :insert_line
      get :view_payments
    end
  end
  resources :ss_line_cells do
    collection do
      put :update_transactions
      put :update_attributes
    end
  end

  resources :payment_disbursements do
    member do
      get :split
    end
  end

  # Home
  resources :home, only: [:index]

  # Application
  resources :application do
    collection do
      get :add_task
      post :flash_notice
      get :flash_notice
      get :large_text
      get :usps
    end
  end

  # Dashboard
  resources :dashboard do
    collection do
      get :upload
    end
  end

  # Feedback
  resources :feedback do
    collection do
      post :send_bug_report
      post :send_feature_request
    end
  end

  # Docs
  resources :docs do
    collection do
      get :destroy
      get :update_related
      get :edit_custom_field
      post :create_custom
      get :show_send
      get :send_docs
      get :import_from_pr
      get :show_lookup_options
      post :print
      post :save
      get :display_search_results
      get :doc_list
      post :send_doc
      get :send_doc
      get :refresh_input_fields
      get :create_signature
      get :update_signature
      get :update_signature_position
      put :update_entity_position
      delete :remove_entity
      get :remove_signature
      put :toggle_split_notary
      get :revert_to_global
      get :add_entity
      post :create_entity
      get :insert_entity
      get :add_sub_entity
      get :new_entity
      put :change_signature_block
      put :update_entity_signature
      get :choose_doc_entity
      get :quick_add
      get :update_all
      post :update_address
      get :display_address_results
      get :display_address_entry
      get :update_settlement_dates
      get :update_notary_vesting
    end
    member do
      get :show_editor
      get :show_doc
      post :save_template
      get :reset_fields
      get :create_entity_signature
      get :signature_preview
      get :format_signature
      get :edit_description
      post :update_description
      get :zoom
    end
  end

  # Doc Templates
  resources :doc_templates do
    collection do
      get :doc_list
      get :pdf
      get :groups
      get :filter_by_state
    end
    put :toggle_group, on: :member
  end

  # Doc Groups
  resources :doc_groups do
    get :display_search_results, on: :collection
    member do
      get :display_templates_not_in_group
      get :add_to_group
      post :update_group
    end
  end

  resources :doc_group_templates

  # Index
  resources :index do
    collection do
      get :update_employee_options
      get :add_employee_to_new_file
      post :add_property_to_new_file
      get :display_search_results
      get :unique_tax_id
      get :display_disbursement_sheet
      post :display_search_results
    end
    member do
      get :gather_contacts
      get :gather_disbursement_contacts
      get :file_info
      post :file_info
      get :update_file_stage
      get :file_image
      get :file_email
      get :change_company
      get :cancel_note
      get :show_resend_confirmation
      post :resend_confirmation
      get :print_confirmation
      get :display_confirmation
      get :print_disbursement_sheet
      get :load_tab
      get :toggle_balance_view
      get :refresh_disbursements
    end
    resources :file_entities, only: [:create, :new]
    resources :file_employees, only: [:create, :new]
    resources :file_properties, only: [:create, :new] do
      collection do
        post :search
      end
    end
    resources :file_notes, only: [:index, :create, :new]
    resources :file_images do
      collection do
        get :show_inactive
      end

      member do
      end
    end
  end

  resources :file_employees, except: [:create, :new]
  resources :file_entities, except: [:create, :new] do
    collection do
      get :search
      # get :display_search_results
      # post :add_to_view
    end
    member do
      post :update_position
      # get :current_contacts
      # get :update_position
    end
  end
  resources :file_properties, except: [:create, :new]

  # Edit File Info
  match '/index/:id/edit_file_info' => 'index#edit_file_info'
  match '/index/update_file_info'   => 'index#update_file_info'
  match '/index/:id/cancel_update_file_info'   => 'index#cancel_update_file_info'

  # File Images
  match '/file_images/view_all'             => 'file_images#view_all'
  match '/file_images/reload_file_images'   => 'file_images#reload_file_images'
  match '/file_images/request_file'         => 'file_images#request_file'
  match '/file_images/load_process_images'  => 'file_images#load_process_images'
  post  '/file_images/file_image_upload'    => 'file_images#file_image_upload', as: "file_image_upload"
  get   '/file_images/file_image_upload'    => 'file_images#file_image_upload', as: "file_image_upload"
  match '/file_images/dnd_upload'           => 'file_images#dnd_upload'
  match '/file_images/remove_temp'          => 'file_images#remove_temp'
  match '/file_images/send_images'          => 'file_images#send_images'
  match '/file_images/view_log'             => 'file_images#view_log'
  match '/file_images/:id/delivery_history' => 'file_images#delivery_history'
  match '/file_images/search_entities'      => 'file_images#search_entities'
  match '/file_images/:id/toggle_active'    => 'file_images#toggle_active'
  match '/index/:id/file_images/new'        => 'file_images#new'
  match '/index/show_new'                   => 'index#show_new'
  match '/index/add_note_to_new_file'       => 'index#add_note_to_new_file'
  match '/index/display_all_file_images'    => 'index#display_all_file_images'
  match '/file_images/:id', to: 'file_images#destroy', via: :delete

  # Rolodex
  resources :rolodex do
    resources :entity_contacts do
      get :edit_info
    end
    resources :entity_notes
    resources :entity_rules
    member do
      get :cancel_update_rolodex_info
      get :entity_new_note
      get :show_contact
      get :preview
      get :edit_rolodex_info
      put :update_convenience_field
      put :update_primary
      get :result_detail
    end
    collection do
      get :show_children
      get :show_new
      get :check_for_duplicates
      get :quick_search
      get :show_entity_by_type
      post :add_contact_to_new_entity
      post :add_address_to_new_entity
      post :add_note_to_new_entity
      post :add_affiliation_to_new_entity
      get :add_affiliation_to_new_entity
      get :display_search_results
      post :update_rolodex_info
    end
  end

  resources :rolodex_affiliations do
    collection do
      post :display_search_results
    end
  end

  resources :orders
  resources :file_images

  resources :rolodex_attachments do
    collection do
      get :reload_entity_images
      get :request_file
      get :load_process_images
      get :user_image
      get :user_file_upload
      post :user_file_upload
      get :dnd_upload
      get :remove_temp
    end
  end

  # Rolodex Signatures
  resources :rolodex_signatures do
    member do
      get :show_editor
      get :mark_active
      post :save_block
      get :revert_to_signature_builder
      get :edit_description
      get :update_description
    end
    collection do
      put :update_signature_entity
      get :add_child
      delete :remove_child
      get :add_to_show
      put :update_child_sort
      get :entity_lookup
    end
  end

  # Entity Contact Info
  resources :entity_contacts do
    member do
      get :activate
      get :show_info
    end
    get :toggle_active, on: :collection
  end

  #Recon Tracking
  resources :recon_trackings do
    collection do
      get :refresh
      get :get_beneficiary_info
    end
    get :copy, on: :member
  end

  # Employee Rolodex
  resources :employee_rolodex

  # Bulletins
  resources :bulletins do
    post :search, on: :collection
  end

  # File Products
  resources :file_products do
    collection do
      get :review
      get :display_search_results
      get :print
      get :display
      get :show_options
      get :get_prior_product_options
      get :helper
      put :helper
      get :import
      put :import
    end
    member do
      get :result_detail
    end
  end

  resources :fp_requirements do
    get :editor, on: :collection
  end

  resources :fp_exceptions do
    collection do
      get :editor
      get :add_requirement
      get :get_exception_number
    end
  end

  resources :schedule_as
  resources :policies
  resources :policy_endorsements

  resources :file_product_histories do
    collection do
      get :undo
      get :view
    end
  end

  # Other
  resources :entity_notes
  resources :entity_rules

  resources :rolodex_affiliations
  resources :orders
  resources :file_images

  # Employees
  resources :employees do
    get :search, on: :collection
  end

  #HUD Lines
  resources :hud_lines do
    member do
      get :clear
      get :default
      get :new_description
      get :manage
      get :update_wallet
      get :split
      get :new_payment
      get :create_payment
      get :add_payee
      get :update_check
      get :change_purpose
      get :view_check
      get :remove_payment
      get :update_payment
      get :refresh_payments
      get :view_payments
    end
  end

  # HUD
  resources :hud_entities

  resources :huds do
    resources :hud_lines
    collection do
      get :dashboard
    end
    member do
      get :sandbox
      get :export_to_new
      get :print
      get :toggle_view
      get :tax_proration_calculator
      post :update_tax_proration
      get :hoa_proration_calculator
      post :update_hoa_proration
    end
  end

  # Invoice
  resources :invoices do
    collection do
      get :hud_fees
      get :update_hud_invoice
    end
    get :set_invoice_date, on: :member
  end

  resources :closing_protection_letters do
    member do
      get :submit_cpl_order
      get :get_lookup_data
      get :close_cpl
      get :update_cpl
      get :cancel_cpl
      get :find_cpl_by_order_number
      get :display_image
    end
  end

  resources :properties do
    collection do
      get :display_search_results
      get :generate_pdf, as: :generate_pdf
      get :images, as: :assessor_image
      get :plat, as: :plat_image
    end
    member do
      get :result_detail
    end
  end

  resources :recording_entries do
    collection do
      get :display_search_results
    end
    member do
      get :result_detail
      get :show_file
    end
  end

  # New Orders
  resources :new_orders do
    resources :file_employees, module: 'new_orders', only: [:create, :destroy] do
      collection do
        get :show_all_employees
      end
    end
    resources :file_properties, module: 'new_orders', only: [:create, :destroy] do
      collection do
        get :lookup_property
        get :fill_property_row
        get :add_custom
      end
    end
    resources :file_entities, module: 'new_orders', only: [:create, :destroy]
    resources :file_notes, module: 'new_orders', only: [:create, :destroy]
    collection do
      get :check_in_progress
    end
  end

  # Admin
  namespace :admin do
    resources :users do
      member do
        get :result_detail
        put :set_user_preference
        put :edit_permission
        put :edit_company
      end
      collection do
        get :display_search_results
      end
    end
    resources :site_preferences do
      member do
        get :set_preference
        get :reset_user_preferences
      end
      collection do
        get :reset_preferences
      end
      devise_scope :user do
        member do
          get :set_user_preference
        end
      end
    end
    resources :site_preference_options
    resources :rules do
      member do
        get :result_detail
      end
      collection do
        post :search
        post :test
      end
    end
    resources :rule_names
    resources :rule_exceptions
    resources :rule_triggers
    root to: 'users#index'
  end

  resources :rule_triggers

  # User Preferences and Settings
  resources :users_preferences, only: [:update]
  resources :site_preferences do
    member do
      get :set_preference
      get :reset_user_preferences
    end
    collection do
      get :reset_preferences
    end
    devise_scope :user do
      member do
        get :set_user_preference
      end
    end
  end

  # Devise authentication
  devise_for :users, path: "", path_names: { sign_in: "login", sign_out: "logout" }
  resources :users do
    member do
      get :edit_role
      get :edit_permission
      get :edit_company
    end
    collection do
      get :populate_permissions
    end
  end

  # Default Route
  root to: 'index#index'
end
