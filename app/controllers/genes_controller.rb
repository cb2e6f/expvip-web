class GenesController < ApplicationController

  require 'digest'  

  before_action :set_gene, only: [:show, :edit, :update, :destroy]

  def examples
    @gene_set = GeneSet.find(session[:gene_set_id])
    examples = GenesHelper.get_example_genes(@gene_set)
    respond_to do |format|      
      format.json { 
        render json: examples
      }
    end
  end

  def getGeneIds(genes)
    gs = Set.new
    gene_set = GeneSet.find(session[:gene_set_id])    
    old_search_by = false
    genes.each do |g|  
      next if g.size == 0
      gene, search_by = GenesHelper.findGeneName(g, gene_set)
      l_name = search_by == "gene" ?  gene.gene : gene.name
      gs << l_name
      old_search_by = search_by unless old_search_by
      raise "Unable to compare a mix of genes and transcripts." unless search_by == old_search_by
    end
    return gs.to_a
  end

  def forwardHeatmap
    genes = params[:genes_heatmap].split(/[,\s]+/).map { |e| e.strip }
    raise "Please select less than 500 genes" if genes.size > 500
    ids = getGeneIds(genes)
    raise "Plese select some genes for the heatmap" if ids.size == 0
    session[:genes] = ids.join(',')    
    redirect_to action: "heatmap"
  end

  def forwardCommon
    gene_name = nil
    gene_name = params[:gene]
    gene_name = params[:query] if params[:query]
    @gene_set = GeneSet.find(params[:gene_set_selector]) if params[:gene_set_selector]
    @gene_set = GeneSet.find(params[:gene_set_selector_main]) if params[:gene_set_selector_main]
    @gene_set = GeneSet.find_by(:name => params[:gene_set]) if params[:gene_set]    
    session[:heatmap] = false
    @gene, @search_by = GenesHelper.findGeneName gene_name, @gene_set 
    @search_by = params[:search_by] if ["gene", "transcript"].include? params[:search_by]
    session[:name] = @search_by == "gene" ? @gene.gene : @gene.name 
    session[:search_by] = @search_by
    session[:gene_set_id] = @gene_set.id
  end

  def forwardSearch
    forwardCommon    
    redirect_to  action: "show", 
      search_by: @search_by, 
      name: session[:name], 
      gene_set: @gene_set.name
  end

  def forwardCompare
    forwardCommon
    @compare, @search_by_compare = GenesHelper.findGeneName params[:compare], @gene_set
    raise "Can't compare gene vs transcript" unless @search_by == @search_by_compare
    redirect_to  action: "show", 
      search_by: @search_by, 
      name: session[:name], 
      gene_set: @gene_set.name,
      compare:  params[:compare] 
  end

  # GET /genes
  # GET /genes.json
  def forward
    session[:studies] = params[:studies] if  params[:studies]     
    begin
      case params[:submit] 
      when "Heatmap"
        forwardHeatmap 
      when "Search"
        forwardSearch
      when "Compare"
        forwardCompare
      else
        raise "Unknow redirect: #{params[:submit]}"
      end
    rescue Exception => e
      flash[:error] = e.to_s
      #puts "ERROR: #{e.inspect}"
      #puts e.backtrace
      redirect_back fallback_location: request.base_url.to_s
      return 
    end
	end

  def autocomplete
    gene_set_id = session[:gene_set_id] 
    @genes = Gene.order(:name).where("name LIKE ? and gene_set_id = ?", "%#{params[:term]}%", gene_set_id).limit(20)

    respond_to do |format|
      format.html
      format.json { 
        render json: [@genes.map(&:gene).uniq, @genes.map(&:transcript) ].flatten
      }
    end
  end

  def heatmap    
    genes = []
    genes = session[:genes] if  session[:genes] 
    genes = params[:genes]  if  params[:genes]
    session[:studies] = params[:studies] if  params[:studies] 
    studies = session[:studies]
    session[:genes] = params[:genes] if params[:genes]
    session[:heatmap] = true

    # If parameters passed contain settings (it's a shared link)
    studies = set_shared_settings if params[:settings]

    @args = {studies: studies }.to_query
    respond_to do |format|
      format.html { render :heatmap }
    end
  end

  # GET /genes/1
  # GET /genes/1.json
  def show 
    #Use TRIAE_CS42_2BL_TGACv1_130848_AA0418720 as it has multiple transcripts
    studies = session[:studies]    
    compare = ""
    alert = ""
    
    #search_by = params[:search_by]
    #search_by.capitalize! if search_by
    gene = {
      name: params[:name],
      gene: params[:name], 
      search_by:  params[:search_by],
      gene_set: params[:gene_set]
    }
    @compare = params[:compare] if params[:compare]
    
    
    # If parameters passed contain settings (it's a shared link)
    studies = set_shared_settings if params[:settings]
     
    
    @gene = OpenStruct.new(gene)    

    @args = {studies: studies,name: @gene.name ,compare: @compare, gene_set: params[:gene_set]  }.to_query  

    #studies.each { |e|  @studies += "studies[]=#{e}\&" }`
  end  

  def share 
    # Hash the settings sent by the clinet's request
    sha1 = Digest::SHA1.new
    sha1 << params[:settings]
    hashed_settings = sha1.hexdigest

    # Get the gene set & gene
    gene_set = GeneSet.find(session[:gene_set_id])          
    gene_name = params[:gene]       
    session[:gene] = gene_name
    @gene, @search_by = GenesHelper.findGeneName gene_name, gene_set unless session[:heatmap]    
    
    # Preparing the DB record
    gene_name = @gene.name if gene_name    
    db_record = {:gene_set => gene_set.name, :name => gene_name, :search_by => @search_by, :settings => params[:settings], :hash => hashed_settings}
    db_record[:genes] = session[:genes] if session[:genes] and session[:heatmap]

    # Store the settings in the DB  
    @client = MongodbHelper.getConnection unless @client
    @client[:share].insert_one(db_record) if @client[:share].find({'hash' => hashed_settings}).count == 0
    
    #Generate the sharable URL and pass it to the client
    response = create_sharable_link gene_set.name, hashed_settings


      # response = request.base_url + "/" + params[:controller].to_s + "/" + @gene.id.to_s + "?" + {gene_set: gene_set.name}.to_query + "&" +{compare: params[:compare]}.to_query + "&" + {name: session[:name]}.to_query + "&" + {search_by: @search_by}.to_query + "&" + {settings: hashedSettings}.to_query    
      # response = request.base_url + "/" + params[:controller].to_s + "/heatmap?" + {settings: hashedSettings}.to_query          
      # response = "#{request.base_url}/#{params[:controller]}/#{@gene.id}?#{{gene_set: gene_set.name}.to_query}&#{{name: session[:name]}.to_query}&#{{search_by: @search_by}.to_query}&#{{settings: hashedSettings}.to_query}"
          
    
    respond_to do |format|
      format.json { render json: {"value" => response}}      
    end
    
  end

  def set_studies_session
    session[:studies] = JSON.parse params[:studies]    
  end
  
  private
    # Use callbacks to share common setup or constraints between actions.
    def set_gene
      @gene = Gene.find(params[:id]) if numeric? params[:id]
      @gene = Gene.find_by(:name=>params[:gene]) unless @gene
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def gene_params
      params.require(:gene).permit(:name,:studies, :cdna, :possition, :gene, :transcript)
    end

    def numeric?(string)
      # `!!` converts parsed number to `true`
      !!Kernel.Float(string) 
    rescue TypeError, ArgumentError
      false
    end
    
    def create_sharable_link gene_set_name, hashed_settings
    	if session[:heatmap]

    		response = "#{request.base_url}/#{params[:controller]}/heatmap?#{{settings: hashed_settings}.to_query}"

    	else

    		response = "#{request.base_url}/#{params[:controller]}/#{@gene.id}?#{{gene_set: gene_set_name}.to_query}&#{{name: session[:name]}.to_query}&#{{search_by: @search_by}.to_query}&#{{settings: hashed_settings}.to_query}"
    		response += "&" +{compare: params[:compare]}.to_query if params[:compare]

    	end
    	
    	return response
    end    

    def set_shared_settings
    	@client = MongodbHelper.getConnection unless @client    
      data = @client[:share].find({'hash' =>  params[:settings]}).first
      @settings = data[:settings]
      gene_set_name = data[:gene_set]
      @gene_set_id = GeneSet.find_by(:name=>gene_set_name)
      session[:gene_set_id] = @gene_set_id.id
      settingsObj = JSON.parse @settings
      session[:genes] = settingsObj['genes'] if settingsObj['genes']
      return settingsObj['study']
    end

end
