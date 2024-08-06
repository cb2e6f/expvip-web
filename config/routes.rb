require "#{Rails.root}/lib/links.rb"  
Rails.application.routes.draw do
  #map.root :controller => 'wellcome', :action => :default
  #get 'wellcome/default'
  root 'wellcome#default'
  get 'wellcome/search_gene'

  get 'download' => 'download#default'
  get 'cite' =>  'wellcome#cite'
 # resources :expression_values
 # resources :type_of_values
 # resources :meta_experiments
 # resources :gene_sets
  resources :genes  do
    collection do
      get 'autocomplete'
      get 'heatmap'
      post 'forward'
      get 'forward'
      post 'share' 
      get 'set_studies_session'     
      get 'show'
      get 'examples'
    end
  end
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'
  get 'expression_values/gene' => 'expression_values#gene'
  get 'expression_values/transcript' => 'expression_values#transcript'
  get 'expression_values/genes' => 'expression_values#genes'

  resources :gene_sets  do
    collection do
      get 'set_gene_set_session'     
    end
  end
end
